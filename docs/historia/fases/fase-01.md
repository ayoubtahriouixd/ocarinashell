# Fase 01 · niri: compositor, binds y comportamiento

**Objetivo**: un niri modular, validado y precioso por sí mismo: entrada afinada para el ThinkPad, el cursor sigue a
las ventanas, binds adaptados, animaciones con firma (shaders de tinta) y todo preparado para la shell.
**Lee antes**: `docs/03-ATAJOS.md`, `reference/binds-ocarina.kdl`, mockup `01-escritorio.png`, y la wiki de niri de
TU versión (delega en un subagente: Overview, Input, Outputs, Layout, Animations, Window Rules, Layer Rules,
Key Bindings, Recent Windows, Miscellaneous, Include, IPC, Xwayland).

## Tareas
1. **Snapshot** y copia de `~/.config/niri` (si no es ya enlace).
2. **Estructura** en `config/niri/`: `config.kdl` con `include` de `ocarina/{input,layout,appearance,
   animations,rules,layer-rules,binds,recent-windows,environment,startup,misc}.kdl` + includes generados con
   `include optional=true "~/.local/state/ocarinashell/niri/{colors,outputs,shinobi,oni,fune-rules,honban-rules,
   user-rules,overrides}.kdl"`. Cada include generado tiene UN solo dueño (`user-rules` = Mado, `honban-rules` = Honban,
   `outputs` = `Displays`/Haichi).
   ⚠ Antes de partir secciones (p. ej. `layout {}` en dos ficheros) comprueba en la wiki cómo FUSIONA niri las
   secciones repetidas entre includes. Si no fusiona en profundidad, cada sección vive entera en un solo fichero y
   lo generado se limita a secciones completas (p. ej. `colors.kdl` contiene el bloque `layout` entero generado
   desde plantilla). Documenta la decisión en DECISIONES.md.
3. **Entrada**: xkb según la entrevista, `repeat-delay 260`, `repeat-rate 40`; touchpad `tap`, `natural-scroll`,
   `dwt`, `dwtp`, `click-method "clickfinger"`, `accel-speed` ≈0,25 (ajustar con Ayoub); TrackPoint `accel-profile
   "flat"` + velocidad cómoda + scroll con botón central; táctil `map-to-output "eDP-1"` (nombre real);
   `focus-follows-mouse max-scroll-amount="0%"` + `warp-mouse-to-focus` + `workspace-auto-back-and-forth`;
   `disable-power-key-handling` (el botón abrirá Dengen).
4. **Salidas**: escribe la primera versión del include generado `~/.local/state/ocarinashell/niri/outputs.kdl` (el
   ÚNICO sitio con bloques `output`: niri no fusiona `output` repetidos entre includes): eDP-1 con el modo exacto
   2880×1800@120 de `niri msg outputs`, escala de la entrevista, VRR `on-demand=true` solo si el panel lo anuncia (se
   evalúa en fase 10). Desde la fase 7 lo regenera Haichi (`Displays`), también para los cambios de Hz de Shinobi/Oni.
5. **Layout**: `gaps 12`, `center-focused-column "never"`, `always-center-single-column`, `preset-column-widths` 1/3 ·
   1/2 · 2/3, `default-column-width { proportion 0.5; }`, `focus-ring` 2 px con degradado `#e60033 → #ff1f4f` (lo
   genera el motor de temas en la fase 2 desde `focusRing` del tema; pon ahora el valor Kurenai), `border off`,
   `shadow { on; softness 30; spread 4; offset x=0 y=6; color "#00000080"; }`, `background-color "transparent"`,
   indicador de pestañas y `insert-hint` con el acento.
6. **Reglas de ventana**: global `geometry-corner-radius 14` + `clip-to-geometry true`; flotantes centradas para
   diálogos de portal/selector de archivos, `pavucontrol`, `nm-connection-editor`, `blueman`, `satty`, imagen-en-imagen
   de Chrome (abajo-derecha, 480×270), ajustes de OcarinaShell (por título). Chrome con `default-column-width 2/3`.
   Opcional (pregunta): `block-out-from "screencast"` para gestores de contraseñas.
