# Fase 11 · 鬼 Oni (rendimiento extremo y juegos) y 滑 Nameraka (vídeo fluido)

Dos partes independientes; cada una se cierra con su commit y su mensaje a Ayoub:
**A · 鬼 Oni** (modo de rendimiento y pila de juego) y **B · 滑 Nameraka** (generar fotogramas en cualquier vídeo, como
Lossless Scaling). La parte B solo necesita las fases 00–04: si Ayoub la pide antes de llegar aquí, hazla en cuanto
termine la fase en curso (`/fase 11b`); en PROGRESS.md, la fila 11 lleva el estado de cada parte.

## Parte A · 鬼 Oni

**Objetivo**: el contrapunto de 忍 Shinobi. Un modo que exprime el P14s Gen 6 (Ryzen AI 7 PRO 350 + Radeon 860M +
LPDDR5X-7500) para jugar, compilar o renderizar: reversible al instante, automático al lanzar un juego y **sin poner en
riesgo el hardware**. Además, una pila de juego completa y bien afinada para una iGPU en un panel de 2880×1800.
**Lee antes**: `docs/01-ARQUITECTURA.md` §10 (misma máquina de estados que Shinobi), mockups `02-centro-de-control.png`
y `08-oni.png`, wiki de CachyOS (gaming, sched-ext/scx_loader, power profiles), docs de gamescope, MangoHud y GameMode.

### Principios
- **Shinobi y Oni son excluyentes**: un único estado de energía `normal | shinobi | oni` con snapshot del estado previo;
  pasar de uno a otro restaura primero y aplica después.
- Lo «máximo» se decide **midiendo** (esta iGPU comparte potencia con la CPU: a veces dar menos CPU = más FPS).
- Límites del fabricante = techo por defecto. Todo lo que los supere es experimental, opcional y vigilado.

### Tareas
1. **Snapshot**.
2. **Pila de juego** (verifica nombres con `pacman -Si`; preferir el meta-paquete de CachyOS si existe): Steam,
   Proton de CachyOS (+ protonup-qt opcional para Proton-GE), `vulkan-radeon` + `lib32-vulkan-radeon` (RADV),
   `gamescope`, `mangohud` + `lib32-mangohud`, `gamemode` + `lib32-gamemode`, `vkbasalt` (opcional), LACT si soporta la
   860M (monitor y perfiles de GPU), reglas udev de mandos (`game-devices-udev` o equivalente), `umu-launcher` (también
   lo usa Fune para apps de Windows). Steam bajo niri vía xwayland-satellite: escala correcta de la interfaz de Steam a
   1,75 y mando funcionando. Comprueba el módulo `ntsync` del kernel (Wine/Proton más rápidos) y actívalo si existe.
3. **Servicio `Modes` (Oni)** (reutiliza el orquestador de Shinobi y el helper `ocarina-powerctl` ampliado con
   operaciones en lista blanca). Pasos, cada uno reversible:
   - **CPU**: PPD `performance` (→ `platform_profile` performance del ThinkPad, EPP `performance`), turbo activado.
     En CachyOS, PPD también cambia el modo de `scx_loader`: comprueba que pasa a modo *gaming* (o configura
     `scx_lavd` en modo rendimiento) y documenta el mecanismo real.
   - **GPU**: `pp_power_profile_mode` 3D_FULL_SCREEN y prueba `power_dpm_force_performance_level` `auto` vs `high`
     con medidas; quédate con lo que dé mejor FPS y 1 % low.
   - **Pantalla**: 120 Hz fijos; VRR para ventanas de juego (regla de niri `variable-refresh-rate true` por app-id de
     gamescope/Steam/juegos) si el panel lo soporta y no parpadea; luz nocturna en pausa (opcional).
   - **Red y periféricos**: Wi-Fi sin ahorro de energía; Bluetooth activo (mandos, cascos); autosuspend USB off para HID.
   - **Escritorio**: No molestar automático (solo críticas), sin blur ni animaciones de shell, sondeos en pausa (tiempo,
     actualizaciones, cliphist de imágenes), Snake descargada, VM de Fune en pausa si no hay apps de Windows abiertas,
     Mamori aplazado; isla en modo Oni: sello 鬼 + temperatura CPU/GPU + vatios (cada 2 s, solo visible). Al activarlo,
     «覚醒»: el sello 鬼 se estampa con una onda expansiva y un brillo rojo recorre los bordes de la pantalla 600 ms
     (una sola vez, nada continuo).
   - **Ventilador al máximo** (opcional, solo con CA): `thinkpad_acpi fan_control=1` (script root, modprobe.d) y nivel
     `full-speed`/`7` durante Oni, `auto` al salir.
   - **Experimental «鬼神 Kishin»** (desactivado por defecto): `ryzenadj` SOLO si `ryzenadj --info` reconoce Krackan Point;
     límites STAPM/PPT moderadamente por encima del perfil de Lenovo, con vigilancia: si `Tctl ≥ 95 °C` 10 s seguidos,
     vuelta inmediata a los límites de fábrica y aviso. Pide confirmación explícita a Ayoub explicando el riesgo.
