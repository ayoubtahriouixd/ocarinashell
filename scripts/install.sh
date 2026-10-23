#!/usr/bin/env bash
# OcarinaShell · links the repo into $HOME (docs/01-ARQUITECTURA §3). Idempotent; never needs root.
# usage: scripts/install.sh [--dry-run] [--uninstall] [--quiet]
#
#   shell/               → ~/.config/quickshell/ocarina   (whole directory)
#   config/{niri,ghostty,nvim}/ → ~/.config/<name>        (whole directory; only when it has real content)
#   config/fish/conf.d/*.fish → ~/.config/fish/conf.d/    (per file: the user's config.fish stays theirs, except a
#                          marked 3-line block at its end that points fish_greeting to OcarinaShell's greeting)
#   config/<app>/**      → ~/.config/<app>/**             (per file, for every other app)
#   bin/*                → ~/.local/bin/
#   systemd/user/*       → ~/.config/systemd/user/        (+ daemon-reload)
#   share/**             → ~/.local/share/**              (per file: .desktop entries…)
#   native/nameraka      → built with meson in ~/.cache/ocarinashell/build/nameraka, installed (copied) to
#                          ~/.local/libexec/ocarinashell/nameraka; its socket and self-test units are enabled
#   assets/logo, assets/wallpapers → hicolor icons «ocarinashell», ~/.local/share/ocarinashell/{logo,wallpapers}/
#   (themed files — starship.toml, gtk.css, qt6ct… — are written by bin/ocarina-theme, not linked)
#
# Anything already at a target that is not our link is moved to <target>.ocarina-bak-<YYYY-MM-DD>[-N].
# --uninstall removes only links that point into this repo and restores the newest backup of each.
set -euo pipefail

repo="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cfg="${XDG_CONFIG_HOME:-$HOME/.config}"
data="${XDG_DATA_HOME:-$HOME/.local/share}"
today="$(date +%F)"
dry=0; uninstall=0; quiet=0
for a in "$@"; do
  case "$a" in
    --dry-run|-n) dry=1 ;;
    --uninstall) uninstall=1 ;;
    --quiet|-q) quiet=1 ;;
    -h|--help) sed -n '2,16p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "opción desconocida: $a" >&2; exit 1 ;;
  esac
done

changed=0
log() { ((quiet)) || printf '%s\n' "$*"; }
run() { if ((dry)); then log "  [dry-run] $*"; else "$@"; fi; }

# A directory counts as "real content" when it holds something besides .gitkeep files.
has_content() { [[ -n "$(find "$1" -type f ! -name .gitkeep -print -quit 2>/dev/null)" ]]; }

backup_path() {
  local b="$1.ocarina-bak-$today" n=1
  while [[ -e "$b" || -L "$b" ]]; do b="$1.ocarina-bak-$today-$n"; ((n++)); done
  printf '%s' "$b"
}

link() {   # link <source in repo> <target>
  local src="$1" dst="$2"
  if [[ -L "$dst" && "$(readlink "$dst")" == "$src" ]]; then return 0; fi
  run mkdir -p "$(dirname "$dst")"
  if [[ -e "$dst" || -L "$dst" ]]; then
    local b; b="$(backup_path "$dst")"
    log "  copia  ${dst/#$HOME/\~} → ${b/#$HOME/\~}"
    run mv "$dst" "$b"
  fi
  log "  enlace ${dst/#$HOME/\~} → ${src#"$repo"/}"
  run ln -s "$src" "$dst"
  changed=1
}

