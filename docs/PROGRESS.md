# Progreso de OcarinaShell

> Claude Code: actualiza este fichero al terminar cada hito y SIEMPRE antes de compactar o cerrar la sesión.
> Formato por fase: estado · hecho · pendiente · métricas · problemas abiertos · qué debe probar Ayoub.

| Fase | Nombre | Estado |
|---|---|---|
| 00 | Reconocimiento, seguridad y cimientos | ✅ terminada |
| 01 | niri: compositor, binds y comportamiento | ✅ terminada |
| 02 | Identidad: fuentes, motor de temas, GTK/Qt, iconos, cursor | ✅ terminada |
| 03 | Núcleo de la shell: servicios, Obi, Shima, fondo, modo seguro | ✅ terminada |
| 04 | Engawa, OSD, Fumi (notificaciones), Koyomi | ✅ terminada |
| 05 | Torii, Kura, Techō, Mihari, Mado, renombrar, chuleta | ✅ (a falta de la prueba de Ayoub) |
| 06 | Kagi (bloqueo), inactividad, Dengen, polkit, greeter opcional | ✅ (a falta de 2 pruebas de Ayoub) |
| 07 | Settei (ajustes) y Kabegami (fondos) | ✅ (a falta del monitor externo y del recorrido de Ayoub) |
| 08 | Ghostty, fish, starship y herramientas CLI | ✅ terminada |
| 09 | Neovim | ✅ terminada |
| 10 | 忍 Shinobi (ahorro extremo) y afinado de energía | ✅ (a falta de la suspensión de 1 h y del reinicio) |
| 11 | 鬼 Oni: rendimiento extremo y juegos (A) · 滑 Nameraka: vídeo fluido (B) | A ✅ (a falta de su juego, del reinicio y del ventilador) · B 🟨 (hecho; faltan las medidas de 5 min y tus pruebas) |
| 12 | 船 Fune: apps de Windows | ✅ (a falta de tu prueba de Win+F y de la medida de batería) |
| 13 | Arranque y apagado: Limine, Plymouth, greeter, despedida | ✅ (a falta de probar-kernel, del llavero «Default» y de las revisiones) |
| 14 | Blindaje: modo seguro, pruebas de humo, reversión, simulacros | ✅ terminada (a falta de tu reinicio normal: greeter con los arreglos) |
| 15 | 蛇 Snake: IA local | ✅ (gpt-oss-20b en Vulkan; primera palabra en caliente ~3 s, no < 2 s: D-074) |
| 16 | 守 Mamori: mantenimiento autónomo | ✅ (activo; primer ciclo automático 2026-10-18 04:12) |
| 17 | Pulido final, QA independiente y entrega | ✅ terminada · versión 2.0.0 |

Leyenda: ⬜ pendiente · 🟨 en curso · ✅ terminada · ⛔ bloqueada

## Registro
<!-- Añade aquí entradas con fecha: ## AAAA-MM-DD · Fase N · resumen -->

## 2026-10-14 · Fase 00 · ✅ reconocimiento, seguridad y cimientos
**Hecho**
- `docs/SISTEMA.md` completo (hardware, rutas sysfs, versiones, arranque, sesión, KVM, NPU, LVFS, conflictos).
- Snapshots **#37** «antes de empezar», **#38** «antes de fase 00», #47 antes de la actualización. Copia de la config de
  usuario en `~/ocarinashell-backup-2026-10-14.tar.zst`. `swaylock` instalado. `05-RESCATE.md` con datos reales.
- Entrevista → D-011…D-018 (escala 1,75, Kurenai, Chrome, greetd propio, huella en bloqueo+sudo/polkit, teclado es,
  Casablanca, carga 75–80 %, sonidos sí, arranque según tema, Limine 3 s). Zona horaria y formatos corregidos (D-016).
- Higiene: `paccache.timer` (-k3), `kernel-modules-hook` + `linux-modules-cleanup`, LTS ya en Limine, núcleo desde repos
  oficiales/CachyOS (`niri`, `quickshell` de cachyos-extra-znver4), `COMPAT.md` con la primera fila real.
- paru 2.1.0 del repo cachyos (el `paru-bin` estaba roto), `paru.conf` validado con su `man`, repo local `[ocarina-aur]`,
  `makepkg.conf` (ccache, /tmp, zstd -T0; flags de CachyOS heredados) probado con `tty-clock` (3,8 s / 2,5 s) — D-019.
- Paquetes base de repos + AUR (`google-chrome`, `bibata-cursor-theme-bin`, `papirus-folders`, PKGBUILD revisados).
  Mirrors ordenados y sistema al día (kernel 7.2.10) con `scripts/root/fase-00-sistema.sh` (lo ejecutó Ayoub).
- Fuentes de marca con `scripts/fonts.sh` + `60-ocarina-jp.conf` (lang=ja → Noto Sans CJK JP; antes KR) — D-020.
- Repo: esqueleto, `scripts/install.sh` (probado en HOME aislado: dry-run, idempotencia, desinstalar y restaurar),
  `scripts/install-system.sh`, `scripts/doctor.sh`. Hooks comprobados (JSON roto y shellcheck bloqueados; guard 201/201).

**Evidencias** `docs/evidencias/fase-00/`: `fuentes.png`, `doctor.txt` (0 problemas, 4 avisos esperados), `guard-tests.txt`.

**Pendiente / para otras fases**
- Fase 1: lanzar la sesión con `niri-session` (hoy `graphical-session.target` inactivo), 2880×1800 **@120 Hz** (ahora 60),
  VRR, sustituir la config por defecto (lleva `spawn-at-startup "waybar"`), revisar `xdg-desktop-portal-gtk` (*failed*),
  flags Wayland de Chrome, generar `xdg-user-dirs`.
- Fase 6/13: huella en PAM (Ayoub registra dedos con `fprintd-enroll`), greetd, Limine a 3 s y tema.
- Fase 10: umbrales 75/80 %. Fase 11: `thinkpad_acpi fan_control=1` si Oni controla el ventilador.
- Hardware: 1 solo módulo de RAM a 5600 MT/s (un canal) y 8 GB de UMA para la iGPU → medir en Oni/Snake; recomendar a
  Ayoub un segundo módulo y valorar bajar la UMA en la BIOS.

**Qué debe probar Ayoub**: cerrar sesión y volver a entrar (para que se apliquen hora y formatos es_ES; `date` debe dar
hora de Casablanca), `paru -Syu` interactivo (debe mostrar noticias y pedir revisar diffs), `google-chrome-stable` abre.


## 2026-10-14 · Fase 01 · 🟨 niri listo — falta la confirmación de Ayoub (ratón/foco y teclas físicas)
**Hecho**
- Snapshot #50. Locale: `/etc/default/locale` (resto de Calamares con `nl_NL`) igualado a `es_ES` (copia `.ocarina-bak`).
- Sesión con `niri-session` (la arrancó Ayoub): `graphical-session.target` y portales activos.
- `config/niri/` modular (11 módulos + 8 includes generados opcionales, D-021), enlazado en `~/.config/niri`
  (copia de la anterior en `~/.config/niri.ocarina-bak-2026-10-14`). `niri validate` OK; recarga en vivo comprobada.
- `~/.local/state/ocarinashell/niri/outputs.kdl` (dueño: Haichi): eDP-1 **2880×1800@120**, escala 1,75, VRR on-demand.
- Entrada ThinkPad (tap, natural, clickfinger, dwt/dwtp, TrackPoint flat + scroll con botón central, táctil → eDP-1),
  FFM sin desplazar + warp, auto back-and-forth. Botón de encendido aplazado a la fase 6 (D-022).
- Apariencia Kurenai: anillo 2 px degradado oklch `#e60033→#ff1f4f`, sin borde, sombra, radio 14 + clip, pestañas e
  insert-hint con el acento, cursor Bibata 24 (se oculta al escribir y a los 2,5 s), vista general 0,55 sobre sumi.
- Animaciones: muelles a medida + shaders **墨 florecer de tinta** (abrir) y **溶 disolución** (cerrar), sin errores de
  compilación en el journal; `config/niri/reference/shinobi.kdl` validado para la fase 10.
- Reglas: flotantes para portales/selector de archivos/pavucontrol/nm/blueman/satty, PiP abajo-derecha 480×270,
  ventanas «OcarinaShell · …», Chrome a 2/3, gestores de contraseñas ocultos en capturas. Capas `ocarina-*` con sombra.
- Binds de DMS adaptados al teclado ES (tabla en 03-ATAJOS), Alt+Tab nativo con resaltado rojo radio 16.
- `bin/ocarina` 0.1 con respaldos (wpctl, brightnessctl, playerctl, swaylock, btop, overlay de niri) y avisos de
  «llega en la fase N». Unidades `ocarina-cliphist{,-img}` activas; `ocarinashell.service` creada y desactivada.
- `environment.d/60-ocarina.conf` (Qt/Electron/cursor para systemd), carpetas XDG registradas (capturas en
  `~/Imágenes/Capturas`), `playerctl` instalado.

**Métricas** niri en reposo (espacio vacío, 10 s): **0,1 % CPU**; con la terminal de Claude animando: 2,3 % (120 Hz).
**Evidencias** `docs/evidencias/fase-01/`: `shader-abrir.jpg`, `shader-cerrar.jpg` (fotogramas de una grabación a
120 fps), `vista-general.png`.

**Falta (Ayoub)**: confirmar foco-sigue-al-ratón + salto del cursor, teclas multimedia/brillo/micro, teclas ES nuevas,
★ y fila Fn con `wev`, y si le gustan la velocidad del TrackPoint/touchpad y los shaders. Ajustar y cerrar ✅.
**Notas**: con permiso de Ayoub se borraron `~/paru-bin` (compilación vieja del AUR, 48 MB) y `~/Downloads` (vacía).
Chrome 155 ya usa Wayland por defecto.
**Cierre 2026-10-14**: Ayoub da el visto bueno («dale») sin pedir ajustes → ✅. Queda abierto: keysyms de ★ y fila Fn
con `wev` (se revisa en la fase 4 con los OSD).

## 2026-10-14 · Fase 02 · ✅ identidad: motor de temas, GTK/Qt, iconos, cursor, fondos y logo
**Hecho**
- Snapshot #53. `bin/ocarina-theme` (`apply <id> [--accent] [--dry-run]`, `from-wallpaper`, `list`, `current`) y 13
  plantillas: niri, Ghostty, Neovim, fish/fzf/eza, starship, btop, yazi, fastfetch (logo kitty + claves kanji del
  mockup), GTK3/GTK4, qt6ct (paleta + Fusion + fuentes), swaylock. bat con `--theme=ansi`. Estado en `theme.json`.
- Escritura todo-o-nada probada en un HOME aislado con una plantilla rota (nada escrito) y con un `gtk.css` previo
  (copia `.ocarina-bak`). Validadores comprobados con ficheros rotos (niri, ghostty, fish, lua).
- Ghostty provisional enlazado (`config/ghostty`, copia del anterior vacío), recarga en vivo por SIGUSR2 (mismo PID
  9448 pasó de Kurenai a Kōhaku). gsettings, carpetas rojas de Papirus, cursor Bibata por tema.
- `install.sh` ahora enlaza `share/**`, el logo en hicolor (16–1024 + SVG, icono `ocarinashell`), el logo de fastfetch y
  los 6 fondos en `~/.local/share/ocarinashell/wallpapers/`, y crea `~/Imágenes/Fondos`. `.desktop` «Ajustes de
  OcarinaShell» (llama a `ocarina settings`). `doctor` comprueba el tema con un dry-run.
**Métricas** cambio de tema completo 0,21–0,22 s (motor 0,15–0,16 s) · dry-run 0,11 s.
**Evidencias** `docs/evidencias/fase-02/`: `kurenai.png`, `kohaku.png` (Nautilus con carpetas 直 骨 曜 角, diálogo Qt,
Ghostty con fastfetch), `tiempos.txt`.
**Pendiente** prompt starship y saludo de fish (fastfetch sale dos veces si se lanza a mano) → fase 8; Neovim lee
`palette.lua` en la fase 9; el fondo se pinta en la fase 3 (Kabegami); MangoHud (11) y Limine/Plymouth (13).
**Cómo cambiar de tema hoy**: `ocarina-theme list` · `ocarina-theme apply kohaku` · `ocarina-theme apply kurenai
--accent '#00a3af'` · `ocarina-theme from-wallpaper ~/Imágenes/Fondos/x.jpg`. Las apps GTK/Qt ya abiertas toman el
cambio al reabrirse; niri y Ghostty, al instante. En la fase 7, desde Ajustes.

