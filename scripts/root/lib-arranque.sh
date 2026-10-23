# shellcheck shell=bash disable=SC2034   # sourced: the variables are used by the scripts that source it
# OcarinaShell · fase 13 · shared helpers for the boot-chain scripts (sourced, never run on its own).
# Every script that sources it must already have `set -euo pipefail`.

say() { printf '\n\e[1;31m▌\e[0m \e[1m%s\e[0m\n' "$*"; }
warn() { printf '\e[33m  ! %s\e[0m\n' "$*" >&2; }
die() { printf '\e[31m  ✗ %s\e[0m\n' "$*" >&2; exit 1; }

need_root() {
  [[ $EUID -eq 0 ]] || die "Ejecútalo con: sudo bash $0"
}

# The repo and Ayoub's home, whichever way the script was launched (sudo bash ~/ocarinashell/scripts/root/x.sh)
REPO=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
# OCARINA_OWNER: set by ocarina-boot-sync.service (root, no sudo); the repo copy there is owned by root
OWNER=${OCARINA_OWNER:-${SUDO_USER:-$(stat -c %U "$REPO")}}
OWNER_HOME=$(getent passwd "$OWNER" | cut -d: -f6)
HELPER="$REPO/bin/ocarina-boot-theme"
LIMINE_CONF=/boot/limine.conf
SAVED_LOOK=/var/lib/ocarinashell/limine-aspecto-previo.conf
BOOT_LOCK=/run/lock/boot-partition.lock     # the same lock limine-entry-tool and limine-snapper-sync take

snapshot() {
  # ocarina-boot-sync takes one snapshot for the whole change and sets OCARINA_SNAPSHOT_DONE
  if [[ -n ${OCARINA_SNAPSHOT_DONE:-} ]]; then echo "  (snapshot ya hecho: #$OCARINA_SNAPSHOT_DONE)"; return 0; fi
  snapper -c root create -d "ocarinashell: $1" --print-number
}

# Copies of everything the boot chain depends on, once per day (a second run the same day adds nothing new)
backup_boot() {
  local dir dst f
  dir="$OWNER_HOME/ocarinashell-backup-boot-$(date +%F)"
  install -d -m 0700 -o "$OWNER" -g "$(id -gn "$OWNER")" "$dir"
  for f in /boot/limine.conf /etc/default/limine /etc/limine-entry-tool.conf /etc/mkinitcpio.conf \
           /etc/plymouth/plymouthd.conf /etc/greetd/config.toml; do
    [[ -f $f ]] || continue
    dst="$dir/$(echo "${f#/}" | tr / _)"
    [[ -f $dst ]] || cp -p "$f" "$dst"
  done
  if [[ -d /etc/mkinitcpio.conf.d && ! -d $dir/etc_mkinitcpio.conf.d ]]; then
    cp -rp /etc/mkinitcpio.conf.d "$dir/etc_mkinitcpio.conf.d"
  fi
  chown -R "$OWNER:" "$dir"
  chmod -R go-rwx "$dir"
  echo "  copia en $dir"
}

# The initramfs images Limine boots now (not the snapshot history)
current_initramfs() {
  sed -n 's/^[[:space:]]*module_path: boot():\([^#]*initramfs[^#]*\).*/\/boot\1/p' "$LIMINE_CONF" | grep -v limine_history | sort -u
}

# The entry tree (everything from the first `/` line): must be byte for byte the same before and after our edit
entries_of() {
  sed -n '/^[[:space:]]*\//,$p' "$1"
}
