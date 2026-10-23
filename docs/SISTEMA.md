# Sistema real — el equipo de referencia

> Foto del ThinkPad de Ayoub el 2026-10-14 (fase 0), antes de instalar OcarinaShell: datos medidos en la máquina, no de
> memoria. La columna «Consecuencia» dice qué se hizo con cada hallazgo. Las versiones de hoy, en `docs/COMPAT.md`;
> lo que hay en tu equipo, en `ocarina doctor`.

## Resumen y sorpresas
| | Hallazgo | Consecuencia |
|---|---|---|
| ⚠ | **RAM: un solo módulo DDR5 SODIMM de 32 GB a 5600 MT/s**, la otra ranura vacía (un canal). No es LPDDR5X a 7500. La BIOS reserva **8 GB para la iGPU** (UMA): Linux ve 23 GiB. | La Radeon 860M y la NPU tienen la mitad del ancho de banda de un doble canal: Oni y Snake se midieron con esto (JUEGOS.md, SNAKE.md). Un segundo módulo igual (2×16 o 2×32) sería la mejora de hardware más rentable. Bajar la UMA a 2–4 GB en la BIOS devuelve RAM al sistema (Vulkan usa GTT igualmente). |
| ⚠ | **niri arranca a pelo** desde `login` en tty1 (`-fish` → `niri`), sin `niri-session` ni gestor de pantalla. | `graphical-session.target` está **inactivo**: ningún servicio `ocarina*` arrancaría. La fase 1 pasó el arranque a `niri-session`; la 13 añadió el greeter propio (greetd, opcional; D-014). |
| ⚠ | La pantalla va a **60 Hz** (modo 0 de 2880×1800); el panel admite 120 Hz y VRR. | La fase 1 fijó `2880x1800@120`; VRR por pantalla en Ajustes → Pantalla (ENERGIA.md). |
| ⚠ | `~/.config/niri/config.kdl` es la plantilla por defecto con `spawn-at-startup "waybar"` (waybar no está instalado) y un bloque `output` comentado con `1920x1080@120.030`/`scale 2`. | Sustituida entera en la fase 1 (con copia de seguridad). |
| ✓ | Zona horaria estaba en Europe/Amsterdam y formatos `nl_NL`. | Corregido con permiso de Ayoub: **Africa/Casablanca** + todo `es_ES.UTF-8` (D-016). La sesión gráfica actual conserva las variables viejas hasta el próximo inicio de sesión. |
| ✓ | `paru` instalado era `paru-bin` del AUR compilado contra `libalpm.so.15`: **roto** tras actualizar pacman. | Sustituido por `paru` del repo `cachyos` (2.1.0-3). |
| ✓ | `yay` ya no está (lo quitó Ayoub: snapshot 33/34). Kernel **LTS ya instalado** y en el menú de Limine. | — |
| ℹ | `xdg-desktop-portal-gtk.service` en estado *failed* (se lanzó sin entorno gráfico). | Resuelto en la fase 1 con `niri-session` (portales gnome+gtk). |
| ℹ | `thinkpad_acpi fan_control=N`: `/proc/acpi/ibm/fan` es de solo lectura (`level auto`). | Para que Oni pueda poner el ventilador al máximo: `options thinkpad_acpi fan_control=1` con `scripts/root/fase-11.sh` (opcional; 05-RESCATE). |

## Sistema
| | |
|---|---|
| Mirrors | ordenados con `cachyos-rate-mirrors` desde Marruecos (2026-10-14); copias `*-mirrorlist-backup` |
| Distribución | CachyOS rolling (`ID=cachyos`) · repos `cachyos-znver4`, `cachyos-core-znver4`, `cachyos-extra-znver4`, `cachyos`, `core`, `extra`, `multilib` + `[ocarina-aur]` (repo local de paru, último) |
| Kernel | `linux-cachyos` **7.2.10-1** (actualizado con `scripts/root/fase-00-sistema.sh`, snapshots 47–49; se arrancó con 7.2.9-2 y sus módulos siguen en disco por kernel-modules-hook hasta reiniciar) · `linux-cachyos-lts` 6.18.55-2 · headers de ambos |
| Línea del kernel | `quiet nowatchdog splash rw rootflags=subvol=/@ root=UUID=<uuid de la raíz>` (en `/etc/default/limine`, `KERNEL_CMDLINE[default]`) |
| pacman.conf | `Color`, `ILoveCandy`, `VerbosePkgLists`, `ParallelDownloads = 10` ya presentes · copia `/etc/pacman.conf.ocarina-bak-2026-10-14` |
| AUR | `paru` 2.1.0 (repo cachyos), libalpm 16.0.1 · sin `yay` |
| Locale | `LANG=es_ES.UTF-8` (todo) · `en_US`, `es_ES`, `nl_NL` generados · copia `/etc/locale.conf.ocarina-bak-2026-10-14` |
| Hora | Africa/Casablanca (+00), NTP sincronizado |
| Teclado | consola `es`, X11/xkb `es` modelo `pc105`; niri sin `xkb` explícito (hereda de localed) |
| Shell | fish 4.9.3 con `/usr/share/cachyos-fish-config/cachyos-config.fish` |
| Carpetas XDG | `xdg-user-dirs` instalado pero **sin** `~/.config/user-dirs.dirs` (no generadas aún) |
| Usuario | `ayoub` (UID 1000); nombre de equipo omitido |

