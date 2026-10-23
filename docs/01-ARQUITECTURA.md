# 01 · Arquitectura

## 1. Pila (versiones comprobadas: docs/SISTEMA.md y docs/COMPAT.md)
| Capa | Elección | Notas |
|---|---|---|
| Compositor | **niri ≥ 26.04** | blur (`ext-background-effect`, «xray» barato), `include optional=true`, recent-windows (Alt+Tab), shaders de animación, IPC JSON por socket |
| Shell | **Quickshell ≥ 0.3.2** (`quickshell` en extra) | Qt 6. Módulos: Wayland (capas, SessionLock, Idle*, BackgroundEffect, Screencopy), Io, Services.{Pipewire,Mpris,Notifications,SystemTray,UPower,Pam,Polkit,Greetd}, Networking, Bluetooth, Widgets, DBusMenu |
| Terminal | **Ghostty ≥ 1.3** | single-instance, shaders de cursor, quick terminal, avisos de fin de comando |
| Shell de comandos | **fish** (por defecto en CachyOS) + **starship** | |
| Editor | **Neovim** (≥ 0.11) + lazy.nvim | |
| Audio | PipeWire + WirePlumber | volumen vía API de Quickshell (sin `wpctl` en caliente) |
| Energía | power-profiles-daemon + helper propio vía polkit | ThinkPad: `platform_profile`, umbrales de carga |
| Bloqueo | Quickshell `WlSessionLock` + PAM (`PamContext`) | `swaylock` como respaldo de emergencia |
| Inactividad | Quickshell `IdleMonitor`/`IdleInhibitor` + `swayidle -w` solo para `before-sleep`/`lock` de logind | |
| Portapapeles | `wl-clipboard` + `cliphist` | |
| Portales | xdg-desktop-portal-gnome (+gtk), gnome-keyring | lo que recomienda niri |
| Paquetes | pacman + **paru** (optimizado: `reference/paru.conf`, `reference/makepkg.conf`) | nada de yay; PKGBUILD revisado |
| Apps de Windows | **Podman sin root** + `dockur/windows` (KVM) + **FreeRDP 3** RemoteApp (lanzador propio sobre los datos de WinApps); Wine/Proton (`umu-run`) para lo compatible | 船 Fune (§16, D-062); medidas en docs/WINDOWS.md |
| IA local | **蛇 Snake**: `llama-server` (llama.cpp con Vulkan en la Radeon 860M) bajo demanda + **whisper.cpp** para la voz | §18; modelo elegido por evaluación (gpt-oss-20b, docs/SNAKE.md); la NPU con FastFlowLM solo para evaluar |
| Mantenimiento | **守 Mamori**: `bin/ocarina-mamori` (Python stdlib) + ayudante root `ocarina-maint` + Snake (Claude Code opcional) | §17; también funciona sin IA |
| Vídeo fluido | **滑 Nameraka**: ayudante nativo `native/nameraka` (C++20, Vulkan, PipeWire) + **lsfg-vk ≥ 2.0** (Lossless Scaling de Steam, rama `lsfg-vk`) | §19; captura de la ventana con la API ScreenCast de niri; medidas en docs/FLUIDO.md |

No hay más demonios de UI: ni waybar, ni mako/dunst/swaync, ni fuzzel/rofi, ni agentes polkit externos
(OcarinaShell ES el servidor de notificaciones y el agente polkit). `ocarina doctor` avisa si hay otro en marcha.

## 2. Procesos (systemd --user, ligados a `graphical-session.target`)
| Unidad | Qué hace |
|---|---|
| `ocarinashell.service` | `qs -c ocarina` · `Restart=always` · `RestartSec=1` · `RestartMode=direct` · logs al journal (06, capa 4) |
| `ocarina-cliphist.service` | `wl-paste --watch cliphist store` (texto) |
| `ocarina-cliphist-img.service` | `wl-paste --type image --watch cliphist store` |
| `ocarina-sleep.service` | `swayidle -w before-sleep 'ocarina lock --wait' lock 'ocarina lock'` |
| `ocarina-nightlight.service` | `wlsunset` con los parámetros de Ajustes (la shell lo reinicia al cambiarlos) |
| `ocarinashell-safe.service` | modo seguro (`shell/safe/shell.qml`), lanzado por `OnFailure=` del servicio principal |
| `ocarina-postupdate.path` + `.service` | pruebas de humo en la sesión tras un hook de pacman (06-ACTUALIZACIONES) |
| `ocarina-mamori.timer` + `.service` | 守 Mamori: ciclo diario de salud, actualización y mantenimiento (`Nice=19`, IO idle, `Persistent=true`) |
| `ocarina-bootmark.service` | marca de arranque correcto (la usa Mamori para detectar kernels que no arrancan) |
| `ocarina-snake.service` | servidor de la IA local en un socket Unix (sin red), arrancado bajo demanda y parado tras N min sin uso |
| `ocarina-mamori-heal.service` | lo lanza el modo seguro: 守 Mamori intenta arreglar la shell sola |
| `ocarina-powerkey.service` | retiene el inhibidor `handle-power-key` de logind: el botón de encendido abre Dengen (D-041) |
| `ocarina-nameraka.socket` + `.service` · `ocarina-nameraka-selftest.service` | 滑 Nameraka (§19): activado por socket al usarlo, se cierra tras 60 s apagado (0 procesos en reposo); `self-test` oneshot al iniciar sesión (`Nice=19`) |
Arranque: niri lanza la sesión (`niri-session`/`niri.service`) → `graphical-session.target` → unidades.
`spawn-at-startup` solo para lo que no admita systemd. `xwayland-satellite` lo gestiona niri.
Fune usa Podman sin root, sin demonio: con Windows apagado no corre nada. 控 Hikae no tiene unidades propias: son los
timers de snapper de la config `home` (`scripts/root/snapper-home.sh`).

## 3. Repo → sistema
`./install.sh` (el instalador animado; `--demo` no cambia nada) hace snapshot, instala los paquetes de los grupos
elegidos (`scripts/paquetes.txt`), las fuentes (`scripts/fonts.sh`), enlaza (`scripts/install.sh`), copia los ficheros
de root (`scripts/install-system.sh`), aplica el tema, activa los servicios y pasa `ocarina doctor`.
`scripts/install.sh` (idempotente; `--dry-run`, `--uninstall`) crea los enlaces simbólicos con copia de seguridad previa (`*.ocarina-bak-<fecha>`):
`shell/ → ~/.config/quickshell/ocarina` · `config/niri/ → ~/.config/niri` · `config/ghostty/ → ~/.config/ghostty` ·
`config/nvim/ → ~/.config/nvim` · `config/fish/conf.d/*.fish` (tu `config.fish` sigue siendo tuyo) · `config/<app>/…` (fichero
a fichero) · `bin/* → ~/.local/bin/` · `systemd/user/*` (servicios, timers y paths) `→ ~/.config/systemd/user/` · el
ayudante nativo de Nameraka se compila con meson en `~/.local/libexec/ocarinashell/`. Lo tematizado (starship, GTK,
qt6ct…) no se enlaza: lo escribe `bin/ocarina-theme`.
Ficheros de root (`system/`: polkit, ayudantes `ocarina-powerctl` y `ocarina-maint`, hook de pacman) se copian con
`scripts/install-system.sh` (sudo), nunca por enlace. Lo del arranque (Limine, Plymouth, greeter) va aparte, en
`scripts/root/`, y lo ejecuta el usuario.
⚠ Quickshell 0.3 no canonicaliza rutas: lanza SIEMPRE con `qs -c ocarina` (misma ruta = mismo id de shell).

