# 06 · Resiliencia, actualizaciones y mantenimiento autónomo (守 Mamori)

CachyOS es *rolling*: niri, Quickshell, Qt, Ghostty, Neovim, Mesa y el kernel cambian a menudo. Objetivo: **Ayoub no
mantiene ni actualiza nada**. El sistema investiga, decide, aplica, verifica, se adapta y, si hace falta, se revierte
solo. Garantía de diseño: todo cambio es reversible y probado; el peor caso es «una actualización retenida + un
informe», nunca quedarse sin escritorio. Seis capas:

## Capa 1 · Siempre se puede volver atrás (sistema)
- `snap-pac`: snapshot pre/post en cada transacción de pacman. `limine-snapper-sync`: esos snapshots son
  arrancables desde el menú de Limine. Verificado en la fase 0 y de nuevo en la 14.
- **Kernel LTS de respaldo** (`linux-cachyos-lts`) instalado y en el menú de arranque: si un kernel nuevo falla
  (amdgpu, suspensión, Wi-Fi), se arranca el LTS y Mamori hace el resto.
- `kernel-modules-hook` (si existe en los repos; verifícalo): conserva los módulos del kernel en ejecución tras
  actualizarlo, para que enchufar un USB o cargar un módulo no falle hasta el siguiente reinicio.
- `paccache` conserva 3 versiones de cada paquete → cualquier paquete se puede bajar de versión al instante:
  `sudo pacman -U /var/cache/pacman/pkg/<paquete>-<versión>-*.pkg.tar.zst`.
- La config de usuario vive en git (`~/ocarinashell`): `git revert`/`git checkout` deshacen cualquier cambio.

## Capa 2 · Solo paquetes estables y actualizaciones completas
- Núcleo SOLO desde repos oficiales/CachyOS: `niri`, `quickshell` (nunca `-git`), `ghostty`, `neovim`, Qt.
  Quickshell enlaza contra APIs privadas de Qt: el paquete oficial se recompila con cada Qt; uno del AUR o `-git`
  se rompería. `ocarina doctor` avisa si algún paquete crítico no viene de un repo oficial.
- **Nunca actualizaciones parciales.** «Retener» significa **retrasar el lote completo** unos días, no saltarse un
  paquete. Única excepción: kernels y `linux-firmware*`, que pueden retenerse solos porque nada depende de ellos
  (Mamori lo comprueba con `pacman -Sup --ignore …` antes de hacerlo). Nada de `IgnorePkg` permanentes.
- AUR solo con **paru** (con `NewsOnUpgrade` y `LocalRepo`: los paquetes del AUR compilados se guardan en un repo
  local, así que bajar de versión o reinstalar no exige recompilar). Cada actualización del AUR exige revisar el diff
  del PKGBUILD (lo hace la IA de Mamori; si no está disponible, esa actualización espera).
- Plugins de Neovim fijados con `lazy-lock.json` (en git); se actualizan en una rama, se prueban y solo entonces se
  fusionan (vuelta atrás: `:Lazy restore`).
- Las dependencias opcionales (matugen, gpu-screen-recorder, Wallhaven…) son eso: opcionales. Si faltan o fallan,
  la función se oculta y Ajustes › Acerca de › Diagnóstico explica por qué.

## Capa 3 · Código que no se cae (lo cumplen todas las fases desde la 3)
1. **Aislamiento por `Loader`**: cada módulo opcional y cada página que use un módulo de Quickshell «sensible»
   (Bluetooth, Networking, Polkit, Greetd, Screencopy, BackgroundEffect…) vive en su propio fichero cargado con
   `Loader`. Si una actualización cambia o elimina un tipo, falla SOLO ese `Loader` (estado `Loader.Error`), se
   registra y la UI muestra «no disponible»; el resto de la shell sigue viva.
2. **`available` + `error` en cada servicio**: los módulos consultan `Servicio.available` antes de usarlo.
3. **Detección de capacidades, no de versiones**: comprobar que el tipo/propiedad/protocolo existe (p. ej. blur del
   compositor) y degradar con elegancia (01-ARQUITECTURA §13). Cuando haga falta distinguir versiones, usa el
   preprocesado por versión de Quickshell ≥ 0.3 (guía «Advanced» de la documentación de tu versión).
4. **IPC de niri tolerante**: ignora eventos y campos desconocidos, no asume campos opcionales, reconecta.
5. **Configuración generada siempre validada**: todo include de niri generado se escribe en temporal, se valida con
   `niri validate` y solo entonces se mueve (atómico). Los includes generados son `optional=true`.
