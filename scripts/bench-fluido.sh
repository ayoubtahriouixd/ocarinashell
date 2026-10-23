#!/usr/bin/env bash
# Fase 11 B · 滑 Nameraka measurements (docs/04-RENDIMIENTO §Vídeo fluido → docs/FLUIDO.md). Plays a test video FULL SCREEN
# (it covers the screen for the whole run: Ctrl+C stops everything), starts a SECOND nameraka daemon on its own socket
# (the systemd one is not touched) and measures what really reaches the compositor:
#   - cadence: wl_surface.commit of the presenter (WAYLAND_DEBUG of the presenter only) → output fps, interval
#     percentiles, «late» = intervals longer than 1,5 refreshes (a refresh shown twice)
#   - CPU of the helper (daemon + presenter, pidstat) and the GPU busy average
# usage: scripts/bench-fluido.sh <mpv|chrome> <24|30|60> <custom|x2|x4|x6> [seconds=300] [--no-write]
set -euo pipefail

player="${1:?uso: bench-fluido.sh <mpv|chrome> <24|30|60> <custom|x2|x4|x6> [segundos] [--no-write]}"
fps="${2:?fps}"; mode="${3:?modo}"; secs="${4:-300}"; write=1
[[ "${5:-}" == --no-write ]] && write=0
[[ "$player" =~ ^(mpv|chrome)$ && "$fps" =~ ^(24|30|60)$ && "$mode" =~ ^(custom|x2|x4|x6)$ && "$secs" =~ ^[0-9]+$ ]] \
  || { echo "argumentos no válidos" >&2; exit 2; }
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
nk="$HOME/.local/libexec/ocarinashell/nameraka"
cache="${XDG_CACHE_HOME:-$HOME/.cache}/ocarinashell/fluido-test"
mkdir -p "$cache"
work="$(mktemp -d)"
sock="$work/nameraka.sock"
pids=()
cleanup() {
  for p in "${pids[@]}"; do kill "$p" 2>/dev/null || true; done
  wait 2>/dev/null || true
  rm -rf "$work"
}
trap cleanup EXIT

# 1080p test video with a frame counter (generated once)
vid="$cache/t${fps}.mp4"
if [[ ! -f "$vid" ]]; then
  echo "Generando $vid…"
  ffmpeg -loglevel error -y -f lavfi -i "testsrc2=size=1920x1080:rate=$fps,drawtext=fontfile=/usr/share/fonts/TTF/DejaVuSans.ttf:text='%{n} @ $fps fps':fontsize=96:x=60:y=60:fontcolor=white:box=1:boxcolor=black" \
    -t 60 -c:v libx264 -preset veryfast -pix_fmt yuv420p "$vid"
fi

if [[ "$player" == mpv ]]; then
  mpv --no-config --no-audio --loop --fs --title=fluido-bench "$vid" >/dev/null 2>&1 & pids+=($!)
  match='w.get("app_id")=="mpv"'
else
  cat > "$work/v.html" <<EOF
<!doctype html><html><body style="margin:0;background:#000;overflow:hidden"><video src="file://$vid" autoplay muted loop
style="width:100vw;height:100vh;object-fit:contain"></video></body></html>
EOF
  google-chrome-stable --user-data-dir="$work/chrome" --no-first-run --no-default-browser-check --kiosk \
    --autoplay-policy=no-user-gesture-required --allow-file-access-from-files "file://$work/v.html" >/dev/null 2>&1 & pids+=($!)
  match='(w.get("app_id") or "").startswith("google-chrome")'