## 4. Estructura QML (`shell/`)
```
shell.qml                 ShellRoot: crea módulos por pantalla (Variants sobre Quickshell.screens) y carga perezosa
config/                   Theme.qml, Motion.qml, Settings.qml, Paths.qml, Glossary.qml   (singletons)
services/                 un singleton por fuente de datos (§5): Niri, Time, Audio, Brightness, Power, Net, Bt, Media,
                          Notifs, Kisetsu, Weather, Usage, Sensors, Idle, Modes, Apps, Launcher, Panels, Fune, Snake,
                          Mamori, Updates, Clipboard, Wallpapers, Sounds, Recorder, Displays, Session, Focus, Hogo,
                          Honban, Iro, Yomu, Nameraka, ThemeCtl, NiriConf, PowerCtl, Health, Tools… ; backends/ aísla
                          los módulos sensibles de Quickshell (06-ACTUALIZACIONES, capa 3)
components/               primitivas: OText, OIcon (Material Symbols), Kanji, Kamon, OButton, IconButton, Switch_,
                          OSlider, HSlider, Segmented, Chip, Tile, Dropdown, TextInput_, PanelSurface, PullDown,
                          ModuleLoader, Anim/CAnim (con Motion), BatteryRing, Sparkline, OcarinaLogo, BootOcarina
modules/obi/              barra: ObiBar, Workspaces, FocusedTitle, StatusCluster (+ UsageBar: 墨 CPU·RAM·GPU), Tray,
                          indicadores 船 蛇 新, campana y AppDrawer (器 cajón de apps, capa propia `ocarina-apps`)
modules/shima/            isla: Shima.qml (reloj, música con Equalizer, OSD, avisos, grabación, renombrar, Shinobi,
                          Oni, foco, Fluido)
modules/hiroba/           広場 Hiroba, la isla abierta: calendario, tiempo, estación, música, el equipo y el gato ネコ
modules/panels/           PanelHost: un solo panel a la vez (Engawa, Fumi, Hiroba, Kura, Mihari, Mado, Snake…)
modules/engawa/           centro de control + páginas Wi-Fi/Bluetooth/Audio/Fluido (FlowCard.qml: tarjeta 滑)
modules/fumi/             toasts + centro de notificaciones
modules/koyomi/           calendario (hoy dentro de Hiroba; `ocarina koyomi` abre Hiroba)
modules/torii/            lanzador (apps, calculadora, órdenes, web, archivos, ventanas, kanji y kaomoji, SSH, ajustes)
modules/kura/  modules/techo/  modules/mihari/  modules/mado/  modules/cheatsheet/
modules/kagi/             bloqueo (Kagi, KagiView, campo con pétalos, proverbio vertical 縦書き; PAM en
                          services/backends/PamBackend.qml; modo prueba con `ocarina lock test`)
modules/dengen/           menú de energía + Farewell.qml (despedida enlazada con Plymouth)
modules/polkit/           diálogo de autenticación
modules/settei/           app de ajustes (FloatingWindow) con una página por sección en pages/ (Apariencia, Barra,
                          Fondos, Pantalla, Energía, Shinobi, Oni, Nameraka, Fune, Snake, Mamori, Atajos…)
modules/kabegami/         renderizador del fondo con la transición de tinta (el explorador vive en Ajustes › Fondos)
modules/fune/             panel de apps de Windows (estado de la VM, recursos, apps, acciones)
modules/snake/            asistente de la IA local (conversación, contexto, voz, acciones con confirmación)
modules/nameraka/  modules/oni/  modules/haichi/  modules/corners/   OSD de Fluido · 覚醒 de Oni · etiquetas de pantalla · esquinas
modules/iro/  modules/yomu/  modules/dim/   cuentagotas · leer y traducir · atenuación por software (07-IDEAS, D-009)
ipc/Ipc.qml               todos los IpcHandler
safe/shell.qml            modo seguro: solo tipos básicos (06-ACTUALIZACIONES, capa 4)
shaders/                  *.frag (fuente) + *.frag.qsb (compilado con `qsb`, se versiona): tinta del fondo, tinte del gato
pam/                      password.conf, fingerprint.conf  (PamContext.configDirectory)
```
Reglas: módulos no se conocen entre sí; hablan por servicios y señales. Popups siempre con `LazyLoader`
(el lanzador se precarga «caliente» tras el arranque para abrir en < 1 frame).

## 5. Servicios (singletons) — fuente de datos y coste
| Servicio | Fuente (eventos) | Notas |
|---|---|---|
| `Niri` | `Socket` a `$NIRI_SOCKET` con petición `"EventStream"` + `SplitParser` por líneas JSON | Modelo de outputs, workspaces (id, idx, name, output, is_active, is_focused, is_urgent, active_window_id), ventanas (id, title, app_id, workspace_id, is_focused, is_floating, is_urgent, layout, focus_timestamp), capas de teclado, overview abierto, casts. Acciones: segundo socket (`{"Action":{…}}`) o `niri msg action …`. Reconexión con backoff. |
| `Time` | `SystemClock` (precisión minutos; segundos solo si se muestran) | medianoche → recalcula Kisetsu/kotowaza |
| `Audio` | `Quickshell.Services.Pipewire` (`Pipewire.defaultAudioSink/Source`, `PwObjectTracker`) | set volumen/mute directo; `PwNodePeakMonitor` solo con la isla en modo música visible y fuera de Shinobi |
| `Brightness` | **una entrada por pantalla**, con conexión en caliente por eventos (`Quickshell.screens` + salidas de `Niri`; nada de sondeo). Interna: `/sys/class/backlight/<dev>` (FileView `watchChanges` en `actual_brightness`). Externas: **DDC/CI** con `ddcutil` (VCP `0x10`, paquete oficial: trae `i2c-dev` y la regla udev `uaccess`, sin root). Sin DDC/CI (TV, proyector, DDC apagado): **atenuación por software** (capa negra translúcida `ocarina-dim` en `Overlay` de esa pantalla, sin entrada; no ahorra energía) | interna con `brightnessctl` (logind, sin root). Externas: `ddcutil detect` SOLO cuando cambian las pantallas (2 s después, en segundo plano; mapa bus I²C ↔ `DRM connector` `card1-DP-1` ↔ salida de niri `DP-1`; identidad = fabricante+modelo+serie del EDID, como en `niri msg -j outputs`; el panel interno sale como «Invalid display · laptop display», es normal) → `~/.local/state/ocarinashell/brightness.json` (lo usa el respaldo del CLI). Lectura `ddcutil --bus N getvcp 10` solo al abrir Engawa/Settei si la caché tiene > 30 s (el usuario pudo usar los botones del monitor). Escritura coalescida en segundo plano: gana el último valor, ≥ 200 ms entre escrituras, `--bus N --noverify` (`--bus` se salta la detección), una cola por bus, `timeout 5`; 3 fallos seguidos → esa pantalla pasa a software con aviso. Etiqueta: alias de Ajustes o «Monitor NN″» (diagonal con `physical_size`); la interna, «Portátil». Teclado: `tpacpi::kbd_backlight` |
| `Power` | `Quickshell.Services.UPower` (displayDevice) + `PowerProfiles` | potencia instantánea: `power_now` (sondeo 5 s SOLO con Engawa/Mihari visibles) |
| `Net` | `Quickshell.Networking` (NetworkManager), en `backends/` | escaneo Wi-Fi solo con la página abierta |
| `Bt` | `Quickshell.Bluetooth` | descubrimiento solo con la página abierta |
| `Media` | `Quickshell.Services.Mpris` | jugador activo = el que reproduce, si no el último usado |
| `Notifs` | `NotificationServer` (acciones, imágenes, respuesta inline, persistencia) | historial en `~/.local/state/ocarinashell/notifications.json` (100 máx.) |
| `Kisetsu` | `assets/data/kisetsu-72.json` | 二十四節気 + 七十二候 + mes tradicional + fase lunar (cálculo local) |
| `Weather` | Open-Meteo (sin clave), cada 30 min, caché en disco | apagado en Shinobi; ubicación desde Ajustes |
| `Usage` | `/proc/stat`, `/proc/meminfo` y `gpu_busy_percent` con `FileView` cada 2 s (sin procesos) | 墨 medidores CPU·RAM·GPU de la barra; redondeado al 2 % para no repintar por nada; parado en Shinobi, con la pantalla bloqueada o apagada y con `bar.showUsage` apagado |
| `Sensors` | hwmon: `k10temp` (Tctl), `amdgpu` (temperatura y PPT) cada 2 s | SOLO con 鬼 Oni encendido (isla y guardia térmica). Mihari lo muestrea `bin/ocarina-mihari`, vivo solo mientras el panel existe |
| `Idle` | `IdleMonitor` ×N (atenuar/bloquear/apagar pantalla/suspender), `IdleInhibitor` (cafeína) | perfiles CA/batería |
| `Modes` (Shinobi · Oni) | orquestador único de modos de energía (ver §10) | excluyentes; snapshot del estado previo |
| `Fune` | `ocarina-fune status --json` al arrancar y `podman events` (con `SplitParser`) SOLO con la VM encendida o en pausa + ventanas RemoteApp del servicio `Niri` | `podman stats` SOLO con el panel abierto; pausa automática; `available=false` si no hay Podman/FreeRDP |
| `Snake` | `ocarina-snake status --json` al arrancar y cuando el CLI avisa por IPC (`loaded`/`unloaded`) | sin sondeo; voz con `ocarina-snake listen` solo mientras se escucha |
| `Apps` (器) | el índice de apps de `Launcher` (el mismo que Torii) + categorías, frecuentes y fijadas | funciones puras: sin timers ni procesos; el cajón solo existe abierto |
| `Panels` | qué panel está abierto (uno a la vez) y en qué pantalla | — |
| `Mamori` | `FileView` con `watchChanges` sobre `~/.local/state/ocarinashell/mamori/status.json` y `history.jsonl` | solo lectura para la UI (indicador 新, página 守, notificaciones); disparo oportunista al estar inactivo 15 min |
| `Clipboard` | `cliphist list` bajo demanda | miniaturas en caché |
| `Wallpapers` | fondos incluidos + `~/Imágenes/Fondos`, miniaturas de `bin/ocarina-thumbs` | nada corre hasta abrir el explorador; rotación solo con CA; 季 rotación por estación colgada del tic diario de `Kisetsu` (sin timer) |
| `Sounds` | `pw-play` con `Process` (sin QtMultimedia) | respeta DND, Shinobi y volumen de UI |
| `Recorder` | `gpu-screen-recorder` o `wf-recorder` | indicador en la isla |
| `Displays` (配置 Haichi) | salidas de `Niri` + `Quickshell.screens` | perfiles por huella de monitores → include `outputs.kdl` validado; `wl-mirror` solo al duplicar |
| `Session` (復元 Fukugen) | eventos de ventanas de `Niri` | guarda `session.json` agrupando 30 s; restaura al entrar si se pide |
| `Focus` (集中 Shūchū) | tic de minutos de `Time` | solo vive mientras hay un bloque activo |
| `Nameraka` (滑, §19) | `FileView` de `~/.local/state/ocarinashell/nameraka/selftest.json` (disponibilidad y motivo, sin arrancar nada) + `Socket` a `$XDG_RUNTIME_DIR/ocarinashell/nameraka.sock` solo con Fluido encendido (eventos JSON; systemd arranca el ayudante al conectar) | estadísticas solo con Engawa u OSD visibles (`stats on/off`); `pause`/`resume` desde la shell al bloquear, apagar pantalla o abrir popups si hiciera falta; 0 procesos con el modo apagado |

