#!/usr/bin/env bash
# OcarinaShell · fase 11 · run as: sudo bash scripts/root/fase-11.sh
# Idempotent. Lets 鬼 Oni put the ThinkPad fan at full speed (Ajustes › Oni › «Ventilador al máximo», off by default).
#   1. snapper snapshot
#   2. /etc/modprobe.d/ocarina-thinkpad.conf: `options thinkpad_acpi fan_control=1`. Without it /proc/acpi/ibm/fan is
#      read-only. The firmware keeps its own thermal protection; the helper only writes «level full-speed» on AC and
#      «level auto» when Oni ends (ocarina-powerctl fan auto|full).
#   3. thinkpad_acpi is loaded from the initramfs (it comes in with amdgpu/video), so the option must be inside it too:
#      the initramfs of every kernel is rebuilt with CachyOS's own tool (limine-mkinitcpio: it also refreshes the
#      checksums that /boot/limine.conf verifies — a plain mkinitcpio would break them) and checked with lsinitcpio.
#   4. Effective after the next reboot (the parameter cannot change while the module is loaded).
# Undo: sudo rm /etc/modprobe.d/ocarina-thinkpad.conf && sudo limine-mkinitcpio (and reboot).
set -euo pipefail

if [[ $EUID -ne 0 ]]; then
  echo "Ejecútalo con: sudo bash $0" >&2
  exit 1
fi

say() { printf '\n\e[1;31m▌\e[0m \e[1m%s\e[0m\n' "$*"; }
conf=/etc/modprobe.d/ocarina-thinkpad.conf
want='options thinkpad_acpi fan_control=1'

say "1/4 Snapshot de snapper"
snapper -c root create -d "ocarinashell: fase 11, antes de thinkpad_acpi fan_control=1" --print-number

say "2/4 $conf"
if [[ -f "$conf" ]] && grep -qxF "$want" "$conf"; then
  echo "ya está"
else
  printf '# OcarinaShell (fase 11): 鬼 Oni can set the fan to full speed (ocarina-powerctl fan auto|full)\n%s\n' "$want" > "$conf"
  chmod 0644 "$conf"
  echo "escrito"
fi

say "3/4 Initramfs (limine-mkinitcpio) y comprobación"
command -v limine-mkinitcpio >/dev/null || { echo "falta limine-mkinitcpio (limine-mkinitcpio-hook)" >&2; exit 1; }
limine-mkinitcpio
bad=0
while IFS= read -r img; do
  if lsinitcpio "$img" 2>/dev/null | grep -qx 'etc/modprobe.d/ocarina-thinkpad.conf'; then
    echo "  ✓ $img"
  else
    echo "  ✗ $img no lleva la opción" >&2; bad=1
  fi
done < <(sed -n 's/^[[:space:]]*module_path: boot():\([^#]*initramfs[^#]*\).*/\/boot\1/p' /boot/limine.conf | grep -v limine_history | sort -u)   # the ones Limine boots now
((bad == 0)) || { echo "Algún initramfs no lleva la opción: NO reinicies y avisa a Claude." >&2; exit 1; }

say "4/4 Listo"
echo "Reinicia cuando te venga bien. Después: cat /proc/acpi/ibm/fan debe listar «commands: level …»."
echo "Vuelve a Claude Code y dile «hecho»."
