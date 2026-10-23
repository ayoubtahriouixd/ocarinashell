# 鬼 Oni y juegos — medidas y cómo jugar

> Medido en la fase 11 (parte A), 2026-10-16. Máquina: ThinkPad P14s Gen 6 AMD · Ryzen AI 7 PRO 350 (Krackan Point) · Radeon 860M (RDNA 3.5,
> 8 CU) · 32 GB en **un solo módulo** (un canal, 5600 MT/s efectivos) · 8 GB de UMA · panel 2880×1800 a 120 Hz.
> Todo enchufado. Herramienta: `scripts/bench-oni.sh` (vkmark sin ventana a 2880×1800, o anidado en gamescope
> headless a 1440×900 → FSR → 2880×1800) con muestreo cada 0,5 s de Tctl, temperatura de la GPU, PPT (potencia del
> paquete APU que da amdgpu), reloj de la GPU (`pp_dpm_sclk`) y media de relojes de la CPU.

## Conclusiones (lo que hace Oni y por qué) — D-060

| Palanca | Medida | Decisión |
|---|---|---|
| **PPD «rendimiento»** (= `platform_profile` performance de Lenovo, EPP performance, turbo) | tanda 1, CPU+GPU: 2105 → 2531 (**+20 %**); PPT 24 → 30 W (Lenovo sube el límite) · solo GPU: +1 % | **sí** (el núcleo de Oni) |
| **scx_lavd en modo juego** (vía scx_loader; PPD lo mantiene en «gaming») | CPU+GPU: +8–10 % (tanda 1) y +3 % / +6 % en Oni (tanda 2, A/B alternado) **gastando menos** (30 frente a 35 W) | **sí**, por defecto (`oni.scx`) |
| GPU `high` frente a `auto` (`power_dpm_force_performance_level`) | −1 % / +1 %: ruido | **no**: `auto` por defecto («Alta» queda en Ajustes) |
| `pp_power_profile_mode` 3D_FULL_SCREEN | no existe en la 860M con el kernel 7.2 (SMU 14) | no aplicable |
| «Prioridad a la GPU» (turbo de CPU apagado) | CPU+GPU: 2531 → 2756 (**+9 %**): el presupuesto compartido va a la gráfica | opción, **apagada** (en juegos limitados por CPU pierde) |
| gamescope 1440×900 → FSR → 2880×1800 | ×2,2–2,4 la puntuación nativa (8435–8968 frente a 3549–4056) | plantilla por defecto |
| Oni frente a normal (tanda 2) | CPU+GPU: 3549 → 4056 (**+14 %**) y 3789–4031 sostenido · solo GPU: +2 % · con gamescope: +6 % | — |

Lectura: esta APU comparte un único presupuesto de potencia entre CPU y GPU. Lo que más rinde es **subir ese
presupuesto** (perfil de Lenovo) y **repartirlo mejor** (lavd da la CPU a quien mueve los fotogramas); forzar relojes no
aporta nada. El turbo apagado demuestra el «menos CPU = más FPS», pero depende del juego: por eso es una opción.
Temperaturas en las pruebas: Tctl máx 89 °C con CPU+GPU a 42 W en el primer minuto (el ventilador del firmware lo
contiene), lejos del límite de 100 °C y de la guardia de Oni (97 °C durante 10 s).

## Prueba térmica (criterio «20 min sin temperaturas fuera de rango»)
`scripts/soak-oni.sh 20` en 鬼 Oni, enchufado: vkmark sin ventana en bucle + 6 hilos de CPU (peor caso del presupuesto
compartido), muestra cada 2 s (`docs/evidencias/fase-11/soak-oni.csv`, 584 muestras, el modo siguió en `oni` todo el rato).

| Tctl máx / media | GPU máx / media | PPT media (1.er min / últimos 10 min) | sclk media | Ventilador máx | Muestras ≥ 95 °C |
|---|---|---|---|---|---|
| **80,1 / 71,8 °C** | **65 / 62,6 °C** | 29,0 W (29,4 / 29,0) | 2529 MHz | 5319 rpm | 0 |

