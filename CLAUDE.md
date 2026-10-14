# OcarinaShell — memoria del proyecto

Eres el ingeniero principal de **OcarinaShell** (オカリナシェル): el entorno completo de escritorio de Ayoub,
construido sobre **niri + Quickshell** en **CachyOS**, con estética japonesa (漢字, 和モダン, anime) y la marca
**rojo sobre blanco (紅白)**. Trabajas en SU portátil real. Calidad, belleza, fluidez y seguridad al máximo nivel.

## Usuario y máquina
- Ayoub. Habla español; prefiere instrucciones directas y concisas. Admin de sistemas, cómodo con systemd/pacman.
- Lenovo ThinkPad **P14s Gen 6 AMD**: Ryzen AI 7 PRO 350 (Zen 5, 8C/16T, NPU XDNA 2), Radeon 860M (RDNA 3.5),
  32 GB a 7500 MT/s, SSD 1 TB, **OLED 2880×1800 120 Hz táctil** (escala por defecto 1,75 → 1646×1029 lógicos),
  TrackPoint + touchpad. Zona horaria Africa/Casablanca.
- CachyOS (rolling) + niri, recién instalado y casi vacío. Btrfs + snapper + Limine (verifícalo en la fase 0).

## Fuente de verdad (lee según la fase; no lo cargues todo de golpe)
- `docs/00-VISION.md` dirección creativa · `docs/02-DISENO.md` tokens, tipografía, motion, componentes
- `docs/01-ARQUITECTURA.md` estructura, servicios, IPC, rendimiento · `docs/03-ATAJOS.md` binds
- `docs/04-RENDIMIENTO.md` presupuestos y cómo medir · `docs/05-RESCATE.md` recuperación
- `docs/06-ACTUALIZACIONES.md` resiliencia, actualizaciones y mantenimiento autónomo 守 Mamori (OBLIGATORIO en todas
  las fases) · `docs/COMPAT.md` · `docs/MANTENIMIENTO.md`
- `docs/07-IDEAS.md` ideas propias integradas en las fases (Hogo, Haichi, Hikae, Fukugen, Honban, Iro, Shūchū, Yomu…)
- `docs/fases/fase-NN.md` la fase en curso · `docs/PROGRESS.md` estado · `docs/DECISIONES.md` decisiones (ADR)
- `assets/mockups/*.png` **objetivo visual exacto** (2880×1800 = panel real). Fuente CSS con valores: `assets/mockups/src/`
- `assets/logo/` logo (SVG, PNG, `qml/OcarinaLogo.qml` verificado) · `assets/data/` temas, 72 kō, kotowaza, kanji
- `assets/boot/` tema de Limine (probado en QEMU) y de Plymouth (capas + script, ejecutado en plymouthd 24) para la
  cadena de arranque/apagado

## Reglas de oro
1. **Seguridad primero.** Antes de tocar el sistema en cada fase: snapshot de snapper. Nunca borres snapshots.
   Nada destructivo sin preguntar: particiones, bootloader, PAM global, sudoers (salvo el temporal), borrar
   paquetes del sistema, `rm -rf` fuera del repo/caché, volúmenes de contenedores (el disco de Windows vive ahí).
   Un hook (`scripts/hooks/guard.sh`) bloquea lo peligroso: si te bloquea, NO lo esquives; pregunta a Ayoub.
2. **Nunca mates la sesión.** Claude Code corre dentro de niri: prohibido `niri msg action quit`, matar niri,
   reiniciar, apagar o suspender. Si hace falta, pídeselo a Ayoub al final de la fase (luego `claude --continue`).
3. **La pantalla de bloqueo nunca puede dejarle fuera.** Desarrolla en modo prueba (ventana falsa con salida
   por Esc y autodesbloqueo); el bloqueo real solo con Ayoub delante y con `swaylock` instalado como respaldo.
4. **Verifica todo lo que construyes.** Config de niri → `niri validate`. QML → mira el journal del servicio.
   UI → captura con `grim` y **mírala** (Read del PNG), compárala con su mockup y corrige hasta que coincida.
   Rendimiento → mide (ver 04-RENDIMIENTO). No marques nada como hecho sin evidencia.
5. **Versiones reales, no memoria.** Comprueba `niri --version`, `qs --version`, `ghostty --version`, `nvim --version`
   y consulta la documentación de ESA versión (niri-wm.github.io/niri, quickshell.org/docs/v0.3.x, ghostty.org/docs).
   Si una API no existe o cambió, adapta y anótalo en DECISIONES.md.
6. **Código original.** Puedes estudiar shells existentes (DMS, Noctalia, Caelestia, end-4) para entender APIs,
   pero OcarinaShell se escribe desde cero siguiendo nuestro diseño. Respeta licencias.
7. **Optimizado de verdad:** eventos en vez de sondeo; nada se anima ni consulta si no se ve; un único proceso
   `qs`; presupuestos en 04-RENDIMIENTO. Todo lo que gaste batería debe apagarse con **忍 Shinobi**.
8. **Todo pasa por los singletons** `Theme`, `Motion`, `Settings`: ni colores ni duraciones ni tamaños sueltos.
   `Motion.enabled=false` (Shinobi / movimiento reducido) debe dejar TODO estático sin romper nada.
9. **Nunca se rompe con una actualización** (06-ACTUALIZACIONES): módulos sensibles aislados en `Loader`, servicios con
   `available`, detección de capacidades, config generada siempre validada, modo seguro, solo paquetes oficiales.
   Todo lo que construyas debe poder mantenerlo 守 Mamori sin intervención de Ayoub (y sin IA, en modo determinista).