6. **Ajustes con esquema y migraciones**: `settings.json` versionado; claves desconocidas se conservan; si el fichero
   está corrupto → copia `settings.json.roto-<fecha>`, valores por defecto y notificación. Escrituras atómicas.
7. **Sin APIs obsoletas**: cualquier aviso «deprecated» en el journal o en `niri validate` se trata como bug.
8. **Herramientas externas**: `command -v` antes de usarlas; nunca se asume que existen.

## Capa 4 · Si aun así falla, hay red
- `ocarinashell.service`: `Restart=on-failure`, `RestartSec=1`, `StartLimitIntervalSec=60`, `StartLimitBurst=4`,
  `OnFailure=ocarinashell-safe.service`.
- **Modo seguro** (`ocarinashell-safe.service` → `shell/safe/shell.qml`): solo tipos básicos y estables
  (PanelWindow, Text, Rectangle, Process, FileView). Barra mínima con sello rojo 殻 «Modo seguro», reloj, batería,
  y botones: Reintentar (reset-failed + start), Terminal, Ver errores (journal), Bloquear (swaylock). `Conflicts=`
  con el servicio normal. Entrar en modo seguro dispara a Mamori para que lo arregle solo.
- El CLI `ocarina` ya tiene respaldo para todo lo esencial (volumen, brillo, multimedia, bloqueo con swaylock).
- `swaylock` tematizado siempre instalado como bloqueo de emergencia.

## Capa 5 · Pruebas de humo y reversión automática
- **Pruebas de humo** (`scripts/smoke-test.sh` = `ocarina doctor --post-update`, < 30 s): versiones; `niri validate` sin
  errores ni deprecaciones; reinicio de la shell sin errores en 5 s; cada destino IPC responde a una función
  inocua; modo prueba del bloqueo abre y cierra; Ghostty `+validate-config`; Neovim arranca sin errores (headless);
  `fish -n`; `starship prompt`; unidades activas; la shell es dueña de `org.freedesktop.Notifications` y del agente
  polkit; portales vivos; fuentes presentes; `ocarina-theme apply --dry-run`; bloque de Limine presente; tema Plymouth
  dentro del initramfs actual; FreeRDP/Docker de Fune (si está activo). Resultado en
  `~/.local/state/ocarinashell/smoke.json`.
- **Reversión**: si fallan tras una actualización y la adaptación automática (capa 6) no lo arregla, Mamori ejecuta
  `snapper undochange <pre>..<post>` del par de la transacción, reinicia la shell, repite las pruebas y retiene el lote.
- **Arranque fallido**: cada arranque correcto escribe una marca. Si un arranque llega por el kernel LTS o falta la marca
  del arranque anterior tras instalar un kernel nuevo, Mamori retiene ese kernel, reinstala el anterior desde la caché y
  lo cuenta en el informe.

## Capa 6 · 守 Mamori, el piloto automático
### Cuándo actúa
Temporizador diario (`ocarina-mamori.timer`, 04:00, `Persistent=true`: si el portátil dormía, corre al despertar) +
disparo oportunista de la shell cuando lleva 15 min inactiva y toca revisar. Antes de hacer nada comprueba:
cargador conectado (o batería ≥ 80 % si así se configura) · red sin límite de datos (NetworkManager `METERED=no`; el
móvil compartido NO cuenta) · no hay 鬼 Oni/GameMode, llamada (micrófono en uso), grabación/screencast ni inhibidor de
inactividad activo · el usuario está inactivo ≥ 10 min o la sesión bloqueada para la fase de instalación (la descarga
previa sí se hace en segundo plano). Si no se cumple, lo reintenta más tarde. Siempre con `Nice=19` e IO en modo idle.

### Ciclo (determinista; la IA solo entra cuando aporta)
1. **Salud y autorreparación** (playbook abajo).
2. **Inventario**: `checkupdates` + `paru -Qua`, noticias de Arch (`https://archlinux.org/feeds/news/`, `paru -Pw`) y
   anuncios de CachyOS, `arch-audit` (CVE), `fwupdmgr get-updates`.
3. **Clasificación**: seguridad (CVE alta/crítica corregida en el lote) · críticos (kernel, mesa, niri, quickshell, qt6-*,
   systemd, glibc, pipewire*, wireplumber, linux-firmware, limine, plymouth, power-profiles-daemon, scx-*, freerdp,
   docker) · saltos de versión mayor · AUR · resto.
