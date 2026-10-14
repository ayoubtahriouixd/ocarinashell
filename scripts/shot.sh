#!/usr/bin/env bash
# Screen capture for visual verification (native resolution: 2880x1800 on the P14s).
# usage: scripts/shot.sh <nombre> [--delay S] [--crop WxH+X+Y] [--output NAME]
#   <nombre> may contain sub-folders, e.g. fase-03/escritorio  → docs/evidencias/fase-03/escritorio.png
#   --crop uses PHYSICAL pixels (same coordinates as the mockup PNGs).
set -euo pipefail

name="${1:?uso: scripts/shot.sh <nombre> [--delay S] [--crop WxH+X+Y] [--output NAME]}"; shift
delay=0; crop=""; output=""
while (($#)); do
  case "$1" in
    --delay) delay="$2"; shift 2 ;;
    --crop) crop="$2"; shift 2 ;;
    --output) output="$2"; shift 2 ;;
    *) echo "opción desconocida: $1" >&2; exit 1 ;;
  esac
done

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
out="$root/docs/evidencias/${name%.png}.png"
mkdir -p "$(dirname "$out")"
command -v grim >/dev/null || { echo "falta grim (pacman -S grim)" >&2; exit 1; }

if [[ -z "$output" ]]; then
  output=$(niri msg --json focused-output 2>/dev/null | python3 -c 'import json,sys; print(json.load(sys.stdin)["name"])' 2>/dev/null || true)
fi
sleep "$delay"
tmp=$(mktemp --suffix=.png)
trap 'rm -f "$tmp"' EXIT
if [[ -n "$output" ]]; then grim -o "$output" "$tmp"; else grim "$tmp"; fi

if [[ -n "$crop" ]]; then
  if command -v magick >/dev/null; then magick "$tmp" -crop "$crop" +repage "$out"
  else convert "$tmp" -crop "$crop" +repage "$out"; fi
else
  cp "$tmp" "$out"
fi
echo "$out"