## 6. Contrato IPC (`qs -c ocarina ipc call <destino> <función> [args]`)
| Destino | Funciones |
|---|---|
| `shell` | `version(): string` · `reload()` · `status(): string` |
| `audio` | `increment(step: string)` · `decrement(step: string)` · `mute()` · `micmute()` · `set(pct: int)` |
| `media` | `playPause()` · `next()` · `previous()` · `stop()` · `increment(step: string)` · `decrement(step: string)` |
| `brightness` | `increment(step: string, output: string)` · `decrement(step: string, output: string)` · `set(pct: int, output: string)` · `list(): string` (JSON: `name`, `label`, `kind` internal\|ddc\|soft\|none, `pct`) — `output` vacío = según `display.brightness.keysTarget`, `"all"` = todas (cada una en su escala) |
| `kbdlight` | `cycle()` · `set(level: int)` |
| `lock` | `lock()` · `isLocked(): bool` · `state(): string` · `test()` (modo prueba: Esc sale) — **sin** `unlock()` |
| `launcher` | `toggle()` · `open(mode: string, query: string)` |
| `engawa` | `toggle()` · `open(page: string)` |
| `notifications` | `toggle()` · `dnd(state: string)` (`on/off/toggle`) · `clear()` |
| `power` | `toggle()` (menú Dengen) · `close()` · `isOpen(): bool` · `farewell(kind: string)` (solo la despedida, para probarla) |
| `settings` | `toggle()` · `open(page: string)` (también `focusOrToggle()` por compatibilidad) |
| `techo` · `kura` · `mihari` · `mado` · `cheatsheet` | `toggle()` |
| `kabegami` | `browse()` · `set(path: string)` · `next()` |
| `workspace` | `rename()` |
| `shinobi` | `on()` · `off()` · `toggle()` · `status(): string` |
| `oni` | `on()` · `off()` · `toggle()` · `status(): string` · `autoOn()` · `autoOff()` (GameMode) |
| `fune` | `toggle()` (panel) · `start()` · `pause()` · `resume()` · `stop()` · `status(): string` |
| `snake` | `toggle()` · `open()` (asistente) · `ask(text: string)` · `listen()` (声 voz) · `status(): string` · `loaded(name)` / `unloaded()` (los llama el CLI) |
| `apps` | `toggle()` (器 cajón de apps) |
| `hiroba` | `toggle()` · `open()` · `close()` · `isOpen(): bool` (`koyomi.toggle()` también abre Hiroba) |
| `mamori` | `status(): string` · `conditions(): string` · `refresh()` (lo llama el orquestador al cambiar el estado) · `run()` · `open()` (su página) |
| `updates` | `status(): string` · `refresh()` (indicador 新) |
| `theme` | `set(id: string)` · `get(): string` · `accent(hex: string)` |
| `record` | `toggle()` · `region()` |
| `osd` | `show(kind: string, value: string)` · `info(text: string, icon: string)` (internos) |
| `nightlight` | `set(mode: string)` · `toggle()` |
| `idle` | `inhibit()` (cafeína) · `status(): string` |
| `displays` | `arrange()` (Settei → Pantalla) · `identify()` · `mirror(on: bool)` · `profile(name: string)` · `list(): string` · `keep()` / `revert()` (aviso de prueba de 15 s) |
| `focus` | `start(minutes: int)` · `stop()` · `status(): string` |
| `session` | `save()` · `restore()` · `status(): string` |
| `backup` | `now()` · `status(): string` · `restore(path: string)` (abre Recuperar en la página 守; vacío = sin preselección) |
| `iro` | `pick()` · `status(): string` |
| `yomu` | `region(translate: bool)` · `status(): string` |
| `nameraka` | `toggle()` · `on()` · `off()` · `mode(m: string)` (`x2\|x4\|x6\|custom\|next`) · `fps(n: int)` (objetivo de «A medida» y pasa a ese modo; 0 = Hz de la pantalla) · `engine(e: string)` (`auto\|lsfg\|ia`) · `calibrate()` · `status(): string` (JSON de la orden `status` del ayudante: estado, motivo, ventana, base, multiplicador real, fps de salida, Hz, motor, tarde %, latencia, GPU) |

## 7. CLI `ocarina` (bash, `bin/ocarina`) — los binds llaman SIEMPRE a esto
- Traduce a IPC y, **si la shell no responde, usa un respaldo** para que las teclas nunca mueran:
  `audio` → `wpctl …`; `brightness` → `brightnessctl …` (interna) y `ddcutil --bus N setvcp 10 …` (externas, buses leídos de
  `brightness.json`; si no existe, `ddcutil detect`); `media` →
  `playerctl` si existe; `lock` → `swaylock -f`
  (tematizado); `launcher` → mensaje en `notify-send`. Bloquear SIEMPRE debe funcionar.