4. **Automatismo**: `~/.config/gamemode.ini` → `[custom] start=ocarina oni auto-on` / `end=ocarina oni auto-off`
   (al cerrar el juego, vuelve exactamente al estado anterior); opciones de lanzamiento de Steam con `gamemoderun`;
   en batería: preguntar o no activar (Ajustes); salida automática al bajar de 20 % de batería.
5. **gamescope + FSR**: la 860M no mueve juegos modernos a 2880×1800. Plantilla recomendada (render a la mitad exacta
   → escalado nítido):
   `gamemoderun gamescope -W 2880 -H 1800 -w 1440 -h 900 -F fsr -r 120 --adaptive-sync -f -- %command%`
   y variantes 1920×1200 / nativa. CLI `ocarina play <cmd>` y botón «Copiar opciones de Steam» en Ajustes › Juegos.
   Verifica que gamescope anidado funciona bien bajo niri (y documenta alternativas si no).
   Si la parte B ya instaló lsfg-vk: perfiles de lsfg-vk por juego (`~/.config/lsfg-vk/conf.toml`, `active_in` por
   ejecutable o App ID de Steam) desde la página 鬼 de Ajustes — en juegos, lsfg-vk directo da menos latencia que
   capturar.
6. **MangoHud con el diseño**: colores Kurenai, etiquetas kanji (`速` FPS, `脳` CPU, `絵` GPU, `記` RAM, `電` W,
   `熱` temperaturas), posición arriba-izquierda, atajo para mostrar/ocultar, registro para benchmarks.
7. **UI**: tarjeta 鬼 Oni junto a 忍 Shinobi en Engawa (mockup 02), página **鬼 Oni / Juegos** en Ajustes (qué cambia,
   automatismo, ventilador, Kishin experimental, plantillas gamescope, perfiles por juego opcionales), atajo `Mod+Alt+O`,
   CLI `ocarina oni on|off|toggle|status|auto-on|auto-off`, IPC `oni`.
8. **BIOS (manual, con Ayoub)**: si la BIOS del ThinkPad permite tamaño de memoria UMA para la GPU, recomienda el valor
   adecuado (algunos juegos miran la VRAM «dedicada»; también ayuda a Snake en la fase 15) y explica pros y contras; no
   lo cambies tú.
9. **Medidas** (enchufado, mismo juego/escena o benchmark de la elección de Ayoub + `vkmark`): MangoHud 60 s →
   FPS medio, 1 % low, frecuencias CPU/GPU, temperaturas, vatios. Escenarios: normal · Oni · Oni + gamescope FSR ·
   (Kishin si aplica). Resultados en `docs/JUEGOS.md`.
10. **Guardia térmica permanente en Oni**: `Tctl ≥ 97 °C` sostenido o batería < 15 % → salir de Oni y avisar.

### Criterios de aceptación (A)
- [ ] Oni on/off < 1 s, reversible al 100 % (diff de estado), excluyente con Shinobi.
- [ ] Al abrir un juego con GameMode, Oni se activa solo; al cerrarlo, todo vuelve como estaba.
- [ ] `docs/JUEGOS.md` con mejora medida frente a normal (y la configuración ganadora documentada en DECISIONES).
- [ ] Captura ≈ mockup 08; MangoHud tematizado; ninguna temperatura fuera de rango en 20 min de juego.

