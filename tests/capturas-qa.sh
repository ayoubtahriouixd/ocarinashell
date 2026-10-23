#!/usr/bin/env bash
# 撮 Fase 17 · every screen of OcarinaShell for the independent visual QA (visual-qa agent) and the README.
# Ayoub runs it from any terminal: it moves to the empty workspace at the end of the output (captures never contain
# his windows) and comes back when it finishes. It opens each
# surface over IPC, waits for its animation, captures the panel output with grim and closes it. ~2 min; Ctrl+C stops
# it (the trap closes whatever is open and puts the theme and the modes back).
# usage: bash tests/capturas-qa.sh [--readme] [filtro]     → docs/evidencias/fase-17/qa/<nn>-<nombre>.png
#   --readme: for the public README: OcarinaShell's own wallpaper and the Kurenai theme while capturing (yours come
#   back at the end), into docs/evidencias/fase-17/readme/
set -euo pipefail

repo="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
readme=0
if [[ "${1:-}" == --readme ]]; then readme=1; shift; fi
out="$repo/docs/evidencias/fase-17/$( ((readme)) && echo readme || echo qa)"
filter="${1:-}"
ipc() { qs -c ocarina ipc call "$@" >/dev/null 2>&1 || true; }
mkdir -p "$out"

output="$(niri msg --json focused-output | python3 -c 'import json,sys; print(json.load(sys.stdin)["name"])')"
# jump to the empty workspace niri keeps at the end of this output (and come back at the end)
read -r back empty < <(niri msg --json workspaces | python3 -c "
import json, subprocess, sys
ws = [w for w in json.load(sys.stdin) if w['output'] == '$output']
wins = json.loads(subprocess.run(['niri', 'msg', '--json', 'windows'], capture_output=True, text=True).stdout)
used = {w.get('workspace_id') for w in wins}
cur = next(w['idx'] for w in ws if w['is_focused'])
free = [w['idx'] for w in sorted(ws, key=lambda w: w['idx']) if w['id'] not in used]
print(cur, free[-1] if free else -1)")
if ((empty < 0)); then
  echo "No hay ningún espacio vacío en $output: las capturas nunca deben llevar tus ventanas." >&2
  exit 1
fi
niri msg action focus-workspace "$empty"
sleep 0.8

theme0="$(python3 "$repo/bin/ocarina-theme" current | cut -d' ' -f1)"
# 静 No molestar while capturing: a toast would put someone's message in the evidence
dnd0="$(qs -c ocarina ipc call shell status 2>/dev/null | tail -n1 | python3 -c 'import json,sys; print("on" if json.load(sys.stdin).get("dnd") else "off")' 2>/dev/null || echo off)"
ipc notifications dnd on
wall0="$(qs -c ocarina ipc call settings get wallpaper.path 2>/dev/null | tail -n1)"
if ((readme)); then
  ipc settings set wallpaper.path '""'; ipc theme set kurenai; sleep 3
fi
cleanup() {
  ipc notifications dnd "$dnd0"
  ((readme)) && ipc settings set wallpaper.path "$wall0"
  ipc power close; ipc lock cancel
  [[ -n "$(qs -c ocarina ipc call settings page 2>/dev/null)" ]] && ipc settings toggle
  ipc shinobi off; ipc oni off
  [[ "$(python3 "$repo/bin/ocarina-theme" current | cut -d' ' -f1)" == "$theme0" ]] || ipc theme set "$theme0"
  niri msg action focus-workspace "$back" || true
}
trap cleanup EXIT INT TERM

n=0
shot() {   # shot <name> <seconds to wait>
  n=$((n + 1))
  local name; name="$(printf '%02d-%s' "$n" "$1")"
  if [[ -n "$filter" && "$name" != *"$filter"* ]]; then return 0; fi
  sleep "${2:-1.2}"
  grim -o "$output" "$out/$name.png"
  echo "  ✓ $name"
}

echo "撮 capturando en $output (no toques nada; Ctrl+C para parar)…"
shot escritorio 1.5
ipc engawa open "";              shot engawa;            ipc engawa toggle; sleep 0.5
ipc engawa open fluido;          shot fluido-mockup13;   ipc engawa toggle; sleep 0.5
ipc launcher open all "";        shot torii;             ipc launcher toggle; sleep 0.5
ipc launcher open all "term";    shot torii-busqueda;    ipc launcher toggle; sleep 0.5
ipc apps toggle;                 shot cajon-apps 1.6;    ipc apps toggle; sleep 0.6
# (no Fumi: its history is other people's messages)
ipc hiroba open;                 shot hiroba 1.6;        ipc hiroba close; sleep 0.6
ipc fune toggle;                 shot fune;              ipc fune toggle; sleep 0.5
ipc snake open;                  shot snake;             ipc snake toggle; sleep 0.5
ipc power toggle;                shot dengen;            ipc power close; sleep 0.6
ipc power farewell shutdown;     shot despedida 1.8;     sleep 3
ipc lock test;                   shot kagi-prueba 2.2;   ipc lock cancel; sleep 1.5
ipc shinobi on;                  shot shinobi 3;         ipc shinobi off; sleep 3
ipc oni on;                      shot oni 3;             ipc oni off; sleep 3

for t in kohaku kurenai; do
  ipc theme set "$t"; sleep 3
  for p in apariencia mamori pantalla atajos fondos acerca; do
    ipc settings open "$p"; shot "settei-$t-$p" 1.6
  done
  ipc settings toggle; sleep 0.8
done
echo "listo: $out (revisa que ninguna tenga nada tuyo antes de añadirlas a git)"