## 2026-10-14 · Fase 03 · 🟨 núcleo de la shell funcionando — falta que Ayoub pruebe teclas y, cuando pueda, un monitor externo
**Hecho**
- Snapshot #54. Shell QML en `shell/` enlazada como `~/.config/quickshell/ocarina`, `ocarinashell.service` activo
  (`Restart=always`, `OnFailure=ocarinashell-safe.service`, texto AA en grises). Referencia de la API de Quickshell 0.3.2
  verificada por un subagente contra los `.qmltypes` instalados.
- Singletons `Theme` (theme.json vigilado, fundido de colores), `Motion`, `Settings` (lectura propia, validación de tipos,
  migraciones, recargas tolerantes, copia `.roto-` si está corrupto: 3 casos probados), `Paths`, `Glossary`.
- Servicios por eventos: `Niri` (stream + socket de peticiones, reconexión con backoff, parser tolerante), `Time`
  (tic de minuto), `Kisetsu` (72 kō), `Audio`, `Media`, `Power`, `Brightness` (interna + DDC/CI por bus + software;
  `brightness.json`), `Weather` (solo si se muestra), `Sounds`, `Net`/`Bt` (backends aislados), `Hogo`, `Health`,
  `Osd`; stubs `Modes`/`Notifs`. IPC completo (§6) con «pendiente (fase N)»; CLI que entiende esas respuestas.
- `ModuleLoader` aísla cada módulo (D-024): probado con Shima roto → la barra siguió viva y el fallo quedó en Health.
- Obi idéntica al mockup en geometría (QA visual: ±1 px), hanko con muelle, título con símbolo monocromo, bandeja con
  menú propio (teclado, «Atrás»), clúster con anillo de batería y perfil 省均速. Shima dentro de la superficie de la barra
  (D-025): reposo con ecualizador real de PipeWire (30 Hz, solo con música), hover con 神無月 · 十四日 · 水曜日 y
  菊花開, ficha de música, OSD de volumen/brillo/micro/perfil. Kabegami con transición de tinta (shader qsb, 900 ms),
  cola de cambios, respaldo si la imagen falla; `ocarina wallpaper next`. Atenuación por software y esquinas (opcional).
- Modo seguro (`shell/safe/shell.qml`, solo tipos básicos) probado con un error de sintaxis en una rama.
- Revisiones independientes: `qml-reviewer` (30 hallazgos: altos y medios corregidos) y `visual-qa` (altos corregidos:
  kanji del hanko negro por `onAccent` → `accentInk`; franjas de color del AA subpíxel → croma 0,56 → 0,05).

**Métricas** (04-RENDIMIENTO)
| | Medido | Presupuesto |
|---|---|---|
| CPU `qs` en reposo (30 s, sin música, espacio vacío) | **0,03 %** | < 0,3 % |
| Despertares en reposo | **0,63/s** | < 2/s |
| CPU con música (ecualizador vivo) | 2,8 % (antes de limitarlo a 30 Hz) | — |
| Memoria del servicio (cgroup) | **216–229 MB** (RSS 346, ~140 compartidos) | < 220 (D-028) |
| Arranque | **143 ms** (qs) · ~200 ms unidad → barra | < 400 ms |
| Vuelta tras `systemctl kill` / SIGKILL | **1,2 s / 1,4 s** | < 2 s |
| Modo seguro con config rota | **0,2 s** | < 5 s |
| Cambio de fondo (tinta) | 900 ms, sin destello | — |
| Procesos `ddcutil` en reposo | **0** | 0 |

**Evidencias** `docs/evidencias/fase-03/`: `escritorio.jpg`, `escritorio-vacio.jpg`, `barra-isla.png`, `barra-v2.png`
(tras la QA), `isla-musica.png`, `osd-volumen.png`, `osd-brillo.png`, `hanko-muelle.png`, `hogo-4-posiciones.png`,
`fondo-tinta.jpg`, `modo-seguro.png`.

**Pendiente**
- Brillo multipantalla con un monitor externo real (no había ninguno): se cierra en la fase 4.
- Ayoub: teclas físicas de volumen/brillo/micro/multimedia con la isla, y keysyms de ★/fila Fn (`wev`).
- Morph de la isla medido solo por vídeo, no con `QSG_RENDER_TIMING` (se hará con el perf-auditor en la fase 4/17).
- Memoria: fondo a menor resolución con escalado por GPU si no se nota (D-028, fase 17).
- Hallazgos bajos del qml-reviewer no aplicados: tokens sueltos restantes (radios 6/8, tamaños 20/30), Hogo con varias
  escalas a la vez, métrica de arranque tras recarga (ya etiquetada).

**Cierre fase 3 (2026-10-14)**: Ayoub probó las teclas físicas: todo bien → ✅. No tiene monitor externo: el brillo
multipantalla queda verificado solo con la interna + pruebas de código (DDC/CI y software) hasta que conecte uno.

## 2026-10-14 · Fase 04 · 🟨 Engawa, Fumi, Koyomi, Shūchū — falta que Ayoub pruebe Wi-Fi/BT/gestos/QR con sus manos
**Hecho**
- Snapshot #55. Servicios nuevos: `Panels`, `Notifs` (servidor real), `Idle` (醒 Despierto, aislado en `IdleGuard`),
  `Recorder` (unidad `ocarina-rec`), `Focus` (persistente), `NightLight` (+ `ocarina-nightlight.service`), `Vpn`;
  `Kisetsu` con sol/luna, `Weather` con previsión de 3 días.
- **Engawa** (mockup 02): cabecera, 6 mosaicos (+ VPN si existe), tarjetas 忍/鬼, volumen, brillo por pantalla (en
  caliente, Mayús = todas, sin recrear al arrastrar), segmentado 省均速, multimedia teñida por la portada, pie de batería
  con vatios de UPower. Páginas: Wi-Fi (escaneo solo abierta, contraseña, olvidar, red oculta, QR), Bluetooth
  (descubrir solo abierta, emparejar, conectar, batería, olvidar con confirmación), Sonido (salida/entrada, volumen por
  app), Luz nocturna, Grabar, VPN.
- **Fumi**: toasts del mockup 01 (pila 3 + «+N», arrastrar para descartar, pausa con el ratón, críticas sin caducidad
  y con sonido, progreso `-h int:value`, reemplazo por id, acciones, inline reply con teclado), centro de notificaciones
  (Mod+Shift+N), No molestar manual y con horario (anulable dentro de la franja), peek en la isla.
- **Koyomi**: 神無月 Kannazuki, semana en kanji, hoy como hanko, 七十二候 con días restantes y 節気, sol y luna,
  tiempo con kanji y 3 días, relojes del mundo (東京), sellos de 集中.
- **Shūchū**: `ocarina focus [min|stop|status]`, anillo + minutos en la isla, No molestar durante el bloque (restaurado),
  aviso «休憩 · descanso»; sobrevive a recargas.
- Isla: estados de grabación (録 + tiempo), foco y peek; OSD de teclado y de Wi-Fi/avión.
- Gestos táctiles (solo dedo): arrastre desde el clúster (Engawa) y la isla (Koyomi), deslizar la isla con música.
- Revisiones: `visual-qa` (20 puntos, altos corregidos) y `qml-reviewer` (30 puntos: altos y medios corregidos).

**Pruebas hechas** notify-send con acciones, imagen, markup, crítica, progreso 60 %, reemplazo por id, 20 seguidas en
0,2 s sin errores, DND → peek; HTML con `<img>` remoto y `file://` saneado; Shūchū de 1 min (anillo, DND activo y
restaurado, aviso, ● en Koyomi, sobrevive a recarga); luz nocturna en manual/auto/off; grabación de 3 s con recarga en
medio (mp4 válido); sliders = `wpctl`/`brightnessctl`.
**Métricas** CPU `qs` en reposo 0,05 % (paneles cerrados) · 0,00 % con Engawa abierto (sin sondeos) · memoria del
servicio 189 MB al arrancar, 221–225 MB tras abrir los paneles (sin fuga apreciable).
**Evidencias** `docs/evidencias/fase-04/`: `engawa.png`, `engawa-completo.png`, `engawa-{wifi,bluetooth,audio,night}.png`,
`toasts.png`, `toasts-pila.png`, `koyomi.png`, `isla-peek.png`, `isla-foco.png`.

**Pendiente**
- Ayoub: conectar/olvidar una red con contraseña, emparejar sus cascos, gestos con el dedo, QR del Wi-Fi con el móvil
  (si NM pide autorización, funcionará tras el agente polkit de la fase 6), notificaciones de sus apps reales
  (Telegram, Chrome, Teams) e inline reply si alguna lo usa.
- Monitor externo: Ayoub no tiene; el brillo multipantalla queda probado por código y con la interna.
- Peek por pantalla completa: niri 26.04 no lo expone por IPC (D-030).
- Integración de avisos de Ghostty (`notify-on-command-finish`) → fase 8; tarjeta agrupada de Mamori → fase 16.
- Bajos no aplicados: radios aún literales en algunos componentes, degradado diagonal de mosaicos.

**Cierre fase 4 (2026-10-14)**: Ayoub probó Wi-Fi/BT/gestos/notificaciones: todo bien → ✅.

## 2026-10-14 · Fase 05 · 🟨 EN CURSO — punto exacto para retomar
Snapshot #56. `wtype` instalado. Hecho y en commit:
- `shell/modules/torii/fuzzy.js` (puntuación tipo fzf, tildes/mayúsculas, highlight), `bin/ocarina-ssh-hosts`
  (probado con `tests/ssh_config`: web-dev, db-prod (prod), nas, router; sin comodín), `services/Launcher.qml`
  (proveedores `= > ? / @ : ! ~`, acciones del sistema, frecencia en state/frecency.json, emoji-test.txt en caché,
  kaomoji/kanji), `modules/torii/{Torii,ToriiWindow,ToriiGate,ResultRow}.qml`, `components/Kbd.qml`, IPC `launcher`
  (toggle/open/stats), CLI `ocarina launcher [modo] [texto]`, `ocarina ssh <host>` provisional, ajustes `ssh.*`.
- Torii abre y busca (captura `docs/evidencias/fase-05/torii.png`), filtro ~4 ms con 30 apps.
**Avance (sesión 2)**: Torii ajustado y medido (filtro 0,3–2 ms; `:a` con 2.500 símbolos 4 ms; apertura 1 ms propio +
~24 ms de mapeo de niri → D-033), emoji en español (CLDR), desenfoque real. Kura ✅ (commit 802f829). Techō ✅ (sobrevive a
`kill -9`). **Artefactos de prueba que hay que limpiar al cerrar**: `settings.json` → `clipboard.dbPath` (BD falsa en el
scratchpad), `~/.local/share/ocarinashell/kura/` (2 fijados de prueba), `~/.local/share/ocarinashell/notas/nota-20261014-194708.md`.
Pendiente: Mihari, Mado, renombrar espacio, chuleta, Iro; QA y cierre.
**Siguiente paso exacto (sesión 1, ya hecho)**: (1) ranking: acciones de escritorio por debajo de las apps, umbral contra coincidencias
dispersas (descartar si huecos > 2·len+3 o score < 20·len); (2) el telón 42 % no se aprecia: revisar `color` del
ToriiWindow (scrim); (3) medir apertura (<1 frame) y filtro con 100 repeticiones; (4) probar prefijos (=, /, :mesa
kaomoji, ~ con `ssh.configPath`=tests/ssh_config, @, !, >, ?); luego Kura, Techō, Mihari, Mado, renombrar espacio,
chuleta, Iro; QA visual vs mockup 04, qml-reviewer, PROGRESS y commit final.

## 2026-10-14 · Fase 05 · ✅ CERRADA (a falta de la prueba de Ayoub)
**Hecho** (commits 84d5cfe…d7fec64):
- **Torii**: difuso propio, prefijos `= / : ! > @ ~ ?`, emoji en español (CLDR), desenfoque real, chips.
- **Kura**: cliphist con miniaturas, fijados, secretos enmascarados, pegar con wtype.
- **Techō**: notas `.md`, autoguardado atómico, búsqueda con rg, letra mincho, `ocarina notes "texto"`.
- **Mihari**: muestreador que vive con la ventana; matar verificado; sesión protegida.
- **Mado**: reglas validadas con niri y saneadas.
- **Renombrar espacio** en la isla.
- **Chuleta** desde `binds.kdl`.
- **Iro**: cuentagotas con 伝統色 por OKLab.
- **Servicio `Tools`**: detecta qué herramientas externas hay.
- Decisiones D-033–D-039.

