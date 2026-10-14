---
description: Actualización guiada a mano del sistema (antes de que exista Mamori, o cuando Ayoub quiera hacerla ahora con Claude Code).
disable-model-invocation: true
---

Si 守 Mamori ya está activo (fase 16), lo normal es `ocarina mamori run --interactive`; usa este flujo solo si Ayoub lo
pide o si Mamori no existe aún. Sigue `docs/06-ACTUALIZACIONES.md` y `docs/COMPAT.md`:

1. **Noticias**: `paru -Pw` (Arch) y anuncios recientes de CachyOS (discuss.cachyos.org / blog). Si alguna pide
   intervención manual, explícasela a Ayoub y no sigas sin su visto bueno.
2. **Pendientes**: `checkupdates` + `paru -Qua`. Resalta paquetes críticos (niri, quickshell, qt6-*, ghostty, neovim,
   mesa, linux-cachyos*, limine, plymouth, pipewire, power-profiles-daemon, scx-*, freerdp, docker, llama-cpp-vulkan) y
   los saltos de versión mayor. Para cada crítico con versión nueva, lee su changelog y busca en el repo (grep) las APIs u
   opciones afectadas. Resume el riesgo en 5 líneas.
3. **Snapshot** «ocarinashell: antes de actualizar» (además del de snap-pac). La actualización completa
   (`paru -Syu`, nunca parcial) la lanza Ayoub en su terminal, o tú si hay sudo temporal y él lo aprueba.
4. **Pruebas de humo**: `scripts/smoke-test.sh` (o `ocarina doctor --post-update`). Revisa avisos de deprecación en
   `niri validate` y en el journal de la shell; comprueba que el tema de Limine y el de Plymouth siguen en su sitio.
5. **Si algo falla**: adapta el código a la nueva versión (commits `compat: …`) y repite las pruebas. Si no es viable
   ahora, propone la vuelta atrás (bajar el paquete desde la caché o `snapper undochange`) y deja nota.
6. **Cierre**: actualiza `docs/COMPAT.md` (versiones verificadas + fecha + incidencias) y PROGRESS.md (Registro). Si
   hubo kernel nuevo, pide a Ayoub que reinicie (y que elija el LTS si algo va mal).
