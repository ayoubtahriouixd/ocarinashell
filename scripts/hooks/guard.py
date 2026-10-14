#!/usr/bin/env python3
"""PreToolUse guard for Claude Code (matcher: Bash). Reads the hook JSON on stdin; exit 2 blocks the command.

A safety net, not a sandbox. The command is parsed like a shell would (shlex: quotes, ; & | && || ( ) $( ) <( ),
newlines, here-docs), common prefixes are peeled (sudo, env, timeout, nohup, xargs, systemd-run…), nested commands
are followed (sh -c, su -c, eval, find -exec, niri msg action spawn, shell here-docs/here-strings) and every
sub-command is judged by what it IS — so `git commit -m "… reboot …"` passes and `sh -c "rm -rf ~"` does not.
Blocked: session killers, power actions, boot chain (/boot, /efi, Limine, mkinitcpio, kernels, EFI vars, firmware),
sudoers/PAM, snapshots, disk tools, recursive deletes of system/home roots, the Fune VM disk, container volumes,
remote scripts piped to a shell, forced pushes, DDC/CI writes other than brightness/contrast, deleting restic
backups outside /tmp test repos, recursive deletes on external disks, and running scripts/root/* (Ayoub runs those
himself).
Stdlib only. Tests: scripts/hooks/test-guard.py
"""
import json
import posixpath
import re
import shlex
import sys

MSG = ("BLOQUEADO por scripts/hooks/guard.sh: {}.\nNo lo esquives. Explica a Ayoub qué necesitas y por qué "
       "(AskUserQuestion); si lo aprueba, escribe un script en scripts/root/ y que lo ejecute él.\n")


class Blocked(Exception):
    pass


def block(reason):
    raise Blocked(reason)


# ------------------------------------------------------------------ path rules
RM_BAD = re.compile(r"^(/|~|\$HOME|/home(/[^/]+)?|/root|/etc|/usr|/var|/boot|/efi|/opt|/srv|/bin|/sbin|/lib|/lib64|"
                    r"/\.snapshots|(~|\$HOME|/home/[^/]+)/(\.config|\.local|\.local/share|ocarinashell)|\.|\.\.|\*|\./\*|\.\./\*)$")
WR_BAD = re.compile(r"^(/boot(/.*)?|/efi(/.*)?|/etc/sudoers(\.d(/.*)?)?|/etc/pam\.d(/.*)?|/etc/default/limine|/etc/limine[^/]*|"
                    r"/etc/mkinitcpio\.conf|/etc/mkinitcpio\.(conf\.)?d(/.*)?|/etc/kernel(/.*)?|/etc/plymouth(/.*)?|/etc/fstab|"
                    r"/etc/crypttab|/\.snapshots(/.*)?|/dev/(sd|nvme|mmcblk|vd|hd|dm-|mapper/|disk/).*|/proc/sysrq-trigger)$")
SUDO_TEMP = "/etc/sudoers.d/90-ocarinashell-temporal"
FUNE = re.compile(r"\.local/share/ocarinashell/fune")
EXTERNAL = ("/run/media", "/mnt", "/media")
KERNEL = re.compile(r"^linux(-cachyos(-[a-z0-9]+)*|-lts|-zen|-hardened|-rt)?$")
KERNEL_FILE = re.compile(r"^linux(-cachyos[a-z0-9-]*|-lts|-zen|-hardened|-rt)?-\d")
CRIT = re.compile(r"^(linux(-cachyos[a-z0-9-]*)?|linux-lts|linux-firmware|amd-ucode|niri|sudo|systemd|systemd-libs|pam|limine|"
                  r"limine-snapper-sync|limine-mkinitcpio-hook|snapper|snap-pac|btrfs-progs|networkmanager|mesa|glibc|base|"
                  r"filesystem|pacman|archlinux-keyring|cachyos-keyring|quickshell|qt6-base|plymouth|mkinitcpio)$")
SESSION_UNITS = re.compile(r"^(niri|graphical-session|display-manager|greetd|sddm|gdm|lightdm|systemd-logind|dbus|user@|wayland-session)")
SHELLS = {"bash", "sh", "zsh", "dash", "fish", "ksh"}
PREFIXES = {"sudo", "doas", "run0", "pkexec", "exec", "nohup", "setsid", "command", "builtin", "time", "nice", "ionice",
            "chrt", "taskset", "stdbuf", "unbuffer", "xargs", "env", "systemd-run", "systemd-inhibit", "flock", "timeout",
            "watch", "caffeinate", "strace", "ltrace", "firejail", "torsocks", "proxychains", "proxychains4"}
