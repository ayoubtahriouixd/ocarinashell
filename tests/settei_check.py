#!/usr/bin/env python3
"""Settei · persistence + live checklist (fase 07). For each setting: write a test value through the same
Settings.set the controls use (IPC `settings set`), check that it is applied live (derived values over IPC or the
generated niri include), restart the shell, check the value survived, then restore the original. Prints a table.
Visible for ~10 s (gaps, ring, clock seconds): run it with Ayoub's ok. Python stdlib only.
"""
import json
import os
import subprocess
import sys
import time
from pathlib import Path

STATE = Path(os.environ.get("XDG_STATE_HOME") or Path.home() / ".local/state") / "ocarinashell"
OVR = STATE / "niri/overrides.kdl"


def ipc(*a):
    r = subprocess.run(["qs", "-c", "ocarina", "ipc", "call", *a], capture_output=True, text=True, timeout=5)
    return r.stdout.strip()


def get(path):
    return json.loads(ipc("settings", "get", path) or "null")


def live():
    return json.loads(ipc("settings", "live") or "{}")


def ovr():
    return OVR.read_text(encoding="utf-8") if OVR.exists() else ""


# (path, test value, live check: function → bool, what it shows)
CASES = [
    ("windows.gaps", 16, lambda: "gaps 16" in ovr(), "overrides.kdl: gaps 16"),
    ("windows.focusRingWidth", 3, lambda: "width 3" in ovr(), "overrides.kdl: focus-ring width 3"),
    ("input.repeatRate", 41, lambda: "repeat-rate 41" in ovr(), "overrides.kdl: repeat-rate 41"),
    ("input.touchpad.speed", 0.3, lambda: "accel-speed 0.30" in ovr(), "overrides.kdl: touchpad accel 0.30"),
    ("input.layouts", ["es", "us"], lambda: 'layout "es,us"' in ovr() and "grp:alt_shift_toggle" in ovr(), "xkb es,us + Alt+Mayús"),
    ("appearance.animSpeed", 1.25, lambda: abs(live()["motionScale"] - 0.8) < 1e-3 and "slowdown 0.800" in ovr(), "Motion.scale 0,8 · niri slowdown 0,8"),
    ("appearance.radius", 1.2, lambda: abs(live()["radiusPanel"] - 26.4) < 1e-3, "Theme.radius.panel 26,4"),
    ("appearance.fontScale", 1.1, lambda: abs(live()["fontScale"] - 1.1) < 1e-6, "Theme.font.scale 1,1"),
    ("bar.showSeconds", True, lambda: live()["clock"].count(":") == 2, "reloj con segundos"),
    ("notifications.timeout", 9, lambda: live()["timeoutMs"] == 9000, "avisos 9 s"),
    ("power.lowBattery", 25, lambda: get("power.lowBattery") == 25, "umbral guardado"),
    ("display.brightness.timeCurve", True, lambda: live()["curve"] is True, "curva día/noche activa"),
    ("island.wheelVolume", False, lambda: get("island.wheelVolume") is False, "rueda sin volumen"),
    ("lock.showMedia", False, lambda: get("lock.showMedia") is False, "bloqueo sin reproductor"),
    ("wallpaper.favorites", ["/tmp/x.jpg"], lambda: get("wallpaper.favorites") == ["/tmp/x.jpg"], "favoritos"),
]


def main():
    orig = {p: get(p) for p, *_ in CASES}
    rows = []
    try:
        for p, v, _, _ in CASES:
            ipc("settings", "set", p, " " + json.dumps(v))   # leading space: qs ipc would parse a bare [..]
        time.sleep(1.5)                      # NiriConf debounce + niri reload
        live_ok = {p: bool(chk()) for p, _, chk, _ in CASES}
        subprocess.run(["systemctl", "--user", "restart", "ocarinashell"], check=True)
        for _ in range(40):
            time.sleep(0.25)
            if ipc("shell", "version"):
                break
        time.sleep(1)
        for p, v, _, what in CASES:
            rows.append((p, what, live_ok[p], get(p) == v))
    finally:
        for p, v in orig.items():
            ipc("settings", "set", p, " " + json.dumps(v))   # leading space: qs ipc would parse a bare [..]
    time.sleep(1.2)
    restored = all(get(p) == v for p, v in orig.items())
    print(f"{'ajuste':34} {'en vivo':8} {'tras reiniciar':15} comprobación")
    for p, what, a, b in rows:
        print(f"{p:34} {'✔' if a else '✘':8} {'✔' if b else '✘':15} {what}")
    print(f"valores originales restaurados: {'✔' if restored else '✘'} · niri: {live().get('overridesError') or 'sin errores'}")
    return 0 if all(a and b for _, _, a, b in rows) and restored else 1


if __name__ == "__main__":
    sys.exit(main())