unlink_one() {   # unlink_one <target>: only if it is our link; then restore the newest backup
  local dst="$1"
  [[ -L "$dst" && "$(readlink "$dst")" == "$repo"/* ]] || return 0
  log "  quita  ${dst/#$HOME/\~}"
  run rm "$dst"
  local newest
  newest="$(compgen -G "$dst.ocarina-bak-*" | sort -V | tail -n1 || true)"
  if [[ -n "$newest" ]]; then
    log "  repone ${newest/#$HOME/\~} → ${dst/#$HOME/\~}"
    run mv "$newest" "$dst"
  fi
  changed=1
}

# Build the (source, target) plan.
plan=()
add() { plan+=("$1"$'\t'"$2"); }

[[ -d "$repo/shell" ]] && has_content "$repo/shell" && add "$repo/shell" "$cfg/quickshell/ocarina"
for d in niri ghostty nvim; do
  [[ -d "$repo/config/$d" ]] && has_content "$repo/config/$d" && add "$repo/config/$d" "$cfg/$d"
done
if [[ -d "$repo/config/fish/conf.d" ]]; then
  for f in "$repo"/config/fish/conf.d/*.fish; do [[ -e "$f" ]] && add "$f" "$cfg/fish/conf.d/${f##*/}"; done
fi
[[ -f "$repo/config/starship.toml" ]] && add "$repo/config/starship.toml" "$cfg/starship.toml"
# GameMode reads only ~/.config/gamemode.ini (top level, so the depth-2 loop below does not see it)
[[ -f "$repo/config/gamemode.ini" ]] && add "$repo/config/gamemode.ini" "$cfg/gamemode.ini"
# default terminal for xdg-terminal-exec (Ghostty; alacritty was removed in phase 8)
[[ -f "$repo/config/xdg-terminals.list" ]] && add "$repo/config/xdg-terminals.list" "$cfg/xdg-terminals.list"
if [[ -d "$repo/config" ]]; then
  while IFS= read -r -d '' f; do
    rel="${f#"$repo"/config/}"
    case "$rel" in niri/*|ghostty/*|nvim/*|fish/*|starship.toml) continue ;; esac
    add "$f" "$cfg/$rel"
  done < <(find "$repo/config" -mindepth 2 -type f ! -name .gitkeep -print0 | sort -z)
fi
if [[ -d "$repo/bin" ]]; then
  for f in "$repo"/bin/*; do [[ -f "$f" && "${f##*/}" != .gitkeep ]] && add "$f" "$HOME/.local/bin/${f##*/}"; done
fi
units=0
if [[ -d "$repo/systemd/user" ]]; then
  for f in "$repo"/systemd/user/*; do
    [[ -f "$f" && "${f##*/}" != .gitkeep ]] || continue
    add "$f" "$cfg/systemd/user/${f##*/}"; units=1
  done
fi

if [[ -d "$repo/share" ]]; then
  while IFS= read -r -d '' f; do add "$f" "$data/${f#"$repo"/share/}"; done < <(
    find "$repo/share" -type f ! -name .gitkeep -print0 | sort -z)
fi
for n in 16 24 32 48 64 128 256 512 1024; do
  f="$repo/assets/logo/png/ocarinashell-icon-$n.png"
  [[ -f "$f" ]] && add "$f" "$data/icons/hicolor/${n}x${n}/apps/ocarinashell.png"
done
# no scalable SVG: it is clipped with <clipPath>/<mask>, which QtSvg (SVG Tiny) ignores, and Qt apps (the shell's
# own drawer) drew a square icon; the rounded PNGs up to 1024 px cover every size (visual QA, fase 17). An older
# install's link to it is removed.
old_svg="$data/icons/hicolor/scalable/apps/ocarinashell.svg"
if [[ -L "$old_svg" && "$(readlink "$old_svg")" == "$repo/"* ]] && ((!dry)); then rm -f "$old_svg"; fi
[[ -f "$repo/assets/logo/png/ocarinashell-mark-512.png" ]] && \
  add "$repo/assets/logo/png/ocarinashell-mark-512.png" "$data/ocarinashell/logo/ocarinashell-mark-512.png"
for f in "$repo"/assets/wallpapers/*.jpg; do
  [[ -f "$f" ]] && add "$f" "$data/ocarinashell/wallpapers/${f##*/}"
done

# fish_greeting: CachyOS redefines it (fastfetch) in config.fish, after conf.d, so the only place that wins is the
# end of config.fish. A marked block, added once and removed by --uninstall.
fish_cfg="$cfg/fish/config.fish"
fish_begin="# >>> OcarinaShell · greeting (scripts/install.sh; --uninstall removes it)"
fish_block() {
  if ((uninstall)); then
    [[ -f "$fish_cfg" ]] && grep -qF "$fish_begin" "$fish_cfg" || return 0
    log "  quito el bloque de OcarinaShell de ${fish_cfg/#$HOME/\~}"
    ((dry)) || sed -i "/^# >>> OcarinaShell · greeting/,/^# <<< OcarinaShell/d" "$fish_cfg"
    changed=1
  else
    [[ -f "$fish_cfg" ]] && grep -qF "$fish_begin" "$fish_cfg" && return 0
    log "  bloque del saludo al final de ${fish_cfg/#$HOME/\~}"
    ((dry)) && return 0
    mkdir -p "${fish_cfg%/*}"
    printf '\n%s\nfunctions -q __ocarina_greeting; and functions -e fish_greeting; and functions -c __ocarina_greeting fish_greeting\n# <<< OcarinaShell\n' \
      "$fish_begin" >> "$fish_cfg"
    changed=1
  fi
}

if ((uninstall)); then
  log "OcarinaShell · desinstalando enlaces$( ((dry)) && echo ' (dry-run)')"
  for p in "${plan[@]}"; do unlink_one "${p#*$'\t'}"; done
  # also catch stale links left by files that no longer exist in the repo
  while IFS= read -r -d '' l; do unlink_one "$l"; done < <(
    find "$cfg" "$HOME/.local/bin" "$data" -maxdepth 6 -type l -lname "$repo/*" -print0 2>/dev/null)
  fish_block