### Al terminar (A)
PROGRESS.md, commit; explica a Ayoub en 4 líneas cómo lanzar sus juegos para sacar el máximo (plantilla de Steam).

## Parte B · 滑 Nameraka: vídeo fluido en todo el sistema

**Objetivo**: lo que pidió Ayoub, «tipo Lossless Scaling»: ver **cualquier** vídeo a pantalla completa (Chrome, Firefox,
mpv…) con fotogramas generados en tiempo real, hasta 120 fps, con **×2 · ×4 · ×6 · A medida** desde Engawa (junto a
audio y brillo) o con `Mod+Alt+F`; al apagarlo, todo vuelve a la normalidad al instante. Fluido nivel dios: cero copias
en CPU, ritmo atado a los Hz, nada corriendo con el modo apagado.
**Lee antes**: `docs/01-ARQUITECTURA.md` §19 (el diseño completo: captura, motores, ritmo y multiplicador efectivo,
estados, capas, audio, energía, protocolo), `docs/02-DISENO.md` (tarjeta 滑 Fluido, página Fluido, isla «armando», OSD,
página de Settei), mockups `02-centro-de-control.png` y `13-fluido.png`, `docs/04-RENDIMIENTO.md` §Vídeo fluido, la
documentación de **tu versión** de lsfg-vk (lsfg-vk.dev/docs: configuración, opciones, variables de entorno, ritmo, CLI) y
`src/dbus/mutter_screen_cast.rs` de **tu versión** de niri. Delega las lecturas largas en un subagente.
**Hecho que no hay que preguntar**: Ayoub tiene Lossless Scaling comprado en Steam.
**Si se hace antes de la fase 11** (`/fase 11b`): solo necesita las fases 00–04. Deja anotados en PROGRESS.md los
enganches que falten: página de Settei (fase 7), cambio de Hz y VRR a través de `Displays` (fase 7), bloqueo en Shinobi
(fase 10) y calidad máxima en Oni (parte A).

### Tareas
1. **Snapshot**.
2. **Motor LSFG** (nombres verificados con `pacman -Si` / `paru -Si`):
   - Steam (si la parte A no lo instaló; repos oficiales, multilib). Pide a Ayoub que instale **Lossless Scaling** y lo
     pase a la rama beta **`lsfg-vk`** (Biblioteca → Propiedades → Betas). Si Steam no deja descargarlo por ser de
     Windows, que active Steam Play para ese título. Espera a que te confirme; comprueba dónde quedó (biblioteca de Steam).
   - **lsfg-vk ≥ 2.0**: repos de CachyOS si lo tienen; si no, AUR con paru (`lsfg-vk-bin` o `lsfg-vk`, PKGBUILD leído;
     nunca `-git`). Licencia CC BY-NC-ND: se instala y se configura, nunca se modifica ni se redistribuye.
   - Verifica: `lsfg-vk-cli healthcheck`; `vkcube` con un fichero de prueba (`LSFGVK_CONFIG=<prueba.toml>
     LSFGVK_PROFILE=prueba vkcube`, el cubo gira más despacio y el log nombra el perfil) frente a `DISABLE_LSFGVK=1 vkcube`;
     y `lsfg-vk-cli benchmark -w 2880 -h 1800 -m 2` (y `-m 4`). Anota versiones en COMPAT.md (Notas). Si lsfg-vk se carga
     como capa implícita, añade `Environment=DISABLE_LSFGVK=1` a las unidades propias que usan la GPU (Snake…).
