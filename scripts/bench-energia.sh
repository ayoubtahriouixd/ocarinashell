#!/usr/bin/env bash
# Fase 10 · energy scenarios A–G in one go (docs/04-RENDIMIENTO §Energía). Ayoub runs it himself, UNPLUGGED, from a
# terminal, and does not touch the laptop until it ends (≈ 7 × (asentar + medir)). Each scenario waits `asentar`
# seconds and then calls scripts/bench-power.sh, which appends one row to docs/ENERGIA.md.
# The screen shows an empty workspace (wallpaper + bar) so every scenario looks the same; everything is put back at
# the end, also on Ctrl+C (brightness, Hz/VRR through niri's own config, Shinobi off, GPU auto, Ethernet PM).
#   A normal 120 Hz · F A + Ethernet runtime PM · B normal 60 Hz · C 120 Hz + VRR always on
#   D Shinobi · G Shinobi + GPU low · E Shinobi + brillo 20 % · H Shinobi + VRR (60 Hz máx., 30 en reposo)
# usage: scripts/bench-energia.sh [medir=120] [asentar=60] [escenarios=AFBCDGE]   (H: pídelo, p. ej. «DH»)
set -euo pipefail

secs="${1:-120}"; settle="${2:-60}"; only="${3:-AFBCDGE}"
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
helper=/usr/local/libexec/ocarina-powerctl
eth=""
for n in /sys/class/net/*; do
  [[ -e "$n/device" && ! -d "$n/wireless" && "$(basename "$n")" != lo ]] && eth="$(readlink -f "$n/device")" && break
done
bat=$(find /sys/class/power_supply -maxdepth 1 -name 'BAT*' -print -quit)
[[ "$(cat "$bat/status")" == Discharging ]] || { echo "Desenchufa el cargador y vuelve a lanzarlo." >&2; exit 1; }

bright0=$(brightnessctl -m -c backlight | cut -d, -f4)
ws0=$(niri msg --json workspaces | python3 -c 'import json,sys; print(next(w["idx"] for w in json.load(sys.stdin) if w["is_focused"]))')
eth0=""; [[ -n "$eth" ]] && eth0=$(cat "$eth/power/control")
mode0=$(niri msg --json outputs | python3 -c 'import json,sys
o=json.load(sys.stdin)["eDP-1"]; m=o["modes"][o["current_mode"]]
print("%dx%d@%.3f" % (m["width"], m["height"], m["refresh_rate"] / 1000))')
vrr0=(off); grep -q 'variable-refresh-rate on-demand=true' "${XDG_STATE_HOME:-$HOME/.local/state}/ocarinashell/niri/outputs.kdl" 2>/dev/null && vrr0=(on --on-demand)
panel() {   # back to what outputs.kdl says (niri msg changes are not undone by a config reload)
  niri msg output eDP-1 mode "$mode0" >/dev/null 2>&1 || true
  niri msg output eDP-1 vrr "${vrr0[@]}" >/dev/null 2>&1 || true
}

restore() {
  echo; echo "Restaurando…"
  ocarina shinobi off >/dev/null 2>&1 || true
  sleep 1.5
  [[ -n "${vrr_set:-}" ]] && setvrr "$vrr_set"
  pkexec "$helper" gpu auto >/dev/null 2>&1 || true
  [[ -n "$eth" && -n "$eth0" ]] && { echo "$eth0" | sudo -n tee "$eth/power/control" >/dev/null 2>&1 || true; }
  panel
  brightnessctl -q -c backlight set "$bright0"
  niri msg action focus-workspace "$ws0" >/dev/null 2>&1 || true
  echo "Listo: todo como estaba. Resultados en docs/ENERGIA.md"
}
trap restore EXIT

scenario() {   # $1 = letter, $2 = label
  [[ "$only" == *"$1"* ]] || return 0
  printf '\n[%s] %s — asentando %ss, midiendo %ss\n' "$1" "$2" "$settle" "$secs"
  sleep "$settle"
  "$root/scripts/bench-power.sh" "$1 · $2" "$secs" | tail -n1
}

echo "忍 Medidas de energía: ${#only} escenarios × $((settle + secs)) s ≈ $(( ${#only} * (settle + secs) / 60 )) min. No toques nada."
echo "Para cortar: Ctrl+C (se restaura todo)."
niri msg action focus-workspace 9 >/dev/null
brightnessctl -q -c backlight set 50%

scenario A "normal 120 Hz, brillo 50 %"
if [[ -n "$eth" && "$only" == *F* ]]; then
  echo auto | sudo -n tee "$eth/power/control" >/dev/null
  scenario F "normal 120 Hz + Ethernet en ahorro (runtime PM)"
  echo "$eth0" | sudo -n tee "$eth/power/control" >/dev/null
fi
if [[ "$only" == *B* ]]; then
  niri msg output eDP-1 mode 2880x1800@60.000
  scenario B "normal 60 Hz"
  panel
fi
if [[ "$only" == *C* ]]; then
  niri msg output eDP-1 vrr on
  scenario C "normal 120 Hz + VRR siempre (vigila parpadeo)"
  panel
fi
vrr_set=$(qs -c ocarina ipc call settings get shinobi.vrr 2>/dev/null || echo false)
setvrr() { qs -c ocarina ipc call settings set shinobi.vrr "$1" >/dev/null; }
if [[ "$only" =~ [DGE] ]]; then
  setvrr false
  ocarina shinobi on >/dev/null
  sleep 2
  scenario D "忍 Shinobi (brillo con tope $(brightnessctl -m -c backlight | cut -d, -f4))"
  if [[ "$only" == *G* ]]; then
    pkexec "$helper" gpu low
    scenario G "忍 Shinobi + GPU al mínimo"
    pkexec "$helper" gpu auto
  fi
  brightnessctl -q -c backlight set 20%
  scenario E "忍 Shinobi + brillo 20 %"
fi
if [[ "$only" == *H* ]]; then
  ocarina shinobi off >/dev/null 2>&1 || true
  sleep 2
  setvrr true
  ocarina shinobi on >/dev/null
  sleep 2
  scenario H "忍 Shinobi + VRR (60 Hz máx.)"
fi
