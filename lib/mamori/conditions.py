"""守 Mamori — when it may act (docs/06 capa 6 › Cuándo actúa).

Two levels:
  background  checking, downloading, researching: autopilot on, not paused, power (AC, or battery ≥ batteryMin if
              Ayoub allows it), an unmetered network, no 鬼 Oni / GameMode / 忍 Shinobi, no call (a real microphone
              open), no recording or screencast, no idle inhibitor
  install     the same + Ayoub idle ≥ 10 min or the session locked (the shell says; without the shell, no)
`ocarina mamori run --interactive` skips the idle rule (Ayoub is the one asking) but never the power or network ones.
"""
import json

from . import common as c


def _f():
    return c.fake().get("conditions", {})


def network():
    """(ok, reason). Metered per NetworkManager: 1 yes, 3 guess-yes (a shared phone) count as metered."""
    f = _f()
    if "network" in f:
        return (True, "") if f["network"] == "ok" else (False, f["network"])
    if not c.have("nmcli"):
        return True, ""
    conn = c.run(["nmcli", "-t", "networking", "connectivity"], timeout=10).stdout.strip()
    if conn != "full":
        return False, "sin conexión a internet" if conn in ("none", "") else f"conexión limitada ({conn})"
    r = c.run(["busctl", "get-property", "org.freedesktop.NetworkManager", "/org/freedesktop/NetworkManager",
               "org.freedesktop.NetworkManager", "Metered"], timeout=5)
    try:
        metered = int(r.stdout.split()[1])
    except (IndexError, ValueError):
        metered = 0
    if metered in (1, 3):
        return False, "red con límite de datos"
    return True, ""


def microphone_in_use():
    f = _f()
    if "microphone" in f:
        return bool(f["microphone"])
    if not c.have("pw-dump"):
        return False
    r = c.run(["pw-dump"], timeout=10)
    try:
        objs = json.loads(r.stdout or "[]")
    except ValueError:
        return False
    for o in objs:
        info = o.get("info") or {}
        props = info.get("props") or {}
        # a real capture device running (the island's peak meter listens to the speakers' monitor, not to a mic)
        if props.get("media.class") == "Audio/Source" and info.get("state") == "running" \
                and not str(props.get("node.name", "")).endswith(".monitor"):
            return True
    return False


def recording():
    f = _f()
    if "recording" in f:
        return bool(f["recording"])
    r = c.run(["niri", "msg", "--json", "casts"], timeout=5)
    try:
        if r.returncode == 0 and json.loads(r.stdout or "[]"):
            return True
    except ValueError:
        pass
    return c.run(["pgrep", "-x", "gpu-screen-reco|wf-recorder|obs"], timeout=5).returncode == 0


def idle_inhibited():
    f = _f()
    if "inhibited" in f:
        return bool(f["inhibited"])
    r = c.run(["systemd-inhibit", "--list", "--no-pager", "--no-legend"], timeout=5)
    for line in r.stdout.splitlines():
        cols = line.split()
        # WHO UID USER PID COMM WHAT WHY… MODE: «idle» in WHAT with mode block
        if len(cols) >= 7 and "idle" in cols[5].split(":") and cols[-1] == "block":
            return True
    return False


def shell_state():
    """The shell knows what systemd does not: idle ≥ 10 min, locked, the 醒 «Despierto» switch."""
    f = _f()
    if "shell" in f:
        return f["shell"]
    out = c.shell_ipc("mamori", "conditions")
    try:
        return json.loads(out) if out else None
    except ValueError:
        return None


def check(level="install", interactive=False):
    """→ {"ok": bool, "reasons": [str], "level": level}. Reasons in Spanish, the first one is shown in the UI."""
    s = c.settings()
    st = c.status()
    reasons = []
    if not s["enabled"] and not interactive:
        reasons.append("piloto automático apagado")
    if st.get("pausedUntil", 0) > c.now():
        reasons.append(f"en pausa hasta el {c.stamp(st['pausedUntil'])}")
    if not c.on_ac():
        bmin = s["batteryMin"]
        pct = c.battery_percent()
        if bmin <= 0:
            reasons.append("con batería (espera al cargador)")
        elif pct < bmin:
            reasons.append(f"batería al {pct} % (mínimo {bmin} %)")
    ok, why = network()
    if not ok:
        reasons.append(why)
    if c.mode_active("oni"):
        reasons.append("鬼 Oni activo")
    if c.mode_active("shinobi"):
        reasons.append("忍 Shinobi activo")
    gm = _f()["gamemode"] if "gamemode" in _f() else \
        c.have("gamemoded") and "is active" in c.run(["gamemoded", "-s"], timeout=5).stdout
    if gm:
        reasons.append("GameMode activo (un juego)")
    if microphone_in_use():
        reasons.append("micrófono en uso (¿una llamada?)")
    if recording():
        reasons.append("grabando o compartiendo pantalla")
    if idle_inhibited():
        reasons.append("una aplicación impide la inactividad")
    if level == "install" and not interactive:
        sh = shell_state()
        if sh is None:
            reasons.append("la shell no responde: no sé si estás usando el equipo")
        else:
            if sh.get("inhibit"):
                reasons.append("«Despierto» activado")
            if sh.get("recording") and "grabando o compartiendo pantalla" not in reasons:
                reasons.append("grabando o compartiendo pantalla")
            if not (sh.get("locked") or sh.get("idle10")):
                reasons.append("estás usando el equipo (espera 10 min de inactividad o el bloqueo)")
    return {"ok": not reasons, "reasons": reasons, "level": level}
