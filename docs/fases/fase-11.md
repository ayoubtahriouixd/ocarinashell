# Fase 11 · 鬼 Oni: rendimiento extremo y juegos

**Objetivo**: el contrapunto de 忍 Shinobi. Un modo que exprime el P14s Gen 6 (Ryzen AI 7 PRO 350 + Radeon 860M +
LPDDR5X-7500) para jugar, compilar o renderizar: reversible al instante, automático al lanzar un juego y **sin poner en
riesgo el hardware**. Además, una pila de juego completa y bien afinada para una iGPU en un panel de 2880×1800.
**Lee antes**: `docs/01-ARQUITECTURA.md` §10 (misma máquina de estados que Shinobi), mockups `02-centro-de-control.png`
y `08-oni.png`, wiki de CachyOS (gaming, sched-ext/scx_loader, power profiles), docs de gamescope, MangoHud y GameMode.

## Principios
- **Shinobi y Oni son excluyentes**: un único estado de energía `normal | shinobi | oni` con snapshot del estado previo;
  pasar de uno a otro restaura primero y aplica después.
- Lo «máximo» se decide **midiendo** (esta iGPU comparte potencia con la CPU: a veces dar menos CPU = más FPS).
- Límites del fabricante = techo por defecto. Todo lo que los supere es experimental, opcional y vigilado.

## Tareas
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

## Criterios de aceptación
- [ ] Oni on/off < 1 s, reversible al 100 % (diff de estado), excluyente con Shinobi.
- [ ] Al abrir un juego con GameMode, Oni se activa solo; al cerrarlo, todo vuelve como estaba.
- [ ] `docs/JUEGOS.md` con mejora medida frente a normal (y la configuración ganadora documentada en DECISIONES).
- [ ] Captura ≈ mockup 08; MangoHud tematizado; ninguna temperatura fuera de rango en 20 min de juego.

## Al terminar
PROGRESS.md, commit; explica a Ayoub en 4 líneas cómo lanzar sus juegos para sacar el máximo (plantilla de Steam).
