#!/usr/bin/env bash
# OcarinaShell · fase 13 · greeter (greetd + niri + Quickshell). Run as:
#   sudo bash scripts/root/greeter.sh instalar [dark|light]   files, packages and units; enables NOTHING
#   sudo bash scripts/root/probar-greeter.sh                  dry run on vt 7 with your real password (nothing starts)
#   sudo bash scripts/root/greeter.sh activar                 greetd on tty1 from the NEXT boot (never starts it now:
#                                                             it would stop getty@tty1, where this session lives)
#   sudo bash scripts/root/greeter.sh desactivar              back to the text login on tty1 from the next boot
#   sudo bash scripts/root/greeter.sh actualizar [dark|light] copy the greeter's QML/assets/units again (after changes)
# Idempotent; each step takes a snapper snapshot and keeps copies. Lock-out safety: greeter-launch falls back to
# agreety (text login) if the greeter fails twice or /etc/ocarinashell/greeter-disabled exists; Ctrl+Alt+F2 always
# gives a text console; the Limine snapshots and the LTS kernel stay as they are.
set -euo pipefail
# shellcheck source=scripts/root/lib-arranque.sh
source "$(dirname "${BASH_SOURCE[0]}")/lib-arranque.sh"

action=${1:-}
variant=${2:-dark}
[[ $variant == dark || $variant == light ]] || die "variante: dark | light"
need_root

G=/usr/local/share/ocarinashell/greeter
LIBEXEC=/usr/local/lib/ocarinashell
FONTS=/usr/local/share/fonts/ocarinashell
CONF=/etc/ocarinashell/greeter.json
STATE=/var/lib/ocarina-greeter
SRC="$REPO/system/greeter"

copy_greeter() {
  say "Greeter → $G ($variant)"
  local stage
  stage=$(mktemp -d /usr/local/share/ocarinashell/.greeter.XXXXXX)
  # dereference the repo's links (config/, components/, kagi/ point into shell/)
  cp -rL "$REPO/greeter/." "$stage/"
  # components that need the shell's services are never used here (they would only warn)
  rm -f "$stage"/components/{Kamon,ModuleLoader,PanelSurface,PullDown}.qml
  install -d "$stage/assets"
  local a
  for a in tile body hole0 hole1 hole2 hole3 hole4 hole5 wave0 wave1 seal-prompt seal-kanji msg-boot-dark msg-boot-light; do
    cp "$REPO/assets/boot/plymouth/ocarinashell/$a.png" "$stage/assets/"
  done
  local bg='#0b0a0c'
  [[ $variant == light ]] && bg='#f4f1ec'
  sed "s/background-color \"#0b0a0c\"/background-color \"$bg\"/" "$SRC/niri.kdl" > "$stage/niri.kdl"
  find "$stage" -type d -exec chmod 0755 {} +
  find "$stage" -type f -exec chmod 0644 {} +
  rm -rf --one-file-system "$G"
  mv "$stage" "$G"
  niri validate -c "$G/niri.kdl" >/dev/null 2>&1 || die "niri no acepta $G/niri.kdl"
  echo "  $(find "$G" -type f | wc -l) ficheros · niri.kdl válido"

  install -d -m 0755 /etc/ocarinashell
  local name
  name=$(getent passwd "$OWNER" | cut -d: -f5 | cut -d, -f1)
  printf '{\n  "user": "%s",\n  "name": "%s",\n  "variant": "%s",\n  "session": ["niri-session"]\n}\n' \
    "$OWNER" "${name:-$OWNER}" "$variant" > "$CONF"
  chmod 0644 "$CONF"
  echo "  $CONF"

  # the theme (accent, fonts) of Ayoub's shell, so the field and the petals look like Kagi
  if [[ -f $OWNER_HOME/.local/state/ocarinashell/theme.json ]]; then
    install -d -o greeter -g greeter -m 0750 "$STATE/state/ocarinashell"
    install -o greeter -g greeter -m 0640 "$OWNER_HOME/.local/state/ocarinashell/theme.json" "$STATE/state/ocarinashell/theme.json"
  fi
}

install_units() {
  local u
  for u in greetd.service ocarina-greeter-ready.path ocarina-plymouth-handoff.service \
           ocarina-plymouth-failsafe.timer ocarina-plymouth-failsafe.service ocarina-greeter-test.service; do
    install -m 0644 "$SRC/$u" "/etc/systemd/system/$u"
  done
  install -m 0755 "$SRC/greeter-launch" "$LIBEXEC/greeter-launch"
  systemctl daemon-reload
  systemctl reset-failed ocarina-greeter-ready.path ocarina-plymouth-handoff.service 2>/dev/null || true
}

