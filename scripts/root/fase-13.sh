#!/usr/bin/env bash
# OcarinaShell · fase 13 · boot theme in one go. Run as: sudo bash scripts/root/fase-13.sh [dark|light] [--timeout N]
# 1) Limine theme (limine-tema.sh) and 2) Plymouth theme + kernel line + initramfs (plymouth-tema.sh). Each one takes
# its own snapper snapshot and copies; both are idempotent and have --uninstall. The greeter is a separate step
# (greeter.sh) after you have seen Plymouth working (probar-plymouth.sh from a text console).
# Same as `ocarina-boot-theme apply …`, which picks the variant from the current OcarinaShell theme.
set -euo pipefail
here=$(dirname "${BASH_SOURCE[0]}")
variant=dark timeout=3
while (($#)); do
  case $1 in
    dark|light) variant=$1 ;;
    --timeout) timeout=${2:?}; shift ;;
    *) echo "argumento desconocido: $1" >&2; exit 1 ;;
  esac
  shift
done
bash "$here/limine-tema.sh" "$variant" --timeout "$timeout"
bash "$here/plymouth-tema.sh" "$variant"
