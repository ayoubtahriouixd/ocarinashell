#!/usr/bin/env bash
# OcarinaShell · installs the root-owned files of system/ (copies, never links). Idempotent.
# usage: sudo bash scripts/install-system.sh [--dry-run] [--uninstall]
#
# system/etc and system/usr mirror absolute paths: system/etc/polkit-1/rules.d/50-ocarina.rules → /etc/polkit-1/…
# (other folders of system/, like greeter/ and boot-sync/, belong to their own scripts in scripts/root/).
# Executables keep 0755, everything else 0644; files under etc/sudoers.d get 0440 and must pass `visudo -c`.
# A pre-existing different file is saved in /var/lib/ocarinashell/backup/<path> before being replaced.
# The list of installed files lives in /var/lib/ocarinashell/system-manifest (used by --uninstall).
# Boot chain, PAM and limine defaults are NOT handled here: they have their own scripts in scripts/root/ (rule 10).
set -euo pipefail

repo="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
src_root="$repo/system"
state=/var/lib/ocarinashell
manifest="$state/system-manifest"
dry=0; uninstall=0
for a in "$@"; do
  case "$a" in
    --dry-run|-n) dry=1 ;;
    --uninstall) uninstall=1 ;;
    -h|--help) sed -n '2,10p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "opción desconocida: $a" >&2; exit 1 ;;
  esac
done
if ((!dry)) && [[ $EUID -ne 0 ]]; then
  echo "Ejecútalo con: sudo bash $0 $*" >&2; exit 1
fi

run() { if ((dry)); then echo "  [dry-run] $*"; else "$@"; fi; }
forbidden() { [[ "$1" =~ ^/(boot|efi)(/|$)|^/etc/pam\.d/|^/etc/default/limine$|^/etc/mkinitcpio ]]; }
changed=0

if ((uninstall)); then
  echo "OcarinaShell · desinstalando ficheros de sistema$( ((dry)) && echo ' (dry-run)')"
  [[ -f "$manifest" ]] || { echo "  no hay manifiesto ($manifest): nada que quitar."; exit 0; }
  while IFS= read -r dst; do
    [[ -n "$dst" && -e "$dst" ]] || continue
    if [[ "$dst" == /etc/systemd/system/*.service ]]; then run systemctl disable --quiet "$(basename "$dst")" || true; fi
    echo "  quita  $dst"; run rm -f "$dst"; changed=1
    if [[ -e "$state/backup$dst" ]]; then
      echo "  repone $dst"; run mv "$state/backup$dst" "$dst"
    fi
  done < "$manifest"
  run rm -f "$manifest"
else
  echo "OcarinaShell · instalando ficheros de sistema$( ((dry)) && echo ' (dry-run)')"
  [[ -d "$src_root" ]] || { echo "  no existe system/: nada que instalar."; exit 0; }
  run mkdir -p "$state/backup"
  new_manifest=()
  while IFS= read -r -d '' f; do
    dst="/${f#"$src_root"/}"
    if forbidden "$dst"; then
      echo "  ✗ $dst: ruta reservada a scripts/root (regla 10); se omite." >&2; continue
    fi
    mode=0644; [[ -x "$f" ]] && mode=0755
    if [[ "$dst" == /etc/sudoers.d/* ]]; then
      mode=0440
      visudo -cqf "$f" || { echo "  ✗ $dst: visudo -c falla; NO se instala." >&2; continue; }
    fi
    new_manifest+=("$dst")
    if [[ -f "$dst" ]] && cmp -s "$f" "$dst" && [[ "$(stat -c %a "$dst")" == "${mode#0}" ]]; then continue; fi
    if [[ -e "$dst" && ! -e "$state/backup$dst" ]] && ! grep -qxF "$dst" "$manifest" 2>/dev/null; then
      echo "  copia  $dst → $state/backup$dst"
      run install -D -m "$(stat -c %a "$dst")" "$dst" "$state/backup$dst"
    fi
    echo "  instala $dst ($mode)"
    run install -D -o root -g root -m "$mode" "$f" "$dst"
    changed=1
  # only the mirrored trees: system/greeter, system/boot-sync… are installed by their own scripts in scripts/root/
  done < <(find "$src_root/etc" "$src_root/usr" -type f ! -name .gitkeep ! -name 'README*' -print0 2>/dev/null | sort -z)
  if ((!dry)); then
    printf '%s\n' "${new_manifest[@]}" | sort -u > "$manifest.new"
    # files that were installed before but are gone from the repo are removed too
    if [[ -f "$manifest" ]]; then
      comm -23 <(sort -u "$manifest") "$manifest.new" | while IFS= read -r old; do
        echo "  quita (ya no está en el repo) $old"; rm -f "$old"
        [[ -e "$state/backup$old" ]] && mv "$state/backup$old" "$old"
      done
    fi
    mv "$manifest.new" "$manifest"
  fi
fi
# units: systemd learns about new/changed files; those with an [Install] section are enabled (never started here)
if ((changed)) && command -v systemctl >/dev/null; then
  run systemctl daemon-reload
fi
if ((!uninstall)); then
  for u in "$src_root"/etc/systemd/system/*.service; do
    if [[ ! -f "$u" ]] || ! grep -q '^\[Install\]' "$u"; then continue; fi
    n="$(basename "$u")"
    if ! systemctl is-enabled --quiet "$n" 2>/dev/null; then
      echo "  habilita $n"; run systemctl enable --quiet "$n"; changed=1
    fi
  done
fi
((changed)) || echo "  nada que cambiar."
