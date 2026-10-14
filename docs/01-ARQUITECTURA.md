# 01 · Arquitectura

## 1. Pila (verifica versiones reales en la fase 0 y anótalas en docs/SISTEMA.md)
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
| Apps de Windows | **WinApps** + `dockur/windows` (KVM) + **FreeRDP 3** RemoteApp; Wine/Proton (`umu-run`) para lo compatible | fase 12 (船 Fune); WinBoat como alternativa con interfaz propia |
| IA local | **蛇 Snake**: `llama-server` (llama.cpp con Vulkan en la Radeon 860M) o FastFlowLM en la NPU XDNA 2, bajo demanda | fase 15; modelo y backend elegidos por evaluación |
| Mantenimiento | **守 Mamori**: `bin/ocarina-mamori` (Python stdlib) + ayudante root `ocarina-maint` + Snake (Claude Code opcional) | fase 16; también funciona sin IA |

No hay más demonios de UI: ni waybar, ni mako/dunst/swaync, ni fuzzel/rofi, ni agentes polkit externos
(OcarinaShell ES el servidor de notificaciones y el agente polkit). La fase 0 detecta y retira conflictos.

## 2. Procesos (systemd --user, ligados a `graphical-session.target`)
| Unidad | Qué hace |
|---|---|
| `ocarinashell.service` | `qs -c ocarina` · `Restart=on-failure` · `RestartSec=1` · logs al journal |
| `ocarina-cliphist.service` | `wl-paste --watch cliphist store` (texto) |
| `ocarina-cliphist-img.service` | `wl-paste --type image --watch cliphist store` |
| `ocarina-sleep.service` | `swayidle -w before-sleep 'ocarina lock --wait' lock 'ocarina lock'` |
| `ocarina-nightlight.service` | `wlsunset` con los parámetros de Ajustes (la shell lo reinicia al cambiarlos) |
| `ocarinashell-safe.service` | modo seguro (`shell/safe/shell.qml`), lanzado por `OnFailure=` del servicio principal |
| `ocarina-postupdate.path` + `.service` | pruebas de humo en la sesión tras un hook de pacman (06-ACTUALIZACIONES) |
| `ocarina-mamori.timer` + `.service` | 守 Mamori: ciclo diario de salud, actualización y mantenimiento (`Nice=19`, IO idle, `Persistent=true`) |
| `ocarina-bootmark.service` | marca de arranque correcto (la usa Mamori para detectar kernels que no arrancan) |
| `ocarina-snake.service` | servidor de la IA local en `127.0.0.1`, arrancado bajo demanda y parado tras N min sin uso |
| `ocarina-hikae.timer` + `.service` · `ocarina-hikae-usb.service` | 控 Hikae: `ocarina backup now --if-due` a diario con CA y al montar el disco de copias (ligado a su `.mount`); `Nice=19`, IO idle |
Arranque: niri lanza la sesión (`niri-session`/`niri.service`) → `graphical-session.target` → unidades.
`spawn-at-startup` solo para lo que no admita systemd. `xwayland-satellite` lo gestiona niri.
El motor de contenedores de Fune (Docker) arranca **bajo demanda** por `docker.socket`: sin Windows, nada corre.

## 3. Repo → sistema (`scripts/install.sh`, idempotente)
Enlaces simbólicos con copia de seguridad previa (`*.ocarina-bak-<fecha>`):
`shell/ → ~/.config/quickshell/ocarina` · `config/niri/ → ~/.config/niri` · `config/ghostty/ → ~/.config/ghostty` ·
`config/nvim/ → ~/.config/nvim` · `config/fish/conf.d/ocarina.fish` · `config/starship.toml` · `config/<app>/…` ·
`bin/* → ~/.local/bin/` · `systemd/user/*` (servicios, timers y paths) `→ ~/.config/systemd/user/`.
Ficheros de root (`system/`) se instalan con `scripts/install-system.sh` (sudo), nunca por enlace.
⚠ Quickshell 0.3 no canonicaliza rutas: lanza SIEMPRE con `qs -c ocarina` (misma ruta = mismo id de shell).

