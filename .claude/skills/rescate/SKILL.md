---
description: Diagnóstico y recuperación cuando algo de OcarinaShell falla (shell, niri, bloqueo, temas, arranque, modos, Windows, Snake, Mamori).
argument-hint: "[descripción del problema]"
disable-model-invocation: true
---

Problema descrito: $ARGUMENTS

1. Diagnóstico: `scripts/doctor.sh` (o equivalentes): estado de `ocarinashell.service` y del modo seguro, últimas 80
   líneas del journal, `niri validate`, enlaces de `install.sh`, conflictos (otros demonios de notificación/polkit),
   modo de energía activo (Shinobi/Oni), estado de Fune (`ocarina fune status`), de Snake (`ocarina snake status`) y de
   Mamori (`ocarina mamori status`, retenciones), espacio en disco, `git status` y `git log -5`.
2. Identifica la causa más probable y propone la corrección mínima. Si viene de un commit reciente, `git revert`.
   Si viene de una actualización, sigue `docs/06-ACTUALIZACIONES.md` (reversión con `ocarina mamori rollback`, bajar el
   paquete desde la caché o adaptar el código).
3. Si el sistema está muy roto, guía con `docs/05-RESCATE.md` (TTY, kernel LTS, snapper). Nunca borres snapshots, ni el
   disco de Windows, ni hagas cambios destructivos sin preguntar; lo que toque `/boot` va en un script de `scripts/root/`
   que ejecuta Ayoub.
4. Tras arreglar: verifica, commit y anota el incidente en PROGRESS.md (sección Registro) y en `docs/MANTENIMIENTO.md`.