- Subcomandos: `audio up|down|mute|mic` · `brightness up|down [<paso>] [--output <salida>|--all]` · `brightness set <N> [--output <salida>|--all]` · `brightness list` · `media toggle|next|prev|up|down` · `launcher [modo] [texto]` ·
  `lock [--wait|test]` · `power` · `settings [página]` · `engawa [página]` · `apps` · `koyomi` · `notifications [dnd on|off|toggle|clear]` ·
  `notes ["texto"]` · `clipboard` · `nightlight [modo]` · `caffeine` ·
  `tasks` · `rules` · `rename-workspace` · `wallpaper [browse|next|<ruta>]` · `shinobi [on|off|toggle|status]` ·
  `oni [on|off|toggle|status|auto-on|auto-off]` · `play <cmd…>` (gamescope + GameMode) · `quickterm` ·
  `fune [status|start|pause|resume|stop|desktop|app <id> [archivo]|scan|apps|webapp <nombre> <url>|wine …|update|maintenance|backup|smoke]` ·
  `snake [ask "<texto>"|listen|status|start|stop|eval|models|fetch|actions|help]` ·
  `mamori [status|run|plan|pause <días>|resume|hold <pkg> <días>|unhold <pkg>|rollback|report|…]` · `rollback [--yes]` ·
  `displays [arrange|identify|mirror on|off|profile <nombre>|list]` · `focus [<min>|stop]` · `session [save|restore]` ·
  `backup [status|now|list [ruta]|restore <ruta> [n]|check]` · `pick-color` · `read [--translate]` · `ssh <host>` ·
  `nameraka [on|off|toggle|status|x2|x4|x6|custom|next|fps <N>|calibrate|self-test]` (alias `fluido`; si la
  shell no responde, habla con el socket del ayudante y `off` cae en `systemctl --user stop ocarina-nameraka.service`) ·
  `record [region]` · `cheatsheet` · `update [--check]` · `doctor [--quiet|--smoke|--post-update]` ·
  `restart` · `logs [-f]` · `version`.
- Herramientas aparte en `bin/`: `ocarina-theme` (§9), `ocarina-binds` (技 atajos editables, 03-ATAJOS),
  `ocarina-snake`, `ocarina-mamori`, `ocarina-fune`, `ocarina-backup`, `ocarina-niri-gen` (valida e instala los includes
  generados de niri), `ocarina-boot-theme`…
- `lock --wait`: pide el bloqueo y espera (máx. 2 s) a `isLocked()==true` para que `swayidle -w` no suspenda antes.

## 8. Ajustes (`~/.config/ocarinashell/settings.json`, `FileView` + `JsonAdapter`, cambios en vivo)
Esquema versionado con migraciones; las claves reales y sus valores por defecto están en `shell/config/Settings.qml`
(`defaults()`), y `bin/ocarina-snake`, `bin/ocarina-mamori` y el CLI leen las mismas. Mapa por secciones:
`appearance {theme, accent, autoTheme{enabled, day, night}, blur, transparency, animSpeed, radius, kanjiDecor, screenCorners, uiFont, jpFont, displayFont, fontScale, reducedMotion}` ·
`bar {position, style (isles|floating|attached|minimal), clock24, showSeconds, showWeather, showUsage (墨 CPU·RAM·GPU), showKisetsu, modules[]}` ·
`island {media, osd, notifPeek, recording, hover, wheelVolume, swipeTracks, aura, hoverFx}` ·
`hiroba {anime, speedLines, petals, vinyl, screentone, sections{me, clock, neko, month, season, music, system}}` · `profile {kanji}` ·
`display {nightLight{mode, temp, from, to}, brightness{keysTarget (focused|internal|all), ddc, softFallback, timeCurve, perOutput{"<fabricante>|<modelo>|<serie>": {alias, min, last, day, night}}}, profiles{"<huella>": {name, kanji, outputs{…: {mode, scale, transform, vrr, position, enabled, primary}}}}, autoProfile, notifyOnConnect, mirrorDnd, lidCloseToExternal}` (escala, Hz y VRR de cada pantalla viven SOLO en su perfil: Haichi es el único dueño) ·
`oled {pixelShift, dimStatic, lockDrift}` · `focus {minutes, breakMinutes, dnd}` · `session {restore (ask|auto|off), exclude[]}` ·
`idle {ac{dim, lock, screenOff, suspend}, battery{…}}` · `audio {uiSounds, uiVolume}` · `bluetooth {enabled}` ·
`power {chargeLimit{enabled, start, end}, lowBattery, autoShinobiAt, autoShinobiAsk, exitShinobiOnAC}` ·
`notifications {dnd, dndSchedule, timeout, position, privacyOnLock, perApp{}}` ·
`terminal {inkCursor, greeting, fastfetchDaily, opacity (Ghostty y Neovim translúcidos; 0,8 por defecto)}` ·
`shinobi {refresh60, vrr, boostOff, bluetoothOff, bluetoothKeepAudio, brightnessCap, brightnessCapExternal, kbdLightOff, wifiPowersave, pauseServices[], gpuLow, funeStop}` ·
`oni {auto, batteryAuto (ask|never|allow), exitBatteryAt, gpuLevel, scx, gpuFirst, fanMax, kishin, vrrGames, dnd, wifiNoPs, nightLightPause, pauseServices[], gamescopePreset, funePause}` ·
`nameraka {mode (x2|x4|x6|custom; por defecto custom), fps (objetivo de «A medida»; 0 = Hz de la pantalla), engine (auto|lsfg|ia), flow (0 = calibrado), perf (auto|on|off), battery (eco|normal|off), avSync (apagado por defecto), auto, exclude[]}` ·
`fune {autoPause, pauseMinutes, stopMinutes, startOnAC, microphone}` ·
`snake {enabled, backend (vulkan|npu), model, fastModel, keepAliveMin, ctx, batteryAssistant, voiceLang}` ·
`mamori {enabled, ai (snake|claude|both|off), batteryMin, maturationDays, maturationDaysNoAi, aur, firmware (approve|off), nightlyReboot, autoImprove, notify, claudeBudget{turns, minutes}}` ·
`lock {fingerprint, showMedia, blurWallpaper}` ·
`input {layouts[] ("es", "us(intl)"…), switchKeys, repeatDelay, repeatRate, touchpad{tap, naturalScroll, dwt, speed, scrollFactor}, trackpointSpeed, mouseSpeed, ffm, ffmScroll, warpMouse, touch}` ·
`windows {gaps, focusRing, focusRingWidth, defaultWidth, niriAnimations}` (input/windows/animSpeed → `overrides.kdl`, D-046) ·
`weather {enabled, lat, lon, place, units}` · `launcher {frecency, webEngine, pinned[] (器 apps fijadas en el cajón)}` ·
`ssh {enabled, configPath, prodHosts[]}` · `clipboard {dbPath, maskSecrets, pasteOnEnter}` · `techo {mincho}` ·
`wallpaper {path ("" = el del tema), perTheme, rotate (minutos, solo con CA; −1 = 季 uno por microestación), favorites[], seasons{"<ruta>": [0–3 = 春夏秋冬]}}` ·
`wallhaven {enabled, query, purity}` · `extras {touchGestures, iro, yomu, kaomoji, wifiQr, vpnTile, worldClocks[]}` (interruptores de 07-IDEAS).
Los atajos cambiados en Ajustes › 技 Atajos van aparte, en `~/.config/ocarinashell/binds.json` (03-ATAJOS).
`appearance.animSpeed` es una velocidad (0 = sin animaciones, 0,5–2×) y `appearance.accent` vale `null` (el del tema),
`"#rrggbb"` o `"wallpaper"` (se recalcula al cambiar de fondo; `services/ThemeCtl.qml`).
Lo que afecta a niri se escribe en includes generados (`~/.local/state/ocarinashell/niri/*.kdl`) y niri recarga solo.