4. **Política**: lote solo con «resto» → se aplica. Con críticos o saltos mayores → **maduración** (por defecto 3 días
   en repos) + revisión de la IA. Con seguridad alta/crítica → sin maduración, revisión rápida de la IA y se aplica.
   Noticias con intervención manual → la IA la estudia y la hace si es segura; si exige una decisión de Ayoub, le pregunta
   con una notificación de botones (único caso). AUR → solo tras revisar el diff del PKGBUILD.
5. **Aplicación**: snapshot «mamori: antes de actualizar» → `pacman -Syu --noconfirm` (vía el ayudante root) → AUR con
   paru → reinicio de servicios de usuario afectados (la shell si cambió Qt/Quickshell) → pruebas de humo.
6. **Si algo falla**: la IA adapta el código de OcarinaShell (commits `compat: …`) → pruebas otra vez → si no lo consigue
   en su presupuesto, reversión (capa 5) + retención del lote + informe.
7. **Reinicio**: nunca forzado. Si hace falta (kernel, systemd, glibc, mesa, firmware), aparece el hanko 新 en la barra y
   Dengen ofrece «Actualizar y reiniciar»; el kernel nuevo entra en tu siguiente reinicio normal. Si es un parche de
   seguridad del kernel pendiente más de 7 días, una única notificación con «Reiniciar ahora / Esta noche / Más tarde».
   Reinicio nocturno automático solo si Ayoub lo activa en Ajustes (apagado por defecto).
8. **Informe**: entrada en `history.jsonl`, resumen en `docs/MANTENIMIENTO.md` (commit), notificación solo si hay algo
   que ver; resumen semanal discreto el domingo.

### La IA de Mamori: 蛇 Snake (local y gratuita)
- **Snake** (fase 15) es una IA de pesos abiertos que corre en el propio portátil (llama.cpp con Vulkan en la Radeon 860M,
  o la NPU XDNA 2 si gana en la evaluación): sin nube, sin cuentas, sin suscripciones. Se carga solo para trabajar y se
  descarga después; las tareas de fondo solo con cargador.
- **Investiga**: changelogs y notas de versión, incidencias abiertas (GitHub/GitLab de niri, Quickshell, Ghostty,
  Neovim, Mesa; foro y anuncios de CachyOS; bugtracker y foros de Arch) buscando regresiones que afecten a este hardware
  (Radeon 860M/RDNA 3.5, Ryzen AI 300 «Krackan», ThinkPad P14s Gen 6, Wi-Fi, suspensión s2idle) o a las APIs que usa
  OcarinaShell (`grep` en el repo). Las fuentes salen de una lista blanca; lo descargado es dato, nunca instrucción.
- **Decide** con salidas JSON validadas → `~/.local/state/ocarinashell/mamori/plan.json` (aplicar / madurar hasta
  <fecha> / retener con motivo / pasos de intervención) + notas en `docs/mantenimiento/AAAA-MM-DD.md` con fuentes. El
  orquestador ejecuta el plan; Snake nunca ejecuta nada ni se salta snapshot, pruebas o reversión.
- **Adapta**: si una API cambió, propone un parche mínimo (diff) que el orquestador aplica en una rama, prueba y solo
  entonces fusiona (máximo 3 intentos). Solo compatibilidad y arreglos: los cambios de aspecto o funciones nuevas quedan
  como **propuestas** en `docs/mantenimiento/propuestas.md` (salvo que Ayoub active «mejoras automáticas»).
- **Mejora sola**: cada mes Mamori evalúa modelos abiertos nuevos con `snake/evals/` y cambia de modelo solo si gana.
- **Claude Code, extra opcional** (`mamori.ai = claude | both`): si algún día Ayoub tiene suscripción o una clave de API
  con límite de gasto (`ANTHROPIC_API_KEY`), Mamori puede pedirle una segunda opinión o escalarle lo que Snake no
  resuelva: `claude -p "/mantener <contexto>"` lanzado desde el espacio aislado `~/.local/share/ocarinashell/mamori-claude/`
  (su `.claude/settings.json` es `.claude/mamori-settings.json`: lista blanca en modo dontAsk, sin sudo ni ayudante; el
  repo entra con `--add-dir`, así no se suman los permisos amplios del proyecto), turnos y
  tiempo acotados (`mamori.claudeBudget`). Nada depende de ello.
