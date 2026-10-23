# 04 · Rendimiento y energía — presupuestos y cómo medir

«Fluido nivel dios» se demuestra con números. Todo cambio que toque la UI o un servicio se mide contra esta tabla; las
medidas de cada fase de la construcción están en `PROGRESS.md` y las de cada módulo en su guía (ENERGIA, JUEGOS,
FLUIDO, WINDOWS, SNAKE).

## Presupuestos (portátil en reposo, sesión normal, tema Kurenai)
| Métrica | Objetivo | Cómo medir |
|---|---|---|
| CPU de `qs` en reposo (30 s sin tocar nada) | **< 0,3 %** de media | `pidstat -p $(pidof qs) 1 30` (sysstat) o `top -b -d1 -n30 -p …` |
| Despertares de `qs` en reposo | **< 2 /s** | `sudo powertop --time=30 --csv=/tmp/pt.csv` → fila de `qs` |
| RSS de `qs` | **< 220 MB** (con lanzador precargado) | `ps -o rss= -p $(pidof qs)` |
| Repintados en reposo | **0** salvo el tic del reloj por minuto | instancia de prueba con `QSG_VISUALIZE=changes` |
| Frames durante animaciones | 120 fps sin saltos (8,3 ms/frame) | `QSG_RENDER_TIMING=1` en instancia de prueba; vídeo con `wf-recorder` si hace falta |
| Arranque de la shell (unidad → barra visible) | **< 400 ms** | marcas de tiempo en el log (`console.info` con `Date.now()` en `Component.onCompleted`) + `systemd-analyze --user blame` |
| Abrir lanzador (tecla → primer frame) | **< 1 frame** visual, < 30 ms | marca en IPC → `onVisibleChanged`; precarga caliente |
| Teclear en el lanzador (filtrado) | < 4 ms por pulsación con 300 apps | `console.time` en el filtro |
| Nueva ventana de Ghostty | < 80 ms | marca con `date +%s%N` antes del spawn y evento `WindowOpenedOrChanged` del socket de niri |
| Arranque de fish interactivo | < 40 ms | `hyperfine 'fish -i -c exit'` |
| Arranque de Neovim | < 30 ms | `nvim --startuptime /tmp/st.log +q && tail -1 /tmp/st.log` |
| CPU de niri en reposo | ~0 % | `pidstat -p $(pidof niri) 1 30` |
| Mamori en segundo plano | Nice 19 + IO idle; nunca con el usuario activo jugando o en llamada | `systemctl --user show ocarina-mamori -p CPUWeight,Nice` y su log |

## Reglas que hacen cumplir los presupuestos
1. **Eventos, no sondeo**: socket de niri, PipeWire, UPower/D-Bus, Mpris, BlueZ, NetworkManager, inotify, `docker events`.
   Sondeos permitidos solo con la vista correspondiente visible (Mihari 1–2 s, potencia 5 s, Fune 2 s) y nunca en Shinobi.
   Excepciones medidas: los 墨 medidores de la barra leen `/proc` y `gpu_busy_percent` cada 2 s con `FileView` (sin
   procesos, redondeado al 2 % para no repintar por nada; parados en Shinobi, con la pantalla bloqueada o apagada, y se
   quitan en Ajustes › Barra) y los sensores de Oni cada 2 s solo con Oni encendido.
   DDC/CI (brillo de monitores externos): `ddcutil detect` solo al conectar/desconectar pantallas, lectura al abrir
   Engawa/Settei (caché 30 s) y escrituras coalescidas; cero procesos `ddcutil` en reposo.
   Ideas (07-IDEAS): Hogo y Shūchū cuelgan del tic de minutos de `Time` (ningún `Timer` propio); Fukugen guarda por
   eventos de ventanas (agrupados 30 s); Hikae solo con CA (`Nice=19`, IO idle); Iro, Yomu y Happyō solo al invocarlos.
   滑 Nameraka: ayudante activado por socket solo al encenderlo; sus estadísticas (1/s) solo con Engawa u OSD visibles.
   蛇 Snake y su voz: 0 procesos hasta que se usan; whisper.cpp solo mientras transcribe. 器 El cajón de apps y 広場
   Hiroba solo existen abiertos (el gato y su monitor de picos de PipeWire, solo con Hiroba a la vista).
2. `LazyLoader`/`Loader { active: … }` para todo popup; destruir lo pesado al cerrar (salvo lanzador caliente).
3. Imágenes con `sourceSize` exacto (tamaño en pantalla × escala), `asynchronous: true`, caché de miniaturas en disco.
4. **Nada de blur en QML** (MultiEffect/FastBlur) sobre áreas grandes: el blur lo hace niri («xray» = calculado
   una vez). El fondo difuminado del bloqueo/overview se **pre-renderiza** al cambiar de fondo (vips/magick).
5. Animaciones con `*Animator` cuando sea posible; nada de `Behavior` en propiedades que cambian cada frame.
6. `SystemClock` en precisión de minutos salvo que se muestren segundos.
7. `ListView` con `reuseItems: true` y delegates ligeros; modelos con `ScriptModel` (identidad estable).
8. Textos grandes animados (reloj del bloqueo): `renderType: Text.CurveRendering` (nítido a cualquier escala).
9. Sin `Timer` con `repeat` corriendo en reposo. Cada `Timer` tiene `running:` ligado a visibilidad/estado.
10. Una sola instancia de `qs`. Nada de `Process` lanzado en bucle: procesos largos con `SplitParser`.

