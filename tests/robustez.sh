#!/usr/bin/env bash
# shellcheck disable=SC2329   # the steps are called through run() as "$3"
# 堅 Fase 17 · robustness list (docs/historia/fases/fase-17.md, tarea 4), run by Ayoub in his own terminal. Every step waits
# for Intro (nothing repeats on its own without you starting it), says what it will do and how long, and afterwards
# the journal of that window is checked: shell warnings/errors (known noise filtered), niri errors, amdgpu errors and
# new coredumps. «s» skips a step, «q» ends. Result: docs/evidencias/fase-17/robustez.txt.
# usage: bash tests/robustez.sh [primer paso]
set -uo pipefail

repo="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
log="$repo/docs/evidencias/fase-17/robustez.txt"
first="${1:-1}"
mkdir -p "$(dirname "$log")"
ipc() { qs -c ocarina ipc call "$@" 2>/dev/null; }
# Qt/Wayland noise that is not ours: text-input-v3 focus juggling, the portal app id after a restart, his truncated JPEG
noise='Corrupt JPEG|QWaylandTextInputv3|register with host portal|textinput'

total_bad=0
check() {   # check <since> <name>
  local since="$1" name="$2" shell niri gpu cores n
  shell="$(journalctl --user -u ocarinashell -u ocarinashell-safe --since "$since" --no-pager -o cat 2>/dev/null | sed 's/\x1b\[[0-9;]*m//g' \
           | grep -E ' WARN | ERROR |CRITICAL|TypeError|ReferenceError' | grep -Ev "$noise" | sort | uniq -c | sort -rn)"
  niri="$(journalctl --user --since "$since" --no-pager -o cat _COMM=niri 2>/dev/null | grep -E ' ERROR ' | sort | uniq -c)"
  gpu="$(journalctl -k --since "$since" --no-pager -o cat 2>/dev/null | grep -iE 'amdgpu.*(error|fault|timeout|reset)')"
  cores="$(coredumpctl list --since "$since" --no-legend 2>/dev/null)"
  n=$(( $(grep -c . <<<"$shell") + $(grep -c . <<<"$niri") + $(grep -c . <<<"$gpu") + $(grep -c . <<<"$cores") ))
  {
    printf '\n## %s · %s\n' "$name" "$(date '+%F %T')"
    if ((n == 0)); then echo "✓ journal limpio (shell, niri, amdgpu, coredumps)"; else
      [[ -n "$shell" ]] && printf 'shell:\n%s\n' "$shell"
      [[ -n "$niri" ]] && printf 'niri:\n%s\n' "$niri"
      [[ -n "$gpu" ]] && printf 'amdgpu:\n%s\n' "$gpu"
      [[ -n "$cores" ]] && printf 'coredumps:\n%s\n' "$cores"
    fi
    [[ -n "${note:-}" ]] && printf '%s\n' "$note"
  } | tee -a "$log"
  total_bad=$((total_bad + n))
  note=""
}
alive() {   # the shell answers over IPC (not safe mode)
  for _ in $(seq 40); do
    if ipc shell status | grep -q '"version"' && ! systemctl --user is-active --quiet ocarinashell-safe; then return 0; fi
    sleep 0.25
  done
  return 1
}

step=0
run() {   # run <title> <explanation> <function>
  step=$((step + 1))
  ((step < first)) && return 0
  printf '\n\e[1m%d · %s\e[0m\n%s\n' "$step" "$1" "$2"
  read -r -p "Intro = empezar · s = saltar · q = terminar › " k
  case "$k" in s|S) echo "(saltado)" | tee -a "$log"; return 0 ;; q|Q) finish ;; esac
  local since; since="$(date '+%F %T')"
  "$3"
  check "$since" "$step · $1"
}
finish() {
  printf '\n%s\n' "Total: $total_bad línea(s) de error · $(date '+%F %T')" | tee -a "$log"
  exit 0
}

