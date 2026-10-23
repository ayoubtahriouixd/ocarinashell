#!/usr/bin/env bash
# OcarinaShell · compiles shell/shaders/*.frag|*.vert to .qsb (Qt Shader Baker). The .qsb files are versioned.
# usage: scripts/build-shaders.sh [--check]   (--check: fail if any .qsb is missing or older than its source)
set -euo pipefail
dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/shell/shaders"
qsb="$(command -v qsb || echo /usr/lib/qt6/bin/qsb)"
[[ -x "$qsb" ]] || { echo "falta qsb (pacman -S qt6-shadertools)" >&2; exit 1; }
check=0; [[ "${1:-}" == "--check" ]] && check=1
rc=0
for src in "$dir"/*.frag "$dir"/*.vert; do
  [[ -e "$src" ]] || continue
  out="$src.qsb"
  if ((check)); then
    [[ -f "$out" && "$out" -nt "$src" ]] || { echo "✗ ${out##*/} desactualizado"; rc=1; }
    continue
  fi
  "$qsb" --glsl "100 es,120,150" --hlsl 50 --msl 12 -o "$out" "$src"
  echo "✓ ${out##*/}"
done
exit "$rc"
