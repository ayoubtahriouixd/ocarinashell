"""守 Mamori — adapting OcarinaShell's own code when an update breaks it (docs/06 capa 6 › Ciclo 6, fase 16 §8).

Snake diagnoses the failed smoke tests with the journal; if the cause is our code, it proposes a minimal diff. The
orchestrator (never Snake) applies it on the branch `mamori/compat-<date>`, commits, runs the active smoke tests and
only then fast-forwards main with the `compat: …` commit. At most 3 attempts; a failed attempt is reverted on the
branch (its history stays there for Ayoub). Only compatibility fixes inside shell/, config/, templates/, bin/ and
snake/ — anything else is refused. Never touches a working tree with Ayoub's uncommitted changes.
"""
import re
from datetime import datetime

from . import ai
from . import common as c
from . import verify

ALLOWED = ("shell/", "config/", "templates/", "bin/", "snake/")
# how Quickshell names our files in errors: «qs:@/qs/modules/x/Y.qml:17:9», «@modules/x/Y.qml[280:9]», or a plain
# path under the repo or ~/.config/quickshell/ocarina
QML_REF = re.compile(r"(?:qs:@/qs/|@|file://)?(?:" + re.escape(str(c.HOME)) + r"/(?:ocarinashell/shell/|\.config/quickshell/ocarina/))?"
                     r"((?:modules|services|components|config|ipc|safe)/[\w./-]+\.(?:qml|js))[:\[](\d+)")


def base_branch():
    """main; a simulation may name its own test branch (docs/evidencias/fase-16, simulacro a)."""
    return c.fake().get("adaptBase", "main") if c.sim() else "main"


def repo_clean():
    if c.git("rev-parse", "--abbrev-ref", "HEAD").stdout.strip() != base_branch():
        return False, f"el repo no está en {base_branch()}"
    if c.git("status", "--porcelain", "--untracked-files=no").stdout.strip():
        return False, "el repo tiene cambios sin guardar (no los toco)"
    gitdir = c.REPO / ".git"
    if any((gitdir / x).exists() for x in ("MERGE_HEAD", "rebase-merge", "rebase-apply", "CHERRY_PICK_HEAD")):
        return False, "hay una fusión o un rebase a medias"
    return True, ""


def _context_files(text):
    out, seen = [], set()
    for m in QML_REF.finditer(text):
        rel = "shell/" + m.group(1)
        if rel in seen or not (c.REPO / rel).is_file():
            continue
        seen.add(rel)
        lines = (c.REPO / rel).read_text(encoding="utf-8", errors="replace").splitlines()
        ln = int(m.group(2))
        lo, hi = max(0, ln - 60), min(len(lines), ln + 60)
        # the file as it is (numbers would end up copied into the patch); the failing line marked at the end
        body = "\n".join(lines[i] + ("    ⟵ ERROR" if i + 1 == ln else "") for i in range(lo, hi))
        out.append(f"### {rel} (líneas {lo + 1}–{hi} de {len(lines)}; la del error lleva «⟵ ERROR»)\n```\n{body}\n```")
        if len(out) >= 3:
            break
    return out


def _diff_paths(diff):
    return re.findall(r"(?m)^\+\+\+ b/(\S+)", diff)


NUM_PREFIX = re.compile(r"^\s*\d{1,5}  ")


def _clean(x):
    """A hunk line as the model wrote it → as it should be: no copied line number, no «⟵ ERROR» marker."""
    return NUM_PREFIX.sub("", x, count=1).replace("    ⟵ ERROR", "").rstrip()


def _indent(line):
    return len(line) - len(line.lstrip(" "))


def apply_loose(diff):
    """Small models write hunks without line numbers («@@») and with shifted indentation. Each hunk is matched by
    content (indentation ignored, the match must be unique), its new lines re-indented to the file's. All or
    nothing: files are written only if every hunk matched. → (ok, why)."""
    files, cur = {}, None
    for line in diff.splitlines():
        if line.startswith("+++ b/"):
            cur = line[6:].strip()
            files.setdefault(cur, [])
        elif line.startswith("--- "):
            continue
        elif cur is not None:
            if line.startswith("@@"):
                files[cur].append([])
            elif files[cur] and (line[:1] in (" ", "-", "+") or line == ""):
                files[cur][-1].append(line)       # anything else (*** End Patch, ``` …) is not part of a hunk
    if not files:
        return False, "el parche no tiene ficheros"
    out = {}
    for path, hunks in files.items():
        f = c.REPO / path
        if not path.startswith(ALLOWED) or ".." in path or not f.is_file():
            return False, f"fichero no permitido o inexistente: {path}"
        text = out.get(path) or f.read_text(encoding="utf-8").split("\n")
        for h in hunks:
            old = [_clean(x[1:] if x[:1] in (" ", "-") else x) for x in h if not x.startswith("+")]
            new = [_clean(x[1:] if x[:1] in (" ", "+") else x) for x in h if not x.startswith("-")]
            while old and not old[-1].strip():
                old.pop()
            key = [x.strip() for x in old]
            if not any(key):
                return False, "un bloque sin líneas que buscar"
            hits = [i for i in range(len(text) - len(key) + 1)
                    if [t.strip() for t in text[i:i + len(key)]] == key]
            if len(hits) != 1:
                return False, f"{path}: el bloque aparece {len(hits)} veces"
            i = hits[0]
            first = next(j for j, x in enumerate(old) if x.strip())
            delta = _indent(text[i + first]) - _indent(old[first])
            fixed = [(" " * delta + x if delta > 0 else x[min(-delta, _indent(x)):]) if x.strip() else ""
                     for x in new]
            text[i:i + len(key)] = fixed
        out[path] = text
    for path, text in out.items():
        (c.REPO / path).write_text("\n".join(text), encoding="utf-8")
    return True, ""


