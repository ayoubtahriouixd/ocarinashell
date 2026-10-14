# Fase 00 · Reconocimiento, seguridad y cimientos

**Objetivo**: conocer la máquina al detalle, poner redes de seguridad, decidir con Ayoub lo que es suyo de decidir
e instalar la base (paquetes, fuentes, repo, herramientas). Sin cambios visuales todavía.
**Lee antes**: `CLAUDE.md` (ya cargado), `docs/00-VISION.md`, `docs/01-ARQUITECTURA.md` §1–3, `docs/05-RESCATE.md`,
`docs/06-ACTUALIZACIONES.md` (capas 1–2).

## Tareas
### 0.1 sudo
`sudo -n true`. Si falla, explica a Ayoub las dos opciones (README §Inicio rápido): drop-in temporal
`/etc/sudoers.d/90-ocarinashell-temporal` (lo crea él con el comando del README) o scripts `scripts/root/*.sh`
que él ejecuta. Pregunta con AskUserQuestion y continúa según la respuesta.

### 0.2 Reconocimiento (solo lectura) → escribe `docs/SISTEMA.md`
Sistema: `/etc/os-release`, `uname -r`, `cat /proc/cmdline`, repos de `/etc/pacman.conf`, AUR helper (`paru`; ¿hay `yay`?),
`pacman -Q niri quickshell ghostty neovim fish starship xwayland-satellite 2>&1`.
Arranque y disco: Limine (`/boot/limine.conf` o ruta real, `limine-snapper-sync`), Plymouth, mkinitcpio/dracut,
`findmnt -t btrfs`, subvolúmenes (`btrfs subvolume list /`), `snapper list-configs` (¿hay config de `home`?), `snap-pac`,
cifrado (`lsblk -f`: ¿LUKS?), `fstrim.timer`.
Sesión: display manager (`systemctl status display-manager`), cómo arranca niri (`niri-session`/`niri.service`),
`systemctl --user list-units --type=service`, `spawn-at-startup` existentes, portales, demonios de notificación o
agentes polkit ya presentes, `echo $XDG_CURRENT_DESKTOP $XDG_SESSION_TYPE`, `xdg-user-dirs` (¿nombres en español?),
locale, zona horaria, distribución de teclado (`localectl`, config de niri).
Hardware (todo lo que la shell va a usar): `lscpu`, `lspci -nnk`, `lsusb`; `niri msg --json outputs` (modos exactos,
VRR, tamaño físico, escala); `/sys/class/backlight/*` (nombre, `max_brightness`); con `ddcutil` instalado y, si Ayoub
tiene, un monitor externo conectado: `ddcutil detect` (el panel interno sale como «Invalid display», es normal) y
`ddcutil --bus N getvcp 10`, ¿DDC/CI activo en el menú del monitor?; `/sys/class/leds/*kbd*`;
`/sys/class/power_supply/BAT*/` (`power_now` o `current_now`/`voltage_now`, `energy_full(_design)`,
`charge_control_{start,end}_threshold`); `/sys/firmware/acpi/platform_profile(_choices)`; cpufreq (`scaling_driver`,
`energy_performance_preference`, `energy_performance_available_preferences`, `cpufreq/boost`);
`powerprofilesctl`; huella (`lsusb` + `fprintd-list $USER` si está fprintd); cámara IR; táctil, touchpad y
TrackPoint (`libinput list-devices`); Wi-Fi/Bluetooth (chip y driver); `cat /sys/power/mem_sleep`; GPU
(`/sys/class/drm/card*/device/gpu_busy_percent`, `pp_dpm_sclk`); sensores (`sensors` o hwmon); virtualización para
Fune (`lscpu | grep -i svm`, `/dev/kvm`, módulo `kvm_amd`); NVMe (`nvme list`, salud con `nvme smart-log` si hay
`nvme-cli`); firmware (`fwupdmgr get-devices` si está fwupd: ¿BIOS del P14s en LVFS?); aceleradores para Snake
(`vulkaninfo --summary`, NPU: `/dev/accel/accel0`, módulo `amdxdna`, versión de firmware de la NPU).
Herramientas útiles que falten: anótalas para 0.6.