**Criterios con evidencia** (`docs/evidencias/fase-05/`):
- **Torii**: abrir = 1 ms propio + ~24 ms de mapeo de niri (D-033; no llega a 1 fotograma, justificado). Filtrar: 0,3–2 ms con 30 apps; `:a` sobre ~2.500 símbolos, 4 ms. Capturas `torii*.png` comparadas con el mockup 04 por el agente visual-qa.
- **Prefijos**:
  - `=2+2*3` → 8; `=10 km to mi` y `=100 EUR to MAD` resueltos por qalc.
  - `/` usa fd; `:mesa` → (╯°□°)╯︵ ┻━┻; `:sakura` → 🌸.
  - `~` con `tests/ssh_config` → web-dev, db-prod (本番), nas, router (sin comodín); `ocarina ssh router` abre Ghostty «ssh · router».
  - `@` ventanas, `!wifi` → Red, `>` comando, `?` web.
- **Kura**: imágenes con miniatura (`kura.png`); copia texto e imagen (`wl-paste` lo confirma); fijar persiste.
- **Techō**: `kill -9` de la shell 0,5 s después de escribir → el texto está en el fichero. Reabrir, Ctrl+T, `ocarina note` con Techō abierto y la papelera, probados sin pérdidas.
- **Mihari**: mismas fórmulas que btop. Muestreador ≈1 % de un núcleo y solo con la ventana abierta. qs con Mihari abierto: 1,5 %.
- **Mado**: regla de prueba aceptada por `niri validate`; un título malicioso con salto de línea queda dentro de la cadena.
- **Iro**: el rojo del logo #ea1f35 → 赤 aka, ΔE 0,018 (#d7172f → 紅 kurenai).
- **Rendimiento en reposo**: CPU 0,05 %. Memoria del cgroup: 203 MB al arrancar y 249 MB tras abrir todos los paneles.

**Revisiones**: qml-reviewer (6 altos: todos corregidos) y visual-qa (20 puntos: corregidos los altos y medios; quedan los bajos de abajo).

**Pendiente / bajo**:
- El pegado de Kura en apps reales lo prueba Ayoub.
- El cuentagotas real (clic en pantalla) lo prueba Ayoub.
- Peso 500 de Geist en chips, radios aún literales y foco por teclado en chips/pestañas → revisar en la fase 7 (Settei) con el sistema de componentes.
- Incidente de pruebas: un `wtype` de prueba acabó en la terminal (el mensaje «dev»). Ahora las pruebas comprueban el foco por IPC (`workspace editing`) antes de teclear.

## 2026-10-14 · Fase 06 · ✅ CERRADA (a falta de 2 pruebas de Ayoub)
Snapshot **#61**. Commits 12adc5d…(cierre).
**Hecho**
- **PAM aislado** (`shell/pam/`, D-040): solo `pam_unix`, sin faillock (las erratas del bloqueo nunca bloquean la cuenta ni
  la TTY); espera creciente 5/15/30/60 s; huella en paralelo cuando haya dedos (hoy no hay: se activa sola). Probado con la
  contraseña real en `tests/pam/PamTest.qml`.
- **鍵 Kagi**: composición del mockup 03 (pétalos, ocarina que suena, 縦書き, reproductor, Wi-Fi/batería, deriva Hogo),
  campo en todas las pantallas, modo prueba (`ocarina lock test`), disolución con «fantasma» (D-042), épocas y estado
  privado, PAM en backend aislado, swaylock con `--ready-fd` y código de salida, marca de recuperación con contador
  anti-bucle, modo seguro con swaylock, sin recargas en caliente bajo bloqueo (D-045). Monitores apagados a los 30 s.
- **電源 Dengen** (mockup 05): 5 tarjetas de pincel, L S E R P, mantener 1,2 s con tinta, saludo por hora, hueco de
  «Actualizar y reiniciar» (marca de Mamori), despedida que espera al guardado de la sesión. Botón de encendido → Dengen
  (`ocarina-powerkey.service`, D-041); bloqueado, suspende.
- **認 Polkit**: agente propio (no había otro), diálogo con pétalos, acciones conocidas en español, pantalla fija.
- **Inactividad** (`Idle`): perfiles CA 4/5/6/nunca y batería 2/3/4/15, atenuar todas las pantallas al 30 % y restaurar,
  `longIdle` ≥ 15 min para Mamori. `ocarina-sleep.service` (swayidle `before-sleep` → `ocarina lock --wait`) activo.
- **復元 Fukugen** (`Session`): guardado por eventos (≤ 30 s) y en la despedida; restauración por oleadas de espacio,
  sin cruzar ventanas de la misma app; terminales en su carpeta; `ocarina session save|restore|status`.
- Greeter → fase 13 (D-044). Decisiones D-040–D-045.

**Criterios con evidencia** (`docs/evidencias/fase-06/`)
- Capturas ≈ mockups: `kagi-v2.png`, `kagi-petalos*.png`, `kagi-error.png` (03) y `dengen.png` (05), revisadas por
  visual-qa (21 puntos: altos y medios corregidos y recapturados); `polkit.png`.
- Bloqueo real: **13 bloqueos/desbloqueos sin fallo** (1 suelto + 12 ciclos, `kagi-ciclos.txt`), confirmados en 138–241 ms;
  contraseñas erróneas y espera tras 3 fallos bien gestionadas (Ayoub: «todo bien»). Ayoub paró los ciclos en el 12.
- Botón de encendido y `pkexec true` real: hechos por Ayoub (faillock limpio tras el acierto).
- Inactividad: atenuar verificado con valor corto (60 → 30 %) y restaurado; ajustes devueltos a los valores por defecto.
- Fukugen: `tests/fukugen_test.py` → 6/6 en su espacio y ancho tras reiniciar la shell (`fukugen.txt`).
- Rendimiento (`rendimiento.txt`): CPU 0,27 % con Claude activo (< 0,3 %; los módulos nuevos no cuestan en reposo), RSS
  estable tras 14 ciclos.
- Revisión qml-reviewer: 7 altos (seguridad del bloqueo) corregidos (D-045); medios corregidos; bajos de estilo pendientes.

**Pendiente**
- Ayoub: **matar la shell con la pantalla bloqueada** (debe volver a bloquearse sola) y **suspender/reanudar ×3** (tapa y
  Dengen) sin ver el escritorio. Los 7 bloqueos que faltan para 20 cuando quiera, uno a uno.
- Huella: cuando registre dedos (`fprintd-enroll`), Kagi la usa sola; sudo/polkit con huella → script root en la fase 13.
- Medida de CPU limpia (sin Claude Code activo) y valores sueltos → tokens (radios, scrims) → fase 7/17.
- niri conserva su inhibidor del botón hasta el próximo inicio de sesión (inocuo).
- Ventana «ssh · router» de las pruebas de la fase 5 sigue abierta (de Ayoub cerrarla).

## 2026-10-15 · Fase 07 · ✅ CERRADA (a falta del monitor externo y del recorrido de Ayoub)
Snapshot **#62**. Commits 7f74b81…(cierre).
**Hecho**
- **設定 Settei**: ventana propia (FloatingWindow «Ajustes de OcarinaShell», regla de niri 1240×924 radio 18, solo existe
  abierta), lateral con wordmark, búsqueda (`/`, Ctrl+F; índice generado de 129 filas con `tools/settei_index.py --check`),
  enlaces profundos (`ocarina settings energia|pantalla|fondos…`, alias), «Restablecer sección» con confirmación, importar
  y exportar `settings.json` (copia del actual antes de importar), teclado completo (Ctrl+Tab/PgDn, Esc, Ctrl+W).
  Torii encuentra también cada ajuste concreto y abre la página resaltando la fila.
- **Páginas**: 彩 Apariencia (temas con miniatura real, 8 acentos tradicionales + «Desde el fondo» que sigue al fondo,
  transparencia, desenfoque, velocidad de animaciones 0–2×, kanji, tres tipografías, tamaño, redondez, esquinas,
  movimiento reducido, 昼夜 tema según la hora) · 帯 Barra e isla (estilos flotante/pegada/mínima con autoocultado y toque
  en el borde, módulos y orden arrastrando, reloj, comportamiento de la isla) · 画 Pantalla (Haichi, abajo) · 音 Sonido
  (página de Engawa + sonidos de interfaz) · 網 Red y Bluetooth (páginas de Engawa lado a lado) · 電 Energía (perfil,
  batería y gráfica de 4 h de UPower por D-Bus, límite de carga, avisos) · 忍 Shinobi y 鬼 Oni (opciones guardadas para
  las fases 10/11) · 鍵 Bloqueo (inactividad CA/batería, huella, reproductor, fondo, deriva, «Probar») · 入 Teclado y
  ratón (distribuciones y tecla de cambio, repetición con campo de prueba, touchpad, TrackPoint, ratón, foco, gestos) ·
  文 Notificaciones (No molestar con horario, tiempo, por app: normal/sin sonido/silenciada) · 窓 Ventanas (huecos,
  ancho, anillo, animaciones de niri, Mado) · 技 Atajos (de binds.kdl, filtro, abrir en Neovim, Iro/kaomoji) · 情 Acerca
  de (logo animado, versiones, equipo, diagnóstico de Health, créditos) · huecos de 滑 船 蛇 守 con su fase.
- **niri desde Ajustes**: `services/NiriConf.qml` → `overrides.kdl` validado (D-046); FFM y salto del cursor pasan a vivir
  ahí; `ThemeCtl` orquesta tema/acento/tema por horas.
- **配置 Haichi** (`services/Displays.qml`): lienzo a escala con imán y 壱弐参, resolución/frecuencia/escala recomendada/
  rotación/VRR/activa/principal (la principal manda barra, isla y avisos), Extender · Duplicar · Solo monitor · Solo
  portátil, perfiles por huella que se aplican solos, aviso al conectar con acciones, Identificar, «revertir en 15 s»
  que sobrevive a la shell (D-049), 発表 Happyō con wl-mirror + No molestar + Despierto + avisos sin contenido + Esc en la
  copia, tapa cerrada (nativa de niri; opción para mantener el panel), brillo por pantalla con nombre y mínimo, teclas de
  brillo, DDC/CI y software, brillo según la hora, Hogo, luz nocturna y táctil.
- **壁紙 Kabegami** (página Fondos; Mod+Shift+W): `bin/ocarina-thumbs` (vips en paralelo, caché por ruta+mtime, nice),
  rejilla con teclado, vista previa con ← →, favoritos, «Tema desde este fondo», rotación (solo con CA), volver al del
  tema, pestaña Explorar con **Wallhaven solo SFW** (decisión de Ayoub) y descarga a `~/Imágenes/Fondos/wallhaven/`.
- Decisiones D-046–D-049. Barra **solo arriba** (Ayoub).

**Criterios con evidencia** (`docs/evidencias/fase-07/`)
- Kōhaku ≈ mockup 07: `settei-kohaku.png` (cabecera, subtítulo, «TEMA» y tarjetas medidos al píxel contra el mockup tras
  la QA); Kurenai correcto: `settei-kurenai.png`. Pantalla ≈ mockup 12 con un monitor simulado: `settei-pantalla.png`
  (+ `-kohaku`). Otras: `settei-{energia,acerca,red,barra}.png`, `kabegami.png`.
- Persistencia y aplicación en vivo: `persistencia.txt` → **15/15** ajustes en vivo y tras reiniciar la shell, originales
  restaurados, niri sin errores (`tests/settei_check.py`).
- Enlaces profundos y búsqueda: `ocarina settings energia` → energia; `wifi` → red; búsqueda «foco» → 3 filas en 2
  páginas; revelar «Grosor del anillo» abre Ventanas y la resalta. Kabegami: **200 imágenes 2880×1800 en 1,45 s** la
  primera vez y **0,05 s** después (`kabegami-indice.txt`).
- Prueba de 15 s (`haichi-prueba-15s.txt`): Mantener, reversión automática y reversión con la shell matada (SIGKILL) a
  mitad; guardas anti-inyección.
- Revisiones: qml-reviewer (7 altos, 12 medios: corregidos; bajos de tokens/foco parcialmente), visual-qa (3 altos y la
  mayoría de medios corregidos y re-medidos), perf-auditor (`rendimiento.txt`): Ajustes abierto 0,00–0,07 % CPU, cerrado
  sin procesos ni temporizadores; título giratorio de Claude Code ya no redibuja la barra.

**Pendiente**
- Con un **monitor externo** (Ayoub no tiene ahora): guardar perfil → desconectar/reconectar → se aplica solo; cambio de
  escala real revertido a los 15 s; Duplicar y salir sin dejar `wl-mirror`; tapa cerrada. El código está probado sin
  monitor (simulado + prueba invisible de 15 s).
- Fase 17: tamaños de letra fraccionarios redondeados en toda la shell; presupuesto de memoria (meseta de ~60 MB tras
  abrir Ajustes, sin fuga); tokens restantes (radios sueltos, ScreenTag), foco por teclado en chips de perfil y lienzo.
