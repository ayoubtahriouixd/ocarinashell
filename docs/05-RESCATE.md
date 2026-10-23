# 05 · Rescate — si algo se rompe

Orden de preferencia: arreglar en caliente → revertir con git → volver al snapshot de snapper.
Casi siempre lo hará 守 Mamori solo; esto es lo que hay debajo, por si hiciera falta a mano. Empieza siempre por
`ocarina doctor`. Lo habitual en CachyOS (y lo que hay en el equipo de referencia): config de snapper `root`, sesión
gráfica en **tty1**, socket Wayland `wayland-1`, kernel LTS `linux-cachyos-lts` en el menú de Limine y `swaylock`
instalado (lo pone `./install.sh`). Comprueba los tuyos con `loginctl list-sessions` y `ls $XDG_RUNTIME_DIR`.

## La barra/shell desapareció o se cuelga
```bash
systemctl --user status ocarinashell        # ¿falló? ¿está el modo seguro?
journalctl --user -u ocarinashell -n 80     # error QML
systemctl --user restart ocarinashell
cd ~/ocarinashell && git log --oneline -5 && git revert <commit>   # si fue un cambio reciente
```
Los atajos esenciales siguen funcionando: el CLI `ocarina` tiene respaldos (volumen, brillo, bloqueo con swaylock).

## niri no acepta la configuración
niri mantiene la última config válida y muestra un aviso. `niri validate` dice la línea exacta.
Revertir: `cd ~/ocarinashell && git checkout -- config/niri/` (o `git revert`).

## La pantalla se quedó bloqueada y no desbloquea
Kagi usa su propio PAM (sin faillock: las erratas nunca bloquean la cuenta, D-040); tras 3 fallos pide esperar
5–60 s. Si la shell muere estando bloqueada, la pantalla sigue cubierta (así lo exige el protocolo): la shell se
reinicia sola en 1 s y vuelve a bloquear (marca `$XDG_RUNTIME_DIR/ocarinashell/locked`); si cae al modo seguro, este
lanza `swaylock`. Si Kagi no se confirma en 2,5 s, `swaylock` toma el relevo. Si aun así no puedes entrar:
1. `Ctrl+Alt+F2` → inicia sesión en la TTY2 (la sesión gráfica suele vivir en la **tty1**; con el greeter instalado
   puede cambiar: `loginctl list-sessions` dice la VT real).
2. `export WAYLAND_DISPLAY=wayland-1 XDG_RUNTIME_DIR=/run/user/$(id -u) NIRI_SOCKET=$(ls /run/user/$(id -u)/niri.wayland-1.*.sock)`
   (comprueba los nombres con `ls $XDG_RUNTIME_DIR`).
3. `systemctl --user restart ocarinashell` y, si no basta, `swaylock` desde esa TTY toma el bloqueo y te deja
   desbloquear con la contraseña. Vuelve con `Ctrl+Alt+F1`.
4. Último recurso: `loginctl terminate-session <id>` (cierra la sesión gráfica; perderás ventanas abiertas).

## El inicio de sesión gráfico no arranca (greeter / sesión)
El greeter (greetd + niri + Quickshell; opcional, `scripts/root/greeter.sh`) se protege solo: si falla dos veces seguidas, `greeter-launch` pasa al
inicio de sesión **en modo texto** (agreety: usuario, contraseña y arranca `niri-session`). Además:
- **Ctrl+Alt+F2** siempre da una consola de texto normal. Entra y:
  - `sudo touch /etc/ocarinashell/greeter-disabled` → el greeter usa agreety al momento (sin reiniciar);
  - `sudo bash ~/ocarinashell/scripts/root/greeter.sh desactivar` → desde el próximo arranque vuelve la entrada por
    tty1 (texto) de antes; `… greeter.sh activar` lo pone otra vez.
- Registro: `journalctl -b -t ocarina-greeter -u greetd`.
- Si nada de eso sirve, en el menú de Limine: **CachyOS → Snapshots → «ocarinashell: antes de activar greetd»**.