TAKES_ARG = {
    "sudo": {"-u", "-g", "-C", "-D", "-p", "-r", "-t", "-U", "-T", "--user", "--group", "--chdir", "--prompt", "--role",
             "--type", "--other-user", "--close-from", "--command-timeout", "--host"},
    "doas": {"-u", "-C"}, "run0": {"-u", "--user", "-g", "--group", "-D", "--chdir", "--unit", "--property", "--setenv"},
    "pkexec": {"--user", "-u"}, "nice": {"-n", "--adjustment"},
    "ionice": {"-c", "-n", "-p", "-P", "-u", "--class", "--classdata", "--pid", "--pgid", "--uid"},
    "timeout": {"-s", "-k", "--signal", "--kill-after"}, "env": {"-u", "--unset", "-C", "--chdir"},
    "systemd-run": {"-p", "--property", "-u", "--unit", "-E", "--setenv", "-M", "--machine", "--slice", "--description",
                    "-H", "--host", "--uid", "--gid", "--working-directory", "-D", "--on-active", "--on-calendar"},
    "systemd-inhibit": {"--what", "--who", "--why", "--mode"}, "flock": {"-w", "--timeout", "-E", "--conflict-exit-code"},
    "watch": {"-n", "--interval", "-q", "--equexit"},
    "xargs": {"-I", "-n", "-P", "-d", "-L", "-s", "-E", "-a", "--max-args", "--max-procs", "--delimiter", "--arg-file"},
    "stdbuf": {"-i", "-o", "-e"}, "exec": {"-a"}, "time": {"-o", "--output"}, "taskset": {"-c"}, "chrt": {"-p"},
    "strace": {"-o", "-e", "-p", "-s", "-u"}, "ltrace": {"-o", "-e", "-p", "-s", "-u"},
}
SEPARATORS = {";", "&", "&&", "|", "||", "|&", "(", ")", "\n", ";;", "<(", ">(", "{", "}", "!", "then", "do", "else",
              "elif", "if", "while", "until", "fi", "done", "esac", "in"}
REDIR_W = {">", ">>", ">|", "&>", "&>>", ">&", "1>", "2>"}
REDIR_ANY = REDIR_W | {"<", "<<", "<<<", "<&", "<>", "<<-"}


def norm(p):
    if p in ("/", ""):
        return p
    return p.rstrip("/") or "/"


def writes_bad(p):
    return bool(WR_BAD.match(norm(p)))


def rm_target_bad(p):
    if p in ("/", "/*"):
        return True
    q = p.rstrip("/")
    if q.endswith("/*"):
        q = q[:-2]
    q = q.rstrip("/")
    if q.startswith("/") and posixpath.normpath(q).startswith(EXTERNAL):   # backup disks / NAS (Hikae lives there)
        return True
    return q == "" or bool(RM_BAD.match(q))


# ------------------------------------------------------------------ tokenising
HEREDOC = re.compile(r"<<(-?)\s*(['\"]?)([A-Za-z_][A-Za-z0-9_]*)\2")
SHELL_BEFORE = re.compile(r"(^|[;&|(\s])((sudo|doas|run0)\s+(-\S+\s+)*)?(bash|sh|zsh|dash|ksh)(\s+-\S+)*\s*$")


def split_heredocs(src):
    """Remove here-doc bodies from the command; bodies fed to a shell are returned as extra commands."""
    lines, out, extra, i = src.split("\n"), [], [], 0
    while i < len(lines):
        line = lines[i]
        out.append(line)
        m = HEREDOC.search(line)
        if m:
            delim, body, i = m.group(3), [], i + 1
            while i < len(lines) and lines[i].strip() != delim:
                body.append(lines[i])
                i += 1
            if SHELL_BEFORE.search(line[:m.start()]):
                extra.append("\n".join(body))
        i += 1
    return "\n".join(out), extra


