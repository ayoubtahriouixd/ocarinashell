# Decisiones (ADR ligeros)

Formato: `## D-NNN · título` · fecha · contexto · decisión · alternativas descartadas · consecuencias.

## D-001 · Marca roja sobre blanco (紅白)
2026-10-13 · Ayoub pidió el logo «rojo con fondo en blanco». Decisión: rojo `#E60033` (赤) como acento de marca
en todos los temas; tema claro Kōhaku que replica el logo; Kurenai oscuro por defecto (OLED). Se confirma en la
entrevista de la fase 0.

## D-002 · niri + Quickshell, sin demonios de UI externos
2026-10-13 · OcarinaShell es barra, notificaciones, lanzador, bloqueo, polkit y OSD en un único proceso `qs`.
Menos procesos, coherencia visual total y un único interruptor de animaciones/energía (Shinobi).

## D-003 · Kit para Claude Code por fases
2026-10-13 · Especificación + mockups + assets verificados; Claude Code implementa en 18 fases (00–17) con snapshot,
verificación visual y métricas en cada una.

## D-004 · Shinobi y Oni, modos excluyentes con snapshot
2026-10-13 · Ahorro extremo (忍) y rendimiento extremo (鬼) comparten orquestador y estado `normal|shinobi|oni`;
pasar de uno a otro restaura primero el estado previo. Evita combinaciones incoherentes (p. ej. 60 Hz con turbo).

## D-005 · paru como único ayudante del AUR
2026-10-13 · Petición de Ayoub: paru en vez de yay, optimizado (`reference/paru.conf`, `reference/makepkg.conf`):
noticias antes de actualizar, repo local de compilados, `-march=native`, LTO, ccache y compilación en RAM.

## D-006 · Apps de Windows: WinApps + dockur/windows en KVM, Wine/Proton primero
2026-10-14 · Ayoub pidió WinBoat «o alternativa más optimizada». WinBoat (beta, Electron, sin CLI ni accesos `.desktop`)
y WinApps usan la misma base (Windows en KVM vía `dockur/windows` + FreeRDP RemoteApp). Se elige **WinApps** como
motor porque es scriptable, crea accesos `.desktop` con iconos y tipos MIME (aparecen en Torii y Nautilus) y trae pausa
automática; la interfaz la pone OcarinaShell (panel 船). Wine/Proton (`umu-run`) para lo que funcione sin VM.
WinBoat queda como alternativa si Ayoub prefiere su interfaz (fase 12 le pregunta).

## D-007 · Mantenimiento autónomo 守 Mamori, con la IA como extra
2026-10-14 · Ayoub no quiere mantener ni actualizar nada. Orquestador determinista + ayudante root con lista blanca +
pruebas y reversión automáticas; la IA (Snake, D-008) solo investiga, revisa y propone; nunca ejecuta. Sin IA, Mamori
sigue en modo determinista (maduración más larga, AUR solo con diffs triviales).

## D-008 · 蛇 Snake: IA local gratuita en lugar de depender de suscripciones
2026-10-14 · Ayoub pidió una IA local gratis llamada Snake para no depender de suscripciones. Servidor local
OpenAI-compatible (llama.cpp Vulkan en la iGPU por defecto; NPU XDNA 2 con FastFlowLM si es estable), modelos de pesos
abiertos con licencia libre elegidos por evaluación propia, tareas acotadas con salidas JSON validadas, carga bajo
demanda. Claude Code queda como extra opcional (`mamori.ai = claude|both`). Límite asumido: menos capaz que un modelo
grande en reescrituras; por eso todo cambio se verifica y, si no se logra, se revierte.

## D-009 · Brillo por pantalla: DDC/CI con ddcutil y atenuación por software de respaldo
2026-10-14 · Ayoub pidió que, al conectar uno o más monitores, se detecten y cada uno tenga su brillo en el mismo menú.
Decisión: la interna por backlight (`brightnessctl`/logind) y las externas por **DDC/CI** con `ddcutil` (repos
oficiales; el paquete carga `i2c-dev` y da acceso con `uaccess`, sin root), detección solo al cambiar las pantallas y
escrituras coalescidas en cola. Si un monitor no tiene DDC/CI, atenuación por software (capa `ocarina-dim`), marcada
«SW». Descartado: `ddcci-driver-linux` (módulo DKMS del AUR que expondría los monitores como backlight; se rompe con
kernels nuevos, contra la regla 9) y la rampa de gamma (choca con la luz nocturna de wlsunset, que ya usa ese protocolo).
Por DDC/CI solo se escriben brillo y contraste (lo vigila el hook de guardia). Límite conocido: en las pantallas con
atenuación por software, capturas y grabaciones salen oscurecidas (es una capa); Iro y Yomu la ocultan al capturar.

## D-010 · Ideas propias de Claude integradas en el kit
2026-10-14 · Ayoub pidió que Claude añadiera también sus ideas. Se integran 13 (`docs/07-IDEAS.md`) en las fases que
les tocan, todas desactivables en Settei y con el mismo listón que el resto: cero coste en reposo, degradación si falta
un paquete y mantenibles por Mamori. Criterio de selección: que encajen con su equipo (OLED táctil, monitores externos),
su trabajo (administración de sistemas) y su gusto (Japón, anime). Se descartaron fondos animados, widgets de
escritorio, recordatorios de vista y sincronización en la nube (motivos en el mismo documento). Las que cambian solas
el aspecto (tema y brillo según la hora) vienen apagadas.

## D-011 · Escala 1,75 y tema por defecto Kurenai
2026-10-14 · Entrevista de la fase 0. Escala **1,75** (2880×1800 → 1645×1028 lógicos; los mockups usan esa geometría) y tema
por defecto **紅 Kurenai** (oscuro, apto OLED). Confirma D-001: el rojo `#E60033` es el acento en todos los temas.

## D-012 · Navegador: Google Chrome
2026-10-14 · Ayoub eligió Chrome (coincide con sus binds de referencia). `google-chrome` del AUR, PKGBUILD revisado
(mantenedor de Arch, `.deb` oficial de `dl.google.com` con sha512, sin scripts de instalación peligrosos) y guardado en
el repo local `[ocarina-aur]`. Firefox sigue instalado como alternativa. Wayland nativo: flags en `~/.config/chrome-flags.conf` (fase 1/2).

## D-013 · Huella para bloqueo, sudo y polkit
2026-10-14 · Lector Synaptics Prometheus (`06cb:00f9`) soportado por fprintd. Decisión: huella **en Kagi y en los diálogos
de autenticación (sudo/polkit)**, con la contraseña siempre como alternativa en paralelo. El registro de dedos lo hace
Ayoub (`fprintd-enroll`); la integración en PAM solo por `scripts/root/` (regla 10) y con pruebas en TTY antes.
Kagi usa su propia configuración PAM (`shell/pam/fingerprint.conf`), no la global.

## D-014 · Inicio de sesión: greetd + greeter propio
2026-10-14 · No hay gestor de pantalla: niri se lanza a mano desde tty1 **sin `niri-session`**, así que
`graphical-session.target` no se activa y ningún servicio de usuario ligado a la sesión arrancaría. Decisión: greeter
propio de OcarinaShell sobre **greetd** (fase 13, con prueba en TTY y respaldo `agreety`). Hasta entonces, la fase 1 hace
que la entrada por tty1 lance `niri-session` (o `niri --session`) para tener systemd y portales bien.

## D-015 · Teclado `es`, ubicación Casablanca
2026-10-14 · Distribución detectada `es` (pc105) confirmada; sin segunda distribución. Ubicación para el tiempo (Open-Meteo)
y la luz nocturna (wlsunset): **Casablanca** (33,57 N · 7,59 O).

## D-016 · Zona horaria Africa/Casablanca y formatos es_ES
2026-10-14 · El sistema estaba en Europe/Amsterdam con formatos `nl_NL`. Con permiso de Ayoub: `timedatectl
set-timezone Africa/Casablanca` y todo el locale a `es_ES.UTF-8` (copia en `/etc/locale.conf.ocarina-bak-2026-10-14`).
La sesión actual ve los valores viejos hasta volver a entrar.

## D-017 · Batería al 75–80 %, sonidos de interfaz activados
2026-10-14 · Umbrales de carga 75 % (inicio) / 80 % (fin) vía `charge_control_{start,end}_threshold` (`BAT0`), con
«carga completa por hoy» en Engawa (fase 4/10; escritura por el ayudante polkit). Sonidos de interfaz **activados**
(silencio en Shinobi y No molestar).

## D-018 · Arranque: tema según el tema activo, Limine a 3 s, LTS ya presente
2026-10-14 · Limine + Plymouth siguen la variante del tema (oscuro con Kurenai, claro con Kōhaku) y se regeneran al
cambiarlo. Tiempo de espera del menú de Limine: **3 s** (ahora 5). Ambos se aplican en la fase 13 por
`scripts/root/limine-tema.sh` (regla 10). El kernel `linux-cachyos-lts` ya estaba instalado y en el menú: no hace falta
`fase-00-lts.sh`.

## D-019 · paru: repo local `[ocarina-aur]` y SudoLoop solo interactivo
2026-10-14 · `LocalRepo` exige un repo declarado en `pacman.conf`: `[ocarina-aur]` en `/var/lib/repo/ocarina-aur`
(propiedad de ayoub, `SigLevel = PackageOptional DatabaseOptional`, último de la lista). Se llama `ocarina-aur` y no
`aur` para no chocar con el prefijo `aur/` de paru. `SudoLoop` hace `sudo -v`, que pide contraseña aunque exista el
drop-in NOPASSWD (la regla `(ALL) ALL` de wheel cuenta para `-v`): las ejecuciones no interactivas (Claude, Mamori)
usan `paru --nosudoloop`. `paru-bin` (AUR, roto tras actualizar libalpm) sustituido por `paru` del repo cachyos.
makepkg: CachyOS ya trae `-march=native -O3`, LTO y endurecimiento; nuestro fichero solo añade ccache, `BUILDDIR=/tmp/makepkg`
y zstd `-T0` sin `-9`, y conserva `!autodeps`. No repite CFLAGS para heredar las mejoras de CachyOS.

## D-020 · Fuentes de marca por script, formas japonesas por fontconfig
2026-10-14 · Las fuentes de Google (OFL/Apache) se instalan con `scripts/fonts.sh` (idempotente, comprueba que cada
descarga es TTF/OTF, escribe `SHA256SUMS`) en `~/.local/share/fonts/ocarinashell/`. `60-ocarina-jp.conf` antepone Noto CJK
JP para `lang=ja` y como respaldo CJK por defecto (fontconfig elegía KR).

## D-021 · Config de niri modular: semántica de fusión, teclado ES y preferencias
2026-10-14 · Verificado en el código del tag v26.04 (`niri-config/src/lib.rs`) y con `niri validate`:
- Repetir una sección en el MISMO fichero es error; entre ficheros, `layout`/`input`/`animations`/`cursor`/`overview`…
  se fusionan campo a campo y gana lo incluido después. Se sustituyen ENTEROS: `touchpad`, `trackpoint`, `mouse`,
  `touch`, `xkb`, cada animación (shader incluido), `preset-column-widths`, `default-column-width`, `struts`,
  `background-color`. Los `output "X"` NO se fusionan: gana el PRIMER bloque que coincide (sin aviso).
- Decisión: módulos a mano en `config/niri/ocarina/*.kdl` y, DESPUÉS, los generados `optional=true` en
  `~/.local/state/ocarinashell/niri/` (colors → outputs → shinobi → oni → fune → honban → user-rules → overrides),
  cada uno con un único dueño. `colors.kdl` puede escribir solo los campos de color (fusión por campo); `outputs.kdl`
  es el único con bloques `output`; `shinobi.kdl` usa `animations { off }` (se fusiona). En includes, `border {}`
  debe llevar `on`/`off` explícito. `niri validate` no compila GLSL: los shaders se comprueban en el journal.
- Teclado ES (niri usa el keysym sin Mayús de cada tecla): ancho ±10 % = `Mod+minus`/`Mod+plus` (alto con Mayús),
  meter/sacar en columna = `Mod+dead_grave`/`Mod+dead_acute` (teclas a la derecha de P y Ñ), chuleta = **Mod+?**
  (`Mod+Shift+apostrophe`; la propuesta inicial Mod+Mayús+- chocaba con «alto −10 %»), atajos nativos de niri =
  `Mod+Ctrl+apostrophe`, terminal desplegable = `Mod+masculine` (º), Alt+º = conmutador por aplicación.
- Ayoub: renombrar espacio en **Mod+Ctrl+Shift+R** (Ctrl+Shift+R vuelve al navegador), gestos del touchpad sí,
  sin esquinas activas, gestores de contraseñas ocultos en capturas y screencast (`block-out-from "screen-capture"`),
  portapapeles primario activo, touchpad con tap + scroll natural + `accel-speed 0.25`.

## D-022 · El botón de encendido sigue en manos de niri hasta la fase 6
2026-10-14 · logind tiene `HandlePowerKey=poweroff` y niri toma el inhibidor `handle-power-key`. Con
`input { disable-power-key-handling }` niri lo suelta y una pulsación apagaría el portátil al instante, sin Dengen
todavía. Se aplaza a la fase 6 junto con el bind `XF86PowerOff → ocarina power` (comentado en `binds.kdl`).

