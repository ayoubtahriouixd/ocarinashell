#!/usr/bin/env python3
"""Fase 06 · 復元 Fukugen acceptance test (docs/historia/fases/fase-06.md).

Opens 6 windows of its own (4 Ghostty in temporary folders + 2 Nautilus) on workspaces 2-4 with two widths,
saves the session, closes ONLY those windows (by id), restarts the shell, runs `ocarina session restore` and checks
that every window came back to its workspace and width. Cleans up its windows at the end and refocuses the
window that had the focus. Never touches other windows. Usage: python3 tests/fukugen_test.py [--keep]
"""
import json
import os
import subprocess
import sys
import tempfile
import time

KEEP = "--keep" in sys.argv


def niri(*args):
    return subprocess.run(["niri", "msg", *args], check=True, capture_output=True, text=True).stdout


def windows():
    return {w["id"]: w for w in json.loads(niri("--json", "windows"))}


def workspaces():
    return {w["id"]: w for w in json.loads(niri("--json", "workspaces"))}


def wait_new(before, app, timeout=15):
    t = time.time()
    while time.time() - t < timeout:
        for wid, w in windows().items():
            if wid not in before and w["app_id"] == app:
                return wid
        time.sleep(0.2)
    raise SystemExit(f"no apareció {app}")


def ipc(*args):
    return subprocess.run(["qs", "-c", "ocarina", "ipc", "call", *args], capture_output=True, text=True).stdout.strip()


focused = next((w["id"] for w in windows().values() if w["is_focused"]), None)
tmp = tempfile.mkdtemp(prefix="fukugen-", dir=os.environ.get("XDG_RUNTIME_DIR", "/tmp"))
plan = [  # (app, launcher, workspace idx, width px)
    ("com.mitchellh.ghostty", ["ghostty", f"--working-directory={tmp}/uno"], 2, 600),
    ("com.mitchellh.ghostty", ["ghostty", f"--working-directory={tmp}/dos"], 2, 1000),
    ("org.gnome.Nautilus", ["nautilus", "--new-window", tmp], 3, 1000),
    ("com.mitchellh.ghostty", ["ghostty", f"--working-directory={tmp}/tres"], 3, 600),
    ("org.gnome.Nautilus", ["nautilus", "--new-window", f"{tmp}/uno"], 4, 600),
    ("com.mitchellh.ghostty", ["ghostty", f"--working-directory={tmp}/cuatro"], 4, 1000),
]
for d in ("uno", "dos", "tres", "cuatro"):
    os.makedirs(f"{tmp}/{d}")

mine = []
try:
    for app, cmd, ws, width in plan:
        before = set(windows())
        niri("action", "spawn", "--", *cmd)
        wid = wait_new(before, app)
        niri("action", "move-window-to-workspace", "--window-id", str(wid), "--focus", "false", str(ws))
        niri("action", "set-window-width", "--id", str(wid), str(width))
        mine.append(wid)
        time.sleep(0.6)
    time.sleep(1.5)  # fish sets the title
    wss = workspaces()
    expected = []
    for wid in mine:
        w = windows()[wid]
        expected.append((w["app_id"], wss[w["workspace_id"]]["idx"], w["layout"]["window_size"][0], w["title"]))
    print("antes:", *expected, sep="\n  ")

    print("guardar:", ipc("session", "save"))
    time.sleep(1.5)
    state = os.path.join(os.environ.get("XDG_STATE_HOME", os.path.expanduser("~/.local/state")), "ocarinashell/session.json")
    saved = [(w["appId"], w["wsIdx"], w["width"]) for w in json.load(open(state))["windows"]]
    others = list(saved)
    for a, i, wd, _ in expected:
        if (a, i, wd) in others:
            others.remove((a, i, wd))
    print("otras ventanas de la sesión (también se restauran):", others)
    for wid in mine:
        niri("action", "close-window", "--id", str(wid))
    mine = []
    time.sleep(1)

    subprocess.run(["systemctl", "--user", "restart", "ocarinashell"], check=True)
    time.sleep(3)
    before = set(windows())
    print("restaurar:", ipc("session", "restore"))
    t = time.time()
    while time.time() - t < 40:
        st = json.loads(ipc("session", "status") or "{}")
        if not st.get("restoring"):
            break
        time.sleep(0.5)
    time.sleep(1)
    print("estado:", ipc("session", "status"))
    wss = workspaces()
    got = []
    for wid, w in windows().items():
        if wid not in before:
            mine.append(wid)
            got.append((w["app_id"], wss[w["workspace_id"]]["idx"], w["layout"]["window_size"][0], w["title"]))
    print("después:", *got, sep="\n  ")

    want = sorted((a, i, wd) for a, i, wd, _ in expected)
    have = [(a, i, wd) for a, i, wd, _ in got]
    for o in others:
        if o in have:
            have.remove(o)
    have = sorted(have)
    ok = want == have
    print("RESULTADO:", "OK — cada ventana en su espacio y con su ancho" if ok else f"FALLO\n  esperado {want}\n  obtenido {have}")
finally:
    if not KEEP:
        for wid in mine:
            subprocess.run(["niri", "msg", "action", "close-window", "--id", str(wid)], capture_output=True)
    if focused is not None:
        subprocess.run(["niri", "msg", "action", "focus-window", "--id", str(focused)], capture_output=True)
    for d in ("uno", "dos", "tres", "cuatro", ""):
        try:
            os.rmdir(os.path.join(tmp, d))
        except OSError:
            pass
sys.exit(0 if ok else 1)