3. **Prueba de concepto de la captura, antes de escribir C++**: `busctl --user introspect org.gnome.Mutter.ScreenCast
   /org/gnome/Mutter/ScreenCast`; una sesión a mano (`CreateSession` → `RecordWindow` con el id de `niri msg -j windows`
   y `cursor-mode` 0 → `Start`) mientras `busctl --user monitor` muestra `PipeWireStreamAdded`. `busctl` abre una conexión
   por llamada: anota si niri cierra la sesión cuando el cliente se desconecta (si la cierra, haz la prueba ya dentro del
   ayudante, con una sola conexión). Consume el nodo con
   `gst-launch-1.0 -v pipewiresrc path=<nodo> ! fpsdisplaysink video-sink=fakesink text-overlay=false` (si está el
   plugin de PipeWire de GStreamer) y comprueba que sale en `pw-dump` y en `niri msg casts`. Con vídeos de 24/30/60 fps a
   pantalla completa en Chrome y en mpv, anota: cadencia real que entrega niri, formatos y modificadores DMA-BUF, si
   trae `SPA_META_VideoDamage`. Cierra con `Stop`. Si algo de §19 no se cumple en tu versión, adapta y anótalo.
4. **Ayudante `native/nameraka`** (C++20 + meson, solo dependencias oficiales; `-Werror` en desarrollo; pruebas unitarias
   en `native/nameraka/tests/` del estimador de base, el multiplicador efectivo con su aviso, el retardo de audio, la
   máquina de estados y el escritor de `lsfg.toml`). Hitos, cada uno verificado antes del siguiente:
   a. **`view` con fuente de prueba** (patrón animado interno a 30 fps) en una capa `overlay` `ocarina-nameraka` sin
      entrada → `grim` + Read: 1:1 con el panel (sin reescalar) y ratón y teclado llegan a la ventana de debajo.
      Excluye `ocarina-nameraka` de la regla de capa `^ocarina-` (sombras), como `ocarina-dim`, y valida con niri.
   b. **+ captura real** (PipeWire DMA-BUF de la ventana con foco), deduplicación y estimador de base: CPU del
      ayudante < 3 % con `pidstat`; `perf top` sin copias de memoria del ayudante.
   c. **+ lsfg-vk**: `LSFGVK_CONFIG`/`LSFGVK_PROFILE`, `lsfg.toml` propio validado con `lsfg-vk-cli validate`; recarga en
      caliente de multiplicador, flujo y modo rendimiento sin cortes (prueba si aguanta un `rename` atómico). Vídeos de
      prueba (04-RENDIMIENTO) en mpv y Chrome a pantalla completa. Mide con MangoHud la cadencia real de 30 × 4, 30 × 2
      y 24 × 4 a 120 Hz y confirma (o corrige) la tabla del multiplicador efectivo de §19.
   d. **`daemon`**: unidades `ocarina-nameraka.socket` + `.service` y `ocarina-nameraka-selftest.service`
      (`selftest.json`), protocolo de control, estados de §19 (objetivo = última ventana enfocada; el foco de la shell no
      cuenta), «armando» (pista y botón solo en reproductores), pausa ⇄ activo < 150 ms, cierre tras 60 s, presentador
      en caliente y **vigilante** (mata el presentador si no presenta en 1 s; `ocarina nameraka off` cae en
      `systemctl --user stop` si el socket no responde). **Capas**: Engawa, Fumi, Dengen y el OSD de Fluido deben estar
      en `overlay` para verse sobre la pantalla completa (si la fase 4 los dejó en `top`, cámbialos); comprueba que lo
      mapeado después queda encima y que, al activarse Nameraka, volver a mapear los popups abiertos los deja por
      encima; si no, `paused` mientras se vean. Prueba que el atenuado por software de la pantalla se mantiene.
   e. **Audio sincronizado** (§19) con el vídeo de destello + pitido: comprueba si el nodo de retardo declara latencia
      (entonces los reproductores la compensan y no sirve) y que WirePlumber no recuerde el destino. Ayoub lo valida a
      ojo y oído; si no convence, `avSync` queda apagado por defecto y se anota el motivo.
   f. **Calibración y guardias** (`calibration.json` con `t_gen` y la huella de la DLL, escalones de calidad, `Tctl`,
      `gpu_busy_percent`), batería `eco`, «A medida» con otro modo de pantalla (60 Hz) a través de `Displays`.
   g. **Motor `ia` (puerta)**: benchmark de RIFE «lite» con `ncnn` (paquete oficial si existe) en la 860M a la resolución
      de flujo; si sostiene ×2 a 30 fps base con margen 1,3 sin pasar del 70 % de GPU, intégralo (A medida exacto, ritmo
      propio, VRR opcional) con `-Dia=enabled` y modelos con SHA-256 fijado en `assets/data/nameraka-models.json`; si
      no, déjalo fuera con la cifra medida (la UI lo muestra deshabilitado con el motivo).