7. **Reglas de capa**: `ocarina-wallpaper` → `place-within-backdrop true`; `^ocarina-` (paneles/popups) → sombra
   suave de niri, salvo `ocarina-dim` (atenuación por software del brillo) y las esquinas, sin sombra; nada de blur
   configurado por niri: lo pedirá la shell con `BackgroundEffect` (así Shinobi lo apaga).
8. **Animaciones**: muelles y curvas a medida (cambio de espacio `spring damping-ratio=1.0 stiffness=900`, vista
   general, movimiento de ventanas…). **Shaders personalizados**: `window-open` «florecer de tinta» (revelado radial
   desde el centro con borde suave y un leve escalado; tono rojo tenue en el frente de la tinta), `window-close`
   «disolución» (ruido + desplazamiento hacia arriba). Estudia los ejemplos de la wiki, mantén los shaders cortos
   (< 60 líneas), sin bucles costosos, y prueba con distintas ventanas. Crea también `shinobi.kdl` de referencia
   (`animations { off }`, sin sombras) para la fase 10 — no se incluye aún.
9. **Binds**: instala `reference/binds-ocarina.kdl` → `ocarina/binds.kdl` adaptando keysyms a la distribución real
   (03-ATAJOS §Comprobación). Crea ya `bin/ocarina` con los respaldos (wpctl/brightnessctl/swaylock/notify-send) para
   que todos los binds funcionen antes de que exista la shell (`brightness up|down` ya acepta `--all`/`--output`; hasta
   la fase 3 solo mueve la interna). `hotkey-overlay-title` en español para los nuestros.
10. **Recent windows**: binds de Alt (ya en el borrador) + `highlight` con el acento y `corner-radius 16`.
11. **Varios**: `prefer-no-csd`, `screenshot-path` en la carpeta real de imágenes (`xdg-user-dir PICTURES`/Capturas),
   `hotkey-overlay { skip-at-startup; }`, `cursor` (tema de la fase 0, tamaño 24, `hide-when-typing`,
   `hide-after-inactive-ms 2500`), `environment` (`QT_QPA_PLATFORMTHEME "qt6ct"`, `ELECTRON_OZONE_PLATFORM_HINT
   "auto"`, cursor), `overview` (zoom ~0,55, `backdrop-color` del tema, sombra de espacios), `gestures`/hot corners
   según preferencia de Ayoub, `clipboard { disable-primary }` solo si él quiere.
12. **systemd --user**: crea en `systemd/user/` las unidades de cliphist (texto e imagen) y actívalas; deja creada
   pero desactivada `ocarinashell.service` (fase 3).
13. Ejecuta `scripts/install.sh`, `niri validate`, y observa la recarga en vivo.

## Criterios de aceptación
- [ ] `niri validate` OK; config modular en git; includes opcionales no rompen si faltan.
- [ ] Foco sigue al ratón y el cursor salta al enfocar con teclado (Ayoub lo confirma).
- [ ] Todos los binds originales funcionan (prueba los de niri con `niri msg action …` y pide a Ayoub probar
      multimedia/brillo); los de la shell ya responden vía respaldo del CLI.
- [ ] Shaders de abrir/cerrar visibles, fluidos y sin artefactos (graba 5 s con `wf-recorder` y revisa fotogramas).
- [ ] Capturas en `docs/evidencias/fase-01/`; niri en reposo ~0 % CPU.

## Riesgos
Nunca `niri msg action quit` ni reiniciar niri. Si un cambio de entrada deja el teclado inusable, la config anterior
vuelve con `git checkout` desde la terminal ya abierta (ten siempre una terminal abierta durante la fase).

## Al terminar
PROGRESS.md, commit, y a Ayoub: lista de 5 cosas para probar (FFM, Alt+Tab, Mod+Tab, multimedia, animaciones).