## D-023 · Motor de temas: destinos generados, recargas y «desde el fondo»
2026-10-14 · `bin/ocarina-theme` (Python stdlib, 355 líneas) + `templates/manifest.json` (13 destinos, un dueño cada uno).
- Lo generado nunca vive en el repo. Si la app admite includes, la config del repo incluye el fichero generado de
  `~/.local/state/ocarinashell/` (niri `colors.kdl`, Ghostty `config-file = ?~/…/theme/ghostty.conf` — Ghostty 1.3
  expande `~` y acepta `?` opcional, verificado —, fish `conf.d/ocarina-theme.fish`, Neovim `palette.lua`). Si no los
  admite, la plantilla ES la config completa y se escribe en su sitio (`starship.toml`, `fastfetch/config.jsonc`,
  `gtk-{3,4}.0/gtk.css`, `qt6ct`, `swaylock`, btop, yazi). bat usa `--theme=ansi` (sigue a la terminal).
- Todo o nada: se renderiza y valida (niri validate, ghostty +validate-config, fish -n, nvim luafile, json/toml) cada
  destino en un temporal junto a él; si algo falla no se toca nada. `--dry-run` trabaja en un directorio temporal.
  Ficheros previos sin la marca «OcarinaShell» → copia `.ocarina-bak-<fecha>` una vez. Permisos 0644.
- Recargas: niri vigila el include; **Ghostty recarga con SIGUSR2** (verificado en una instancia aislada: «received
  SIGUSR2, reloading configuration»; la man no lo documenta); GTK/Qt al abrir la app; gsettings (esquema, tema GTK,
  iconos, cursor 24, fuentes Geist/JetBrains Mono 11, `accent-color` más cercano); `papirus-folders` solo si cambia
  el color, con `sudo -n` y en segundo plano (si no hay sudo sin contraseña, avisa con el comando).
- «Desde el fondo»: matugen 4.2 `image --json hex`; su `primary` M3 en oscuro es pastel (`#ffb2bc`) y no sirve como
  sello 紅, así que el acento es `source_color` (el dominante real) con saturación ≥ 0,6 y luminosidad acotada por modo;
  `accent2` = `tertiary`. Base (superficies) = la del tema activo.
- Cursor por tema (Bibata Classic en oscuros, Ice en claros) vía niri `colors.kdl` + gsettings; se quitó `XCURSOR_*` de
  `environment.d` para no fijarlo. Medido: cambio completo Kurenai ↔ Kōhaku en **0,21–0,22 s** (criterio < 1,5 s).

## D-024 · Aislamiento de módulos con ModuleLoader y registro qs.*
2026-10-14 · `Loader` no puede alojar ventanas (no son Items). `components/ModuleLoader.qml` crea cada módulo con
`Qt.createComponent` + `createObject` (con `props` en la creación, p. ej. la pantalla) y, si su fichero o un módulo de
Quickshell que importa falla tras una actualización, solo ese módulo falta: el error va a `Health` (IPC `shell status`,
`ocarina doctor`) y admite `fallback` (la barra sin desenfoque). Quickshell solo registra los módulos `qs.<carpeta>` que
algún fichero importa de forma estática, así que `shell.qml` los importa (importar no compila los componentes normales:
el aislamiento se mantiene; **los singletons sí se compilan todos**, ver D-071). Probado: con Shima roto, la barra siguió viva y el fallo quedó en Health. Diagnóstico extra:
`OCARINA_DISABLE="Obi,Shima"` arranca sin esos módulos.

## D-025 · La isla vive en la superficie de la barra
2026-10-14 · niri apila las superficies de una misma capa por orden de creación (la primera queda encima): con la isla
en su propia ventana, quedaba debajo de la barra o dependía del orden de carga. Decisión: Shima va dentro de la ventana
de Obi en la pantalla principal (`Loader` aislado), con superficie más alta que la barra, `exclusiveZone` 40 y máscara de
entrada solo en barra e isla. Consecuencias: una ventana menos, orden fijo, el desenfoque se pide solo para la píldora
(Region con radio 14) y la sombra de barra e isla la dibuja QML (`SoftShadow`), por lo que `ocarina-obi` se excluye de la
regla de sombra de niri (que sombrearía todo el rectángulo transparente).

## D-026 · Sin shaders propios en la UI permanente; texto con pointSize
2026-10-14 · Medido: cada tipo de efecto con shader propio (`RectangularShadow`, `ClippingRectangle`, `Shape` con
`CurveRenderer`) añade ~20 MB de memoria del driver (radeonsi) por ventana. Las sombras y el brillo del hanko son
rectángulos concéntricos (`SoftShadow`), la portada redonda es una máscara del color de la isla y el anillo de batería
es un `Canvas` que solo repinta al cambiar. El `ShaderEffect` de tinta del fondo solo existe durante la transición.
Texto: `font.pixelSize` es entero en Qt; los componentes usan `size` en px lógicos → `pointSize = size × 0,75`
(Wayland, 96 ppp) para reproducir los 13,5/14,5 px del mockup. Las ventanas renderizan a la escala real 1,75
(fractional-scale-v1; la pantalla informa 2 pero la ventana 1,75).

## D-027 · Servicio con Restart=always y modo seguro al primer fallo
2026-10-14 · `systemctl kill` envía SIGTERM, que systemd trata como salida limpia: con `Restart=on-failure` la shell no
volvía. `Restart=always` (un `systemctl stop` explícito sigue sin reiniciarla): vuelve en 1,2 s (SIGTERM) / 1,4 s
(SIGKILL). Con la config rota, `qs` sale con 255 en 60 ms; systemd dispara `OnFailure=` ya en el primer fallo, así que el
modo seguro aparece en ~0,2 s y, en cuanto la shell normal arranca de nuevo, `Conflicts=` lo retira. Tras 4 fallos en
60 s la shell queda en *failed* y el modo seguro se queda (botón Reintentar = `reset-failed` + `start`).

## D-028 · Memoria: se mide por cgroup; RSS documentada
2026-10-14 · RSS de `qs` ≈ 346 MB, pero ~140 MB son ficheros compartidos (LLVM y Mesa, Qt, fuentes mapeadas) y la base
de Quickshell con una sola ventana ya es 159 MB. La memoria propia del servicio según systemd/cgroup es **216 MB**
(presupuesto 220). El fondo decodificado ocupa ~40 MB (dos copias de 2880×1800; `QSG_TRANSIENT_IMAGES` no las libera) y
el resto se reparte entre runtime QML, glifos y servicios. Probado sin mejora apreciable: `QSG_RENDER_LOOP=basic`,
`MALLOC_ARENA_MAX=2`. Queda para la fase 17 (perf-auditor): fondo a 0,75× + escalado por GPU si no se nota.

## D-029 · Paneles: anfitrión a pantalla completa por pantalla
2026-10-14 · Engawa, el centro de notificaciones y Koyomi viven en `PanelHost` (capa Top, transparente, a pantalla
completa) que solo existe mientras hay un panel abierto en esa pantalla (+ la animación de salida). Clic fuera o Esc
cierran; foco de teclado `OnDemand`; uno solo a la vez (`Panels`). Creado después de la barra, que sigue encima y
utilizable. Desenfoque del compositor solo bajo el panel (`PanelHostBlur` → respaldo `PanelHost` opaco al 94 %). Las
páginas de detalle se cargan con `Loader` (Wi-Fi/Bluetooth importan módulos sensibles) y, si fallan, muestran «No
disponible» en vez de un panel vacío. Gestos táctiles (solo `TouchScreen`): arrastrar desde el clúster o la isla abre
el panel siguiendo el dedo (40 % para abrir).

## D-030 · Fumi: notificaciones seguras y baratas
2026-10-14 · Servidor propio (`NotificationServer`) con acciones, imagen, markup e inline reply. Decisiones:
cuerpo saneado a b/i/u/a/br (sin `<img>`: un píxel remoto rastrearía, `file://` leería ficheros) y enlaces solo
http(s)/mailto; `bodyImagesSupported: false`. Con No molestar las no críticas solo asoman en la isla y se cierran
(su copia queda en el historial); tras una recarga, las anteriores no vuelven a sonar ni a mostrarse. Toasts con
vidrio al 94 % (una región de desenfoque para la pila desenfocaría también los huecos). Barra de tiempo redibujada
4 veces por segundo, no a 120 Hz. Historial (100) con id único por entrada. Limitación: niri 26.04 no expone en su IPC si
una ventana está en pantalla completa, así que el «peek» por pantalla completa queda pendiente de que lo haga.

## D-031 · Grabación como unidad transitoria y luz nocturna como servicio
2026-10-14 · `wf-recorder` se lanza con `systemd-run --user --unit=ocarina-rec`: una recarga o reinicio de la shell
no corta el mp4 (probado: grabación con recarga en medio, fichero válido). Parar = SIGINT a la unidad. La luz nocturna
es `ocarina-nightlight.service` (wlsunset) con argumentos en un fichero de entorno; los cambios se agrupan 400 ms, no se
reinicia si nada cambió y la temperatura se aplica al soltar el slider (evita parpadeos de gamma).

## D-032 · Sol, luna y tiempo en local o bajo demanda
2026-10-14 · Amanecer/atardecer (ecuación solar estándar) y fase lunar se calculan en local, una vez al día. El
tiempo (Open-Meteo) solo se pide al abrir Koyomi si la caché tiene más de 30 min (o si se muestra en la barra); nunca
en Shinobi. VPN: lista de conexiones de NetworkManager leída al abrir Engawa (nmcli), sin sondeo. Vatios de la batería
por eventos de UPower (`changeRate`), no leyendo `power_now`.

## D-033 · Torii: superficie precargada y latencia de mapeo de niri
2026-10-14 · Torii se crea al arrancar (una ventana por pantalla) y abrir es solo mapearla. Medido: nuestro código tarda
1 ms entre la orden y `visible`, pero el primer fotograma llega a los 23–26 ms porque niri tiene que crear y configurar
la superficie de capa. Para bajar de 1 fotograma habría que dejar una capa a pantalla completa siempre mapeada y
transparente, que niri compondría en cada fotograma (GPU y batería, regla 7). Se acepta ≈3 fotogramas a 120 Hz;
`qs ipc call launcher stats` da `lastOpenMs`. Filtro: 0,3–2 ms con 30 apps; `:a` con ~2.500 símbolos, 4 ms (top-30 sin
ordenar todo e `indexOf` nativo para el inicio de palabra). Coincidencias: siglas solo por inicio de palabra, palabras
clave contiguas y bonificación de subcadena (fuzzy.js).

## D-034 · Emoji en español generados, nunca descargados en tiempo de ejecución
2026-10-14 · Los nombres y palabras clave en español salen de Unicode CLDR 48 (`tools/emoji_es.py` →
`assets/data/emoji-es.json`, 120 KiB, licencia Unicode v3 citada en el JSON), con palabras japonesas añadidas (sakura,
onigiri…). El orden y el nombre en inglés vienen del paquete oficial `unicode-emoji` si está instalado; sin él, Torii
funciona igual con CLDR. Se elimina la descarga de `emoji-test.txt` en tiempo de ejecución (privacidad y sin red).

## D-035 · Herramientas de la fase 5 como paneles del host, no como ventanas
2026-10-14 · Kura, Techō, Mihari, Mado, la chuleta e Iro son tipos de `PanelHost`: existen solo mientras están abiertos
(cero coste en reposo, medido: 0,05 % de CPU y 203 MB al arrancar), heredan Esc/clic fuera y el desenfoque, y se
abre uno a la vez. Lo que necesita procesos vive con el panel: el muestreador de Mihari (`bin/ocarina-mihari`, Python
stdlib, ≈1 % de un núcleo, fórmulas de btop) muere al cerrarlo; Kura y Techō leen al abrir, sin sondeo.

## D-036 · Kura: privacidad del portapapeles
2026-10-14 · cliphist ya descarta lo marcado `CLIPBOARD_STATE=sensitive` (gestores de contraseñas). Además, Kura
enmascara lo que parece un secreto (sin espacios, 8–128 caracteres, 3 clases de carácter, no URL/ruta/correo) con
botón para mostrarlo, y no lo busca. Los fijados viven aparte (`data/kura/pins.json` + imágenes) y sobreviven a vaciar.
↵ copia; ⇧↵ copia y pega con `wtype` (Ctrl+V, o Ctrl+Shift+V si la ventana enfocada es una terminal).
`clipboard.dbPath` apunta a otra base de cliphist (pruebas sin tocar el historial real).

## D-037 · Mado escribe solo su include y valida antes de instalar
2026-10-14 · Las reglas van a `state/niri/user-rules.kdl` (incluido como opcional por config.kdl), un bloque por regla
con marcador `// mado:` para listarlas y borrarlas. `bin/ocarina-mado apply` valida el fichero candidato con
`niri validate -c` (un include solo con `window-rule` es una config válida) y solo entonces lo mueve atómicamente; si
niri lo rechaza no cambia nada y se muestra su mensaje. El app-id se escapa como regex en una cadena cruda `r#"…"#`.

