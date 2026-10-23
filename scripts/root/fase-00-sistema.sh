#!/usr/bin/env bash
# OcarinaShell · fase 00 · run as: sudo bash scripts/root/fase-00-sistema.sh
# Idempotent. Steps:
#   1. snapper snapshot
#   2. rank CachyOS + Arch mirrors with cachyos-rate-mirrors (fastest from this connection)
#   3. full system upgrade (pacman -Syu): never partial upgrades (docs/06-ACTUALIZACIONES, capa 2)
#   4. verify the CachyOS hook regenerated the Limine entries for every installed kernel (incl. LTS)
set -euo pipefail

if [[ $EUID -ne 0 ]]; then
  echo "Ejecútalo con: sudo bash $0" >&2
  exit 1
fi

say() { printf '\n\e[1;31m▌\e[0m \e[1m%s\e[0m\n' "$*"; }

say "1/4 Snapshot de snapper"
snapper -c root create -d "ocarinashell: fase 00, antes de mirrors + actualización" --print-number

say "2/4 Mirrors más rápidos (cachyos-rate-mirrors)"
if command -v cachyos-rate-mirrors >/dev/null; then
  # The tool backs up the previous mirrorlists itself (*.backup) and rewrites them.
  cachyos-rate-mirrors || echo "⚠ cachyos-rate-mirrors falló; se mantienen los mirrors actuales."
else
  echo "cachyos-rate-mirrors no está instalado; se omite."
fi

say "3/4 Actualización completa (pacman -Syu)"
pacman -Syu --noconfirm

say "4/4 Comprobación de entradas de Limine"
conf=/boot/limine.conf
fail=0
for k in /usr/lib/modules/*/pkgbase; do
  pkg=$(<"$k")
  if grep -q "kernel-id=${pkg}\b" "$conf"; then
    echo "✓ ${pkg}: entrada presente en ${conf}"
  else
    echo "✗ ${pkg}: SIN entrada en ${conf}"; fail=1
  fi
done
grep -E '^\s*comment: Kernel version' "$conf" | head -4

if (( fail )); then
  echo -e "\n⚠ Falta alguna entrada. NO reinicies; avisa a Claude." >&2
  exit 1
fi
echo -e "\nListo. No hace falta reiniciar ahora (kernel-modules-hook conserva los módulos del kernel en uso)."