def tokens(src):
    src = src.replace("\\\n", " ").replace("\r", " ").replace("`", " ; ").replace("${HOME}", "$HOME")
    lex = shlex.shlex(src, posix=True, punctuation_chars=";&|()<>\n")
    lex.whitespace = " \t"
    lex.whitespace_split = True
    lex.commenters = ""
    out = []
    try:
        for t in lex:
            out.append(t)
    except ValueError:                       # unbalanced quotes: fall back to a plain split (still checked)
        out = src.replace(";", " ; ").replace("|", " | ").replace("&", " & ").split()
    return out


def segments(src):
    """Yield (words, redirections) for every simple command; nested command strings go to `pending`."""
    body, extra = split_heredocs(src)
    pending.extend(extra)
    seg, redirs, toks, i = [], [], tokens(body), 0
    while i < len(toks):
        t = toks[i]
        if t.endswith("$") and i + 1 < len(toks) and toks[i + 1].startswith("("):     # $( … )
            t = t[:-1]
            if t:
                seg.append(t)
            yield seg, redirs
            seg, redirs = [], []
            i += 1
            continue
        if t in REDIR_ANY or (t and t[0].isdigit() and t.rstrip("0123456789") in REDIR_ANY):
            op = t.lstrip("0123456789")
            target = toks[i + 1] if i + 1 < len(toks) else ""
            redirs.append((op, target))
            i += 2
            continue
        if t in SEPARATORS or set(t) <= set(";&|()\n"):
            if seg or redirs:
                yield seg, redirs
            seg, redirs = [], []
            i += 1
            continue
        seg.append(t)
        i += 1
    if seg or redirs:
        yield seg, redirs


pending = []


# ------------------------------------------------------------------ the rules
def peel(w):
    """Skip prefixes like `sudo -u x env A=b timeout 5 nohup`. Returns the index of the real command."""
    i, n = 0, len(w)
    while i < n:
        t = w[i]
        base = t.rsplit("/", 1)[-1]
        if base in PREFIXES:
            pfx, i, positional = base, i + 1, 0
            while i < n:
                t = w[i]
                if t == "--":
                    i += 1
                    break
                if t.startswith("-") and len(t) > 1:
                    i += 2 if (t in TAKES_ARG.get(pfx, ()) and "=" not in t) else 1
                    continue
                if "=" in t or re.match(r"^[0-9.]+[smhd]?$", t):
                    i += 1
                    continue
                if pfx in ("flock", "taskset") and not positional:
                    positional, i = 1, i + 1
                    continue
                break
            continue
        if "=" in t and re.match(r"^[A-Za-z_][A-Za-z0-9_]*=", t):
            i += 1
            continue
        break
    return i


def check(words, redirs):
    for op, target in redirs:
        if op in REDIR_W or op.endswith(">") or op.endswith(">>"):
            if writes_bad(target):
                block(f"escribir en {target} (arranque, sudo, PAM, snapshots o disco)")
    if not words:
        return
    i = peel(words)
    if i >= len(words):
        return
    raw0 = words[i]
    if " " in raw0.strip() and len(words) == i + 1:     # watch "cmd args", xargs sh -c strings…
        pending.append(raw0)
        return
    c0 = raw0.rsplit("/", 1)[-1].lstrip("!")
    a = words[i + 1:]
    nonopt = [x for x in a if not x.startswith("-")]
    joined = " " + " ".join(a) + " "

    for op, target in redirs:                            # here-strings fed to a shell are commands
        if op == "<<<" and c0 in SHELLS:
            pending.append(target)

    if "scripts/root/" in raw0:
        block("los scripts de scripts/root/ los ejecuta Ayoub, no Claude Code")
    if c0 in SHELLS | {"su", "source", "."}:
        for k, x in enumerate(a):
            if x == "-c" or (re.match(r"^-[a-zA-Z]*c$", x) and c0 != "fish"):
                pending.append(" ".join(a[k + 1:]))
                break
        else:
            if "-n" not in a:
                for x in nonopt:
                    if "scripts/root/" in x:
                        block("los scripts de scripts/root/ los ejecuta Ayoub, no Claude Code")
                    break
    if c0 == "eval":
        pending.append(" ".join(a))
    if c0 == "find":
        root_bad = bool(nonopt) and rm_target_bad(nonopt[0])
        for k, x in enumerate(a):
            if x in ("-exec", "-execdir", "-ok", "-okdir"):
                rest = a[k + 1:]
                if ";" in rest:
                    rest = rest[:rest.index(";")]
                rest = [r for r in rest if r not in ("{}", "+", "\\;", ";")]
                if root_bad and rest and rest[0].rsplit("/", 1)[-1] == "rm" and \
                        any(r == "--recursive" or (r.startswith("-") and not r.startswith("--") and "r" in r.lower()) for r in rest[1:]):
                    block(f"find {nonopt[0]} … -exec rm -r")
                pending.append(" ".join(rest))
        if "-delete" in a and root_bad:
            block(f"find -delete sobre {nonopt[0]}")
    if c0 == "niri" and ("spawn" in a or "spawn-sh" in a):
        k = a.index("spawn") if "spawn" in a else a.index("spawn-sh")
        rest = [x for x in a[k + 1:] if x != "--"]
        pending.append(" ".join(rest))

    rule = RULES.get(c0)
    if rule:
        rule(c0, a, nonopt, joined)
    elif re.match(r"^mkfs(\..+)?$", c0):
        block(f"herramienta que formatea discos ({c0})")