## D-038 · Renombrar espacio dentro de la isla
2026-10-14 · Clic derecho en un espacio o Mod+Ctrl+Shift+R abren un campo dentro de Shima (modo «rename», prioridad
máxima). La barra pide el teclado en exclusiva solo durante la edición (`keyboardFocus` ligado a `Panels.renameId`) y
lo suelta al aplicar, cancelar o a los 60 s. Vacío = `UnsetWorkspaceName`. Los nombres latinos se muestran con la
fuente de interfaz en mayúscula; los kanji, con la japonesa.

## D-039 · Nombres de funciones IPC
2026-10-14 · El CLI `qs ipc call` no acepta argumentos para una función llamada `show` (choca con su subcomando):
la de Iro se llama `preview(hex)`. Regla para el futuro: no usar `show` ni `call` como nombres de función IPC con argumentos.

## D-040 · Kagi: PAM propio sin faillock y espera creciente en la interfaz
2026-10-14 · `system-auth` incluye `pam_faillock` y `/run/faillock/ayoub` es escribible por el usuario: cualquier
bloqueador que incluya `system-local-login` (también swaylock) cuenta fallos, y 3 erratas dejarían la cuenta bloqueada
10 min **también en la TTY de rescate**. Kagi usa `shell/pam/password.conf` = solo `auth required pam_unix.so` (con su
retardo de ~2 s por fallo) y la interfaz añade una espera tras 3 fallos (5, 15, 30 y 60 s como máximo; nunca un cierre).
La huella va en un `PamContext` paralelo (`fingerprint.conf`, `pam_fprintd`) solo si `fprintd-list` muestra dedos; la
contraseña funciona siempre. La conversación PAM tiene un máximo de 15 s. Polkit sigue con su PAM del sistema.

## D-041 · El botón de encendido abre Dengen (inhibidor de logind, sin tocar /etc)
2026-10-14 · niri convierte XF86PowerOff en «suspender» por código salvo con `disable-power-key-handling`, y entonces
logind (`HandlePowerKey=poweroff`) apagaría al instante. En vez de cambiar `logind.conf` (root), la unidad de usuario
`ocarina-powerkey.service` mantiene el inhibidor `handle-power-key` de logind; niri suelta la tecla y su bind llama a
`ocarina power`. Sin la shell, `ocarina power` suspende (lo que hacía niri); bloqueado, el botón suspende. Fuera de la
sesión (TTY, greeter) vuelve el comportamiento de logind. Mantener ~5 s sigue apagando por hardware.

## D-042 · Desbloqueo: el «fantasma» que se disuelve
2026-10-14 · Una superficie de `ext-session-lock` no puede dejar ver el escritorio, así que «disolverse» dentro de ella
solo funde a negro. Al acertar, la superficie de bloqueo hace el estallido de la ocarina; debajo se mapea una copia no
interactiva en la capa Overlay (`ocarina-kagi-ghost`, sin teclado ni entrada), se libera el bloqueo y es la copia la
que se funde 300 ms hacia el escritorio. Con movimiento reducido se libera sin copia. El host de Kagi se carga siempre
(un `WlSessionLock` inactivo no cuesta nada) para que el desbloqueo nunca dependa del orden de destrucción de un Loader.

## D-043 · Inactividad y Fukugen: detalles de la versión
2026-10-14 · `IdleMonitor` (Quickshell 0.3.2) arma el aviso de inactividad con el `timeout` que tiene al activarse y
no reacciona si cambia después: los monitores se recrean (Variants con clave) cuando cambia el perfil. La entrada de
`wtype` (teclado virtual) no cuenta como actividad en niri. Fukugen restaura por oleadas de espacio (los espacios de niri
son dinámicos: mover a «3» con el 2 vacío deja la ventana en el 2) y nunca lanza dos ventanas de la misma app a la vez
(se emparejan por app-id). Las terminales vuelven a la carpeta que fish pone en el título de Ghostty («RUTA - fish»).
La sesión se lee de `niri msg --json` solo al guardar, porque el modelo de la shell no sigue los cambios de layout.

## D-044 · Greeter: en la fase 13
2026-10-14 · Ayoub eligió greeter propio (D-014), pero greetd no está instalado y la fase 13 es la del arranque
(Plymouth → greeter sin costuras). En la fase 6 Kagi queda preparado para compartirse (`KagiView` es la composición
completa, independiente de `WlSessionLock`); greetd, `agreety` de respaldo y la prueba en TTY se hacen en la fase 13.

## D-045 · Kagi: épocas, swaylock con código de salida y nada de recargas bajo bloqueo
2026-10-14 · Tras la revisión de qml-reviewer. Cada bloqueo abre una «época»; un éxito (PAM, huella, fin del modo
prueba) solo libera el bloqueo de su propia época, así que nada del modo prueba ni de un bloqueo anterior puede abrir el
actual, y bloquear durante la disolución cancela el desbloqueo (el compositor sigue bloqueado). El estado sensible es
privado (`Lock` expone solo lectura; la UI llama a `leaveTest`, `testDissolved`, `ghostDone`, `reportSecure`). PAM vive en
`services/backends/PamBackend.qml`, creado en tiempo de ejecución: si `Quickshell.Services.Pam` cambia, el bloqueo es
swaylock. swaylock se lanza con `--ready-fd` (en pantalla = bloqueado) y solo su salida 0 cuenta como desbloqueo; si
muere, se relanza. La marca de `$XDG_RUNTIME_DIR` cuenta los arranques bajo bloqueo: el segundo seguido va directo a
swaylock (sin bucles de caídas). `Quickshell.watchFiles` está apagado mientras hay bloqueo y la recarga por IPC se niega.
El IPC de pruebas solo envía una contraseña errónea fija (`submitWrong`). Cancelar `pkexec` cuenta como fallo en
`faillock` (polkit usa el PAM del sistema): en pruebas no se cancela `pkexec` más de una vez cada 15 min.

## D-046 · Settei escribe niri por `overrides.kdl`; la velocidad de animación es una velocidad
2026-10-15 · `services/NiriConf.qml` es el único dueño de `~/.local/state/ocarinashell/niri/overrides.kdl` (el último
include, D-021): lo genera desde Settings (`input`, `windows`, `appearance.animSpeed`, `display.lidCloseToExternal`) y lo
instala `bin/ocarina-niri-gen` (`niri validate` + escritura atómica + `.prev`). niri 26.04 no deja apagar una bandera desde
un include posterior (`warp-mouse-to-focus false` → «unexpected argument»), así que `focus-follows-mouse` y
`warp-mouse-to-focus` salieron de `ocarina/input.kdl` y viven solo en el generado; `touchpad`, `trackpoint`, `mouse`,
`touch` y `xkb` se escriben siempre completos (se sustituyen enteros). La shell escribe el fichero al arrancar si difiere.
`appearance.animSpeed` pasa a ser una VELOCIDAD (Ajustes: 0 = sin animaciones, 0,5–2×): `Motion.scale = 1/velocidad` y niri
recibe `animations { slowdown 1/velocidad }` (u `off` con 0, movimiento reducido o «Animaciones de niri» apagado).
Desarrollo: un tipo QML nuevo dentro de un módulo existente no entra con la recarga en caliente («X is not a type»):
tras crear ficheros se reinicia `ocarinashell.service`.

## D-047 · Settei: ventana, Kabegami dentro y alcance
2026-10-15 · Settei es un `FloatingWindow` (xdg-toplevel) titulado «Ajustes de OcarinaShell» —el título que muestra la barra
del mockup— con su regla de niri por título (flotante, 1240×924, radio 18); se crea solo mientras está abierto. Páginas,
glifos y kanji de cabecera salen de `kanji-ui.json → settingsPages`; búsqueda sobre un índice generado de las páginas
(`tools/settei_index.py`, `--check` en pruebas). 壁紙 Kabegami es la página «Fondos» de Settei (Mod+Shift+W abre Ajustes ahí):
una sola ventana, el mismo sistema de componentes y nada vivo en reposo. Miniaturas con `bin/ocarina-thumbs` (vips en
paralelo, caché por ruta+mtime): 200 imágenes 2880×1800 en 1,45 s la primera vez, 0,05 s después. Decisiones de Ayoub:
**barra solo arriba** (estilos flotante/pegada/mínima con autoocultado sí, posición abajo no) y **Explorar con Wallhaven solo
SFW** (`purity=100` y filtro de nuevo en el cliente; nada se pide hasta abrir la pestaña; descarga a
`~/Imágenes/Fondos/wallhaven/`). «Tema según la hora» vive en Apariencia (donde se eligen los temas) y no en Pantalla. Las
páginas de Shinobi y Oni guardan ya sus opciones (las usarán las fases 10 y 11); Vídeo fluido, Windows, Snake y
Mantenimiento dejan su hueco con la fase en que llegan, sin controles falsos. Importar/exportar: rutas escritas a mano
(no hay selector de archivos sin GTK/portal en la shell); importar guarda antes una copia del settings.json actual.

## D-048 · 配置 Haichi: salidas por conector, prueba de 15 s, perfiles y presentar
2026-10-15 · Verificado en niri v26.04 (`OutputName::matches`, tty.rs): `outputs.kdl` se escribe por nombre de conector
(el modelo del panel lleva un espacio final y no tiene serie: «Make Model Serial» sería frágil); los perfiles se guardan
por huella `fabricante|modelo|serie` de cada pantalla, ordenadas, y al conectar ese conjunto se reescribe el fichero con
los conectores de ese momento. Cada cambio a mano es una prueba: se instala ya y, sin «Mantener» en 15 s, vuelve el texto
guardado al empezar (también si se desconecta un monitor durante la prueba). Seguridad: si todas las pantallas que quedan
están apagadas, se enciende el panel al momento. Tapa cerrada con monitor: lo hace niri solo (apaga eDP/LVDS/DSI);
«Con la tapa cerrada, todo al monitor» apagado escribe `debug { keep-laptop-panel-on-when-lid-is-closed }`. 発表 Happyō:
`wl-mirror --fullscreen-output` de la principal (niri no clona salidas) + No molestar + Despierto + avisos sin contenido;
wl-mirror no lee el teclado, así que una capa propia transparente sobre la copia recoge Esc. Brillo según la hora: dos
tramos (amanecer–atardecer de Koyomi); lo que mueves a mano se guarda para ese tramo y se aplica al cambiar de tramo (una
escritura por pantalla y transición). La gráfica de Energía usa `GetHistory` de UPower por D-Bus (los .dat son de root).

## D-049 · Fase 07 tras las revisiones: la prueba de pantallas no depende de la shell
2026-10-15 · qml-reviewer, visual-qa y perf-auditor. (1) La prueba de 15 s guarda el `outputs.kdl` bueno como
`outputs.kdl.trial` y arma un temporizador transitorio de systemd (`ocarina-haichi-revert`, 17 s, AccuracySec=1s) que lo
restaura aunque la shell muera o se recargue (probado con SIGKILL a mitad); «Mantener» lo desarma; al arrancar se restaura
cualquier prueba huérfana. Sin fichero previo, la copia buena es un `outputs.kdl` vacío (= valores de niri). (2) Las salidas
se releen tras cada escritura, con `ConfigLoaded` y con eventos DRM de `udevadm monitor` (un monitor configurado `off` no crea
wl_output); la garantía «nunca todo apagado» se comprueba en cada cambio real de salidas, también tras revertir. (3) Los
ficheros generados solo pueden contener sus propios nodos: `render()` usa lista blanca de transformaciones y números finitos y
`ocarina-niri-gen` rechaza `binds`, `spawn`, `include`, reglas… (un settings.json importado no puede colar órdenes). (4) Un
perfil automático que apaga el panel se aplica como prueba visible, y toda prueba iniciada fuera de Ajustes → Pantalla pregunta
«Mantener / Revertir» con una notificación. (5) Settings agrupa las escrituras (250 ms) y migra a la versión 2
(`animSpeed` multiplicador → velocidad); claves `__proto__`/`constructor` rechazadas. (6) Memoria: sin fuga (repetir no
crece) pero meseta de ~60 MB tras el primer uso de Ajustes (caché de Qt); `MALLOC_ARENA_MAX=2` no ayuda → revisión del
presupuesto de memoria en la fase 17. (7) Los tamaños de letra de medio píxel (13,5 · 12,5…) se pintan redondeados en toda la
shell (no es el hinting): pasada tipográfica en la fase 17.

## D-050 · 広場 Hiroba, isla v2 y barra en islas (petición de Ayoub tras la fase 07)
2026-10-16 · Ayoub pidió un panel «nivel dios» al pulsar la isla, más anime, una isla y una barra que dejen con la boca
abierta, todo optimizado y configurable. Mockups 14–17 aprobados («dale»). 広場 Hiroba sustituye a Koyomi: es la isla
creciendo (un rectángulo de tinta que va del rectángulo REAL de la isla —publicado por la barra— al panel con un muelle, o
sigue al dedo) y vuelve a ella en tres tiempos (contenido, tinta, fundido cruzado con la isla); vive en la pantalla de la isla.
Sin capas ni shaders: `ClippingRectangle` se descartó (textura viva de todo el panel en cada fotograma, ~20 MB de driver); las
esquinas redondas salen de formas redondeadas y de recortes rectangulares metidos 0,3·radio. Coste medido: 0,50 % de CPU
abierto (los anillos no animan entre muestras: antes 5,9 %), 0,00 % cerrado; el muestreador (`ocarina-mihari --light`) solo
existe con la fila del equipo en pantalla. Los efectos (líneas de velocidad, pétalos, destello de la isla) son de un disparo;
el vinilo gira solo mientras suena y se ve. Todo en Ajustes → Barra e isla (estilo anime y cada efecto, secciones, sello).
La barra pasa a «islas» por defecto (sin fondo, dos cápsulas de vidrio); Hogo desplaza ahora la cápsula/isla ENTERA con su
contenido (antes movía solo los iconos dentro de un vidrio quieto: se veían descentrados).

