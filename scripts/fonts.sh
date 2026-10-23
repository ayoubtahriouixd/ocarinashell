#!/usr/bin/env bash
# OcarinaShell · installs the brand fonts (OFL / Apache-2.0) into ~/.local/share/fonts/ocarinashell/. Idempotent.
# usage: scripts/fonts.sh [--force]
# Sources: github.com/google/fonts (OFL) and github.com/google/material-design-icons (Apache-2.0).
# Every download is checked to be a real TrueType/OpenType file before it replaces anything; checksums of what is
# installed are written to SHA256SUMS in the target folder (Mamori compares them on updates).
set -euo pipefail

dest="${XDG_DATA_HOME:-$HOME/.local/share}/fonts/ocarinashell"
gf="https://raw.githubusercontent.com/google/fonts/main/ofl"
md="https://raw.githubusercontent.com/google/material-design-icons/master"
force=0; [[ "${1:-}" == "--force" ]] && force=1

# <url> <file name in $dest>
files=(
  "$gf/geist/Geist%5Bwght%5D.ttf                        Geist[wght].ttf"
  "$gf/geist/Geist-Italic%5Bwght%5D.ttf                 Geist-Italic[wght].ttf"
  "$gf/geist/OFL.txt                                    LICENSE-Geist.txt"
  "$gf/zenkakugothicnew/ZenKakuGothicNew-Light.ttf      ZenKakuGothicNew-Light.ttf"
  "$gf/zenkakugothicnew/ZenKakuGothicNew-Regular.ttf    ZenKakuGothicNew-Regular.ttf"
  "$gf/zenkakugothicnew/ZenKakuGothicNew-Medium.ttf     ZenKakuGothicNew-Medium.ttf"
  "$gf/zenkakugothicnew/ZenKakuGothicNew-Bold.ttf       ZenKakuGothicNew-Bold.ttf"
  "$gf/zenkakugothicnew/OFL.txt                         LICENSE-ZenKakuGothicNew.txt"
  "$gf/shipporiminchob1/ShipporiMinchoB1-Regular.ttf    ShipporiMinchoB1-Regular.ttf"
  "$gf/shipporiminchob1/ShipporiMinchoB1-Medium.ttf     ShipporiMinchoB1-Medium.ttf"
  "$gf/shipporiminchob1/ShipporiMinchoB1-Bold.ttf       ShipporiMinchoB1-Bold.ttf"
  "$gf/shipporiminchob1/OFL.txt                         LICENSE-ShipporiMinchoB1.txt"
  "$gf/yujisyuku/YujiSyuku-Regular.ttf                  YujiSyuku-Regular.ttf"
  "$gf/yujisyuku/OFL.txt                                LICENSE-YujiSyuku.txt"
  "$gf/unbounded/Unbounded%5Bwght%5D.ttf                Unbounded[wght].ttf"
  "$gf/unbounded/OFL.txt                                LICENSE-Unbounded.txt"
  "$md/variablefont/MaterialSymbolsRounded%5BFILL,GRAD,opsz,wght%5D.ttf        MaterialSymbolsRounded[FILL,GRAD,opsz,wght].ttf"
  "$md/variablefont/MaterialSymbolsRounded%5BFILL,GRAD,opsz,wght%5D.codepoints MaterialSymbolsRounded.codepoints"
  "$md/LICENSE                                          LICENSE-MaterialSymbols.txt"
)

mkdir -p "$dest"
tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
new=0
for entry in "${files[@]}"; do
  read -r url name <<<"$entry"
  out="$dest/$name"
  if [[ -s "$out" && $force -eq 0 ]]; then continue; fi
  printf '  descarga %s\n' "$name"
  curl -fsSL --retry 3 --proto '=https' -o "$tmp/f" "$url"
  if [[ "$name" == *.ttf ]]; then
    file -b "$tmp/f" | grep -qiE 'TrueType|OpenType' || { echo "✗ $name no es una fuente válida" >&2; exit 1; }
  fi
  mv "$tmp/f" "$out"; chmod 644 "$out"; new=1
done

( cd "$dest" && sha256sum -- *.ttf > SHA256SUMS )
if ((new)); then fc-cache -f "$dest" >/dev/null; echo "  fc-cache actualizado"; else echo "  fuentes al día"; fi
