# Fase 13 · Arranque y apagado: Limine, Plymouth, greeter y despedida

**Objetivo**: una cadena visual continua y sin parpadeos de texto, con la marca de principio a fin:
**firmware → Limine (tema OcarinaShell) → Plymouth (ocarina animada, ようこそ) → greeter → escritorio**, y al revés:
**Dengen → despedida (おやすみなさい / また後で) → Plymouth de apagado → negro**. Variante según el tema: oscura
(Kurenai, Sumi, Ai, Yozakura) o clara (Kōhaku, Matcha).
**Lee antes**: `assets/boot/` (todo: `limine/preview-*.png`, `limine/limine-tema-*.conf`, `plymouth/preview-*.png`,
`plymouth/ocarinashell/ocarinashell.script`), `docs/05-RESCATE.md`, `docs/06-ACTUALIZACIONES.md`, mockups 03 y 05.
**Importante**: todo lo que toca `/boot`, el initramfs o la línea del kernel lo ejecuta **Ayoub** con scripts de
`scripts/root/` (el hook de guardia bloquea a Claude Code en esas rutas, a propósito). Snapshot antes de cada uno.

## Ya hecho en el kit (verificado)
- Fondos de Limine 2880×1800 oscuro/claro y bloque de tema para `limine.conf` **probado con Limine 10.8.5 en QEMU**:
  menú centrado dentro de la tarjeta, texto de marca de Limine oculto, ayuda propia en español en el fondo.
- Tema Plymouth `ocarinashell` (script): capas de la ocarina que comparten lienzo (tile, cuerpo, 6 agujeros, 2 ondas,
  sellos ❯_/殻), animación de entrada + bucle (agujeros que «tocan», ondas que laten, sello que se estampa y alterna),
  mensajes por modo (arranque/apagado/reinicio/actualización/firmware), contraseña de disco con pétalos, mensajes del
  sistema abajo. ~490 KB en total (no engorda el initramfs). Solo API documentada y **ya ejecutado en un plymouthd real
  24.004.60** (renderer x11 bajo Xvfb a 2880×1800): modos boot/shutdown/reboot/updates, contraseña con pétalos y
  `display-message` sin errores en el log; `plymouth/preview-*.png` son esas capturas. Falta verlo en tu hardware
  (DRM/simpledrm, initramfs real): eso es esta fase.

## Tareas
1. **Snapshot** y copia de `/boot/limine.conf`, `/etc/default/limine`, `/etc/mkinitcpio.conf` (y `.d/`) a
   `~/ocarinashell-backup-boot-<fecha>/` mediante script root. Confirma que el menú de Limine ya ofrece snapshots y el
   kernel LTS (rescate).
2. **`bin/ocarina-boot-theme`** (`apply dark|light|auto`, `status`, `--dry-run`): decide la variante desde el tema
   actual y genera los scripts root necesarios; nunca escribe en `/boot` por sí mismo.
3. **Limine**
   - Instala `qemu-desktop` (o `qemu-base`), `edk2-ovmf`, `mtools`, `dosfstools` y previsualiza con
     `python3 tools/limine-preview.py` (solo biblioteca estándar) usando una COPIA de tu `limine.conf` real + el bloque de tema (rutas de
     CachyOS: `/usr/share/limine/BOOTX64.EFI`, `/usr/share/edk2/x64/OVMF_*.4m.fd`). Compara con
     `assets/boot/limine/preview-*.png`. Ajusta si la versión instalada difiere.
   - Averigua qué regenera `limine-entry-tool`/`limine-mkinitcpio` de CachyOS y comprueba que las opciones GLOBALES al
     inicio de `limine.conf` sobreviven a una regeneración (simúlala en una copia o lee el código de la herramienta). Si no
     sobreviven, usa el mecanismo soportado y documéntalo en DECISIONES.md.
   - `scripts/root/limine-tema.sh` (idempotente): copia `ocarinashell-limine-<variante>.png` como
     `ocarinashell-limine.png` junto a `limine.conf` (en la misma partición: `boot():/`), inserta o reemplaza el bloque
     entre los marcadores `# ── OcarinaShell · tema de Limine` y `# ── fin del tema OcarinaShell` al principio del
     fichero sin tocar las entradas, ajusta `timeout` a lo que Ayoub prefiera (2–3 s), elimina claves globales duplicadas
     y guarda copia. `--uninstall` lo revierte.