### 0.3 Redes de seguridad
1. Si no hay config `root` de snapper o falta `snap-pac`, pregúntale y configúralo al estilo CachyOS.
2. `sudo snapper -c root create -d "ocarinashell: antes de empezar"` (anota el número en SISTEMA.md).
3. Copia de seguridad de la config de usuario actual (solo las carpetas que existan; en una instalación nueva faltarán
   varias y `tar` fallaría):
   ```bash
   cd ~ && d=(); for x in .config/niri .config/fish .config/ghostty .config/nvim .config/quickshell; do [[ -e $x ]] && d+=("$x"); done
   (( ${#d[@]} )) && tar --zstd -cf ~/ocarinashell-backup-"$(date +%F)".tar.zst "${d[@]}"; cd - >/dev/null
   ```
4. Completa `docs/05-RESCATE.md` con datos reales: TTY a usar, nombre del socket Wayland, cómo se ven los snapshots en
   Limine, comando real de restauración de CachyOS.
5. Instala `swaylock` (respaldo de bloqueo) ya ahora.

### 0.4 Entrevista (AskUserQuestion, tres rondas de máximo 4 preguntas; la opción recomendada va primero)
Ronda 1: escala de pantalla (1,75 rec. / 1,6 / 2,0 / 1,5) · tema por defecto (Kurenai oscuro rec. / Kōhaku claro /
Sumi / Yozakura) · navegador (Chrome como en tus binds / Firefox / Zen / Brave) · inicio de sesión (greeter propio
con greetd rec. / mantener el actual / autologin + bloqueo).
Ronda 2: huella para desbloquear (solo si hay lector) · distribución de teclado (confirma la detectada) · ubicación
para el tiempo y la luz nocturna (pregúntale la ciudad) · límite de carga al 80 % (sí rec. / no).
Ronda 3: sonidos de interfaz (sí rec. / no) · kernel LTS de respaldo en el menú de arranque (sí rec. / no) · arranque
(Limine + Plymouth) en variante del tema (rec.) / siempre clara 紅白 / siempre oscura · tiempo de espera del menú de
Limine (3 s rec. / 1 s / 5 s). Anota todo en `docs/DECISIONES.md` a partir de D-011.

### 0.4b Higiene de actualizaciones desde el primer día (ver 06-ACTUALIZACIONES)
- Si Ayoub aceptó el kernel LTS: escribe `scripts/root/fase-00-lts.sh` (idempotente, `set -euo pipefail`: snapshot →
  `pacman -S --needed linux-cachyos-lts` (+ headers si hacen falta) → comprobar que el hook de CachyOS añadió la entrada
  a `limine.conf`) y pídele que lo ejecute con `sudo bash …` (regla 10: un kernel escribe en /boot y regenera el
  initramfs; el *hook* de guardia bloquea instalarlo desde Claude Code). Después confirma la entrada leyendo
  `/boot/limine.conf`.
- `pacman-contrib` (checkupdates, paccache) y `paccache.timer` con 3 versiones; `kernel-modules-hook` si existe.
- Comprueba que `niri` y `quickshell` vienen de repos oficiales (no `-git`/AUR); si no, propón cambiarlo.
- Crea `docs/COMPAT.md` con la matriz inicial de versiones (niri, quickshell, Qt, ghostty, neovim, kernel, mesa, limine,
  plymouth, freerdp) y la fecha. Hasta que exista 守 Mamori (fase 16), las actualizaciones se hacen con `/actualizar`.

### 0.5 Repo y herramientas
1. `git init` si hace falta, `.gitignore` (cachés, `*.qsb` NO se ignora, `docs/evidencias/**/*.png` sí se versiona
   salvo que pese > 2 MB), commit inicial «fase 0: kit inicial».
2. Crea el esqueleto de la arquitectura (`shell/`, `config/`, `bin/`, `system/`, `templates/`, `systemd/user/`,
   `scripts/root/`, `docs/evidencias/`).
3. `scripts/install.sh` (idempotente, `--dry-run`, `--uninstall`, copias `*.ocarina-bak-<fecha>`) y
   `scripts/install-system.sh` (root, idempotente, `--uninstall`). `scripts/doctor.sh` inicial.
   Ya vienen hechos y probados en el kit: `scripts/shot.sh`, `scripts/compare.sh`, `scripts/bench-power.sh`,
   `scripts/hooks/*.sh`, `tools/limine-preview.py` (revísalos, no los reescribas sin motivo).
4. Comprueba que los hooks de `.claude/settings.json` funcionan (edita un `.json` de prueba con un error y verifica
   que el hook te avisa; luego bórralo).

### 0.5b paru optimizado (petición expresa de Ayoub: paru, no yay)
1. `paru` desde el repo de CachyOS (no hace falta compilarlo). Si `yay` está instalado, pregunta y desinstálalo; en fish
   quedará la abreviatura `yay → paru` (fase 8).
