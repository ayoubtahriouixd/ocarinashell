"""守 Mamori — verification after applying (docs/06 capa 5): the smoke tests and 滑 Nameraka's self-test.

Active tests (they restart the shell and open the test lock) only when the batch touched what the shell runs on and
the session is NOT locked: restarting the shell under a real lock would drop the lock surface. Locked → passive tests
now and the restart is left for the next time Ayoub is away with the session unlocked (status.restartPending).
"""
import re
from pathlib import Path

from . import common as c
from . import conditions

NAMERAKA = Path.home() / ".local/libexec/ocarinashell/nameraka"
NAMERAKA_RE = r"^(lsfg-vk.*|mesa|vulkan-radeon|vulkan-icd-loader|pipewire.*|niri)$"


def locked():
    sh = conditions.shell_state()
    return bool(sh and sh.get("locked"))


def smoke(active):
    """→ (ok, [failed check messages])."""
    f = c.fake().get("smoke")
    if f is not None:
        return f.get("ok", True), f.get("fails", [])
    if c.DRY:
        c.say(f"[dry-run] ocarina doctor {'--post-update' if active else '--smoke'} --quiet")
        return True, []
    mode = "--post-update" if active else "--smoke"
    r = c.run([str(c.BIN / "ocarina"), "doctor", mode, "--quiet"], timeout=300)
    rep = c.load_json(c.STATE_ROOT / "smoke.json", {}) or {}
    fails = [x.get("msg", "") for x in rep.get("checks", []) if x.get("level") == "fail"]
    return r.returncode == 0, fails


def after_update(names):
    """Smoke tests for a batch → (ok, fails, active_done)."""
    want_active = any(re.match(c.SHELL_BASE_RE, n) for n in names)
    active = want_active and not locked()
    ok, fails = smoke(active)
    if want_active and not active:
        c.update_status(restartPending=True)
        c.say("sesión bloqueada: reinicio de la shell y pruebas activas aplazados hasta que no estés")
    return ok, fails, active


def pending_restart():
    """The shell restart left for later (session was locked): do it now if the session is unlocked and idle."""
    st = c.status()
    if not st.get("restartPending") or locked():
        return None
    ok, fails = smoke(True)
    c.update_status(restartPending=False)
    c.history("update", "Shell reiniciada tras la actualización", "pruebas activas " + ("✓" if ok else "✗"),
              "ok" if ok else "fail")
    return ok, fails


def nameraka(names):
    """After lsfg-vk, Mesa, PipeWire or niri changed: self-test; a link failure → rebuild once. 13–15 are «not
    available for a known reason» (no GPU support, no DLL…), not failures."""
    if not NAMERAKA.exists() or not any(re.match(NAMERAKA_RE, n) for n in names):
        return True
    if c.DRY:
        c.say("[dry-run] nameraka self-test")
        return True
    rc = c.run([str(NAMERAKA), "self-test"], timeout=120).returncode
    if rc in (0, 13, 14, 15):
        return True
    build = c.CACHE / "build/nameraka"
    if (build / "build.ninja").exists():
        c.run(["meson", "setup", "--reconfigure", str(build), str(c.REPO / "native/nameraka")], timeout=300)
        if c.run(["ninja", "-C", str(build)], timeout=900).returncode == 0:
            c.run(["install", "-D", "-m", "0755", str(build / "nameraka"), str(NAMERAKA)], timeout=30)
            rc = c.run([str(NAMERAKA), "self-test"], timeout=120).returncode
    ok = rc in (0, 13, 14, 15)
    c.history("health", "滑 Nameraka recompilado" if ok else "滑 Nameraka no disponible tras actualizar",
              f"self-test {'✓' if ok else '✗ (código ' + str(rc) + ')'}", "ok" if ok else "attention")
    return ok
