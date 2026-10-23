#!/usr/bin/env bash
# Fase 10 · drain while suspended (s2idle) and s0ix residency (amd_pmc). Ayoub runs it, unplugged:
#   scripts/bench-suspend.sh           notes the battery, suspends, and on resume prints Wh/h, %/h and the s0ix
#                                      residency (should be ≈ the time asleep: if it is 0, s0ix is not reached)
# Leave it asleep ≥ 1 h for a meaningful number. Appends a row to docs/ENERGIA.md (section «Suspensión»).
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
bat=$(find /sys/class/power_supply -maxdepth 1 -name 'BAT*' -print -quit)
[[ "$(cat "$bat/status")" == Discharging ]] || { echo "Desenchufa el cargador y vuelve a lanzarlo." >&2; exit 1; }
wh() { awk '{printf "%.3f", $1/1e6}' "$bat/energy_now"; }
s0ix() { sudo -n cat /sys/kernel/debug/amd_pmc/s0ix_stats 2>/dev/null | awk -F: '/Residency Time/ {gsub(/ /, "", $2); print $2}' || true; }

e0=$(wh); p0=$(cat "$bat/capacity"); t0=$(date +%s); r0=$(s0ix)
echo "Batería ${p0} % (${e0} Wh). Suspendiendo en 5 s… despierta el portátil cuando quieras (≥ 1 h)."
sleep 5
systemctl suspend
# systemctl returns at once; wait until the clock shows we really slept
while (( $(date +%s) - t0 < 20 )); do sleep 1; done
sleep 5   # let the battery gauge settle after resume
e1=$(wh); p1=$(cat "$bat/capacity"); t1=$(date +%s); r1=$(s0ix)
read -r hours rate pct res <<<"$(awk -v e0="$e0" -v e1="$e1" -v p0="$p0" -v p1="$p1" -v t="$((t1 - t0))" -v r0="${r0:-0}" -v r1="${r1:-0}" \
  'BEGIN { h = t / 3600; printf "%.2f %.3f %.2f %.0f", h, (e0 - e1) / h, (p0 - p1) / h, (r1 - r0) / 1e6 }')"
echo "Dormido ${hours} h · ${rate} W de media · ${pct} %/h · residencia s0ix ${res} s de $((t1 - t0)) s"
doc="$root/docs/ENERGIA.md"
grep -q '^## Suspensión' "$doc" 2>/dev/null || printf '\n## Suspensión (s2idle)\n\n| Fecha | Horas | W medios | %%/h | Residencia s0ix |\n|---|---|---|---|---|\n' >> "$doc"
printf '| %s | %s | %s | %s | %s s de %s s |\n' "$(date '+%F %H:%M')" "$hours" "$rate" "$pct" "$res" "$((t1 - t0))" >> "$doc"