## D-051 · Fase 08: terminal (Ghostty 1.3.1, fish 4.9, starship 1.26)
2026-10-16. (1) **Terminal desplegable emulado**: en Linux, Ghostty 1.3 solo alterna su quick terminal desde un atajo global
(portal GlobalShortcuts); niri no lo implementa y la acción no existe por D-Bus (`org.gtk.Actions` solo expone new-window,
present-surface…). `ocarina-quickterm` usa una ventana de Ghostty con título fijo «端 Terminal desplegable», flotante arriba
por regla de niri; esconderla = moverla al espacio vacío del final de su monitor (nunca desplaza los demás); Obi oculta ese
espacio (`Niri.stashWs`) y numera por posición. Si Ghostty añade la acción por D-Bus, se cambia a la nativa. (2) **Saludo de
fish**: CachyOS redefine `fish_greeting` (fastfetch) en `config.fish`, después de `conf.d`; el único sitio que gana es el
final de `config.fish`: `scripts/install.sh` añade un bloque marcado de 3 líneas (y `--uninstall` lo quita). (3) **pure**
(prompt por defecto de CachyOS) se sombrea con `conf.d/pure.fish` y `_pure_init.fish` homónimos (mecanismo estándar de fish:
el de usuario gana al de vendor): −6 ms por shell y sin línea en blanco extra. `done.fish` de CachyOS sigue (≈5 ms, llama a
xprop) pero no duplica avisos: el foco X no cambia en niri; los avisos de fin de comando los da Ghostty
(`notify-on-command-finish = unfocused`, 10 s). (4) **Caché diaria** (`ocarina-daily`): saludo por hora, proverbio (mismo
índice que Kagi), 節気 y 候; fish la *sourcea* (sin procesos), starship lee `$OCARINA_SEKKI` con `env_var`. zoxide y starship
se inicializan desde scripts cacheados que se regeneran si el binario cambia. Resultado: `fish -i -c exit` 31,7 ms, prompt
7,6 ms en un repo git, ventana nueva 67,5 ms. (5) **Estela de tinta**: shader propio con los uniforms de cursor de 1.3; el
include `ghostty-effects.conf` lo escribe solo `ocarina-theme effects on|off` (valida y recarga solo si cambia) y lo decide
`TermFx`: enchufado ∧ ¬Shinobi ∧ movimiento activo ∧ ajuste. Coste de CPU no medible (el bucle va en el hilo de render).
(6) **Tamaño de letra**: 10 pt + `adjust-cell-height 14%` = 13 px/1,5 del mockup (elegido por Ayoub frente a 11,5 pt).
(7) **btop** se enlaza desde el repo: lo que se cambie en su menú queda en `config/btop/btop.conf`. **lazygit** de extra,
tema por plantilla. **alacritty** desinstalado a petición de Ayoub; `xdg-terminals.list` → Ghostty.

## D-052 · 本番 Honban: reglas de producción generadas y validadas
2026-10-16. `ocarina-honban` lee solo los nombres `Host` (vía `ocarina-ssh-hosts`) + `ssh.prodHosts` y escribe
`honban-rules.kdl` a través de `ocarina-niri-gen` (validado con `niri validate`; en ese include solo se permiten
`window-rule` y se rechazan `spawn`, `include`, `open-on-*`, `block-out-from`…). Los nombres fuera de `[A-Za-z0-9._@-]`
nunca entran en una regex. Producción = anillo sólido (gradiente de un solo color, porque el tema define `active-gradient` y
un `active-color` suelto no lo taparía) + borde sólido de 3 px también sin foco (la spec decía 2 px; visual-qa: a 2 px con
alfa no se leía «producción» sin foco), en el color `error` del tema; sello 本番 en Obi (en `accent`, legible a 11 px);
aviso discreto la primera conexión del día (`ocarina ssh` mantiene la regla al día también sin la shell).

## D-053 · 広場 Hiroba, peticiones de Ayoub del 16/10
Sin velo oscuro detrás; un poco más pequeño (1056×616, anchos de tarjeta en tokens); apertura 240 ms y cierre ≈250 ms con
curva decelerada (sin muelle: no se ve la tinta vacía); **se abre bajo la barra** (Theme.island.hirobaTop = 56) y **la barra y
la isla se quedan** visibles y usables (tocar la isla lo cierra): la tinta sale como una píldora del tamaño de la isla justo
debajo. Engawa gana la fila de luz del teclado (UPower KbdBacklight, Apagada/Baja/Alta; Fn+Espacio se sigue solo con Engawa
abierto). Supersede las partes de D-050 sobre el morph desde el rectángulo de la isla y la barra que se apartaba.

## D-054 · Fase 09: Neovim 0.12.6, servidores y herramientas de los repos oficiales
2026-10-16. Neovim 0.12.6: LSP con la API nativa (`vim.lsp.config`/`vim.lsp.enable`; nvim-lspconfig solo aporta las
definiciones de `lsp/*.lua`), `winborder`, nvim-treesitter rama **main** (la de 0.12: instala parsers con tree-sitter-cli;
resaltado, pliegues e indentación se arrancan con la API del núcleo). lazy.nvim sigue (carga diferida) y fija versiones con
`config/nvim/lazy-lock.json` en git. **Servidores y formateadores de pacman, no de mason** (`scripts/root/fase-09.sh`):
pacman y Mamori los actualizan con el sistema y no se baja nada de GitHub; mason queda solo bajo demanda (`:Mason`,
`PATH=append`). Sustituciones por disponibilidad en repos: `pyright` (no basedpyright), `ts_ls` (no vtsls), `prettier`
(no prettierd). qmlls es `qmlls6` (qt6-declarative) y lee `shell/.qmlls.ini`, que escribe Quickshell (en .gitignore).
Un servidor solo se activa si su binario existe. Formatear al guardar está **apagado** por defecto (el repo tiene su estilo;
qmlformat reescribiría el QML entero): `<leader>cf` a mano, `<leader>uf` lo activa en la sesión. Lua con `stylua.toml`.

## D-055 · Neovim y la shell: `theme/effects.json` y una sola estela
La paleta está en `~/.local/state/ocarinashell/theme/palette.lua` (la spec decía `nvim/palette.lua`; el motor de temas ya la
escribía ahí desde la fase 2). Neovim vigila **el directorio** `theme/` con `vim.uv.new_fs_event` (el motor reemplaza los
ficheros con un rename atómico, que dejaría huérfano un watch sobre el fichero) y reaplica el colorscheme o los efectos.
En vez de leer `~/.local/state/ocarinashell/mode` (lo escribiría Modes en la fase 10), Neovim lee `theme/effects.json`
`{cursor, motion}`, que escribe `ocarina-theme effects … --motion …` desde `TermFx` con la misma decisión que Ghostty:
`cursor` = CA + fuera de 忍 Shinobi + movimiento; `motion` = fuera de Shinobi + movimiento. Así Shinobi, la batería y el
movimiento reducido llegan a Neovim sin que la fase 10 toque nada aquí. **smear-cursor nunca dentro de Ghostty**: su shader
墨 de la fase 8 ya dibuja la estela también en Neovim y dos estelas se pelean; smear-cursor queda para otros terminales.
`motion=false` apaga `vim.g.snacks_animate` y `Snacks.scroll`.

## D-056 · Neovim: barras y dashboard
Statusline propia (sin lualine) global (`laststatus=3`); el corte (`%<`) cae en la ruta, nunca en el bloque de modo; el
nombre del servidor LSP solo con ≥ 110 columnas. Diagnósticos con kanji 誤 警 報 示 (señales y barra) y texto virtual solo
en la línea del cursor (el mockup enseña el código limpio). Las **migas de pan** (símbolos LSP, una petición por cambio, no
por movimiento) van a la derecha de la **tabline**, junto al kanji del tema, en vez de en un winbar: el mockup 01 tiene una
sola barra arriba; si no caben junto a las pestañas, se ocultan. Dashboard de snacks: la ocarina PNG real por protocolo
kitty (decidido por entorno —Ghostty/kitty, sin tmux ni SSH—: la sonda de snacks bloquea el arranque hasta 1,5 s) y, si no,
braille generado por `tools/nvim_logo.py`; proverbio y 候 de `~/.cache/ocarinashell/daily.json` (nuevo en `ocarina-daily`).
QML: la query de injections de qmljs hereda todo ecma (plantillas html/sql/graphql/css que en QML no existen) y costaba
57 ms al abrir el primer `.qml`; se sustituye con `vim.treesitter.query.set` por una de solo regex (un fichero en
`queries/` no basta: Neovim acumula los `inherits` de todos los ficheros). `:checkhealth ocarina` comprueba que compila.

## D-057 · `ocarina-nvim-health`: salud y actualizaciones de plugins para Mamori
`ocarina-nvim-health` (headless): arranque sin errores, mediana de 7 arranques < 30 ms, `:checkhealth` sin errores (tras
`UIEnter`, como una sesión real) y LSP de Lua y QML conectados. Errores ajenos ignorados y listados: herramientas opcionales
de snacks.image (LaTeX, Mermaid) y «sin protocolo kitty» en headless. `update` hace `Lazy! sync` en un **sandbox** (copia de
`config/nvim` + copia reflink de los plugins, XDG aparte: el Neovim real no se toca) y repite las pruebas allí; `--apply`
confirma el nuevo `lazy-lock.json` en una rama `mamori/nvim-<fecha>` (worktree temporal), hace fast-forward, `Lazy! restore`
y vuelve a probar; si falla, `git revert` + `Lazy! restore`. Probado el 16/10 con mini.ai retrasado a propósito en una
rama de prueba (sandbox → rama → fusión → restore → sano).

## D-058 · Fase 09 tras visual-qa
Ghostty pasa a `window-padding-color = background` (supersede la línea de D-051): con aplicaciones de pantalla completa
como Neovim, `extend` siempre copia la celda vecina al relleno —la pestaña activa subía hasta el borde y el bloque rojo del
modo se ensanchaba— y el fondo es el mismo, así que no se pierde nada. QML: una extensión `after/queries/qmljs/
highlights.scm` (`;extends`) pinta en asagi (t6, `@module`) los singletons y tipos adjuntos usados como objeto (`Theme.`,
`Niri.`, `Qt.`) y los ids (`id: root`, `root.`, `parent.`), que ecma ponía en oro; los miembros tras el punto van en el
color del texto (el azul queda para los nombres de las asignaciones). Rojo con mesura: números en t13 (el rojo es foco:
línea actual, modo, cursor), título y teclas del dashboard en texto/tenue (solo el kanji de cada fila en el acento), 候 en
tenue. Pestañas con un solo glifo de documento y un espacio por lado; migas solo de los dos niveles interiores; margen con
`statuscolumn` (número y después la señal) y sin banda de línea actual; avisos en el oro de la barra (t3); barra de
pestañas de los temas claros hacia surface3; cursor oculto en el dashboard (`guicursor` con `blend=100`).

## D-059 · Fase 10: 忍 Shinobi
- **Ayudante root `ocarina-powerctl`** (bash, lista blanca, `/usr/local/libexec`, polkit `org.ocarinashell.powerctl` solo
  `allow_active`): `boost`, `epp`, `gpu auto|low|high`, `charge`, `wifi-ps [iface]`, `status` (sin root). `pkexec` desde el
  servicio de usuario funciona sin contraseña (polkit 127 usa la sesión gráfica del usuario). `install-system.sh` ahora
  hace `daemon-reload` y habilita las unidades con `[Install]` (nunca las arranca).
- **Turbo**: power-profiles-daemon 0.30 ya escribe `policy*/boost=0` en «ahorro» con amd-pstate. Escribir el `boost`
  global a 0 hacía fallar después el cambio de perfil de PPD (`Argumento inválido` en `policy11/boost`), así que el
  ayudante escribe por política y Shinobi solo lo llama si el turbo sigue activo tras el perfil; al salir, turbo antes
  que perfil.
- **Capas, no ajustes**: Shinobi no toca `settings.json` salvo lo suyo. Tema: `ThemeCtl.hold/release` (lo que se elija
  durante el modo se guarda y se aplica al salir; el acento «del fondo» se recalcula). Hz: `Displays.refreshCap` se aplica
  en `render()`, así que ninguna recarga ni perfil devuelve los 120 Hz, y los perfiles guardan el modo real. Brillo:
  topes declarativos en `Brightness` y, en el snapshot, solo las pantallas que el tope recorta (`{was, cap}`), devueltas
  solo si siguen en el tope (lo que Ayoub cambie a mano se respeta), también bajo la atenuación por inactividad.
- **Snapshot** en `~/.local/state/ocarinashell/shinobi-prev.json` con lo que Shinobi cambió; sobrevive a recargas y
  reinicios (al arrancar se reaplica lo que vive en el kernel). Peticiones durante una transición se encolan (gana la
  última) y una vigilancia de 15 s cierra una transición atascada (`Health`).