- Límite de carga: la UI guarda 75/80 %; lo escribe en el sistema el ayudante de la fase 10.
- Shinobi/Oni: sus páginas guardan opciones; los modos llegan en las fases 10/11.

**Qué debe probar Ayoub** (5 min recorriendo Ajustes y decir qué echa en falta):
1. `Super+,` abre Ajustes; `/` y escribe «foco», Intro. Esc cierra.
2. Apariencia: cambia a Kōhaku y vuelve; prueba un acento y «Fondo».
3. Barra e isla: estilo «Mínima» (acerca el ratón arriba o toca el borde) y vuelve a «Flotante».
4. Pantalla: Escala 1,5 → espera 15 s sin tocar (vuelve sola); repite y pulsa «Mantener» si te gusta (o vuelve a 1,75).
5. Teclado y ratón: añade «us», cambia con Alt+Mayús, quítala.
6. `Super+Shift+W`: vista previa con ← →, aplica uno, «Tema desde este fondo», y prueba Explorar.

## 2026-10-16 · Tras la fase 07 · 広場 Hiroba, isla v2, barra en islas (peticiones de Ayoub)
- **広場 Hiroba** (pulsar la isla; sustituye a Koyomi): perfil con bocadillo, reloj en viñeta de cielo según la hora, sol y
  luna, mes, 七十二候 con tiempo por horas y 3 días, música (NOW PLAYING, vinilo), equipo en anillos HUD. Morph exacto desde
  la isla y cierre en tres tiempos sin parpadeos (687 ms hasta desaparecer). 0,50 % CPU abierto · 0,00 % cerrado (D-050).
- **Isla v2**: aura 紅→金, día como sello, kamon de la estación; al pasar el ratón, billete con destello y pétalos (un disparo).
- **Barra en islas** (por defecto): dos cápsulas de vidrio; iconos de estado coherentes (18 px rellenos, apagado atenuado),
  hover en píldora concéntrica, centrado exacto también con Hogo.
- **Interruptor** rediseñado (ajustado a píxeles físicos). **fastfetch**: logo con su proporción y etiquetas doradas.
- Mockups 14–17 (`tools/mockups_chrome.py` los renderiza con Chrome sin Playwright).
- Revisiones: qml-reviewer ×2 (altos y medios corregidos). Pendiente: foco por teclado dentro de Hiroba (bajo).

## 2026-10-16 · Fase 08 · ✅ Ghostty, fish, starship y herramientas CLI
**Hecho**
- **Ghostty 1.3.1** (`config/ghostty/config.ghostty`): JetBrains Mono + Noto Sans Mono CJK JP + emoji, **10 pt con
  interlineado 1,5** (13px/1.5 del mockup, elegido por Ayoub), ligaduras, sin cabecera GTK (niri dibuja el anillo), cursor
  barra fija, selección → primaria (Ayoub), integración de fish (cursor, sudo, título, ssh-env), avisos de fin de comando
  ≥ 10 s sin foco → Fumi, atajos Ctrl+Mayús coherentes con niri (D-051), instancia única (ventana nueva 67 ms).
- **墨 Estela de tinta** (`shaders/ink-cursor.glsl`): trazo de pincel de 120 ms al saltar el cursor; solo enchufado, fuera de
  Shinobi y con movimiento (servicio `TermFx` → `ocarina-theme effects on|off`, único dueño del include). CPU no medible.
- **端 Terminal desplegable** (Mod+º, `ocarina-quickterm`): Ghostty flotante arriba que se esconde en el espacio vacío del
  final y vuelve con el foco; Obi no muestra ese espacio (emulado: Ghostty no expone su quick terminal sin portal, D-051).
- **fish** (`conf.d/ocarina.fish`): abreviaturas (yay→paru, git, niri, ocarina…), zoxide y starship desde caché, fzf con
  vistas previas (bat/eza/fd), título «orden · carpeta», `y` (yazi), `snake`, `ossh`, colores de less; saludo diario
  < 5 ms (こんばんは, 節気 · 候, 諺) y fastfetch solo la primera terminal del día o con `ff`; pure sombreado (−6 ms).
- **starship**: dos líneas como el mockup (`╭─ 寒露 ~/ruta on 枝 main 変2 新1 · 0.4s … 21:38` / `╰─❯`), 誤 con el código
  si falla, prompt transitorio. **fastfetch**: logo 24×6 por kitty, claves en kanji, 季 Kō, batería en español.
- **Herramientas**: btop (tema, 2 s, vim), yazi (vista previa nítida, saltos `g o/i/D/s`), lazygit (extra, plantilla de
  tema, sin fetch en segundo plano), bat, less. `ocarina-daily` (caché diaria). `alacritty` desinstalado (Ayoub).
- **本番 Honban**: `ocarina ssh <host>`; producción (`# ocarina: prod` o Ajustes → Red → hosts) → `honban-rules.kdl` validado
  (anillo rojo sólido + borde sólido de 3 px también sin foco), sello 本番 en Obi, aviso de la primera conexión del día (D-052).
- **Ajustes**: Apariencia → 端 Terminal (estela, saludo, fastfetch diario); Red → 本番 SSH de producción.
- **Peticiones de Ayoub durante la fase** (D-053): luz del teclado en Engawa (bajo el brillo); 広場 sin velo oscuro, un
  poco más pequeño, apertura/cierre rápidos (240/≈250 ms), bajo la barra y con **barra e isla visibles**.
- `ocarina doctor`: sección Terminal (config de Ghostty, efectos, arranque de fish, saludo, starship, Honban).
- **Revisiones**: qml-reviewer (2 altos y 6 medios corregidos: eco de UPower en la luz del teclado, espacio del desplegable,
  recuentos de ventanas sin recalcular por título, campo de hosts, color de Honban con el tema, `~`, paneles por pantalla,
  tokens Motion.hiroba) y visual-qa (estela en 紅 real por gamma, fastfetch casi al píxel del mockup, grises c8 del prompt,
  kanji en Zen Kaku Gothic New, cursor de 2 px, luna creciente y reloj de 広場).

**Métricas** (evidencias en `docs/evidencias/fase-08/`)
| Medida | Resultado | Presupuesto |
|---|---|---|
| Ventana nueva de Ghostty (`+new-window` → mapeada, 4 muestras) | **67,5 ms** | < 80 ms |
| `fish -i -c exit` (hyperfine, 30) | **31,7 ms** (40,7 antes de sombrear pure) | < 40 ms |
| Prompt de starship en el repo (git) | **7,6 ms** (git_status 5 ms) · fuera de git 3,1 ms | < 15 ms |
| Estela de tinta (CPU de Ghostty con/sin) | 10,7 % / 10,6 % (ruido de Claude Code) | — |
| 広場 apertura / cierre | 240 ms / ≈250 ms | — |

**Criterios de aceptación**
- [x] Ghostty ≈ mitad izquierda del mockup 01 (`ghostty-vs-mockup01.png`).
- [x] Ventana < 80 ms · fish < 40 ms · prompt < 15 ms (arriba).
- [x] Desplegable (abrir/esconder/mostrar probado por IPC de niri) · aviso de fin de comando en Fumi
  (`aviso-fin-comando.txt`) · la estela se apaga sin movimiento (`estela-apagado.txt`; Shinobi usa la misma condición
  `Modes.shinobi`, que activará la fase 10).
- [x] Honban con `tests/ssh_config`: db-prod con anillo rojo sólido y 本番; web-dev con el anillo de siempre.

**Pendiente / notas**
- Memoria del servicio: 207 MB al arrancar, ~250 MB tras abrir paneles (igual que en la fase 07) → fase 17.
- `done.fish` de CachyOS cuesta ≈5 ms por shell (llama a xprop); no se puede sombrear (lo carga cachyos-config por ruta).

**Qué debe probar Ayoub** (5 min)
1. Mod+º: aparece el desplegable arriba; Mod+º otra vez lo esconde; vuelve con lo que tenías.
2. Abre una terminal nueva (Mod+T): saludo; `sleep 12`, cambia de ventana y espera el aviso.
3. Mueve el cursor a saltos (Intro, flechas en nvim…) enchufado: estela roja muy corta.
4. Ajustes → Red → «Hosts de producción»: pon un host tuyo de producción y `ocarina ssh <host>` (o `ossh`).
5. Engawa: luz del teclado (Apagada/Baja/Alta) y Fn+Espacio con Engawa abierto. 広場: barra e isla se quedan.

## 2026-10-16 · Fase 09 · ✅ Neovim
**Hecho**
- Snapshot **#68** «antes de fase 09». `scripts/root/fase-09.sh` (lo ejecutó Ayoub): `pacman -Syu` + LSP, formateadores,
  tree-sitter-cli y chafa de los repos oficiales (D-054). No había `~/.config/nvim` previo; ahora enlaza a `config/nvim`.
- `config/nvim/`: `init.lua`, `lua/ocarina/{options,keymaps,autocmds,lazy,statusline,winbar,tabline,ui,colors,palette,fx,
  dashboard,health,ts,logo}.lua`, `lua/plugins/{snacks,lsp,treesitter,coding,editor}.lua`, `colors/ocarina.lua`,
  `lazy-lock.json` y `stylua.toml`. 20 plugins con lazy.nvim, todo diferido salvo snacks y treesitter.
- Colorscheme `ocarina` (478 grupos) desde `theme/palette.lua`, recarga en caliente vigilando `theme/` (D-055); sintaxis
  como el mockup 01 (palabra clave t5, tipo t3, propiedad/función t4, módulo/id t6, cadena t2, comentario t8 en cursiva).
- Statusline propia con modos en kanji, 枝/新/変/消, 誤/警/報/示, LSP, codificación y posición; tabline con pestañas, migas
  LSP y kanji del tema (D-056). Dashboard con la ocarina PNG por protocolo kitty (braille de respaldo), proverbio y 候.
- Efectos: `ocarina-theme effects --motion` escribe `theme/effects.json` desde `TermFx` → Shinobi/batería/movimiento
  reducido apagan en caliente el scroll suave y las animaciones de snacks; smear-cursor solo fuera de Ghostty (D-055).
- `bin/ocarina-nvim-health` (salud + `update [--apply]` en sandbox para Mamori, D-057) y sección Neovim en `ocarina doctor`.
- `ocarina-daily` escribe también `daily.json`; `tools/nvim_logo.py` genera el braille.

**Métricas**
| Medida | Valor | Presupuesto |
|---|---|---|
| `nvim --startuptime +q` con UI real en Ghostty (dashboard, mediana de 7) | **11,5 ms** | < 30 ms |
| ídem headless (`ocarina-nvim-health`, mediana de 7) | 9–13 ms | < 30 ms |
| Abrir el primer `.qml` de la sesión | 80 ms (137 antes de la query de injections propia) | — |
| `:checkhealth` | 0 errores propios; 3 ajenos ignorados (LaTeX, Mermaid, sin gráficos en headless) | 0 |

**Criterios de aceptación**
- [x] Captura ≈ mitad derecha del mockup 01 (`nvim-vs-mockup01.png`, `nvim-sumi.png`, `dashboard.png`). La spec decía
  `Obi.qml`, que no existe: se editó `shell/modules/obi/Workspaces.qml`, el fichero del mockup.
- [x] Arranque < 30 ms; `:checkhealth` sin errores (salvo los 3 ajenos documentados); LSP de QML (qmlls6), Lua (lua_ls) y
  Python (pyright) conectados (también bashls y taplo).
- [x] Cambio de tema en caliente (Sumi → Kurenai → Sumi con Neovim abierto) y Shinobi en caliente (`effects off --motion
  off` → `snacks_animate=false`, scroll apagado; y vuelta), comprobado por el socket de Neovim.

**Pendiente / notas**
- visual-qa: 19 hallazgos (2 altos) aplicados (D-058) y comprobados por el socket de Neovim. Las capturas de
  `docs/evidencias/fase-09/` son de antes de esos retoques; faltan las finales en Sumi, Kurenai, Kōhaku y Shinobi, que se
  hacen cuando Ayoub deje la pantalla libre 20 s (estaba usándola y no se le roba el foco).
- Opcional, a decidir con Ayoub: kanji de interfaz (常, 紅) en la fuente mincho del mockup con `font-codepoint-map` de
  Ghostty (afectaría a toda la terminal).
- qmlls da ~20 avisos `missing-property` en el QML de la shell porque `Theme.colors` es `Item {…}` y `font`/`radius` son
  `QtObject {…}`: qmllint no ve sus propiedades. Deuda de tipado de la shell → fase 17 (componentes con tipo propio).
- Snake en Neovim (endpoint OpenAI-compatible local) queda para la fase 15, desactivado por defecto.