def attempt_ok(diff):
    paths = _diff_paths(diff)
    if not paths:
        return False, "el parche no tiene ficheros"
    bad = [p for p in paths if not p.startswith(ALLOWED) or ".." in p]
    if bad:
        return False, "toca fuera de lo permitido: " + ", ".join(bad)
    r = c.run(["git", "-C", str(c.REPO), "apply", "--check", "-"], input=diff, timeout=30)
    if r.returncode != 0:
        return False, "no aplica: " + r.stderr.strip()[-200:]
    return True, ""


def adapt(fails, journal_text, packages):
    """→ (fixed: bool, detail). On success main has a new `compat:` commit and the smoke tests are green."""
    if not ai.available():
        return False, "sin IA: no puedo reescribir código (modo determinista)"
    ok, why = repo_clean()
    if not ok:
        return False, why
    ctx = (f"Tras actualizar: {', '.join(packages[:30])}\nPruebas de humo fallidas:\n- " + "\n- ".join(fails) +
           f"\n\nJournal de la shell:\n{journal_text[-8000:]}")
    d = ai.task("diagnose", ctx)
    if not d or d.get("suspicious"):
        return False, "Snake no encontró una causa fiable"
    # the journal pointing at one of our files outweighs Snake's guess about the cause (it may blame a package)
    files = _context_files(journal_text)
    if not files:
        return False, "el journal no señala ningún fichero de OcarinaShell"
    if d.get("category") not in ("shell-qml", "config", "compositor") and d.get("fix", {}).get("kind") != "patch":
        return False, f"no es un fallo de nuestro código ({d.get('category')}): {d.get('summary_es', '')[:200]}"
    branch = f"mamori/compat-{datetime.now():%Y%m%d-%H%M}"
    if c.DRY:
        c.say(f"[dry-run] Snake propondría un parche en {branch}")
        return False, "dry-run"
    if c.git("switch", "-c", branch).returncode != 0:
        return False, f"no pude crear la rama {branch}"
    notes = []
    try:
        for n in range(1, 4):
            errors = "\n".join(sorted({m.group(0) for m in re.finditer(r"[^\n]*\.qml:\d+(?::\d+)?:[^\n]*", journal_text)})[:8])
            prompt = (f"Errores exactos del journal (la causa está en NUESTRO fichero; corrígelo ahí):\n{errors}\n\n"
                      f"Diagnóstico de Snake: {d.get('cause', '')}\nPasos: {'; '.join(d['fix'].get('steps', []))}\n"
                      f"Fallos:\n- " + "\n- ".join(fails) + "\n\nFicheros (con número de línea):\n\n" +
                      "\n\n".join(files) + "\n\nJournal:\n" + journal_text[-4000:] +
                      ("\n\nIntentos anteriores fallidos:\n" + "\n".join(notes) if notes else "") +
                      "\n\nDevuelve un diff unificado (git) mínimo, solo de compatibilidad, con rutas a/ b/ "
                      "relativas al repo.")
            p = ai.task("propose-patch", prompt)
            if p and p.get("diff"):
                (c.STATE / "adapt").mkdir(parents=True, exist_ok=True)
                (c.STATE / "adapt" / f"{branch.split('/')[-1]}-{n}.diff").write_text(p["diff"], encoding="utf-8")
            if not p or p.get("suspicious") or not p.get("diff"):
                notes.append(f"{n}: sin parche")
                continue
            good, why = attempt_ok(p["diff"])
            if good:
                c.run(["git", "-C", str(c.REPO), "apply", "-"], input=p["diff"], timeout=30)
            else:
                good, why2 = apply_loose(p["diff"])
                if not good:
                    notes.append(f"{n}: {why} · por contenido: {why2}")
                    continue
            if not c.git("diff", "--name-only").stdout.strip():
                notes.append(f"{n}: el parche no cambia nada")
                continue
            why = (p.get("rationale") or d.get("cause", "adaptación")).replace("\n", " ").strip()
            why = why.split(". ")[0][:72].rsplit(" ", 1)[0] if len(why.split(". ")[0]) > 72 else why.split(". ")[0]
            msg = "compat: " + why.rstrip(".")
            c.git("commit", "-am", msg + "\n\n守 Mamori · Snake · intento " + str(n) + "\n" + "\n".join(fails[:5]))
            ok, new_fails = verify.smoke(True)
            if ok:
                c.git("switch", base_branch())
                if c.git("merge", "--ff-only", branch).returncode == 0:
                    c.git("branch", "-d", branch)
                    c.history("adapt", "Adaptado: " + msg[8:], f"Snake lo arregló en {n} intento(s); pruebas ✓",
                              "ok", branch=branch)
                    return True, msg
                return False, "no pude fusionar la rama"
            notes.append(f"{n}: pruebas aún fallan: {'; '.join(new_fails[:3])}")
            c.git("revert", "--no-edit", "HEAD")
        return False, "3 intentos sin éxito: " + " | ".join(notes)[:300]
    finally:
        if c.git("rev-parse", "--abbrev-ref", "HEAD").stdout.strip() != base_branch():
            c.git("switch", base_branch())
