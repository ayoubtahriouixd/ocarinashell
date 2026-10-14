---
description: Ejecuta una fase del plan de OcarinaShell (docs/fases/fase-NN.md). Uso — /fase 3 · /fase 11b
argument-hint: "[número de fase 0-17; 11a/11b = una parte de la fase 11]"
disable-model-invocation: true
---

Fase solicitada: $ARGUMENTS

1. Normaliza el número a dos cifras (3 → 03) y lee COMPLETO `docs/fases/fase-NN.md`, luego `docs/PROGRESS.md` y las
   lecturas que la fase indique en «Lee antes» (delega en un subagente las lecturas largas de documentación externa).
   Con una letra (`11a`, `11b`) ejecuta SOLO esa parte («Parte A», «Parte B») con sus propios prerrequisitos, tareas,
   criterios y cierre, y en PROGRESS.md marca el estado de esa parte dentro de la fila de la fase.
2. Prerrequisitos: las fases anteriores deberían estar ✅ en PROGRESS.md. Si no lo están, díselo a Ayoub y pregunta
   si continuar. Si esta fase está 🟨, retómala exactamente desde el último punto registrado.
3. Marca la fase 🟨 en PROGRESS.md, crea las tareas (TaskCreate) con los pasos de la fase y haz el snapshot:
   `sudo snapper -c root create -d "ocarinashell: antes de fase NN"` (o el script root si no hay sudo).
4. Ejecuta las tareas en orden, validando cada paso (CLAUDE.md, reglas 4 y 9). Commits atómicos `fase NN: …`.
5. Comprueba CADA criterio de aceptación con evidencia (capturas en `docs/evidencias/fase-NN/`, métricas, logs).
   Usa los agentes `visual-qa`, `perf-auditor` o `qml-reviewer` cuando la fase lo pida o haya UI/QML nueva.
6. Cierre: PROGRESS.md (✅, hecho, métricas, pendientes, qué probar), DECISIONES.md si hubo decisiones, commit final y
   un mensaje a Ayoub en español: qué se hizo (3–5 líneas), qué probar (lista corta), si debe reiniciar sesión o equipo,
   y cuál es la siguiente fase. Espera su feedback antes de empezar otra fase.