## 9. Motor de temas (`bin/ocarina-theme`, Python stdlib)
`assets/data/themes/<id>.json` + acento elegido → **tokens resueltos** en `~/.local/state/ocarinashell/theme.json` →
plantillas `templates/**` (sintaxis `{{token}}`) → destinos: niri `colors.kdl`, Ghostty `themes/ocarina`,
Neovim `palette.lua`, fish/fzf/eza/bat, starship, btop, yazi, fastfetch, GTK3/4 `gtk.css`, qt6ct, swaylock,
gsettings (`color-scheme`, `gtk-theme`, `icon-theme`, `cursor-theme`, `accent-color`), papirus-folders.
Recargas: niri (auto), Ghostty (señal/acción de recarga de la versión instalada), Neovim (vigila el fichero con
`vim.uv.new_fs_event`), la shell (FileView con `watchChanges` → todos los colores con `ColorAnimation`).
Modo «Desde el fondo»: `matugen` → se mapean sus colores a nuestros tokens.
Efectos de terminal (`services/TermFx.qml` → `ocarina-theme effects on|off --motion … --opacity …`): estela de tinta
del cursor de Ghostty, animaciones de Neovim y la opacidad del fondo (`background-opacity` + `background-opacity-cells`:
Ghostty y el Neovim que corre dentro, translúcidos sobre el fondo desenfocado que pone la regla `background-effect` de
niri; 0,8 por defecto, 1 en Shinobi, en Oni o sin transparencias). Escribe `theme/ghostty-effects.conf` y
`theme/effects.json` (Neovim lo vigila); Ghostty recarga solo si cambia su include.

## 10. Modos de energía: 忍 Shinobi y 鬼 Oni (orquestación)
Un único estado `normal | shinobi | oni`. Oni aplica el camino inverso a Shinobi: PPD `performance`
(+ modo gaming de scx_loader en CachyOS), turbo, perfil 3D de la GPU, 120 Hz + VRR en juegos, Wi-Fi sin ahorro,
No molestar, shell sin blur/animaciones/sondeos, VM de Fune en pausa si no hay apps de Windows abiertas, ventilador al
máximo opcional y Kishin experimental vigilado. Se activa a mano o con GameMode y vuelve al snapshot exacto al salir.
Detalle de Shinobi:
Máquina de estados `off → entering → on → leaving → off`. Al entrar guarda un **snapshot** del estado previo
(`~/.local/state/ocarinashell/shinobi-prev.json`) y aplica, en orden y de forma reversible:
shell (Motion off, blur/transparencias off, tema `shinobi`, fondo negro, isla mínima, monitores de pico y tiempo off,
reloj por minutos) → niri (include `shinobi.kdl`: `animations { off }`, sin sombras ni blur) → pantalla (120→60 Hz a
través de `Displays`, que reescribe `outputs.kdl`: así ninguna recarga de niri devuelve los 120 Hz;
tope de brillo en la interna —y en externas solo con `brightnessCapExternal`, para monitores USB-C alimentados
por el portátil—, luz de teclado off) → energía (PPD `power-saver`, turbo off vía helper) → radios (Bluetooth off si
no hay dispositivo en uso o si así está configurado; Wi-Fi powersave) → apps (efectos de Ghostty y Neovim off,
pausa de servicios configurados, VM de Fune pausada o apagada). Salir restaura el snapshot exacto. Mientras el modo no
es normal se pausan el tema y el brillo según la hora (al salir se aplica el tramo actual) y, al volver de la atenuación
por inactividad, el brillo respeta el tope del modo. Oni también cambia Hz/VRR solo a través de `Displays`. Disparadores:
manual, % de batería, al desenchufar (opcional); salida automática al enchufar (configurable).

## 11. Seguridad y privacidad
- **Bloqueo**: `WlSessionLock`; si la shell muere bloqueada, niri mantiene la pantalla bloqueada; recuperación en
  `05-RESCATE.md`. PAM con ficheros propios en `shell/pam/` (no se toca `/etc/pam.d` salvo el greeter opcional).
- **Helper root** `ocarina-powerctl`: lista blanca estricta de operaciones y valores; acción polkit
  `org.ocarinashell.powerctl` con `allow_active=yes` solo para la sesión local activa.
- Notificaciones: opción de ocultar contenido en el bloqueo; toasts con `block-out-from "screencast"` opcional.
- Portapapeles: respeta `CLIPBOARD_STATE=sensitive`; límite de elementos; borrado con un clic.
- Fune: RDP y visor web solo en `127.0.0.1`; contraseña de la VM en gnome-keyring (`secret-tool`), nunca en claro.
- Snake: `llama-server` escucha en un socket Unix de un directorio 0700 y la unidad no tiene red (`PrivateNetwork=yes`);
  sin ejecución libre de comandos; lo descargado de internet se trata como dato. La voz solo existe en
  `$XDG_RUNTIME_DIR` mientras se transcribe.
- Ideas (07-IDEAS): Yomu hace el OCR y la traducción en local y borra la captura; Hikae cifra con `restic` y guarda la
  contraseña en gnome-keyring; Honban solo lee los nombres `Host` de `~/.ssh/config` (nunca claves ni `known_hosts`).
- 滑 Nameraka captura SOLO la ventana objetivo, en memoria de la GPU y mientras está activo: nada se graba, nada sale
  del equipo y la captura termina al apagarlo (se ve en `niri msg casts`). La DLL de Lossless Scaling sale de la
  instalación de Steam del usuario; OcarinaShell nunca la copia ni la redistribuye.
- Ninguna telemetría. Peticiones de red solo: Open-Meteo (tiempo), Wallhaven si se activa y el destino de Hikae.

## 12. Verificación y herramientas
- `tests/qml-check.sh [ficheros]`: compila todo el QML en una instancia aislada (< 1 s). `tests/render-page.sh <Página>`:
  PNG de una página de Ajustes dibujada fuera de pantalla. `tests/contraste.py`: WCAG AA de cada tema.
- `scripts/shot.sh <nombre> [región]` → `grim` (en un espacio vacío: nunca la pantalla con tus ventanas);
  `scripts/compare.sh <shot> <mockup>` → montaje con la diferencia frente al mockup.
- Logs: `journalctl --user -u ocarinashell -f`. Arranque de depuración con `QSG_VISUALIZE=changes` o
  `QSG_RENDER_TIMING=1` en una instancia de prueba (`qs -p shell/shell.qml` con otro id).
- `scripts/doctor.sh` / `ocarina doctor`: versiones, servicios, conflictos (otro demonio de notificaciones o polkit),
  fuentes, enlaces, permisos de los ayudantes (y si quedara el sudo temporal de la construcción), estado de snapper, estado de Fune, brillo
  (`i2c-dev` cargado, `ddcutil detect` sin root, pantallas y su tipo internal/ddc/soft).
- `ocarina doctor --smoke`: las pruebas de humo pasivas (~2 s, no tocan la pantalla).
- Hooks de Claude Code (si usas un agente en el repo; ver `AGENTS.md`): validación tras cada edición
  (`scripts/hooks/validate.sh`) y guardia de comandos peligrosos (`scripts/hooks/guard.sh`).

## 13. Degradación elegante
Sin blur (niri < 26.04 o Shinobi) → superficies opacas al 94 %. Sin huella → solo contraseña. Sin batería (CA) →
oculta batería. Sin Bluetooth → oculta mosaico. Sin red → tiempo desde caché con aviso. Sin Podman/FreeRDP → Fune
oculto. Pantalla externa → barra en cada salida, isla solo en la principal (configurable), bloqueo en todas.
Sin `ddcutil`/acceso I²C → brillo externo por software. Sin amdgpu → el medidor 墨 de GPU se oculta. Sin `restic`, `tesseract`, `wl-mirror` o `qrencode` → esa
función se oculta con la pista del paquete que falta. Sin `niri msg pick-color` (niri < 25.05) → cuentagotas oculto.
Nameraka: sin lsfg-vk o sin la DLL de Lossless Scaling → motor `ia` si pasó su puerta; si no, la tarjeta 滑 dice qué
falta y enlaza a Ajustes. Sin la API ScreenCast de niri, sin layer-shell o sin importación DMA-BUF en Vulkan → tarjeta
oculta y el motivo en Ajustes › Acerca de › Diagnóstico.

