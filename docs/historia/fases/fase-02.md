# Fase 02 · Identidad: motor de temas, GTK/Qt, iconos, cursor, fondos y logo

**Objetivo**: que TODO el sistema hable el mismo idioma visual desde una única fuente (`assets/data/themes/*.json`)
y que cambiar de tema sea un solo comando con resultado coherente en niri, GTK, Qt, terminal y editor.
**Lee antes**: `docs/02-DISENO.md` §1–2, `docs/01-ARQUITECTURA.md` §9, `assets/data/themes/kurenai.json`.

## Tareas
1. **Snapshot**.
2. **`bin/ocarina-theme`** (Python stdlib, `#!/usr/bin/env python3`, < 400 líneas):
   - `ocarina-theme apply <id> [--accent HEX]` · `list` · `current` · `from-wallpaper <ruta>` (matugen) · `--dry-run`.
   - Resuelve tokens (tema + acento + derivados: `accentHover`, `accentSoft`, variantes con alfa en formato de cada
     destino) → escribe `~/.local/state/ocarinashell/theme.json` (lo lee la shell).
   - Renderiza `templates/**` con `{{token}}` / `{{token|rgb}}` / `{{token|alpha:0.72}}` / `{{token|nohash}}`; escribe
     de forma atómica (tmp + rename); registro de destinos en `templates/manifest.json` (plantilla → ruta → recarga).
   - Recargas: niri (automática), Ghostty (la vía soportada por la versión instalada: señal o acción de recarga;
     verifícalo), Neovim (vigila su fichero), gsettings (`color-scheme`, `gtk-theme` adw-gtk3/adw-gtk3-dark,
     `icon-theme`, `cursor-theme`, `font-name` «Geist 11», `monospace-font-name` «JetBrains Mono 11»,
     `accent-color` más cercano), `papirus-folders -C red` (o el color más cercano al acento).
3. **Plantillas** (`templates/`): niri `colors.kdl` (anillo de foco degradado, sombras, insert-hint, pestañas,
   recent-windows, overview backdrop), Ghostty `themes/ocarina` (16 ANSI + fondo/primer plano/cursor/selección),
   Neovim `palette.lua`, fish (colores de sintaxis + `FZF_DEFAULT_OPTS` + `EZA_COLORS`), starship (paleta), btop
   (`ocarina.theme`), yazi (flavor), fastfetch (colores), bat (vía ANSI o tmTheme generado), GTK3 y GTK4
   (`gtk.css` con `@define-color` sobre adw-gtk3/libadwaita: acento, fondos de ventana/vista/cabecera, popovers),
   qt6ct (`colors/ocarina.conf` + `qt6ct.conf`: estilo Fusion, paleta, fuentes), swaylock (respaldo con nuestros
   colores y fondo), MangoHud (fase 11) y variante de Limine/Plymouth (fase 13) si procede.
4. **Fondos**: copia `assets/wallpapers/*.jpg` (solo los fondos; la hoja de contactos vive en `preview/`) a
   `~/.local/share/ocarinashell/wallpapers/` y crea `~/Imágenes/Fondos`
   (nombre real de XDG). Cada tema apunta a su fondo por defecto.
5. **Logo en el sistema**: iconos `ocarinashell` en `~/.local/share/icons/hicolor/<tam>/apps/` (PNG de
   `assets/logo/png/` + SVG escalable), `.desktop` para «Ajustes de OcarinaShell» (llama a `ocarina settings`).
   Fastfetch: logo `assets/logo/png/ocarinashell-mark-512.png` vía protocolo de imágenes de kitty (lo soporta Ghostty).
6. **Cursor e iconos**: Bibata (variante oscura/clara según tema), Papirus(-Dark) con carpetas rojas; coherencia en
   niri `cursor`, gsettings y `XCURSOR_*`.
7. **Comprobación tipográfica**: abre Nautilus y un diálogo Qt, y verifica kanji con formas japonesas (直 骨 曜) en
   GTK, Qt y terminal.

## Criterios de aceptación
- [ ] `ocarina-theme apply kurenai` y `apply kohaku` cambian TODOS los destinos sin errores, en < 1,5 s.
- [ ] Capturas antes/después (Nautilus, diálogo Qt, Ghostty provisional) en `docs/evidencias/fase-02/`.
- [ ] Ningún fichero de destino a medio escribir si algo falla (escritura atómica, `--dry-run` probado).
- [ ] Kanji con formas JP en todas partes; iconos y cursor coherentes.

## Al terminar
PROGRESS.md, commit, y a Ayoub: cómo cambiar de tema hoy (`ocarina-theme apply …`) — en la fase 7 será desde Ajustes.