**Qué debe probar Ayoub** (5 min)
1. `nvim` en una terminal: dashboard con la ocarina; `f` busca archivo, `r` recientes.
2. `nvim ~/ocarinashell/shell/modules/obi/Workspaces.qml`: colores, `gd` sobre un tipo, `K`, `␣ c a`; pulsa `␣` y espera:
   which-key con los grupos en kanji.
3. Ajustes → Apariencia → otro tema con Neovim abierto: cambia solo. Movimiento reducido: el scroll deja de animarse.
4. `␣ g g` (lazygit) y `-` (oil) en el repo.
5. `ocarina doctor`: sección Neovim en verde.

**Chuleta: 10 atajos con `<leader>` (Espacio)**
`␣␣` buscar archivo · `␣/` buscar texto · `␣,` buffers · `␣e` explorador · `␣gg` lazygit · `␣ca` acción de código ·
`␣cr` renombrar · `␣cf` formatear · `␣xx` diagnósticos · `␣qs` restaurar sesión (`␣?` y `␣` solo enseñan el resto).

## 2026-10-16 · Fase 10 · ✅ 忍 Shinobi y energía (a falta de la suspensión de 1 h y del reinicio)
Snapshot snapper 74 «antes de fase 10».

**Hecho**
- **`ocarina-powerctl`** (`system/usr/local/libexec/`, bash estricto, lista blanca) + polkit `org.ocarinashell.powerctl`
  (`allow_active`, sin contraseña, también desde el servicio de usuario) + `ocarina-charge.service` (habilitada).
  `install-system.sh` recarga systemd y habilita unidades. Límite de carga **75–80 %** aplicado y guardado.
- **`Modes`**: máquina `off → entering → on → leaving`, snapshot de lo que Shinobi cambia, vuelta exacta, cola de
  peticiones y vigilancia de 15 s, reanudación tras recarga o reinicio (reaplica turbo/GPU/Wi-Fi/teclado), salida al
  enchufar si entró desenchufado, umbral de batería que pregunta (`power.autoShinobiAsk`). `PowerCtl` (cola de pkexec,
  límite de carga sincronizado con Ajustes).