fi
for _ in $(seq 100); do
  wid=$(niri msg --json windows | python3 -c "import json,sys
for w in json.load(sys.stdin):
    if $match: print(w['id']); break" || true)
  [[ -n "$wid" ]] && break; sleep 0.1
done
[[ -n "${wid:-}" ]] || { echo "no encuentro la ventana del reproductor" >&2; exit 1; }
niri msg action focus-window --id "$wid"
sleep 3

# second daemon; the presenter inherits WAYLAND_DEBUG (the daemon itself has no Wayland connection)
NAMERAKA_SOCKET="$sock" WAYLAND_DEBUG=client "$nk" daemon 2> "$work/daemon.log" & pids+=($!)
for _ in $(seq 50); do [[ -S "$sock" ]] && break; sleep 0.1; done
python3 -I - "$sock" "$wid" "$mode" "$secs" > "$work/events.log" <<'PY' &
import json, socket, sys, time
sock, wid, mode, secs = sys.argv[1], int(sys.argv[2]), sys.argv[3], float(sys.argv[4])
s = socket.socket(socket.AF_UNIX); s.connect(sock); s.settimeout(0.5)
s.sendall((json.dumps({"cmd": "start", "window": wid, "mode": mode, "fps": 0}) + "\n").encode())
s.sendall(b'{"cmd":"stats","on":true}\n')
t0 = time.time(); buf = b""
while time.time() - t0 < secs + 6:
    try:
        d = s.recv(65536)
        if not d: break
        buf += d
    except socket.timeout:
        pass
    while b"\n" in buf:
        line, buf = buf.split(b"\n", 1)
        print(f"{time.time()-t0:.3f} {line.decode()}", flush=True)
s.sendall(b'{"cmd":"stop"}\n'); time.sleep(0.5)
PY
pids+=($!)
client=$!
sleep 8                                    # start, settle, lsfg-vk context
view=""
for p in $(pgrep -x nameraka); do grep -qa view "/proc/$p/cmdline" && view=$p; done
daemon=$(pgrep -f "nameraka daemon" | head -n1)
gpu=""; for g in /sys/class/drm/card*/device/gpu_busy_percent; do [[ -r "$g" ]] && { gpu=$g; break; }; done
( g=0; n=0; t=$((secs - 4)); while ((t > 0)); do g=$((g + $(cat "$gpu"))); n=$((n + 1)); sleep 1; t=$((t - 1)); done
  echo $((g / (n > 0 ? n : 1))) > "$work/gpu" ) & pids+=($!)
pidstat -u -p "${view:-1},${daemon:-1}" $((secs - 6)) 1 2>/dev/null | awk '/Media/ && $NF ~ /nameraka/ {s += $(NF-2)} END {printf "%.2f\n", s}' > "$work/cpu" || true
wait "$client" 2>/dev/null || true
sleep 1

stats="$(python3 - "$work/daemon.log" "$work/events.log" "$secs" <<'PY'
import json, re, sys
log, ev, secs = sys.argv[1], sys.argv[2], float(sys.argv[3])
t = []
for l in open(log, errors="replace"):
    m = re.match(r"\[(\d+):(\d+):([\d.]+)\]\s+\{mesa vk display queue\}\s+->\s+wl_surface#\d+\.commit\(\)", l)
    if m:
        t.append((int(m[1]) * 3600 + int(m[2]) * 60 + float(m[3])) * 1000)
state = {}
for l in open(ev):
    _, j = l.split(" ", 1)
    try:
        e = json.loads(j)
    except ValueError:
        continue
    if e.get("ev") in ("state", "stats"):
        state = e
if len(t) < 100:
    print("sin datos"); sys.exit()
t = [x for x in t if t[0] + 5000 < x < t[-1] - 1000]       # steady state
d = sorted(b - a for a, b in zip(t, t[1:]))
hz = state.get("hz", 120)
period = 1000 / hz
late = sum(1 for x in d if x > period * 1.5)
dur = (t[-1] - t[0]) / 1000
print(f'{(len(t)-1)/dur:.1f} {d[len(d)//2]:.2f} {d[int(len(d)*0.99)]:.2f} {100*late/len(d):.2f} {state.get("base",0)} {state.get("m",0)} {state.get("flow",0)} {dur:.0f}')
PY
)"
read -r outfps p50 p99 latepct base m flow dur <<<"$stats"
cpu=$(cat "$work/cpu" 2>/dev/null || echo "?"); gpuavg=$(cat "$work/gpu" 2>/dev/null || echo "?")
echo "滑 $player ${fps} fps · $mode → salida $outfps fps · base $base ×$m flujo $flow · intervalo p50 $p50 ms p99 $p99 ms · tarde $latepct % · CPU $cpu % · GPU $gpuavg % · $dur s"
if ((write)) && [[ -f "$root/docs/FLUIDO.md" ]]; then
  row="| $(date '+%F %H:%M') | $player | 1080p${fps} | $mode | ${base} ×${m} · flujo ${flow} | **${outfps}** | ${p50} / ${p99} | **${latepct} %** | ${cpu} % | ${gpuavg} % | ${dur} s |"
  python3 - "$root/docs/FLUIDO.md" "$row" <<'PY'
import sys
path, row = sys.argv[1], sys.argv[2]
lines = open(path, encoding="utf-8").read().split("\n")
start = next(i for i, l in enumerate(lines) if l.startswith("## Cadencia"))
i = start
while i < len(lines) and not lines[i].startswith("|"):
    i += 1
while i < len(lines) and lines[i].startswith("|"):
    i += 1
lines.insert(i, row)
open(path, "w", encoding="utf-8").write("\n".join(lines))
PY
  echo "→ fila en docs/FLUIDO.md"
fi