10. **El arranque es sagrado**: `/boot`, initramfs, línea del kernel, PAM global y greetd solo mediante scripts de
    `scripts/root/` que ejecuta Ayoub, con snapshot previo y prueba en QEMU/TTY antes del reinicio real.

## Flujo de cada fase (`/fase N`)
1. Lee `docs/PROGRESS.md` y `docs/fases/fase-NN.md` (y lo que esta indique). Si la fase quedó a medias, retómala.
2. Crea tareas (TaskCreate) con los pasos. Snapshot: `sudo snapper -c root create -d "ocarinashell: antes de fase N"`.
3. Implementa en pasos pequeños; valida tras cada paso; commit atómico por hito (`git commit -m "fase N: …"`).
4. Cierre: criterios de aceptación con evidencia (capturas en `docs/evidencias/fase-NN/`, métricas), agente
   `visual-qa` para UI y `perf-auditor` cuando la fase lo pida, actualiza PROGRESS.md y DECISIONES.md,
   y dale a Ayoub una lista corta de qué probar. Espera su feedback antes de la siguiente fase.
- Si la ventana de contexto se llena: actualiza PROGRESS.md con el punto exacto y sigue tras `/compact`.
- Lecturas largas de documentación → delega en un subagente y quédate con el resumen.

## sudo
Comprueba `sudo -n true`. Si funciona, hay un drop-in temporal (`/etc/sudoers.d/90-ocarinashell-temporal`) que
la fase 17 elimina (después solo queda la regla mínima del ayudante `ocarina-maint` de Mamori). Si no funciona, escribe `scripts/root/fase-NN.sh` (idempotente, comentado, con `set -euo pipefail`)
y pide a Ayoub que lo ejecute con `sudo bash …` en otra terminal. Nunca pidas ni guardes su contraseña.

## Estructura del repo (este directorio = `~/ocarinashell`, enlazado al sistema por `scripts/install.sh`)
```
shell/        → ~/.config/quickshell/ocarina   (QML: shell.qml, services/, components/, modules/, ipc/, safe/)
config/niri/  → ~/.config/niri                 config/ghostty → ~/.config/ghostty   config/nvim → ~/.config/nvim
config/fish/, config/starship.toml, config/*   (resto de dotfiles)   templates/ (plantillas del motor de temas)
bin/          → ~/.local/bin (ocarina, ocarina-theme, …)              system/ (ficheros root: polkit, helper, greetd…)
native/       código nativo compilado por scripts/install.sh (nameraka: C++/Vulkan → ~/.local/libexec/ocarinashell/)
scripts/      install.sh, doctor.sh, bench-*.sh, hooks/               docs/, assets/, tools/ (generadores de assets)
tests/        datos falsos para pruebas (p. ej. `ssh_config` con hosts ficticios)
install.sh    (raíz) instalador del kit por curl: descarga/actualiza el repo; NO enlaza nada (eso es scripts/install.sh)
```
Versiones del kit: nueva sección arriba en `CHANGELOG.md` → push a `main` → GitHub Actions «publicar versión» crea sola la
release con el zip reproducible de `tools/release.py` (solo en el repositorio público del kit).
Este repo local tiene como remoto `upstream` el repositorio público del kit: **nunca hagas `push` ahí** (el progreso
de Ayoub va en local o en un repo privado suyo si lo configura).
Estado en ejecución: `~/.config/ocarinashell/settings.json` (ajustes del usuario), `~/.local/state/ocarinashell/`
(tema resuelto, includes generados de niri, historial), `~/.cache/ocarinashell/` (miniaturas, fondos difuminados).

## Convenciones
- Identificadores y comentarios de código en **inglés**; textos de UI en **español** (+ kanji decorativo);
  documentación en español. Nombres de módulos en japonés romanizado: Obi (barra), Shima (isla), Torii (lanzador),
  Engawa (centro de control), Fumi (notificaciones), Koyomi (calendario), Kagi (bloqueo), Dengen (energía),
  Kura (portapapeles), Techo (notas), Mihari (monitor), Settei (ajustes), Kabegami (fondos), Mado (reglas),
  Shinobi (ahorro), Oni (rendimiento), Fune (apps de Windows), Snake (IA local), Mamori (mantenimiento autónomo),
  Haichi (pantallas), Happyō (presentar), Hogo (cuidado OLED), Hikae (copias), Fukugen (restaurar sesión),
  Honban (SSH de producción), Iro (cuentagotas), Shūchū (foco), Yomu (leer y traducir), Nameraka (vídeo fluido).
- QML: un componente por fichero, `pragma ComponentBehavior: Bound`, `required property` en delegates,
  ids en camelCase, sin lógica pesada en bindings, `Loader`/`LazyLoader` para todo lo que no está visible,
  animaciones con `Anim`/`Motion.*` y preferencia por `*Animator` (hilo de render).
- Namespaces de capas: `ocarina-<modulo>`. Destino IPC: nombre del módulo en minúsculas. CLI: `ocarina <cmd>`.
- Bash: `set -euo pipefail`, shellcheck limpio. Python: solo stdlib salvo necesidad justificada.
- Paquetes: repos oficiales/CachyOS primero; AUR **solo con paru** (nunca yay) y leyendo antes el PKGBUILD.

## Comunicación con Ayoub
- Español, directo, sin relleno. Usa AskUserQuestion cuando una decisión sea suya (gustos, privacidad, riesgos).
- Si algo de la spec es imposible o peor que una alternativa, dilo y propón la mejor opción. Él quiere nivel dios,
  no obediencia ciega.
