#!/usr/bin/env bash
# Render a Settei page to a PNG without touching the screen: a throwaway qs instance on Qt's offscreen platform, with
# copies of the config (settings, niri) so nothing real is read-write shared. For checking UI while Ayoub uses the
# laptop (fase 17). The page sits in a plain window, not in Settei: its title comes from Settei.page (ignore it).
# usage: tests/render-page.sh <Página> [salida.png] [ancho] [alto] [js tras 1,2 s, p. ej. 'page.editing = "Mod+N"']
set -euo pipefail

page="${1:?uso: tests/render-page.sh <Página> [salida.png] [ancho] [alto] [js]}"
repo="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
out="$(realpath -m "${2:-$page.png}")"
w="${3:-900}"; h="${4:-1400}"; js="${5:-}"
[[ -f "$repo/shell/modules/settei/pages/$page.qml" ]] || { echo "no existe la página $page" >&2; exit 2; }
work="$(mktemp -d "${TMPDIR:-/tmp}/ocarina-render.XXXXXX")"
trap 'rm -rf "$work"' EXIT
mkdir -p "$work/cfg" "$work/state" "$work/shell"
cp -rL "$repo/shell/." "$work/shell/"
cp -rL "${XDG_CONFIG_HOME:-$HOME/.config}/ocarinashell" "${XDG_CONFIG_HOME:-$HOME/.config}/niri" "$work/cfg/"
# the state too (resolved theme, Mamori, Snake…: ~0,5 MB), so the page shows what the real one shows
cp -rL "${XDG_STATE_HOME:-$HOME/.local/state}/ocarinashell" "$work/state/" 2>/dev/null || true
cat > "$work/shell/shell.qml" <<EOF
import QtQuick
import Quickshell
import qs.config
import qs.components
import qs.services
import qs.modules.settei
import qs.modules.settei.pages

ShellRoot {
    FloatingWindow {
        implicitWidth: $w
        implicitHeight: $h
        color: Theme.colors.bg
        // only the width: a Settei page is a column as tall as its content (Settei scrolls it)
        $page { id: page; width: parent.width }
        Timer { interval: 1200; running: true; onTriggered: { $js } }
        Timer {
            interval: 2500
            running: true
            onTriggered: page.grabToImage(r => { r.saveToFile("$out"); console.info("RENDER OK"); })
        }
    }
}
EOF
log="$work/.log"
(cd "$work" && XDG_CONFIG_HOME="$work/cfg" XDG_STATE_HOME="$work/state" QT_QPA_PLATFORM=offscreen \
   exec qs -p "$work/shell" >"$log" 2>&1) &
pid=$!
for _ in $(seq 100); do grep -q 'RENDER OK' "$log" 2>/dev/null && break; kill -0 "$pid" 2>/dev/null || break; sleep 0.1; done
kill "$pid" 2>/dev/null || true; wait "$pid" 2>/dev/null || true
sed 's/\x1b\[[0-9;]*m//g' "$log" | grep -E 'WARN (scene|qml)|TypeError|ReferenceError' || true
if ! grep -q 'RENDER OK' "$log"; then echo "no se pudo renderizar" >&2; exit 1; fi
echo "$out"