- **Medidas** (`docs/ENERGIA.md`): GPU al mínimo se queda (−0,2 W); VRR en Shinobi no (a 60 Hz no ahorra nada medible); la
  Ethernet en runtime PM `auto` no se aplica (ruido); PSR no se fuerza (el driver lo deja apagado en este panel y habría
  que tocar la línea del kernel). VRR siempre a 120 Hz en uso normal ahorró 0,5 W: queda como propuesta para Ayoub.
- Ajustes por defecto con Ayoub: preguntar al umbral (`power.autoShinobiAsk`), Bluetooth apagado salvo audio
  (`shinobi.bluetoothKeepAudio`), tope 35 %, monitores externos sin tope (100 = sin tope). Esquema de ajustes 3.
- Ghostty `app-notifications = no-config-reload`: la shell recarga Ghostty sola (tema, Shinobi) y cada recarga sacaba un
  aviso en cada ventana.

## D-060 · Fase 11 (A): 鬼 Oni
- **Un único estado** `normal | shinobi | oni` en `Modes` con `request(modo)`: pedir un modo con el otro activo sale
  primero (su snapshot restaurado) y entra después (la petición queda en `want` hasta que acaba la salida). Snapshot por
  modo (`shinobi-prev.json`, `oni-prev.json`), reanudación al arrancar con los dos ficheros; un Oni que arrancó GameMode
  se cierra al arrancar si `gamemoded -s` ya no ve juegos. `Modes.quiet` (cualquier modo) pausa tiempo, segundos y
  rotación de fondos; lo propio de Shinobi (tema negro, silencio, sello 忍) sigue en `Modes.shinobi`.
- **Qué hace Oni, decidido midiendo** (`docs/JUEGOS.md`, vkmark sin ventana + carga de CPU): PPD «rendimiento» (+20 %:
  Lenovo sube el límite de potencia) y **scx_lavd en modo juego** vía scx_loader (+3…10 % gastando menos); GPU `auto`
  (`high` no gana nada); «prioridad a la GPU» (sin turbo, +9 % en carga GPU) como opción apagada; Wi-Fi sin ahorro;
  máximo de Hz + VRR on-demand en la salida y `oni.kdl` con VRR por ventana (`gamescope`, `steam_app_*`,
  `steam_proton`); No molestar por enlace (`Notifs.oniDnd`, no toca el ajuste; el propio toast «覚醒» pasa); unidades en
  pausa (`ocarina-cliphist-img`; luz nocturna opcional). En CachyOS, PPD 0.30 trae integración con scx_loader: cambia el
  *modo* del planificador que esté corriendo, pero **no arranca ninguno** (no había ninguno activo): Oni lo arranca y lo para.
- `pp_power_profile_mode` no existe en la 860M (kernel 7.2): no se usa. El autosuspend USB de los HID ya está en `on`
  por defecto (nada que cambiar).
- **Ayudante** `ocarina-powerctl`: `fan auto|full` (solo con CA y con `thinkpad_acpi fan_control=1`, que pone
  `scripts/root/fase-11.sh` en modprobe.d + `limine-mkinitcpio`, porque el módulo se carga desde el initramfs) y
  `scx lavd|stop` (scx_loader exige `auth_admin_keep`; el ayudante llama como root). `status` añade `fan`, `scx`,
  `scxAvailable`.
- **GameMode** (`config/gamemode.ini`): solo avisa (`[custom] start/end` → `ocarina oni auto-on|auto-off`). Su cambio de
  governor se neutraliza (`powersave` en todo): con amd-pstate activo, «performance» fija EPP y se peleaba con PPD
  (medido: dejaba `epp=performance` al salir). `[gpu]` no se admite en el fichero de usuario. auto-off solo deshace un
  Oni que abrió auto-on. Con batería: preguntar (por defecto), no activar o activar; sale solo por debajo del 20 %.
- **Guardias**: Tctl ≥ 97 °C cinco muestras seguidas (10 s, `Sensors` cada 2 s solo en Oni) o batería baja → sale y avisa
  (crítico). Al desenchufar con el ventilador al máximo, vuelve a `auto`.
- **鬼神 Kishin descartado** por Ayoub: siempre los límites de fábrica (ryzenadj no se instala).
- **gamescope**: plantilla por defecto mitad exacta + FSR, anidado con `--backend sdl --force-grab-cursor` (wiki de niri)
  y `--mangoapp`. Steam: `STEAM_FORCE_DESKTOPUI_SCALING=1.75` (xwayland-satellite da píxeles nativos).
- **MangoHud** como plantilla del motor de temas (acento del tema en las etiquetas 速/脳/絵, oro fijo de Oni en la gráfica).
- **Fumi**: Quickshell 0.3.2 entrega `expireTimeout` en milisegundos (un `-t 4000` duraba 66 min con el `× 1000`
  anterior: ningún toast con tiempo propio caducaba). Los toasts de modo se cierran al salir del modo.
- Esquema de ajustes 4 (migración: `gpuLevel high → auto`, `onBattery → batteryAuto`, preset `auto → fsr`, `funePause`).
  `onBattery:false` («solo enchufado») pasa a «preguntar» y no a «no activar»: eran opciones guardadas sin efecto hasta
  esta fase y nadie las eligió; preguntar es el valor por defecto de la spec.
- Revisión qml-reviewer (28 puntos) aplicada: pasos de una transición vieja ya no cuentan ni aplican en la siguiente
  (época por proceso), una entrada cuyo sondeo se cuelga no queda «on» sin aplicar, `off`/`auto-off` cancelan una
  entrada en cola, el paso Shinobi⇄Oni no despierta la shell a medias (`chaining`), peticiones antes de leer los
  snapshots se encolan, dos snapshots activos se resuelven por fecha, Oni no entra por debajo del umbral de batería,
  el No molestar de Oni se puede levantar desde el interruptor, sin 覚醒 a pantalla completa sobre un juego que abre
  GameMode (solo el sello), animadores en el hilo de render.

## D-061 · Fase 11 (B): 滑 Nameraka
- **Arquitectura tal y como §19**, con lo medido: ayudante `native/nameraka` (C++20 + meson, solo dependencias oficiales,
  `-Werror` en desarrollo, pruebas del núcleo en `tests/test_core.cpp`), `daemon` activado por socket (sale a los 60 s
  apagado: 0 procesos en reposo), `view` hijo con el entorno de lsfg-vk propio (`LSFGVK_CONFIG` + `LSFGVK_PROFILE`, el
  `conf.toml` de los juegos intacto), `self-test` oneshot al iniciar sesión que escribe `selftest.json`.
- **Captura**: ScreenCast de niri v4 por sd-bus (una conexión); **enlace PipeWire propio** con `link-factory` (WirePlumber
  no enlaza con el nodo de niri); solo DMA-BUF con modificador explícito, importado una vez por búfer, **copia 1:1** a la
  swapchain (recorte del medio píxel 2881×1801 → 2880×1800). Las sesiones huérfanas (niri no las cierra) se apuntan en
  `nameraka/session` y se cierran al arrancar. El daemon nunca roba un socket vivo.
- **La capa no es opaca** (`PRE_MULTIPLIED`): con una opaca niri frena las frame callbacks de la ventana tapada y Chrome
  dejaba de pintar (4 fps). Coste asumido: niri compone también la ventana de debajo.
- **Ritmo**: lsfg-vk 2.0 solo tiene `vsync`; medido 30 × 4 = **120,0 fps, 0–0,17 % tarde** (mpv y Chrome). La tabla del
  multiplicador efectivo de §19 se confirma (pruebas del núcleo). **«A medida» por defecto**. Base por llegada de
  fotogramas (media del 50 % central de 32 intervalos; 29,97/30 se resuelve a favor de la cadencia entera salvo medida clara).
- **Calidad**: calibración real (`ocarina nameraka calibrate`, 24 combinaciones en ~75 s, huella de la DLL) con margen 1,3×;
  sin calibrar, valores medidos en la 860M (2880×1800 ×4 → flujo 0,5). Guardias por escalones (GPU ≥ 95 % 3 s, fotogramas
  perdidos 3 s, Tctl ≥ 95 °C 10 s): flujo −0,15 ×2 → modo rendimiento → paso directo con aviso; «ajustado» en la tarjeta.
  Batería `eco` (rendimiento + flujo −25 %). En Oni, sin `eco`.
- **Estados**: los de §19; el foco de las superficies de la shell no cuenta; pausa ⇄ activo en 29–70 ms; vigilante por latido
  (250 ms; fuera a 750 ms sin latido, o si llegan fotogramas y no se presenta nada en 1 s): 680 ms medidos.
- **Capas**: OSD/«armando» en una superficie propia en `overlay`; **Engawa (PanelHost) y Fumi pasan a `overlay` solo mientras
  Fluido está encendido** (en `top` la barra sigue respondiendo con un panel abierto) y se **remapean** (visible false→true)
  cuando el presentador aparece o cuando se abre un panel / llega un aviso, porque en una misma capa queda encima lo último
  mapeado. Dengen ya estaba en `overlay` y se crea al abrirse.
- **Audio**: `pw-loopback --delay` (latencia declarada 0, así que sirve), flujos por `target.object` y vuelta borrando el
  metadato (WirePlumber no guarda destino). `avSync` **apagado por defecto** hasta la prueba de Ayoub (`scripts/fluido-av-test.sh`).
- **«A medida» con otro modo de pantalla**: con un objetivo divisor de los Hz (60 en 120) la shell pide ese modo a `Displays`
  mientras dura y lo devuelve (nunca en Oni).
- **Automático**: pantalla completa + reproductor MPRIS de la misma app en «Playing»; apagado por defecto; uno arrancado así se
  apaga (no se arma) al salir de pantalla completa.
- **Motor IA: no pasa la puerta** (RIFE-ncnn de 2022 incompatible con ncnn 2026; ver FLUIDO.md). La UI lo muestra
  deshabilitado; `vrrWhileActive` no se ofrece (solo tendría sentido con IA).
- Diferencias con §19: sin `SPA_META_VideoDamage` en niri (la deduplicación por firma no hace falta: niri solo entrega
  fotogramas con daño); estadísticas solo con la página de Engawa o el OSD visibles.
- **Revisiones** (qml-reviewer 20 puntos, perf-auditor 5 + menores, visual-qa 18) aplicadas en lo esencial: el daemon se para
  si su cliente se va sin `stop` y limpia las pausas al apagar; la shell empareja sus `stop` (on/off rápido sin quedarse
  huérfano), reenvía bloqueo/pantalla al conectar, manda cualquier cambio de ajustes desde un único sitio, no reenciende
  «Automático» en la misma ventana tras apagarlo y usa el layout vivo de la ventana enfocada (Niri lo guarda aparte) con el
  mismo criterio que el daemon; el tope de Hz de «A medida» usa el máximo nativo del panel, solo con vídeo (no armando),
  sobrevive a un reinicio de la shell y cede ante Shinobi/Oni (`Nameraka.dropRefresh()` antes de que Modes tome Displays);
  Engawa/Fumi suben a `overlay` solo cuando el presentador ya está en pantalla (`presenting`); atajos con `repeat=false`.
  Ayudante: al apagar se quita la capa antes de desmontar la captura; en pausa > 5 s la captura se suspende
  (`pw_stream_set_active`) y vuelve en ~56 ms; guardia de GPU con media de 5 s ≥ 97 % (las puntas sueltas bajaban la calidad
  a 80 % de media); bucles con menos despertares (daemon 1 s apagado, presentador solo stdin cada 250 ms).
- Pendiente: avSync escanea `pw-dump` cada 2 s (solo con avSync, apagado por defecto) → registro de PipeWire por eventos en
  la fase 17; degradado de la tarjeta a 135° (Qt Quick no lo tiene); animación de entrada del OSD.


## D-062 · Fase 12: 船 Fune — Podman sin root, Windows 11 Pro 4/6, lanzador propio sobre los datos de WinApps
2026-10-17 · Entrevista con Ayoub: **Podman sin root** (no Docker: el grupo `docker` equivale a root), **Windows 11 Pro ·
4 vCPU · 6 GB · disco de 96 GB** (23 GB útiles en el equipo: 8 GB son de la iGPU), Windows ve **todo `~/`** (solo mientras
hay una app conectada: redirección RDP `+home-drive`, sin Samba de dockur), sin apps concretas todavía (pruebas: Explorador/
Bloc de notas por RemoteApp, Notepad++ con Wine, Microsoft 365 web).
- **Contenedor**: `dockur/windows` fijado (6.06) en `config/winapps/compose.yaml` (la ruta fija de WinApps), solo
  `127.0.0.1`, `restart: "no"`, `SAMBA=N`, disco en un subvolumen Btrfs propio con `chattr +C` (NOCOW) fuera de snapper.
  `podman-compose` ignora `stop_grace_period` → `--podman-run-args=--stop-timeout=120`; y como CachyOS pone
  `DefaultTimeoutStopSec=10s`, un drop-in `libpod-.scope.d` da 110 s al scope del contenedor al apagar el equipo (si no,
  Windows recibiría SIGKILL a mitad del apagado ACPI). Módulos NAT (`modules-load.d/ocarina-fune.conf`): el kernel no los
  carga desde un namespace sin privilegios y dockur hace NAT con iptables-nft dentro del contenedor.
