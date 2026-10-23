#!/usr/bin/env bash
# shellcheck disable=SC2015,SC2012  # ok/ko always return 0; the .roto names are ours (no odd characters)
# Simulacro a (fase 14): settings.json corrupt → defaults + .roto copy + notice; corrupt while running → the good
# settings stay in memory and are written back. A window-less Quickshell instance loads only the Settings singleton
# from this repo against a temporary XDG_CONFIG_HOME: nothing of Ayoub's settings or screen is touched.
set -euo pipefail
repo="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
cp -r "$repo/shell/config" "$tmp/config"
mkdir -p "$tmp/xdg/ocarinashell"
cfg="$tmp/xdg/ocarinashell/settings.json"
cat > "$tmp/shell.qml" <<'QML'
//@ pragma ShellId ocarina-sim-a
import QtQuick
import Quickshell
import qs.config
ShellRoot {
    Connections {
        target: Settings
        function onCorrupted(bak) { console.info("SIM corrupted", bak, "kept", Settings.keptLive, "theme", Settings.data.appearance.theme); }
    }
    Timer {
        interval: 1200; running: true
        onTriggered: {
            console.info("SIM loaded theme", Settings.data.appearance.theme, "gaps", Settings.data.windows.gaps, "version", Settings.data.version);
            if (Quickshell.env("SIM_HOT") === "1")
                Quickshell.execDetached(["sh", "-c", "printf '{ roto' > \"$1\"", "sh", Settings.data && Paths.settings]);
        }
    }
    Timer { interval: Quickshell.env("SIM_HOT") === "1" ? 5000 : 2500; running: true; onTriggered: Qt.quit() }
}
QML
run() { XDG_CONFIG_HOME="$tmp/xdg" timeout 15 qs -p "$tmp/shell.qml" 2>&1 | sed 's/\x1b\[[0-9;]*m//g' | grep -E 'SIM|Settings:' || true; }
pass=0 fail=0
ok() { pass=$((pass + 1)); echo "  ✓ $*"; }
ko() { fail=$((fail + 1)); echo "  ✗ $*"; }

echo "── 1) corrupto al arrancar"
printf '{ "version": 4, "appearance": { "theme": "sumi", ' > "$cfg"
sum_broken="$(sha256sum < "$cfg")"
out="$(run)"; printf '%s\n' "$out" | sed 's/^/     /'
bak="$(ls "$cfg".roto-* 2>/dev/null | head -n1)"
[[ -n "$bak" && "$(sha256sum < "$bak")" == "$sum_broken" ]] && ok "copia .roto idéntica al fichero dañado ($(basename "$bak"))" || ko "sin copia .roto fiel"
jq -e . "$cfg" >/dev/null 2>&1 && ok "settings.json reescrito y válido" || ko "settings.json sigue roto"
[[ "$(jq -r .appearance.theme "$cfg")" == kurenai ]] && ok "valores por defecto (tema kurenai)" || ko "no son los valores por defecto"
grep -q 'SIM corrupted' <<<"$out" && ok "señal corrupted → aviso (OSD + notificación en la shell real)" || ko "sin señal corrupted"

echo "── 2) corrupto en caliente (con ajustes buenos en memoria)"
rm -f "$cfg".roto-*
jq '.appearance.theme = "sumi" | .windows.gaps = 20' "$cfg" > "$cfg.n" && mv "$cfg.n" "$cfg"
out="$(SIM_HOT=1 run)"; printf '%s\n' "$out" | sed 's/^/     /'
bak="$(ls "$cfg".roto-* 2>/dev/null | head -n1)"
[[ -n "$bak" && "$(cat "$bak")" == "{ roto" ]] && ok "copia .roto del fichero roto" || ko "sin copia .roto"
[[ "$(jq -r .appearance.theme "$cfg" 2>/dev/null)" == sumi && "$(jq -r .windows.gaps "$cfg")" == 20 ]] \
  && ok "se conservan los ajustes de la sesión (sumi, gaps 20) y se reescriben" || ko "se perdieron los ajustes buenos"
grep -q 'SIM corrupted.*kept true' <<<"$out" && ok "aviso con «se mantienen los de esta sesión»" || ko "aviso incorrecto"

echo "── 3) valores fuera de rango y versión en texto"
rm -f "$cfg".roto-*
jq '.version = "4" | .windows.gaps = 1000000 | .appearance.fontScale = 40 | .bar.style = "x" | .idle.ac.lock = -1' "$cfg" > "$cfg.n" && mv "$cfg.n" "$cfg"
out="$(run)"; printf '%s\n' "$out" | grep -c 'fuera de rango' | sed 's/^/     avisos de rango: /'
[[ "$(jq -r '[.windows.gaps, .appearance.fontScale, .bar.style, .idle.ac.lock, .version] | map(tostring) | join(",")' "$cfg")" == "12,1,isles,5,4" ]] \
  && ok "cada valor absurdo vuelve a su valor por defecto; version «4» → 4 sin repetir migraciones" || ko "rangos: $(jq -c '[.windows.gaps, .appearance.fontScale, .bar.style, .idle.ac.lock, .version]' "$cfg")"
[[ "$(jq -r .appearance.theme "$cfg")" == sumi ]] && ok "el resto del fichero se conserva" || ko "se perdió el resto"
echo "resultado: $pass bien · $fail mal"
((fail == 0))
