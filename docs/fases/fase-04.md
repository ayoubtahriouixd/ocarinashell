# Fase 04 · Engawa (centro de control), OSD, Fumi (notificaciones) y Koyomi (calendario)

**Objetivo**: el panel de control del mockup 02, notificaciones propias impecables (servidor incluido) y el calendario
vivo con las 72 microestaciones.
**Lee antes**: mockups 01 (toast) y 02, `docs/02-DISENO.md` §5–7, documentación de Quickshell: NotificationServer/
Notification, Networking, Bluetooth, PowerProfiles, ColorQuantizer, PopupWindow.

## Tareas
1. **Snapshot**.
2. **Engawa** (`modules/engawa/`): panel de capa anclado arriba-derecha (420 px), cierre con Esc/clic fuera, foco de
   teclado (`WlrKeyboardFocus.OnDemand`), navegación completa con teclado. Cabecera, mosaicos (Wi-Fi, Bluetooth, No
   molestar, Luz nocturna, Despierto/IdleInhibitor, Micrófono, Grabar, Captura), tarjetas de modo 忍 Shinobi y 鬼 Oni
   (de momento llaman a los servicios stub), sliders (volumen con selector de salida/entrada; **brillo: uno por
   pantalla** —mockup 02—, que aparecen y desaparecen en caliente al conectar o quitar monitores, en el orden físico de
   niri, con el nombre a la derecha y el texto invertido bajo el relleno; Mayús + arrastrar mueve todos; teclado si
   existe), segmentado de perfiles, tarjeta multimedia (Mpris + ColorQuantizer), pie de batería (UPower + `power_now`
   sondeado cada 5 s SOLO con el panel visible). Páginas de detalle con transición lateral: Wi-Fi (escaneo mientras
   está abierta, conectar con contraseña, olvidar, red oculta), Bluetooth (descubrir, emparejar, conectar, batería de
   los dispositivos), Audio (dispositivos y volumen por aplicación con PipeWire).
3. **Luz nocturna**: `ocarina-nightlight.service` con wlsunset; modos auto (amanecer/atardecer calculados con la
   ubicación de Ajustes), programado y manual; temperatura ajustable.
4. **Fumi**: `NotificationServer` (actions, body markup, images, inline reply, persistence), toasts del mockup 01
   (pila de 3 + «+N», arrastrar para descartar, pausa del temporizador al pasar el ratón, barra de progreso, hint
   `value` para barras de progreso de apps), críticas persistentes con sonido `critical`, sonido `notify`, aviso en
   la isla («peek») si hay pantalla completa o No molestar parcial, agrupado por app, historial persistente,
   centro de notificaciones (Mod+Shift+N) con «borrar todo», No molestar con horario. Privacidad: contenido oculto
   en bloqueo (fase 6 lo usa). Integra avisos de Ghostty (`notify-on-command-finish`). Las notificaciones de 守 Mamori
   (fase 16) se agrupan en una sola tarjeta discreta.
5. **Koyomi** (clic en la isla): mes con cabecera tradicional (`神無月 Kannazuki · octubre 2026`), días de la semana
   en kanji 日月火水木金土 (domingo en rojo), hoy como hanko, tarjeta del 七十二候 actual (kanji grande, lectura,
   traducción, días restantes) y del 節気; amanecer/atardecer y fase lunar (cálculo local); tiempo (Open-Meteo) con
   kanji 晴/曇/雨/雪/雷/霧 y previsión de 3 días.
6. **OSD**: completa los tipos (micro silenciado, perfil, teclado, Wi-Fi/avión con la tecla Fn, cafeína).
7. **集中 Shūchū · modo foco** (`docs/07-IDEAS.md`; `ocarina focus [25|50|<min>|stop]` y menú contextual de la isla; la
   acción de Torii llega en la fase 5): estado `Focus` de Shima con anillo fino de progreso y minutos restantes
   (precisión de minuto, tic de `Time`), No molestar mientras dura (se restaura al acabar), nota de ocarina + aviso
   «休憩 · descanso 5 min» con «Otro bloque»; los bloques del día salen como sellos ●●○ en Koyomi. Ajuste `focus
   {minutes, breakMinutes, dnd}`.
8. **Gestos táctiles** (la pantalla es táctil): arrastrar hacia abajo desde el clúster de estado abre Engawa siguiendo
   el dedo (soltar pasado el 40 % lo abre; si no, vuelve con muelle); desde la isla, Koyomi; desde la marca, Torii;
   deslizar la isla en horizontal con música cambia de canción. Solo táctil (`DragHandler { acceptedDevices:
   PointerDevice.TouchScreen }`): ratón y touchpad se comportan igual que antes.
9. **Detalles**: en la página Wi-Fi, «Compartir» muestra un QR de la red actual (`qrencode`; la contraseña la da
   NetworkManager y puede pedir polkit: hasta que exista el agente propio de la fase 6, si NM pide autorización el
   botón dice «disponible tras la fase 6»); mosaico **VPN** solo si hay conexiones VPN/WireGuard en NetworkManager
   (activar, elegir, icono en el clúster); en Koyomi, relojes del mundo (por defecto 東京 Tokio, editable).

## Criterios de aceptación
- [ ] Captura del panel abierto ≈ mockup 02 (visual-qa sin diferencias altas).
- [ ] Batería de pruebas: `notify-send` con acciones, imagen, urgencia crítica, `-h int:value:60`, reemplazo por id,
      respuesta inline (si hay app que la use), 20 notificaciones seguidas (sin tirones), DND.
- [ ] Wi-Fi: conectar a una red con contraseña y olvidarla; Bluetooth: conectar los cascos de Ayoub.
- [ ] Shūchū de 1 min (prueba): anillo y minutos en la isla, No molestar activo y restaurado, aviso al terminar.
      Gestos táctiles probados por Ayoub con el dedo (el ratón no cambia); QR del Wi-Fi leído con su móvil.
- [ ] Sliders = valores reales (`wpctl get-volume`, `brightnessctl g`, `ddcutil --bus N getvcp 10`). Cero sondeos con el
      panel cerrado.
- [ ] Con un monitor externo: conectar con Engawa abierto → su slider entra animado sin cerrar el panel; moverlo cambia
      SOLO ese monitor (y la interna no se mueve); usar los botones del propio monitor y reabrir Engawa → valor real;
      desconectar → la fila se va. Captura con dos pantallas ≈ mockup 02.

## Al terminar
PROGRESS.md, commit; pide a Ayoub que pruebe notificaciones de sus apps reales (Telegram, Chrome, Teams).
