# 05 · Rescate — si algo se rompe

Orden de preferencia: arreglar en caliente → revertir con git → volver al snapshot de snapper.
Casi siempre lo hará 守 Mamori solo (fase 16); esto es lo que hay debajo, por si hiciera falta a mano.
La fase 0 completa este documento con los datos reales (nombre de configs de snapper, entradas de Limine, TTY).

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
1. `Ctrl+Alt+F3` → inicia sesión en la TTY.
2. `export WAYLAND_DISPLAY=wayland-1 XDG_RUNTIME_DIR=/run/user/$(id -u)` (comprueba el nombre del socket con
   `ls $XDG_RUNTIME_DIR`).
3. `systemctl --user restart ocarinashell` y, si no basta, `swaylock` desde esa TTY toma el bloqueo y te deja
   desbloquear con la contraseña. Vuelve con `Ctrl+Alt+F2` (o la VT de la sesión: `loginctl`).
4. Último recurso: `loginctl terminate-session <id>` (cierra la sesión gráfica; perderás ventanas abiertas).

## El inicio de sesión gráfico no arranca (greeter / sesión)
- En el menú de Limine elige un **snapshot** anterior (limine-snapper-sync los lista) o entra en TTY.
- Desde TTY: `sudo systemctl disable greetd && sudo systemctl enable <dm anterior>` o arranca con `niri-session`.

## El kernel nuevo falla (Wi-Fi, suspensión, gráficos)
Elige en Limine la entrada del kernel **LTS** (`linux-cachyos-lts`) y arranca. Mamori detecta el arranque de respaldo,
retiene el kernel problemático y vuelve al anterior desde la caché. A mano: `ocarina doctor`, `/rescate` en Claude Code
o bajar el kernel desde `/var/cache/pacman/pkg`.

## El arranque se queda en el splash o algo va mal con Plymouth/Limine
En el menú de Limine pulsa **E** sobre la entrada, borra `splash` (y `quiet`) de la línea del kernel y arranca para ver
los mensajes. Desinstalar temas: `sudo bash scripts/root/plymouth-tema.sh --uninstall` y
`sudo bash scripts/root/limine-tema.sh --uninstall` (los crea la fase 13).

## 鬼 Oni se quedó activo o el ventilador no baja
`ocarina oni off` (restaura el snapshot). Si la shell no responde: `powerprofilesctl set balanced` y
`echo level auto | sudo tee /proc/acpi/ibm/fan`.

## 船 Windows (Fune) no arranca o va lento
`ocarina fune status` · `docker logs --tail 80 WinApps` · visor web de emergencia en `http://127.0.0.1:8006` ·
`docker restart WinApps`. El disco de Windows vive en `~/.local/share/ocarinashell/fune/` (subvolumen propio): **nunca**
borres ese directorio ni los volúmenes de Docker para «arreglar» algo. Copia de seguridad: `ocarina fune backup` (VM apagada).

## 蛇 Snake ocupa memoria o va lento
`ocarina snake stop` (descarga el modelo al instante) · `ocarina snake status` · desactívalo en Ajustes › 蛇 Snake.
Mamori sigue funcionando sin él (modo determinista).

## 守 Mamori hizo algo que no quieres
`ocarina mamori status` (qué hizo y por qué) · `ocarina mamori rollback` (deshace la última actualización con su
snapshot) · `ocarina mamori hold <paquete> <días>` · `ocarina mamori pause 7` (pausa 7 días todo el piloto automático).
Historial completo: `docs/MANTENIMIENTO.md` y `~/.local/state/ocarinashell/mamori/history.jsonl`.

## Una pantalla se quedó en negro o mal colocada (配置 Haichi)
Si no pulsaste «Mantener», el cambio se revierte solo a los 15 s. Si aun así quedó mal: desde otra pantalla o una TTY,
`rm ~/.local/state/ocarinashell/niri/outputs.kdl` (es un include opcional: niri recarga y vuelve a lo automático; el
perfil se puede volver a guardar luego). Brillo externo atascado: botones del propio monitor; `ocarina brightness list`
dice qué ve la shell.

## Recuperar archivos de una copia (控 Hikae)
Settei → Mantenimiento → Copias → **Recuperar** (restaura en `~/Restaurado/<fecha>/`, nunca encima). Sin la shell:
`ocarina backup restore <ruta>` o, a mano, `restic -r <repo> restore latest --target ~/Restaurado --include <ruta>`
(la contraseña: `secret-tool lookup service ocarinashell-hikae`, o la copia que guardaste fuera del equipo). Si el
portátil entero se pierde: instala CachyOS, `restic -r <repo> restore latest:/home/<usuario> --target ~/` desde el disco
o el NAS, y las listas guardadas te devuelven los paquetes: `sudo pacman -S --needed - < paquetes-repo.txt` y luego
`paru -S --needed - < paquetes-aur.txt`.

## Rollback completo con snapper
```bash
sudo snapper -c root list                    # busca «ocarinashell: antes de fase N» o el par pre/post de pacman
sudo snapper -c root undochange <pre>..0     # deshace cambios de / desde ese snapshot (sin reiniciar)
```
O arranca ese snapshot desde Limine y, si todo va bien, hazlo permanente con la herramienta de CachyOS
(`limine-snapper-restore` u homóloga; verifícalo en la fase 0). `~/` vive en otro subvolumen: la config de
usuario se revierte con git (`~/ocarinashell`) y con la copia `~/ocarinashell-backup-*.tar.zst` de la fase 0.

## Quitar OcarinaShell por completo
`scripts/install.sh --uninstall` (restaura las copias `*.ocarina-bak-*`), desactivar unidades `ocarina*`,
y `scripts/install-system.sh --uninstall` para los ficheros de root.
