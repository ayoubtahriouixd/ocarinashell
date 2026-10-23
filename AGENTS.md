# AGENTS.md · OcarinaShell (オカリナシェル)

Guía para agentes de IA (Claude Code, Codex, Gemini CLI, Cursor…) que trabajen en este repositorio. Si usas Claude
Code, `CLAUDE.md` amplía esto y además lo hacen cumplir los *hooks* de `.claude/`. Created by Ayoub.

## Qué es

El escritorio completo de Ayoub sobre **niri + Quickshell** en **CachyOS**: barra, isla, lanzador, centro de control,
bloqueo, ajustes, IA local (蛇 Snake), mantenimiento autónomo (守 Mamori), apps de Windows (船 Fune), vídeo fluido
(滑 Nameraka) y los dotfiles de Ghostty, fish, Neovim y demás. Estética japonesa, marca rojo sobre blanco (紅白).

Máquina de referencia: ThinkPad P14s Gen 6 AMD, OLED 2880×1800 a 120 Hz, escala 1,75. Versiones: niri 26.04,
Quickshell 0.3.2, Qt 6.12. **Consulta siempre la documentación de la versión instalada**, no de memoria.

## Estructura

| Ruta | Qué hay | Se instala en |
|---|---|---|
| `shell/` | QML de la shell: `shell.qml`, `config/` (singletons Theme, Motion, Settings, Paths), `services/`, `components/`, `modules/`, `ipc/`, `safe/` (modo seguro), `shaders/` | `~/.config/quickshell/ocarina` |
| `config/` | niri, Ghostty, fish, starship, Neovim y demás dotfiles | `~/.config/…` |
| `bin/` | CLI `ocarina` y herramientas `ocarina-*` (bash y Python solo con stdlib) | `~/.local/bin` |
| `lib/mamori/` | orquestador de 守 Mamori (lo importa `bin/ocarina-mamori`) | — |
| `native/nameraka/` | C++/Vulkan del vídeo fluido (meson) | `~/.local/libexec/ocarinashell/` |
| `system/`, `scripts/root/` | ficheros y scripts de root (polkit, ayudante `ocarina-maint`, greeter, arranque) | los ejecuta Ayoub con `sudo bash …` |
| `systemd/user/` | unidades de usuario | `~/.config/systemd/user` |
| `templates/` | plantillas del motor de temas (`bin/ocarina-theme`) | — |
| `assets/` | logo, fondos, temas (`data/themes/*.json`), datos (72 kō, kanji…), arranque, mockups | `~/.local/share/ocarinashell` |
| `snake/` | modelos, tareas con esquema JSON, acciones permitidas y evaluaciones de la IA local | — |
| `docs/` | diseño, arquitectura, atajos, rendimiento, rescate, decisiones (`DECISIONES.md`), progreso | — |
| `tests/` | comprobaciones (ver abajo) y datos falsos | — |

`scripts/install.sh` enlaza todo (idempotente; `--dry-run`, `--uninstall`). El estado en ejecución vive fuera del
repo: `~/.config/ocarinashell/settings.json`, `~/.local/state/ocarinashell/`, `~/.cache/ocarinashell/`.

## Reglas que no se negocian

1. **Nunca mates la sesión.** El agente corre dentro de niri: nada de `niri msg action quit`, matar niri o la shell
   a ciegas, reiniciar, apagar ni suspender. Para recargar la shell: guardar el QML (recarga en caliente) o
   `ocarina restart`.
2. **Seguridad antes que nada.** Antes de tocar el sistema, un snapshot (`sudo -n /usr/local/libexec/ocarina-maint
   snapshot "<motivo>"`). Nada destructivo sin preguntar: particiones, `/boot`, initramfs, línea del kernel, PAM,
   sudoers, borrar paquetes o snapshots, `rm -rf` fuera del repo, volúmenes de contenedores (ahí vive Windows).
   El arranque y root solo mediante scripts de `scripts/root/` que ejecuta Ayoub.
3. **La pantalla de bloqueo nunca puede dejarle fuera**: pruebas en modo prueba (`ocarina lock test`, Esc sale).
4. **Su pantalla es suya**: no hagas capturas de pantalla completa con sus ventanas (usa un espacio vacío o
   `tests/render-page.sh`, que dibuja fuera de pantalla), no envíes teclas sintéticas a ciegas y no lances bucles
   que actúen sobre su escritorio sin que él los dispare.
5. **La memoria de la GPU es la sesión**: nada en la GPU sin tamaño + 4 GiB libres (agotar la GTT tumba niri).
6. **Paquetes**: repos oficiales/CachyOS primero; AUR solo con `paru` y leyendo antes el PKGBUILD.

## Cómo se escribe el código

- Identificadores y comentarios en **inglés**; textos de la UI en **español** (+ kanji decorativo); docs en español.
- QML: un componente por fichero, `pragma ComponentBehavior: Bound`, `required property` en delegates, nada pesado en
  bindings, `Loader`/`LazyLoader` para lo que no se ve, eventos en vez de sondeo.
- **Todo pasa por `Theme`, `Motion` y `Settings`**: ni colores, ni duraciones, ni tamaños sueltos. Con
  `Motion.enabled = false` (Shinobi, movimiento reducido) todo queda quieto sin romperse.
- Módulos sensibles aislados (`ModuleLoader`, servicios con `available`) para que una actualización no tumbe la shell.
- Bash: `set -euo pipefail` y shellcheck limpio. Python: solo stdlib.
- Commits pequeños con mensaje en español que diga qué y por qué.

## Cómo se valida (obligatorio antes de dar algo por hecho)

| Cambio | Comprobación |
|---|---|
| QML | `tests/qml-check.sh [ficheros]` (compila los ~220 QML en una instancia aislada, <1 s) y el journal: `journalctl --user -u ocarinashell --since -2min` |
| UI | `tests/render-page.sh <PáginaDeAjustes>` (PNG sin tocar la pantalla) o `tests/capturas-qa.sh` (lo lanza Ayoub) |
| Colores de tema | `tests/contraste.py` (WCAG AA) |
| niri | `niri validate` (los includes generados pasan por `bin/ocarina-niri-gen`) |
| Ghostty | `ghostty +validate-config` |
| Bash | `shellcheck` |
| Shaders | `scripts/build-shaders.sh` (los `.qsb` se versionan) |
| Mamori | `tests/mamori-simulacros.py all` (estado aislado; restaura `docs/evidencias/fase-16` después) |
| Todo | `ocarina doctor` y `ocarina doctor --smoke` |

## Dónde mirar

- `docs/00-VISION.md`, `docs/02-DISENO.md` (tokens, tipografía, movimiento) y `assets/mockups/` (objetivo visual).
- `docs/01-ARQUITECTURA.md` (servicios, IPC), `docs/03-ATAJOS.md`, `docs/04-RENDIMIENTO.md` (presupuestos).
- `docs/05-RESCATE.md` si algo se rompe; `docs/06-ACTUALIZACIONES.md` y `docs/MANTENIMIENTO.md` para Mamori.
- `docs/DECISIONES.md`: por qué cada cosa es como es. Si cambias una decisión, añade una entrada nueva.