El límite sostenido del perfil de Lenovo (~29 W) llega antes que el térmico: el equipo no se acerca a la guardia de Oni
(97 °C) ni al límite de la CPU (100 °C). Con el ventilador al máximo (tras `scripts/root/fase-11.sh`) habría margen para
temperaturas más bajas, no para más potencia (el tope lo pone el firmware, no la temperatura).

## Coste de Oni en la shell
`qs` en reposo 0,05 % de CPU; con Oni (isla con sensores cada 2 s) 0,7 % en 20 s que incluyen el toast. Memoria del
cgroup recién arrancada 222 MB. Con Oni apagado no se lee ningún sensor.

## Cómo jugar para sacar el máximo

1. **Steam** (Biblioteca › juego › Propiedades › Opciones de lanzamiento): pega lo que da **Ajustes › Oni › Copiar**
   (o `ocarina play --steam`). Por defecto, mitad exacta + FSR (nítido y el doble de fps):
   `gamemoderun gamescope -W 2880 -H 1800 -w 1440 -h 900 -F fsr -r 120 --adaptive-sync -f --force-grab-cursor --backend sdl --mangoapp -- %command%`
   Variantes: `1920×1200 + FSR` para juegos ligeros, `nativa` para 2D/indies, `sin gamescope`
   (`MANGOHUD=1 gamemoderun %command%`) si un juego se lleva mal con gamescope.
2. **GameMode** enciende 鬼 Oni solo al abrir el juego y lo apaga al cerrar el último, devolviendo todo como estaba
   (`gamemoderun` está en las plantillas; con batería pregunta antes).
3. **Proton**: Steam › Ajustes › Compatibilidad → `proton-cachyos-slr` (repos de CachyOS; Proton-GE con protonup-qt si un
   juego lo pide). `ntsync` está cargado (`/dev/ntsync`): Proton/Wine lo usan solos.
4. **MangoHud**: Mayús dcha + F12 lo muestra u oculta; Mayús izda + F2 graba 60 s en
   `~/.local/state/ocarinashell/mangohud/` (para comparar ajustes de un juego).
5. Fuera de Steam: `ocarina play <orden>` (Lutris/Heroic: el mismo prefijo en sus «opciones de lanzamiento»).