def r_rm(c0, a, nonopt, joined):
    rec, opts, targets = False, True, []
    for x in a:
        if opts and x == "--":
            opts = False
            continue
        if opts and x.startswith("-") and len(x) > 1:
            if x == "--recursive" or (not x.startswith("--") and re.search(r"[rR]", x)):
                rec = True
            continue
        targets.append(x)
    for x in targets:
        if FUNE.search(x):
            block("borrar el disco de la VM de Windows (Fune)")
        if writes_bad(x) and norm(x) != SUDO_TEMP:
            block(f"borrar {x} (arranque, sudo, PAM, snapshots o disco)")
        if rec and rm_target_bad(x):
            block(f"rm recursivo sobre {x}")


def r_copy(c0, a, nonopt, joined):
    dest, k = None, 0
    while k < len(a):
        x = a[k]
        if x in ("-t", "--target-directory") and k + 1 < len(a):
            dest = a[k + 1]
        elif x.startswith("--target-directory="):
            dest = x.split("=", 1)[1]
        k += 1
    if dest is None and nonopt:
        dest = nonopt[-1]
    if dest and writes_bad(dest):
        block(f"{c0} hacia {dest} (arranque, sudo, PAM o snapshots)")


def r_write_all(c0, a, nonopt, joined):
    if c0 == "sed" and not any(x.startswith("-i") or x.startswith("--in-place") for x in a):
        return
    for x in nonopt:
        if writes_bad(x):
            block(f"{c0} sobre {x} (arranque, sudo, PAM, snapshots o disco)")
    if c0 in ("chmod", "chown", "chgrp"):
        for x in nonopt:
            if norm(x) in ("/", "/etc", "/usr", "/var", "/home", "~", "$HOME", "/boot"):
                block(f"{c0} sobre {x}")


def r_dd(c0, a, nonopt, joined):
    for x in a:
        if x.startswith("of="):
            p = x[3:]
            if p.startswith("/dev/") and p not in ("/dev/null", "/dev/zero", "/dev/stdout", "/dev/stderr", "/dev/tty"):
                block(f"dd hacia un dispositivo ({p})")
            if writes_bad(p):
                block(f"dd hacia {p}")


def r_download(c0, a, nonopt, joined):
    for k, x in enumerate(a[:-1]):
        if x in ("-o", "--output", "-O", "--output-document") and writes_bad(a[k + 1]):
            block(f"descargar sobre {a[k + 1]}")


def r_disk(c0, a, nonopt, joined):
    block(f"herramienta que formatea o borra discos ({c0})")


def r_part(c0, a, nonopt, joined):
    if not (set(a) & {"-l", "--list", "print"}):
        block(f"editar particiones ({c0})")


def r_crypt(c0, a, nonopt, joined):
    if set(a) & {"luksFormat", "erase", "luksErase", "luksKillSlot", "luksRemoveKey", "luksAddKey", "luksChangeKey",
                 "reencrypt", "convert"}:
        block("cambiar el cifrado del disco")


def r_power(c0, a, nonopt, joined):
    block("reiniciar o apagar: pídeselo a Ayoub al final de la fase")


def r_init(c0, a, nonopt, joined):
    if set(a) & {"0", "6", "s", "S", "1"}:
        block("cambiar de runlevel")


