# 船 Fune — apps de Windows: cómo empezar, medidas y configuración ganadora

## Cómo empezar
1. En el instalador, marca el grupo **船 Fune** (Podman sin root, FreeRDP, passt, crun) o instálalos luego con pacman.
   Necesitas KVM (`/dev/kvm`), unos 70 GB libres y 6 GB de RAM para la VM.
2. `ocarina fune create`: descarga Windows 11 y lo instala solo (≈ 8 GB y unos 26 min). La contraseña de la VM es
   aleatoria y vive en gnome-keyring; nunca la escribes.
3. `ocarina fune scan` detecta las apps instaladas y crea sus accesos: aparecen en Torii (con la insignia 船) y en
   «Abrir con» de Nautilus. Super+Alt+W abre el panel; `ocarina fune desktop`, el escritorio entero.
4. Si la app tiene versión web, mejor `ocarina fune webapp <nombre> <url>`; si funciona con Wine, `ocarina fune wine help`
   (sin VM, cero sobrecoste).
La VM se pausa sola a los 10 min sin ventanas de Windows (0 % CPU) y se apaga tras 30 min en pausa (Ajustes › 船 Fune).
Si algo falla: 05-RESCATE.

Medido en la fase 12.

Medido el 2026-10-17 en el P14s Gen 6 (Ryzen AI 7 PRO 350, 23 GB útiles, OLED 2880×1800 a 1,75), con batería y
忍 Shinobi activo, Windows 11 Pro 24H2 en dockur 6.06 (4 vCPU · 6 GB · disco de 96 GB), Podman 6.1 sin root,
FreeRDP 3.32.2 bajo xwayland-satellite 0.8.3 en niri 26.04. Decisiones: D-062.

## Medidas

| Qué | Resultado | Cómo |
|---|---|---|
| Instalación desatendida | descarga 8 GB + instalación ≈ 26 min hasta el primer inicio de sesión | `ocarina fune create`, log de dockur |
| Abrir app con Windows **apagada** (arranque incluido) | **18,7–20,0 s** hasta la ventana con el archivo cargado | eventos de niri (`WindowOpenedOrChanged`) |
| Abrir app con Windows **en pausa** | **1,86 s** (reanudar 80–90 ms + hora + agente) · criterio < 2 s ✅ | ídem |
| Abrir app con Windows **activa** | **0,8 s** por el agente (conexión ya abierta) · 3,1 s si hay que abrir conexión | ídem |
| App de Wine (Notepad++, prefijo listo) | **5,1 s** | ídem |
| CPU en reposo con apps abiertas sin tocar (30 s) | QEMU **2,8 %** de un núcleo · xfreerdp3 **0,03 %** | `pidstat -u 30 1` |
| CPU en pausa | **0,00 %** | `pidstat -u 10 1` |
| RAM | QEMU 6,07 GiB residentes · xfreerdp3 548 MiB · disponible: 13,6 GiB activa o en pausa → **19,7 GiB apagada** | `ps`, `/proc/meminfo` |
| Apagado limpio | **12–14 s** (`shutdown.exe` dentro de Windows por el agente) | `ocarina fune stop` |
| Disco | 13 GiB usados de 96 (imagen dispersa en subvolumen NOCOW) | `stat` (bloques) |
| Procesos con Windows apagada | **0** (ni podman, ni conmon, ni FreeRDP, ni `podman events`) | `pgrep` |
| Puertos | 3389 tcp/udp, 7148, 8006 → solo `127.0.0.1` | `podman port`, `ss -tlnp` |

Sin medir todavía: eco de tecleo a 120 fps (`wf-recorder`), consumo extra de batería
(`scripts/bench-power.sh` con Windows activa · en pausa · apagada) y los modos `/gfx` (AVC444 frente a progresivo): los
548 MiB de xfreerdp3 son sobre todo cachés de gráficos a 2838×1675, el primer sitio donde mirar.

## Configuración ganadora de FreeRDP

```
xfreerdp3 <app>.rdp /v:127.0.0.1:3389 /u:ayoub /d: /cert:tofu
  /scale-desktop:175 /scale-device:180 /size:2838x1675
  /network:lan -wallpaper -menu-anims -window-drag +fonts /gfx +auto-reconnect
  /sound:sys:pulse /microphone:sys:pulse +home-drive [/drive:media,/run/media/$USER]
  /wm-class:fune-windows /log-level:WARN          + FREERDP_ASKPASS="ocarina-fune askpass"
```

- **Una sola conexión para todas las apps.** Dos conexiones RDP se roban la sesión de Windows (ventanas que no repintan
  ni se cierran). La primera app abre la conexión con `wscript.exe launch.vbs` → `launch.ps1` (oculto), que arranca la
  app y se queda como **agente** de esa sesión (puerto 7148, token del llavero, comparación en tiempo constante y
  peticiones acotadas, ideas de WinBoat). Las siguientes apps se piden al agente y aparecen en 0,8 s por la misma
  conexión. Si el programa inicial termina, RemoteApp deja de mostrar ventanas nuevas: por eso el agente es él.
- **`.rdp` temporal** (`remoteapplicationcmdline`): `/app:…,cmd:"…"` no admite comillas en FreeRDP 3.32 (llegan a
  Windows con las barras) y las rutas con espacios las necesitan.
- **`/size` = una columna maximizada de niri** y apps abiertas maximizadas dentro de Windows: niri no puede redimensionar
  una ventana RemoteApp (FreeRDP envía el tamaño y Windows contesta con el suyo). Win+F (`ocarina maximize`) alterna a la
  vez Windows (agente) y la columna (`set-column-width 100 % / 50 %`).
- `/scale-desktop` según la salida enfocada (175 en el panel): Windows dibuja nítido, sin doble escalado.
- `-wallpaper -menu-anims -window-drag +fonts`: lo que en RemoteApp no aporta fuera; ClearType sí.

## Límites conocidos

- Apps UWP puras (Calculadora): RemoteApp solo las muestra si son la primera app de la conexión → fuera de la lista
  por defecto (`ocarina fune scan --all` las añade).
- Mod+R (anchos predefinidos) no redimensiona las ventanas de Windows; Win+F sí.
- FreeRDP mapea ventanas auxiliares de la sesión (marcadora de RemoteApp, diálogos sin título): una regla las vuelve
  transparentes y el servicio Fune las saca del mosaico; asoma una esquina de 32×74 px sin dibujo.
- La primera conexión tras un corte brusco (`kill -9`) puede tardar: Windows mantiene la sesión colgada un rato. El CLI
  cierra siempre con SIGTERM (y SIGKILL solo con la VM ya apagada).
- Sin aceleración GPU dentro de la VM: apps 3D pesadas → Wine/Proton o no viables. Anti-cheat de kernel: no.
