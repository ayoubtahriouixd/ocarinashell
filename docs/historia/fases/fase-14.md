# Fase 14 · Blindaje: modo seguro, pruebas de humo, reversión y simulacros

**Objetivo**: que ninguna actualización ni fallo deje a Ayoub sin escritorio, y construir las piezas deterministas
que usará 守 Mamori (fase 16): ayudante root, pruebas de humo, reversión, marca de arranque y hook de pacman.
**Lee antes**: `docs/06-ACTUALIZACIONES.md` (capas 1–5 completas), `docs/05-RESCATE.md`, `docs/04-RENDIMIENTO.md`.

## Tareas
1. **Snapshot**.
2. **Capa 1**: verifica `snap-pac` + `limine-snapper-sync` (snapshots arrancables), `linux-cachyos-lts` instalado y en el
   menú (si Ayoub lo aceptó en la fase 0), `paccache.timer` conservando 3 versiones, `kernel-modules-hook` (si existe).
   Prueba real de bajada de versión de un paquete inocuo desde la caché y vuelta atrás.
3. **Capa 2**: `ocarina doctor` comprueba que los paquetes críticos vienen de repos oficiales (no `-git`, no AUR) y que no
   hay `IgnorePkg` peligrosos; `lazy-lock.json` versionado.
4. **Capa 3 (auditoría de código)**: agente `qml-reviewer` con foco en resiliencia: módulos sensibles aislados en
   `Loader`, `available`/`error` en servicios, parser de niri tolerante, includes generados validados antes de moverse,
   esquema y migraciones de ajustes, `command -v` para herramientas externas, cero avisos «deprecated». Corrige.
5. **Capa 4**: modo seguro completo (el de la fase 3 + diagnóstico en pantalla), respaldo del CLI y `swaylock`
   tematizado verificados con la shell parada.
6. **Capa 5 — piezas deterministas**:
   - `scripts/smoke-test.sh` (= `ocarina doctor --post-update`) con todas las comprobaciones de 06-ACTUALIZACIONES,
     incluidas arranque (bloque de Limine, tema Plymouth en el initramfs actual) y Fune. Informe JSON + código de salida.
     Duración < 30 s. Diseñado para ampliarse (Snake en la fase 15).
   - **Ayudante root `ocarina-maint`** (`system/ocarina-maint` → `/usr/local/libexec/`, bash estricto, `set -euo pipefail`):
     lista blanca y validación de cada argumento (06-ACTUALIZACIONES › Seguridad del piloto automático); registro en el
     journal; regla sudoers mínima `NOPASSWD` solo para él (instalada con `visudo -c` y por script root). Pruebas: 10
     llamadas maliciosas rechazadas (rutas, `;`, números de snapshot que no son pares pre/post, paquetes inexistentes…).
   - **Reversión**: `ocarina-maint rollback <pre> <post>` (solo pares de snap-pac/Mamori) + reinicio de la shell + pruebas.
   - **Marca de arranque**: `ocarina-bootmark.service` (oneshot tras `graphical-session.target`) escribe kernel y hora del
     arranque correcto; detector de «arranque por LTS tras kernel nuevo» o «falta la marca» → aviso (Mamori lo resolverá).
   - Hook de pacman `system/pacman/90-ocarinashell.hook` (PostTransaction → `/var/lib/ocarinashell/needs-check`) +
     `ocarina-postupdate.path`/`.service` de usuario → pruebas de humo automáticas en la sesión tras cualquier transacción.
   - `bin/ocarina-update` (`ocarina update`) manual de transición: noticias (`paru -Pw` + anuncios de CachyOS), pendientes
     con críticos, snapshot, `paru -Syu`, pruebas de humo, informe. La fase 16 lo convierte en un atajo de Mamori.
   - Indicador 新 en Obi (`checkupdates` cada 6 h solo con CA y fuera de Shinobi; reinicio pendiente si el kernel en
     ejecución ≠ instalado). Mamori lo alimentará después.
