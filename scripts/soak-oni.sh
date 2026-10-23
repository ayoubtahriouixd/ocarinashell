#!/usr/bin/env bash
# Fase 11 · 鬼 Oni thermal soak (criterio: «ninguna temperatura fuera de rango en 20 min de juego»). vkmark offscreen in a
# loop (winsys headless: nothing on the screen) + 6 busy CPU threads, the worst case for this APU's shared power budget,
# sampling Tctl, GPU edge, PPT, clocks, fan speed and the mode every 2 s into a CSV. Put the machine in the scenario
# first (ocarina oni on). Ctrl+C stops everything.
# usage: scripts/soak-oni.sh [minutes=20] [csv=docs/evidencias/fase-11/soak-oni.csv]
set -euo pipefail

mins="${1:-20}"
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
csv="${2:-$root/docs/evidencias/fase-11/soak-oni.csv}"
[[ "$mins" =~ ^[0-9]+$ ]] || { echo "minutos no válidos" >&2; exit 2; }
pids=()
cleanup() { for p in "${pids[@]}"; do kill "$p" 2>/dev/null || true; done; wait 2>/dev/null || true; }
trap cleanup EXIT

hw() { for h in /sys/class/hwmon/hwmon*; do [[ "$(cat "$h/name")" == "$1" ]] && { readlink -f "$h"; return; }; done; }
k10="$(hw k10temp)"; gpu="$(hw amdgpu)"; tp="$(hw thinkpad)"
card="$(dirname "$(dirname "$gpu")")"

for _ in 1 2 3 4 5 6; do yes >/dev/null & pids+=($!); done
vkmark --winsys headless -s 2880x1800 --run-forever -b shading:shading=phong:duration=30 -b cube:duration=30 \
  -b texture:duration=30 >/dev/null 2>&1 & pids+=($!)

echo "t_s,tctl_c,gpu_c,ppt_w,sclk_mhz,cpu_mhz,fan_rpm,mode" > "$csv"
t0=$SECONDS; end=$((SECONDS + mins * 60)); max_t=0; max_g=0
echo "鬼 prueba térmica: $mins min → $csv"
while ((SECONDS < end)); do
  c=0; n=0
  for f in /sys/devices/system/cpu/cpufreq/policy*/scaling_cur_freq; do c=$((c + $(<"$f"))); n=$((n + 1)); done
  t=$(<"$k10/temp1_input"); g=$(<"$gpu/temp1_input"); w=$(<"$gpu/power1_input")
  s="$(sed -n 's/^[0-9]*: \([0-9]*\)Mhz \*$/\1/p' "$card/pp_dpm_sclk")"
  fan=$(cat "$tp/fan1_input" 2>/dev/null || echo 0)
  mode="$(timeout 1 qs -c ocarina ipc call oni status 2>/dev/null | python3 -c 'import json,sys; print(json.load(sys.stdin)["state"])' 2>/dev/null || echo ?)"
  printf '%d,%d.%d,%d.%d,%d.%d,%s,%d,%s,%s\n' $((SECONDS - t0)) $((t / 1000)) $((t % 1000 / 100)) $((g / 1000)) \
    $((g % 1000 / 100)) $((w / 1000000)) $((w % 1000000 / 100000)) "${s:-0}" $((c / n / 1000)) "$fan" "$mode" >> "$csv"
  ((t > max_t)) && max_t=$t; ((g > max_g)) && max_g=$g
  sleep 2
done
echo "máximos: Tctl $((max_t / 1000)) °C · GPU $((max_g / 1000)) °C"