- Shell en Shinobi: `Motion.held`, `Theme.lean` (sin desenfoque, superficies opacas), tema `shinobi` retenido
  (`ThemeCtl.hold/release`), fundido a negro del fondo, isla mínima con sello 忍 estampado, logo mono, toast del
  mockup 06 con sello (`x-ocarina-kanji`), sonidos y segundos fuera. niri `shinobi.kdl` (sin animaciones ni sombras,
  anillo #5C0010). 60 Hz y topes de brillo a través de Displays/Brightness. PPD «ahorro» (quita el turbo), GPU al
  mínimo, Wi-Fi en ahorro por interfaz, Bluetooth apagado salvo audio, unidades en pausa configurables.
- Ajustes: página Shinobi con estado y botón; Energía con «Preguntar antes». Ghostty sin aviso de recarga.
- Herramientas: `scripts/power-state.sh`, `bench-energia.sh` (A–H), `bench-suspend.sh`; `bench-power.sh` inserta en la
  primera tabla. Docs: `ENERGIA.md`, D-059, rescate de Shinobi, COMPAT.

**Criterios de aceptación**
- [x] On/off < 1 s: entrar 297–616 ms, salir 144–247 ms (hasta que acaba el último paso). `diff` de
  `scripts/power-state.sh` (brillo, Hz, perfil, turbo, EPP, GPU, carga, Wi-Fi, BT, teclado, tema, niri, efectos)
  **idéntico** en 6 ciclos, también con re-entrada inmediata y con VRR (`docs/evidencias/fase-10/estado-*.txt`).
- [x] Captura ≈ mockup 06 (`shinobi.png`, `shinobi-barra.png`, `shinobi-toast.png`). Nada roto: bloqueo en modo prueba
  (`shinobi-bloqueo.png`), aviso crítico (`shinobi-critico.png`), OSD de volumen (`shinobi-osd.png`), brillo pedido 80 →
  35 %, la shell reiniciada sigue en Shinobi.
- [x] `docs/ENERGIA.md`: 9 escenarios. Shinobi −30 % en la misma tanda (6,4 → 9,3 h con brillo al 50 %), **3,9 W ≈
  12,7 h** con el tope; GPU al mínimo −0,2 W (se queda); VRR en Shinobi y Ethernet PM sin ganancia (fuera).
- [x] El ayudante rechaza 13 argumentos fuera de lista (`helper-malicioso.txt`) + interfaz Wi-Fi inventada.

**Revisiones**: qml-reviewer (15 puntos: carreras, brillo atenuado, perfiles a 60 Hz, reanudación tras reinicio, cola…)
y visual-qa (12 puntos) aplicados; de visual-qa quedan para la fase 17 los que no son de Shinobi: márgenes de la barra en
islas (derecha 15 px más adentro), peso 600 del reloj de la isla, forma del chip 省, campana de contorno, ancho de la
tarjeta de música del bloqueo; el anillo de foco de 1 px no se puede desde `shinobi.kdl` porque `overrides.kdl` (último)
fija el ancho.

**Métricas**: CPU de `qs` en reposo 0,10–0,15 % (Ayoub usando el equipo); memoria del cgroup 235 MB recién arrancada
(anon 224; fase 09: 207 al arrancar) → presupuesto de memoria ya anotado para la fase 17.

**Pendiente**
- Ayoub: `scripts/bench-suspend.sh` desenchufado ≥ 1 h (consumo en s2idle y residencia s0ix → ENERGIA.md).
- Ayoub: tras el próximo reinicio, `cat /sys/class/power_supply/BAT0/charge_control_{start,end}_threshold` → 75 / 80.
- A decidir por Ayoub: VRR siempre en uso normal (−1 W a 120 Hz medido; mirar si parpadea a 120 → 30 Hz).
- PSR desactivado por amdgpu en este panel: revisar con kernels nuevos (sin tocar la línea del kernel).

**Qué debe probar Ayoub** (5 min)
1. Mod+Alt+S: fundido a negro, sello 忍 en la isla, toast; Mod+Alt+S otra vez: vuelve todo (tema, 120 Hz, brillo).
2. En Shinobi sube el brillo con las teclas: se para en 35 %. Bloquea (Mod+L) y desbloquea.
3. Ajustes → Shinobi: botón Entrar/Salir; Ajustes → Energía: «Preguntar antes».
4. Desenchufado con Shinobi activo, enchufa: sale solo.

## 2026-10-17 · Fase 11 · Parte A ✅ 鬼 Oni y juegos (a falta del juego de Ayoub, del reinicio y del ventilador)
Snapshots snapper 75 «antes de fase 11» y 77 (post de pacman).

**Hecho**
- **Pila de juego** (repos oficiales/CachyOS): `cachyos-gaming-applications` (Steam, gamescope, MangoHud, Lutris, Heroic,
  goverlay, faugus) + `cachyos-gaming-meta` (proton-cachyos-slr, umu-launcher, wine-cachyos, protontricks, winetricks,
  ntsync-autoload) + gamemode/lib32, lact, vkmark, protonup-qt. `steam-devices` (mandos). `ntsync` cargado. Ayoub en el
  grupo `gamemode` (vale al volver a entrar). vkBasalt solo en AUR: fuera. Kishin descartado por Ayoub.
- **`Modes`**: estado único `normal|shinobi|oni` excluyente (`request`, cola cancelable, cadena que restaura antes de
  aplicar, épocas por paso), snapshot `oni-prev.json`, reanudación con los dos ficheros. **Oni**: PPD rendimiento,
  scx_lavd modo juego (ayudante `scx`), GPU según ajuste, turbo/«prioridad a la GPU», Wi-Fi sin ahorro, máximo de Hz + VRR
  on-demand (`Displays.boostRefresh`) y `oni.kdl` con VRR por ventana, No molestar por capa, unidades en pausa, ventilador
  al máximo opcional (ayudante `fan`, solo con CA). Guardias: Tctl ≥ 97 °C 10 s, batería < 20 %. **GameMode** →
  `ocarina oni auto-on|auto-off` (`config/gamemode.ini`, governor neutralizado).
- **Shell**: isla 鬼 con 脳/絵/電 (`Sensors`, cada 2 s solo en Oni), 覚醒 (sello con onda + brillo de bordes 600 ms, sin
  brillo sobre un juego de GameMode), toast «Oni · 覚醒», tarjeta de Engawa con tokens Oni, Ajustes › Oni (estado,
  disparadores, equipo, plantillas de gamescope con «Copiar», MangoHud), IPC `oni`, CLI `ocarina oni …` y
  `ocarina play`, `Mod+Alt+O` (ya estaba). MangoHud como plantilla del tema. Steam con `STEAM_FORCE_DESKTOPUI_SCALING=1.75`.
- **Arreglo de Fumi**: los toasts con `-t` no caducaban (Quickshell 0.3.2 da `expireTimeout` en ms).
- `scripts/bench-oni.sh`, `scripts/soak-oni.sh`, `scripts/power-state.sh` ampliado, `ocarina doctor` con energía y juegos,
  `scripts/root/fase-11.sh` (fan_control). Docs: `JUEGOS.md`, D-060, COMPAT, rescate de Oni.

**Criterios de aceptación**
- [x] On/off < 1 s: entrar 87–330 ms (una vez 1,6 s desde Shinobi: el planificador BPF cargando en frío), salir 42–48 ms.
  `power-state.sh` **idéntico** tras: ciclo manual, prueba de 20 min, Shinobi → Oni → normal, Shinobi → Oni cancelado y
  GameMode (`docs/evidencias/fase-11/estado-*.txt`). Excluyente: Oni pedido en Shinobi sale de Shinobi primero (perfil
  base `balanced` en el snapshot de Oni).
- [x] GameMode: `gamemoderun` → Oni en 87 ms con `auto:true`; al cerrar, «juego cerrado» y todo como estaba.
- [x] `docs/JUEGOS.md`: PPD rendimiento +20 %, scx_lavd +3…10 % con menos vatios, Oni +14 % (CPU+GPU) frente a normal,
  gamescope FSR ×2,2; GPU `high` sin ganancia. Configuración ganadora en D-060. Medido con vkmark (elección de Ayoub).
- [x] Capturas ≈ mockup 08 (`oni-isla.png`, `oni-toast.png`, `oni-kakusei.jpg`) y 02 (`engawa-oni.png`); MangoHud
  tematizado (`mangohud.png`); 20 min con CPU+GPU al máximo: Tctl máx 80 °C, GPU 65 °C (`soak-oni.csv`).

**Revisiones**: qml-reviewer (28 puntos: 3 altos en la máquina de estados) y visual-qa (13) aplicados; quedan, aceptados:
la marca de agua 鬼 del toast 16 px más a la izquierda (la × del toast), MangoHud no admite etiquetas kanji para RAM/VRAM
ni el ancho exacto del mockup.

**Métricas**: `qs` 0,05 % CPU en reposo, 0,7 % en Oni (20 s con toast); memoria 222 MB recién arrancada.

**Pendiente**
- Ayoub: `sudo bash scripts/root/fase-11.sh` y reiniciar → «Ventilador al máximo» disponible (doctor lo comprueba).
- Ayoub: volver a entrar en la sesión (grupo `gamemode`, `STEAM_FORCE_DESKTOPUI_SCALING` en todo lo que lanza la shell).
- Ayoub: un juego real con la plantilla de Steam (gamescope anidado con SDL, cursor, VRR, MangoHud) → si algo falla,
  probar «1920×1200» o «sin gamescope» y contármelo; las medidas de JUEGOS.md son sintéticas (vkmark).
- Recomendación de hardware/BIOS en JUEGOS.md: segundo módulo de RAM (doble canal) y UMA en 8 GB.
- Notas para fases: Fune (12) y Snake (15) deben enganchar `oni.funePause` y la descarga de Snake; Mamori (16) aplazado
  en Oni.

**Qué debe probar Ayoub** (10 min)
1. `Mod+Alt+O`: sello 鬼 con onda en la isla, brillo rojo en los bordes, toast; la isla muestra 脳 絵 電. Otra vez: todo vuelve.
2. Con Shinobi activo, `Mod+Alt+O`: sale de Shinobi (vuelven 120 Hz y tu tema) y entra en Oni.
3. Ajustes › Oni › «Copiar» y pégalo en las opciones de lanzamiento de un juego de Steam; ábrelo: Oni se enciende solo,
   MangoHud arriba a la izquierda (Mayús dcha + F12 lo oculta); al cerrar el juego, Oni se apaga solo.
4. Steam: la interfaz a tamaño normal (si sale enorme o diminuta, dímelo).

## 2026-10-17 · Fase 11 · Parte B 🟨 滑 Nameraka (todo construido y medido en corto; faltan las tandas de 5 min y las pruebas de Ayoub)
Snapshot snapper 78 «antes de fase 11 parte B».

**Hecho**
- Motor: `lsfg-vk` 2.0.0 (repos de CachyOS) + Lossless Scaling rama `lsfg-vk` (`lsfg-vk.dll`). `mpv`, `gst-plugin-pipewire`,
  cadena de compilación (meson, ninja, vulkan-headers, wayland-protocols, wlr-protocols, vulkan-validation-layers).
- Prueba de concepto de la captura (FLUIDO.md): ScreenCast v4 sin diálogo, solo DMA-BUF, 2881×1801, un fotograma por
  fotograma nuevo; niri no cierra sesiones huérfanas; WirePlumber no enlaza su nodo.
- **`native/nameraka`** (C++20 + meson, `-Werror`): núcleo con pruebas (base, multiplicador efectivo y aviso, retardo de
  audio, estados, `lsfg.toml`, JSON); `view` (capa overlay sin entrada, 1:1, DMA-BUF sin copias, enlace PipeWire propio,
  swapchain con alfa, latido, captura suspendida en pausa); `daemon` (socket de systemd, eventos de niri, sesiones
  huérfanas, estados, `lsfg.toml` en caliente, vigilante, guardias, calibración, audio sincronizado, dueño del cliente);
  `self-test` (códigos 10–14 → `selftest.json`). `install.sh` lo compila e instala, unidades socket/servicio/self-test.
- **Shell**: `Nameraka.qml`, tarjeta 滑 en Engawa, página Fluido, OSD/«armando», página 滑 de Ajustes, IPC `nameraka`,
  CLI `ocarina nameraka|fluido`, `Mod+Alt+F` / `Mod+Alt+Shift+F`, Automático (pantalla completa + MPRIS), «A medida» con otro
  modo de pantalla, Engawa/Fumi en overlay mientras presenta, `ocarina doctor`, rescate, `scripts/bench-fluido.sh`,
  `scripts/fluido-av-test.sh`. Docs: `FLUIDO.md`, D-061, COMPAT.

**Criterios de aceptación**
- [x] Chrome 30 fps a pantalla completa → **120,0 fps** (mpv y Chrome); `start` → primer fotograma generado ≈ 90 ms; apagar:
  la capa se quita primero (46 ms el proceso entero antes del cambio de orden).
- [x] ×2 · ×4 · ×6 · A medida en caliente (×4 119,6 → ×2 60,0 → ×1 30,0 commits/s, hueco ≤ 1 fotograma base); la tarjeta
  enseña el real («×6 → ×4 · 120 Hz») y avisa ⚠ (30 × 2 = 60 ≠ 120).
- [~] Engawa encima y usable sin pausar (comprobado con capturas). Ratón, teclado y táctil sobre el vídeo: diseño (región de
  entrada vacía, sin teclado) — **lo prueba Ayoub**.
- [x] Vista general, Alt+Tab a otra ventana, bloqueo → pausa en 5–26 ms y vuelta en 29–70 ms (56 ms tras 7 s en pausa con la
  captura suspendida).
- [~] Cadencia: 30 s por escenario → 0,00 % tarde (mpv) y 0–0,17 % (Chrome), CPU del ayudante 2,0–3,0 %, 0 procesos apagado.
  **Faltan las tandas de 5 min** (1080p30 ×4, 1080p60 ×2, 1080p24 A medida): `scripts/bench-fluido.sh mpv 30 custom 300`…
- [x] Vigilante: `kill -STOP` → capa fuera en 680 ms.
- [~] Audio sincronizado: mecanismo comprobado (62 ms, vuelta limpia); **la validación a ojo y oído es de Ayoub**
  (`scripts/fluido-av-test.sh`); `avSync` apagado por defecto hasta entonces. Shinobi lo bloquea y lo apaga.
- [x] Capturas ≈ mockups 02 y 13 (`fluido-tarjeta-*.png`, `fluido-pagina-panel.png`); `ocarina doctor` y Ajustes explican
  cualquier falta (lsfg-vk, DLL, ScreenCast, Vulkan).

**Medidas** calibración (24 combinaciones, FLUIDO.md): 2880×1800 ×4 flujo 0,75 → 41,5 fps base (30 × 4 cabe con margen
1,3×). GPU 80–82 % con 30 × 4. Motor IA: no pasa la puerta (RIFE-ncnn de 2022 incompatible con ncnn 2026).

**Pendiente**
- Tandas de 5 min con la pantalla ocupada (15 min) y potencia en batería (`bench-power.sh` sin Nameraka · ×4 · eco · pausa).
- avSync: decisión con Ayoub tras la prueba. YouTube real en Chrome (DRM/streaming sin prometer: anotar).
- Fase 17: registro de PipeWire por eventos para avSync; degradado a 135° de la tarjeta; animación del OSD; THP de `qs`
  (perf-auditor: RSS 404 MB por `anon_thp`, propuesta `PR_SET_THP_DISABLE`).


## 2026-10-17 · Fase 12 ✅ 船 Fune (a falta de la prueba de Win+F de Ayoub y de la medida de batería)
**Entrevista** (D-062): Podman sin root · Windows 11 Pro 4 vCPU / 6 GB / 96 GB · Windows ve todo `~/` (solo con una app
conectada) · sin apps concretas. Snapshot **#87** «antes de fase 12».

**Hecho**
- Podman 6.1 sin root (0 demonios), dockur 6.06 fijado (`config/winapps/compose.yaml`, solo 127.0.0.1, red passt con
  `USER_PORTS`), subvolumen NOCOW fuera de snapper, contraseña aleatoria en el llavero, apagado ACPI con margen
  (`--stop-timeout=120` + drop-in `libpod-.scope.d`). Windows instalada sola en ≈ 26 min.
- `bin/ocarina-fune`: ciclo de vida, RDP real (X.224), **una sola conexión RemoteApp** con agente propio en la sesión
  (`assets/fune/{agent,launch}.ps1`, `launch.vbs`), apps por `.rdp` temporal (archivos con espacios y ñ desde Nautilus),
  UWP por `shell:AppsFolder`, escaneo con nombres en español, web, Wine (umu + proton-cachyos, clase e icono por app,
  DPI), `rules`, `stats`, `toggle`, `update`/`maintenance`/`backup`/`smoke`, hora de Linux al reanudar.
- Shell: servicio `Fune` por eventos, panel 船 ≈ mockup 09, indicador 船, «Windows despertando…», página 船 Windows,
  IPC, `(Windows)` en el título, ventanas auxiliares invisibles y fuera del mosaico, Win+F inteligente (`ocarina
  maximize`), botón de perfil de energía delante del Wi-Fi (petición de Ayoub). qml-reviewer: 30 hallazgos corregidos.
- Problemas encontrados y resueltos en vivo: «otro usuario ya inició sesión» (AutoLogonCount de dockur, corregido en
  el registro de la VM sin conexión), robo de sesión entre conexiones (ventanas que no cierran ni repintan), comillas
  de `/app`, consola visible del lanzador, apagado cortado por una recarga de la shell (acciones en `systemd-run`).
- WinBoat analizado: ideas adoptadas (token en tiempo constante, peticiones acotadas), no su código ni su modelo.

**Criterios**
- [x] Nivel 2 (Bloc, Paint, Explorador…) y nivel 1 (Notepad++) como ventanas de niri, nítidas, anillo asagi; teclado,
  portapapeles y Win+Q confirmados por Ayoub; archivos desde Nautilus. Nivel 0: mecanismo listo (Ayoub no quiere M365).
- [x] Pausa automática real (Shinobi: 8 s, apagado a los 5 min) · abrir desde pausa **1,86 s** · apagada → +6,1 GiB.
- [x] Puertos solo `127.0.0.1`; contraseña y token en el llavero (fuera de git y de ficheros legibles).
- [x] Panel ≈ mockup 09 (`docs/evidencias/fase-12/panel-fune.png`); `docs/WINDOWS.md` con medidas y flags.

**Métricas**: frío 18,7–20 s · pausa 1,86 s · activa 0,8 s · Wine 5,1 s · reposo QEMU 2,8 % + xfreerdp 0,03 % ·
pausa 0 % · apagado 12–14 s · 0 procesos apagada.

**Pendiente**: Win+F con el teclado de Ayoub; `bench-power.sh` (activa/pausa/apagada) y eco de tecleo; RSS de
xfreerdp3 (548 MiB, probar modos `/gfx`); inventario de apps del menú Inicio (estilo WinBoat) cuando instale sus
programas; Mod+R no redimensiona ventanas de Windows.

**Qué debe probar Ayoub**: abrir una app de Windows desde Torii (sale a ancho completo), Win+F dos veces, Win+Q; dejar
Windows sin apps 10 min → 船 atenuado (pausa); abrir otra vez (≈ 2 s).

## 2026-10-17 · Fase 13 · 🟨 EN CURSO — punto exacto para retomar
Snapshot **#96**. Commits 01b37f7…323cc36.
**Hecho (en el repo, verificado sin tocar /boot)**
- `bin/ocarina-boot-theme` (status · apply dark|light|auto · limine-merge/unmerge) y scripts root: `fase-13.sh`
  (= limine-tema + plymouth-tema), `limine-tema.sh`, `plymouth-tema.sh`, `probar-plymouth.sh`, `greeter.sh`
  (instalar/activar/desactivar/actualizar), `probar-greeter.sh` (vt 7, PAM real), `probar-kernel.sh`. Simulados en un
  árbol falso (instalar → cambiar variante → desinstalar deja limine.conf idéntico).
- Limine 12.9.3 en QEMU con el limine.conf real ≈ referencia (`docs/evidencias/fase-13/limine-qemu-*.png`).
- Despedida (`Farewell.qml`) = primer fotograma del Plymouth de apagado (1–2 px, 1 nivel de color); `ocarina power
  farewell shutdown|reboot|logout` para probarla. Llegada: startup + barra que entra una vez por sesión.
- Greeter propio (`greeter/`, `system/greeter/`), probado en modo prueba dentro de la sesión.
- Extras pedidos por Ayoub: ventanas nuevas a media pantalla (D-066); Bluetooth persistente con rfkill (D-065).
**Falta (Ayoub ejecuta; después Claude comprueba)**
1. `sudo bash ~/ocarinashell/scripts/root/fase-13.sh dark` → `ocarina-boot-theme status`.
2. Ctrl+Alt+F3 → `sudo bash ~/ocarinashell/scripts/root/probar-plymouth.sh` → leer `~/.cache/ocarinashell/plymouth-debug.log`.
3. `sudo bash …/greeter.sh instalar dark` → `sudo bash …/probar-greeter.sh` → `greeter.sh activar`.
4. Reinicio real con Ayoub mirando (Limine → Plymouth → greeter → sesión; despedida → apagado). `systemd-analyze` después
   (antes: `docs/evidencias/fase-13/systemd-analyze-antes.txt`).
5. `sudo bash …/probar-kernel.sh`. Revisión qml-reviewer (lanzada) y visual-qa con las capturas.

## 2026-10-17 · Fase 13 · ✅ Arranque y apagado (a falta de probar-kernel, del llavero «Default» y de las revisiones)
Snapshots #96, #101–#102 (temas) y los de greeter/llavero. Commits 01b37f7…53e984d.
**Hecho y visto en el equipo real**
- Limine 12.9.3 con tema oscuro, timeout 3 s y `terse` (sin «Loading kernel…»); el bloque vive en la cabecera, que las
  herramientas de CachyOS conservan (D-063). QEMU con el limine.conf real ≈ referencia.
- Plymouth `ocarinashell` desde el initramfs, `DeviceScale=1`, línea del kernel silenciosa; sin errores en el journal.
  Apagado/reinicio empiezan en t = 280 (se mueve desde el primer instante).
- Greeter propio en greetd (tty1): Plymouth → greeter en 0,7 s sin modeset (60 Hz), `deactivate` + `--retain-splash`;
  prueba en seco con PAM real (mala → AUTH_ERR, buena → ok); entrada real de Ayoub por el greeter. Respaldo agreety.
- Despedida animada (BootOcarina = el bucle de Plymouth) en apagar/reiniciar/cerrar sesión; espera a Fukugen y a
  Windows ≤ 30 s; salvaguarda de 2,5 s. Llegada: startup + barra que entra una vez.
- Peticiones de Ayoub durante la fase: ventanas a media pantalla (D-066), Bluetooth persistente (D-065), llavero por
  PAM (D-067: `login` se abre solo), foco que sigue al ratón con columnas a media pantalla (max-scroll 25 %).

**Métricas** (`docs/evidencias/fase-13/systemd-analyze-*.txt`): kernel 0,92 → 0,74 s · initrd 2,32 → 2,44 s · userspace
hasta graphical 4,09 → 3,98 s: el splash no alarga el arranque. Despedida vs Plymouth: 1–2 px, 1 nivel de color.

**Pendiente**
- Ayoub: `sudo bash scripts/root/greeter.sh actualizar dark` (unidad de traspaso con RemainAfterExit) si no lo hizo;
  `sudo bash scripts/root/probar-kernel.sh` (el tema sobrevive a reinstalar el kernel); decir si vio negro/texto entre
  Plymouth y el greeter.
- Llavero: Chrome usa «Default keyring» (6 entradas, otra contraseña). Solución preparada sin probar:
  `bin/ocarina-keyring merge` (mueve las entradas a «login» comprobando cada copia y lo hace el llavero por defecto) —
  falló al leer por una ruta caducada de gnome-keyring; reintentar con Ayoub delante. Alternativa: al pedirla, marcar
  «Desbloquear automáticamente al iniciar sesión».
- qml-reviewer (se cortó dos veces con los reinicios) y visual-qa del greeter/despedida → al inicio de la fase 14.
- Ctrl+Alt+F3 no cambia de consola (probablemente necesita Fn): confirmar Ctrl+Alt+Fn+F2 como salida de rescate.

## 2026-10-17 · Fase 14 · 🟨 EN CURSO — punto exacto para retomar
Snapshot **#117**. Commits f4a35c2…(último «simulacros a, b, f, g, j»). Decisiones D-070 (snapper @home en vez de restic,
petición de Ayoub) y D-071 (singletons sin módulos sensibles).
**Hecho y verificado**
- Capa 1 verificada: snap-pac 3.0.1, limine-snapper-sync 1.32.1 (enabled), linux-cachyos-lts 6.18.55 en Limine,
  kernel-modules-hook, paccache -k3. Falta la prueba real de bajada (lazygit 0.66.2 → 0.66.1 desde la caché y vuelta)
  con `ocarina-maint downgrade` cuando esté instalado.
