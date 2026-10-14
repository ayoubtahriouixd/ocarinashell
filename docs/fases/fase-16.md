# Fase 16 · 守 Mamori: mantenimiento autónomo

**Objetivo**: que Ayoub no tenga que mantener ni actualizar nada nunca. OcarinaShell se revisa, se actualiza, se adapta y
se repara solo —con Snake como cerebro local y sin depender de suscripciones— y siempre de forma reversible.
**Lee antes**: `docs/06-ACTUALIZACIONES.md` completo (sobre todo la capa 6), `docs/01-ARQUITECTURA.md` §17,
mockup `10-mamori.png`, D-007 y D-008, y lo construido en las fases 14 (piezas deterministas) y 15 (Snake).

## Tareas
1. **Snapshot**.
2. **`bin/ocarina-mamori`** (Python stdlib, modular: `conditions`, `health`, `inventory`, `policy`, `apply`, `verify`,
   `adapt`, `rollback`, `report`): subcomandos de 01-ARQUITECTURA §7, estado en `~/.local/state/ocarinashell/mamori/`,
   registro en el journal, `--dry-run` en todo, un solo ciclo a la vez (`flock`), idempotente y reanudable si se
   interrumpe (apagado, suspensión): cada paso deja constancia en `status.json`.
3. **Condiciones** (06 §Cuándo actúa): CA o batería mínima, red sin límite (`nmcli -g GENERAL.METERED`), sin
   Oni/GameMode (`gamemoded -s`), sin micrófono en uso (PipeWire), sin grabación ni screencast (`niri msg casts`), sin
   inhibidores de inactividad, inactividad ≥ 10 min o sesión bloqueada para instalar (la descarga previa sí en segundo
   plano). Si no se cumplen, reprograma.
4. **Salud y autorreparación**: cada fila del playbook de 06 como comprobación → acción → verificación, con límites
   (no repetir una acción fallida más de 2 veces al día) y escalado a Snake (`diagnose`) si no se resuelve.
5. **Inventario, clasificación y política** (06 §Ciclo): `checkupdates`, `paru -Qua`, noticias (RSS de Arch + CachyOS),
   `arch-audit`, `fwupdmgr get-updates`; maduración (3 días con IA, 7 sin IA), seguridad sin maduración, **lote completo
   o nada** (retener solo kernels/firmware, verificado con `pacman -Sup --ignore …`), AUR solo con `review-pkgbuild` de
   Snake aprobado o diff trivial (comprobación determinista de que solo cambian `pkgver`/`pkgrel`/sumas/URL de versión).
6. **Investigación con Snake**: `triage-news`, `review-changelog` (contra un `grep` de las APIs/opciones que usa el
   repo), `scan-issues` (paquetes críticos × hardware: Radeon 860M, Krackan Point, P14s Gen 6) y `review-pkgbuild` →
   `plan.json` con decisión y motivo + notas `docs/mantenimiento/AAAA-MM-DD.md` con las fuentes enlazadas.
   **Claude Code opcional** (`mamori.ai = snake | claude | both | off`, por defecto `snake`): si Ayoub lo tiene, como
   segunda opinión o escalado, desde un **espacio de trabajo aislado** que crea esta fase:
   `~/.local/share/ocarinashell/mamori-claude/` con `.claude/settings.json` = copia de `.claude/mamori-settings.json`,
   `.claude/skills/mantener` → enlace a la del repo y un `CLAUDE.md` corto (alcance + reglas del repo). Se lanza con
   `cd ~/.local/share/ocarinashell/mamori-claude && claude -p "/mantener …" --add-dir ~/ocarinashell --add-dir ~/.local/state/ocarinashell/mamori --max-turns <N>` y presupuesto (`mamori.claudeBudget`). No uses `--settings` dentro del repo: Claude Code suma los
   permisos de todos los ámbitos y se colarían las reglas amplias del proyecto. Ese perfil (modo dontAsk) solo lee,
   investiga, edita código del repo en la rama `mamori/compat-<fecha>` y escribe su decisión en `plan.json`; no
   ejecuta código del repo, ni sudo, ni `ocarina-maint`: las pruebas y la aplicación son del orquestador.
   **Prueba de jaula** (evidencia): pídele en ese perfil `systemctl --user stop ocarinashell`, `sudo -n true`,
   `bash scripts/smoke-test.sh`, editar `~/.bashrc` y leer `~/.ssh/`: las cinco deben quedar denegadas.
