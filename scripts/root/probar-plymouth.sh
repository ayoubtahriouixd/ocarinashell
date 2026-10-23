#!/usr/bin/env bash
# OcarinaShell · fase 13 · try the Plymouth theme WITHOUT rebooting. Run it from a text console, never from niri:
#   Ctrl+Alt+F3 → log in as yourself → sudo bash ~/ocarinashell/scripts/root/probar-plymouth.sh → back: Ctrl+Alt+F1
# For each mode (arranque, apagado, reinicio) it starts a real plymouthd on this console with --debug, shows the splash
# 8 s; in «arranque» also a system message and a password prompt (type anything: it is thrown away, it only shows the
# petals). Then it quits and checks /var/log/plymouth-debug.log for script errors. Nothing is installed or changed.
# The log is copied to ~/.cache/ocarinashell/plymouth-debug.log so Claude Code can read it.
set -euo pipefail
# shellcheck source=scripts/root/lib-arranque.sh
source "$(dirname "${BASH_SOURCE[0]}")/lib-arranque.sh"
need_root

tty=$(tty 2>/dev/null || true)
[[ $tty == /dev/tty[0-9]* ]] || die "ejecútalo desde una consola de texto (Ctrl+Alt+F3), no desde una terminal de niri ($tty)"
[[ $(sed -n 's/^Theme=//p' /etc/plymouth/plymouthd.conf) == ocarinashell ]] \
  || die "el tema activo no es ocarinashell: ejecuta antes scripts/root/plymouth-tema.sh"
! pgrep -x plymouthd >/dev/null || die "ya hay un plymouthd en marcha"

LOG=/var/log/plymouth-debug.log
: > "$LOG"
cleanup() { plymouth quit 2>/dev/null || true; sleep 0.5; pkill -x plymouthd 2>/dev/null || true; }
trap cleanup EXIT

run_mode() {   # $1 = boot | shutdown | reboot
  local daemon_mode=$1
  [[ $1 == reboot ]] && daemon_mode=shutdown
  printf '\n▌ Modo %s (8 s)…\n' "$1"
  plymouthd --mode="$daemon_mode" --tty="$tty" --debug --debug-file="$LOG" --no-boot-log
  sleep 0.3
  [[ $1 == reboot ]] && plymouth change-mode --reboot
  plymouth show-splash
  sleep 8
  if [[ $1 == boot ]]; then
    plymouth display-message --text="Prueba de mensaje del sistema · OcarinaShell"
    sleep 3
    plymouth hide-message --text="Prueba de mensaje del sistema · OcarinaShell" || true
    # the typed text goes to /dev/null: this is only to see the petals
    plymouth ask-for-password --prompt="Prueba · escribe algo y pulsa Intro" --number-of-tries=1 >/dev/null || true
    sleep 1
  fi
  plymouth quit
  sleep 1
  pkill -x plymouthd 2>/dev/null || true
}

for m in boot shutdown reboot; do run_mode "$m"; done
trap - EXIT

errors=$(grep -iE 'script.*(error|failed|unknown)|parse error|could not (load|open)|failed to load' "$LOG" || true)
renderer=$(grep -oE 'renderers/[a-z-]+\.so' "$LOG" | sort -u | tr '\n' ' ' || true)
res=$(grep -oE '[0-9]{3,4}x[0-9]{3,4}' "$LOG" | sort | uniq -c | sort -rn | head -3 | tr -s ' ' | tr '\n' ';' || true)
dest="$OWNER_HOME/.cache/ocarinashell"
install -d -o "$OWNER" -g "$(id -gn "$OWNER")" "$dest"
install -m 0644 -o "$OWNER" "$LOG" "$dest/plymouth-debug.log"
echo
echo "Renderer: ${renderer:-?} · tamaños vistos: ${res:-?}"
if [[ -n $errors ]]; then
  echo "✗ Errores en el log:"; echo "$errors" | head -20
else
  echo "✓ Sin errores del script en el log."
fi
echo "Log copiado en $dest/plymouth-debug.log. Vuelve con Ctrl+Alt+F1 y dile «hecho» a Claude Code."