- Capa 3: qml-reviewer → 22 hallazgos; arreglados los críticos e importantes (backends Power/Media/Audio/Idle/Lock/Notifs,
  Settings, greeter, NightLight, Mado, niri-gen, KbdLight, atomicWrites, Nameraka binding loop). Pendientes menores para
  la fase 17: tokens sueltos del greeter (#20), parche de títulos en Niri (#15), `available/error` en servicios sin
  dependencia externa (#7, parte).
- Capa 4: modo seguro con causa en la barra + panel 診 Diagnóstico (orden probada en el journal real).
- Capa 5: `ocarina-maint` (20/20 llamadas maliciosas rechazadas como usuario), `scripts/smoke-test.sh` (22 pasivas en
  1,8 s; detecta un niri.kdl roto), `ocarina-bootmark` + unidad (activa), hook de pacman + `ocarina-postupdate.path`
  (activo), `ocarina update` (--check probado: 52 + 1 AUR pendientes), `ocarina rollback`, `ocarina backup`, 新 en Obi
  (servicio Updates: 52 pendientes visto por IPC), `install-system.sh` arreglado (instalaba system/greeter en /greeter).
- Simulacros superados (evidencias en docs/evidencias/fase-14/): a, b, f, g, j.
**Falta**
1. Ayoub: `sudo bash ~/ocarinashell/scripts/root/fase-14.sh` (ayudante + hook + sudoers + snapper home + greeter).
2. Con Ayoub delante: simulacros c (módulo roto en rama de prueba), d (5 caídas → modo seguro → Reintentar),
   e (reinicio de PipeWire), h (hook tras `pacman -S` inocuo), i (paquete de prueba que rechaza Yuji Syuku →
   `ocarina rollback`), k (borrar y recuperar con `ocarina backup restore`); `ocarina doctor --post-update`;
   bajada/subida de lazygit; `ocarina update` real (52 paquetes); captura recortada del 新 y visual-qa.
3. Docs: COMPAT.md, 06-ACTUALIZACIONES (Hikae = snapper, activo/pasivo tras pacman, rollback y /boot), 05-RESCATE.

## 2026-10-17 · Fase 14 · ✅ Blindaje
Snapshots #117 (antes de la fase), los del script root (blindaje, snapper home, greeter) y #126 (antes de la primera
`ocarina update`). Decisiones D-070 (snapper @home), D-071 (singletons sin módulos sensibles), D-072 (systemd supervisa
cada caída). Evidencias: `docs/evidencias/fase-14/`.
**Hecho y verificado en el equipo**
- Capa 1: snap-pac, limine-snapper-sync, LTS en Limine, kernel-modules-hook, paccache -k3; bajada real lazygit
  0.66.2 → 0.66.1 desde la caché con `ocarina-maint downgrade` y vuelta.
- Capa 2: doctor/smoke comprueban repos oficiales, `-git`, yay; `lazy-lock.json` en git.
- Capa 3 (qml-reviewer, 22 hallazgos): crítico — un singleton con un import sensible tumbaba TODA la shell → backends
  aislados (Power, Media, Audio, Idle, Lock, Notifs); ajustes (copia antes de escribir, conserva los buenos en caliente,
  límites, versión en texto, aviso en Fumi); greeter (sale a agreety si greetd falla, errores ≠ contraseña, teclado en
  Reiniciar/Apagar); luz nocturna, Mado, niri-gen, KbdLight, atomicWrites, bucle de binding de Nameraka.
- Capa 4: modo seguro con la causa en la barra + panel 診; botones arreglados (nunca habían funcionado); respaldos del CLI
  y swaylock tematizado con la shell parada.
- Capa 5: `ocarina-maint` (lista blanca, 20/20 ataques rechazados como usuario y por sudo, journal, flock;
  rollback solo del último par con /boot coherente), regla sudoers 91-ocarina-maint (visudo -c), pruebas de humo
  (`ocarina doctor --smoke` 1,9 s · `--post-update` 5,3 s), hook de pacman → `ocarina-postupdate.path` (activo solo si
  cambia la base de la shell), `ocarina-bootmark`, `ocarina update`, `ocarina rollback`, `ocarina backup`, 新 en Obi.
- 控 Hikae = snapper `home` cada hora (D-070), restauración en ~/Restaurado/ sin root.
- Simulacros a–k superados; d encontró dos fallos reales (OnFailure en cada caída → `RestartMode=direct`; relanzador de
  Quickshell → `QS_DISABLE_CRASH_HANDLER=1`).
- Primera actualización real: 52 paquetes + Chrome (diff del PKGBUILD revisado), pruebas de humo verdes.
- Peticiones de Ayoub: sin restic (snapshots); CPU · GPU · RAM en vivo junto al perfil (anillos del tamaño de la batería
  con el % dentro; FileView cada 2 s, parado en Shinobi/bloqueo/pantalla apagada; Ajustes › Barra › «Uso en tiempo real»).
**Métricas**: smoke pasivas 1,9 s · activas 5,3–5,6 s · una caída → vuelve en 2,8 s · 4 caídas → modo seguro 4,9 s ·
reversión completa 2,3 s · niri socket: reconecta 0,8 s tras volver · PipeWire: audio de vuelta en 0,64 s · muestreo de
uso ≈0,28 ms cada 2 s · memoria del cgroup en reposo 228 MB (presupuesto 220 → fase 17) · CPU de qs 5 % con Chrome
reproduciendo (ecualizador de la isla; medir en reposo de verdad en la fase 17).
**Pendiente**
- Ayoub: reinicio normal cuando le venga bien (el greeter con los arreglos de la auditoría solo se ve al arrancar).
- paru con `SudoLoop` pide contraseña (sudo -v + verifypw=all): en interactivo la teclea Ayoub; Mamori (fase 16) usará
  `--nosudoloop` con el ayudante.
- visual-qa (fase 13): despedida algo blanda (posición a medio píxel) y fase de las ondas distinta de Plymouth en el
  corte (parar en t=280); Limine con el limine.conf real: contenido bajo y descentrado en la tarjeta, comentario
  «Kernel version» en asagi, entradas «Other systems/EFI fallback» en inglés; 1 nivel de color en el fondo de Plymouth;
  corregir D-064 (t=280). Capa 3 menor: tokens sueltos del greeter (#20), parche de títulos en Niri (#15).
**Qué debe probar Ayoub**: mirar los anillos de uso con una carga (un vídeo, una compilación); `ocarina update --check`;
`ocarina backup list ~/algún-fichero`; reiniciar y ver que el greeter y el escritorio llegan bien (la marca de arranque
lo registra sola: `ocarina-bootmark status`).

## 2026-10-17 · Fase 15 · ✅ 蛇 Snake: la IA local · 読 Yomu
- Snapshot 131 «antes de fase 15». Paquetes: llama-cpp 0.6.0 + ggml-vulkan 0.26.0, xrt, xrt-plugin-amdxdna, fastflowlm.
- **Hecho**: `bin/ocarina-snake` (servidor bajo demanda con vigilante, política, 9 tareas con esquema JSON, lista blanca
  de fuentes y de acciones, contexto de solo lectura, evaluación con vatios del SoC, `warm`), `snake/` (5 modelos
  Apache-2.0 con sha256, 38 casos de evaluación, actions.json, sources.json), unidad `ocarina-snake.service` sin red
  (`PrivateNetwork=yes`, socket Unix en `$XDG_RUNTIME_DIR`), UI (panel ≈ mockup 11 con `Mod+Shift+A`, indicador 蛇 en
  Obi, `;` en Torii, `snake` en fish, Ajustes › 蛇 Snake, precarga al abrir el panel), 読 Yomu (`Mod+Alt+T`,
  `ocarina read`, OCR horizontal/vertical, traducción en streaming), pruebas de humo (snake, yomu), docs/SNAKE.md.
- **Modelo**: gpt-oss-20b (MXFP4) en Vulkan — 95,2 % clasificación, 100 % JSON válido, 100 % inyección (6/6; en una
  repetición un log no se marcó como sospechoso, sin recomendar el comando), 10–11 tok/s. Tabla de los 5 modelos y la
  NPU en docs/SNAKE.md (D-073).
- **Criterios**: ≥ 85 % clasificación ✓ · 100 % JSON ✓ · RAM 0 en reposo ✓ (unidad parada, sin procesos ni socket;
  MemAvailable y GTT vuelven al parar, perf-auditor) · frío: carga 11–12 s, primera palabra ~16 s sin precarga (la
  precarga al abrir el panel la solapa con lo que se escribe) · caliente ~3 s, **no < 2 s** (razonamiento obligatorio
  de gpt-oss + memoria de un canal, D-074) · acciones solo con «Ejecutar» ✓ (oni-off confirmado por Ayoub 19:16:24) ·
  inyección ✓ · Shinobi y Oni descargan Snake ✓ (19:16:12 y 19:19:10, journal) · Yomu: OCR 97,8–100 % en tests/yomu,
  traducción coherente, probado por Ayoub ✓ · red: 455 muestras durante carga y traducción, 0 conexiones de Snake/Yomu ✓.
- **Incidentes**: qwen3.6-35b-a3b agotó la GTT y tumbó niri (dos veces se cerró la sesión de Claude) → regla dura de
  memoria de GPU (D-073). `IPAddressDeny` no se aplica en unidades de usuario → socket Unix + PrivateNetwork (D-078).
  slurp lanzado desde la shell esperaba rectángulos por stdin → `</dev/null` (también en la grabación de región).
- **Peticiones de Ayoub durante la fase (hechas)**: iconos de Obi centrados ópticamente; 広場 ネコ gato vibing cyberpunk
  rojo y gris en lugar de «sol y luna» (D-075); Nameraka detecta siempre la ventana y se llama Nameraka; foco sigue al
  ratón con ventanas medio ocultas; clic en notificación → destino; luz del teclado con 3 niveles + icono; barras
  deslizantes (D-076); Shinobi con VRR a 120 Hz en vez de 60 Hz, sin parpadeo (D-079); tarjeta de Yomu sin recuadro negro.
- **visual-qa** (asistente ≈ mockup 11, `docs/evidencias/fase-15/snake-asistente.png`): estructura y medidas
  coinciden (±2 px); corregidos el ritmo 10 → 14, el detalle repetido de la acción, el 蛇 de la cabecera y los ••• que
  laten al generar. Quedan bajas: acción secundaria fantasma del mockup («Salir de Shinobi al enchufar», necesita un
  campo `setting` en el esquema), pesos del kanji (Kanji.qml fuerza Bold), subtítulo 12,5 frente a 12, mono 4 % mayor,
  foco del campo al 50 % de acento; sin ver: chips adjuntos, streaming y Kōhaku.
- **Pendiente / notas**: RSS de qs 373 MB (> 220, anterior a esta fase; THP `always`, propuesto `PR_SET_THP_DISABLE`);
  despertares de qs a medir en reposo real; el perfil de energía está en «Ahorro» enchufado (decisión de Ayoub).
- **Qué probar**: `Mod+Shift+A` y una pregunta (el modelo empieza a cargar al abrir); `;` en Torii; `snake ¿qué hace
  Shinobi?` en fish; `Mod+Alt+T` sobre texto japonés → «Traducir con Snake»; Shinobi (`Mod+Alt+S`) sin parpadeo.

## 2026-10-17 · Fase 16 · ✅ 守 Mamori: mantenimiento autónomo
Snapshot #134 «antes de fase 16» (+ los del script root y #141 del primer ciclo real). Decisiones D-080 (AUR compilado
por root en un entorno aislado; petición de Ayoub), D-081 (diseño) y D-082 (peticiones y notas). Ayoub: IA = solo
Snake, instalar solo con cargador. Evidencias en `docs/evidencias/fase-16/`.
**Hecho**
- `bin/ocarina-mamori` + `lib/mamori/` (condiciones, salud y autorreparación, inventario, política, AUR, aplicación,
  verificación, adaptación, reversión, informes, periódico, ciclo reanudable con `flock` y `status.json` por paso,
  `--dry-run` en todo). `ocarina update` = `ocarina mamori run --interactive` (fuera `bin/ocarina-update`).
- Unidades: `ocarina-mamori.timer` (04:00, Persistent, ±20 min) → `ocarina-mamori@timer`, reintento transitorio cada
  30 min, `@shell` (15 min fuera), `@boot` (tras `ocarina-bootmark`), `ocarina-mamori-heal` (desde el modo seguro).
- `ocarina-maint`: `aur-build` (commit exacto del AUR, usuario efímero DynamicUser, claves PGP del commit), `unit-restart`
  (solo unidades fallidas), `time-sync`, `paccache 2|3`, `health` con snapshots; `upgrade` se niega si un repo
  `file://` es escribible. **Hallazgo de seguridad**: el repo local de paru era de Ayoub → cualquier proceso suyo podía
  colar un paquete instalado como root por la regla sin contraseña; ahora es solo de root (`scripts/root/fase-16.sh`).
  32/32 llamadas maliciosas rechazadas.
- Shell: servicio `Mamori` (sin sondeo, reloj por minuto, IPC `mamori conditions/status/refresh/run/open`), inactividad
  de 10 min, página 守 Mantenimiento ≈ mockup 10 (+ retenciones, interruptores, 控 Copias), 新 en Obi cuando hay reinicio
  o algo que mirar, `Updates` cede la cuenta a Mamori cuando está vivo.
- Snake: `eval` de cada modelo en `snake/models.json` para la evaluación mensual.
**Criterios**
- Simulacros a–j ✓ (`tests/mamori-simulacros.py`, `tests/mamori-simulacro-a.sh`): a) Snake adaptó la API rota al primer
  intento y las pruebas activas validaron antes de fusionar (5 vueltas previas para arreglar el orquestador); b) noticia
  con intervención → retiene y extrae los pasos; c) `curl | bash` en un PKGBUILD → sospechoso, no se instala; d) disco
  lleno → limpieza; e) unidad fallida → reparada; f) kernel que no arranca → retenido + bajada; g) sin red/sin IA →
  determinista (7 días); h) GameMode y micrófono reales → aplaza; i) batería → aplaza; j) pausa/reanudar.
