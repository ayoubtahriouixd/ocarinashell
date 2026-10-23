#!/usr/bin/env bash
# OcarinaShell · fase 13 · robustness: does the boot theme survive a kernel update? Run as:
#   sudo bash scripts/root/probar-kernel.sh
# snapper snapshot → `pacman -S linux-cachyos` (a reinstall of the same version: pacman's own hooks rebuild the
# initramfs and limine-entry-tool rewrites /boot/limine.conf exactly as on a real update) → checks:
#   1. the OcarinaShell block is still at the top of limine.conf and its wallpaper exists
#   2. every initramfs Limine boots carries the ocarinashell Plymouth theme (script.so + layers)
#   3. the kernel entries keep the quiet/splash/silence parameters
# Phase 14 runs the same checks in the smoke tests (read-only).
set -euo pipefail
# shellcheck source=scripts/root/lib-arranque.sh
source "$(dirname "${BASH_SOURCE[0]}")/lib-arranque.sh"
need_root

say "1/3 Snapshot"
snapshot "fase 13, antes de reinstalar linux-cachyos (prueba del tema)"
say "2/3 Reinstalar linux-cachyos"
pacman -S --noconfirm linux-cachyos
say "3/3 Comprobaciones"
bad=0
if grep -q '^# ── OcarinaShell · tema de Limine' "$LIMINE_CONF" && [[ -f /boot/ocarinashell-limine.png ]]; then
  echo "  ✓ el tema de Limine sigue en limine.conf"
else
  echo "  ✗ el tema de Limine ha desaparecido" >&2; bad=1
fi
while IFS= read -r img; do
  list=$(lsinitcpio "$img" 2>/dev/null)
  if grep -qx 'usr/share/plymouth/themes/ocarinashell/ocarinashell.script' <<<"$list" \
     && grep -qx 'usr/lib/plymouth/script.so' <<<"$list"; then
    echo "  ✓ $img lleva el tema"
  else
    echo "  ✗ $img NO lleva el tema" >&2; bad=1
  fi
done < <(current_initramfs)
n=$(sed '/limine_history/,$d' "$LIMINE_CONF" | grep -c 'cmdline:.*splash.*vt.global_cursor_default=0' || true)
if ((n >= 1)); then echo "  ✓ $n entradas con la línea silenciosa"; else echo "  ✗ las entradas perdieron la línea" >&2; bad=1; fi
((bad == 0)) || die "Algo no ha sobrevivido: NO reinicies y avisa a Claude."
echo "Todo sobrevive a la reinstalación del kernel. Dile «hecho» a Claude Code."