def r_systemctl(c0, a, nonopt, joined):
    op = nonopt[0] if nonopt else ""
    if op in {"reboot", "poweroff", "halt", "suspend", "hibernate", "hybrid-sleep", "suspend-then-hibernate", "kexec",
              "soft-reboot", "isolate", "exit", "default", "rescue", "emergency", "switch-root"}:
        block(f"systemctl {op} mataría la sesión o el equipo: pídeselo a Ayoub")
    if op in {"stop", "restart", "try-restart", "reload-or-restart", "try-reload-or-restart", "kill", "mask", "disable",
              "freeze"}:
        for u in nonopt[1:]:
            if SESSION_UNITS.match(u):
                block(f"systemctl {op} {u} mataría la sesión gráfica (y a Claude Code)")


def r_loginctl(c0, a, nonopt, joined):
    if set(a) & {"terminate-session", "terminate-user", "kill-session", "kill-user", "terminate-seat", "poweroff", "reboot",
                 "suspend", "hibernate"}:
        block("cerrar la sesión gráfica o apagar con loginctl")


def r_niri(c0, a, nonopt, joined):
    if "action" in a and "quit" in a[a.index("action") + 1:a.index("action") + 2]:
        block("cerrar niri mataría la sesión (y esta sesión de Claude Code)")


def r_pkill(c0, a, nonopt, joined):
    for x in nonopt:
        if re.search(r"(^|\W)niri(\W|$)", x) or x == "niri":
            block("matar niri mata la sesión")


def r_kill(c0, a, nonopt, joined):
    if "-1" in a[1:] or (a and a[-1] == "-1"):
        block("kill -1 mata todos los procesos")


def r_snapper(c0, a, nonopt, joined):
    if set(nonopt) & {"delete", "remove", "rm", "cleanup", "undochange", "rollback"}:
        block("borrar o aplicar snapshots (lo decide Ayoub, o Mamori con su ayudante)")


def r_btrfs(c0, a, nonopt, joined):
    j = " ".join(nonopt)
    if re.search(r"\b(subvolume|subvol|sub)\s+(delete|del)\b", j) or ("check" in nonopt and "--repair" in a) or \
            set(nonopt) & {"rescue", "replace"} or re.search(r"\bdevice\s+(delete|remove)\b", j):
        block("operación destructiva de btrfs (subvolúmenes/snapshots)")


def r_pkg(c0, a, nonopt, joined):
    rm_op = any(re.match(r"^-R", x) or x in ("--remove", "remove") for x in a)
    inst = any((re.match(r"^-S[a-z]*$", x) and not re.search(r"[islgpc]", x)) or x.startswith("-U") or x in ("--sync", "install")
               for x in a)
    for x in nonopt:
        b = x.rsplit("/", 1)[-1]
        if rm_op and CRIT.match(x):
            block(f"desinstalar un paquete crítico del sistema ({x})")
        if inst and ((KERNEL.match(x) and not x.endswith(("-headers", "-docs"))) or
                     (KERNEL_FILE.match(b) and "headers" not in b and "docs" not in b)):
            block(f"instalar o reinstalar el kernel ({x}) toca /boot y el initramfs (regla 10: lo hace Ayoub con scripts/root/)")


def r_mkinitcpio(c0, a, nonopt, joined):
    ok = {"-L", "--listhooks", "-H", "--hookhelp", "-M", "--automods", "-h", "--help", "-V", "--version"}
    if not a or not (a[0] in ok and (a[0] in ("-H", "--hookhelp") or set(a) <= ok)):
        block("regenerar el initramfs (regla 10: lo hace Ayoub con scripts/root/)")


def r_boot(c0, a, nonopt, joined):
    block(f"tocar el arranque ({c0}) — regla 10: script de scripts/root/ que ejecuta Ayoub")


def r_limine(c0, a, nonopt, joined):
    if not (set(a) & {"--version", "--help", "-h", "-v"}):
        block("instalar o modificar Limine")


def r_efi(c0, a, nonopt, joined):
    if any(x not in ("-v", "--verbose", "-u", "--unicode", "-q", "--quiet") for x in a):
        block("modificar las entradas EFI")


