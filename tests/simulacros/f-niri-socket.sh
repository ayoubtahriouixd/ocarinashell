#!/usr/bin/env bash
# shellcheck disable=SC2015  # the { pass++; echo; } groups always succeed
# Simulacro f (fase 14): niri's socket goes away and comes back → the shell reconnects by itself and gets the whole
# state again. niri itself is never touched: a window-less Quickshell instance with this repo's Niri service talks to
# niri through a socat proxy (NIRI_SOCKET=proxy); killing the proxy is the «socket restarted», starting it again
# is niri coming back. Also checks that a config reload (`niri msg action load-config-file`) changes nothing.
set -uo pipefail
repo="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
[[ -S "${NIRI_SOCKET:-}" ]] || { echo "hace falta estar dentro de niri"; exit 2; }
command -v socat >/dev/null || { echo "falta socat"; exit 2; }
tmp="$(mktemp -d)"; real="$NIRI_SOCKET"; proxy="$tmp/niri-proxy.sock"
cp -r "$repo/shell/." "$tmp/shell/"
cat > "$tmp/shell/shell.qml" <<'QML'
//@ pragma ShellId ocarina-sim-f
import QtQuick
import Quickshell
import qs.services
ShellRoot {
    property double t0: Date.now()
    Timer {
        interval: 250; repeat: true; running: true
        onTriggered: console.info("SIM", ((Date.now() - parent.t0) / 1000).toFixed(2), Niri.available, Niri.workspaces.length, Niri.outputs ? Object.keys(Niri.outputs).length : 0)
    }
    Timer { interval: 14000; running: true; onTriggered: Qt.quit() }
}
QML
proxy_up() { socat "UNIX-LISTEN:$proxy,fork,unlink-early" "UNIX-CONNECT:$real" 2>/dev/null & echo $! > "$tmp/socat.pid"; sleep 0.3; }
proxy_down() { kill "$(cat "$tmp/socat.pid")" 2>/dev/null; pkill -f "socat UNIX-LISTEN:$proxy" 2>/dev/null; rm -f "$proxy"; }
cleanup() { proxy_down; rm -rf "$tmp"; }
trap cleanup EXIT

proxy_up
NIRI_SOCKET="$proxy" timeout 20 qs -p "$tmp/shell/shell.qml" > "$tmp/log" 2>&1 &
qpid=$!
sleep 3;  proxy_down;  echo "  t≈3 s: proxy cortado (socket de niri «reiniciado»)"
sleep 3;  proxy_up;    echo "  t≈6 s: proxy de vuelta"
sleep 2;  niri msg action load-config-file >/dev/null 2>&1 && echo "  t≈8 s: niri recarga su config"
wait "$qpid" 2>/dev/null
sed 's/\x1b\[[0-9;]*m//g' "$tmp/log" | awk '/SIM/ {print $(NF-3), $(NF-2), $(NF-1), $NF}' > "$tmp/s"
# columns: seconds available workspaces outputs
before="$(awk '$1 < 3 && $2 == "true"' "$tmp/s" | tail -n1)"
during="$(awk '$1 > 3.5 && $1 < 6 && $2 == "false"' "$tmp/s" | head -n1)"
back="$(awk '$1 > 6 && $2 == "true"' "$tmp/s" | head -n1)"
last="$(tail -n1 "$tmp/s")"
pass=0 fail=0
[[ -n "$before" ]] && { pass=$((pass + 1)); echo "  ✓ conectado al principio ($before)"; } || { fail=$((fail + 1)); echo "  ✗ nunca conectó"; }
[[ -n "$during" ]] && { pass=$((pass + 1)); echo "  ✓ ve la caída: available=false en t=$(cut -d' ' -f1 <<<"$during") s"; } || { fail=$((fail + 1)); echo "  ✗ no vio la caída"; }
if [[ -n "$back" ]]; then
  pass=$((pass + 1)); echo "  ✓ reconecta sola en t=$(cut -d' ' -f1 <<<"$back") s ($(awk '{printf "%.1f", $1 - 6}' <<<"$back") s tras volver el socket)"
else fail=$((fail + 1)); echo "  ✗ no reconectó"; fi
read -r _ la lw lo <<<"$last"
[[ "$la" == true && "$lw" -gt 0 && "$lo" -gt 0 ]] && { pass=$((pass + 1)); echo "  ✓ tras la recarga de config: estado completo ($lw espacios, $lo salidas)"; } \
  || { fail=$((fail + 1)); echo "  ✗ estado incompleto al final: $last"; }
errs="$(sed 's/\x1b\[[0-9;]*m//g' "$tmp/log" | grep -E 'TypeError|ReferenceError|ERROR' | head -n 3)"
[[ -z "$errs" ]] && { pass=$((pass + 1)); echo "  ✓ sin errores QML durante la caída"; } || { fail=$((fail + 1)); echo "  ✗ errores: $errs"; }
echo "resultado: $pass bien · $fail mal"
((fail == 0))
