#!/usr/bin/env bash
# The power-relevant state of the machine, read from the system itself (not from the shell), one «key=value» per line.
# Used to prove that leaving 忍 Shinobi (or 鬼 Oni) puts everything back:
#   scripts/power-state.sh > antes.txt; ocarina shinobi on; …; ocarina shinobi off; scripts/power-state.sh | diff antes.txt -
set -euo pipefail

st=/usr/local/libexec/ocarina-powerctl
bl=$(find /sys/class/backlight -mindepth 1 -maxdepth 1 -print -quit)
[[ -n "$bl" ]] && echo "brillo=$(( $(cat "$bl/brightness") * 100 / $(cat "$bl/max_brightness") )) %"
niri msg --json outputs | python3 -c '
import json, sys
for n, o in sorted(json.load(sys.stdin).items()):
    m = o.get("current_mode")
    if m is not None:
        mm = o["modes"][m]
        print("pantalla.%s=%dx%d@%.0f" % (n, mm["width"], mm["height"], mm["refresh_rate"] / 1000))'
echo "perfil=$(powerprofilesctl get 2>/dev/null || echo ?)"
if [[ -x "$st" ]]; then
  "$st" status | python3 -c '
import json, sys
d = json.load(sys.stdin)
print("turbo=%s" % d["boost"]); print("epp=%s" % d["epp"]); print("gpu=%s" % d["gpu"])
print("carga=%s-%s" % (d["charge"]["start"], d["charge"]["end"]))
for i, v in sorted(d["wifiPs"].items()): print("wifi-ahorro.%s=%s" % (i, v))
f = d.get("fan") or {}; print("ventilador=%s" % f.get("level", "?")); print("scx=%s" % (d.get("scx") or "no"))'
fi
echo "bluetooth=$(busctl get-property org.bluez /org/bluez/hci0 org.bluez.Adapter1 Powered 2>/dev/null | awk '{print $2}' || echo ?)"
echo "teclado=$(busctl --json=short call org.freedesktop.UPower /org/freedesktop/UPower/KbdBacklight \
  org.freedesktop.UPower.KbdBacklight GetBrightness 2>/dev/null | python3 -c 'import json,sys; print(json.load(sys.stdin)["data"][0])' || echo ?)"
state="${XDG_STATE_HOME:-$HOME/.local/state}/ocarinashell"
echo "tema=$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1])).get("id","?"))' "$state/theme.json" 2>/dev/null || echo ?)"
n=$(grep -c '^animations' "$state/niri/shinobi.kdl" 2>/dev/null || true); echo "niri.shinobi=${n:-0}"
n=$(grep -c '^window-rule' "$state/niri/oni.kdl" 2>/dev/null || true); echo "niri.oni=${n:-0}"
grep -q 'variable-refresh-rate' "$state/niri/outputs.kdl" 2>/dev/null && echo "vrr=$(grep -o 'variable-refresh-rate.*' "$state/niri/outputs.kdl" | head -1)"
echo "governor=$(cat /sys/devices/system/cpu/cpufreq/policy0/scaling_governor)"
echo "no-molestar=$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["notifications"]["dnd"])' "${XDG_CONFIG_HOME:-$HOME/.config}/ocarinashell/settings.json" 2>/dev/null || echo ?)"
for u in ocarina-cliphist-img ocarina-nightlight; do echo "unidad.$u=$(systemctl --user is-active "$u" 2>/dev/null || true)"; done
fx="$state/theme/effects.json"
[[ -r "$fx" ]] && echo "efectos=$(tr -d ' \n' < "$fx")"
true