## 14. Resiliencia, actualizaciones y mantenimiento autónomo
Ver `docs/06-ACTUALIZACIONES.md` (6 capas: snapshots/LTS, paquetes oficiales, código que no
se cae, modo seguro, pruebas de humo con reversión automática y 守 Mamori, el piloto automático).

## 15. Cadena de arranque y apagado
Limine (tema en `assets/boot/limine/`, probado en QEMU) → Plymouth (`assets/boot/plymouth/ocarinashell/`, script con capas)
→ greeter (greetd + niri + Quickshell, opcional) → sesión; y Dengen → `Farewell` → Plymouth de apagado. Misma variante
(oscura/clara) en toda la cadena; el icono ocupa la misma posición (centro al 42 % del alto) en Plymouth, greeter y
despedida. Nada de esto lo instala `./install.sh`: lo pone el usuario con `scripts/root/fase-13.sh` (Limine y Plymouth),
`scripts/root/greeter.sh` y `scripts/root/arranque-auto.sh`, cada uno con su snapshot y su vuelta atrás (`--uninstall`,
`desactivar`, `quitar`; 05-RESCATE).

## 16. 船 Fune — apps de Windows
Tres niveles, del más barato al más compatible: **web/PWA** (si la app tiene versión web, ventana de Chrome `--app`) →
**Wine/Proton** (`umu-run` + `proton-cachyos`, NTSYNC; cero sobrecoste de VM) → **Windows en KVM** (`dockur/windows`
con **Podman sin root**, lanzador propio `bin/ocarina-fune` sobre los datos de WinApps, disco en subvolumen Btrfs NOCOW
fuera de snapper, apps como ventanas nativas vía FreeRDP 3
RemoteApp bajo xwayland-satellite, accesos `.desktop` con iconos y tipos MIME → aparecen en Torii y en Nautilus).
La shell aporta la interfaz (panel 船, indicador en Obi, reglas de ventana) y el ahorro (pausa automática, Shinobi/Oni).

## 17. 守 Mamori — mantenimiento autónomo
Orquestador determinista `bin/ocarina-mamori` + paquete `lib/mamori/` (Python stdlib, un módulo por paso) lanzado por
`ocarina-mamori.timer` (→ `ocarina-mamori@timer.service`), por la shell al llevar 15 min inactiva (`@shell`), tras el
arranque (`@boot`, desde `ocarina-bootmark`) y por el modo seguro (`ocarina-mamori-heal.service`): comprueba condiciones (cargador, red sin límite, sin Oni/llamada/grabación, usuario inactivo) → salud
y autorreparación → inventario (pacman/AUR/noticias/CVE/firmware) → política (maduración, seguridad, AUR, retenciones
sin actualizaciones parciales) → snapshot → actualización vía ayudante root `ocarina-maint` (lista blanca + sudoers
mínimo) → pruebas de humo → adaptación (IA) o reversión → informe. La IA es **Snake** (local, §18): investiga,
revisa y propone arreglos con salidas JSON validadas; Claude Code (`claude -p "/mantener"` desde el espacio aislado
`~/.local/share/ocarinashell/mamori-claude/`, cuyo perfil es `.claude/mamori-settings.json`) es un extra opcional.
Sin IA, modo determinista.
Estado en `~/.local/state/ocarinashell/mamori/` (`status.json`, `plan.json`, `holds.json`, `history.jsonl`).

## 18. 蛇 Snake — IA local
`ocarina-snake.service` → `llama-server` (llama.cpp con Vulkan en la iGPU) en un socket Unix, arrancado bajo demanda y
parado tras `snake.keepAliveMin` minutos sin uso. Cliente `bin/ocarina-snake` (Python stdlib) con tareas de esquema fijo
(`triage-news`, `review-changelog`, `scan-issues`, `review-pkgbuild`, `diagnose`, `propose-patch`, `report`, `assist`,
`translate`) y recuperación de información de una lista blanca de fuentes. Modelo principal **gpt-oss-20b**, elegido y
reevaluado cada mes con `snake/evals/`. Si no cabe en la memoria libre de la GPU (un navegador ocupándola), el asistente
usa solo el mejor modelo ligero descargado que sí quepa (qwen3.5-9b, luego qwen3.5-4b) y lo dice; las tareas de fondo de
Mamori nunca bajan de modelo: esperan. 声 Voz: `ocarina-snake listen` graba hasta una pausa, transcribe con whisper.cpp
(large-v3-turbo) y pregunta. Snake nunca ejecuta nada: propone; Mamori (o el usuario, con confirmación en el asistente)
dispone. 0 MB de RAM en reposo; bloqueado en Shinobi y Oni. Detalle y medidas: docs/SNAKE.md.

## 19. 滑 Nameraka — vídeo fluido: generación de fotogramas en todo el sistema
El «Lossless Scaling» de OcarinaShell. La tarjeta 滑 de Engawa (o `Mod+Alt+F`) multiplica los fps de lo que estés
viendo a pantalla completa —cualquier app: Chrome, Firefox, mpv, Electron…— con **×2 · ×4 · ×6** o **A medida** (los
fps que quieras; por defecto, los Hz de la pantalla). Apagarlo deja todo exactamente como estaba: Nameraka nunca toca
la app ni su vídeo, solo pone (y quita) una capa encima. Mismo principio que Lossless Scaling en Windows: **capturar →
generar → presentar encima**, aquí sin copias en CPU y con el ritmo atado a los Hz del panel.

### Tubería
1. **Captura sin diálogo y sin copias.** niri implementa en D-Bus la API de screencast de Mutter, la misma que usa
   xdg-desktop-portal-gnome (`org.gnome.Mutter.ScreenCast`, versión 4; ver `src/dbus/mutter_screen_cast.rs` de tu
   versión). El ayudante llama a `CreateSession({})` → `Session.RecordWindow({"window-id": <u64, el id de niri>,
   "cursor-mode": <u32> 0})` → `Session.Start()` y recibe `Stream.PipeWireStreamAdded(node_id)`; se conecta a ese nodo de
   PipeWire pidiendo DMA-BUF con modificadores (memoria compartida solo como respaldo). Todo desde una única conexión de
   D-Bus que vive lo que dura la sesión. Se captura solo esa ventana —nada de lo que tenga encima— y sin cursor: el cursor
   real lo sigue dibujando niri por encima, así que ni se retrasa ni se deforma. Al no pasar por el portal no sale el
   selector de ventanas; la sesión aparece en `niri msg casts` y muere al apagar. Desde 25.08 niri entrega cada
   fotograma ya renderizado; si el búfer trae un fence implícito, se espera (`DMA_BUF_IOCTL_EXPORT_SYNC_FILE`) antes de leer.
2. **Presentación encima.** `nameraka view` crea una superficie layer-shell con espacio de nombres `ocarina-nameraka` en
   la capa `overlay` de la salida de la ventana: anclada a los cuatro bordes, `exclusive_zone -1`,
   `keyboard_interactivity none` y **región de entrada vacía** (ratón, teclado y táctil siguen yendo a la app de debajo,
   como en Lossless Scaling). Cubre el panel 1:1 sin reescalar: búfer (fractional-scale-v1) + viewporter para que cada
   píxel del búfer caiga en un píxel físico (a escala 1,75, 1646 × 1,75 = 2880,5: el medio píxel sobrante se recorta en
   la copia, nunca se reescala). Verificado con un patrón de 1 px (docs/FLUIDO.md). Importa cada DMA-BUF en Vulkan (`VK_EXT_external_memory_dma_buf` + `VK_EXT_image_drm_format_modifier`, ambas
   en RADV) y lo copia a la swapchain FIFO con una pasada de cómputo (~0,3 ms a 2880×1800) que también aplica el
   atenuado por software de esa pantalla si lo hay (la capa `ocarina-dim` queda debajo de Nameraka).
