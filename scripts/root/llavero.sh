#!/usr/bin/env bash
# OcarinaShell · fase 13 · the keyring opens by itself at login. Run as: sudo bash scripts/root/llavero.sh
#                                                                      sudo bash scripts/root/llavero.sh --uninstall
# Chrome (and every app that keeps secrets: VS Code, Fune's RDP password…) asked for the keyring password after each
# boot because nothing unlocked gnome-keyring at login. pam_gnome_keyring takes the password you type in the greeter
# (or in the text login) and unlocks the «login» keyring with it; `passwd` keeps both passwords in step from now on.
# Only the per-service files /etc/pam.d/{greetd,login,passwd} change (never system-auth / system-local-login), and
# every line is `optional`: if the module failed, logging in would still work exactly as today.
# Requirement: the keyring password must be your login password (if it is not, the script tells you what to do).
# Idempotent; snapper snapshot; previous files in /var/lib/ocarinashell/pam-<name>.previo; --uninstall restores them.
set -euo pipefail
# shellcheck source=scripts/root/lib-arranque.sh
source "$(dirname "${BASH_SOURCE[0]}")/lib-arranque.sh"
need_root
[[ -f /usr/lib/security/pam_gnome_keyring.so ]] || die "falta pam_gnome_keyring.so (paquete gnome-keyring)"

AUTH='auth       optional     pam_gnome_keyring.so'
SESSION='session    optional     pam_gnome_keyring.so auto_start'
PASSWORD='password   optional     pam_gnome_keyring.so'

say "1/3 Snapshot"
snapshot "fase 13, llavero: pam_gnome_keyring en greetd/login/passwd ($([[ ${1:-} == --uninstall ]] && echo quitar || echo poner))"
install -d -m 0755 /var/lib/ocarinashell

if [[ ${1:-} == --uninstall ]]; then
  say "2/3 Restaurar"
  for f in greetd login passwd; do
    prev=/var/lib/ocarinashell/pam-$f.previo
    if [[ -f $prev ]]; then cp -p "$prev" "/etc/pam.d/$f"; echo "  /etc/pam.d/$f restaurado"; fi
  done
  say "3/3 Listo"
  exit 0
fi

say "2/3 /etc/pam.d/{greetd,login,passwd}"
add_after() {   # file, regex of the anchor line, line to add (once)
  local file=$1 anchor=$2 line=$3
  grep -qF "$line" "$file" && return 0
  grep -qE "$anchor" "$file" || die "no encuentro «$anchor» en $file: no toco nada"
  sed -i -E "0,/$anchor/{/$anchor/a\\
$line
}" "$file"
}
for f in greetd login passwd; do
  [[ -f /etc/pam.d/$f ]] || { warn "/etc/pam.d/$f no existe (¿greetd sin instalar?)"; continue; }
  [[ -f /var/lib/ocarinashell/pam-$f.previo ]] || cp -p "/etc/pam.d/$f" "/var/lib/ocarinashell/pam-$f.previo"
done
for f in greetd login; do
  [[ -f /etc/pam.d/$f ]] || continue
  add_after "/etc/pam.d/$f" '^auth[[:space:]]+include[[:space:]]+system-local-login' "$AUTH"
  add_after "/etc/pam.d/$f" '^session[[:space:]]+include[[:space:]]+system-local-login' "$SESSION"
done
add_after /etc/pam.d/passwd '^password[[:space:]]+include[[:space:]]+system-auth' "$PASSWORD"

say "3/3 Comprobación"
for f in greetd login passwd; do
  [[ -f /etc/pam.d/$f ]] || continue
  echo "  /etc/pam.d/$f"
  sed 's/^/  │ /' "/etc/pam.d/$f"
done
echo
echo "Listo: desde el próximo inicio de sesión el llavero se abre solo con tu contraseña."
echo "Si después de reiniciar Chrome aún la pide, la contraseña del llavero no es la de tu usuario: abre «Contraseñas"
echo "y claves» (seahorse) → llavero «Inicio de sesión» → Cambiar contraseña → pon la de tu usuario."
