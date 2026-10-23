"""守 Mamori — shared plumbing: paths, settings, state files, the journal, the root helper, notifications.

Everything Mamori writes lives in ~/.local/state/ocarinashell/mamori/ (OCARINA_MAMORI_STATE moves it, for tests):
  status.json    what the UI shows and where an interrupted cycle resumes (one entry per finished step)
  plan.json      the decision about the pending batch, with its reasons and what Snake said
  holds.json     packages held back (by Ayoub or by Mamori), with a date and a reason
  history.jsonl  one line per event (the 守 page's timeline and the weekly report read it)
  inventory.json what was pending last time, when each version was first seen, the news already handled
  periodic.json  when each periodic job last ran; limits.json  how often each repair failed today
Root only through /usr/local/libexec/ocarina-maint (sudoers: NOPASSWD for that file alone).
"""
import fcntl
import hashlib
import json
import os
import re
import shutil
import subprocess
import sys
import syslog
import time
from datetime import datetime
from pathlib import Path

HOME = Path.home()
REPO = Path(__file__).resolve().parents[2]
BIN = REPO / "bin"
CONFIG = Path(os.environ.get("XDG_CONFIG_HOME", HOME / ".config"))
STATE_ROOT = Path(os.environ.get("XDG_STATE_HOME", HOME / ".local/state")) / "ocarinashell"
STATE = Path(os.environ.get("OCARINA_MAMORI_STATE") or STATE_ROOT / "mamori")
CACHE = Path(os.environ.get("XDG_CACHE_HOME", HOME / ".cache")) / "ocarinashell"
DATA = Path(os.environ.get("XDG_DATA_HOME", HOME / ".local/share")) / "ocarinashell"
RUNTIME = Path(os.environ.get("XDG_RUNTIME_DIR", f"/run/user/{os.getuid()}")) / "ocarinashell"
MAINT = "/usr/local/libexec/ocarina-maint"

DEFAULTS = {
    "enabled": True,            # the autopilot (Ajustes › 守 «Piloto automático»)
    "ai": "snake",              # snake | claude | both | off (D-007, D-008)
    "batteryMin": 0,            # 0 = only on AC; 50–100 = also on battery at or above that %
    "maturationDays": 3,        # critical packages / major versions, with an AI reviewing
    "maturationDaysNoAi": 7,    # the same without any AI (deterministic mode)
    "aur": True,                # update AUR packages (reviewed PKGBUILD, built by root in a sandbox)
    "firmware": "approve",      # approve (BIOS/EC: one touch + polkit, never through the helper) | off
    "nightlyReboot": False,     # reboot at night when an update needs it (locked, on AC)
    "autoImprove": False,       # let the AI apply improvements, not only compatibility fixes
    "notify": True,             # notifications (only when there is something to see)
    "claudeBudget": {"turns": 25, "minutes": 15},
}
DAY = 86400
# docs/06 capa 6 › Clasificación (the same list as services/Updates.qml and bin/ocarina-update)
CRITICAL_RE = (r"^(linux.*|mesa|lib32-mesa|vulkan-radeon|niri|quickshell|qt6-.*|systemd|systemd-libs|glibc|pipewire.*"
               r"|wireplumber|linux-firmware.*|limine|plymouth|power-profiles-daemon|scx-.*|freerdp|docker|podman)$")
REBOOT_RE = r"^(linux(-[a-z0-9]+)*|systemd|systemd-libs|glibc|mesa|linux-firmware.*|amd-ucode)$"
# what the running shell is built on: a change here deserves a shell restart + the active smoke tests
SHELL_BASE_RE = (r"^(qt6-.*|quickshell|mesa|vulkan-.*|libdrm|wayland|wayland-protocols|libxkbcommon|niri|pipewire.*"
                 r"|wireplumber|glib2|glibc|systemd|systemd-libs|pam|xdg-desktop-portal.*|fontconfig|freetype2"
                 r"|harfbuzz|icu)$")

DRY = False                     # --dry-run: nothing that changes the system runs (bin/ocarina-mamori sets it)
INTERACTIVE = False             # `ocarina mamori run --interactive`: Ayoub is watching in a terminal


def sim():
    """A simulation (OCARINA_MAMORI_FAKE set): no notifications on screen, no commits, no periodic jobs."""
    return bool(os.environ.get("OCARINA_MAMORI_FAKE"))


def fake():
    """Simulations (docs/evidencias/fase-16): OCARINA_MAMORI_FAKE=<file.json> replaces what the system says."""
    p = os.environ.get("OCARINA_MAMORI_FAKE")
    if not p:
        return {}
    try:
        return json.loads(Path(p).read_text())
    except (OSError, ValueError):
        return {}


# ── logging and output ──────────────────────────────────────────────────────────────────────
def jlog(msg, prio=syslog.LOG_INFO):
    syslog.openlog("ocarina-mamori", 0, syslog.LOG_USER)
    syslog.syslog(prio, msg[:4000])