3. **Generación** (`engine`; `auto`, el valor por defecto, usa `lsfg` si está disponible):
   - **`lsfg`**: **Lossless Scaling Frame Generation 3.1** a través de **lsfg-vk ≥ 2.0**, una capa Vulkan que se engancha
     al `vkQueuePresentKHR` del presentador e inserta los fotogramas generados entre cada dos que presenta. Necesita
     Lossless Scaling comprado en Steam y su rama `lsfg-vk`. La 2.0 usa FP16: de 2 a 3,5 veces más
     rápida en iGPU AMD que la 1.x según sus notas.
   - **`ia`** (alternativa libre, experimental): **RIFE** (red neuronal de interpolación; código y modelos MIT) con
     `ncnn` sobre Vulkan dentro del presentador: flujo óptico a resolución reducida, mezcla a resolución completa y pasos
     de tiempo arbitrarios; aquí el presentador marca su propio ritmo. **No pasó la puerta de rendimiento** (D-061,
     docs/FLUIDO.md): el RIFE empaquetado no compila con el ncnn actual, así que la interfaz lo muestra deshabilitado.
4. **Ritmo.** El presentador entrega cada fotograma **nuevo** una sola vez (deduplicado) y nunca más deprisa de lo que
   permite la pantalla. lsfg-vk solo tiene ritmo `vsync`: presenta los generados en cuanto los tiene y FIFO los reparte
   uno por refresco, así que va perfecto **solo cuando base × multiplicador = Hz** (cada fotograma, un refresco). Si
   no, los generados salen seguidos y el real se queda varios refrescos: 30 fps × 2 en 120 Hz da una cadencia 1-3, que
   se nota más que no generar nada. Por eso el valor por defecto es «A medida = Hz».

### Multiplicador efectivo
Hz = frecuencia actual de la salida (de `Niri`); base = fps reales del contenido. Modo fijo:
`m = max(1, min(elegido, ⌊Hz/base⌋))`. «A medida» con objetivo T (`customFps`; 0 = Hz):
`m = max(1, min(round(T/base), ⌊Hz/base⌋))`; con `ia`, exactamente T. `m = 1` es paso directo (lsfg-vk lo admite como
«bypass» y se recarga en caliente). Si T es otro modo de la pantalla (p. ej. 60 Hz), Nameraka puede pedir a `Displays`
ese modo mientras dura —y devolver el anterior al apagar— para que base × m = T. La tarjeta muestra siempre el resultado
real («×6 → ×4 · 120 Hz») y avisa ⚠ cuando base × m ≠ Hz.

| Contenido (base) | ×2 | ×4 | ×6 | A medida = 120 (por defecto) |
|---|---|---|---|---|
| 23,976/24 fps (cine, anime) | 48 ⚠ | 96 ⚠ | 120 (×5) | **120 (×5)** |
| 25 fps | 50 ⚠ | 100 ⚠ | 100 ⚠ (×4) | 100 ⚠ (×4) |
| 30 fps | 60 ⚠ | **120** | 120 (×4) | **120 (×4)** |
| 60 fps | **120** | 120 (×2) | 120 (×2) | **120 (×2)** |

⚠ = base × m ≠ 120: tirones (con 30 → 60 se puede evitar con «A medida 60» y la pantalla a 60 Hz). 25 y 50 fps no
dividen 120 ni 60: con `lsfg` siempre irán algo irregulares; con `ia` y VRR (`vrrWhileActive`: solo con `ia`, que marca
su ritmo, si el panel lo admite sin parpadeo y las medidas lo confirman) irían regulares. ×6 brilla con fuentes de
≤ 20 fps o en monitores de 144 Hz (24 × 6 = 144).

**Base**: intervalos entre fotogramas nuevos (marcas de tiempo de PipeWire) → mediana de los 32 últimos → se ajusta a
10 · 12 · 15 · 20 · 23,976 · 24 · 25 · 29,97 · 30 · 48 · 50 · 59,94 · 60 si está a ±3 %; un cambio solo se aplica si dura
> 1 s. Sin fotogramas nuevos (pausa del vídeo) no se presenta nada y la pantalla conserva el último. **Duplicados**:
niri puede entregar repintados sin cambios; se descartan con `SPA_META_VideoDamage` si viene y, si no, con una firma en
la GPU (luminancia a 1/16 comparada con la anterior, ~0,1 ms).

### Estados
`off → arming → starting → active ⇄ paused → off` (+ marcas `adjusted`, `blocked`, `unavailable`; textos y kanji en
`kanji-ui.json` → `namerakaStatus`). Los decide el daemon con los eventos de niri; lo que niri no publica (bloqueo,
pantalla apagada por inactividad, popups de la shell) se lo manda la shell con `pause`/`resume`.
- **Objetivo**: la ventana con el foco al encender (la última ventana enfocada; el foco de las superficies de la shell
  —Engawa, Torii…— no cuenta, así que abrir Engawa no lo cambia).
- **active** solo si el objetivo existe, está a pantalla completa (niri 26.04 no tiene ese campo: `layout.window_size`
  = tamaño lógico de su salida ±1 px y, si viene, `tile_pos_in_workspace_view` = (0, 0); si una versión futura trae un
  campo explícito, se usará ese), ninguna otra **ventana** ha tomado el foco, su espacio está visible y no hay vista general, bloqueo
  ni pantalla apagada.
- **paused**: se destruye la superficie (se ve la ventana real) pero se mantienen captura y presentador: volver tarda
  < 150 ms. Si el objetivo deja la pantalla completa estando activo → **arming** (60 s); si se cierra → **off**.
- **arming** (al encender sobre una ventana que no está a pantalla completa): la isla dice «Pon el vídeo a pantalla
  completa». En navegadores eso es la tecla F o el botón ⛶ del reproductor (la pantalla completa de la ventana sería la
  del navegador, F11, no la del vídeo); en reproductores (mpv, Celluloid, Haruna, VLC…) la isla ofrece además el botón
  «Pantalla completa» (acción `FullscreenWindow` con su `id`; es un conmutador: solo se llama si no lo está y, al
  apagar, se deshace solo si la puso Nameraka). Arranca en cuanto lo esté; se cancela a los 60 s.
- **Automático** (`autoOnFullscreenVideo`, apagado por defecto): cuando una ventana pasa a pantalla completa y un
  reproductor MPRIS de esa misma app (identidad o `desktop entry` ↔ `app_id`) está en «Playing», Nameraka arranca solo;
  nunca con ventanas de `exclude[]` ni de gamescope. Así no hace falta capturar nada para «adivinar» si hay vídeo.
- **Apagar**: la capa desaparece en el siguiente fotograma, `Session.Stop()`, el audio vuelve a su salida y el ayudante
  (daemon y presentador, sin superficie ni captura) queda en caliente 60 s.
- **Vigilante**: si el presentador no presenta nada en 1 s estando activo (GPU colgada, FIFO bloqueado), el daemon lo
  mata: una capa opaca congelada nunca puede quedarse tapando la pantalla. Y `ocarina nameraka off` hace
  `systemctl --user stop ocarina-nameraka.service` si el socket no responde en 300 ms (05-RESCATE).
- **Capas**: sobre una ventana a pantalla completa niri oculta la capa `top`, así que todo lo de la shell que deba verse
  encima de un vídeo (Engawa, Fumi, OSD, Dengen) vive en `overlay`; dentro de una capa, la superficie mapeada después
  queda encima. Al pasar a `active`, la shell vuelve a mapear sus popups abiertos y muestra el OSD en una
  superficie propia de vida corta (se mapea después del presentador). Si niri no lo respetara, Nameraka pasa a
  `paused` mientras se vean.

