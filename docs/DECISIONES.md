# Decisiones (ADR ligeros)

Formato: `## D-NNN · título` · fecha · contexto · decisión · alternativas descartadas · consecuencias.

## D-001 · Marca roja sobre blanco (紅白)
2026-10-13 · Ayoub pidió el logo «rojo con fondo en blanco». Decisión: rojo `#E60033` (赤) como acento de marca
en todos los temas; tema claro Kōhaku que replica el logo; Kurenai oscuro por defecto (OLED). Se confirma en la
entrevista de la fase 0.

## D-002 · niri + Quickshell, sin demonios de UI externos
2026-10-13 · OcarinaShell es barra, notificaciones, lanzador, bloqueo, polkit y OSD en un único proceso `qs`.
Menos procesos, coherencia visual total y un único interruptor de animaciones/energía (Shinobi).

## D-003 · Kit para Claude Code por fases
2026-10-13 · Especificación + mockups + assets verificados; Claude Code implementa en 18 fases (00–17) con snapshot,
verificación visual y métricas en cada una.

## D-004 · Shinobi y Oni, modos excluyentes con snapshot
2026-10-13 · Ahorro extremo (忍) y rendimiento extremo (鬼) comparten orquestador y estado `normal|shinobi|oni`;
pasar de uno a otro restaura primero el estado previo. Evita combinaciones incoherentes (p. ej. 60 Hz con turbo).

## D-005 · paru como único ayudante del AUR
2026-10-13 · Petición de Ayoub: paru en vez de yay, optimizado (`reference/paru.conf`, `reference/makepkg.conf`):
noticias antes de actualizar, repo local de compilados, `-march=native`, LTO, ccache y compilación en RAM.

## D-006 · Apps de Windows: WinApps + dockur/windows en KVM, Wine/Proton primero
2026-10-14 · Ayoub pidió WinBoat «o alternativa más optimizada». WinBoat (beta, Electron, sin CLI ni accesos `.desktop`)
y WinApps usan la misma base (Windows en KVM vía `dockur/windows` + FreeRDP RemoteApp). Se elige **WinApps** como
motor porque es scriptable, crea accesos `.desktop` con iconos y tipos MIME (aparecen en Torii y Nautilus) y trae pausa
automática; la interfaz la pone OcarinaShell (panel 船). Wine/Proton (`umu-run`) para lo que funcione sin VM.
WinBoat queda como alternativa si Ayoub prefiere su interfaz (fase 12 le pregunta).

## D-007 · Mantenimiento autónomo 守 Mamori, con la IA como extra
2026-10-14 · Ayoub no quiere mantener ni actualizar nada. Orquestador determinista + ayudante root con lista blanca +
pruebas y reversión automáticas; la IA (Snake, D-008) solo investiga, revisa y propone; nunca ejecuta. Sin IA, Mamori
sigue en modo determinista (maduración más larga, AUR solo con diffs triviales).

## D-008 · 蛇 Snake: IA local gratuita en lugar de depender de suscripciones
2026-10-14 · Ayoub pidió una IA local gratis llamada Snake para no depender de suscripciones. Servidor local
OpenAI-compatible (llama.cpp Vulkan en la iGPU por defecto; NPU XDNA 2 con FastFlowLM si es estable), modelos de pesos
abiertos con licencia libre elegidos por evaluación propia, tareas acotadas con salidas JSON validadas, carga bajo
demanda. Claude Code queda como extra opcional (`mamori.ai = claude|both`). Límite asumido: menos capaz que un modelo
grande en reescrituras; por eso todo cambio se verifica y, si no se logra, se revierte.

## D-009 · Brillo por pantalla: DDC/CI con ddcutil y atenuación por software de respaldo
2026-10-14 · Ayoub pidió que, al conectar uno o más monitores, se detecten y cada uno tenga su brillo en el mismo menú.
Decisión: la interna por backlight (`brightnessctl`/logind) y las externas por **DDC/CI** con `ddcutil` (repos
oficiales; el paquete carga `i2c-dev` y da acceso con `uaccess`, sin root), detección solo al cambiar las pantallas y
escrituras coalescidas en cola. Si un monitor no tiene DDC/CI, atenuación por software (capa `ocarina-dim`), marcada
«SW». Descartado: `ddcci-driver-linux` (módulo DKMS del AUR que expondría los monitores como backlight; se rompe con
kernels nuevos, contra la regla 9) y la rampa de gamma (choca con la luz nocturna de wlsunset, que ya usa ese protocolo).
Por DDC/CI solo se escriben brillo y contraste (lo vigila el hook de guardia). Límite conocido: en las pantallas con
atenuación por software, capturas y grabaciones salen oscurecidas (es una capa); Iro y Yomu la ocultan al capturar.

## D-010 · Ideas propias de Claude integradas en el kit
2026-10-14 · Ayoub pidió que Claude añadiera también sus ideas. Se integran 13 (`docs/07-IDEAS.md`) en las fases que
les tocan, todas desactivables en Settei y con el mismo listón que el resto: cero coste en reposo, degradación si falta
un paquete y mantenibles por Mamori. Criterio de selección: que encajen con su equipo (OLED táctil, monitores externos),
su trabajo (administración de sistemas) y su gusto (Japón, anime). Se descartaron fondos animados, widgets de
escritorio, recordatorios de vista y sincronización en la nube (motivos en el mismo documento). Las que cambian solas
el aspecto (tema y brillo según la hora) vienen apagadas.