2. `~/.config/paru/paru.conf` a partir de `reference/paru.conf`, validando cada opción con `man paru.conf` de la versión
   instalada (NewsOnUpgrade, SudoLoop, CombinedUpgrade, BatchInstall, RemoveMake, CleanAfter, BottomUp, PgpFetch,
   LocalRepo con su repo local creado, revisión con bat).
3. `~/.config/pacman/makepkg.conf` a partir de `reference/makepkg.conf` (compáralo antes con el `/etc/makepkg.conf` de
   CachyOS y conserva su endurecimiento): `-march=native -O3`, LTO, `-j$(nproc)`, `ccache`, `BUILDDIR=/tmp/makepkg`,
   zstd multihilo. Instala `ccache`. Prueba compilando un paquete AUR pequeño y anota el tiempo.
4. pacman (script root): `ParallelDownloads = 10`, `Color`, `ILoveCandy`, `VerbosePkgLists` si no están; mirrors con
   `cachyos-rate-mirrors` (o la herramienta equivalente de tu versión) con los más rápidos desde su conexión.
5. Regla para todo el proyecto: **antes de instalar cualquier paquete del AUR, lee su PKGBUILD** (`paru -Gp <pkg>`) y
   comprueba origen, checksums y scripts de instalación; solo entonces instala (con `--skipreview` si es no interactivo).

### 0.6 Paquetes base (repos oficiales/CachyOS primero; AUR con paru solo si no hay alternativa)
Comprueba cada nombre con `pacman -Si`/`paru -Si` antes de instalar y registra versiones en SISTEMA.md:
`quickshell qt6-svg qt6-imageformats qt6-shadertools qt6-declarative` (qmlls/qmllint/qmlformat) `ghostty fish starship
neovim git ripgrep fd fzf bat eza zoxide yazi btop fastfetch jq wl-clipboard cliphist brightnessctl ddcutil swayidle swaylock
wlsunset grim slurp satty wf-recorder libqalculate imagemagick libvips xwayland-satellite xdg-desktop-portal-gnome
xdg-desktop-portal-gtk gnome-keyring libsecret power-profiles-daemon bluez bluez-utils networkmanager fprintd (si hay
lector) adw-gtk-theme qt6ct papirus-icon-theme nautilus sysstat powertop hyperfine shellcheck stylua wev arch-audit
fwupd nvme-cli smartmontools` + los de las ideas de `docs/07-IDEAS.md`: `restic wl-mirror qrencode tesseract
tesseract-data-jpn tesseract-data-jpn_vert tesseract-data-spa tesseract-data-eng`
+ cursor Bibata (`bibata-cursor-theme` o equivalente) + `papirus-folders` + `matugen` + navegador elegido +
`gpu-screen-recorder` (opcional). Retira (preguntando) lo que choque: otros demonios de notificación, barras,
lanzadores o agentes polkit.

### 0.7 Fuentes
Repos: `ttf-jetbrains-mono-nerd noto-fonts noto-fonts-cjk noto-fonts-emoji`. Google Fonts (raw.githubusercontent.com,
licencia OFL/Apache) → `~/.local/share/fonts/ocarinashell/`: Geist, Zen Kaku Gothic New (300–700), Shippori Mincho B1
(400/500/700), Yuji Syuku, Unbounded, Material Symbols Rounded (variable). `fc-cache -f`.
`~/.config/fontconfig/conf.d/60-ocarina-jp.conf`: preferir formas japonesas para `lang=ja` y para el genérico CJK.
Verifica: `fc-match "sans-serif:lang=ja"`, `fc-match "Geist"`, `fc-list | grep -i "Material Symbols"`.

## Criterios de aceptación
- [ ] `docs/SISTEMA.md` completo (hardware, versiones, rutas reales de sysfs, conflictos detectados, KVM, LVFS).
- [ ] Snapshot creado y documentado; copia de seguridad de `~/.config` hecha; `swaylock` instalado.
- [ ] Respuestas de la entrevista en `DECISIONES.md`.
- [ ] Repo con esqueleto, scripts base y primer commit; hooks comprobados.
- [ ] paru y makepkg optimizados probados; paquetes y fuentes instalados y verificados (sin errores de pacman).

## Al terminar
Actualiza PROGRESS.md, commit «fase 0: …», y dile a Ayoub en 5 líneas qué encontraste (sorpresas de hardware
incluidas) y qué viene en la fase 1. No hace falta reiniciar.