- Ciclo real con Ayoub delante ✓: 7 paquetes, snapshot #141, pruebas de humo ✓, entrada y commit en
  `docs/MANTENIMIENTO.md`; BIOS 0.1.22 y dbx 20260707 esperando su aprobación.
- AUR real ✓: papirus-folders recompilado e instalado por `aur-build` (snapshots 138/139).
- Página 守 ≈ mockup 10 ✓ (visual-qa: horizontal ±1 px; arreglados interlineado de Snake, márgenes, filas, casillas,
  chips). Informe semanal: se genera el domingo (probado con `report --weekly` en simulación; el primero real, el 18).
- Solo regla mínima ✓: todo lo de Mamori pasa por `sudo -n ocarina-maint` (el ciclo real lo hizo así); quitar el
  drop-in temporal lo hace la fase 17 (`fase-16.sh sin-sudo` aparca el temporal N minutos con vuelta automática).
- Jaula de Claude Code ✓: las 5 denegadas y sin efecto (`docs/evidencias/fase-16/jaula-claude.txt`).
**Pendiente / para la fase 17**
- Revisar la primera semana de Mamori (ciclos, retenciones, falsos avisos: los coredumps de hoy eran de la GTT agotada
  en la fase 15, no de Mesa como sugirió Snake).
- Pasada tipográfica global de Ajustes (visual-qa): `SectionTitle` suma 4 px de `spacing` (+5,7 sobre el mockup), chip
  de cabecera sin alinear por línea base, tamaños de medio píxel; degradado diagonal de la tarjeta de estado.
- Recapturar la página 守 en el tema Kurenai (la captura es en Sumi) con un ciclo ya hecho («Todo en orden»).
- Tras el cierre, peticiones de Ayoub: 器 cajón de apps de la ocarina (D-082) y animación al pulsarla; probado por Ayoub ✓.
**Qué debe probar Ayoub**: pulsar la ocarina (cajón de apps, buscar tecleando, Tab = acciones/fijar); Ajustes › 守 Mantenimiento; aprobar o no
la BIOS 0.1.22 desde su notificación; `ocarina mamori status` mañana por la mañana.

## 2026-10-18 · Fase 17 · 🟨 hecha salvo la revisión de la primera semana de Mamori (24/10) y el tag
Decisiones de Ayoub al empezar: todo hoy y **tag el 24/10** tras revisar la primera semana de Mamori; **sudo temporal
fuera hoy** ✓; opcionales: **Snake con voz** ✓ y **fondos por estación 七十二候** ✓ (el grabador ya existía); **sin
monitor externo** (D-091). Snapshots **#144** «antes de fase 17» y **#147** «1.0-rc.1, antes de quitar el sudo temporal».
**Hecho**
- QA visual independiente (visual-qa, 2 rondas sobre 26 pantallas): ronda 1 = 3 altas + 8 medias → corregidas
  (Atajos vacío, cajón 器 que no abría por IPC → capa propia, tarjeta de Mamori, cápsulas, SectionTitle, chip de
  cabecera, Fluido apagado, Snake, textDim AA); ronda 2 = **0 altas**, 7 medias → corregidas (buscador del cajón,
  icono cuadrado por el SVG, rejilla, insignia de Mamori, mensaje de Snake, cápsulas en temas claros, acentos).
  Evidencias en `docs/evidencias/fase-17/qa/`.
- Rendimiento (perf-auditor): lanzador 8–14 → 2,3–3,9 ms ✓; `MemoryTHP=disable` → la shell en **158 MB** (antes
  403–506); arranque 478–499 ms (presupuesto 400, justificado en D-091); Snake parado 0 MB ✓, Fune apagada ✓, Mamori
  Nice 19 + IO idle sin sondeo ✓; el ecualizador ya no corre bloqueado, con pantalla apagada, en batería ni tapado.
- Robustez (`tests/robustez.sh`, cada paso lo disparó Ayoub): kill de la shell (vuelve en 1,9 s), 20 temas, 20 Shinobi,
  10 Oni, sin red, rfkill BT, reproductor que desaparece, 100 notificaciones, 20 Fluido con vídeo + Alt+Tab/vista
  general/bloqueo, 4 suspensiones (2 con tapa): 0 errores; 1 aviso (toast en ráfaga) corregido. Cargador, monitor
  externo, Fune y Snake con la VM: no probados (D-091). `docs/evidencias/fase-17/robustez.txt`.
- Accesibilidad: contraste AA calculado (`tests/contraste.py`, en doctor), navegación por teclado completa en los
  paneles (qml-reviewer → 2 agentes), foco visible, movimiento reducido (ecualizador incluido).
- Documentación: README con **capturas reales** (Wi-Fi y host pixelados; mockups en un desplegable), 03-ATAJOS
  (Super+D cajón, Super+Alt+A voz), 05-RESCATE verificado y ampliado, `ocarina doctor` completo (QML, contraste,
  atajos, Snake/voz, Mamori): «Sin problemas, 2 avisos» (limine.conf sin root; ventilador de Oni).
- Limpieza: **sudo temporal eliminado** (`sudo -n true` falla; `sudo -n ocarina-maint health|boot-check` funciona);
  `scripts/install.sh --dry-run` «nada que cambiar»; artefactos de prueba fuera del repo (PNG del README borrados).
- Peticiones de Ayoub durante la fase: terminal y Neovim translúcidos (80 %, desenfoque xray), **Atajos editables** en
  Ajustes, Acerca con «Created by Ayoub» y condiciones (GPL-3.0+, CC BY-SA, D-088), **墨 medidores** de CPU/RAM/GPU en
  la barra (cifra encima, tinta con muelle, pico; hover → kanji), cifras legibles; la **isla y 広場 Hiroba de papel en
  los temas claros**; el **gato ネコ con el acento del tema** (gris fijo; capas base + tinte y shader `nekotint`).
- Snake: voz local (whisper.cpp), modelo ligero automático si el principal no cabe en la GPU (qwen3.5-9b/4b), mensajes
  de política para personas, 2 evaluaciones nuevas con casos reales (40 en total).
- Herramientas nuevas: `tests/qml-check.sh`, `tests/render-page.sh` (UI a PNG sin tocar la pantalla),
  `tests/capturas-qa.sh [--readme]`, `tests/robustez.sh`, `tests/contraste.py`, `bin/ocarina-binds`.
- Decisiones D-083…D-091. Versión **1.0.0-rc.1**.
**Pendiente (24/10)**
- Revisar la primera semana de 守 Mamori: `docs/MANTENIMIENTO.md` y `history.jsonl` (¿actuó cuando debía?, avisos
  innecesarios —hoy marca «5 cosas para mirar», en parte diagnósticos de la fase 15 que eran la GTT—, decisiones de
  Snake), ajustar umbrales/plantillas y ampliar `snake/evals/`.
- perf-auditor en reposo real (audio en pausa, 2 min sin tocar) para CPU/despertares de la shell.
- Versión `1.0.0` (Paths.qml, bin/ocarina), `sudo -n /usr/local/libexec/ocarina-maint snapshot "OcarinaShell 1.0"`,
  `git tag ocarinashell-v1.0.0` (D-089), PROGRESS todo ✅ y el resumen final a Ayoub.
**Qué debe probar Ayoub**: Super+D (cajón, escribir directo, Esc); Ajustes › Atajos (lápiz); Super+Alt+A (voz);
los 墨 medidores de la barra (pasar el ratón); Ajustes › Fondos: etiquetar con 1–4 y «Rotar: Con el 七十二候».

## 2026-10-23 · Fase 17 · ✅ cerrada · OcarinaShell 2.0.0
**Primera semana de 守 Mamori revisada (D-092)**: actuó bien (actualizaciones con snapshot y pruebas, chrome del AUR
revisado y compilado aislado, lote grande madurando, firmware esperando aprobación). Arreglado: falso fallo de
pipewire-pulse (servicio por socket), Neovim «en rojo» por leer mal su JSON, Snake rediagnosticando volcados de la
sesión caída (filtro de volcados simultáneos, una vez por semana, prompt con las dos trampas reales: diagnóstico 6/6),
«cosas para mirar» solo cuenta lo nuevo, volcados desde la última revisión (no 24 h). Bugs reales encontrados de paso:
segfault de Nameraka al apagar Fluido (carrera render/stop) y `llama-server` abortando al pararse (KillMode=mixed).
**Peticiones de Ayoub al cerrar**: Bluetooth apagado que sobrevive al reinicio (Settings + reaplicar al iniciar sesión;
6 arranques comprobados), página «Nameraka» en Ajustes, `AGENTS.md`, instalador animado (`./install.sh`, D-094), repo
de kit a dotfiles terminados (D-093): fases en `docs/historia/fases`, README/CLAUDE/CHANGELOG/CI/release al día, guías
de docs/ revisadas, registro de Mamori y capturas con su fondo fuera de git.
**Otros**: chips rojos con texto AA, teclas alternativas como teclas en Atajos, nombres de Fune en dos líneas.
**Sin hacer (justificado)**: medida del reposo real de la shell (necesita 2 min sin tocar el portátil: pendiente de
Ayoub), monitor externo (no tiene), cargador en la pasada de robustez, kanji de la cabecera de Ajustes 3 px bajo.
**Qué debe probar Ayoub**: `./install.sh --demo` en una terminal grande (todo el espectáculo sin cambiar nada); Ajustes ›
Nameraka; Super+D, Super+Alt+A; aprobar o no la BIOS 0.1.22 desde su aviso.