## El kernel nuevo falla (Wi-Fi, suspensión, gráficos)
Elige en Limine la entrada del kernel **LTS** (`linux-cachyos-lts`) y arranca. Mamori detecta el arranque de respaldo,
retiene el kernel problemático y vuelve al anterior desde la caché. A mano: `ocarina doctor`, `/rescate` si usas Claude
Code en el repo, o `sudo /usr/local/libexec/ocarina-maint downgrade <kernel>` (solo paquetes firmados de la caché).

## El arranque se queda en el splash o algo va mal con Plymouth/Limine
- **Arrancar sin splash una vez**: en el menú de Limine elige la entrada, pulsa **E**, borra `splash` (y `quiet`,
  `loglevel=3`) de la línea `cmdline:` y pulsa **F10** para arrancar. Verás los mensajes del sistema.
- **Esc** durante el splash también muestra los mensajes (Plymouth pasa a modo texto).
- **Quitar los temas** (cada uno hace su snapshot y deja copia):
  - `sudo bash ~/ocarinashell/scripts/root/plymouth-tema.sh --uninstall` → vuelve el tema de CachyOS (initramfs
    regenerado);
  - `sudo bash ~/ocarinashell/scripts/root/limine-tema.sh --uninstall` → vuelve el aspecto anterior de Limine y su
    `timeout`.
- **Cambiar de variante**: `ocarina-boot-theme apply dark|light|auto` (te dice el comando root que debes lanzar);
  `ocarina-boot-theme status` dice qué hay instalado.
- Copias de todo lo que tocan los scripts de arranque: `~/ocarinashell-backup-boot-<fecha>/` y `/var/lib/ocarinashell/`.

## 忍 Shinobi se quedó activo (pantalla a 60 Hz, tema negro, sin turbo)
`ocarina shinobi off` (restaura el snapshot `~/.local/state/ocarinashell/shinobi-prev.json`). Si la shell no responde:
`powerprofilesctl set balanced` (también devuelve el turbo), `pkexec /usr/local/libexec/ocarina-powerctl gpu auto`,
`ocarina-theme apply <tu tema>`, `: > ~/.local/state/ocarinashell/niri/shinobi.kdl` (niri recarga solo) y, para que no
se reanude al volver la shell, `rm ~/.local/state/ocarinashell/shinobi-prev.json`. Los 120 Hz vuelven desde Ajustes →
Pantalla o con `niri msg output eDP-1 mode 2880x1800@120.000`.

## 鬼 Oni se quedó activo o el ventilador no baja
`ocarina oni off` (restaura el snapshot `~/.local/state/ocarinashell/oni-prev.json`). Si la shell no responde:
`powerprofilesctl set balanced` (EPP y turbo vuelven con el perfil), `pkexec /usr/local/libexec/ocarina-powerctl scx stop`
(vuelve el planificador del kernel), `pkexec /usr/local/libexec/ocarina-powerctl gpu auto`,
`pkexec /usr/local/libexec/ocarina-powerctl wifi-ps on`, `pkexec /usr/local/libexec/ocarina-powerctl fan auto` (solo
existe con `thinkpad_acpi fan_control=1`, que pone `scripts/root/fase-11.sh`; sin él el ventilador ya está en `auto`),
`: > ~/.local/state/ocarinashell/niri/oni.kdl` y, para que no se reanude al volver la shell,
`rm ~/.local/state/ocarinashell/oni-prev.json`. Si GameMode lo vuelve a encender sin juego abierto: `gamemoded -s`
(debe decir «inactive»; `systemctl --user restart gamemoded`). Para que GameMode no lo toque nunca: Ajustes › Oni ›
«Automático con juegos».