## Arranque y disco
| | |
|---|---|
| Disco | SK hynix Platinum P41/PC801 `HFS001TEJ9X162N` 1 TB, firmware 51730A10, SMART PASSED, 0 % usado, 4,58 TB escritos, 1051 h |
| Particiones | `nvme0n1p1` vfat 4 GB → `/boot` (ESP) · `nvme0n1p2` Btrfs → resto. **Sin LUKS** (sin cifrado de disco) · swap = `zram0` (zstd, 23 GB) |
| Btrfs | `noatime,compress=zstd:1,ssd,discard=async,space_cache=v2` · subvolúmenes `@` `/`, `@home`, `@root`, `@srv`, `@cache` `/var/cache`, `@tmp` `/var/tmp`, `@log` `/var/log`, `.snapshots` |
| `/tmp` | tmpfs 11,6 GB (makepkg compila ahí) |
| Bootloader | **Limine 12.9.3** · `/boot/EFI/limine/limine_x64.efi` · config `/boot/limine.conf` (generada por `limine-entry-tool` 1.40 de `limine-mkinitcpio-hook`; tema CachyOS de diegons490, `timeout: 5`, `default_entry: 2`, `remember_last_entry: yes`) · fondo `/boot/limine-splash.png` |
| Entradas | `/+CachyOS` → `//linux-cachyos`, `//linux-cachyos-lts`, `//Snapshots` (`///<n> │ <fecha>` → `////linux-cachyos` / `////linux-cachyos-lts`, `rootflags=subvol=/@/.snapshots/<n>/snapshot`) · `BOOT_ORDER="*, *lts, *fallback, Snapshots"` |
| Initramfs | mkinitcpio 42.2 · `HOOKS=(base systemd autodetect microcode kms modconf block keyboard sd-vconsole plymouth filesystems)` · sin dracut |
| Plymouth | 26.134 · tema `cachyos` |
| Snapper | 0.13.2 · solo config `root` (la de `home` llegó en la fase 14: 控 Hikae, D-070) · `NUMBER_LIMIT=50`, `NUMBER_LIMIT_IMPORTANT=15`, timeline **desactivado** · `snap-pac` 3.0.1 (pre/post por transacción) · `limine-snapper-sync` 1.32.1 activo (`RESTORE_METHOD=replace`, máx. 30 entradas en el menú) · restauración: `limine-snapper-restore` |
| Snapshots OcarinaShell | **#37 «ocarinashell: antes de empezar»** · **#38 «ocarinashell: antes de fase 00»** · #47 «fase 00, antes de mirrors + actualización» (sin algoritmo de limpieza: no se borran solos) |
| Mantenimiento | `fstrim.timer` activo · `paccache.timer` activo (`PACCACHE_ARGS=-k3`) · `kernel-modules-hook` 0.1.7 + `linux-modules-cleanup.service` |

## Sesión
| | |
|---|---|
| Inicio | Sin display manager. `login` en **tty1** → fish → `niri` (sin `niri-session`): `XDG_CURRENT_DESKTOP` vacío, `XDG_SESSION_TYPE=tty`, `graphical-session.target` inactivo. Sesión logind 1 (seat0, tty1) |
| Wayland | `WAYLAND_DISPLAY=wayland-1` · `NIRI_SOCKET=/run/user/1000/niri.wayland-1.919.sock` |
| Servicios de usuario | pipewire, wireplumber, xdg-desktop-portal, xdg-document-portal, xdg-permission-store, gvfs, at-spi · `xdg-desktop-portal-gtk` *failed* |
| Portales | `xdg-desktop-portal`, `-gtk` (1.15.3) y `-gnome` (51.0, instalado en esta fase) |
| Conflictos | Ninguno en ejecución: sin notificadores (mako/dunst/swaync), sin barras, sin lanzadores, sin agente polkit de usuario. Solo `spawn-at-startup "waybar"` en la config de niri (binario ausente) y `~/.config/autostart/cachyos-hello.desktop` (niri no lee autostart XDG) |
| Terminal de entonces | Alacritty 0.17 (Ghostty pasó a ser la terminal en la fase 8) |
| Navegador | Firefox 157 (instalado) + **Google Chrome 155** (AUR, elegido por Ayoub) |