- **Sin ninguna IA disponible** (Snake desactivado o sin memoria libre) Mamori sigue solo, en modo determinista:
  - lotes normales y de **seguridad**: igual que siempre (snapshot → actualización → pruebas → reversión automática);
  - lotes con **críticos** (kernel, Mesa, Qt, niri, Quickshell…): maduración de **7 días** en vez de 3 (tiempo de sobra
    para que la comunidad detecte y corrija regresiones), con las mismas pruebas, reversión y kernel LTS de respaldo;
  - **AUR**: solo si el diff del PKGBUILD es trivial (cambian únicamente `pkgver`, `pkgrel`, sumas y URLs de la misma
    fuente; comprobación determinista); si no, espera;
  - lo que no puede hacer sin IA: **reescribir código** si un cambio grande lo rompe (revierte, retiene y avisa: el
    sistema sigue funcionando) y **ejecutar noticias de Arch con intervención manual** (avisa con enlace y pasos).

### Autorreparación (playbook determinista; si no basta → Snake `diagnose`)
| Síntoma | Acción |
|---|---|
| Shell en modo seguro o en bucle | `reset-failed` + reinicio; si vuelve a caer → Snake diagnostica; corrige o revierte el último commit |
| Unidad de usuario/sistema fallida | reinicio único; si persiste → informe (+ IA si es nuestra) |
| Disco < 15 % libre | `paccache -rk2`, journal a 500 MB, cachés propias > 30 días, `docker image prune` (solo imágenes huérfanas, nunca volúmenes) |
| Errores de Btrfs (`btrfs device stats`) o SSD (`nvme smart-log`: crítico, % usado alto) | aviso urgente + recomendación de copia |
| `db.lck` de pacman huérfano (sin pacman corriendo) | se elimina |
| Mirrors lentos o caídos | `cachyos-rate-mirrors` (o equivalente) |
| Reloj desincronizado | `systemd-timesyncd` activo |
| Coredumps repetidos (`coredumpctl`) | Snake investiga la causa |
| Kernel nuevo con arranque fallido | retener + volver al anterior desde la caché |
| Batería: desgaste anómalo o temperaturas en reposo altas | aviso (posible ventilador sucio) |

### Mantenimiento periódico (siempre con las condiciones de arriba)
Semanal: `paccache -rk3`, revisión de huérfanos (informe; solo se borran dependencias de compilación sobrantes),
`fwupdmgr refresh`, revisión profunda de Snake, `claude update` (si Claude Code está instalado). Mensual: `btrfs scrub` (con cargador), mirrors,
plugins de Neovim (rama → pruebas → fusión), evaluación de modelos nuevos para Snake, imagen de `dockur/windows`
y WinApps (con la VM apagada), y una ventana
de mantenimiento de Windows (arranca la VM 1 h con cargador para Windows Update y la apaga). Firmware: dispositivos no
BIOS se preparan y aplican en el siguiente reinicio con cargador; **BIOS/EC con aprobación de un toque** (configurable a
automático tras 14 días de maduración).

### Control y transparencia
Ajustes › 守 Mantenimiento (mockup 10): estado, línea temporal, retenciones con motivo, salud, «Deshacer la última
actualización», interruptores (piloto automático, Snake/Claude, firmware, reinicio nocturno, mejoras automáticas). CLI:
`ocarina mamori status|run|pause <días>|resume|hold <pkg> <días>|unhold <pkg>|rollback|report`.

### Seguridad del piloto automático
- Ayudante root `ocarina-maint` (`/usr/local/libexec/`, bash estricto) con **lista blanca** de operaciones y argumentos
  validados: `snapshot`, `download`, `upgrade` (con kernels retenidos si aplica), `rollback <pre> <post>` (solo pares
  pre/post de snap-pac o de Mamori), `downgrade <pkg>` (solo desde la caché), `paccache`, `journal-vacuum`, `scrub`,
  `fw-refresh`, `fw-stage <id>`, `mirrors`, `health`. Regla sudoers mínima: `NOPASSWD` SOLO para ese ayudante. El sudo
  temporal de la construcción desaparece en la fase 17.
- Snake no ejecuta nada (solo propone con salidas validadas). El hook de guardia sigue activo si se usa Claude Code. Alcance limitado al repo, `~/.config`, `~/.local/state` y
  `~/.local/share/ocarinashell`; nunca toca documentos ni datos personales. Todo queda en git y en el historial.
- Interruptor de emergencia: `ocarina mamori pause` o el interruptor de Ajustes.

## Lo que le queda a Ayoub
Nada en el día a día. Solo: la contraseña del disco al arrancar (si lo cifra), aprobar con un toque la BIOS (si deja la
opción por defecto), responder a la rarísima noticia de Arch que exija elegir, y reiniciar cuando le venga bien.