- **Contraseña**: aleatoria (24 car.) en gnome-keyring (`secret-tool`, service `ocarinashell-fune`); dockur no tiene
  `*_FILE`, así que solo viaja como variable al crear el contenedor; FreeRDP la pide por `FREERDP_ASKPASS` (nunca en la
  línea de órdenes ni en ficheros nuestros). Límite asumido: dockur la escribe en el `unattend.xml` dentro del disco de la VM.
- **WinApps solo como datos** (commit fijado en `~/.local/share/ocarinashell/winapps-src`): su `.reg` de RemoteApp y tareas
  OEM, su base de apps conocidas (MIME, iconos) y `ExtractPrograms.ps1`. **El lanzador es nuestro** (`bin/ocarina-fune`)
  porque el de WinApps pone `/scale:` después de `RDP_FLAGS` (máximo 180 %, nunca el 175 % exacto del panel), su pausa
  automática sondea procesos cada pocos segundos y avisa con `notify-send` en inglés. El nuestro: escala de la salida
  enfocada (`/scale-desktop:175`), `/wm-class:fune-<app>` (una sola regla de niri para el anillo asagi), mapeo de rutas a
  `\\tsclient\home`, comprobación RDP real (X.224, porque pasta acepta TCP mucho antes que Windows) y la isla.
- **Política en la shell, por eventos**: ventanas RemoteApp contadas con los eventos de niri; `podman events` solo con la VM
  encendida o en pausa (apagada, 0 procesos); pausa tras 10 min sin ventanas, apagado tras 30 min en pausa; Shinobi pausa al
  momento y apaga a los 5 min; Oni pausa sin apps de Windows. La última palabra la tiene el CLI (`--auto`: nunca durante la
  instalación, el mantenimiento o con ventanas abiertas).
- Ajustes de Windows en el OEM (primer inicio de sesión, máquina recién creada sin datos de Ayoub): 175 %, efectos al mínimo
  con ClearType, sin apps de inicio ni en segundo plano, SysMain fuera, horas activas 07–01 sin reinicio con sesión abierta,
  sin suspensión/hibernación, Africa/Casablanca, teclado español.
- Descartado: WinBoat (Electron beta sin CLI, bugs abiertos en niri), Docker (grupo root-equivalente y demonio), compartir
  `~/` por Samba (Windows lo vería siempre que la VM corre, no solo con una app abierta).
- **Ajustes tras las pruebas reales (mismo día):**
  - dockur 6.06 con Podman usa la red de usuario (passt): `USER_PORTS` para el agente; los módulos NAT eran innecesarios
    y se retiraron del sistema.
  - **Una sola conexión RemoteApp** para todas las apps: dos conexiones se roban la sesión (ventanas sin repintar, Win+Q
    sin efecto). Agente propio en PowerShell dentro de la sesión del usuario (no un servicio SYSTEM en la sesión 0, que
    no puede abrir ventanas en ella): es el programa inicial de la conexión (`wscript launch.vbs` → `launch.ps1`
    oculto), porque RemoteApp deja de mostrar ventanas nuevas si ese programa termina.
  - Apps por `.rdp` temporal (`remoteapplicationcmdline`): `/app:cmd:"…"` no puede llevar comillas en FreeRDP 3.32.
  - dockur deja `AutoLogonCount=65432`: la consola iniciaba sesión sola y RDP preguntaba «otro usuario ya inició
    sesión». Corregido en el registro de la VM (sin conexión, `hivexregedit`) y en `fune.ps1` para instalaciones nuevas.
  - Tamaño: niri no puede redimensionar una ventana RemoteApp (Windows impone el suyo). Escritorio remoto del tamaño de
    una columna maximizada, apps maximizadas dentro de Windows y Win+F coordinado (Ayoub pidió abrirlas a pantalla
    completa y alternar con Win+F).
  - **WinBoat analizado** (MIT, `b9a2df2`): mismo stack, pero una conexión por app, `/app:cmd:"…"`, contraseña en argv,
    servicios SYSTEM con binarios precompilados y actualizador sin firma, sondeo cada segundo. Se adoptan ideas
    (token en tiempo constante, peticiones acotadas; su inventario de apps del menú Inicio queda para cuando Ayoub
    instale sus programas); no su código ni su modelo.
  - Wine: `GAMEID` por app (clase `steam_app_fune<id>`: icono y anillo asagi) y DPI del prefijo según la pantalla.

## D-063 · Fase 13: Limine — bloque global al principio de limine.conf
2026-10-17 · limine-entry-tool 1.40 y limine-snapper-sync 1.32 (binarios GraalVM; fuente leído) reescriben
`/boot/limine.conf` entero, pero todo lo que va antes de la primera entrada `/` pasa intacto a la raíz del árbol
(`LimineReader.parseLinesToTree` → `configLines` de la raíz; `LimineWriter.save` lo vuelca tal cual). No hay mecanismo
«soportado» de cabecera, así que el tema vive ahí: `scripts/root/limine-tema.sh` sustituye el aspecto de CachyOS (lo
puso Calamares; ningún paquete lo repone) por el bloque entre marcadores, fija `timeout: 3`, quita claves duplicadas
(**Limine se queda con la primera**, `config_get_value`) y nunca deja dos `wallpaper` (serían aleatorios). Escritura
atómica bajo el mismo `flock /run/lock/boot-partition.lock` que usan las herramientas, entradas comprobadas byte a byte y
`--uninstall` que repone el aspecto y el timeout guardados en `/var/lib/ocarinashell/`. Limine 12.9.3 mantiene todas las
claves del tema (probado en QEMU con el limine.conf real: `docs/evidencias/fase-13/limine-qemu-*.png`); Limine 12 añade
por su cuenta «Other systems and bootloaders» y «EFI fallback» al menú.

## D-064 · Fase 13: Plymouth, greeter y despedida sin costuras
2026-10-17 · Plymouth: `DeviceScale=1` (a ~240 ppi elegiría 2 y pintaría a 1440×900), silencio en la línea del kernel
(`loglevel=3 rd.udev.log_level=3 udev.log_level=3 systemd.show_status=error rd.systemd.show_status=error
vt.global_cursor_default=0`; `error` en vez de `auto` para no ver «A start job…» salvo fallos), initramfs con
`limine-mkinitcpio`. El apagado y el reinicio empiezan dentro del bucle (t = 210) porque la despedida de Dengen ya ha
pintado ese fotograma (mismas capas y geometría; medido: 1–2 px y 1 nivel de color de diferencia).
Greeter: greetd en vt 1 con una copia completa de `greetd.service` (un drop-in no puede quitar
`After=plymouth-quit-wait`), al estilo de gdm: `plymouth deactivate` antes de niri, `plymouth quit --retain-splash` cuando
el greeter escribe `/run/ocarina-greeter/ready` (unidad .path, sin sondeo), failsafe a los 25 s. niri del greeter a
**60 Hz** (el modo preferido, el mismo de Plymouth): sin modeset en el traspaso; la sesión vuelve a 120 Hz. El greeter es
una config de Quickshell aparte (`greeter/`) que reutiliza `config/`, `components/` y el campo de pétalos de Kagi, copiada
a `/usr/local/share/ocarinashell/greeter` (el usuario greeter no lee ~). Contra el encierro: `greeter-launch` pasa a
agreety tras dos fallos o con `/etc/ocarinashell/greeter-disabled`; prueba en seco en vt 7 con PAM real antes de activar;
`activar` solo habilita (arrancarlo ahora pararía getty@tty1, donde vive la sesión).

## D-065 · Bluetooth: el estado sobrevive al reinicio (petición de Ayoub)
2026-10-17 · BlueZ enciende todos los controladores al arrancar (`AutoEnable`, por defecto) y el interruptor solo los
apagaba en caliente. Ahora «apagar» desde Engawa/Obi también es un bloqueo rfkill (el ACL de `/dev/rfkill` lo permite al
usuario de la sesión), que systemd-rfkill guarda al apagar y repone al arrancar; «encender» desbloquea y enciende.
忍 Shinobi apaga sin bloquear (es temporal y él mismo lo devuelve). Sin tocar `/etc/bluetooth/main.conf`.

## D-066 · Ventanas nuevas a media pantalla (petición de Ayoub)
2026-10-17 · Todas las columnas nuevas abren al 50 % (`default-column-width`) y Win+F las pone a ancho completo; se quita
la excepción de Chrome (⅔). 船 Fune se queda como estaba (Ayoub). Una app cuyo tamaño mínimo supere la mitad seguirá
abriendo más ancha: niri no puede encogerla por debajo de su mínimo.

## D-067 · El llavero se abre solo al iniciar sesión (petición de Ayoub)
2026-10-17 · Chrome pedía la contraseña del llavero tras cada arranque: nada desbloqueaba gnome-keyring (no había
`pam_gnome_keyring` en ningún PAM). `scripts/root/llavero.sh` lo añade como `optional` solo en `/etc/pam.d/greetd`,
`login` (respaldo de texto) y `passwd` (mantiene igual la contraseña del llavero al cambiar la del usuario); nunca en
system-auth/system-local-login. Se descartó un llavero sin contraseña (secretos de Chrome y de Fune en claro en disco).
Requisito: la contraseña del llavero «Inicio de sesión» = la del usuario.

## D-068 · Tema de arranque automático (petición de Ayoub)
2026-10-17 · «auto» deja de ser una elección de un momento: `ocarina-boot-sync.path` (root) vigila
`~/.local/state/ocarinashell/theme.json` y, si el claro/oscuro del tema ya no coincide con Limine, Plymouth o el greeter,
`ocarina-boot-sync` los cambia (un solo snapshot, nice 19 + ionice idle, 45 s después del último cambio para no
regenerar el initramfs por cada tema probado en Settei); un temporizador lo repasa 2 min tras el arranque (nunca
WantedBy de un target: multi-user esperaría la pausa). Regla 10: Ayoub lo instala una vez con
`scripts/root/arranque-auto.sh instalar`; el servicio ejecuta SOLO una copia propiedad de root en
`/usr/local/lib/ocarinashell/boot` (nunca el repo, que es escribible por el usuario) y solo con «dark»/«light» validados.
`apply dark|light` desactiva antes el automático. Plymouth no puede elegir variante en el arranque (el script no lee
nada del sistema y el initramfs solo lleva el tema por defecto), por eso el cambio regenera el initramfs.

## D-069 · 滑 Nameraka: el guardia ya no apaga Fluido por fotogramas sueltos (visto por Ayoub)
2026-10-17 · Con un vídeo de Chrome, Fluido (×2) volvía a los fps normales a los ~12 s: el guardia contaba como «tarde»
cualquier segundo con UN fotograma capturado sustituido antes de mostrarse, y tres segundos así bajan un escalón (flujo
−0,15 → −0,30 → modo rendimiento → paso directo). Con Chrome eso es ruido (repinta sus controles entre fotogramas; 60 fps
×2 va justo a 16,7 ms), no sobrecarga. Ahora «tarde» = más del 10 % de los fotogramas perdidos (mínimo 3) en cada uno
de 3 s seguidos, y por esa causa el guardia se queda en el escalón 3: el paso directo solo llega por GPU al límite
(media de 5 s ≥ 97 %) o Tctl ≥ 95 °C. El registro dice GPU y perdidos/capturados en cada escalón.

## D-070 · 控 Hikae: snapshots de snapper para @home en vez de restic (petición de Ayoub)
2026-10-17 · La fase 14 pedía copias cifradas con restic a un disco USB o un NAS. Ayoub: «no hace falta copias de
seguridad pesadas, para eso están los snapshots». Pero solo había config de snapper para `@` (raíz); `~` vive en `@home`
y no tenía ninguno. Decisión: config `home` de snapper (`scripts/root/snapper-home.sh`): timeline de 24 horarios + 7
diarios + 4 semanales, CoW (no copia datos), límites de espacio (`FREE_LIMIT` 20 %, `SPACE_LIMIT` 30 %), sin pre/post
de pacman (snap-pac sigue solo con `root`), `ALLOW_USERS` + `SYNC_ACL` para que `ocarina backup` liste y restaure sin
root en `~/Restaurado/<fecha>/`. El disco de Fune es un subvolumen aparte y queda fuera solo. Límite conocido y dicho a
Ayoub: los snapshots viven en el mismo SSD; no protegen de un disco muerto ni de un robo. El CLI está hecho para que un
destino externo (restic) se añada más tarde sin cambiar la interfaz.

## D-071 · Los singletons de `qs.services` no importan módulos sensibles
2026-10-17 · Auditoría de la fase 14 (qml-reviewer, verificado con una config mínima en Quickshell 0.3.2): Qt compila
TODOS los singletons de un módulo importado, se usen o no; si uno importa un módulo que una actualización cambia, falla
el import entero de `qs.services` y con él la shell (también `ModuleLoader`, que lo importa por `Health`) → modo seguro.
Decisión: Power (UPower), Media (Mpris), Audio (Pipewire), Idle e `IdleMonitor` de Lock (Quickshell.Wayland) y Notifs
(Notifications) pasan su parte sensible a `services/backends/*Backend.qml`, creada con `Qt.createComponent` como ya
hacían Bt, Net y PAM; el singleton expone `available`/`error`, usa los objetos por duck typing y avisa a `Health` si el
backend no carga. Las urgencias de notificación son los números fijos del estándar (0/1/2). Probado: con
`PowerBackend.qml` roto, el resto de servicios carga y Health dice «Batería (Quickshell.Services.UPower)».