7. **控 Hikae · copias de seguridad de verdad** (`docs/07-IDEAS.md`; los snapshots viven en el mismo SSD). `restic`
   con repositorio cifrado en el destino que elija Ayoub (pregúntale con AskUserQuestion: disco USB, NAS por
   SFTP/REST o los dos); contraseña en gnome-keyring (`secret-tool store --label='OcarinaShell Hikae' service
   ocarinashell-hikae`; restic la lee con `--password-command "secret-tool lookup service ocarinashell-hikae"`),
   nunca en claro, y dile que la guarde también fuera del equipo (sin ella la copia no se abre). Si el llavero está
   bloqueado (el inicio con huella o automático no lo desbloquea), no copia: aviso en Fumi «Desbloquea el llavero
   para hacer la copia» con un botón que lo pide. Qué: `~` con exclusiones (`~/.cache`, papelera, `node_modules`,
   Steam y juegos, modelos de Snake, disco de Fune salvo que lo pida) + listas de paquetes por separado (`pacman
   -Qqen` → `paquetes-repo.txt`, `pacman -Qqem` → `paquetes-aur.txt`) + el repo `~/ocarinashell`. Cuándo: `ocarina
   backup now --if-due` (no hace nada si la última copia correcta a ese destino tiene < 20 h) desde dos disparadores:
   `ocarina-hikae.timer` diario con CA (`Persistent=true`) y `ocarina-hikae-usb.service` (`Type=oneshot`,
   `RemainAfterExit=yes`, `BindsTo=`/`After=` y `WantedBy=` la unidad `.mount` del punto de montaje de udisks del
   disco, para que se dispare en cada conexión; comprueba con `systemctl --user list-units -t mount` que el gestor de
   usuario ve ese montaje y, si no, dispara desde la shell con `udisksctl monitor`). Nada de `.path` con
   `PathExists=`: se re-dispara en bucle mientras el disco siga montado. Nunca en batería, Shinobi ni Oni;
   `systemd-inhibit` mientras copia; `Nice=19`, IO idle. Retención `forget --keep-daily 7 --keep-weekly 5
   --keep-monthly 12 --prune`. Estado en `~/.local/state/ocarinashell/hikae/status.json`. En esta fase: CLI `ocarina
   backup [now [--if-due]|status|restore <ruta>|check]` y avisos en Fumi (solo si falla o la última copia tiene más
   de 7 días); la sección 控 de la página 守 (última copia, tamaño, destino, «Copiar ahora», **Recuperar**: navegar
   instantáneas y restaurar en `~/Restaurado/<fecha>/`, nunca encima del original) se construye en la fase 16.
8. **Simulacros** (todos deben acabar bien y documentados en `docs/evidencias/fase-14/`):
   a) `settings.json` corrupto → valores por defecto + copia `.roto` + aviso · b) include de niri inválido → nunca llega a
   escribirse · c) módulo opcional con import roto (en una rama de prueba) → solo cae ese módulo · d) la shell revienta 5
   veces → modo seguro en < 5 s y «Reintentar» recupera · e) reinicio de PipeWire/WirePlumber → audio se recupera solo ·
   f) niri recarga config/reinicia el socket → la shell reconecta · g) sin red → tiempo desde caché · h) hook de pacman →
   pruebas de humo automáticas tras `sudo pacman -S <paquete inocuo>` · i) actualización «mala» simulada (cambio de un
   fichero vigilado por las pruebas dentro de una transacción de prueba) → reversión con `ocarina-maint rollback` deja
   todo como estaba · j) marca de arranque ausente → aviso correcto · k) borrar un fichero de prueba y recuperarlo con
   Hikae en `~/Restaurado/` → idéntico (`sha256sum`).

## Criterios de aceptación
- [ ] Los 11 simulacros superados con evidencias. Pruebas de humo verdes en < 30 s. Primera copia de Hikae completa.
- [ ] `ocarina-maint` rechaza todo lo que no está en su lista blanca; sudoers validado con `visudo -c`.
- [ ] `ocarina update` probado al menos una vez con una actualización real (con Ayoub).
- [ ] `docs/COMPAT.md` y `docs/06-ACTUALIZACIONES.md` al día.

## Al terminar
PROGRESS.md, commit; explica a Ayoub en 3 líneas qué le protege ya y que la fase 16 lo hará todo automático.
