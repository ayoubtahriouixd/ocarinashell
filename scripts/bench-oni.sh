#!/usr/bin/env bash
# Fase 11 · 鬼 Oni measurements (docs/04-RENDIMIENTO, docs/JUEGOS.md). Runs vkmark OFFSCREEN (winsys headless: nothing
# appears on the screen, the GPU does the same work) at the panel's resolution and samples, every 0.5 s, the CPU and GPU
# clocks, Tctl, the GPU edge temperature and the APU package power (PPT). One row is appended to docs/JUEGOS.md.
# It never changes the power state by itself: put the machine in the scenario first (ocarina oni on, …) and label it.
#   load gpu  → vkmark only                    load mix → vkmark + 6 busy CPU threads (a game also uses the CPU: on this
#   APU both share one power budget, so «more CPU» can mean «fewer fps»)
#   gamescope → vkmark nested in a headless gamescope rendering at 1440×900 and upscaling with FSR to 2880×1800
# usage: scripts/bench-oni.sh "<label>" [gpu|mix] [native|gamescope] [seconds per scene=6] [--no-write]
set -euo pipefail

label="${1:?uso: bench-oni.sh \"etiqueta\" [gpu|mix] [native|gamescope] [s por escena] [--no-write]}"
load="${2:-gpu}"; how="${3:-native}"; per="${4:-6}"; write=1
[[ "${5:-}" == --no-write ]] && write=0
[[ "$load" =~ ^(gpu|mix)$ && "$how" =~ ^(native|gamescope)$ && "$per" =~ ^[0-9]+$ ]] || { echo "argumentos no válidos" >&2; exit 2; }
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
out="$root/docs/JUEGOS.md"
tmp="$(mktemp -d)"; pids=()
cleanup() { for p in "${pids[@]}"; do kill "$p" 2>/dev/null || true; done; wait 2>/dev/null || true; rm -rf "$tmp"; }
trap cleanup EXIT

hw() { for h in /sys/class/hwmon/hwmon*; do [[ "$(cat "$h/name")" == "$1" ]] && { echo "$h"; return; }; done; }
k10="$(hw k10temp)"; gpu="$(hw amdgpu)"
card="$(dirname "$(dirname "$(readlink -f "$gpu")")")"   # …/device/hwmon/hwmonN → …/device
[[ -n "$k10" && -n "$gpu" && -e "$card/pp_dpm_sclk" ]] || { echo "no encuentro k10temp/amdgpu" >&2; exit 1; }

sampler() {   # t tctl edge ppt_w sclk_mhz cpu_mhz gpu_busy
  while :; do
    local s c=0 n=0 f
    s="$(sed -n 's/^[0-9]*: \([0-9]*\)Mhz \*$/\1/p' "$card/pp_dpm_sclk")"
    for f in /sys/devices/system/cpu/cpufreq/policy*/scaling_cur_freq; do c=$((c + $(<"$f"))); n=$((n + 1)); done
    printf '%s %s %s %s %s %s %s\n' "$EPOCHREALTIME" "$(<"$k10/temp1_input")" "$(<"$gpu/temp1_input")" \
      "$(<"$gpu/power1_input")" "${s:-0}" "$((c / n / 1000))" "$(<"$card/gpu_busy_percent")"
    sleep 0.5
  done
}

scenes=(-b "vertex:duration=$per" -b "texture:duration=$per" -b "shading:shading=phong:duration=$per"
        -b "effect2d:duration=$per" -b "desktop:duration=$per" -b "cube:duration=$per")
echo "鬼 $label · carga $load · $how · $((${#scenes[@]} * per / 2)) s"
echo "estado: $(powerprofilesctl get) · GPU $(cat "$card/power_dpm_force_performance_level") · EPP $(cat /sys/devices/system/cpu/cpufreq/policy0/energy_performance_preference) · scx $(cat /sys/kernel/sched_ext/root/ops 2>/dev/null || echo off)"

if [[ "$load" == mix ]]; then
  for _ in 1 2 3 4 5 6; do yes >/dev/null & pids+=($!); done
fi
sampler > "$tmp/s" & pids+=($!)
if [[ "$how" == gamescope ]]; then
  gamescope --backend headless -W 2880 -H 1800 -w 1440 -h 900 -F fsr -r 120 -- \
    vkmark --winsys xcb --fullscreen "${scenes[@]}" > "$tmp/v" 2>&1 || true
else
  vkmark --winsys headless -s 2880x1800 "${scenes[@]}" > "$tmp/v" 2>&1 || true
fi
for p in "${pids[@]}"; do kill "$p" 2>/dev/null || true; done; pids=()

score="$(sed -n 's/.*vkmark Score: *\([0-9]*\).*/\1/p' "$tmp/v")"
[[ -n "$score" ]] || { echo "vkmark no terminó:"; tail -n 20 "$tmp/v"; exit 1; }
perscene="$(sed -n 's/.*\[\([a-z0-9]*\)\] .*FPS: *\([0-9]*\).*/\1 \2/p' "$tmp/v" | tr '\n' ' ')"
stats="$(awk 'NR>2 { n++; t+=$2; if($2>tm)tm=$2; e+=$3; if($3>em)em=$3; w+=$4; s+=$5; c+=$6; b+=$7 }
  END { if(!n){print "- - - - - - -"; exit} printf "%.1f %.1f %.1f %.1f %.1f %d %d %d", t/n/1000, tm/1000, e/n/1000, em/1000, w/n/1e6, s/n, c/n, b/n }' "$tmp/s")"
read -r tavg tmax eavg emax watts sclk cmhz busy <<<"$stats"
echo "puntuación $score · $perscene"
echo "Tctl $tavg (máx $tmax) °C · GPU $eavg (máx $emax) °C · PPT $watts W · sclk $sclk MHz · CPU $cmhz MHz · GPU ocupada $busy %"

if ((write)); then
  [[ -f "$out" ]] || { echo "falta $out" >&2; exit 1; }
  row="| $(date '+%F %H:%M') | $label | $load · $how | **$score** | $perscene | $tavg / $tmax | $eavg / $emax | $watts | $sclk | $cmhz |"
  python3 - "$out" "$row" <<'PY'
import sys
path, row = sys.argv[1], sys.argv[2]
lines = open(path, encoding="utf-8").read().split("\n")
# append after the last row of the first table under «## Medidas»
start = next(i for i, l in enumerate(lines) if l.startswith("## Medidas"))
i = start
while i < len(lines) and not lines[i].startswith("|"):
    i += 1
while i < len(lines) and lines[i].startswith("|"):
    i += 1
lines.insert(i, row)
open(path, "w", encoding="utf-8").write("\n".join(lines))
PY
  echo "→ fila añadida a docs/JUEGOS.md"
fi
