#!/usr/bin/env bash
# OcarinaShell · fase 16 · 守 Mamori: what needs root, in one go. Run as:
#   sudo bash ~/ocarinashell/scripts/root/fase-16.sh            install / update (idempotent)
#   sudo bash ~/ocarinashell/scripts/root/fase-16.sh sin-sudo   criterion «Mamori with the minimal rule only»: moves
#        /etc/sudoers.d/90-ocarinashell-temporal aside for N minutes (default 20) and puts it back by itself with a
#        root timer (or earlier with `… con-sudo`). Only that temporary drop-in is touched; phase 17 deletes it.
#   sudo bash ~/ocarinashell/scripts/root/fase-16.sh con-sudo   puts the temporary drop-in back now
# Install, in order:
#   1. snapshot «ocarinashell: fase 16, antes de instalar Mamori»
#   2. system files (scripts/install-system.sh): the new ocarina-maint (aur-build, unit-restart, time-sync, paccache 2|3,
#      health with snapshots; refuses to upgrade while a file:// repo is writable by a user)
#   3. the local AUR repo /var/lib/repo/ocarina-aur becomes root's alone: until now Ayoub's user owned it, and
#      `ocarina-maint upgrade` (pacman -Syu as root, no password) would have installed whatever a user process put there
#   4. checks: 32 malicious calls refused through sudo -n, health JSON, upgrade's repo check
# Nothing here touches /boot, the initramfs, the kernel command line, PAM or the sudoers rule of the helper.
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
temporal=/etc/sudoers.d/90-ocarinashell-temporal
parked=/root/90-ocarinashell-temporal.aparcado
as_user() { sudo -u "$user" -H -- "$@"; }

case "${1:-instalar}" in
  sin-sudo)
    mins="${2:-20}"
    if ! [[ "$mins" =~ ^[0-9]{1,3}$ ]] || ((mins < 1 || mins > 240)); then die "minutos: 1–240"; fi
    [[ -f "$temporal" ]] || die "no hay drop-in temporal que aparcar (¿ya se quitó?)"
    install -o root -g root -m 0400 "$temporal" "$parked"
    rm -f "$temporal"
    visudo -cq || { install -o root -g root -m 0440 "$parked" "$temporal"; die "visudo -c falla: lo devuelvo"; }
    # put it back by itself even if nobody remembers (phase 17 is the one that removes it for good)
    systemd-run --quiet --collect --unit=ocarinashell-sudo-temporal-vuelve --on-active="${mins}m" \
      /usr/bin/bash "$repo/scripts/root/fase-16.sh" con-sudo-auto
    echo "  drop-in temporal aparcado ${mins} min (vuelve solo; antes: sudo bash $0 con-sudo)"
    if as_user sudo -n -l /usr/bin/id >/dev/null 2>&1; then die "aún hay sudo general sin contraseña: revisa /etc/sudoers.d"; fi
    as_user sudo -n "$helper" help >/dev/null && echo "  ✓ solo queda la regla del ayudante (sudo -n ocarina-maint funciona)"
    exit 0 ;;
  con-sudo|con-sudo-auto)
    if [[ -f "$parked" ]]; then
      install -o root -g root -m 0440 "$parked" "$temporal"
      visudo -cq || { rm -f "$temporal"; die "visudo -c falla con el drop-in: no lo devuelvo"; }
      rm -f "$parked"
      echo "  drop-in temporal de vuelta"
    else
      echo "  no estaba aparcado"
    fi
    [[ "$1" == con-sudo ]] && systemctl stop ocarinashell-sudo-temporal-vuelve.timer 2>/dev/null || true
    exit 0 ;;
  instalar) ;;
  *) die "uso: sudo bash $0 [instalar|sin-sudo [min]|con-sudo]" ;;
esac

say "1/4 Snapshot"
snapper -c root create -d "ocarinashell: fase 16, antes de instalar Mamori" >/dev/null && echo "  hecho"

say "2/4 Ficheros de sistema (ocarina-maint nuevo)"
bash "$repo/scripts/install-system.sh"
cmp -s "$repo/system/usr/local/libexec/ocarina-maint" "$helper" || die "el ayudante instalado no coincide con el del repo"
echo "  ✓ $helper al día"

say "3/4 Repo local del AUR solo de root"
aur=/var/lib/repo/ocarina-aur
if [[ -d "$aur" ]]; then
  chown -hR root:root "$aur"
  find "$aur" ! -type l -exec chmod go-w {} +
  # symlinks always show 0777 (their mode means nothing): only their owner counts
  bad="$(find "$aur" \( ! -user root -o \( ! -type l -perm /022 \) \) -print -quit)"
  [[ -z "$bad" ]] || die "aún hay algo escribible en $aur: $bad"
  echo "  ✓ $aur: root:root, sin escritura para otros"
else
  echo "  no existe $aur (sin paquetes del AUR): nada que hacer"
fi

say "4/4 Comprobaciones"
as_user sudo -n "$helper" help >/dev/null || die "sudo -n ocarina-maint no funciona como $user"
out="$(as_user bash "$repo/tests/ocarina-maint-mal.sh" "sudo -n $helper" 2>&1 || true)"
tail -n 1 <<<"$out" | sed 's/^/  /'
grep -q 'aceptadas por error: 0' <<<"$out" || { printf '%s\n' "$out"; die "alguna llamada maliciosa NO fue rechazada"; }
as_user sudo -n "$helper" health | sed 's/^/  health: /'
journalctl -t ocarina-maint -n 2 -o cat --no-pager | sed 's/^/  journal: /'
echo
echo "Listo. Dile «hecho» a Claude Code."
