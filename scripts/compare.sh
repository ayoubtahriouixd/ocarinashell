#!/usr/bin/env bash
# Mockup vs capture: montage [MOCKUP | CAPTURA | DIFERENCIA] + RMSE score.
# usage: scripts/compare.sh <captura.png> <mockup.png|01|02|…> [--crop WxH+X+Y] [--out ruta.png]
# Then LOOK at the output with Read. RMSE ~0.00 identical · <0.05 very close · >0.15 clearly different.
set -euo pipefail

cap="${1:?uso: scripts/compare.sh <captura.png> <mockup.png|NN> [--crop WxH+X+Y] [--out ruta]}"
mock="${2:?falta el mockup}"; shift 2
crop=""; out=""
while (($#)); do
  case "$1" in
    --crop) crop="$2"; shift 2 ;;
    --out) out="$2"; shift 2 ;;
    *) echo "opción desconocida: $1" >&2; exit 1 ;;
  esac
done

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
if [[ ! -f "$mock" ]]; then
  match=$(find "$root/assets/mockups" -maxdepth 1 -name "${mock}*.png" -print -quit 2>/dev/null || true)
  [[ -n "$match" ]] || { echo "mockup no encontrado: $mock" >&2; exit 1; }
  mock="$match"
fi
[[ -f "$cap" ]] || { echo "captura no encontrada: $cap" >&2; exit 1; }

if command -v magick >/dev/null; then IM=(magick); CMP=(magick compare)
else IM=(convert); CMP=(compare); fi

base="$(basename "${cap%.png}")"
out="${out:-$root/docs/evidencias/compare-$base.png}"
mkdir -p "$(dirname "$out")"
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

size=$("${IM[@]}" "$mock" -format '%wx%h' info: 2>/dev/null || identify -format '%wx%h' "$mock")
"${IM[@]}" "$mock" "$work/m.png"
"${IM[@]}" "$cap" -resize "${size}!" "$work/c.png"
if [[ -n "$crop" ]]; then
  "${IM[@]}" "$work/m.png" -crop "$crop" +repage "$work/m.png"
  "${IM[@]}" "$work/c.png" -crop "$crop" +repage "$work/c.png"
fi
rmse=$("${CMP[@]}" -metric RMSE "$work/m.png" "$work/c.png" "$work/d.png" 2>&1 >/dev/null || true)
label() { "${IM[@]}" "$1" -background '#111' -fill '#eee' -gravity North -splice 0x44 -pointsize 26 -annotate +0+8 "$2" "$3"; }
label "$work/m.png" "MOCKUP" "$work/m2.png"
label "$work/c.png" "CAPTURA" "$work/c2.png"
label "$work/d.png" "DIFERENCIA (rojo = distinto)" "$work/d2.png"
# wide strips (e.g. the bar) are stacked vertically so they stay readable
read -r w h < <("${IM[@]}" "$work/m.png" -format '%w %h\n' info: 2>/dev/null || identify -format '%w %h\n' "$work/m.png")
if (( w > 2 * h )); then
  "${IM[@]}" "$work/m2.png" "$work/c2.png" "$work/d2.png" -background '#111' -splice 0x12 -append "$out"
else
  "${IM[@]}" "$work/m2.png" "$work/c2.png" "$work/d2.png" -background '#111' -splice 12x0 +append "$out"
fi
echo "$out"
echo "RMSE: ${rmse}"