# ── the steps ───────────────────────────────────────────────────────────────────────────────
s_kill() {
  ipc engawa open "" >/dev/null; sleep 0.8
  local t0; t0=$(date +%s.%N)
  systemctl --user kill -s KILL ocarinashell
  sleep 0.5
  if alive; then note="vuelve en $(python3 -c "import time; print(round(time.time() - $t0, 1))") s (systemd la relanza)"
  else note="✗ NO volvió en 10 s"; total_bad=$((total_bad + 1)); fi
  ipc lock cancel >/dev/null
}
s_themes() {
  local t0 i themes=(kurenai kohaku sumi ai matcha yozakura)
  t0="$(python3 "$repo/bin/ocarina-theme" current | cut -d' ' -f1)"
  for i in $(seq 0 19); do ipc theme set "${themes[i % 6]}" >/dev/null; sleep 2.2; printf '.'; done
  ipc theme set "$t0" >/dev/null; sleep 2; echo
  alive || note="✗ la shell no responde tras los temas"
}
s_shinobi() {
  for _ in $(seq 20); do ipc shinobi on >/dev/null; sleep 2; ipc shinobi off >/dev/null; sleep 2; printf '.'; done; echo
  sleep 2
  [[ "$(ipc shinobi status)" == *'"state":"normal"'* ]] || note="✗ no quedó en modo normal: $(ipc shinobi status)"
}
s_oni() {
  for _ in $(seq 10); do ipc oni on >/dev/null; sleep 3; ipc oni off >/dev/null; sleep 3; printf '.'; done; echo
  sleep 2
  [[ "$(ipc oni status)" == *'"state":"normal"'* ]] && note="modo normal · perfil $(powerprofilesctl get 2>/dev/null)" \
    || note="✗ no quedó en modo normal: $(ipc oni status)"
}
s_net() {
  nmcli networking off; sleep 15; ipc shell status >/dev/null || note="✗ IPC sin red"
  nmcli networking on; sleep 8
  note="${note:-}red: $(nmcli -t -f STATE general 2>/dev/null)"
}
s_bt() {
  rfkill block bluetooth; sleep 8; rfkill unblock bluetooth; sleep 5
  note="bluetooth: $(rfkill list bluetooth | grep -c 'Soft blocked: no') radio(s) desbloqueada(s)"
}
s_player() {
  mpv --no-video --volume=0 --title=ocarina-prueba --force-media-title="Prueba de robustez" \
      'av://lavfi:sine=frequency=440:duration=60' >/dev/null 2>&1 &
  local pid=$!; sleep 5; kill -9 "$pid" 2>/dev/null; sleep 3
}
s_notifs() {
  # transient: they show as toasts but never reach your history
  for i in $(seq 100); do notify-send -e -u low -a "Prueba" "Prueba $i/100" "OcarinaShell · robustez" ; done
  sleep 8
  note="memoria de la shell: $(( $(systemctl --user show -p MemoryCurrent --value ocarinashell) / 1048576 )) MB"
}
s_fluido() {
  mpv --fs --loop --title="ocarina-prueba-fluido" 'av://lavfi:testsrc2=size=1920x1080:rate=30' >/dev/null 2>&1 &
  local pid=$!; sleep 4
  for _ in $(seq 20); do ipc nameraka toggle >/dev/null; sleep 3; printf '.'; done; echo
  ocarina nameraka on >/dev/null 2>&1; sleep 3
  echo "Fluido encendido con el vídeo a pantalla completa. Ahora tú: Alt+Tab un par de veces, la vista general"
  echo "(Super+Tab) y el bloqueo de prueba: ocarina lock test (Esc sale). Intro cuando acabes."
  read -r _
  ocarina nameraka off >/dev/null 2>&1; kill "$pid" 2>/dev/null
}
s_suspend() {
  local since; since="$(date '+%F %T')"
  echo "Suspende 5 veces (cierra la tapa o Dengen › Suspender; espera 10 s y despierta). Una de ellas con la tapa,"
  echo "y desenchufa y enchufa el cargador dos veces entre medias. Intro cuando hayas terminado."
  read -r _
  note="suspensiones: $(journalctl -k --since "$since" --no-pager -o cat | grep -c 'PM: suspend exit') · cargador: $(journalctl --user -u ocarinashell --since "$since" --no-pager -o cat | grep -ci 'cargador\|batería\|onBattery')"
}
s_fune() {
  echo "Abre el Bloc de notas de Windows desde Windows apagada; luego pausa la VM y ábrelo otra vez; luego con la VM"
  echo "en marcha. Lo hago yo con ocarina fune app notepad, tú solo miras (cada arranque en frío tarda ~1 min)."
  ocarina fune app notepad; read -r -p "¿Se abrió? Intro para pausar y repetir › " _
  ocarina fune pause; sleep 3; ocarina fune app notepad; read -r -p "¿Se abrió desde la pausa? Intro › " _
  ocarina fune app notepad; read -r -p "¿Se abrió con la VM activa? Intro › " _
  echo "Ahora Snake con la VM encendida (política de RAM):"
  ocarina snake ask "Dime en una frase cuánta RAM libre hay ahora mismo" 2>&1 | tail -n 3
  read -r -p "Intro para apagar la VM › " _
  ocarina fune stop
}

: > "$log"
echo "# Robustez · fase 17 · $(date '+%F %T') · $(qs --version | head -1) · $(niri --version)" | tee -a "$log"
run "Matar la shell con un panel abierto" "Abre Engawa y mata qs con SIGKILL; systemd debe relanzarla en ~1 s, sin modo seguro. (5 s)" s_kill
run "20 cambios de tema" "Recorre los 6 temas 20 veces y vuelve al tuyo. (~50 s)" s_themes
run "20 × Shinobi" "Enciende y apaga 忍 Shinobi 20 veces. La pantalla parpadeará a negro. (~80 s)" s_shinobi
run "10 × Oni" "Enciende y apaga 鬼 Oni 10 veces. (~60 s)" s_oni
run "Sin red" "Apaga la red 15 s y la vuelve a encender. Claude Code se queda en pausa mientras tanto. (~25 s)" s_net
run "Bluetooth por rfkill" "Bloquea el Bluetooth 8 s y lo desbloquea. (~15 s)" s_bt
run "Reproductor que desaparece" "Un tono silencioso en mpv (sale en la isla) y lo mato con SIGKILL. (~8 s)" s_player
run "100 notificaciones" "100 avisos efímeros seguidos (no se guardan en tu historial). (~15 s)" s_notifs
run "20 × Fluido con vídeo" "Una imagen de prueba a pantalla completa en mpv, Fluido 20 veces y después tus Alt+Tab, vista general y bloqueo de prueba. (~2 min)" s_fluido
run "5 suspensiones, tapa y cargador" "Lo haces tú; yo solo cuento en el journal." s_suspend
run "船 Fune y Snake con la VM" "Apps de Windows desde apagada, en pausa y activa; Snake con la VM encendida. (~4 min)" s_fune
finish
