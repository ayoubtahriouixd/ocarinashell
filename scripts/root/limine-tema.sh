#!/usr/bin/env bash
# OcarinaShell · fase 13 · Limine theme. Run as: sudo bash scripts/root/limine-tema.sh [dark|light] [--timeout N]
#                                                 sudo bash scripts/root/limine-tema.sh --uninstall
# Idempotent. What it does:
#   1. snapper snapshot + copies of the boot configs in ~/ocarinashell-backup-boot-<date>/
#   2. /boot/ocarinashell-limine.png ← assets/boot/limine/ocarinashell-limine-<variant>.png (same partition: boot():/)
#   3. /boot/limine.conf: the block between «# ── OcarinaShell · tema de Limine» and «# ── fin del tema OcarinaShell» goes
#      at the very top; the previous look (CachyOS's term_*/wallpaper/interface_* lines) is removed and saved in
#      /var/lib/ocarinashell/limine-aspecto-previo.conf for --uninstall; `timeout` set; duplicate global keys removed.
#      The entries are left byte for byte (checked) and the file is replaced atomically under the same lock that
#      limine-entry-tool / limine-snapper-sync take. Those tools keep everything above the first entry when they
#      regenerate the file (DECISIONES D-063), so the theme survives kernel updates and new snapshots.
# Undo: --uninstall (puts the previous look and timeout back and removes the PNG).
set -euo pipefail
# shellcheck source=scripts/root/lib-arranque.sh
source "$(dirname "${BASH_SOURCE[0]}")/lib-arranque.sh"

variant=dark timeout=3 uninstall=0
while (($#)); do
  case $1 in
    dark|light) variant=$1 ;;
    --timeout) timeout=${2:?}; shift ;;
    --uninstall) uninstall=1 ;;
    *) die "argumento desconocido: $1" ;;
  esac
  shift
done
[[ $timeout =~ ^([0-9]|10)$ ]] || die "--timeout entre 0 y 10"
need_root
[[ -f $LIMINE_CONF ]] || die "no existe $LIMINE_CONF"
command -v python3 >/dev/null || die "falta python3"

say "1/4 Snapshot y copias"
snapshot "fase 13, antes del tema de Limine ($([[ $uninstall == 1 ]] && echo quitar || echo "$variant"))"
backup_boot
install -d -m 0755 "$(dirname "$SAVED_LOOK")"
cp -p "$LIMINE_CONF" "/var/lib/ocarinashell/limine.conf.$(date +%Y%m%d-%H%M%S)"

exec 9>"$BOOT_LOCK"
flock -w 60 9 || die "otra herramienta de Limine tiene el fichero ocupado; inténtalo en un minuto"

tmp=$LIMINE_CONF.ocarina-tmp
trap 'rm -f "$tmp"' EXIT
if ((uninstall)); then
  say "2/4 Quitar el bloque de tema"
  python3 -I "$HELPER" limine-unmerge "$LIMINE_CONF" "$tmp" --saved "$SAVED_LOOK"
else
  say "2/4 Fondo ($variant)"
  png="$REPO/assets/boot/limine/ocarinashell-limine-$variant.png"
  [[ -f $png ]] || die "falta $png"
  cp "$png" /boot/ocarinashell-limine.png.tmp
  mv -f /boot/ocarinashell-limine.png.tmp /boot/ocarinashell-limine.png
  echo "  /boot/ocarinashell-limine.png"
  say "3/4 Bloque de tema en limine.conf (timeout $timeout s)"
  python3 -I "$HELPER" limine-merge "$LIMINE_CONF" "$tmp" "$variant" --timeout "$timeout" --saved "$SAVED_LOOK"
fi

# safety: the entries must be untouched and the new header must not have two wallpapers or two timeouts
cmp -s <(entries_of "$LIMINE_CONF") <(entries_of "$tmp") || die "las entradas cambiarían: no toco nada"
hdr=$(sed '/^[[:space:]]*\//,$d' "$tmp")
for k in wallpaper timeout; do
  n=$(grep -c "^[[:space:]]*$k:" <<<"$hdr" || true)
  ((n <= 1)) || die "$k aparece $n veces en la cabecera: no toco nada"
done
sync -f "$tmp"
mv -f "$tmp" "$LIMINE_CONF"
trap - EXIT
((uninstall)) && rm -f /boot/ocarinashell-limine.png

say "4/4 Comprobación"
sed '/^[[:space:]]*\//,$d' "$LIMINE_CONF" | sed 's/^/  │ /'
if ((uninstall)); then
  ! grep -q '^# ── OcarinaShell' "$LIMINE_CONF" || die "el bloque sigue ahí"
  echo "  ✓ tema quitado (aspecto anterior restaurado si estaba guardado)"
else
  grep -q '^# ── OcarinaShell · tema de Limine' "$LIMINE_CONF" || die "el bloque no está"
  [[ -f /boot/ocarinashell-limine.png ]] || die "falta el fondo en /boot"
  echo "  ✓ tema $variant instalado · entradas intactas"
fi
echo "Lo verás en el próximo arranque. Vuelve a Claude Code y dile «hecho»."
