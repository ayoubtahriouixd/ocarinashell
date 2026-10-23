#!/usr/bin/env bash
# OcarinaShell · fase 13 · Plymouth theme. Run as: sudo bash scripts/root/plymouth-tema.sh [dark|light]
#                                                    sudo bash scripts/root/plymouth-tema.sh --uninstall
# Idempotent. What it does:
#   1. snapper snapshot + copies of the boot configs in ~/ocarinashell-backup-boot-<date>/
#   2. checks: plymouth installed, mkinitcpio HOOKS with `kms` before `plymouth` (amdgpu early, native resolution)
#   3. /usr/share/plymouth/themes/ocarinashell/ ← assets/boot/plymouth/ocarinashell/ with `variant` set
#   4. /etc/plymouth/plymouthd.conf: Theme=ocarinashell, DeviceScale=1 (at ~240 ppi Plymouth would pick scale 2 and
#      the script would draw at 1440×900 and be upscaled: blurry), ShowDelay=0. The previous file is kept in
#      /var/lib/ocarinashell/plymouthd.conf.previo for --uninstall.
#   5. /etc/default/limine KERNEL_CMDLINE[default]: keeps CachyOS's parameters and adds the silence ones
#      (loglevel=3 rd.udev.log_level=3 udev.log_level=3 systemd.show_status=error rd.systemd.show_status=error
#      vt.global_cursor_default=0); `quiet splash` are already there.
#   6. initramfs + Limine entries with CachyOS's own tool (limine-mkinitcpio: it also refreshes the checksums and the
#      cmdline that /boot/limine.conf carries) and checks with lsinitcpio that the theme is inside every image.
# Undo: --uninstall (previous plymouthd.conf, theme directory removed, initramfs rebuilt; the silence parameters stay —
# they are harmless; remove them by hand from /etc/default/limine if you want the old text back).
set -euo pipefail
# shellcheck source=scripts/root/lib-arranque.sh
source "$(dirname "${BASH_SOURCE[0]}")/lib-arranque.sh"

variant=dark uninstall=0
for a in "$@"; do
  case $a in
    dark|light) variant=$a ;;
    --uninstall) uninstall=1 ;;
    *) die "argumento desconocido: $a" ;;
  esac
done
need_root
THEME_DIR=/usr/share/plymouth/themes/ocarinashell
PLY_CONF=/etc/plymouth/plymouthd.conf
PLY_PREV=/var/lib/ocarinashell/plymouthd.conf.previo
DEFAULT_LIMINE=/etc/default/limine
SILENCE=(loglevel=3 rd.udev.log_level=3 udev.log_level=3 systemd.show_status=error rd.systemd.show_status=error
         vt.global_cursor_default=0)

say "1/6 Snapshot y copias"
snapshot "fase 13, antes del tema de Plymouth ($([[ $uninstall == 1 ]] && echo quitar || echo "$variant"))"
backup_boot
install -d -m 0755 /var/lib/ocarinashell