### Audio sincronizado
Generar retrasa la imagen ≈ 1 fotograma base + cálculo (30 fps → unos 45 ms; se nota en los labios). Con `avSync`
(apagado por defecto; Ajustes › 滑 Nameraka) el ayudante retrasa igual el audio de esa app: crea un sumidero de retardo
(`pw-loopback --delay`) hacia la salida actual y mueve allí los flujos de la app objetivo (por PID y sus hijos; también
los que nazcan mientras dura) con el metadato `target.object`; al apagar borra el metadato y WirePlumber los devuelve a
la salida por defecto sin guardar destino. En `paused` más de 2 s el audio vuelve a su salida y se retrasa de nuevo al reanudar. Retardo
`D = 1000/base + t_gen + 1,5 × 1000/Hz` ms (`t_gen` de la calibración); solo se reajusta si cambia > 10 ms. El sumidero
declara latencia 0: si la declarase, los reproductores la compensarían retrasando también la imagen y no se ganaría nada.
`scripts/fluido-av-test.sh` (destello + pitido) comprueba la sincronía.

### Energía, calidad y calibración
- 忍 Shinobi lo apaga y lo bloquea (la tarjeta lo dice). En batería, `battery`: `eco` (por defecto: modo rendimiento +
  flujo −25 %), `normal` u `off`. 鬼 Oni: calidad máxima.
- **Guardias** (con lo que ya mide el ayudante y, solo mientras está activo, `gpu_busy_percent` y `Tctl` cada 1 s): GPU
  ≥ 95 % durante 3 s, fotogramas tarde o `Tctl` ≥ 95 °C 10 s → baja un escalón: flujo −0,15 → modo rendimiento →
  multiplicador con ritmo perfecto inferior (p. ej. 30 → 60 con la pantalla a 60 Hz) → paso directo con aviso. La
  tarjeta dice «ajustado». Nunca sube solo (nada de oscilaciones) hasta que cambies de modo.
- **Calibración**: `lsfg-vk-cli benchmark -w <ancho> -h <alto> -m <N>` a la resolución de cada pantalla, para
  N ∈ {2…6} × flujo {1 · 0,75 · 0,5} × modo rendimiento (cómo fijar flujo y modo: `--help` del CLI o
  `LSFGVK_FLOW_SCALE`/`LSFGVK_PERFORMANCE_MODE`) → `~/.local/state/ocarinashell/nameraka/calibration.json` (fps base máximos
  de cada combinación, `t_gen` y la huella de la DLL). Se usa la de más calidad cuyo máximo ≥ 1,3 × la base necesaria.
  `flowScale` y `performance` a `null` = lo que diga la calibración. Se recalibra al actualizarse lsfg-vk o Mesa
  (Mamori), cuando cambia la huella de la DLL (la comprueba el daemon al arrancar: Steam la actualiza por su cuenta) y
  con «Calibrar» en Ajustes.
- **Configuración de lsfg-vk propia y aislada**: `~/.local/state/ocarinashell/nameraka/lsfg.toml`; el daemon lanza el
  presentador con `LSFGVK_CONFIG=<ese fichero>` y `LSFGVK_PROFILE=nameraka`, así el `~/.config/lsfg-vk/conf.toml` de los
  juegos queda intacto. `version = 2`, `[global]` (`allow_fp16 = true`; `dll` solo si no la encuentra en la biblioteca de
  Steam) y un `[[profile]]` `nameraka` con `multiplier`, `flow_scale` y `performance_mode` (las tres se recargan en
  caliente con renombrado atómico: pasar de ×2 a ×4 no corta nada) y `pacing_mode = "vsync"`. La calibración y el
  `self-test` corren con `DISABLE_LSFGVK=1`.
- **Exclusiones**: nunca sobre superficies de OcarinaShell, ventanas de gamescope ni juegos que ya usen lsfg-vk (se
  generaría dos veces); lista por app-id en Ajustes. Para juegos es mejor lsfg-vk directo, por juego (menos latencia que
  capturar): perfiles en Settei → 鬼 Oni.
- **Reglas de capa de niri**: `ocarina-nameraka` queda fuera de la regla `^ocarina-` (sin sombra ni efectos), como
  `ocarina-dim`.

### Procesos y ficheros
- `native/nameraka/` (C++20 + meson; dependencias de los repos oficiales: `vulkan-headers`,
  `vulkan-icd-loader`, `wayland`, `wayland-protocols`, `libpipewire`, `libdrm`, `systemd-libs` (sd-bus), `glslang`;
  `wlr-layer-shell-unstable-v1.xml` de `wlr-protocols` o copiado con su licencia MIT; `ncnn` solo con `-Dia=enabled`).
  Un binario, `~/.local/libexec/ocarinashell/nameraka`, con tres modos:
  - `daemon`: activado por socket (`ocarina-nameraka.socket` → `$XDG_RUNTIME_DIR/ocarinashell/nameraka.sock`); máquina de
    estados, eventos de niri, D-Bus ScreenCast (sd-bus), audio, `lsfg.toml`, calibración, guardias y vigilante. Se
    cierra tras 60 s apagado.
  - `view`: el presentador (PipeWire + Wayland + Vulkan), hijo del daemon con el entorno del motor (`LSFGVK_*`, o
    `DISABLE_LSFGVK=1` con `ia`); cambiar de motor = relanzar el hijo. El origen de captura va detrás de una interfaz:
    cuando niri tenga `ext-image-copy-capture` con origen de ventana, se cambia a él (menos latencia, sin D-Bus).
  - `self-test [--json]`: comprueba por etapas y por motor. Códigos: 0 ok · 10 sin ScreenCast de niri · 11 sin
    layer-shell o fractional-scale · 12 sin Vulkan/DMA-BUF · 13 sin lsfg-vk · 14 sin la DLL de Lossless Scaling · 15 sin
    ncnn o sin modelos (solo `ia`). Lo lanza `ocarina-nameraka-selftest.service` (oneshot al iniciar sesión, `Nice=19`)
    y escribe `~/.local/state/ocarinashell/nameraka/selftest.json` (resultado por etapa y por motor + huella de la DLL),
    que la shell lee con `FileView`: así sabe `available` y el motivo sin arrancar nada. 10–12 ocultan la tarjeta; 13–15
    la muestran con el motivo (si el otro motor sirve, se usa ese). También lo usan `ocarina doctor` y Mamori.
- **Protocolo de control** (líneas JSON por el socket): órdenes `start {window, engine, mode, fps, flow, perf, avSync}` ·
  `set {…}` · `pause` · `resume` · `stop` · `status` (respuesta única: estado, motivo, ventana, salida, base, m, fps de
  salida, Hz, motor, `late`, `latency_ms`, `gpu`) · `stats {on}` · `calibrate`; eventos `state {state, flags, reason,
  window, output}` · `stats {…}` (1/s y solo con `stats on`, es decir, con Engawa u OSD visibles) · `error {code, msg}`.
- **Shell**: `services/Nameraka.qml` (cliente `Socket` + `FileView` de `selftest.json`), `modules/engawa/FlowCard.qml` +
  página Fluido, estados de la isla (armando) y OSD, y página 滑 de Settei. `scripts/install.sh` compila el ayudante
  (meson) y enlaza las unidades.

### Descartado (y por qué)
mpv + VapourSynth/RIFE: solo serviría en mpv. lsfg-vk directo en el navegador: Firefox (GL) y Chromium en Wayland no
presentan por una swapchain de Vulkan, así que no hay dónde engancharse; el presentador se la da. Un segundo `qs` como
presentador: QML no consume nodos de PipeWire en Vulkan y cargaría la shell. Capturar la salida completa: incluiría la
propia capa (bucle) y niri tapa en negro lo bloqueado con `block-out-from`.

### Límites (sin maquillar)
Solo pantalla completa (como Lossless Scaling). Latencia de ≈ 1 fotograma base (el audio se compensa; para juegos,
lsfg-vk directo). Texto que se mueve rápido o desplazamientos bruscos pueden mostrar artefactos (como en Lossless
Scaling; menos cuantos más fps base). Contenido de 25/50 fps: algo irregular con `lsfg`. Sin HDR. Vídeo con DRM: en
Linux los navegadores lo componen como cualquier otro, así que debería capturarse, pero no se ha probado con servicios
de streaming: no se promete.
