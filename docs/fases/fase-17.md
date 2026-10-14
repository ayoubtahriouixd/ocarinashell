# Fase 17 · Pulido final, QA independiente y entrega

**Objetivo**: cerrar OcarinaShell 1.0 con calidad de producto: revisión visual y de rendimiento independientes,
robustez, accesibilidad, documentación y limpieza. Opcionales de lujo al final si hay ganas.
**Lee antes**: todos los mockups, `docs/04-RENDIMIENTO.md`, `docs/PROGRESS.md`, `docs/MANTENIMIENTO.md`.

## Tareas
1. **Snapshot**.
2. **QA visual independiente**: lanza el agente `visual-qa` con todas las pantallas (escritorio, Engawa, Torii, Kagi
   en modo prueba, Dengen, despedida, Shinobi, Oni, Fune, Snake, Settei en Kōhaku y Kurenai con las páginas 守 y 画
   Pantalla (mockup 12), menú de Limine en QEMU). Corrige todo lo de severidad alta y media. Repite hasta que no
   queden altas.
3. **Auditoría de rendimiento**: agente `perf-auditor` contra 04-RENDIMIENTO (reposo de la shell, Snake parado, VM de
   Fune en pausa/apagada, Mamori en segundo plano); corrige y vuelve a medir.
4. **Robustez** (además de los simulacros de las fases 14 y 16): matar la shell con popups abiertos; 5 ciclos de
   suspensión; tapa; enchufar/desenchufar CA; monitor externo si Ayoub tiene (conectar/desconectar en caliente, brillo
   de cada pantalla por separado); 20 cambios de tema; 20 Shinobi on/off y 10 Oni on/off; sin red; Bluetooth apagado por
   rfkill; reproductor que desaparece; 100 notificaciones; abrir una app de Windows desde VM apagada, en pausa y activa;
   Snake respondiendo mientras la VM está activa (política de RAM). Cero errores en el journal.
5. **Primera semana de Mamori**: revisa `docs/MANTENIMIENTO.md` y `history.jsonl`: ¿actuó cuando debía?, ¿algún aviso
   innecesario?, ¿alguna decisión dudosa de Snake? Ajusta umbrales y plantillas; amplía `snake/evals/` con los casos reales.
6. **Accesibilidad**: navegación completa por teclado en cada popup, foco visible, contraste AA en Kurenai y Kōhaku
   (calcúlalo con los tokens), movimiento reducido.
7. **Documentación**: `README.md` con capturas REALES (sustituye a los mockups), `docs/03-ATAJOS.md` final,
   `docs/05-RESCATE.md` verificado, `CHANGELOG.md`, `ocarina doctor` completo.
8. **Limpieza**: elimina `/etc/sudoers.d/90-ocarinashell-temporal` (si existe) y comprueba `sudo -n true` → falla (solo
   queda la regla mínima de `ocarina-maint`); borra artefactos de prueba; `scripts/install.sh --dry-run` limpio;
   `git tag v1.0`; snapshot «OcarinaShell 1.0».

## Opcionales (pregunta a Ayoub cuáles quiere)
- Greeter (si se saltó en la fase 6; la fase 13 ya deja preparado el traspaso desde Plymouth).
- Grabador de pantalla con UI completa. Explorador Wallhaven.
- Rotación de fondos por estación (七十二候) con los fondos del usuario etiquetados.
- Snake con voz (transcripción local con Whisper en la NPU si FastFlowLM la soporta).

## Criterios de aceptación
- [ ] visual-qa sin diferencias altas; perf-auditor todo en verde (o justificado en DECISIONES).
- [ ] Lista de robustez completa sin errores. README con capturas reales. sudo temporal eliminado.
- [ ] Mamori + Snake funcionando solos con la regla mínima; primera semana revisada.

## Al terminar
PROGRESS.md (todo ✅), commit y tag; resumen final a Ayoub: qué tiene, cómo usarlo, cómo rescatarlo (y que, en el día a
día, no tiene que hacer nada).