def say(msg):
    """A line for the journal and, in interactive runs, for the terminal."""
    jlog(msg)
    if INTERACTIVE or sys.stdout.isatty():
        print(f"守 {msg}", flush=True)


# ── small helpers ───────────────────────────────────────────────────────────────────────────
def have(cmd):
    return shutil.which(cmd) is not None


def run(cmd, timeout=60, input=None, env=None, cwd=None):
    try:
        return subprocess.run(cmd, capture_output=True, text=True, timeout=timeout, input=input,
                              env=env, cwd=cwd)
    except (OSError, subprocess.TimeoutExpired) as e:
        return subprocess.CompletedProcess(cmd, 124 if isinstance(e, subprocess.TimeoutExpired) else 127, "", str(e))


def now():
    return int(time.time())


def stamp(ts=None):
    return datetime.fromtimestamp(ts or now()).strftime("%Y-%m-%d %H:%M")


def load_json(path, fallback=None):
    try:
        return json.loads(Path(path).read_text(encoding="utf-8"))
    except (OSError, ValueError):
        return fallback


def save_json(path, obj):
    """Atomic: a cycle cut by a power loss never leaves half a file."""
    path = Path(path)
    path.parent.mkdir(parents=True, exist_ok=True)
    tmp = path.with_name(f"{path.name}.{os.getpid()}.tmp")      # two writers never share a temporary
    tmp.write_text(json.dumps(obj, ensure_ascii=False, indent=1) + "\n", encoding="utf-8")
    os.replace(tmp, path)


def settings():
    s = load_json(CONFIG / "ocarinashell/settings.json", {}) or {}
    user = s.get("mamori", {}) if isinstance(s, dict) else {}
    out = json.loads(json.dumps(DEFAULTS))
    if isinstance(user, dict):
        for k, v in user.items():
            if k in DEFAULTS and type(v) is type(DEFAULTS[k]):
                out[k] = v
    if out["ai"] not in ("snake", "claude", "both", "off"):
        out["ai"] = "snake"
    out["batteryMin"] = max(0, min(100, out["batteryMin"]))
    out["maturationDays"] = max(0, min(30, out["maturationDays"]))
    out["maturationDaysNoAi"] = max(out["maturationDays"], min(30, out["maturationDaysNoAi"]))
    out["snakeEnabled"] = bool((s.get("snake") or {}).get("enabled", True)) if isinstance(s, dict) else True
    return out


# ── state ───────────────────────────────────────────────────────────────────────────────────
def status():
    return load_json(STATE / "status.json", {}) or {}


def next_timer():
    """When ocarina-mamori.timer fires next (epoch seconds), 0 if unknown."""
    r = run(["systemctl", "--user", "show", "ocarina-mamori.timer", "-p", "NextElapseUSecRealtime", "--value"],
            timeout=10)
    try:
        import time
        return int(time.mktime(time.strptime(r.stdout.strip()[4:23], "%Y-%m-%d %H:%M:%S")))
    except (ValueError, IndexError, AttributeError):
        return 0


def update_status(**kw):
    st = status()
    st.update(kw)
    st["updated"] = now()
    # a cycle that stops early (deferred, waiting for an approval) left no «next run»: the timer knows it
    if st.get("state") != "running" and (st.get("nextRun") or 0) < now():
        st["nextRun"] = next_timer()
    if not DRY:
        save_json(STATE / "status.json", st)
    return st


def history(kind, title, detail="", result="ok", **extra):
    """kind: update · hold · review · repair · firmware · rollback · adapt · health · periodic · info.
    result: ok · hold · fail · info · attention (drives the icon and colour of the 守 timeline)."""
    ev = {"at": now(), "kind": kind, "title": title, "detail": detail, "result": result}
    ev.update(extra)
    jlog(f"[{kind}/{result}] {title}{' · ' + detail if detail else ''}")
    if INTERACTIVE:
        print(f"守 {title}{' · ' + detail if detail else ''}", flush=True)
    if DRY:
        return ev
    STATE.mkdir(parents=True, exist_ok=True)
    with open(STATE / "history.jsonl", "a", encoding="utf-8") as f:
        f.write(json.dumps(ev, ensure_ascii=False) + "\n")
    return ev


def read_history(limit=200):
    try:
        lines = (STATE / "history.jsonl").read_text(encoding="utf-8").splitlines()[-limit:]
    except OSError:
        return []
    out = []
    for line in lines:
        try:
            out.append(json.loads(line))
        except ValueError:
            continue
    return out


def holds():
    h = load_json(STATE / "holds.json", {}) or {}
    t = now()
    return {k: v for k, v in h.items() if isinstance(v, dict) and v.get("until", 0) > t}


def set_hold(pkg, days, reason, kind="auto", version=""):
    h = holds()
    h[pkg] = {"until": now() + int(days * DAY), "reason": reason, "kind": kind, "version": version, "since": now()}
    if not DRY:
        save_json(STATE / "holds.json", h)
    return h[pkg]