## 滑 Fluido: la imagen se congeló o no se quita
Lo que ves es la capa de Nameraka encima del vídeo (ratón y teclado siguen yendo a la app de debajo). En orden:
`Mod+Alt+F` · `ocarina nameraka off` · `systemctl --user stop ocarina-nameraka.service` (lo cierra todo y la capa
desaparece). El vigilante del ayudante ya debería quitarla solo en 1 s. Si se repite: `journalctl --user -u
ocarina-nameraka -n 80` y `~/.local/libexec/ocarinashell/nameraka self-test`. Si sigue, prueba otra calidad
(Ajustes › 滑 Nameraka: modo rendimiento «Siempre») o recalibra (`ocarina nameraka calibrate`). El motor IA no está
disponible (no pasó la puerta de rendimiento, D-061). Para que no arranque nunca: no lo enciendas; con Fluido apagado
no hay ningún proceso.
Si niri se queda con una captura huérfana (`niri msg casts` muestra una «inactive» sin Fluido encendido): el daemon la
cierra al arrancar; a mano, `busctl --user call org.gnome.Mutter.ScreenCast /org/gnome/Mutter/ScreenCast/Session/u<N>
org.gnome.Mutter.ScreenCast.Session Stop`.

## 船 Windows (Fune) no arranca o va lento
`ocarina fune status` · `podman logs --tail 80 WinApps` · visor web de emergencia en `http://127.0.0.1:8006` ·
`podman restart WinApps` (podman sin root; el contenedor se define en `~/.config/winapps/compose.yaml`). El disco de
Windows vive en `~/.local/share/ocarinashell/fune/` (subvolumen propio): **nunca** borres ese directorio ni los
volúmenes de podman para «arreglar» algo. Copia de seguridad: `ocarina fune backup` (VM apagada).

## 蛇 Snake ocupa memoria, va lento o dice «No cabe ahora»
`ocarina snake stop` (descarga el modelo al instante) · `ocarina snake status` (modelo, memoria y qué dice la política) ·
desactívalo en Ajustes › 蛇 Snake. «No cabe ahora» es la regla de la memoria de la GPU (docs/SNAKE.md): cierra lo que
la esté ocupando (un navegador con vídeo) o descarga un modelo ligero (`ocarina-snake models pull qwen3.5-4b`), que el
asistente usa solo cuando el principal no cabe. Mamori sigue funcionando sin él (modo determinista).

## 守 Mamori hizo algo que no quieres
`ocarina mamori status` (qué hizo y por qué) · `ocarina mamori rollback` (deshace la última actualización con su
snapshot) · `ocarina mamori hold <paquete> <días>` · `ocarina mamori pause 7` (pausa 7 días todo el piloto automático).
Historial completo: `~/.local/state/ocarinashell/mamori/history.jsonl` y el resumen en `docs/MANTENIMIENTO.md` de tu copia
local (no se publica).

## Una pantalla se quedó en negro o mal colocada (配置 Haichi)
Si no pulsaste «Mantener», el cambio se revierte solo a los 15 s. Si aun así quedó mal: desde otra pantalla o una TTY,
`rm ~/.local/state/ocarinashell/niri/outputs.kdl` (es un include opcional: niri recarga y vuelve a lo automático; el
perfil se puede volver a guardar luego). Brillo externo atascado: botones del propio monitor; `ocarina brightness list`
dice qué ve la shell.

## Un atajo de teclado dejó de funcionar o hace otra cosa (技 Atajos)
Los cambios de Ajustes › Atajos viven aparte de los atajos del repo: `~/.config/ocarinashell/binds.json` → el include generado
`~/.local/state/ocarinashell/niri/user-binds.kdl`. Todo de vuelta a los atajos de fábrica: `ocarina-binds reset-all`
(o «Restaurar todos» en la página). Sin la shell, desde una TTY: `: > ~/.local/state/ocarinashell/niri/user-binds.kdl`
(niri recarga solo). Lo que tienes cambiado: `ocarina-binds list` (las marcadas con `*`).

## La terminal se ve demasiado transparente o ilegible
Ajustes › Apariencia › Opacidad de la terminal (100 % = opaca). Sin la shell: borra las dos líneas `background-opacity`
de `~/.local/state/ocarinashell/theme/ghostty-effects.conf` y Ghostty vuelve a ser opaco en la ventana siguiente.