case $action in
  instalar)
    say "1/6 Snapshot y copias"
    snapshot "fase 13, antes de instalar el greeter"
    backup_boot

    say "2/6 Paquetes (greetd, agreety de respaldo)"
    pacman -S --needed --noconfirm greetd greetd-agreety
    getent passwd greeter >/dev/null || die "greetd no creó el usuario greeter"
    groups greeter | grep -qw video || usermod -aG video greeter

    say "3/6 Directorios"
    install -m 0644 "$SRC/tmpfiles.conf" /etc/tmpfiles.d/ocarina-greeter.conf
    systemd-tmpfiles --create /etc/tmpfiles.d/ocarina-greeter.conf
    install -d -o greeter -g greeter -m 0750 "$STATE"/{config,state,cache,data}
    install -d -m 0755 /usr/local/share/ocarinashell "$LIBEXEC"
    install -m 0755 "$SRC/greeter-launch" "$LIBEXEC/greeter-launch"

    say "4/6 Fuentes para el usuario greeter ($FONTS)"
    install -d -m 0755 "$FONTS"
    fsrc="$OWNER_HOME/.local/share/fonts/ocarinashell"
    for f in "Geist[wght].ttf" ZenKakuGothicNew-Regular.ttf ZenKakuGothicNew-Medium.ttf ShipporiMinchoB1-Regular.ttf \
             ShipporiMinchoB1-Medium.ttf "MaterialSymbolsRounded[FILL,GRAD,opsz,wght].ttf" LICENSE-Geist.txt \
             LICENSE-ZenKakuGothicNew.txt LICENSE-ShipporiMinchoB1.txt LICENSE-MaterialSymbols.txt; do
      if [[ -f $fsrc/$f ]]; then install -m 0644 "$fsrc/$f" "$FONTS/"; else warn "falta $f"; fi
    done
    fc-cache -s "$FONTS" >/dev/null

    copy_greeter

    say "5/6 Unidades y configuración de greetd"
    install_units
    install -d -m 0755 /etc/greetd
    if [[ -f /etc/greetd/config.toml && ! -f /var/lib/ocarinashell/greetd-config.toml.previo ]] \
       && ! grep -q OcarinaShell /etc/greetd/config.toml; then
      install -d -m 0755 /var/lib/ocarinashell
      cp -p /etc/greetd/config.toml /var/lib/ocarinashell/greetd-config.toml.previo
    fi
    install -m 0644 "$SRC/config.toml" /etc/greetd/config.toml
    install -m 0644 "$SRC/config-test.toml" /etc/greetd/ocarina-test.toml
    systemctl daemon-reload

    say "6/6 Comprobaciones"
    runuser -u greeter -- test -r "$G/shell.qml" || die "el usuario greeter no puede leer $G"
    runuser -u greeter -- test -w "$STATE/cache" || die "el usuario greeter no puede escribir en $STATE"
    if fc-list : family | grep -q "Shippori Mincho B1"; then echo "  ✓ fuentes visibles para todos"
    else warn "fc-list no ve las fuentes"; fi
    if systemd-analyze verify /etc/systemd/system/greetd.service >/dev/null 2>&1; then echo "  ✓ unidades válidas"
    else warn "systemd-analyze se queja (mira: systemd-analyze verify /etc/systemd/system/greetd.service)"; fi
    echo
    echo "Instalado, NO activado. Siguiente paso, la prueba en seco (vt 7, tu contraseña real, no arranca nada):"
    echo "  sudo bash $REPO/scripts/root/probar-greeter.sh"
    ;;

  actualizar)
    snapshot "fase 13, greeter: actualizar ficheros"
    copy_greeter
    install_units
    echo "Listo: el próximo arranque del greeter usa los ficheros nuevos."
    ;;

  activar)
    [[ -x $LIBEXEC/greeter-launch && -f $G/shell.qml ]] || die "primero: sudo bash $0 instalar"
    snapshot "fase 13, antes de activar greetd"
    backup_boot
    say "Activar greetd (desde el próximo arranque)"
    for dm in gdm sddm lightdm ly lemurs; do
      if systemctl is-enabled "$dm.service" >/dev/null 2>&1; then die "$dm está activado: desactívalo antes"; fi
    done
    rm -f /etc/ocarinashell/greeter-disabled
    systemctl enable greetd.service
    systemctl is-enabled greetd.service
    [[ $(readlink -f /etc/systemd/system/display-manager.service) == */greetd.service ]] && echo "  ✓ display-manager → greetd"
    echo
    echo "Activo desde el próximo arranque (no lo arranco ahora: cerraría esta sesión)."
    echo "Si algo va mal al reiniciar: Ctrl+Alt+F2 → entra → sudo bash $REPO/scripts/root/greeter.sh desactivar → reinicia."
    ;;

  desactivar)
    snapshot "fase 13, desactivar greetd"
    systemctl disable greetd.service || true
    install -d -m 0755 /etc/ocarinashell
    : > /etc/ocarinashell/greeter-disabled            # a greetd still running right now falls back to agreety
    echo "Desactivado: desde el próximo arranque vuelves a entrar por tty1 (texto) y niri-session."
    echo "Los ficheros siguen instalados; «activar» lo vuelve a poner."
    ;;

  *)
    sed -n '2,12p' "$0" | sed 's/^# \{0,1\}//'
    exit 1
    ;;
esac