def r_bootctl(c0, a, nonopt, joined):
    if set(nonopt) & {"install", "update", "remove", "set-default", "set-oneshot", "unlink", "cleanup", "random-seed"}:
        block("modificar el gestor de arranque")


def r_sb(c0, a, nonopt, joined):
    if set(a) & {"sign", "sign-all", "enroll-keys", "create-keys", "reset", "remove-file", "--import", "--delete", "--reset"}:
        block("tocar Secure Boot")


def r_fw(c0, a, nonopt, joined):
    if set(nonopt) & {"update", "upgrade", "install", "reinstall", "downgrade", "activate", "switch-branch", "unlock", "install-blob"}:
        block("actualizar firmware/BIOS: lo aprueba Ayoub (Mamori lo propone)")


def r_plymouth(c0, a, nonopt, joined):
    if set(a) & {"-R", "--rebuild-initrd"}:
        block("regenerar el initramfs (regla 10)")


def r_visudo(c0, a, nonopt, joined):
    if not any(x == "--check" or (x.startswith("-") and not x.startswith("--") and "c" in x) for x in a):
        block("editar sudoers")


def r_usermod(c0, a, nonopt, joined):
    if re.search(r"(^|[\s,])(wheel|sudo)([\s,]|$)", " ".join(a)):
        block("dar permisos de administrador a un usuario")


def r_container(c0, a, nonopt, joined):
    if re.search(r" volume (rm|remove|prune)( |$)", joined) or (" system prune" in joined and " --volumes" in joined) or \
            (" compose " in joined and " down" in joined and re.search(r" (-v|--volumes)( |$)", joined)):
        block("borrar volúmenes de contenedores (el disco de Windows vive ahí)")


def r_git(c0, a, nonopt, joined):
    if "push" in nonopt:
        for x in a:
            if re.match(r"^(-f|--force|--force-with-lease.*|--force-if-includes|\+.+)$", x):
                block("git push forzado")


DDC_ARG = {"-b", "--bus", "-d", "--display", "--dis", "-l", "--model", "-g", "--mfg", "-n", "--sn", "-e", "--edid", "-u",
           "--usb", "--sleep-multiplier", "--maxtries", "--trace", "--trcfunc", "--trcfile", "--mccs"}
DDC_WRITABLE = {0x10, 0x12}                         # brightness, contrast


def r_ddc(c0, a, nonopt, joined):
    # ddcutil [opts] setvcp <code> [+|-] <value> [<code> [+|-] <value>…]: only brightness/contrast may be written
    pos, skip = [], False
    for x in a:
        if skip:
            skip = False
        elif x in ("+", "-") or not x.startswith("-"):
            pos.append(x)
        elif x in DDC_ARG:
            skip = True
    if set(pos) & {"loadvcp", "scs"}:
        block("ddcutil: cargar o grabar perfiles en el monitor (solo se permite brillo y contraste)")
    if "setvcp" not in pos:
        return
    rest, j = pos[pos.index("setvcp") + 1:], 0
    while j < len(rest):
        code = rest[j].lower()
        code = code[2:] if code.startswith("0x") else code[1:] if code.startswith("x") else code[:-1] if code.endswith("h") else code
        try:
            ok = int(code, 16) in DDC_WRITABLE
        except ValueError:
            ok = False
        if not ok:
            block(f"ddcutil setvcp {rest[j]}: por DDC/CI solo se escriben brillo (10) y contraste (12); entrada, apagado, "
                  "reset de fábrica, etc. los cambia Ayoub")
        j += 1
        if j < len(rest) and rest[j] in ("+", "-"):
            j += 1
        j += 1


def r_restic(c0, a, nonopt, joined):
    # deleting snapshots/keys: Claude Code may only do it on throwaway repos in /tmp (Hikae's service applies the real
    # retention policy by itself)
    sub = set(nonopt)
    destructive = bool(sub & {"forget", "prune"}) or ("--forget" in a and bool(sub & {"rewrite", "repair"})) or \
        ("key" in sub and bool(sub & {"remove", "rm", "delete"}))
    if not destructive or {"--dry-run", "-n", "--help", "-h"} & set(a):
        return
    repo = ""
    for k, x in enumerate(a):
        if x in ("-r", "--repo") and k + 1 < len(a):
            repo = a[k + 1]
        elif x.startswith("--repo="):
            repo = x.split("=", 1)[1]
    if not (repo.startswith("/") and posixpath.normpath(repo).startswith("/tmp/")):
        block("borrar copias de seguridad o claves con restic (forget/prune/--forget/key remove): solo en repositorios de "
              "prueba en /tmp; la retención real la aplica el servicio de Hikae")