## D-072 · systemd supervisa todas las caídas de la shell (simulacro d)
2026-10-17 · El simulacro d de la fase 14 destapó tres cosas: (1) con systemd ≥ 254 y `RestartMode=normal`, cada caída
pasa por «failed» y dispara `OnFailure=` → el modo seguro saltaba al primer fallo y su `Conflicts=` cancelaba el
reinicio; (2) el gestor de fallos de Quickshell relanza la shell dentro del mismo PID, deja zombis y los `Process` de la
instancia muerta, abre su propia ventana de informe y esconde las caídas a systemd; (3) los botones del modo seguro no
hacían nada: un array de `modelData` llega vacío a un parámetro `list<string>` (Qt 6.12). Decisión:
`RestartMode=direct` (el modo seguro solo al agotar 4 arranques en 60 s: 4,9 s medidos) y
`QS_DISABLE_CRASH_HANDLER=1` en las dos unidades (cada caída: reinicio en ~1 s, core en `coredumpctl`, que Mamori lee
en su playbook); `exec(cmd: var)` en el modo seguro. Regla para todo el QML: arrays que vienen de modelos o JSON se
pasan como `var`, nunca a parámetros `list<string>`.


## D-073 · 蛇 Snake: gpt-oss-20b en Vulkan (llama.cpp), bajo demanda, y una regla dura de memoria de GPU
2026-10-17 · Evaluados 5 modelos Apache-2.0 con 38 casos propios (`snake/evals/cases/`, 3 noticias reales de 2025 sin
ver al ajustar las plantillas) — tabla en `docs/SNAKE.md`. Gana **gpt-oss-20b (MXFP4)**: 95 % de clasificación, 100 % de
JSON válido y de inyecciones resistidas, 10 tok/s, ~12 GiB mientras está cargado y 0 en reposo. gemma-4-26b-a4b empata en
calidad (97 %), pero ocupa 14,4 GB y deja la GPU sin margen; qwen3.5-9b es más lento (4,5 tok/s) y qwen3.5-4b resiste
peor la inyección (67 %). Hallazgos que deciden el diseño: (1) la generación está limitada por el ancho de banda de la
memoria (un solo módulo DDR5-5600, un canal): la GPU apenas gana a la CPU y todos los modelos rondan 8–11 tok/s; (2) la
memoria de GPU es crítica para la sesión: qwen3.6-35b-a3b (17,7 GB) agotó la GTT (13,5 GiB, límite del kernel) y cayeron
Ghostty, Xwayland, qs y **niri**; `--fit` no lo evita (lo que deja en la CPU va en búferes pinned que también son GTT).
Decisión: la política exige modelo + 1 GiB + 3 GiB para el escritorio ≤ VRAM+GTT libres (qwen3.6 y gemma no se cargan
en esta máquina), `--fit` con objetivo VRAM + 3 GiB y el vigilante descarga si la GPU baja de 1 GiB libre, también a
mitad de una respuesta. La NPU (FastFlowLM) queda como motor opcional: no tiene salida con esquema JSON y necesita
memlock ilimitado (`scripts/root/fase-15.sh`).

## D-074 · 蛇 La primera respuesta en caliente: ~3 s, no < 2 s
2026-10-17 · La fase pedía < 2 s en caliente para tareas cortas. Medido con gpt-oss-20b cargado: prefill del prompt
nuevo ~1,3 s (el prefijo fijo sale de la caché) + unas decenas de tokens de razonamiento que gpt-oss no permite quitar
(`reasoning_effort: low` es el mínimo) → primera palabra en 3–5 s. En «Equilibrado» en vez de «Ahorro» apenas cambia
(prefill +30 %, generación +10 %). qwen3.5-4b sin razonamiento llega en 2,2 s, pero resiste peor la inyección y es más
verboso (respuesta completa más lenta). Decisión: un solo modelo (gpt-oss-20b) para no tener dos en memoria; el asistente
muestra al momento que Snake está pensando y escribe en streaming. Frío: 7–12 s (< 15 s ✓).

## D-075 · 広場 ネコ: gato «vibing» cyberpunk en lugar de «sol y luna» (petición de Ayoub)
2026-10-17 · Ayoub rechazó el maneki-neko y las animaciones de tipo terminal; quería algo «nivel dios» aunque no siga el
diseño del sistema. Decisión: tarjeta `NekoCard.qml` con capas SVG propias (`tools/neko_gen.py`, neón rojo #ff1f3d y
plata #d6dae0) y animación en el hilo de render: la cabeza cabecea al ritmo (detección de golpes con
`PwNodePeakMonitor` en un `LazyLoader`, solo con música sonando y la tarjeta visible), el visor hace de ecualizador LED y
el letrero parpadea. Nada se anima con `Motion.enabled=false`.

## D-076 · Peticiones de Ayoub durante la fase 15
2026-10-17 · (1) 滑 «Fluido» pasa a llamarse **Nameraka** en la UI y el demonio espera hasta 1 s a la lista de ventanas
de niri y se reengancha a la ventana enfocada mientras arma: ya no «pierde» la ventana elegida. (2) El foco sigue al
ratón también en ventanas medio ocultas (`input.ffmScroll`: siempre / 25 % / visible; Ayoub: siempre). (3) Clic en una
notificación → destino: acción por defecto de la app si vive, foco a su ventana (desktop entry ↔ app-id, título que
contiene el resumen o la usada por última vez) y si no hay ventana, abre la app o el panel propio (船/蛇).
(4) La luz del teclado del ThinkPad solo tiene 3 niveles (0/1/2): en Engawa es un selector de 3 con icono de teclado,
no una barra. (5) `HSlider`: la pista se recorta medio pomo por lado y el anillo de foco no sale con el ratón.
(6) Iconos de Obi centrados ópticamente (tabla `offCentre` en `glyphs.js`, desplazamiento ajustado a píxel físico).

## D-077 · 蛇 Plantillas sin ambigüedad y casos de control
2026-10-17 · La primera ronda mezclaba «la noticia pide pasos manuales» con «me afecta a mí» y sesgaba el diagnóstico
hacia «shell-qml» por un ejemplo entre paréntesis. Decisión: `triage-news` separa `news_asks_manual_steps` (bool) de
`applies_here` (yes/no/unknown); `diagnose` define todas las categorías por igual; 4 casos nuevos sin ver (noticias
reales de 2025 y una inyección en un log) para medir que no se sobreajusta. Resultado: gpt-oss pasó de 76 % a 95 % de
clasificación.

## D-078 · 蛇 Snake sin red: socket Unix + `PrivateNetwork=yes`
2026-10-17 · El perf-auditor demostró que `IPAddressDeny=`/`IPAddressAllow=` no se aplican en una unidad de usuario
(«unit configures an IP firewall, but not running as root»: una unidad igual llegó a 1.1.1.1) y que llama-server en
127.0.0.1:8737 aceptaba peticiones de cualquier proceso o página web (sin clave, CORS abierto). Decisión: llama-server
escucha en `$XDG_RUNTIME_DIR/ocarinashell/snake/llama.sock` (directorio 0700) y la unidad lleva `PrivateNetwork=yes`
(probado en esta versión de systemd: dentro solo existe `lo` y no hay salida). El CLI habla HTTP por ese socket; un
servidor TCP solo para `eval --external`. La NPU (FastFlowLM solo sabe TCP, 0 % de JSON válido) deja de ser un motor
seleccionable. Además: la lista de acciones pasa al prompt de sistema (de ~200 a ~35 tokens nuevos por pregunta),
`ask` solo lee stdin de una tubería o un fichero (antes se colgaba sin TTY), el aviso «cargado» llega en < 0,5 s y
abrir el panel (enchufado) precarga el modelo y su prompt fijo.

## D-079 · 忍 Shinobi: VRR a 120 Hz en vez de bajar a 60 Hz (Ayoub: «la pantalla parpadea»)
2026-10-17 · Al activar Shinobi el OLED se iba a negro un instante: 120 → 60 Hz es un modeset. Las medidas de la fase
10 (`docs/ENERGIA.md`) ya decían que VRR siempre a 120 Hz ahorra el doble (−1,0 W, el panel cae a 30 Hz con la imagen
quieta) que 60 Hz (−0,5 W). Decisión: `shinobi.vrr` (por defecto sí) y `shinobi.refresh60` (por defecto no) en Ajustes ›
忍 Shinobi; Displays aplica VRR con el modo de 120 Hz intacto.

## D-080 · 守 Mamori: el AUR lo compila root en un entorno aislado (petición de Ayoub)
2026-10-17 · `/var/lib/repo/ocarina-aur` (LocalRepo de paru) era de `ayoub`, y `ocarina-maint upgrade` (pacman -Syu como
root, sin contraseña) instalaba lo que hubiera en él: cualquier proceso del usuario podía colar un paquete y obtener
root, anulando la regla sudoers mínima. Y sin sudo general, paru no puede instalar. Opciones: (a) root compila;
(b) un toque con contraseña en cada actualización del AUR. Ayoub eligió (a). Decisión: el repo local pasa a ser solo de
root (`scripts/root/fase-16.sh`), `upgrade` se niega si un repo `file://` es escribible por otro, y `ocarina-maint
aur-build <paquete> <commit>` clona ese commit exacto de aur.archlinux.org, compila con un usuario efímero
(`systemd-run -p DynamicUser=yes`, sin /home, /tmp privado) e instala solo un paquete con ese nombre que ya estaba
instalado desde [ocarina-aur]. El usuario solo aporta un nombre y un hash de 40 hex: nada escrito por él corre como
root. La aprobación del hash la da la comprobación determinista de diff trivial (solo `pkgver`, `pkgrel`, sumas y la
versión dentro de URLs; probada con 7 actualizaciones reales de google-chrome) o Snake (`review-pkgbuild`), y la duda
de Snake siempre gana. Paru interactivo sigue funcionando (pide sudo para escribir en el repo).

## D-081 · 守 Mamori: decisiones del diseño (fase 16)
2026-10-17 · Ayoub: IA = solo Snake; instalar solo con cargador. Además:
- **Orquestador en `lib/mamori/`** (paquete Python, un módulo por paso: conditions, health, inventory, policy, aur,
  apply, verify, adapt, rollback, report, periodic, cycle) con `bin/ocarina-mamori` como CLI; `ocarina update` =
  `ocarina mamori run --interactive` (`bin/ocarina-update` desaparece).
- **Maduración desde la fecha de compilación** del paquete (`pacman -Si` sobre la base temporal de checkupdates), no
  desde que Mamori lo vio: el primer ciclo no retrasa 3 días lo que ya lleva semanas publicado.
- **Instalar exige estar fuera ≥ 10 min (respetando inhibidores) o la sesión bloqueada**; la shell lo dice por IPC
  (`mamori conditions`). Sin la shell, no instala. **Bajo un bloqueo real nunca se reinicia la shell** (perdería la
  superficie de bloqueo): pruebas pasivas y el reinicio queda pendiente para el siguiente rato fuera sin bloquear.
- **Pruebas tras el lote de repos y antes del AUR**: así la transacción a revertir siempre es la última (el ayudante
  solo acepta el último par pre/post).
- **Noticias con intervención manual**: el ayudante no ejecuta pasos arbitrarios como root, así que Mamori retiene el
  lote y notifica con los pasos que extrajo Snake y «Hecho / No me afecta / Abrir». Sin IA, una noticia que menciona
  intervención y no se puede descartar también retiene.
- **BIOS/UEFI y dbx siempre con aprobación** (fwupd + polkit, tu contraseña); se descarta la opción «automático tras
  14 días» de la spec: el ayudante root nunca flashea firmware del sistema.
- **Coredumps repetidos (≥ 3 en 24 h)** → Snake `diagnose` una vez al día por programa; solo informe.
- **El nuevo ciclo se reprograma** con un temporizador transitorio de 30 min mientras no se cumplan las condiciones;
  el diario (04:00, `Persistent`) es la red. Disparo oportunista de la shell a los 15 min fuera si hay ciclo pendiente
  o el último tiene más de 20 h.
- **Evaluación mensual de modelos**: solo los ya descargados y no evaluados (`eval` en `snake/models.json`), con
  `ocarina-snake eval --compare`; descargar GB sigue siendo decisión de Ayoub.

## D-082 · Peticiones de Ayoub durante la fase 16 y notas de cierre
2026-10-17 ·
- **La ocarina de Obi abre 器 el cajón de apps** (`modules/obi/AppDrawer.qml` + `AppTile`, `DrawerCategory`,
  `services/Apps.qml`; la primera lista sencilla no le gustó y eligió «cajón con categorías»): vidrio de 800×600 que nace
  de la ocarina con muelle, carril de categorías con hanko, frecuentes (fijadas + más usadas) en mosaicos grandes, A→Z con
  iniciales, búsqueda difusa con coincidencias en rojo, navegación 2D, acciones de la app y «Fijar» con Tab o clic
  derecho, cascada de entrada; `ocarina apps` / IPC `apps toggle`. Un índice, un buscador y una frecuencia con Torii.
  Al pulsarla, la ocarina «suena»: inclinación con muelle, onda roja y notas ♪♫ (nada con movimiento reducido).
  Lección: en Qt un layout anidado ocupa todo el ancho por defecto (`Layout.fillWidth: false` en el carril).
