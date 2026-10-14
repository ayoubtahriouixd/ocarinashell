# Fase 10 · 忍 Shinobi (ahorro extremo) y afinado de energía

**Objetivo**: que al activar Shinobi el portátil dure lo máximo posible fuera de casa, de forma totalmente reversible,
y que el uso normal ya sea eficiente. Con números medidos, no con fe.
**Lee antes**: `docs/01-ARQUITECTURA.md` §10–11, `docs/04-RENDIMIENTO.md` §Energía, mockup 06.

## Tareas
1. **Snapshot**.
2. **Helper root `ocarina-powerctl`** (`system/ocarina-powerctl`, bash estricto, instalado en
   `/usr/local/libexec/ocarina-powerctl`) + acción polkit `org.ocarinashell.powerctl`
   (`/usr/share/polkit-1/actions/`, `allow_active=yes`, `annotate key="org.freedesktop.policykit.exec.path"`).
   Operaciones en lista blanca, validando cada argumento: `boost on|off` · `epp <valor de la lista disponible>` ·
   `gpu auto|low` · `charge <inicio 40-95> <fin 50-100>` · `wifi-ps on|off` (o vía NetworkManager sin root) ·
   `status` (JSON). Rechaza todo lo demás. Unidad `ocarina-charge.service` (oneshot al arrancar) que reaplica el
   límite de carga guardado.
3. **Servicio `Modes` (Shinobi)**: máquina de estados y snapshot del estado previo (ARQUITECTURA §10). Pasos, cada uno
   reversible e idempotente:
   shell → `Motion.enabled=false`, tema `shinobi`, fondo negro, blur/transparencias off, isla mínima con sello 忍,
   monitores de pico/tiempo/Mihari off, reloj por minutos, logo estático, sonidos off ·
   niri → incluir `shinobi.kdl` (`animations { off }`, sin sombras ni blur) ·
   pantalla → 60 Hz a través de `Displays` (reescribe `outputs.kdl`; un `niri msg output` suelto se perdería en la
   siguiente recarga de niri), tope de brillo (35 % por defecto, en la interna; en monitores
   externos solo con `brightnessCapExternal`, pensado para los USB-C que se alimentan del portátil), luz de teclado off ·
   energía → PPD `power-saver`, turbo off (helper), `gpu low` solo si las medidas lo justifican ·
   radios → Bluetooth off (salvo dispositivo de audio conectado, configurable), Wi-Fi powersave ·
   apps → efectos de Ghostty y Neovim off (fichero `mode`), pausa de servicios de usuario configurados (Snake y la VM
   de Fune se enganchan aquí en sus fases).
   Entrada: el sello 忍 se estampa en la isla y el tema funde a negro (única animación permitida); toast como el
   mockup 06 con autonomía estimada (potencia media de los últimos 60 s).
   Disparadores: manual (Mod+Alt+S, mosaico, CLI), batería ≤ umbral (preguntar o automático según Ajustes), salida
   automática al conectar CA (configurable).
4. **Medidas** con `scripts/bench-power.sh` (04-RENDIMIENTO §Energía): pide a Ayoub desenchufar; escenarios A–E;
   resultados en `docs/ENERGIA.md` con autonomía estimada. Si alguna medida de Shinobi no aporta (p. ej. `gpu low`),
   quítala y documenta por qué.
5. **Afinado global** (no Shinobi): revisa PSR/Panel Replay de amdgpu, ASPM, autosuspend USB (excluyendo HID),
   `snd_hda_intel` power_save, Wi-Fi powersave en batería, suspensión s2idle y residencia s0ix (`amd_pmc`), consumo
   en suspensión (1 h). Aplica solo lo medido y seguro, con ficheros en `system/` instalados por install-system.sh.
6. **Límite de carga** al 80 % (si Ayoub dijo sí): `charge_control_end_threshold`, comprobado tras reiniciar.

## Criterios de aceptación
- [ ] Shinobi on/off < 1 s; tras salir, `diff` del estado (brillo, Hz, perfil, BT, tema…) idéntico al previo.
- [ ] Captura en Shinobi ≈ mockup 06. Nada roto en Shinobi: bloqueo, notificaciones críticas, teclas multimedia.
- [ ] `docs/ENERGIA.md` con tabla de escenarios y ganancia real de Shinobi.
- [ ] Helper rechaza argumentos fuera de lista (prueba 5 casos maliciosos).

## Al terminar
PROGRESS.md, commit; explica a Ayoub en 3 líneas cuánto gana con Shinobi y cuándo se activa solo.
