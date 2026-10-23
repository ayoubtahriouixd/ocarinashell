# Fase 12 · 船 Fune: apps de Windows como ventanas nativas

**Objetivo**: cualquier programa de Windows que Ayoub necesite, funcionando dentro de OcarinaShell como si fuera nativo
(ventanas de niri, en Torii, abriendo sus archivos desde Nautilus), con el menor coste de batería y memoria posible y
sin ralentizar nada cuando no se usa.
**Lee antes**: `docs/DECISIONES.md` D-006, `docs/01-ARQUITECTURA.md` §16, mockup `09-fune.png`, `docs/02-DISENO.md` §5
(Fune), y la documentación ACTUAL (delega en un subagente) de WinApps (github.com/winapps-org/winapps), dockur/windows
(`docs/environment.md`), WinBoat (winboat.app) y FreeRDP 3 (`xfreerdp3 /help`).

## Estrategia: del más barato al más compatible
| Nivel | Cuándo | Coste |
|---|---|---|
| 0 · Web/PWA | la app tiene versión web (Office web, Teams, Outlook, consolas de administración…) | una ventana de Chrome `--app`; casi nada |
| 1 · Wine/Proton | la app funciona en Wine (WineHQ AppDB / ProtonDB / prueba real) | sin VM: `umu-run` + Proton de CachyOS + NTSYNC |
| 2 · Windows en KVM | todo lo demás (Office de escritorio, Visio, RSAT, Adobe…) | VM con pausa y apagado automáticos |

## Tareas
1. **Snapshot**.
2. **Entrevista** (AskUserQuestion): qué apps necesita (lista libre: clasifícalas por nivel investigando cada una);
   edición de Windows (11 Pro rec., con su licencia · 11 LTSC `11l`, más ligera, solo si tiene licencia Enterprise/LTSC);
   recursos (4 vCPU / 8 GB rec. · 6 / 12 para apps pesadas); motor (WinApps con la interfaz de OcarinaShell rec. ·
   WinBoat con su propia interfaz). Anota en DECISIONES.
3. **Prerrequisitos**: SVM activo en BIOS (`/dev/kvm`), `kvm_amd`, usuario en `kvm`; Docker + compose v2 con
   **activación por socket** (`docker.socket` habilitado, `docker.service` sin arranque permanente: sin Windows no corre
   nada) y usuario en `docker` (explica a Ayoub que ese grupo equivale a root; alternativa Podman si lo prefiere);
   FreeRDP 3 (`xfreerdp3`), `iproute2`, `libnotify`, `dialog`, `netcat` (lo que pida la versión de WinApps).
4. **Almacenamiento óptimo en Btrfs**: `~/.local/share/ocarinashell/fune` como **subvolumen** propio, `chattr +C` antes de
   crear el disco (NOCOW: sin fragmentación ni amplificación de escritura; sin compresión), fuera de cualquier config de
   snapper; disco de 64–128 GB que crece bajo demanda. Comprueba espacio libre antes.
5. **Windows con `dockur/windows`**: `config/fune/compose.yaml` versionado: `VERSION`, `RAM_SIZE`, `CPU_CORES`,
   `DISK_SIZE`, `USERNAME`/`PASSWORD` (contraseña aleatoria guardada en gnome-keyring con `secret-tool`, nunca en git),
   puertos SOLO en `127.0.0.1` (8006 web, 3389 tcp/udp), `/storage` en el subvolumen, carpeta compartida (pregunta:
   `~/` entero o solo `~/Documentos`), `restart: "no"`, `stop_grace_period: 2m`, `/dev/kvm` y `/dev/net/tun`,
   `NET_ADMIN`. Instalación desatendida: sigue el progreso en `http://127.0.0.1:8006` y avisa con notificación al acabar.
6. **Ajustes dentro de Windows** (script PowerShell por la carpeta compartida, revisado y ejecutado con permiso de
   Ayoub): escala 175 % (nítido a 2880×1800), efectos visuales «mejor rendimiento» (sin animaciones ni transparencias),
   sin apps de inicio superfluas, Windows Update con horas activas fuera de la ventana de mantenimiento, sin suspensión
   del invitado (la pausa la gestiona Fune), zona horaria Africa/Casablanca, RemoteApp habilitado (el `.reg` de WinApps).