## Energía: protocolo de medida
Requisitos: **desenchufado**, brillo fijo (50 %), Wi-Fi conectado, sin Bluetooth en uso, 2 min de reposo antes de medir.
`scripts/bench-power.sh <etiqueta> [segundos=120]` muestrea `/sys/class/power_supply/BAT0/power_now` (o
`current_now × voltage_now`) cada segundo y guarda media, mediana y p95 en `docs/ENERGIA.md`.
Escenarios: A) normal Kurenai 120 Hz · B) normal 60 Hz · C) VRR activado (si el panel lo soporta; vigilar parpadeo) ·
D) Shinobi completo · E) Shinobi + brillo 20 %. Autonomía estimada = `energy_full / potencia media`.
Comprobaciones globales (sin aplicar a ciegas `powertop --auto-tune`): PSR/Panel Replay activo en amdgpu,
ASPM, autosuspend USB (excepto entrada), `power_save` de audio, Wi-Fi powersave en batería, `amd_pmc` y
residencia s0ix tras suspender (`/sys/kernel/debug/amd_pmc/s0ix_stats`), consumo en suspensión (1 h).

## Juegos (鬼 Oni): protocolo de medida
Enchufado, 10 min de calentamiento, misma escena o benchmark integrado de un juego que elija Ayoub + `vkmark`.
MangoHud con registro (`log_duration=60`, `output_folder=~/.local/state/ocarinashell/mangohud/`): FPS medio, 1 % low,
frecuencias CPU/GPU, `Tctl`, temperatura de la GPU y vatios del paquete. Escenarios: normal · Oni · Oni + gamescope
1440×900→2880×1800 FSR. Resultado en `docs/JUEGOS.md` con la configuración ganadora.
Límite duro: ninguna medida justifica superar 97 °C sostenidos.

## Vídeo fluido (滑 Nameraka): presupuestos y protocolo
| Métrica | Objetivo |
|---|---|
| Apagado | **0 procesos**, 0 % CPU/GPU (el socket de systemd espera; la shell no se conecta) |
| Encender (toque → primer fotograma generado) | **< 300 ms** en frío · < 120 ms en caliente (daemon y presentador vivos 60 s tras apagar) |
| Apagar (toque en la tarjeta → app original a la vista) | **≤ 2 fotogramas** (≤ 17 ms a 120 Hz; con el atajo, que pasa por el CLI, ≤ 50 ms) |
| Pausa ⇄ activo (Alt+Tab, vista general, popup) | < 150 ms |
| CPU del ayudante activo | **< 3 %** de un núcleo (cero copias en CPU: DMA-BUF de punta a punta) |
| Fotogramas tarde o perdidos | **< 0,5 %** en 5 min a 120 Hz con 1080p30 ×4, 1080p60 ×2 y 1080p24 A medida (×5) |
| Latencia añadida | ≤ 1 fotograma base + `t_gen` + 12,5 ms (la fórmula de §19); con `avSync`, desfase audio-vídeo dentro de ±15 ms |
| Memoria del ayudante | < 150 MB (motor `lsfg`) |
| Potencia extra | se mide y se publica (no hay tope: es una función que gasta por diseño); `eco` en batería |
Cómo medir: vídeos de prueba generados con ffmpeg a 23,976/24/25/30/60 fps (`testsrc2` + un rótulo en movimiento
horizontal y un contador de fotogramas) en mpv y en Chrome a pantalla completa, más un vídeo real de cada tipo
(anime 24, deporte 60). Las estadísticas del ayudante (`ocarina nameraka status`: base, multiplicador real, salida,
tarde %, latencia, GPU) durante 5 min, `gpu_busy_percent`, `pidstat` del ayudante y MangoHud sobre el presentador (según la
guía de capas superpuestas de lsfg-vk) para la gráfica de tiempos: plana en 8,33 ms cuando base × m = Hz. Potencia con
`scripts/bench-power.sh` (mide descargando: en batería con `battery: normal` y con `eco`; sin Nameraka · ×2 · ×4 ·
A medida). Sincronía: vídeo de destello + pitido (`scripts/fluido-av-test.sh`), a ojo y oído. Resultado en
`docs/FLUIDO.md` (`scripts/bench-fluido.sh`) con la configuración ganadora por resolución y fps base.

## Windows (船 Fune): protocolo de medida
Latencia de apertura de una app (clic en Torii → ventana visible) en frío (VM apagada), templado (VM en pausa) y
caliente (VM activa); eco de tecleo en un editor de texto de Windows (vídeo a 120 fps con `wf-recorder`, contar
fotogramas); CPU de `qemu` y `xfreerdp3` en reposo con una app abierta; consumo extra de batería con la VM activa,
en pausa y apagada (`scripts/bench-power.sh`). Herramienta: `scripts/bench-fune.sh`. Resultado en `docs/WINDOWS.md`
con los ajustes ganadores de FreeRDP.

## IA local (蛇 Snake): protocolo de medida
Para cada combinación backend × modelo × cuantización: tokens/s de prefill (prompt de 2 000 tokens) y de generación,
tiempo hasta el primer token en frío (servicio parado → respuesta) y en caliente, RAM residente, vatios medios durante una
tarea típica (`scripts/bench-power.sh` en paralelo, desenchufado) y aciertos en `snake/evals/`. Objetivo orientativo:
≥ 15 tokens/s de generación, primera respuesta < 15 s en frío y < 2 s en caliente, 0 MB en reposo. Resultado en
`docs/SNAKE.md` (`ocarina-snake eval`): con un solo canal de memoria, la realidad es ~10 tok/s y ~3 s en caliente.
Voz: tiempo de transcripción por segundo de audio en Vulkan y en CPU (≈ 1,3 s por 7 s de voz con GPU libre).