7. **Aplicación**: `ocarina-maint snapshot` → `ocarina-maint upgrade` → AUR con paru (`--noconfirm` solo para lo aprobado)
   → reinicio de servicios de usuario afectados (la shell si cambió Qt/Quickshell) → pruebas de humo.
8. **Adaptación o reversión**: si las pruebas fallan → Snake `diagnose` + `propose-patch` (máximo 3 intentos en la rama
   `mamori/compat-<fecha>`, pruebas tras cada uno) → fusión y commit `compat: …`. Si no lo consigue → `ocarina-maint
   rollback` + retención del lote + informe. Nunca toca nada fuera del repo y de la configuración generada.
9. **Arranque fallido** (marca de la fase 14): retener ese kernel, `ocarina-maint downgrade` al anterior desde la caché,
   informe.
10. **Reinicio**: hanko 新 en Obi + «Actualizar y reiniciar» en Dengen; notificación única si un parche de seguridad del
    kernel lleva > 7 días pendiente; reinicio nocturno solo si Ayoub lo activa.
11. **Periódico** (06 §Mantenimiento periódico): paccache, huérfanos (informe), firmware (BIOS con aprobación de un
    toque), scrub mensual, mirrors, plugins de Neovim (rama → salud y arranque headless → fusión), Fune (`ocarina fune
    update` + ventana de mantenimiento de Windows), Snake (evaluación mensual de modelos nuevos), Hikae (última copia
    ≤ 7 días; `restic check --read-data-subset 5%` mensual con CA; aviso si falla), `claude update` si está instalado,
    滑 Nameraka (tras actualizar lsfg-vk, Mesa, PipeWire, niri o la DLL de Lossless Scaling: `nameraka self-test` +
    recalibración; playbook de 06-ACTUALIZACIONES si falla).
12. **Disparadores**: `ocarina-mamori.timer` (diario 04:00, `Persistent=true`, `RandomizedDelaySec=20m`) + disparo
    oportunista desde la shell (inactiva 15 min y ciclo pendiente) + revisión tras cada arranque si hay marca pendiente.
13. **Informes y UI**: `history.jsonl`, `docs/MANTENIMIENTO.md` (commit), notificaciones agrupadas con hanko 守 (solo
    si hay algo que ver), resumen semanal el domingo, página 守 Mantenimiento en Ajustes (mockup 10: estado, línea
    temporal, retenciones con «liberar ahora», salud, «Deshacer la última actualización», interruptores, tarjeta de
    Snake) + sección **控 Copias** de Hikae (fase 14; sin mockup propio: mismo estilo que los mosaicos de salud).
    `ocarina update` pasa a ser `ocarina mamori run --interactive`.
14. **Seguridad**: Mamori corre como usuario; root solo por `ocarina-maint`; hook de guardia activo en los procesos de
    Claude; Snake sin ejecución libre; interruptor de emergencia; perfil de Claude aislado (paso 6). Comprueba
    que todo funciona solo con la regla sudoers mínima (pide a Ayoub que desactive un momento el drop-in temporal con un
    script root y lo vuelva a activar si la fase 17 aún lo necesita).

## Simulacros (evidencias en `docs/evidencias/fase-16/`)
a) actualización que rompe la shell (cambio de API simulado en una rama de prueba) → Snake adapta o Mamori revierte ·
b) noticia de Arch con intervención manual → plan correcto · c) PKGBUILD sospechoso → no se instala · d) disco casi
lleno simulado (fichero temporal en `~/.cache/ocarinashell/`) → limpieza · e) unidad fallida → reparada · f) arranque
fallido simulado → kernel retenido · g) sin red y sin Snake → modo determinista · h) Oni activo o llamada → aplaza ·
i) en batería → aplaza · j) `ocarina mamori pause` → no hace nada hasta `resume`.

## Criterios de aceptación
- [ ] Los 10 simulacros superados; un ciclo real completo con una actualización real (Ayoub delante la primera vez).
- [ ] Página 守 ≈ mockup 10; informe semanal generado; `docs/MANTENIMIENTO.md` con entradas reales.
- [ ] Mamori funciona solo con la regla mínima del ayudante (sin sudo general).

## Al terminar
PROGRESS.md, commit; deja Mamori activo y explica a Ayoub en 4 líneas qué verá (y qué no) a partir de ahora. La fase 17
revisa su primera semana.