RULES = {"rm": r_rm, "cp": r_copy, "install": r_copy, "rsync": r_copy, "ln": r_copy,
         **{k: r_write_all for k in ("mv", "tee", "sed", "perl", "truncate", "touch", "chmod", "chown", "chgrp", "chattr",
                                     "unlink", "rmdir", "shred", "mkdir", "patch", "setfacl")},
         "dd": r_dd, "curl": r_download, "wget": r_download,
         **{k: r_disk for k in ("mke2fs", "mkswap", "wipefs", "sgdisk", "blkdiscard", "mkdosfs", "mkntfs", "zpool")},
         **{k: r_part for k in ("fdisk", "sfdisk", "gdisk", "cfdisk", "parted")}, "cryptsetup": r_crypt,
         **{k: r_power for k in ("reboot", "poweroff", "halt", "shutdown", "kexec", "telinit")}, "init": r_init,
         "systemctl": r_systemctl, "loginctl": r_loginctl, "niri": r_niri, "pkill": r_pkill, "killall": r_pkill, "kill": r_kill,
         "snapper": r_snapper, "btrfs": r_btrfs, **{k: r_pkg for k in ("pacman", "paru", "yay", "pamac")},
         "mkinitcpio": r_mkinitcpio,
         **{k: r_boot for k in ("dracut", "dracut-rebuild", "update-initramfs", "kernel-install", "grub-install", "grub-mkconfig",
                                "update-grub", "limine-update", "limine-mkinitcpio", "limine-entry-tool", "limine-snapper-sync",
                                "limine-install", "limine-scan")},
         "limine": r_limine, "efibootmgr": r_efi, "bootctl": r_bootctl, "sbctl": r_sb, "mokutil": r_sb,
         "fwupdmgr": r_fw, "fwupdtool": r_fw, "plymouth-set-default-theme": r_plymouth, "visudo": r_visudo,
         "usermod": r_usermod, "gpasswd": r_usermod, "docker": r_container, "podman": r_container, "git": r_git,
         "ddcutil": r_ddc, "restic": r_restic}

WHOLE = [
    (re.compile(r"(bash|sh|zsh|dash|fish|source|\.)\s*<\(\s*(curl|wget)"), "ejecutar un script descargado de internet"),
    (re.compile(r"(curl|wget)[^|;&]*\|\s*((sudo|doas|run0)\s+(-[a-zA-Z]+\s+)*)?(bash|sh|zsh|dash|fish|python3?|perl)(\s|$)"),
     "ejecutar un script remoto con tubería a la shell"),
    (re.compile(r"(bash|sh|zsh|dash|eval)(\s+-[a-z]+)*\s+[\"']?\$\(\s*(curl|wget)"), "ejecutar un script descargado de internet"),
    (re.compile(r"login1.*\b(PowerOff|Reboot|Halt|Suspend|Hibernate|HybridSleep|SuspendThenHibernate|KExec|TerminateSession|"
                r"KillSession|TerminateUser|KillUser)\b"), "apagar, reiniciar, suspender o cerrar la sesión por D-Bus (logind)"),
    (re.compile(r"(kill|pkill)[^;|&]*\$\(\s*(pidof|pgrep)[^)]*niri"), "matar niri mata la sesión (y esta sesión de Claude Code)"),
]


def judge(cmd):
    for rx, why in WHOLE:
        if rx.search(cmd):
            block(why)
    pending.clear()
    pending.append(cmd)
    seen = 0
    while pending and seen < 200:
        src = pending.pop(0)
        seen += 1
        for words, redirs in segments(src):
            check(words, redirs)


def main():
    raw = sys.stdin.read()
    try:
        cmd = json.loads(raw).get("tool_input", {}).get("command", "")
    except (ValueError, AttributeError):
        cmd = raw
    if not cmd:
        return 0
    try:
        judge(cmd)
    except Blocked as e:
        sys.stderr.write(MSG.format(e))
        return 2
    return 0


if __name__ == "__main__":
    sys.exit(main())
