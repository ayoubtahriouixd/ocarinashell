# tools/ — generadores de assets

Todo lo visual y sonoro del kit sale de aquí (nada de terceros) y ya está generado en `assets/`: solo hace falta
volver a ejecutarlos si cambias algo. Requisitos en CachyOS (sin tocar el Python del sistema):
```bash
sudo pacman -S --needed chromium qemu-desktop edk2-ovmf mtools dosfstools   # QEMU/OVMF solo para Limine
python -m venv ~/.local/share/ocarinashell/venv
~/.local/share/ocarinashell/venv/bin/pip install pillow numpy fonttools uharfbuzz playwright PySide6-Essentials
alias otools=~/.local/share/ocarinashell/venv/bin/python                  # otools tools/logo_gen.py …
```
Fuentes: `export OCARINA_FONTS=~/.local/share/fonts/ocarinashell` (las instala la fase 0). Chromium: el del sistema se
detecta solo (o `OCARINA_CHROMIUM=/usr/bin/chromium`). `PySide6-Essentials` solo hace falta para verificar el QML del
logo fuera de la shell.

| Script | Genera | Verificado así |
|---|---|---|
| `logo_gen.py [salida]` | logo completo: 19 SVG (estáticos y animados) + `logo-geometry.json` → `assets/logo/svg/` | render en Chromium |
| `logo_png.py` | PNG del icono (16–1024, plano ≤ 32), marca y wordmarks → `assets/logo/png/` | |
| `qml_logo_gen.py [geometry.json] [salida.qml]` | `assets/logo/qml/OcarinaLogo.qml` (QtQuick + Shapes, sin capas ni blur) | render offscreen con PySide6 6.12 contra el SVG: diferencia media < 1/255 |
| `logo_preview.py` | `assets/logo/preview.html` (todas las variantes animadas) | |
| `textpath.py` | utilidad: texto → contornos SVG con HarfBuzz | |
| `htmlshot.py` | utilidad: HTML/SVG → PNG con Chromium (la usan logo_png, mockups y boot_assets) | |
| `build_data.py` | `assets/data/*.json`: 7 temas (+ ANSI), 24 sekki + 72 kō, 42 kotowaza, glosario kanji, 31 colores, 105 kaomoji | comprueba contraste WCAG de cada tema y sale con error si algo no llega a AA |
| `emoji_es.py` | `assets/data/emoji-es.json`: nombres y palabras clave de 2307 emoji en español (Unicode CLDR 48, + palabras japonesas) | descarga única; la shell nunca descarga nada |
| `wallpapers.py [nombre…] [/dir] [--preview]` | `assets/wallpapers/*.jpg` (2880×1800, uno por tema) | `--preview` = hoja de contactos en `assets/wallpapers/preview/` |
| `sounds.py` | `assets/sounds/*.wav` (48 kHz, timbre de ocarina, pentatónica de La menor) | análisis espectral |
| `mockups.py [--fonts DIR] [--only NN,…] [--sheet]` | `assets/mockups/NN-*.png` + `src/*.html` + `src/tokens.css` (de los temas) | revisión visual pantalla a pantalla |
| `boot_assets.py [--previews]` | `assets/boot/`: fondos y bloque de tema de Limine, tema Plymouth (capas + script) | ver abajo |
| `limine-preview.py conf out.png --asset fichero=nombre` | arranca el Limine REAL en QEMU/OVMF con esa config y captura el menú | así se hicieron `limine/preview-*.png` |
| `readme_assets.py [--fonts DIR]` | `docs/img/`: previas ligeras de mockups y arranque, `recorrido.webp` animado y `social-preview.png` (1280×640) | las ve el README de GitHub |
| `release.py vX.Y.Z [--repo usuario/repo]` | `dist/`: zip reproducible del kit, `SHA256SUMS` y notas de la versión (de `CHANGELOG.md`) | escribe el repo en README e instalador |
| `publicar-github.sh [repo]` | publica desde tu equipo con GitHub CLI (crea el repo, sube el código y la release) | alternativa a la Action «publicar versión» |

Arranque: `limine/preview-*.png` son capturas del Limine 10.8.5 real en QEMU con `limine-test-*.conf`; los
`plymouth/preview-*.png` son capturas del tema ejecutándose en un plymouthd 24.004.60 real (renderer x11 bajo Xvfb, a
2880×1800). `boot_assets.py --previews` las sustituye por composiciones equivalentes hechas con Pillow.

```bash
export OCARINA_FONTS=~/.local/share/fonts/ocarinashell
otools tools/logo_gen.py && otools tools/logo_png.py && otools tools/qml_logo_gen.py && otools tools/logo_preview.py
otools tools/build_data.py && otools tools/wallpapers.py --preview && otools tools/sounds.py
otools tools/mockups.py --sheet && otools tools/boot_assets.py && otools tools/readme_assets.py
otools tools/limine-preview.py assets/boot/limine/limine-test-dark.conf /tmp/limine-dark.png \
  --asset assets/boot/limine/ocarinashell-limine-dark.png=ocarinashell-limine.png
```