## 声 La voz de Snake no oye o no transcribe
`ocarina-snake listen` en una terminal enseña el nivel del micro (`{"level": …}`) y el texto. Sin modelo:
`ocarina-snake models pull whisper` (548 MiB, sha256 comprobado). Micro equivocado: elige la entrada en Engawa › Audio.
El audio nunca se guarda en disco: solo existe en `$XDG_RUNTIME_DIR` mientras se transcribe.

## sudo pide contraseña
Es lo normal. Sin contraseña solo existe la regla mínima del ayudante de Mamori
(`sudo -n /usr/local/libexec/ocarina-maint <orden>`, órdenes fijas y validadas; `/etc/sudoers.d/91-ocarina-maint`, que
pone `scripts/root/fase-14.sh`).
Los scripts de `scripts/root/` se ejecutan con `sudo bash …` y tu contraseña. (El permiso temporal con el que se
construyó OcarinaShell desapareció en la fase 17; si `ocarina doctor` lo viera, avisa.)

## Recuperar archivos (控 Hikae: snapshots de `~`, D-070)
Con la config `home` de snapper (`sudo bash scripts/root/snapper-home.sh instalar`, opcional), `~` tiene snapshots cada
hora (24 horarios, 7 diarios, 4 semanales). Sin root:
- `ocarina backup list <ruta>` → en qué snapshots está (y cuánto ocupa en cada uno);
- `ocarina backup restore <ruta> [<número>]` → lo copia en `~/Restaurado/<fecha>-#n/<ruta>` (nunca encima del original;
  por defecto, el snapshot más reciente que lo tiene). Con botones: Ajustes › 守 Mantenimiento › 控 Copias.
- A mano: los snapshots están en `/home/.snapshots/<n>/snapshot/<usuario>/…` (`snapper -c home list`).
Límite: viven en el mismo SSD. No te salvan de un disco muerto ni de un robo.

## Deshacer la última actualización
`ocarina rollback` (te enseña la transacción y pregunta): `snapper undochange` del último par pre/post de pacman, los
paquetes de arranque reinstalados desde la caché para que `/boot` cuadre, la shell reiniciada y las pruebas de humo otra
vez. Si fue un kernel nuevo: arranca el LTS desde Limine y `sudo /usr/local/libexec/ocarina-maint downgrade <kernel>`.
Pruebas de humo a mano: `ocarina doctor --smoke` (no toca la pantalla) o `--post-update` (reinicia la shell).

## Rollback completo con snapper
```bash
sudo snapper -c root list                    # busca «OcarinaShell: antes de instalar», «mamori: antes de actualizar» o el par pre/post de pacman
sudo snapper -c root undochange <pre>..0     # deshace cambios de / desde ese snapshot (sin reiniciar)
```
O arranca ese snapshot desde Limine (CachyOS → Snapshots) y, si todo va bien, hazlo permanente **desde ese arranque**
con `sudo limine-snapper-restore` (CachyOS; `RESTORE_METHOD=replace` en `/etc/limine-snapper-sync.conf`: sustituye `@` por
el snapshot y guarda el anterior; `--kernels <ID>` repone también los kernels de ese snapshot). Snapshot de referencia:
«OcarinaShell: antes de instalar», que crea `./install.sh` antes de tocar nada.
`~/` vive en otro subvolumen (`@home`): la config de usuario se revierte con git (`~/ocarinashell`), con las copias
`*.ocarina-bak-<fecha>` que dejó `scripts/install.sh` de lo que ya tuvieras y con los snapshots de `home` si los activaste
(控 Hikae, arriba).

## Quitar OcarinaShell por completo
`bash scripts/install.sh --uninstall` (quita los enlaces y restaura las copias `*.ocarina-bak-*`), desactivar las unidades
`ocarina*` y `sudo bash scripts/install-system.sh --uninstall` para los ficheros de root. Los paquetes se quedan. Si
instalaste el arranque o el greeter, quítalos antes con sus scripts (arriba). Para volver al punto de partida exacto:
el snapshot «OcarinaShell: antes de instalar».
