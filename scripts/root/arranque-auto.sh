#!/usr/bin/env bash
# OcarinaShell · fase 13 · boot theme in «auto»: it follows the desktop theme by itself (D-068). Run as:
#   sudo bash scripts/root/arranque-auto.sh instalar     install, enable and sync once now
#   sudo bash scripts/root/arranque-auto.sh refrescar    copy the repo pieces again (after updates to the boot theme)
#   sudo bash scripts/root/arranque-auto.sh quitar       back to manual (`ocarina-boot-theme apply dark|light`)
# What «auto» is: ocarina-boot-sync.path watches ~/.local/state/ocarinashell/theme.json; when the theme's light/dark
# differs from the boot chain, ocarina-boot-sync (root) switches Limine, Plymouth (initramfs) and the greeter, with one
# snapper snapshot, at the lowest CPU/IO priority, 45 s after the last change. A timer checks again 2 min after boot.
# The service runs ONLY a root-owned copy of the scripts and assets in /usr/local/lib/ocarinashell/boot (never the
# user-writable repo): what root executes can only change when you run this script again.
set -euo pipefail
# shellcheck source=scripts/root/lib-arranque.sh
source "$(dirname "${BASH_SOURCE[0]}")/lib-arranque.sh"
need_root

LIB=/usr/local/lib/ocarinashell/boot
SRC="$REPO/system/boot-sync"
UNITS=(ocarina-boot-sync.path ocarina-boot-sync.service ocarina-boot-sync.timer)

copy_lib() {
  say "Copia de root en $LIB"
  install -d -m 0755 /usr/local/lib/ocarinashell
  local stage
  stage=$(mktemp -d /usr/local/lib/ocarinashell/.boot.XXXXXX)
  install -d "$stage"/{bin,scripts/root,assets/boot,system}
  install -m 0755 "$REPO/bin/ocarina-boot-theme" "$stage/bin/"
  install -m 0644 "$REPO"/scripts/root/{lib-arranque,limine-tema,plymouth-tema,greeter}.sh "$stage/scripts/root/"
  cp -r "$REPO/assets/boot/limine" "$REPO/assets/boot/plymouth" "$stage/assets/boot/"
  cp -rL "$REPO/greeter" "$stage/greeter"
  cp -r "$REPO/system/greeter" "$stage/system/greeter"
  install -m 0755 "$SRC/ocarina-boot-sync" "$stage/ocarina-boot-sync"
  chown -R root:root "$stage"
  find "$stage" -type d -exec chmod 0755 {} +
  find "$stage" -type f ! -perm -u+x -exec chmod 0644 {} +
  rm -rf --one-file-system "$LIB"
  mv "$stage" "$LIB"
  echo "  $(find "$LIB" -type f | wc -l) ficheros (propiedad de root)"
}

install_units() {
  say "Unidades"
  local u
  for u in "${UNITS[@]}"; do
    sed "s#@HOME@#$OWNER_HOME#g; s#@USER@#$OWNER#g" "$SRC/$u" > "/etc/systemd/system/$u"
    chmod 0644 "/etc/systemd/system/$u"
  done
  systemctl daemon-reload
  systemd-analyze verify /etc/systemd/system/ocarina-boot-sync.{path,service,timer} >/dev/null 2>&1 \
    || warn "systemd-analyze se queja de las unidades (mira: systemd-analyze verify /etc/systemd/system/ocarina-boot-sync.service)"
}

case ${1:-} in
  instalar)
    snapshot "fase 13, antes del tema de arranque automático"
    copy_lib
    install_units
    systemctl enable --now ocarina-boot-sync.path ocarina-boot-sync.timer
    say "Comprobación ahora (sin la espera de 45 s)"
    OCARINA_OWNER=$OWNER nice -n 19 "$LIB/ocarina-boot-sync"
    echo
    echo "Automático: el arranque sigue a tu tema (oscuro o claro). Registro: journalctl -u ocarina-boot-sync"
    ;;
  refrescar)
    snapshot "fase 13, tema de arranque automático: refrescar copia"
    copy_lib
    install_units
    echo "Copia actualizada."
    ;;
  quitar)
    snapshot "fase 13, quitar el tema de arranque automático"
    systemctl disable --now ocarina-boot-sync.path ocarina-boot-sync.timer 2>/dev/null || true
    for u in "${UNITS[@]}"; do rm -f "/etc/systemd/system/$u"; done
    systemctl daemon-reload
    echo "Manual otra vez: ocarina-boot-theme apply dark|light. (La copia en $LIB se queda; no se ejecuta.)"
    ;;
  *)
    sed -n '2,11p' "$0" | sed 's/^# \{0,1\}//'
    exit 1
    ;;
esac