## gamescope dentro de niri
- Anidado con `--backend sdl --force-grab-cursor`: el backend Wayland de gamescope no bloquea bien el puntero en niri
  (wiki de niri «Application issues», gamescope #1711). `--mangoapp` es la forma soportada de MangoHud en gamescope.
- `--adaptive-sync` anidado solo vale si niri ya tiene el VRR encendido para esa ventana: lo hace la regla de `oni.kdl`
  (`app-id` `gamescope`, `steam_app_*`, `steam_proton`) con la salida en `variable-refresh-rate on-demand=true`.
- Sin `cap_sys_nice` en gamescope (no se toca el binario del paquete: se perdería en cada actualización).
- Las medidas de arriba son sin pantalla (`--backend headless`); con ventana se usa la plantilla de Ajustes › Oni.

## Steam bajo niri
xwayland-satellite 0.8 entrega a las apps X11 píxeles nativos (nítidas, pero diminutas a escala 1,75) y publica
`Xft.dpi 168`. La interfaz de Steam se escala con `STEAM_FORCE_DESKTOPUI_SCALING=1.75`
(`config/environment.d/60-ocarina.conf` y `environment.kdl`): deja el deslizador de Accesibilidad de Steam al 100 % para no
escalar dos veces. Mandos: reglas udev de `steam-devices` (vienen con Steam).

## BIOS (a mano) — no se cambia desde aquí
- **Lo que más rendimiento da no es un ajuste: es el segundo módulo de RAM.** El equipo tiene un solo SO-DIMM (un canal,
  5600 MT/s). La 860M vive del ancho de banda de la RAM: con dos módulos iguales (doble canal) la GPU integrada suele ganar
  del orden de +30–60 % en juegos. Si el P14s tiene la segunda ranura libre, es la mejor inversión.
- **Memoria UMA para la GPU**: hoy 8 GB. Con 32 GB de RAM, **dejarla en 8 GB** (o «Auto» si la BIOS lo ofrece): hay juegos
  que miran la VRAM «dedicada» y se niegan a arrancar o bajan texturas con menos de 4–6 GB, y Snake también la
  aprovecha. Contra: esos 8 GB se restan de la RAM del sistema (quedan 24). Bajarla a 4 GB solo tiene sentido si la RAM se
  queda corta (no es el caso). Los controladores pueden usar además memoria GTT compartida más allá de la UMA.

## Notas
- LACT (instalado) soporta APUs RDNA 3.5 para monitorizar; su servicio `lactd` no se activa: Oni ya gobierna la GPU y dos
  dueños del mismo ajuste se pisarían. Para usarlo: `sudo systemctl enable --now lactd`.
- 鬼神 Kishin (ryzenadj por encima de los límites de Lenovo): descartado por decisión de Ayoub (D-060).
- vkBasalt no está en los repos oficiales (solo AUR): no se instala.

## Medidas

Dos tandas. **Solo se comparan filas de la misma tanda**: entre la 1 (22:57–23:06) y la 2 (desde 23:28) la misma
escena da ~40 % más con la misma potencia y el mismo reloj de GPU, así que algo del estado de la máquina cambió entre
medias (memoria/fclk de la APU, caché de sombreadores o la carga de la batería: en la tanda 2 estaba «sin cargar» al 79 %);
no se pudo reproducir la tanda 1. Las conclusiones salen de pares medidos uno detrás de otro (A/B alternados).

| Fecha | Escenario | Carga | Puntuación vkmark | FPS por escena | Tctl media / máx °C | GPU media / máx °C | PPT W | sclk MHz | CPU MHz |
|---|---|---|---|---|---|---|---|---|---|
| 2026-10-16 22:57 | normal (balanced · GPU auto) | mix · native | **2105** | vertex 4955 texture 2502 shading 1963 effect2d 710 desktop 1080 cube 1422  | 64.3 / 67.2 | 55.5 / 58.0 | 24.0 | 1470 | 2466 |
| 2026-10-16 22:58 | PPD performance · GPU auto | mix · native | **2531** | vertex 5910 texture 3062 shading 2398 effect2d 770 desktop 1333 cube 1717  | 72.3 / 74.4 | 61.8 / 64.0 | 29.5 | 1635 | 2542 |
| 2026-10-16 22:59 | PPD performance · GPU high | mix · native | **2499** | vertex 5748 texture 3035 shading 2392 effect2d 780 desktop 1331 cube 1709  | 71.7 / 72.9 | 61.9 / 65.0 | 29.0 | 1571 | 2526 |
| 2026-10-16 23:00 | normal (balanced · GPU auto) | gpu · native | **2836** | vertex 6769 texture 3291 shading 2563 effect2d 1119 desktop 1464 cube 1813  | 61.0 / 63.9 | 60.6 / 64.0 | 24.0 | 2705 | 1187 |
| 2026-10-16 23:01 | PPD performance · GPU auto | gpu · native | **2864** | vertex 6826 texture 3260 shading 2579 effect2d 1220 desktop 1481 cube 1819  | 66.8 / 70.5 | 65.9 / 72.0 | 30.1 | 2854 | 1468 |
| 2026-10-16 23:02 | PPD performance · GPU high | gpu · native | **2886** | vertex 6917 texture 3325 shading 2593 effect2d 1185 desktop 1481 cube 1820  | 65.1 / 68.2 | 64.6 / 69.0 | 29.0 | 2832 | 1345 |
| 2026-10-16 23:03 | PPD performance · turbo off | mix · native | **2756** | vertex 6565 texture 3195 shading 2504 effect2d 1089 desktop 1424 cube 1760  | 66.4 / 69.1 | 63.0 / 68.0 | 31.8 | 2600 | 1591 |
| 2026-10-16 23:04 | PPD performance · scx_lavd gaming | mix · native | **2682** | vertex 6498 texture 3169 shading 2474 effect2d 870 desktop 1378 cube 1706  | 70.6 / 76.8 | 61.2 / 65.0 | 29.0 | 2206 | 2386 |
| 2026-10-16 23:05 | PPD performance · scx_lavd gaming (2) | mix · native | **2742** | vertex 6592 texture 3178 shading 2497 effect2d 1063 desktop 1381 cube 1742  | 69.0 / 73.8 | 61.2 / 65.0 | 29.0 | 2320 | 2178 |
| 2026-10-16 23:06 | PPD performance · sin scx (2) | mix · native | **2471** | vertex 5699 texture 2985 shading 2373 effect2d 762 desktop 1311 cube 1699  | 70.3 / 72.0 | 59.8 / 63.0 | 29.0 | 1610 | 2566 |
| 2026-10-16 23:28 | normal (balanced · GPU auto) | mix · gamescope | **8435** | texture 10859 shading 8681 effect2d 4292 desktop 4054 cube 9281  | 71.0 / 75.2 | 58.0 / 64.0 | 34.5 | 1686 | 3447 |
| 2026-10-16 23:29 | 鬼 Oni (performance · scx_lavd gaming) | mix · native | **4056** | vertex 9587 texture 4729 shading 3707 effect2d 1636 desktop 2086 cube 2596  | 82.3 / 89.4 | 67.0 / 79.0 | 42.2 | 2526 | 2430 |
| 2026-10-16 23:30 | 鬼 Oni (performance · scx_lavd gaming) | gpu · native | **4151** | vertex 9804 texture 4772 shading 3720 effect2d 1847 desktop 2140 cube 2625  | 72.3 / 81.2 | 71.8 / 84.0 | 38.7 | 2929 | 2358 |
| 2026-10-16 23:31 | 鬼 Oni + gamescope 1440×900 → FSR | mix · gamescope | **8968** | texture 11136 shading 8765 effect2d 5745 desktop 4119 cube 9427  | 77.7 / 81.2 | 62.7 / 69.0 | 35.8 | 2099 | 3327 |
| 2026-10-16 23:32 | normal (balanced · GPU auto) · batería sin cargar | mix · native | **3549** | vertex 8597 texture 4254 shading 3149 effect2d 1011 desktop 1745 cube 2539  | 63.2 / 67.9 | 53.9 / 58.0 | 25.0 | 1535 | 2323 |
| 2026-10-16 23:33 | normal (balanced · GPU auto) · batería sin cargar | gpu · native | **4061** | vertex 9696 texture 4712 shading 3692 effect2d 1566 desktop 2102 cube 2600  | 59.7 / 63.8 | 59.4 / 64.0 | 23.7 | 2738 | 1195 |
| 2026-10-16 23:35 | 鬼 Oni sin scx (A/B 1) | mix · native | **3885** | vertex 9169 texture 4652 shading 3639 effect2d 1247 desktop 2027 cube 2580  | 72.4 / 79.1 | 60.0 / 67.0 | 35.5 | 1869 | 2587 |
| 2026-10-16 23:35 | 鬼 Oni con scx_lavd (A/B 1) | mix · native | **4001** | vertex 9345 texture 4730 shading 3679 effect2d 1576 desktop 2080 cube 2601  | 69.3 / 74.2 | 61.6 / 67.0 | 30.5 | 2399 | 2058 |
| 2026-10-16 23:36 | 鬼 Oni sin scx (A/B 2) | mix · native | **3789** | vertex 8852 texture 4577 shading 3618 effect2d 1114 desktop 1993 cube 2584  | 68.9 / 73.4 | 58.5 / 62.0 | 29.0 | 1642 | 2471 |
| 2026-10-16 23:37 | 鬼 Oni con scx_lavd (A/B 2) | mix · native | **4031** | vertex 9587 texture 4715 shading 3699 effect2d 1504 desktop 2085 cube 2600  | 66.7 / 71.6 | 60.7 / 66.0 | 29.0 | 2470 | 1825 |