def clear_hold(pkg):
    h = holds()
    gone = h.pop(pkg, None)
    if not DRY:
        save_json(STATE / "holds.json", h)
    return gone


class CycleLock:
    """One cycle at a time (timer, shell, Ayoub): a non-blocking flock in the runtime dir."""

    def __init__(self):
        RUNTIME.mkdir(mode=0o700, parents=True, exist_ok=True)
        self.f = open(RUNTIME / "mamori.lock", "w")

    def acquire(self):
        try:
            fcntl.flock(self.f, fcntl.LOCK_EX | fcntl.LOCK_NB)
            return True
        except OSError:
            return False


# ── root helper ─────────────────────────────────────────────────────────────────────────────
def maint(*args, timeout=3600, check_only=False):
    """sudo -n ocarina-maint <op> …: (returncode, stdout, stderr). Dry runs only print, except read-only ops."""
    readonly = args and args[0] in ("health", "last-pair", "boot-check", "help")
    if (DRY or check_only or fake().get("maintDry")) and not readonly:
        say(f"[dry-run] ocarina-maint {' '.join(args)}")
        return 0, "", ""
    if not Path(MAINT).exists():
        return 127, "", f"falta {MAINT} (scripts/root/fase-16.sh)"
    if INTERACTIVE and args[0] in ("upgrade", "aur-build", "download"):
        # Ayoub is watching: pacman's output goes straight to the terminal
        r = subprocess.run(["sudo", "-n", MAINT, *args], timeout=timeout)
        return r.returncode, "", ""
    r = run(["sudo", "-n", MAINT, *args], timeout=timeout)
    return r.returncode, r.stdout, r.stderr


def maint_available():
    if not Path(MAINT).exists():
        return False
    return run(["sudo", "-n", MAINT, "help"], timeout=10).returncode == 0


# ── the shell and notifications ─────────────────────────────────────────────────────────────
def shell_ipc(target, *args, timeout=2):
    if not have("qs"):
        return None
    r = run(["qs", "-c", "ocarina", "ipc", "call", target, *args], timeout=timeout)
    return r.stdout.strip() if r.returncode == 0 else None


def ping_shell():
    """The 守 page rereads the state now (inotify loses atomically replaced files now and then)."""
    if not DRY and not sim():
        shell_ipc("mamori", "refresh", timeout=2)


def notify(title, body="", urgency="normal", actions=None, tag="", payload=None):
    """Grouped under the 守 hanko. With actions, a detached `ocarina-mamori answer <tag>` waits for the click so the
    cycle never blocks on Ayoub (actions: [(id, label)]; payload: what the answer needs, kept in asks.json)."""
    if not settings()["notify"] and urgency != "critical":
        return
    if DRY or sim():
        say(f"[dry-run] notificación: {title} — {body}")
        return
    if not have("notify-send"):
        return
    base = ["notify-send", "-a", "守 Mamori", "-u", urgency, "-i", "dialog-information",
            "-h", "string:x-ocarina-kanji:守", "-h", "string:x-ocarina-mamori:" + (tag or "info")]
    if not actions:
        run(base + [title, body], timeout=5)
        return
    asks = load_json(STATE / "asks.json", {}) or {}
    asks[tag] = dict(payload or {}, at=now(), title=title)
    save_json(STATE / "asks.json", asks)
    argv = [str(BIN / "ocarina-mamori"), "answer", tag, "--", *base]
    for aid, label in actions:
        argv += ["-A", f"{aid}={label}"]
    argv += [title, body]
    unit = f"ocarina-mamori-ask-{re.sub(r'[^A-Za-z0-9_-]', '', tag) or 'x'}-{now()}"
    run(["systemd-run", "--user", "--quiet", "--collect", f"--unit={unit}", *argv], timeout=10)


def on_ac():
    f = fake().get("conditions", {})
    if "ac" in f:
        return bool(f["ac"])
    for ps in Path("/sys/class/power_supply").glob("*"):
        try:
            if (ps / "type").read_text().strip() == "Mains":
                return (ps / "online").read_text().strip() == "1"
        except OSError:
            continue
    return True       # a desktop without a battery


def battery_percent():
    f = fake().get("conditions", {})
    if "battery" in f:
        return int(f["battery"])
    for ps in Path("/sys/class/power_supply").glob("BAT*"):
        try:
            return int((ps / "capacity").read_text().strip())
        except (OSError, ValueError):
            continue
    return 100


def mode_active(mode):
    f = fake().get("conditions", {})
    if mode in f:
        return bool(f[mode])
    d = load_json(STATE_ROOT / f"{mode}-prev.json", {}) or {}
    return bool(d.get("active"))


def short_id(text):
    return hashlib.sha1(text.encode()).hexdigest()[:10]


def git(*args, timeout=60):
    return run(["git", "-C", str(REPO), *args], timeout=timeout)
