# Fase 03 · Núcleo de la shell: arquitectura QML, servicios, Obi, Shima, fondo y modo seguro

**Objetivo**: la columna vertebral de OcarinaShell funcionando como servicio: singletons de diseño, servicios
dirigidos por eventos, IPC completo, CLI con respaldo, fondo con transición de tinta y la barra + isla idénticas al
mockup 01. Esta fase marca la calidad de todo lo demás: no la cierres hasta que la captura y el mockup coincidan.
**Lee antes**: `docs/01-ARQUITECTURA.md` completo, `docs/02-DISENO.md`, `docs/04-RENDIMIENTO.md`,
`docs/06-ACTUALIZACIONES.md` (capas 3–4), mockups 01 y 02, `assets/logo/qml/OcarinaLogo.qml`, documentación de
Quickshell 0.3.x (delega: guía de inicio, PanelWindow, WlrLayershell, BackgroundEffect, Region, Variants, LazyLoader,
Singleton, IpcHandler, FileView/JsonAdapter, Socket/SplitParser, Process, SystemClock, Pipewire, UPower/PowerProfiles,
Mpris, SystemTray, DesktopEntries, ColorQuantizer, PwNodePeakMonitor).

## Tareas
1. **Snapshot**. Lanza el desarrollo con una instancia de prueba (`qs -p shell/shell.qml`) mientras construyes; activa
   `ocarinashell.service` cuando la barra sea estable.
2. **Singletons de config** (`shell/config/`): `Theme` (lee `~/.local/state/ocarinashell/theme.json` con
   `watchChanges`; expone `colors`, `font`, `radius`, `space()`, métricas de barra/isla; colores con `Behavior`/
   `ColorAnimation` para el fundido entre temas), `Motion` (ver 02-DISENO §4; `enabled` ligado a Shinobi/Oni y a
   movimiento reducido), `Settings` (`FileView`+`JsonAdapter`, valores por defecto completos, `version` y migración),
   `Paths`, `Glossary` (kanji-ui.json). Componente `Anim` y primitivas de `components/` necesarias para esta fase.
3. **Servicio `Niri`**: `Socket` a `$NIRI_SOCKET` → `"EventStream"` → `SplitParser` → modelos de outputs/espacios/
   ventanas (incluido `WindowLayoutsChanged`, `WindowFocusTimestampChanged`, `OverviewOpenedOrClosed`,
   `KeyboardLayoutsChanged`). Acciones por un segundo socket o `niri msg action`. Reconexión con backoff. Sin sondeo.
4. **Servicios** `Time`, `Audio`, `Brightness`, `Power`, `Media`, `Kisetsu`, `Weather` (caché + apagado en Shinobi),
   `Sounds` (pw-play). Contratos según ARQUITECTURA §5.
   - **`Brightness` multipantalla** (Ayoub lo pidió expresamente: al conectar uno o más monitores, cada uno con su
     brillo desde el mismo menú). Modelo con una entrada por pantalla (`name`, `label`, `kind` internal|ddc|soft|none,
     `pct`, `bus`, `key`) que se rehace SOLO cuando cambia `Quickshell.screens`. Comprueba antes: `ddcutil --version`,
     `lsmod | grep i2c_dev` y que `ddcutil detect` funciona **sin sudo** (el paquete de Arch trae
     `/usr/lib/modules-load.d/ddcutil.conf` y la regla udev `60-ddcutil-i2c.rules` con `uaccess`; si el módulo aún no
     está cargado, `sudo modprobe i2c-dev` una vez). Detección 2 s después del cambio, en segundo plano (`Process`),
     con parseo tolerante de `ddcutil detect` (`I2C bus`, `DRM connector`, `EDID synopsis`, «Invalid display») y
     escritura atómica de `~/.local/state/ocarinashell/brightness.json`. Escritura DDC con cola por bus y coalescencia
     (ARQUITECTURA §5); la interna sigue al kernel por eventos. **`ocarina-dim`** (atenuación por software para
     pantallas sin DDC/CI): una `PanelWindow` por pantalla que SOLO existe si su nivel < 100 %, capa `Overlay`, `mask:
     Region {}`, `exclusionMode: Ignore`, opacidad máx. 0,6 (nunca negro total), sin sombra (regla de capa). Teclas de
     brillo: `keysTarget` (por defecto la pantalla con el foco de niri); Mayús + tecla = todas. Amplía el respaldo del
     CLI: `--output`/`--all` con `ddcutil --bus N` leyendo `brightness.json`. Iro y Yomu ocultan `ocarina-dim` un
     instante al capturar (si no, la captura sale oscurecida). Por DDC/CI solo se escriben brillo (10) y contraste
     (12): el hook de guardia bloquea el resto.
5. **IPC** (`ipc/Ipc.qml`): TODOS los destinos y funciones de ARQUITECTURA §6; los módulos que aún no existen
   responden con un aviso «pendiente (fase N)». **CLI `bin/ocarina`** completo con respaldos y `--wait` del bloqueo.