else
  log "OcarinaShell · instalando enlaces$( ((dry)) && echo ' (dry-run)')"
  for p in "${plan[@]}"; do link "${p%%$'\t'*}" "${p#*$'\t'}"; done
  for f in "$repo"/bin/*; do [[ -f "$f" && ! -x "$f" && "${f##*/}" != .gitkeep ]] && run chmod +x "$f"; done
  [[ -f "$repo/config/fish/conf.d/ocarina.fish" ]] && fish_block
  # user folder for wallpapers (real XDG name, e.g. ~/Imágenes/Fondos); never removed by --uninstall
  pics="$(xdg-user-dir PICTURES 2>/dev/null || echo "$HOME/Pictures")"
  [[ -d "$pics/Fondos" ]] || { log "  carpeta ${pics/#$HOME/\~}/Fondos"; run mkdir -p "$pics/Fondos"; }
fi

if ((changed && units && !dry)) && command -v systemctl >/dev/null; then
  systemctl --user daemon-reload || true
fi
# phase 14 units that must be on in every session (enabled, not started: they act at the next login or transaction)
if ((!dry && !uninstall)) && command -v systemctl >/dev/null; then
  for u in ocarina-bootmark.service ocarina-postupdate.path; do
    [[ -f "$repo/systemd/user/$u" ]] || continue
    systemctl --user is-enabled -q "$u" 2>/dev/null || { log "  habilito $u"; systemctl --user enable "$u" >/dev/null 2>&1 || true; }
  done
  # 守 Mamori (fase 16): the daily timer runs from now on (its conditions decide whether a cycle acts)
  if [[ -f "$repo/systemd/user/ocarina-mamori.timer" ]] && ! systemctl --user is-enabled -q ocarina-mamori.timer 2>/dev/null; then
    log "  habilito ocarina-mamori.timer"; systemctl --user enable --now ocarina-mamori.timer >/dev/null 2>&1 || true
  fi
fi

# 滑 Nameraka: native helper (C++/Vulkan). Built only when its sources changed (meson keeps the build dir); a failed
# build leaves the previous binary in place and says why (Fluido then reports «no disponible» through its self-test).
libexec="$HOME/.local/libexec/ocarinashell"
nk_build="${XDG_CACHE_HOME:-$HOME/.cache}/ocarinashell/build/nameraka"
if ((uninstall)); then
  if [[ -e "$libexec/nameraka" ]]; then
    log "  quito ${libexec/#$HOME/\~}/nameraka"
    if ((!dry)); then
      systemctl --user disable --now ocarina-nameraka.socket ocarina-nameraka-selftest.service >/dev/null 2>&1 || true
      rm -f "$libexec/nameraka"
    fi
  fi
elif [[ -f "$repo/native/nameraka/meson.build" ]]; then
  if ! command -v meson >/dev/null || ! command -v ninja >/dev/null; then
    log "  ⚠ Nameraka sin compilar: faltan meson/ninja (sudo pacman -S meson ninja vulkan-headers wayland-protocols wlr-protocols)"
  elif ((!dry)); then
    if [[ ! -f "$nk_build/build.ninja" ]]; then
      mkdir -p "${nk_build%/*}"
      meson setup "$nk_build" "$repo/native/nameraka" --buildtype=release >/dev/null 2>"${nk_build%/*}/nameraka-setup.log" || log "  ⚠ meson setup de Nameraka falló"
    fi
    if [[ -f "$nk_build/build.ninja" ]] && ninja -C "$nk_build" >/dev/null 2>&1; then
      if ! cmp -s "$nk_build/nameraka" "$libexec/nameraka" 2>/dev/null; then
        install -D -m 0755 "$nk_build/nameraka" "$libexec/nameraka.new" && mv -f "$libexec/nameraka.new" "$libexec/nameraka"
        log "  Nameraka compilado → ${libexec/#$HOME/\~}/nameraka"
        # an idle daemon left from before would keep the old binary (and its protocol): the socket starts the new one
        if command -v systemctl >/dev/null && ! pgrep -x nameraka -a 2>/dev/null | grep -q ' view'; then
          systemctl --user stop ocarina-nameraka.service >/dev/null 2>&1 || true
        fi
        changed=1
      fi
      if command -v systemctl >/dev/null; then
        systemctl --user is-enabled -q ocarina-nameraka.socket 2>/dev/null \
          || systemctl --user enable --now ocarina-nameraka.socket >/dev/null 2>&1 || true
        systemctl --user is-enabled -q ocarina-nameraka-selftest.service 2>/dev/null \
          || systemctl --user enable ocarina-nameraka-selftest.service >/dev/null 2>&1 || true
      fi
    else
      log "  ⚠ Nameraka no compiló: ninja -C ${nk_build/#$HOME/\~} para ver el error"
    fi
  else
    log "  [dry-run] compilar native/nameraka → ${libexec/#$HOME/\~}/nameraka"
  fi
fi
((changed)) || log "  nada que cambiar."