## Hardware
| | |
|---|---|
| Modelo | Lenovo ThinkPad P14s Gen 6 AMD · `21QL0020US` · BIOS **R2XET39W (1.19)** 2026-03-19 |
| CPU | AMD Ryzen AI 7 PRO 350 w/ Radeon 860M · 8C/16T · 623–5091 MHz · L3 16 MB · AMD-V (`svm`) |
| Memoria | 1 × 32 GB DDR5 SODIMM a **5600 MT/s** (ranura 2 vacía) · 8 GB reservados para la iGPU (`mem_info_vram_total`) · zram 23 GB |
| GPU | Radeon 860M (Krackan, `1002:1114`) · amdgpu · `card1` · `/sys/class/drm/card1/device/gpu_busy_percent` · `pp_dpm_sclk`: 600 / 640 / 3000 MHz · Vulkan 1.4.354, RADV KRACKAN1, Mesa 26.2.4 |
| NPU | XDNA 2 (`1022:17f0`) · módulo `amdxdna` (driver 0.10.0) · `/dev/accel/accel0` · firmware NPU **1.1.2.64** (`amdnpu/17f0_10/npu_7.sbin`) |
| Pantalla | eDP-1 · Samsung OLED `ATNA40HQ02-0` (EDID Lenovo, sin número de serie) · 300×190 mm · modos 2880×1800 @ 60 y **@ 120** (+ resoluciones menores a 60) · **VRR soportado** (desactivado) · escala 1,75 → **1645×1028** lógicos · entonces a 60 Hz |
| Brillo | `/sys/class/backlight/amdgpu_bl1` · `max_brightness=496000` (valor actual ≈ 101941) |
| DDC/CI | ddcutil 3.0.2 · solo el panel interno (`/dev/i2c-3`, «Invalid display», normal) · sin monitor externo conectado en la fase 0 |
| LEDs | `tpacpi::kbd_backlight` · `platform::mute` · `platform::micmute` · `tpacpi::{power,standby,thinkvantage,lid_logo_dot}` |
| Batería | `BAT0` · Li-poly `5B11H56417` · `energy_full` 49,52 Wh / diseño 52,5 Wh (**94 %**) · 112 ciclos · `power_now` (µW), `voltage_now`, `energy_now` · `charge_control_start_threshold`=0, `charge_control_end_threshold`=100 · `charge_behaviour` [auto] inhibit-charge force-discharge · cargador `AC` + 2 × `ucsi-source-psy-USBC000:00{1,2}` |
| Energía | `platform_profile`: low-power / **balanced** / performance · `amd-pstate-epp` (status active) · gobernador `powersave` · EPP `balance_performance` (opciones: default performance balance_performance balance_power power custom) · `cpufreq/boost=1` · power-profiles-daemon 0.30 (CpuDriver amd_pstate + platform_profile) · `ananicy-cpp` activo · suspensión `s2idle` únicamente |
| Ventilador | `thinkpad_acpi` · `/proc/acpi/ibm/fan` (level auto, `fan_control=N`) · hwmon `thinkpad` (fan1/fan2) |
| Sensores | hwmon: `k10temp` (Tctl), `amdgpu` (edge, PPT, sclk), `nvme` (Composite), `thinkpad` (CPU, temps), `acpitz`, `mt7925_phy0`, `BAT0`, `AC` |
| Huella | Synaptics **Prometheus** `06cb:00f9` · fprintd 1.94.5 detecta «Synaptics Sensors» · sin dedos registrados · firmware 10.01.4486791 |
| Cámara | `5986:11af` Bison «Integrated Camera»: RGB (`video0/1`) + **IR** (`video2/3`, «Integrated I») → Howdy posible, no previsto |
| Entrada | Teclado AT · TrackPoint `TPPS/2 Synaptics TrackPoint` · touchpad `ELAN0678:00 04F3:3195` (114×58 mm, tap desactivado por defecto) · táctil `ELAN901C:00 04F3:4406` (300×185 mm) · `ThinkPad Extra Buttons` |
| Wi-Fi | MediaTek **MT7925** (Wi-Fi 7, 160 MHz 2×2) · `mt7925e` · NetworkManager 1.58 (sin iwd) |
| Bluetooth | MediaTek `0e8d:e025` · `btusb`/`btmtk` · BlueZ 5.87 activo · el controlador se anuncia con el nombre del equipo |
| Audio | ACP (`snd_acp_pci`/SOF) + HDA genérico + HDMI/DP · PipeWire + WirePlumber |
| USB/TB | xHCI × 4 + USB4/Thunderbolt (`thunderbolt`) · salidas DRM: `eDP-1`, `DP-1…7`, `HDMI-A-1` |
| Virtualización (Fune) | `kvm_amd` cargado · `/dev/kvm` presente · `ccp`/`amdtee` |
| Firmware (LVFS) | fwupd 2.1.8: **System Firmware de Lenovo en LVFS** (cápsula UEFI), CPU/SMU/PSP, NVMe, cámara y huella listados · `fwupdmgr get-updates`: nada pendiente a 2026-10-14 |
| Aceleradores (Snake) | Vulkan RADV en la iGPU (8 GB UMA + GTT) · NPU XDNA 2 con firmware 1.1.2.64 |