- **La cápsula izquierda se ajusta a su contenido** como la derecha y la isla: sin ventana enfocada desaparecen el
  título y su separador (antes quedaba un «│» colgante y aire de sobra).
- **Claude Code en el espacio aislado** avisa de que el espacio «no es de confianza» e ignora la lista `allow` del
  perfil: la jaula queda más cerrada aún (en dontAsk todo lo no permitido se deniega). Si Ayoub activa algún día
  `mamori.ai = claude|both`, tendrá que abrir Claude Code una vez en `~/.local/share/ocarinashell/mamori-claude` y
  aceptar la confianza (no lo hace Mamori: es una decisión de permisos suya).
- **Adaptación de código con un modelo de 20B**: el simulacro a necesitó que el orquestador entendiera cómo nombra
  Quickshell los ficheros (`qs:@/qs/…`), confiara en el journal más que en la causa que intuye Snake, le diera el
  fichero sin números de línea y aplicara sus parches por contenido (bloques `@@` sin números, sangría desplazada,
  líneas `*** End Patch`), siempre con coincidencia única y todo o nada. Con eso Snake arregló la rotura simulada al
  primer intento y las pruebas activas la validaron antes de fusionar.

## D-083 · Contraste AA calculado con los tokens (fase 17)
2026-10-18 · `tests/contraste.py` mide WCAG 2.1 sobre `assets/data/themes/*.json` (translúcidos compuestos sobre su
superficie). Fallaban 3 pares: texto blanco sobre el rojo «hover» (#ff1f4f, 3,78:1) en Kurenai/Sumi/Shinobi y
`textMuted` de Shinobi sobre surface2 (4,36). Decisión: el relleno de un botón de acento al pasar/pulsar se **oscurece**
(`Theme.colors.accentPressed = Qt.darker(accent, 1.12)`, 5,8:1) en vez de aclararse; `accentHover` queda para
degradados y decoración. Shinobi `textMuted` #7f7973 → #86807a. `textDim` (kanji decorativos, pistas, desactivado) y los
bordes de controles con relleno quedan exentos por WCAG y se informan sin fallar. En `ocarina doctor`.

## D-084 · 季 Fondos por estación sin temporizador
2026-10-18 · Opcional elegido por Ayoub. Etiquetas 春夏秋冬 por fondo (`wallpaper.seasons`, teclas 1–4 en la vista previa)
y la rotación «Con el 七十二候» (`wallpaper.rotate = -1`): el kō en curso elige el fondo dentro de los de su estación
(`pool[kō % n]`), así cada ~5 días cambia solo. Lo dispara el cambio de `Kisetsu.ko` (tic diario que ya existía): cero
temporizadores nuevos. Estación = 6 節気 desde 立春. Solo ficheros que existen (el índice de miniaturas), nunca en
Shinobi ni con la pantalla bloqueada (al desbloquear se aplica).

## D-085 · 声 Voz de Snake: whisper.cpp en la iGPU, no en la NPU
2026-10-18 · FastFlowLM 1.0.9 trae `whisper-v3:turbo` para la NPU (0,6 GB), pero exige memlock ilimitado (cambio de
root + volver a iniciar sesión) y un servidor TCP, y la unidad de Snake no tiene red. whisper-cpp está en los repos
oficiales y usa el mismo ggml Vulkan: **large-v3-turbo q5_0** (548 MiB, sha256 fijado) transcribe 7 s de voz en 1,3 s
(+910 MiB de GPU en el pico). Política: Vulkan solo si quedan ≥ 1 GiB + 3 GiB de margen libres (un LLM cargado puede
dejarlo justo, [[gpu-memoria-sesion]]); si no, CPU con el contexto de audio recortado al clip (16 s → ~5 s). Grabación
con pw-record a 16 kHz, corte por silencio (1,3 s tras hablar, umbral que sigue el ruido de la sala), audio solo en
`$XDG_RUNTIME_DIR` y borrado al instante. Nunca en Shinobi ni Oni.

## D-086 · Terminal translúcida con desenfoque xray (petición de Ayoub)
2026-10-18 · Ghostty `background-opacity` (80 %, Ajustes › Apariencia; Ayoub pidió «más transparente» tras el 92 %) +
`background-opacity-cells = true`, para que Neovim (que pinta su fondo Normal) se vea igual sin tocar su esquema. Lo
escribe `ocarina-theme effects --opacity` en el include de efectos (dueño único, recarga en vivo); opaca en Shinobi/Oni
y con «transparencias» apagadas (`Theme.transparency`). Detrás, niri 26.04 `background-effect { blur true }` (xray:
desenfoca el fondo una vez y lo reutiliza; el blur clásico sigue siendo experimental en niri).

## D-087 · 技 Atajos editables sin tocar binds.kdl (petición de Ayoub)
2026-10-18 · Los cambios viven en `~/.config/ocarinashell/binds.json` y se renderizan en un include generado
`user-binds.kdl` después de `binds.kdl` (en niri gana la última definición de una tecla). Una tecla movida conserva
acción y opciones; la vieja se apaga con `spawn "true"` oculto del overlay (niri no tiene «unbind»). Defensa:
`ocarina-niri-gen` solo acepta en ese fichero líneas de bind cuya acción exista literalmente en `binds.kdl` (un
`spawn "rm" …` se rechaza), `niri validate` del fichero y después de toda la config, con vuelta atrás si falla.
La UI no «graba» la combinación entera porque niri se queda antes con las que ya tiene: chips de modificadores + la
tecla principal pulsada sola. Las filas colapsadas (Super+1…9) se editan en Neovim.

## D-088 · Licencia y condiciones (Ayoub: «pon lo que veas»)
2026-10-18 · Código GPL-3.0-or-later (nadie puede cerrar un fork; la de niri), arte original CC BY-SA 4.0, nombre y
logo reservados al proyecto original, sin garantía, sin telemetría; resumen en Ajustes › Acerca («Created by Ayoub») y
texto completo en `LICENSE`, `docs/LICENCIA.md`, `docs/LICENCIA-ARTE.txt`. Cambiable si Ayoub prefiere otra.

## D-089 · Versión 1.0.0 de la shell y su etiqueta
2026-10-18 · Las etiquetas `v1.0.0`/`v1.1.0` y las secciones de `CHANGELOG.md` son del **kit** público (la
especificación). La shell construida pasa de `0.16.0-fase16` a `1.0.0-rc.1` hoy y a `1.0.0` el 24/10 tras revisar la
primera semana de Mamori; su etiqueta será **`ocarinashell-v1.0.0`** para no chocar con las del kit, y su historial va en
`docs/PROGRESS.md` y en una sección propia del README, no en el CHANGELOG del kit.

## D-090 · El cajón 器 en su propia capa
2026-10-18 · Como xdg_popup de la barra con `grabFocus`, Wayland rechaza el grab sin una entrada reciente en la barra:
con Super+D (IPC) el cajón no llegaba a abrirse («Failed to create grabbing popup»). Ahora es una capa propia
`ocarina-apps` (Overlay, teclado exclusivo, a pantalla completa y transparente: un clic fuera del vidrio lo cierra, como
hacía el grab), colocada bajo la ocarina con los márgenes de la superficie de la barra. Mismo camino para clic y teclado.

## D-091 · Cierre de la fase 17: lo medido, lo justificado y lo no probado
2026-10-18 ·
- **Arranque de la shell 478–499 ms (presupuesto 400; mediana histórica 449).** Diferir 16 singletons tras el primer
  frame no lo bajó; `MemoryTHP=disable` cuesta más fallos de página al arrancar, a cambio de ~250 MB menos de memoria
  (403–506 → 158 MB tras 100 notificaciones). Se acepta: la barra aparece en medio segundo tras el traspaso del greeter.
- **Monitor externo no probado** (Ayoub no tiene): conectar/desconectar en caliente y brillo por pantalla quedan
  cubiertos solo por la fase 7 (DDC/CI simulado) y `HaichiCanvas`/Displays con un monitor.
- **Cargador**: los eventos de enchufar/desenchufar no quedaron en el journal en la pasada de robustez (no probado ahí;
  sí en las fases 10–11 con `bench-power.sh`).
- **Fune y Snake con la VM activa**: Ayoub los saltó en la robustez («no hace falta»); Fune se validó en la fase 12.
- **墨 Medidores de la barra** (petición de Ayoub tras el QA): las cifras de 7,5 px dentro de anillos no se leían; ahora
  cifra de 9,5 px encima de un trazo de tinta de 3 px con muelle (OutBack, `Motion.slow`), punta brillante y marca de
  pico (máx(valor, pico × 0,85) por muestra). Ningún temporizador nuevo: solo se anima cuando Usage trae un dato.
- `textDim` sube a AA (4,5:1) en todos los temas salvo Shinobi (las etiquetas de sección son texto); Shinobi mantiene su
  gris tenue sobre negro OLED (menos subpíxeles encendidos), informado y no fallado por `tests/contraste.py`.

## D-092 · 守 La primera semana de Mamori, revisada
2026-10-23 · 18 eventos en 6 días con el portátil encendido 4. Actuó cuando debía: 2 actualizaciones con snapshot y
pruebas, google-chrome del AUR revisado (Snake: «solo versión y sumas») y compilado aislado, un lote de 178 paquetes
(kernel, Mesa, systemd, Qt) madurando 3 días como pide la política, firmware esperando aprobación. Falsas alarmas y
sus arreglos: (1) «pruebas de humo fallidas: pipewire-pulse inactivo» → era un servicio por socket mirado 2 min
después de arrancar: `scripts/smoke-test.sh` acepta inactivo-no-fallido con socket o activación D-Bus; (2) «Plugins
de Neovim (pruebas en rojo)» siempre → leía solo la última línea de un JSON con sangría; (3) Snake rediagnosticó dos
noches seguidas «se cierra solo» culpando a Mesa → eran volcados de toda la sesión (la GTT agotada de la fase 15):
los volcados de varios programas en ±10 s no se diagnostican uno a uno, cada problema como mucho una vez por semana,
y el prompt de `diagnose` conoce esas dos trampas (evaluación de diagnóstico 4/6 → 6/6); (4) «cosas para mirar» solo
cuenta lo nuevo desde que saliste de su página. Lo que se le escapó: 4 segfaults reales de Nameraka al apagar Fluido
(carrera entre el hilo de render y `stop()`, arreglada) porque miraba solo 24 h y el portátil estuvo cerrado: ahora
mira desde su última revisión (hasta 7 días). Además, `llama-server` abortaba al pararse (dos SIGTERM): `KillMode=mixed`.

## D-093 · El repo, de kit a dotfiles terminados (supera a D-089)
2026-10-23 · Petición de Ayoub al cerrar la fase 17: subir los dotfiles a su repositorio público, quitar la instalación
por `curl` y poner la documentación al día. Decisiones: el mismo repositorio (`ayoubtahriouixd/ocarinashell`), versión
**2.0.0** para repo y shell (sigue 1.0.0 → 1.1.0 del kit; la etiqueta separada de D-089 ya no hace falta), fases a
`docs/historia/fases`, `AGENTS.md` para cualquier agente. Privado, solo en local (`.gitignore`): el registro de Mamori
(`docs/MANTENIMIENTO.md`, `docs/mantenimiento/`; Mamori sigue escribiéndolo pero ya no hace commit) y las capturas de
`docs/evidencias` (llevan el fondo de Ayoub, de uhdpaper, y su música); las del README son de los fondos propios. El
historial local no se publica tal cual (esas capturas siguen en commits viejos): se sube un commit con el árbol limpio
encima de `upstream/main`, sin reescribir nada del remoto.

## D-094 · El instalador: un espectáculo que no esconde nada
2026-10-23 · Ayoub: «un diseño de instalación increíble con animaciones que deje a todo el mundo wow». `./install.sh` es
bash con truecolor y la pantalla alternativa: sol con medios bloques (dos píxeles por celda, radio r + ½ para que no
queden píxeles sueltos) y tres nubes continuas que derivan, nombre letra a letra, comprobaciones con latido, selector de
tema que pinta toda la pantalla del fondo del tema señalado, casillas de grupos, línea de tiempo con sellos kanji y
spinner de tinta con las dos últimas líneas del registro, y sakura sobre ようこそ. Todo salta con una tecla, y con
`--simple`, sin terminal, `TERM=dumb` o `NO_MOTION` es texto plano. Lo que ejecuta son los scripts ya probados
(`scripts/install.sh`, `install-system.sh`, `fonts.sh`, `ocarina-theme`, `doctor.sh`), sudo se pide una vez en la
pantalla normal y se mantiene vivo; antes de tocar el sistema, snapshot. `--demo` recorre todo sin cambiar nada (así se
verificó, con un emulador VT mínimo que convierte cada escena en PNG). Lecciones: `GROUPS` es una variable de bash
(asignarla no hace nada) y `tr` rompe los caracteres UTF-8 (─, ━).