4. **Plymouth**
   - Comprueba: paquete `plymouth`, hook en `mkinitcpio.conf` (con `kms`/amdgpu temprano), y en `/etc/default/limine`
     `KERNEL_CMDLINE` con `quiet splash` + silencio (`loglevel=3 rd.udev.log_level=3 systemd.show_status=auto
     vt.global_cursor_default=0`), conservando los parámetros que CachyOS ya tenga.
   - `scripts/root/plymouth-tema.sh`: instala `assets/boot/plymouth/ocarinashell/` en `/usr/share/plymouth/themes/`, fija
     `variant` en el script, pone `DeviceScale=1` en `[Daemon]` de `/etc/plymouth/plymouthd.conf` (a ~240 ppi Plymouth
     elegiría escala 2 y el script dibujaría a 1440×900 reescalado: icono y texto borrosos; con 1 pinta a 2880×1800
     nativos), `plymouth-set-default-theme ocarinashell` y regenera initramfs como manda CachyOS
     (`limine-mkinitcpio` o `mkinitcpio -P`). Verifica con `lsinitcpio` que el tema está dentro.
   - **Prueba sin reiniciar** con `scripts/root/probar-plymouth.sh`, que Ayoub lanza desde una TTY (Ctrl+Alt+F3):
     `plymouthd --debug --mode=boot` → `plymouth show-splash` → 8 s → `plymouth ask-for-password` (prueba de pétalos) →
     `plymouth quit`; repetir con `--mode=shutdown`. Revisa `/var/log/plymouth-debug.log` y corrige el script hasta
     que no haya errores. Después, reinicio real con Ayoub mirando (que grabe con el móvil si quiere).
5. **Traspaso sin parpadeo** Plymouth → greeter (si existe, fase 6) o → sesión: el greeter empieza con el mismo fondo y
   el icono en la MISMA posición y tamaño (centro en 42 % de alto; 380 px físicos a 1800 p) y luego anima hacia su
   diseño. Investiga la secuencia correcta (`plymouth quit --retain-splash`, orden de `greetd` respecto a
   `plymouth-quit.service`) para que no haya negro intermedio ni consola visible.
6. **Despedida dentro de la sesión** (`modules/dengen/Farewell.qml`): al elegir Apagar/Reiniciar/Cerrar sesión, una capa
   `Overlay` a pantalla completa funde al color de fondo de Plymouth (400 ms), muestra el icono en la posición exacta
   de Plymouth y la imagen de mensaje correspondiente (`msg-shutdown|reboot-<variante>.png`), suena una nota suave y
   entonces ejecuta la acción. Resultado: la entrada en el Plymouth de apagado es invisible. En Shinobi, sin animación.
   Al iniciar sesión: sonido `startup` y la barra entra una sola vez (si Motion está activo). Si hay una VM de Fune
   encendida, la despedida espera a que se apague limpiamente (máx. 30 s) antes de seguir.
7. **Robustez**: Ayoub reinstala el kernel con `scripts/root/probar-kernel.sh` (snapshot + `pacman -S linux-cachyos`;
   lo escribes tú, lo ejecuta él); después comprueba que el bloque de Limine sigue y que el initramfs nuevo lleva el tema. Añade estas comprobaciones a las pruebas de humo de la fase 14.
   En `05-RESCATE.md`: cómo arrancar sin splash (tecla E en Limine, quitar `splash`) y cómo desinstalar ambos temas.

## Criterios de aceptación
- [ ] Previsualización QEMU del menú real con el tema ≈ `assets/boot/limine/preview-<variante>.png`.
- [ ] `probar-plymouth.sh` sin errores en el log; arranque y apagado reales vistos por Ayoub: sin texto, resolución
      nativa, animación fluida, mensajes correctos (ようこそ / おやすみなさい / また後で), contraseña de disco con pétalos si aplica.
- [ ] Despedida → Plymouth de apagado sin salto perceptible; Plymouth → greeter sin negro intermedio.
- [ ] El tema sobrevive a una reinstalación del kernel. `systemd-analyze` anotado (el splash no debe alargar el arranque).

## Al terminar
PROGRESS.md, commit; dile a Ayoub cómo cambiar la variante clara/oscura (`ocarina-boot-theme apply …`) y cómo
desactivarlo en caso de apuro.
