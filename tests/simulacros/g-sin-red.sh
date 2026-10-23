#!/usr/bin/env bash
# Simulacro g (fase 14): no network → the weather comes from the disk cache, nothing breaks, the cache is not lost.
# A window-less Quickshell instance with this repo's Weather service runs inside an empty network namespace
# (`unshare -rn`: no interfaces but loopback) with a temporary copy of the cache (made 2 h old so a fetch is tried),
# temporary settings and state. Ayoub's network, cache and shell are not touched.
# shellcheck disable=SC2015  # the { pass++; echo; } groups always succeed
set -uo pipefail
repo="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
src="${XDG_CACHE_HOME:-$HOME/.cache}/ocarinashell/weather.json"
[[ -r "$src" ]] || { echo "no hay caché del tiempo que copiar ($src)"; exit 2; }
cp -r "$repo/shell/." "$tmp/shell/"
mkdir -p "$tmp/cache/ocarinashell" "$tmp/config" "$tmp/state"
# 2 h old: Weather.refresh() must try the network (and fail)
jq --argjson f "$(( ($(date +%s) - 7200) * 1000 ))" '.fetched = $f' "$src" > "$tmp/cache/ocarinashell/weather.json"
want="$(jq -r .temperature "$tmp/cache/ocarinashell/weather.json")"
cat > "$tmp/shell/shell.qml" <<'QML'
//@ pragma ShellId ocarina-sim-g
import QtQuick
import Quickshell
import qs.services
ShellRoot {
    Timer { interval: 1500; running: true; onTriggered: { console.info("SIM before", Weather.temperature, Weather.available); Weather.refresh(); } }
    Timer { interval: 6000; running: true; onTriggered: { console.info("SIM after", Weather.temperature, Weather.available, "error=" + Weather.error, "days=" + Weather.daily.length); Qt.quit(); } }
}
QML
XDG_CACHE_HOME="$tmp/cache" XDG_CONFIG_HOME="$tmp/config" XDG_STATE_HOME="$tmp/state" \
  timeout 20 unshare -rn qs -p "$tmp/shell/shell.qml" > "$tmp/log" 2>&1
log="$(sed 's/\x1b\[[0-9;]*m//g' "$tmp/log")"
grep 'SIM' <<<"$log" | sed 's/^.*SIM/  SIM/'
pass=0 fail=0
unshare -rn sh -c 'curl -s -m 3 -o /dev/null https://api.open-meteo.com' && { fail=$((fail + 1)); echo "  ✗ ¡hay red dentro del espacio aislado!"; } \
  || { pass=$((pass + 1)); echo "  ✓ sin red de verdad dentro del espacio aislado"; }
after="$(grep 'SIM after' <<<"$log")"
[[ "$after" == *"after $want true"* ]] && { pass=$((pass + 1)); echo "  ✓ temperatura desde la caché: $want °C (available=true)"; } \
  || { fail=$((fail + 1)); echo "  ✗ no muestra la caché: $after"; }
[[ "$after" == *"error=HTTP 0"* || "$after" == *"error="?* ]] && { pass=$((pass + 1)); echo "  ✓ el fallo de red queda en Weather.error ($(sed -E 's/.*error=([^ ]+ [^ ]+).*/\1/' <<<"$after"))"; } \
  || { fail=$((fail + 1)); echo "  ✗ sin error registrado"; }
[[ "$(jq -r .temperature "$tmp/cache/ocarinashell/weather.json")" == "$want" ]] && { pass=$((pass + 1)); echo "  ✓ la caché sigue intacta (no se sobrescribe con nada)"; } \
  || { fail=$((fail + 1)); echo "  ✗ la caché cambió"; }
errs="$(grep -E 'TypeError|ReferenceError' <<<"$log" | head -n 3)"
[[ -z "$errs" ]] && { pass=$((pass + 1)); echo "  ✓ sin errores QML"; } || { fail=$((fail + 1)); echo "  ✗ $errs"; }
echo "resultado: $pass bien · $fail mal"
((fail == 0))