5. **Shell** (QML, reglas de CLAUDE.md): `services/Nameraka.qml` (`FileView` de `selftest.json` + `Socket` solo con
   Fluido encendido; manda `pause`/`resume` al bloquear y al apagarse la pantalla), tarjeta 滑 Fluido en Engawa
   (mockup 02), página Fluido (mockup 13), isla «armando» y OSD, IPC `nameraka`, CLI `ocarina nameraka …` (alias
   `fluido`), binds `Mod+Alt+F` y `Mod+Alt+Shift+F` en `config/niri/ocarina/binds.kdl` (con `niri validate`), ajustes
   `nameraka {…}` y la página 滑 de Settei (si la fase 7 ya está; si no, queda para ella). `scripts/install.sh` compila
   e instala el ayudante; `ocarina doctor` incluye `nameraka self-test`; 05-RESCATE, la entrada de «pantalla congelada».
6. **Energía**: Shinobi lo apaga y lo bloquea (si la fase 10 ya está), batería `eco`, Oni calidad máxima.
   `vrrWhileActive` solo con el motor `ia`, si el panel admite VRR y las medidas con 25/50 fps mejoran sin parpadeo.
7. **Medidas** (04-RENDIMIENTO §Vídeo fluido) → `docs/FLUIDO.md`, y `perf-auditor` sobre el ayudante y la shell.
8. **Visual**: capturas de la tarjeta y la página contra los mockups 02 y 13 con `visual-qa`; corrige hasta que
   coincidan.
9. **DECISIONES.md** (siguiente número libre): «滑 Nameraka» con lo medido: motor y calidad por defecto por
   resolución/fps base, cadencias reales, si `ia` pasó la puerta, si `avSync` va por defecto, cómo quedaron las capas y
   cualquier diferencia con §19.

### Criterios de aceptación (B)
- [ ] Vídeo de 30 fps en Chrome a pantalla completa: un toque en Engawa → 120 fps generados (×4 o A medida) en
      < 300 ms; otro toque → la app original en ≤ 2 fotogramas, sin haberla tocado.
- [ ] ×2 · ×4 · ×6 · A medida cambian en caliente sin cortes; la tarjeta enseña el multiplicador real («×6 → ×4 ·
      120 Hz») y avisa ⚠ cuando base × m ≠ Hz (24 × 4, 30 × 2).
- [ ] Con Fluido activo, ratón, teclado y táctil siguen funcionando en el vídeo (pausa, barra de progreso, salir con F/Esc),
      y Engawa se puede abrir y usar encima sin que se pause.
- [ ] Alt+Tab, vista general, otro espacio, bloqueo o apagar pantalla → se aparta al instante y vuelve solo (< 150 ms).
- [ ] < 0,5 % de fotogramas tarde en 5 min (1080p30 ×4, 1080p60 ×2, 1080p24 A medida) con la calibración por defecto;
      CPU del ayudante < 3 %; 0 procesos y 0 consumo con Fluido apagado.
- [ ] El vigilante funciona: con el presentador detenido a propósito (`kill -STOP`), la capa desaparece en ≤ 1 s.
- [ ] Audio sincronizado si `avSync` (Ayoub no nota desfase); Shinobi lo bloquea (cuando exista).
- [ ] Capturas ≈ mockups 02 y 13; `ocarina doctor` explica cualquier falta (sin lsfg-vk, sin DLL, sin ScreenCast…).

### Al terminar (B)
PROGRESS.md (fila 11: estado de la parte B), commit; 4 líneas para Ayoub: cómo activarlo (tarjeta 滑 o `Mod+Alt+F`),
que «A medida» (por defecto) es lo mejor casi siempre y ×2/×4/×6 sirven para fijarlo, que funciona a pantalla completa
y qué esperar (algún artefacto en texto que se mueve rápido, como en Lossless Scaling).