6. **Kabegami (renderizado)**: `WlrLayer.Background`, namespace `ocarina-wallpaper`, una por pantalla; `Image` con
   `sourceSize` físico; transición «mancha de tinta» con `ShaderEffect` (fuente `shaders/inkwipe.frag` en GLSL 440
   al estilo Qt 6 —bloque uniforme `buf` con `qt_Matrix` y `qt_Opacity`—, compilado con
   `qsb --glsl "100 es,120,150" --hlsl 50 --msl 12 -o shaders/inkwipe.frag.qsb shaders/inkwipe.frag`; ruido + máscara
   radial con borde irregular, 700 ms); difuminado pre-renderizado (vips/magick) en `~/.cache/ocarinashell/wallpapers/`
   para bloqueo y backdrop; en Shinobi: negro sólido.
7. **Obi (barra)** exactamente como el mockup 01 (medidas en 02-DISENO §5): vidrio con `BackgroundEffect.blurRegion`
   redondeado (Region con radio), marca plana, espacios kanji con el **hanko deslizante con muelle**, puntos de
   ventanas, urgente con pulso, rueda/clic/clic derecho; título de la ventana enfocada con icono de la app
   (`DesktopEntries.heuristicLookup`); bandeja (`SystemTray` + menús con `QsMenuOpener`, tematizados); clúster de
   estado (Wi-Fi/BT/volumen/anillo de batería/perfil 省均速/campana); huecos para los indicadores 船 y 新. Barra por pantalla.
8. **Shima (isla)**: estados reposo/hover/música/OSD con morph de muelle (02-DISENO §5): ecualizador real con
   `PwNodePeakMonitor` (solo visible + música sonando + no Shinobi), portada con `ColorQuantizer`, OSD para volumen,
   brillo, micro, perfil; hover con fecha kanji (`神無月 · 十三日 · 火曜日`) y microestación (`菊花開 · florecen…`).
9. **Esquinas de pantalla redondeadas** (opcional, ajuste): 4 superficies diminutas en `Overlay` sin entrada.
10. **Servicio systemd** activado; retirar lo que quede de barras/demonios previos.
11. **Red de seguridad desde ya** (06-ACTUALIZACIONES, capas 3–4): unidad con `StartLimitIntervalSec=60`,
    `StartLimitBurst=4`, `OnFailure=ocarinashell-safe.service`; **modo seguro básico** `shell/safe/shell.qml` (solo
    tipos básicos: barra mínima con sello 殻 «Modo seguro», reloj, batería y botones Reintentar/Terminal/Ver errores/
    Bloquear). Patrones obligatorios desde esta fase: módulos sensibles en su propio fichero cargado por `Loader`,
    `available`/`error` en cada servicio, parser de niri tolerante, `settings.json` con esquema/migración y copia si
    está corrupto, escrituras atómicas.
12. **保護 Hogo · cuidado del OLED** (`docs/07-IDEAS.md`; ajuste `oled`): el contenido de Obi y Shima se desplaza en un
    ciclo de 4 posiciones de ±2 px **físicos** (2/escala en lógicos, para que el texto no se emborrone) cada 15 min
    —se mueve el contenido, nunca la superficie: la zona exclusiva no cambia— y, tras 3 min sin puntero ni cambios en
    la barra, baja al 80 % de opacidad con un fundido de 1 s (vuelve al instante con hover, OSD o aviso). Todo cuelga
    del tic de minutos de `Time`: ningún `Timer` propio. Fuera en pantalla completa y en Shinobi (ya atenuado).

## Criterios de aceptación
- [ ] Captura `scripts/shot.sh fase-03/escritorio` vs `01-escritorio.png` revisada con `scripts/compare.sh`; el
      agente `visual-qa` no encuentra diferencias de severidad alta en barra, isla, espacios y fondo.
- [ ] `ocarina audio up/down/mute`, `brightness up/down`, `media toggle` → OSD en la isla; teclas físicas también.
- [ ] **Brillo multipantalla**, con un monitor externo de Ayoub (si no hay ninguno a mano, déjalo pendiente en PROGRESS.md
      y se cierra en la fase 4): al conectarlo, `ocarina brightness list` lo muestra en < 4 s con `kind: ddc` (o `soft` si
      no tiene DDC/CI) y sin errores en el journal; `ocarina brightness set 30 --output <salida>` cambia SOLO ese monitor;
      las teclas siguen `keysTarget` y el OSD nombra la pantalla; al desconectarlo desaparece; con la shell parada,
      `ocarina brightness up --all` sigue funcionando. Cero procesos `ddcutil` en reposo.
- [ ] Hanko de espacios se desliza con muelle; morph de la isla fluido (sin saltos con `QSG_RENDER_TIMING`).
- [ ] Reposo: CPU de `qs` < 0,3 %, despertares < 2/s, sin repintados (04-RENDIMIENTO) → anota métricas.
- [ ] `systemctl --user kill ocarinashell` → vuelve sola en < 2 s; con la shell parada, las teclas usan el respaldo.
- [ ] Cero avisos/errores QML en el journal durante 5 min de uso.
- [ ] Hogo: con `QSG_VISUALIZE=changes` (y el ciclo acortado a 1 min para la prueba) la barra solo repinta con el reloj
      y en cada desplazamiento; el texto sigue nítido en las 4 posiciones.
- [ ] Introduce un error de sintaxis a propósito en una rama de prueba → aparece el modo seguro en < 5 s; al revertir,
      «Reintentar» devuelve la shell normal.

## Al terminar
PROGRESS.md (con métricas), commit, y a Ayoub: qué mirar (hanko, isla con música, OSD, transición de fondo con
`ocarina wallpaper next`).
