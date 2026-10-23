# 滑 Nameraka — vídeo fluido: medidas

> Medido en la fase 11 (parte B), 2026-10-17. ThinkPad P14s Gen 6 AMD · Radeon 860M · panel 2880×1800 a 120 Hz · lsfg-vk 2.0.0 (FP16) ·
> Lossless Scaling rama `lsfg-vk` · niri 26.04. Herramientas: `scripts/bench-fluido.sh` (cadencia real: `wl_surface.commit`
> del presentador vía WAYLAND_DEBUG), `lsfg-vk-cli benchmark`, `ocarina nameraka calibrate`.

## Prueba de concepto de la captura (niri 26.04)
- `org.gnome.Mutter.ScreenCast` versión 4: `CreateSession` → `RecordWindow({window-id: t, cursor-mode: u 0})` → `Start` →
  `Stream.PipeWireStreamAdded(nodo)`. Sin diálogo. Aparece en `niri msg casts`.
- **niri no cierra la sesión si el cliente muere** (no rastrea el dueño): queda «inactive» hasta un `Stop`. El daemon
  guarda la ruta de su sesión y la cierra al arrancar si quedó huérfana.
- Solo **DMA-BUF** (sin memoria compartida): `BGRx`/`BGRA` con 9 modificadores AMD + lineal; niri fija uno (aquí
  `0x0200000008401b04`). Tamaño físico de la ventana: a pantalla completa **2881×1801** (1646×1029 lógicos × 1,75: el medio
  píxel de §19) → se recorta a 2880×1800 al copiar. Sin `SPA_META_VideoDamage` ni pts: la base se mide por llegada.
- Cadencia que entrega niri: **un fotograma por fotograma nuevo** del contenido (24 → 24,0 · 30 → 30,0 · 60 → 60,0 con
  mpv; Chrome 30 → 30,0), con el refresco como tope (una terminal que se repinta sin parar llega a 120).
- WirePlumber **no enlaza** un cliente con el nodo de niri (`Stream/Output/Video`, `object.register=false`: «target not
  found»): el presentador crea el enlace él mismo con `link-factory`.

## Latencias (criterios de §19)
| Medida | Valor | Criterio |
|---|---|---|
| `start` → primer fotograma generado en pantalla (daemon ya activo por socket) | **≈ 90 ms** (activo a 47 ms + 41–51 ms hasta el primer present) | < 300 ms |
| `stop` → la app original | 46 ms (la capa desaparece al destruir la superficie, antes de cerrar la captura) | ≤ 2 fotogramas base |
| pausa ⇄ activo (vista general, Alt+Tab, bloqueo, otro espacio) | decisión 5–26 ms · visible otra vez en **29–70 ms** | < 150 ms |
| Vigilante: presentador congelado (`kill -STOP`) → capa fuera | **680 ms** (latido cada 250 ms, corte a 750 ms) | ≤ 1 s |
| Copia 1:1 DMA-BUF → swapchain (sin lsfg-vk) | 0,33 ms/fotograma · CPU del ayudante 1,67 % | — |
| Patrón 1 px a 2880×1800 | franjas 0/255 conservadas (deriva ≤ 3/255 en el borde por el medio píxel lógico) | sin reescalar |

## lsfg-vk: rendimiento (benchmark a 2880×1800, Radeon 860M, `ocarina nameraka calibrate`)
| ×m | flujo 1,0 | 0,75 | 0,5 | 0,75 rend. | 0,5 rend. | 0,35 rend. |
|---|---|---|---|---|---|---|
| ×2 | 66,2 | 94,7 | 135,7 | 125,2 | 156,2 | 181,7 |
| ×3 | 40,4 | 58,1 | 85,0 | 80,2 | 97,2 | 117,5 |
| ×4 | 29,2 | 41,5 | 61,6 | 58,3 | 71,2 | 86,6 |
| ×5 | 22,8 | 32,5 | 47,8 | 45,5 | 55,2 | 67,6 |

(fps base máximos sostenidos). Con el margen 1,3× de §19: 30 × 4 → **flujo 0,75**; 24 × 5 → flujo 0,75; 60 × 2 → flujo 0,75.
A flujo 1,0, ×4 no llega a 30 fps base en este panel. 1080p da el triple de margen (×4 flujo 1,0 → 78 fps base).

**Recarga en caliente** (renombrado atómico de `lsfg.toml`): ×4 → 119,6 · ×2 → 60,0 · ×1 (paso directo) → 30,0
commits/s, con un hueco máximo de un fotograma base en el cambio.

## Hallazgo: la capa no puede ser opaca
Con una superficie opaca encima, niri considera la ventana de debajo oculta y le manda las frame callbacks a ~1 Hz:
**Chrome dejaba de pintar** (4 fps capturados, p99 948 ms; mpv no depende de ellas). El presentador usa una swapchain con
alfa (`PRE_MULTIPLIED`) sin región opaca: Chrome vuelve a 30 → 120 fps. Coste: niri compone también la ventana de debajo.

## Motor IA (puerta de §19)
No pasa: el único RIFE para ncnn empaquetado (AUR `rife-ncnn-vulkan` 20221029) no compila con el ncnn 2026 de los repos
sin parches y, parcheado, se cae al compilar sus sombreadores. Medirlo exigiría portar RIFE a la API actual de ncnn: hoy
queda fuera (D-061). Referencia: lsfg-vk genera ×2 a 2880×1800 en 15,1 ms (flujo 1,0). La interfaz muestra «IA» deshabilitada.

## Audio sincronizado
`pw-loopback --delay` crea un sumidero virtual que **declara latencia 0** (los reproductores no la compensan) y los flujos
de la app (y de sus procesos hijos) se mueven con el metadato `target.object`; al apagar se **borra** el metadato y
WirePlumber los devuelve a la salida por defecto **sin guardar destino** (comprobado en `stream-properties`). Retardo
medido con mpv a 30 fps: 62 ms (= 33,3 + 16,2 de generación + 12,5 de 1,5 refrescos). **Apagado por defecto**: se
enciende en Ajustes › 滑 Nameraka («Sincronizar audio») y `scripts/fluido-av-test.sh` (destello + pitido) te dice si
compensa en tu equipo.

## Cadencia (04-RENDIMIENTO: < 0,5 % de fotogramas tarde en 5 min; CPU del ayudante < 3 %)

| Fecha | Reproductor | Vídeo | Modo | Base · m · flujo | Salida fps | Intervalo p50 / p99 ms | Tarde | CPU ayudante | GPU | Duración |
|---|---|---|---|---|---|---|---|---|---|---|
| 2026-10-17 01:17 | mpv | 1080p30 | custom | 30 ×4 · flujo 0.75 | **120.0** | 8.32 / 8.76 | **0.00 %** | 2.00 % | 80 % | 30 s |
| 2026-10-17 01:20 | chrome | 1080p30 | custom | 30 ×4 · flujo 0.75 | **120.0** | 8.31 / 8.80 | **0.00 %** | 3.00 % | 82 % | 30 s |
