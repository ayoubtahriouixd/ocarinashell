---
description: Actualiza el propio kit de OcarinaShell a una versión publicada (remoto upstream) sin perder el progreso de las fases. Uso — /actualizar-kit [vX.Y.Z|main]
argument-hint: "[vX.Y.Z o main; vacío = la última publicada]"
disable-model-invocation: true
---

Versión pedida: $ARGUMENTS (vacío = la última publicada; si no hay ninguna, `main`).

El kit vive en este repo; las versiones nuevas llegan del remoto `upstream` (el repositorio público del kit). El
progreso de Ayoub son los commits locales de las fases en `main`. **Nunca hagas push a `upstream`.**

1. **Estado limpio**: `git status` sin cambios (si los hay, commit «fase NN: …» o pregunta). Si hay una fase 🟨 a medias,
   díselo a Ayoub: lo normal es actualizar entre fases.
2. **Objetivo**: `git fetch --tags upstream`; la última etiqueta `vX.Y.Z` (orden de versiones) o `upstream/main` si se
   pide `main` o aún no hay etiquetas. Si ya es antepasado de `HEAD`, no hay nada que hacer: dilo y para.
3. **Qué trae**: la sección nueva de `CHANGELOG.md` del objetivo (`git show <objetivo>:CHANGELOG.md`) y
   `git diff --stat HEAD...<objetivo>`. Resúmeselo a Ayoub en 3–5 líneas antes de fusionar.
4. **Respaldo**: `git branch respaldo/antes-de-<objetivo>` (solo cambia el repo: no hace falta snapshot del sistema).
5. **Fusión**: asegúrate de que `.git/info/attributes` tiene `docs/DECISIONES.md merge=union` y
   `docs/MANTENIMIENTO.md merge=union`; luego `git merge --no-edit <objetivo>`. Si hay conflictos:
   - `docs/PROGRESS.md`: manda lo de Ayoub (estados, métricas, registro); añade solo lo nuevo del kit.
   - `docs/DECISIONES.md`: con `merge=union` no da conflicto y se conservan ambas; tras fusionar, busca números
     repetidos (`grep -o '^## D-[0-9]*' docs/DECISIONES.md | sort | uniq -d`) y renumera los del kit a los siguientes libres.
   - Especificación y herramientas (`docs/`, `CLAUDE.md`, `.claude/`, `assets/`, `tools/`, `reference/`): manda el kit,
     salvo adaptaciones deliberadas de las fases (las anotadas en DECISIONES.md), que se mezclan a mano.
   - Lo ya construido (`shell/`, `config/`, `bin/`, `system/`, `scripts/`, `native/`, `systemd/`): manda lo de Ayoub; si
     el kit cambió algo ahí, aplícalo encima con cuidado y valídalo.
6. **Comprobación**: `python3 scripts/hooks/test-guard.py`; `niri validate` si cambió `config/niri`; reinicio de la
   shell y journal si cambió `shell/`; `scripts/install.sh` si hay enlaces o unidades nuevas.
7. **Cierre**: commit «kit: fusiona <objetivo>», entrada en el Registro de PROGRESS.md y resumen a Ayoub: qué trae, qué
   fases nuevas o cambiadas le afectan (y si alguna puede adelantarse, como la parte B de la fase 11) y si conviene
   salir y volver a entrar en Claude Code (`claude --continue`) para que lea la nueva versión de CLAUDE.md y las skills.