## 4. Estructura QML (`shell/`)
```
shell.qml                 ShellRoot: crea módulos por pantalla (Variants sobre Quickshell.screens) y carga perezosa
config/                   Theme.qml, Motion.qml, Settings.qml, Paths.qml, Glossary.qml   (singletons)
services/                 Niri.qml, Time.qml, Audio.qml, Brightness.qml, Power.qml, Network.qml, Bt.qml,
                          Media.qml, Notifs.qml, Kisetsu.qml, Weather.qml, SysInfo.qml, Idle.qml, Modes.qml
                          (Shinobi/Oni), Fune.qml, Snake.qml, Mamori.qml, Clipboard.qml, Wallpapers.qml, Sounds.qml,
                          Recorder.qml, Displays.qml, Session.qml, Focus.qml, Backup.qml   (singletons)
components/               primitivas: Surface, GlassPanel, OText, OIcon (Material Symbols), Kanji, Hanko,
                          OButton, OToggle, OSlider, OSwitch, Segmented, Chip, Tile, ListRow, ScrollArea,
                          Tooltip, PopupPanel, Anim (NumberAnimation con Motion), Ripple, OcarinaLogo
modules/obi/              barra: Obi.qml, Workspaces.qml, FocusedTitle.qml, StatusCluster.qml, Tray.qml
modules/shima/            isla: Shima.qml (+ estados: Clock, Media, Osd, Peek, Recording, Rename, Shinobi, Oni, Focus)
modules/engawa/           centro de control + páginas Wi-Fi/Bluetooth/Audio
modules/fumi/             toasts + centro de notificaciones
modules/koyomi/           calendario + tiempo + 72 kō
modules/torii/            lanzador (+ providers/: Apps, Calc, Run, Web, Files, Windows, Kanji (+ kaomoji), Ssh, Settings, Actions)
modules/kura/  modules/techo/  modules/mihari/  modules/mado/  modules/cheatsheet/
modules/kagi/             bloqueo (LockContext.qml con PAM, LockSurface.qml, TestLock.qml)
modules/dengen/           menú de energía + Farewell.qml (despedida enlazada con Plymouth)
modules/polkit/           diálogo de autenticación
modules/settei/           app de ajustes (FloatingWindow) con una página por sección
modules/kabegami/         renderizador de fondo + explorador
modules/fune/             panel de apps de Windows (estado de la VM, recursos, apps, acciones)
modules/snake/            asistente de la IA local (panel, conversación, contexto, acciones con confirmación)
modules/iro/  modules/yomu/  modules/dim/   cuentagotas · leer y traducir · atenuación por software (07-IDEAS, D-009)
ipc/Ipc.qml               todos los IpcHandler
safe/shell.qml            modo seguro: solo tipos básicos (06-ACTUALIZACIONES, capa 4)
shaders/                  *.frag (fuente) + *.frag.qsb (compilado con `qsb`, se versiona)
pam/                      password.conf, fingerprint.conf  (PamContext.configDirectory)
assets/                   enlaces a ../assets (logo, datos, sonidos)
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
| `Network` | `Quickshell.Networking` (NetworkManager) | escaneo Wi-Fi solo con la página abierta |
| `Bt` | `Quickshell.Bluetooth` | descubrimiento solo con la página abierta |
| `Media` | `Quickshell.Services.Mpris` | jugador activo = el que reproduce, si no el último usado |
| `Notifs` | `NotificationServer` (acciones, imágenes, respuesta inline, persistencia) | historial en `~/.local/state/ocarinashell/notifications.json` (100 máx.) |
| `Kisetsu` | `assets/data/kisetsu-72.json` | 二十四節気 + 七十二候 + mes tradicional + fase lunar (cálculo local) |
| `Weather` | Open-Meteo (sin clave), cada 30 min, caché en disco | apagado en Shinobi; ubicación desde Ajustes |
| `SysInfo` | `/proc`, `/sys/class/hwmon`, `gpu_busy_percent`, `ps` | SOLO mientras Mihari está abierto |
| `Idle` | `IdleMonitor` ×N (atenuar/bloquear/apagar pantalla/suspender), `IdleInhibitor` (cafeína) | perfiles CA/batería |
| `Modes` (Shinobi · Oni) | orquestador único de modos de energía (ver §10) | excluyentes; snapshot del estado previo |
| `Fune` | `docker events --filter container=WinApps` con `SplitParser` (eventos, sin sondeo) + ventanas RemoteApp del servicio `Niri` | `docker stats` SOLO con el panel abierto; pausa automática; `available=false` si no hay Docker/FreeRDP |
| `Snake` | estado del servicio + API local (`/health`, OpenAI-compatible) solo cuando se usa | sin sondeo; el indicador 蛇 sale de `systemctl --user` vía `Process` al cambiar |
| `Mamori` | `FileView` con `watchChanges` sobre `~/.local/state/ocarinashell/mamori/status.json` y `history.jsonl` | solo lectura para la UI (indicador 新, página 守, notificaciones); disparo oportunista al estar inactivo 15 min |
| `Clipboard` | `cliphist list` bajo demanda | miniaturas en caché |
| `Wallpapers` | directorios de fondos + caché de miniaturas/difuminados (vips/magick) | |
| `Sounds` | `pw-play` con `Process` (sin QtMultimedia) | respeta DND, Shinobi y volumen de UI |
| `Recorder` | `gpu-screen-recorder` o `wf-recorder` | indicador en la isla |
| `Displays` (配置 Haichi) | salidas de `Niri` + `Quickshell.screens` | perfiles por huella de monitores → include `outputs.kdl` validado; `wl-mirror` solo al duplicar |
| `Session` (復元 Fukugen) | eventos de ventanas de `Niri` | guarda `session.json` agrupando 30 s; restaura al entrar si se pide |
| `Focus` (集中 Shūchū) | tic de minutos de `Time` | solo vive mientras hay un bloque activo |
| `Backup` (控 Hikae) | `FileView` de `~/.local/state/ocarinashell/hikae/status.json` (lo escribe `ocarina backup`) | la UI nunca lanza `restic` salvo «Copiar ahora»/«Recuperar» |

## 6. Contrato IPC (`qs -c ocarina ipc call <destino> <función> [args]`)
| Destino | Funciones |
|---|---|
| `shell` | `version(): string` · `reload()` · `status(): string` |
| `audio` | `increment(step: string)` · `decrement(step: string)` · `mute()` · `micmute()` · `set(pct: int)` |
| `media` | `playPause()` · `next()` · `previous()` · `stop()` · `increment(step: string)` · `decrement(step: string)` |
| `brightness` | `increment(step: string, output: string)` · `decrement(step: string, output: string)` · `set(pct: int, output: string)` · `list(): string` (JSON: `name`, `label`, `kind` internal\|ddc\|soft\|none, `pct`) — `output` vacío = según `display.brightness.keysTarget`, `"all"` = todas (cada una en su escala) |
| `kbdlight` | `cycle()` · `set(level: int)` |
| `lock` | `lock()` · `isLocked(): bool` · `test()` (bloqueo falso de desarrollo) — **sin** `unlock()` |
| `launcher` | `toggle()` · `open(mode: string, query: string)` |
| `engawa` | `toggle()` · `open(page: string)` |
| `notifications` | `toggle()` · `dnd(state: string)` (`on/off/toggle`) · `clear()` |
| `power` | `toggle()` (menú Dengen) |
| `settings` | `toggle()` · `open(page: string)` (también `focusOrToggle()` por compatibilidad) |
| `techo` · `kura` · `mihari` · `mado` · `cheatsheet` | `toggle()` |
| `kabegami` | `browse()` · `set(path: string)` · `next()` |
| `workspace` | `rename()` |
| `shinobi` | `on()` · `off()` · `toggle()` · `status(): string` |
| `oni` | `on()` · `off()` · `toggle()` · `status(): string` · `autoOn()` · `autoOff()` (GameMode) |
| `fune` | `toggle()` (panel) · `start()` · `pause()` · `resume()` · `stop()` · `status(): string` |
| `snake` | `toggle()` (asistente) · `ask(text: string)` · `status(): string` |
| `mamori` | `status(): string` · `notify(json: string)` (lo llama el orquestador para avisos y el indicador 新) |
| `theme` | `set(id: string)` · `get(): string` · `accent(hex: string)` |
| `record` | `toggle()` · `region()` |
| `osd` | `show(kind: string, value: string)` (interno) |
| `displays` | `arrange()` (Settei → Pantalla) · `identify()` · `mirror(on: bool)` · `profile(name: string)` · `list(): string` |
| `focus` | `start(minutes: int)` · `stop()` · `status(): string` |
| `session` | `save()` · `restore()` · `status(): string` |
| `backup` | `now()` · `status(): string` · `restore(path: string)` (abre Recuperar en la página 守; vacío = sin preselección) |
| `iro` | `pick()` · `status(): string` |
| `yomu` | `region(translate: bool)` · `status(): string` |

## 7. CLI `ocarina` (bash, `bin/ocarina`) — los binds llaman SIEMPRE a esto
- Traduce a IPC y, **si la shell no responde, usa un respaldo** para que las teclas nunca mueran:
  `audio` → `wpctl …`; `brightness` → `brightnessctl …` (interna) y `ddcutil --bus N setvcp 10 …` (externas, buses leídos de
  `brightness.json`; si no existe, `ddcutil detect`); `media` →
  `playerctl` si existe; `lock` → `swaylock -f`
  (tematizado); `launcher` → mensaje en `notify-send`. Bloquear SIEMPRE debe funcionar.
- Subcomandos: `audio up|down|mute|mic` · `brightness up|down [<paso>] [--output <salida>|--all]` · `brightness set <N> [--output <salida>|--all]` · `brightness list` · `media toggle|next|prev|up|down` · `launcher [modo] [texto]` ·
  `lock [--wait|test]` · `power` · `settings [página]` · `engawa` · `notifications [dnd on|off|toggle]` · `notes` · `clipboard` ·
  `tasks` · `rules` · `rename-workspace` · `wallpaper [browse|next|<ruta>]` · `shinobi [on|off|toggle|status]` ·
  `oni [on|off|toggle|status|auto-on|auto-off]` · `play <cmd…>` (gamescope + GameMode) · `quickterm` ·
  `fune [panel|start|pause|resume|stop|desktop|app <nombre>|webapp <nombre> <url>|status|update|maintenance|backup]` ·
  `snake [panel|ask "<texto>"|status|start|stop|eval|model <id>]` ·
  `mamori [status|run|pause <días>|resume|hold <pkg> <días>|unhold <pkg>|rollback|report]` ·
  `displays [arrange|identify|mirror on|off|profile <nombre>|list]` · `focus [<min>|stop]` · `session [save|restore]` ·
  `backup [now [--if-due]|status|restore <ruta>|check]` · `pick-color` · `read [--translate]` · `ssh <host>` ·
  `theme <id>` · `record [region]` · `cheatsheet` · `update` · `doctor [--post-update|--quiet]` · `restart` ·
  `logs [-f]` · `version`.
- `lock --wait`: pide el bloqueo y espera (máx. 2 s) a `isLocked()==true` para que `swayidle -w` no suspenda antes.

## 8. Ajustes (`~/.config/ocarinashell/settings.json`, `FileView` + `JsonAdapter`, cambios en vivo)
Esquema con `"version": 1` y migraciones. Secciones (claves orientativas; defínelas en `config/Settings.qml`):
`appearance {theme, accent, autoTheme{enabled, day, night}, blur, transparency, animSpeed, radius, kanjiDecor, screenCorners, uiFont, jpFont, displayFont, fontScale, reducedMotion}` ·
`bar {position, style, modules[], clock24, showSeconds, showWeather, showKisetsu}` ·
`island {media, osd, notifPeek, recording}` ·
`display {nightLight{mode, temp, from, to}, brightness{keysTarget (focused|internal|all; por defecto focused), ddc, softFallback, timeCurve, perOutput{"<fabricante>|<modelo>|<serie>": {alias, min, last, day, night}}}, profiles{"<huella>": {name, kanji, outputs{"<fabricante>|<modelo>|<serie>": {mode, scale, transform, vrr, position, enabled, primary}}}}, autoProfile, notifyOnConnect, mirrorDnd, lidCloseToExternal}` (escala, Hz y VRR de cada pantalla viven SOLO en su perfil: Haichi es el único dueño) ·
`oled {pixelShift, dimStatic, lockDrift}` · `focus {minutes, breakMinutes, dnd}` · `session {restore (ask|auto|off), exclude[]}` ·
`ssh {enabled, configPath, prodHosts[]}` · `backup {enabled, repos[], keep{daily, weekly, monthly}, exclude[], includeFune}` ·
`extras {touchGestures, iro, yomu, kaomoji, wifiQr, vpnTile, worldClocks[]}` (interruptores de 07-IDEAS) ·
`audio {uiSounds, uiVolume}` · `power {chargeLimit, lowBattery, autoShinobiAt, exitShinobiOnAC}` ·
`shinobi {refresh60, boostOff, bluetoothOff, brightnessCap, brightnessCapExternal, kbdLightOff, wifiPowersave, pauseServices[], gpuLow, funeStop}` ·
`oni {auto, onBattery, gpuLevel, fanMax, kishin, vrrGames, dnd, gamescopePreset, funePause}` ·
`fune {enabled, autopauseMin, autostopMin, startOnLoginAC, cpus, ramGB, scale, rdpFlags, pinnedApps[], maintenanceWindow}` ·
`snake {enabled, backend (vulkan|npu|lemonade), model, keepAliveMin, minFreeRamGB, onBattery, assistant, contextSources[]}` ·
`mamori {enabled, requireAC, minBattery, allowMetered, soakDays, soakDaysNoAI, ai (snake|claude|both|off), claudeBudget, firmware (approve|auto|off), autoReboot, autoImprove, quietHours}` ·
`lock {fingerprint, showNotifications, showMedia, blurWallpaper}` · `idle {ac{dim,lock,screenOff,suspend}, battery{…}}` ·
`input {layouts[], repeatDelay, repeatRate, ffm, warpMouse, naturalScroll, tap, trackpointSpeed}` ·
`notifications {dnd, dndSchedule, timeout, position, privacyOnLock, perApp{}}` · `weather {lat, lon, place, units}` ·
`launcher {frecency, webEngine}` · `wallpaper {path, perTheme, rotate}`.
Lo que afecta a niri se escribe en includes generados (`~/.local/state/ocarinashell/niri/*.kdl`) y niri recarga solo.

## 9. Motor de temas (`bin/ocarina-theme`, Python stdlib)
`assets/data/themes/<id>.json` + acento elegido → **tokens resueltos** en `~/.local/state/ocarinashell/theme.json` →
plantillas `templates/**` (sintaxis `{{token}}`) → destinos: niri `colors.kdl`, Ghostty `themes/ocarina`,
Neovim `palette.lua`, fish/fzf/eza/bat, starship, btop, yazi, fastfetch, GTK3/4 `gtk.css`, qt6ct, swaylock,
gsettings (`color-scheme`, `gtk-theme`, `icon-theme`, `cursor-theme`, `accent-color`), papirus-folders.
Recargas: niri (auto), Ghostty (señal/acción de recarga de la versión instalada), Neovim (vigila el fichero con
`vim.uv.new_fs_event`), la shell (FileView con `watchChanges` → todos los colores con `ColorAnimation`).
Modo «Desde el fondo»: `matugen` → se mapean sus colores a nuestros tokens.

## 10. Modos de energía: 忍 Shinobi y 鬼 Oni (orquestación)
Un único estado `normal | shinobi | oni`. Oni (fase 11) aplica el camino inverso a Shinobi: PPD `performance`
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
- Snake: servidor solo en `127.0.0.1`; sin ejecución libre de comandos; lo descargado de internet se trata como dato.
- Ideas (07-IDEAS): Yomu hace el OCR y la traducción en local y borra la captura; Hikae cifra con `restic` y guarda la
  contraseña en gnome-keyring; Honban solo lee los nombres `Host` de `~/.ssh/config` (nunca claves ni `known_hosts`).
- Ninguna telemetría. Peticiones de red solo: Open-Meteo (tiempo), Wallhaven si se activa y el destino de Hikae.

## 12. Verificación y herramientas
- `scripts/shot.sh <nombre> [región]` → `grim` (salida eDP-1) en `docs/evidencias/…`; `scripts/compare.sh <shot> <mockup>`
  → montaje con la diferencia para revisarlo con Read.
- Logs: `journalctl --user -u ocarinashell -f`. Arranque de depuración con `QSG_VISUALIZE=changes` o
  `QSG_RENDER_TIMING=1` en una instancia de prueba (`qs -p shell/shell.qml` con otro id).
- `scripts/doctor.sh` / `ocarina doctor`: versiones, servicios, conflictos (otro demonio de notificaciones o polkit),
  fuentes, enlaces, sudoers temporal pendiente, permisos del helper, estado de snapper, estado de Fune, brillo
  (`i2c-dev` cargado, `ddcutil detect` sin root, pantallas y su tipo internal/ddc/soft).
- Hooks de Claude Code: validación tras cada edición (`scripts/hooks/validate.sh`) y guardia de comandos peligrosos.

## 13. Degradación elegante
Sin blur (niri < 26.04 o Shinobi) → superficies opacas al 94 %. Sin huella → solo contraseña. Sin batería (CA) →
oculta batería. Sin Bluetooth → oculta mosaico. Sin red → tiempo desde caché con aviso. Sin Docker/FreeRDP → Fune
oculto. Pantalla externa → barra en cada salida, isla solo en la principal (configurable), bloqueo en todas.
Sin `ddcutil`/acceso I²C → brillo externo por software. Sin `restic`, `tesseract`, `wl-mirror` o `qrencode` → esa
función se oculta con la pista del paquete que falta. Sin `niri msg pick-color` (niri < 25.05) → cuentagotas oculto.

## 14. Resiliencia, actualizaciones y mantenimiento autónomo
Obligatoria desde la fase 3: ver `docs/06-ACTUALIZACIONES.md` (6 capas: snapshots/LTS, paquetes oficiales, código que no
se cae, modo seguro, pruebas de humo con reversión automática y 守 Mamori, el piloto automático).

## 15. Cadena de arranque y apagado
Limine (tema en `assets/boot/limine/`, probado en QEMU) → Plymouth (`assets/boot/plymouth/ocarinashell/`, script con capas)
→ greeter (fase 6) → sesión; y Dengen → `Farewell` → Plymouth de apagado. Misma variante (oscura/clara) en toda la
cadena; el icono ocupa la misma posición (centro al 42 % del alto) en Plymouth, greeter y despedida. Fase 13.

## 16. 船 Fune — apps de Windows (fase 12)
Tres niveles, del más barato al más compatible: **web/PWA** (si la app tiene versión web, ventana de Chrome `--app`) →
**Wine/Proton** (`umu-run` + `proton-cachyos`, NTSYNC; cero sobrecoste de VM) → **Windows en KVM** (`dockur/windows`
gestionado por WinApps, disco en subvolumen Btrfs NOCOW fuera de snapper, apps como ventanas nativas vía FreeRDP 3
RemoteApp bajo xwayland-satellite, accesos `.desktop` con iconos y tipos MIME → aparecen en Torii y en Nautilus).
La shell aporta la interfaz (panel 船, indicador en Obi, reglas de ventana) y el ahorro (pausa automática, Shinobi/Oni).

## 17. 守 Mamori — mantenimiento autónomo (fase 16)
Orquestador determinista `bin/ocarina-mamori` (Python stdlib) lanzado por `ocarina-mamori.timer` y por la shell al
estar inactiva: comprueba condiciones (cargador, red sin límite, sin Oni/llamada/grabación, usuario inactivo) → salud
y autorreparación → inventario (pacman/AUR/noticias/CVE/firmware) → política (maduración, seguridad, AUR, retenciones
sin actualizaciones parciales) → snapshot → actualización vía ayudante root `ocarina-maint` (lista blanca + sudoers
mínimo) → pruebas de humo → adaptación (IA) o reversión → informe. La IA es **Snake** (local, fase 15): investiga,
revisa y propone arreglos con salidas JSON validadas; Claude Code (`claude -p "/mantener"` desde el espacio aislado
`~/.local/share/ocarinashell/mamori-claude/`, cuyo perfil es `.claude/mamori-settings.json`) es un extra opcional.
Sin IA, modo determinista.
Estado en `~/.local/state/ocarinashell/mamori/` (`status.json`, `plan.json`, `holds.json`, `history.jsonl`).

## 18. 蛇 Snake — IA local (fase 15)
Servidor OpenAI-compatible en `127.0.0.1` (llama.cpp Vulkan en la iGPU por defecto; NPU XDNA 2 con FastFlowLM si es
estable y gana en la evaluación), arrancado bajo demanda y parado tras N min sin uso. Cliente `bin/ocarina-snake`
(Python stdlib) con tareas de esquema fijo (`triage-news`, `review-changelog`, `scan-issues`, `review-pkgbuild`,
`diagnose`, `propose-patch`, `report`, `assist`, `translate`) y recuperación de información de una lista blanca de fuentes.
Snake nunca ejecuta nada: propone; Mamori (o el usuario, con confirmación en el asistente) dispone. Modelo elegido y
reevaluado cada mes con `snake/evals/`. 0 MB de RAM en reposo; bloqueado en Shinobi y Oni.
