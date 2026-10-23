# Energía — medidas reales

ThinkPad P14s Gen 6 AMD (Ryzen AI 7 PRO 350, Radeon 860M, OLED 2880×1800 120 Hz), CachyOS, kernel 7.2, niri 26.04.
Protocolo: `docs/04-RENDIMIENTO.md` §Energía. Filas escritas por `scripts/bench-power.sh` (vía `scripts/bench-energia.sh`):
desenchufado, escritorio vacío (fondo + barra), Wi-Fi conectado, Bluetooth apagado, 60 s de asentado y 120 s de medida.
Tema del uso normal: Sumi (el de Ayoub; oscuro como Kurenai).

| Fecha | Escenario | Media (W) | Mediana | p95 | Brillo | Hz | Autonomía estimada (batería llena) |
|---|---|---|---|---|---|---|---|
| 2026-10-16 22:03 | A · normal 120 Hz, brillo 50 % | 7.72 | 7.57 | 8.39 | 50% | 120 | 6.4 h |
| 2026-10-16 22:06 | F · normal 120 Hz + Ethernet en ahorro (runtime PM) | 7.57 | 7.54 | 7.91 | 50% | 120 | 6.5 h |
| 2026-10-16 22:10 | B · normal 60 Hz | 7.05 | 7.03 | 7.15 | 50% | 60 | 7.0 h |
| 2026-10-16 22:13 | C · normal 120 Hz + VRR siempre (vigila parpadeo) | 6.39 | 6.55 | 7.26 | 50% | 120 | 7.7 h |
| 2026-10-16 22:16 | D · 忍 Shinobi (brillo con tope 50%) | 5.35 | 5.30 | 5.78 | 50% | 60 | 9.3 h |
| 2026-10-16 22:19 | G · 忍 Shinobi + GPU al mínimo | 5.14 | 5.09 | 5.58 | 50% | 60 | 9.6 h |
| 2026-10-16 22:22 | E · 忍 Shinobi + brillo 20 % | 4.96 | 4.93 | 5.34 | 20% | 60 | 10.0 h |
| 2026-10-16 22:30 | D · 忍 Shinobi (brillo con tope 35%) | 3.90 | 3.87 | 4.18 | 35% | 60 | 12.7 h |
| 2026-10-16 22:33 | H · 忍 Shinobi + VRR (60 Hz máx.) | 4.00 | 4.00 | 4.05 | 35% | 60 | 12.4 h |

## Lectura (2026-10-16)

Dos tandas: A–G seguidas y, después, D y H repetidas. **Comparar solo dentro de una misma tanda**: la primera D (5,3 W)
tuvo el brillo al 50 % porque el tope no se aplicaba (el script cambió el brillo por fuera de la shell, ya corregido) y
probablemente música y Chrome de fondo; la segunda D, con el tope al 35 %, dio 3,9 W.

| Qué | Efecto medido | Decisión |
|---|---|---|
| **忍 Shinobi completo** (D frente a A, misma tanda) | 7,57 → 5,30 W de mediana (**−30 %**, de 6,4 a 9,3 h) con el brillo aún al 50 %; con el tope al 35 % y el sistema en calma, **3,9 W ≈ 12,7 h** | Es el modo |
| 120 → 60 Hz (B frente a A) | −0,5 W | En Shinobi (`refresh60`) |
| VRR siempre a 120 Hz (C frente a A) | −1,0 W (el panel cae a 30 Hz con la imagen quieta); Ayoub no vio parpadeo en Shinobi | Interruptor «VRR» por pantalla en Ajustes → Pantalla (perfil de Haichi), a tu gusto |
| VRR en Shinobi (H frente a D, 2.ª tanda) | +0,1 W (ruido): a 60 Hz no hay margen | No se usa en Shinobi |
| GPU al mínimo (G frente a D) | −0,21 W de mediana (−4 %) | Activado por defecto en Shinobi (`gpuLow`) |
| Brillo 50 → 20 % en Shinobi (E frente a G) | −0,16 W: en OLED el negro no gasta | El tope (35 %) basta |
| Ethernet runtime PM (F frente a A) | −0,03 W (ruido) | No se aplica |

Autonomía estimada = `energy_full` (49,5 Wh, 94 % del diseño) / potencia media, en reposo. Con uso real (navegador,
vídeo, compilar) baja; la ganancia relativa de Shinobi se mantiene porque sus mayores palancas (60 Hz, sin turbo, tema
negro, sin animaciones) actúan sobre todo lo que se dibuja.

## Diagnóstico del sistema (2026-10-16, antes de medir)

| Punto | Estado | Decisión |
|---|---|---|
| PSR / Panel Replay (amdgpu, eDP-1) | El panel anuncia PSR v1, pero el driver no lo activa (`PSR support 0, DC PSR ver 0`); Panel Replay: el panel no lo soporta | No se fuerza: haría falta `amdgpu.dcfeaturemask` en la línea del kernel (regla 10) y en OLED con VRR hay riesgo de parpadeo. Se revisará si un kernel futuro lo activa solo |
| ASPM | L1.1/L1.2 activos en NVMe y Wi-Fi (MT7925); política `default` del firmware | Correcto; no se toca |
| Ethernet Realtek RTL8111 (sin cable) | Runtime PM `on`, ASPM desactivado por el driver r8169 | Escenario F: sin ganancia medible (mediana 7,57 → 7,54 W): no se aplica |
| Audio (`snd_hda_intel` power_save) | CachyOS (`cachyos-settings`, `20-audio-pm.rules`) ya pone 10 s en batería y 0 con cargador | Correcto; no se toca |
| Wi-Fi power save | `on` por defecto (mt7925e) | Correcto; Shinobi solo lo asegura |
| Autosuspend USB | `auto` en cámara, hub, Bluetooth; `on` en el receptor 2,4 GHz (HID) | Correcto (la entrada nunca se suspende) |
| Turbo | power-profiles-daemon 0.30 ya lo quita en «ahorro» (`policy*/boost`) | Shinobi usa el perfil; el ayudante solo actúa si el turbo sigue activo (D-059) |
| Suspensión | `s2idle` (único modo), `amd_pmc` cargado | Sin medir aún: `scripts/bench-suspend.sh` (≥ 1 h desenchufado) da el consumo en s2idle y la residencia s0ix |