7. **WinApps**: instalación de usuario, `~/.config/winapps/winapps.conf` (`chmod 600`): `WAFLAVOR="docker"`,
   `RDP_IP="127.0.0.1"`, credenciales por `RDP_ASKPASS` + `secret-tool` si la versión lo soporta (si no, `RDP_PASS` con
   el fichero en 600), `RDP_SCALE` y `RDP_FLAGS` afinados midiendo (parte de `/cert:tofu /sound /microphone +home-drive`
   y prueba `/network:lan`, modos `/gfx`, portapapeles), `AUTOPAUSE="on"` + `AUTOPAUSE_TIME` desde Ajustes,
   `FREERDP_COMMAND="xfreerdp3"`, `HIDEF` según pruebas. Detecta apps (oficiales + las de Ayoub) → `.desktop` con
   iconos y tipos MIME.
8. **Integración con niri**: RemoteApp es X11 bajo xwayland-satellite. Include generado `fune-rules.kdl`: ventanas de
   FreeRDP (app-id/clase real de la versión instalada) con anillo de foco **asagi `#00a3af`**, columnas normales;
   diálogos y menús flotantes. Verifica nitidez (sin doble escalado), mover/redimensionar, menús contextuales,
   portapapeles en ambos sentidos, archivos vía carpeta compartida y monitor externo.
9. **Wine/Proton (nivel 1)**: `umu-launcher` + Proton de CachyOS, un prefijo por app en
   `~/.local/share/ocarinashell/wine/<app>`, `.desktop` generados con icono y `Exec=umu-run …`, DXVK/VKD3D, NTSYNC si
   existe. Bottles solo si Ayoub quiere interfaz gráfica.
10. **Web/PWA (nivel 0)**: `ocarina fune webapp <nombre> <url>` → `.desktop` con `google-chrome-stable --app=<url>` y clase
    propia, icono en alta resolución y regla de niri. Ofrece las que tengan sentido.
11. **Servicio `Fune` + CLI + UI**: estado por `docker events` (sin sondeo); `ocarina fune start|pause|resume|stop|desktop|
    app <nombre>|status`; lanzar una app **reanuda solo** si la VM estaba en pausa (`docker unpause` → app en ~1 s) o la
    arranca si estaba apagada (aviso «Windows despertando…» en la isla); pausa automática sin ventanas RemoteApp durante N
    min (CPU 0, RAM retenida) y apagado tras M min en pausa (RAM liberada); arranque al iniciar sesión solo si Ayoub lo
    activa y hay cargador. Panel 船 (mockup 09) desde el indicador de Obi y `Mod+Alt+W`, página 船 Windows en Ajustes,
    insignia 船 en Torii.
12. **Modos**: Shinobi → pausa (y apagado si lleva > 5 min sin ventanas); Oni → pausa si no hay apps de Windows abiertas;
    Snake y Mamori consultan la RAM de la VM antes de cargar nada.
13. **Mantenible por Mamori** (fase 16): `ocarina fune update` (imagen de dockur y WinApps con la VM apagada; el disco se
    conserva), `ocarina fune maintenance` (1 h con cargador para Windows Update y apaga), `ocarina fune backup` (copia del
    disco con la VM apagada, `cp --sparse=always`), y pruebas de humo de Fune para `scripts/smoke-test.sh`.
14. **Medidas** (04-RENDIMIENTO §Windows) → `docs/WINDOWS.md`.

## Criterios de aceptación
- [ ] Una app de cada nivel que use Ayoub abre desde Torii como ventana de niri, nítida, con portapapeles y archivos.
- [ ] Pausa/reanudación automáticas verificadas (abrir desde pausa < 2 s); VM apagada → RAM liberada.
- [ ] Ningún puerto fuera de `127.0.0.1` (`ss -tlnp`); contraseña fuera de git y de ficheros legibles por otros.
- [ ] Captura del panel ≈ mockup 09. `docs/WINDOWS.md` con medidas y la configuración ganadora de FreeRDP.
- [ ] Si Ayoub eligió WinBoat: mismo resultado con su interfaz + reglas de niri + estado en la barra.

## Riesgos y límites (explícaselos a Ayoub)
Grupo `docker` = privilegios de root · licencia de Windows a su cargo · sin aceleración GPU dentro de la VM (apps 3D
pesadas → nivel 1 o no viables) · anti-cheat de kernel no funciona en VM · espacio en disco.

## Al terminar
PROGRESS.md, commit; explica a Ayoub en 4 líneas cómo abrir sus apps de Windows y qué hace la VM cuando no la usa.
