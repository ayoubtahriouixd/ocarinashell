#!/usr/bin/env bash
# OcarinaShell · fase 13 · greeter dry run. Run as: sudo bash scripts/root/probar-greeter.sh   (from niri is fine)
# Starts greetd with the greeter on vt 7 (a separate unit: your session on tty1 is not touched) and switches there.
# Type a wrong password first (it must shake and say «Contraseña incorrecta»), then your real one: it says
# «✓ Contraseña correcta · prueba terminada» and nothing is started. Then it stops by itself and brings you back to
# tty1. If you get stuck: Ctrl+Alt+F1 brings your session back; the test ends alone after 3 minutes.
set -euo pipefail
# shellcheck source=scripts/root/lib-arranque.sh
source "$(dirname "${BASH_SOURCE[0]}")/lib-arranque.sh"
need_root

[[ -f /etc/systemd/system/ocarina-greeter-test.service ]] || die "primero: sudo bash $REPO/scripts/root/greeter.sh instalar"
back=$(fgconsole 2>/dev/null || echo 1)
stop_test() {
  systemctl stop ocarina-greeter-test.service 2>/dev/null || true
  chvt "$back" 2>/dev/null || true
}
trap stop_test EXIT

rm -f /run/ocarina-greeter/test-done
since=$(date '+%F %T')
systemctl start ocarina-greeter-test.service
echo "Greeter de prueba en vt 7. Prueba una contraseña mala y luego la buena."
for _ in $(seq 1 180); do
  [[ -e /run/ocarina-greeter/test-done ]] && break
  systemctl is-active --quiet ocarina-greeter-test.service || break
  sleep 1
done
ok=0
[[ -e /run/ocarina-greeter/test-done ]] && ok=1
sleep 2
stop_test
trap - EXIT

dest="$OWNER_HOME/.cache/ocarinashell"
install -d -o "$OWNER" -g "$(id -gn "$OWNER")" "$dest"
# two queries: -t and -u together would have to match the same line (none does)
{ journalctl --since "$since" -u ocarina-greeter-test.service --no-pager -o short-monotonic
  journalctl --since "$since" -t ocarina-greeter --no-pager -o short-monotonic; } > "$dest/greeter-prueba.log" 2>&1 || true
chown "$OWNER:" "$dest/greeter-prueba.log"
if ((ok)); then
  echo "✓ El greeter autenticó con greetd y PAM (nada se ha lanzado)."
else
  echo "✗ La prueba no terminó con una contraseña correcta (¿tiempo agotado o cerrado a mano?)."
fi
echo "Registro en $dest/greeter-prueba.log. Dile «hecho» a Claude Code."
