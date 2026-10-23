#!/usr/bin/env bash
# OcarinaShell · fase 14 · blindaje: everything that needs root, in one go. Run as:
#   sudo bash ~/ocarinashell/scripts/root/fase-14.sh
# Idempotent (run it again after pulling changes). In order:
#   1. snapshot «ocarinashell: fase 14, antes de instalar el blindaje»
#   2. system files (scripts/install-system.sh): ocarina-maint (Mamori's root helper), ocarina-needs-check and the pacman
#      hook /etc/pacman.d/hooks/90-ocarinashell.hook (smoke tests after every transaction)
#   3. sudoers rule /etc/sudoers.d/91-ocarina-maint: NOPASSWD for /usr/local/libexec/ocarina-maint ONLY, checked with
#      `visudo -c` before it is installed (the temporary 90-ocarinashell-temporal stays until phase 17)
#   4. snapper for @home (scripts/root/snapper-home.sh instalar): hourly snapshots of ~ (控 Hikae, D-070)
#   5. the greeter's copy in /usr/local/share (scripts/root/greeter.sh actualizar): fixes of the phase 14 audit
#   6. checks: the helper through sudo -n as you, 20 malicious calls refused through sudo, boot-check, last-pair
# Nothing here touches /boot, the initramfs, the kernel command line or PAM.
set -euo pipefail
export LC_ALL=C

repo="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
[[ $EUID -eq 0 ]] || { echo "Ejecútalo con: sudo bash $0" >&2; exit 1; }
user="${SUDO_USER:-}"
[[ -n "$user" && "$user" != root ]] || { echo "lánzalo con sudo desde tu usuario (necesito SUDO_USER)" >&2; exit 1; }
[[ "$user" =~ ^[a-z_][a-z0-9_-]*$ ]] || { echo "nombre de usuario raro: $user" >&2; exit 1; }
say() { printf '\n\e[1;31m▌\e[0m \e[1m%s\e[0m\n' "$*"; }
die() { printf '\e[31m  ✗ %s\e[0m\n' "$*" >&2; exit 1; }
helper=/usr/local/libexec/ocarina-maint

say "1/6 Snapshot"
snapper -c root create -d "ocarinashell: fase 14, antes de instalar el blindaje" >/dev/null && echo "  hecho"

say "2/6 Ficheros de sistema (ocarina-maint, hook de pacman)"
bash "$repo/scripts/install-system.sh"
[[ -x "$helper" && -f /etc/pacman.d/hooks/90-ocarinashell.hook ]] || die "no se instalaron el ayudante o el hook"

say "3/6 Regla de sudo mínima para ocarina-maint"
bash "$repo/scripts/root/mamori-sudo.sh" "$user"
echo "  visudo -c: todo el sudoers es válido"

say "4/6 Snapshots de ~ (snapper «home»)"
bash "$repo/scripts/root/snapper-home.sh" instalar

say "5/6 Greeter (copia en /usr/local/share)"
if [[ -f /usr/local/share/ocarinashell/greeter/shell.qml ]]; then
  bash "$repo/scripts/root/greeter.sh" actualizar
else
  echo "  el greeter no está instalado: nada que actualizar"
fi

say "6/6 Comprobaciones"
as_user() { sudo -u "$user" -H -- "$@"; }
as_user sudo -n "$helper" help >/dev/null || die "sudo -n ocarina-maint no funciona como $user"
echo "  ✓ $user llama a ocarina-maint sin contraseña"
if as_user sudo -n -l /usr/bin/id >/dev/null 2>&1 && [[ ! -e /etc/sudoers.d/90-ocarinashell-temporal ]]; then
  die "$user puede ejecutar otras órdenes sin contraseña: revisa /etc/sudoers.d"
fi
out="$(as_user bash "$repo/tests/ocarina-maint-mal.sh" "sudo -n $helper" 2>&1 || true)"
tail -n 1 <<<"$out" | sed 's/^/  /'
grep -q 'aceptadas por error: 0' <<<"$out" || { printf '%s\n' "$out"; die "alguna llamada maliciosa NO fue rechazada"; }
as_user sudo -n "$helper" boot-check | sed 's/^/  boot-check: /'
as_user sudo -n "$helper" last-pair | sed 's/^/  last-pair: /'
journalctl -t ocarina-maint -n 3 -o cat --no-pager | sed 's/^/  journal: /'
echo
echo "Listo. Dile «hecho» a Claude Code."
