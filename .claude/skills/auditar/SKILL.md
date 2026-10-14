---
description: Auditoría independiente (rendimiento/energía, visual o código QML). Uso — /auditar rendimiento | visual | qml
argument-hint: "[rendimiento|visual|qml]"
disable-model-invocation: true
---

Tipo: $ARGUMENTS

- **rendimiento** → lanza el agente `perf-auditor` con `docs/04-RENDIMIENTO.md` como contrato; presenta su tabla y
  propone correcciones priorizadas.
- **visual** → lanza el agente `visual-qa` sobre todas las pantallas existentes con sus mockups; hallazgos por severidad.
- **qml** → lanza el agente `qml-reviewer` sobre `shell/` (o sobre el diff reciente); hallazgos con fichero:línea.

No corrijas nada hasta que Ayoub vea el informe, salvo errores evidentes de severidad alta.