say "2/6 Comprobaciones"
pacman -Q plymouth >/dev/null || die "falta el paquete plymouth"
command -v limine-mkinitcpio >/dev/null || die "falta limine-mkinitcpio (limine-mkinitcpio-hook)"
hooks=$(sed -n 's/^HOOKS=(\(.*\))/\1/p' /etc/mkinitcpio.conf)
for d in /etc/mkinitcpio.conf.d/*.conf; do
  [[ -f $d ]] && h=$(sed -n 's/^HOOKS=(\(.*\))/\1/p' "$d") && [[ -n $h ]] && hooks=$h
done
echo "  HOOKS=($hooks)"
[[ " $hooks " == *" plymouth "* ]] || die "el hook plymouth no está en HOOKS: añádelo tras kms (o pídeselo a Claude)"
[[ " $hooks " == *" kms "* ]] || die "falta el hook kms (amdgpu temprano)"
k=${hooks%% plymouth *}
[[ " $k " == *" kms "* ]] || die "kms debe ir antes que plymouth"
echo "  ✓ plymouth $(pacman -Q plymouth | cut -d' ' -f2) · kms antes de plymouth"

if ((uninstall)); then
  say "3/6 Quitar el tema"
  if [[ -f $PLY_PREV ]]; then cp -p "$PLY_PREV" "$PLY_CONF"; else printf '[Daemon]\nTheme=cachyos\n' > "$PLY_CONF"; fi
  rm -rf --one-file-system "$THEME_DIR"
  echo "  plymouthd.conf restaurado · $THEME_DIR eliminado"
  say "4/6 (nada que hacer)"
  say "5/6 (la línea del kernel se queda como está)"
else
  say "3/6 Tema → $THEME_DIR ($variant)"
  src="$REPO/assets/boot/plymouth/ocarinashell"
  [[ -f $src/ocarinashell.script ]] || die "falta $src"
  stage=$(mktemp -d /usr/share/plymouth/themes/.ocarinashell.XXXXXX)
  cp "$src"/*.png "$src"/ocarinashell.plymouth "$src"/ocarinashell.script "$stage/"
  sed -i -E "s/^variant = \"[a-z]+\";/variant = \"$variant\";/" "$stage/ocarinashell.script"
  grep -q "^variant = \"$variant\";" "$stage/ocarinashell.script" || die "no pude fijar la variante"
  chmod 0755 "$stage"; chmod 0644 "$stage"/*
  rm -rf --one-file-system "$THEME_DIR"
  mv "$stage" "$THEME_DIR"
  echo "  $(find "$THEME_DIR" -type f | wc -l) ficheros, $(du -sh "$THEME_DIR" | cut -f1)"

  say "4/6 $PLY_CONF"
  if [[ ! -f $PLY_PREV ]] && ! grep -q '^Theme=ocarinashell' "$PLY_CONF" 2>/dev/null; then
    cp -p "$PLY_CONF" "$PLY_PREV" 2>/dev/null || true
  fi
  cat > "$PLY_CONF" <<'EOF'
# OcarinaShell (fase 13) — scripts/root/plymouth-tema.sh. Previous file: /var/lib/ocarinashell/plymouthd.conf.previo
[Daemon]
Theme=ocarinashell
# 2880×1800 at ~240 ppi: without this Plymouth picks scale 2 and the theme is drawn at 1440×900 and upscaled (blurry)
DeviceScale=1
ShowDelay=0
DeviceTimeout=8
EOF
  sed 's/^/  │ /' "$PLY_CONF"

  say "5/6 Línea del kernel ($DEFAULT_LIMINE)"
  grep -qE '^KERNEL_CMDLINE\[default\]\+?=' "$DEFAULT_LIMINE" || die "no hay KERNEL_CMDLINE[default] en $DEFAULT_LIMINE"
  for p in "${SILENCE[@]}"; do
    key=${p%%=*}
    line=$(grep -E '^KERNEL_CMDLINE\[default\]\+?=' "$DEFAULT_LIMINE")
    if [[ $line =~ [\ \"]${key//./\\.}= ]]; then
      sed -i -E "/^KERNEL_CMDLINE\[default\]\+?=/ s/([ \"])${key//./\\.}=[^ \"]*/\1$p/" "$DEFAULT_LIMINE"
    else
      sed -i -E "/^KERNEL_CMDLINE\[default\]\+?=/ s/\"[[:space:]]*$/ $p\"/" "$DEFAULT_LIMINE"
    fi
  done
  line=$(grep -E '^KERNEL_CMDLINE\[default\]\+?=' "$DEFAULT_LIMINE")
  echo "  $line"
  for p in quiet splash "${SILENCE[@]}"; do
    [[ $line == *" $p"* || $line == *"\"$p"* ]] || die "falta $p en la línea del kernel"
  done
fi

say "6/6 Initramfs y entradas de Limine (limine-mkinitcpio)"
exec 9>"$BOOT_LOCK.ocarina"            # serialise with our own scripts only: limine-mkinitcpio takes the real lock itself
flock -w 60 9 || die "otro script de OcarinaShell está tocando el arranque"
limine-mkinitcpio
bad=0
while IFS= read -r img; do
  list=$(lsinitcpio "$img" 2>/dev/null)
  if ((uninstall)); then
    if grep -q 'usr/share/plymouth/themes/ocarinashell/' <<<"$list"; then echo "  ✗ $img aún lleva el tema" >&2; bad=1
    else echo "  ✓ $img sin el tema"; fi
  elif grep -qx 'usr/share/plymouth/themes/ocarinashell/ocarinashell.script' <<<"$list" \
       && grep -qx 'usr/lib/plymouth/script.so' <<<"$list" \
       && grep -qx 'usr/share/plymouth/themes/ocarinashell/body.png' <<<"$list"; then
    echo "  ✓ $img lleva el tema (script.so + capas)"
  else
    echo "  ✗ $img NO lleva el tema" >&2; bad=1
  fi
done < <(current_initramfs)
if ! ((uninstall)); then
  n=$(grep -c 'cmdline:.*vt.global_cursor_default=0' "$LIMINE_CONF" || true)
  if ((n >= 1)); then echo "  ✓ $n entradas de Limine con la línea nueva"
  else warn "las entradas aún no tienen la línea nueva (no es peligroso: solo se verían mensajes); ejecuta «sudo limine-update»"; fi
fi
grep -q '^# ── OcarinaShell · tema de Limine' "$LIMINE_CONF" && echo "  ✓ el tema de Limine sigue en limine.conf" || true
((bad == 0)) || die "Algo no cuadra: NO reinicies y avisa a Claude (la copia está en ~/ocarinashell-backup-boot-$(date +%F)/)."
echo
echo "Listo. Antes de reiniciar, pruébalo sin reiniciar: Ctrl+Alt+F3, entra como $OWNER y ejecuta"
echo "  sudo bash $REPO/scripts/root/probar-plymouth.sh"
echo "Luego vuelve con Ctrl+Alt+F1 (o F2) y dile «hecho» a Claude Code."
