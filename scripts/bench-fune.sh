#!/usr/bin/env bash
# Fase 12 · 船 Fune measurements (docs/04-RENDIMIENTO §Windows → docs/WINDOWS.md). It OPENS WINDOWS on the screen:
# run it only when Ayoub says so (Ctrl+C stops it; the VM is left as it was found when possible).
#   open  <app> <cold|warm|hot> [runs=3]   ocarina-fune app <app> → the RemoteApp window mapped in niri (event stream)
#                                           cold = VM off · warm = paused · hot = running
#   idle  <app> [seconds=60]               CPU of qemu and xfreerdp3 with one app open and untouched (pidstat)
#   ram                                    host RAM available with the VM running, paused and off
# usage: scripts/bench-fune.sh open notepad warm 5
set -euo pipefail

fune="${HOME}/.local/bin/ocarina-fune"
cmd="${1:-}"; app="${2:-}"
[[ -n "$cmd" ]] || { sed -n '2,10p' "$0" | sed 's/^# \{0,1\}//'; exit 2; }

state() { "$fune" status --json | jq -r .state; }
close_app() {   # close every Windows window (one shared connection: app-id fune-windows; titled = a real window)
  local id
  for id in $(niri msg --json windows | jq -r '.[] | select(.app_id == "fune-windows" and .title != "" and .title != "RemoteApp Marker Window") | .id'); do
    niri msg action close-window --id "$id"
  done
}
prepare() {   # $1 = cold|warm|hot
  case "$1" in
    cold) [[ "$(state)" == exited ]] || "$fune" stop >/dev/null ;;
    warm) [[ "$(state)" == paused ]] || { "$fune" up --quiet; sleep 25; "$fune" pause >/dev/null; } ;;   # 20 s RemoteApp logoff
    hot)  "$fune" up --quiet ;;
  esac
}

case "$cmd" in
  open)
    mode="${3:-warm}"; runs="${4:-3}"
    [[ "$mode" =~ ^(cold|warm|hot)$ && -n "$app" ]] || { echo "uso: $0 open <app> <cold|warm|hot> [runs]" >&2; exit 2; }
    for i in $(seq "$runs"); do
      prepare "$mode"
      ms=$(python3 -I - "$fune" "$app" <<'PY'
import json, subprocess, sys, time
fune, app = sys.argv[1], sys.argv[2]
ev = subprocess.Popen(["niri", "msg", "--json", "event-stream"], stdout=subprocess.PIPE, text=True)
t0 = time.monotonic()
subprocess.Popen([fune, "app", app], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, start_new_session=True)
deadline = t0 + 300
for line in ev.stdout:
    if time.monotonic() > deadline:
        print(-1); break
    try:
        e = json.loads(line)
    except ValueError:
        continue
    w = (e.get("WindowOpenedOrChanged") or {}).get("window") or {}
    if w.get("app_id") == "fune-windows" and w.get("title") not in (None, "", "RemoteApp Marker Window"):
        print(int((time.monotonic() - t0) * 1000)); break
ev.terminate()
PY
)
      echo "open $app $mode #$i: ${ms} ms"
      sleep 3; close_app; sleep 25                  # RemoteApp keeps the session 20 s after the last window
    done ;;
  idle)
    secs="${3:-60}"
    "$fune" up --quiet
    "$fune" app "$app" >/dev/null 2>&1 &
    sleep 15
    qemu=$(pgrep -f "qemu-system-x86_64" | head -1); rdp=$(pgrep -n xfreerdp3)
    echo "pidstat ${secs} s · qemu=$qemu xfreerdp3=$rdp (sin tocar la ventana)"
    LC_ALL=C pidstat -u -p "$qemu,$rdp" "$secs" 1 | awk '/Average|Media/ && $NF !~ /Command/ {print "  " $NF ": " $(NF-3) " % CPU"}'
    close_app ;;
  ram)
    avail() { awk '/MemAvailable/ {printf "%.1f GiB", $2 / 1048576}' /proc/meminfo; }
    "$fune" up --quiet; sleep 5; echo "activa:   $(avail)"
    "$fune" pause >/dev/null; sleep 3; echo "en pausa: $(avail)"
    "$fune" stop >/dev/null; sleep 3; echo "apagada:  $(avail)" ;;
  *) sed -n '2,10p' "$0" | sed 's/^# \{0,1\}//'; exit 2 ;;
esac