## Versiones instaladas (fase 0)
| Paquete | Versión | Origen |
|---|---|---|
| niri | 26.04-1.1 | cachyos-extra-znver4 |
| quickshell | 0.3.2-1.1 | cachyos-extra-znver4 |
| qt6-base / qt6-declarative / -svg / -imageformats / -shadertools | 6.12.0 | extra |
| ghostty | 1.3.1-2.1 | cachyos-extra-znver4 |
| neovim | 0.12.6-1.1 | cachyos-extra-znver4 |
| fish | 4.9.3-1 | extra |
| starship | 1.26.0 | extra |
| mesa | 26.2.4-1 | cachyos |
| limine | 12.9.3-2 | cachyos |
| plymouth | 26.134.222-4 | cachyos |
| freerdp | 3.32.2 | cachyos-extra-znver4 |
| swaylock / swayidle | 1.8.6 / 1.9.0 | cachyos-extra-znver4 |
| matugen | 4.2.0 | cachyos-extra-znver4 |
| gpu-screen-recorder | 6.1.4 | cachyos-extra-znver4 |
| ddcutil | 3.0.2 | extra |
| fprintd | 1.94.5 | cachyos-extra-znver4 |
| google-chrome · bibata-cursor-theme-bin · papirus-folders | 155.0.8059.79 · 2.0.7 · 1.14.0 | AUR → `[ocarina-aur]` (PKGBUILD revisados) |
| paru | 2.1.0-3 | cachyos |

Paquetes instalados en la fase 0 (repos oficiales): quickshell, qt6-{svg,imageformats,shadertools,declarative}, ghostty, starship,
neovim, zoxide, yazi, wl-clipboard, cliphist, brightnessctl, ddcutil, swayidle, swaylock, wlsunset, grim, slurp, satty, wf-recorder,
libqalculate, libvips, xwayland-satellite, xdg-desktop-portal-gnome, gnome-keyring, adw-gtk-theme, qt6ct, papirus-icon-theme, sysstat,
powertop, hyperfine, shellcheck, stylua, wev, arch-audit, fwupd, nvme-cli, restic, wl-mirror, tesseract (+ jpn, jpn_vert, spa, eng),
matugen, gpu-screen-recorder, kernel-modules-hook, ccache, ttf-jetbrains-mono-nerd, libinput-tools, vulkan-tools, freerdp.
Ya estaban: git, ripgrep, fd, fzf, bat, eza, btop, fastfetch, jq, imagemagick, power-profiles-daemon, bluez(-utils), networkmanager,
fprintd, nautilus, smartmontools, pacman-contrib, noto-fonts(-cjk,-emoji), lm_sensors, firefox, xdg-desktop-portal-gtk, xdg-user-dirs.
Fase 5 (repos oficiales): wtype (pegar desde Kura/Torii), unicode-emoji (orden y nombres en inglés de los emoji de Torii).

## Fuentes
`~/.local/share/fonts/ocarinashell/` (`scripts/fonts.sh`, con licencias y `SHA256SUMS`): Geist (variable + itálica), Zen Kaku
Gothic New 300/400/500/700, Shippori Mincho B1 400/500/700, Yuji Syuku, Unbounded (variable), Material Symbols Rounded
(variable FILL/GRAD/opsz/wght + `.codepoints`). Repos: JetBrainsMono Nerd, Noto, Noto CJK, Noto Emoji.
`~/.config/fontconfig/conf.d/60-ocarina-jp.conf`: `sans-serif:lang=ja` → Noto Sans CJK JP (antes KR); el respaldo CJK sin
idioma también es JP (la captura de la comprobación se quedó en local, con el resto de capturas de las fases).

## Compilación (paru + makepkg)
`~/.config/paru/paru.conf` y `~/.config/pacman/makepkg.conf` enlazados desde `config/`. Prueba: `tty-clock` compilado con
`-march=native -O3 -flto=auto` + endurecimiento de CachyOS en `BUILDDIR=/tmp/makepkg`: 3,8 s (en frío) / 2,5 s. ccache
activo (los paquetes de un solo fichero compilan y enlazan en una llamada y ccache no los cachea; es lo esperado).
`paru -S` sin terminal necesita `--nosudoloop` (D-019).
