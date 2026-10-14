# Fase 05 · Torii (lanzador), Kura, Techō, Mihari, Mado, renombrar espacio y chuleta

**Objetivo**: las herramientas de uso diario, rápidas como el pensamiento.
**Lee antes**: mockup 04, `docs/02-DISENO.md` §5, `docs/04-RENDIMIENTO.md` (presupuestos del lanzador).

## Tareas
1. **Snapshot**.
2. **Torii** (`modules/torii/`, Mod+A): panel del mockup 04, **precargado en caliente** (abrir = mostrar).
   - Búsqueda difusa propia, insensible a mayúsculas y tildes (puntuación tipo fzf: inicio de palabra, consecutivas,
     camelCase, acrónimos) sobre nombre, nombre genérico, palabras clave y ejecutable; **frecencia** persistente;
     acciones de escritorio (`DesktopAction`) como sub-resultados.
   - Proveedores por prefijo: `=` calculadora (`qalc -t`, con debounce, resultado copiable), `>` comando (en Ghostty o
     en segundo plano), `?` web (motor configurable), `/` archivos (`fd` limitado a $HOME, cancelable), `@` ventanas
     (lista de niri → enfocar), `:` kanji y emoji (emoji de `emoji-test.txt` de Unicode descargado en caché; kanji de
     `kanji-ui.json` + lista curada; **kaomoji** de `assets/data/kaomoji.json` buscables por palabra en español;
     comprueba que ninguno sale como «tofu»: si falta un glifo, `noto-fonts` o quítalo de la lista) que copia al
     portapapeles, `!` ajustes (salta a la página), `~` **hosts SSH** (nombres `Host` de `~/.ssh/config` y sus
     `Include`, sin comodines; Enter → `ocarina ssh <host>`, ver fase 8; ruta configurable con `ssh.configPath` para
     probar con un fichero falso, porque Claude Code no puede leer `~/.ssh`), acciones del sistema (bloquear,
     suspender, tema, Shinobi, Oni, Windows, foco, cuentagotas, leer pantalla…) siempre buscables en español.
   - Las apps de Windows de la fase 12 llegan como `.desktop` normales: deja previsto mostrarlas con insignia 船.
   - Teclado: ↑↓/Ctrl+J/K, Tab cambia modo, Enter, Ctrl+Enter alternativo, Esc. Ratón y táctil. Escalonado sutil.
3. **Kura** (Mod+V): historial de cliphist con búsqueda, vista previa de imágenes (miniaturas en caché), fijar,
   borrar, vaciar, Enter copia y (opcional, si funciona en niri) pega con `wtype`. Respeta contenido sensible.
4. **Techō** (Mod+N): panel deslizante desde la derecha, notas en `~/.local/share/ocarinashell/notas/*.md`,
   pestañas, autoguardado, búsqueda, recuento de palabras, opción de fuente mincho para escribir «bonito».
5. **Mihari** (Ctrl+Alt+Supr / Mod+M): gráficas CPU (por núcleo), RAM, GPU (`gpu_busy_percent`), temperaturas
   (k10temp, amdgpu, NVMe), potencia de batería en W, red; tabla de procesos (ordenar, filtrar, terminar/matar con
   confirmación). Todo el sondeo vive y muere con la ventana.
6. **Mado** (Mod+Shift+Y): muestra app-id/título de la ventana enfocada, formulario de regla (flotante, tamaño,
   espacio, opacidad, bloquear en capturas, esquinas…), escribe en `~/.local/state/ocarinashell/niri/user-rules.kdl`,
   valida con `niri validate`, lista y borra reglas existentes.
7. **Renombrar espacio** (Ctrl+Shift+R): edición en línea dentro de la isla → `set-workspace-name`/`unset-workspace-name`.
8. **Chuleta** (Mod+Shift+/): superposición que parsea `config/niri/ocarina/binds.kdl` (`hotkey-overlay-title` y
   acción), agrupada (Espacios, Ventanas, Shell, Multimedia, Apps) con cabeceras kanji y búsqueda.
9. **色 Iro · cuentagotas** (`docs/07-IDEAS.md`; Mod+Alt+P, `ocarina pick-color`, acción de Torii): `niri msg
   pick-color` (niri ≥ 25.05) → aviso con muestra, `#hex`, `rgb()`, `oklch()` y el 伝統色 más cercano de
   `colores-nippon.json` (distancia en OKLab: «近い色 · 紅 kurenai #d7003a»); clic en un formato lo copia; los últimos 12
   colores quedan en Kura. Esc cancela.

## Criterios de aceptación
- [ ] Captura ≈ mockup 04. Abrir el lanzador < 1 frame (mide), filtrar < 4 ms por pulsación con todas las apps.
- [ ] Todos los prefijos funcionan; la calculadora maneja unidades y divisas offline de qalc.
- [ ] Kura muestra imágenes; Techō no pierde texto al matar la shell; Mihari coincide con `btop`; Mado genera reglas válidas.
- [ ] Cuentagotas sobre el rojo del logo → 赤/紅 con la menor distancia; `:mesa` da el kaomoji; `~` lista los hosts de
      `tests/ssh_config` (hosts falsos: web-dev, db-prod, nas y router; nunca el comodín) y Enter abre Ghostty con
      `ssh <host>` (el título `ssh · <host>` llega con `ocarina ssh` en la fase 8).

## Al terminar
PROGRESS.md (métricas), commit; propón a Ayoub tres búsquedas para probar el lanzador.
