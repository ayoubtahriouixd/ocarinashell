#!/usr/bin/env bash
# Battery power draw benchmark (fases 10, 11, 12, 15). Run UNPLUGGED, idle, fixed brightness.
# usage: scripts/bench-power.sh <etiqueta> [segundos=120]
# Appends a row to docs/ENERGIA.md: etiqueta · media W · mediana · p95 · autonomía estimada.
set -euo pipefail

label="${1:?uso: scripts/bench-power.sh <etiqueta> [segundos]}"
secs="${2:-120}"
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
bat=$(find /sys/class/power_supply -maxdepth 1 -name 'BAT*' -print -quit 2>/dev/null || true)
[[ -n "$bat" ]] || { echo "no hay batería" >&2; exit 1; }
status=$(cat "$bat/status")
[[ "$status" == "Discharging" ]] || { echo "desenchufa el cargador (estado: $status)" >&2; exit 1; }

read_watts() {
  if [[ -r "$bat/power_now" ]]; then
    awk '{printf "%.3f\n", $1/1e6}' "$bat/power_now"
  else
    awk -v v="$(cat "$bat/voltage_now")" '{printf "%.3f\n", ($1/1e6)*(v/1e6)}' "$bat/current_now"
  fi
}

echo "Midiendo «$label» durante ${secs}s… no toques el portátil."
samples=$(mktemp)
trap 'rm -f "$samples"' EXIT
for ((i = 0; i < secs; i++)); do read_watts >> "$samples"; sleep 1; done

if [[ -r "$bat/energy_now" ]]; then energy_wh=$(awk '{printf "%.2f", $1/1e6}' "$bat/energy_now")
else energy_wh=$(awk -v v="$(cat "$bat/voltage_now")" '{printf "%.2f", ($1/1e6)*(v/1e6)}' "$bat/charge_now"); fi
if [[ -r "$bat/energy_full" ]]; then full_wh=$(awk '{printf "%.2f", $1/1e6}' "$bat/energy_full")
else full_wh=$(awk -v v="$(cat "$bat/voltage_min_design" 2>/dev/null || cat "$bat/voltage_now")" '{printf "%.2f", ($1/1e6)*(v/1e6)}' "$bat/charge_full"); fi

stats=$(sort -n "$samples" | awk -v full="$full_wh" '
  { a[NR] = $1; s += $1 }
  END {
    n = NR; mean = s / n; med = (n % 2) ? a[(n + 1) / 2] : (a[n / 2] + a[n / 2 + 1]) / 2
    p95 = a[int(n * 0.95) > 0 ? int(n * 0.95) : 1]
    printf "%.2f %.2f %.2f %.1f", mean, med, p95, full / mean
  }')
read -r mean med p95 hours <<<"$stats"
brightness=$(brightnessctl -m 2>/dev/null | cut -d, -f4 || echo "?")
refresh=$(niri msg --json outputs 2>/dev/null | python3 -c 'import json,sys
d=json.load(sys.stdin)
for o in d.values():
    m=o.get("current_mode"); ms=o.get("modes") or []
    if m is not None and ms: print(round(ms[m]["refresh_rate"]/1000))' 2>/dev/null | head -n1 || echo "?")

doc="$root/docs/ENERGIA.md"
if [[ ! -f "$doc" ]]; then
  cat > "$doc" <<'EOF'
# Energía — medidas reales

| Fecha | Escenario | Media (W) | Mediana | p95 | Brillo | Hz | Autonomía estimada (batería llena) |
|---|---|---|---|---|---|---|---|
EOF
fi
row=$(printf '| %s | %s | %s | %s | %s | %s | %s | %s h |' "$(date '+%F %H:%M')" "$label" "$mean" "$med" "$p95" "$brightness" "$refresh" "$hours")
# the row goes at the end of the FIRST table (the analysis and other tables may follow it in the document)
tmp=$(mktemp "$doc.XXXXXX")
awk -v row="$row" '
  !done && /^\|/ { intable = 1 }
  !done && intable && !/^\|/ { print row; done = 1 }
  { print }
  END { if (!done) print row }' "$doc" > "$tmp" && mv -f "$tmp" "$doc"
echo "media ${mean} W · mediana ${med} W · p95 ${p95} W · autonomía ≈ ${hours} h (energía actual ${energy_wh} Wh de ${full_wh} Wh)"
