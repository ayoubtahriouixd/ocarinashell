# Fase 07 · Settei (ajustes) y Kabegami (explorador de fondos)

**Objetivo**: una app de ajustes completa, bonita en claro y oscuro (mockup 07 en Kōhaku) donde todo se aplica al
instante, y un explorador de fondos rápido.
**Lee antes**: mockups 07, 10 y 12, `docs/01-ARQUITECTURA.md` §8 (esquema de ajustes), `docs/02-DISENO.md` §5,
`docs/07-IDEAS.md`.

## Tareas
1. **Snapshot**.
2. **Ventana**: `FloatingWindow` (título «Ajustes — OcarinaShell», regla de niri: flotante centrada 1240×924),
   lateral con wordmark, búsqueda (`/`), navegación con glifo kanji; enlaces profundos (`ocarina settings energia`);
   una página por sección, con «Restablecer sección»; importar/exportar `settings.json`; teclado completo.
3. **Páginas** (cada control enlazado a `Settings`; lo que afecta a niri escribe includes generados y valida). Orden,
   glifo del lateral y kanji de cabecera salen de `assets/data/kanji-ui.json` → `settingsPages` (fuente única; los
   mockups 07, 10 y 12 se generan de ahí):
   - 彩 **Apariencia** (cabecera 外観): tema (tarjetas con miniatura real), acento (赤 朱 金 若竹 浅葱 瑠璃 紫 紅梅 + «Desde el fondo»),
     transparencia/blur, velocidad de animaciones (0 = sin animaciones), radio, kanji decorativos, esquinas de
     pantalla, tipografías, escala de fuente, movimiento reducido.
   - 帯 **Barra e isla**: posición, estilo (flotante/pegada/mínima con autoocultado), módulos y orden (arrastrar),
     reloj 24 h/segundos, mostrar tiempo/estación, comportamientos de la isla.
   - 画 **Pantalla**: luz nocturna y táctil; escala, frecuencia y VRR se ajustan por pantalla dentro de Haichi (abajo),
     con vista previa y «mantener / revertir en 15 s».
     **Brillo por pantalla**: una tarjeta por monitor detectado (nombre editable, tipo Interna/DDC/CI/Software, slider,
     mínimo), botón «Detectar de nuevo», a qué pantalla van las teclas de brillo (la del foco · solo la interna ·
     todas), DDC/CI on/off y atenuación por software on/off.
     **配置 Haichi** (mockup 12): lienzo con las pantallas a escala lógica (arrastrar con imán a los bordes, numeradas
     con los numerales formales 壱 弐 参; «Identificar» muestra el suyo gigante 2 s en cada pantalla); por pantalla:
     resolución, frecuencia, escala, rotación, VRR, activa y **principal** (barra completa, isla y avisos). Modo:
     Extender · Duplicar · Solo monitor · Solo portátil. **Perfiles** por conjunto de monitores (huella =
     fabricante|modelo|serie ordenados) que se aplican solos al conectar; «Guardar perfil» con nombre y kanji (家 Casa,
     職 Oficina…). Todo va a `~/.local/state/ocarinashell/niri/outputs.kdl` (include `optional=true`, validado con
     `niri validate`, atómico) con «mantener / revertir en 15 s». **Aviso al conectar** un monitor sin perfil:
     «Monitor 27″ conectado · Extender · Solo este · Duplicar · Organizar». **Tapa cerrada** con monitor: la interna
     se apaga y todo pasa al monitor; al abrir, vuelve (comprueba si tu versión de niri ya lo hace; si no,
     `switch-events { lid-close … }`). **発表 Happyō** (Duplicar): `wl-mirror` de la principal a pantalla completa en la
     otra + No molestar + Despierto + avisos sin contenido; se sale desde la isla o con Esc en la copia. Opcionales,
     apagados: **tema según la hora** (pareja día/noche con el amanecer/atardecer de Koyomi) y **brillo según la
     hora** (curva día/noche por pantalla; si lo mueves a mano se pausa hasta el siguiente tramo; en DDC, como mucho
     una escritura por minuto); ambos se pausan en Shinobi/Oni y al salir aplican el tramo actual. **保護 Hogo**:
     desplazar píxeles, atenuar lo estático y bloqueo a la deriva.
   - 音 **Sonido**: dispositivos, volumen por app, sonidos de interfaz y su volumen.
   - 網 **Red y Bluetooth**: reutiliza las páginas de Engawa a pantalla completa.
   - 電 **Energía y batería**: perfiles, límite de carga (helper de la fase 10; aquí UI + «pendiente» si no está),
     umbrales de batería baja, gráfica de consumo de las últimas horas (UPower history si existe), auto-Shinobi.
   - 忍 **Shinobi** y 鬼 **Oni**: qué apaga/enciende cada modo (checkboxes), disparadores, estimaciones (Oni llega en la
     fase 11: deja la página preparada).
   - 鍵 **Bloqueo e inactividad**: tiempos CA/batería, huella, privacidad, multimedia en bloqueo.
   - 入 **Teclado, ratón y táctil**: distribuciones y cambio, repetición, touchpad, TrackPoint, foco sigue al ratón,
     cursor sigue al foco.
   - 文 **Notificaciones**: No molestar y horario, silenciar por app, sonidos, tiempo en pantalla, privacidad.
   - 窓 **Ventanas y reglas**: huecos, anillo de foco, ancho por defecto, animaciones de niri, reglas de Mado.
   - 船 **Windows** (fase 12), 蛇 **Snake** (fase 15) y 守 **Mantenimiento** (fase 16, mockup 10): deja el hueco en la
     navegación.
   - 技 **Atajos**: lista legible (misma fuente que la chuleta) + «abrir en Neovim».
   - 壁 **Fondos** → Kabegami. · 情 **Acerca de**: logo hero animado (`OcarinaLogo` grande + wordmark), versiones
     (OcarinaShell, Quickshell, Qt, niri, kernel), hardware, diagnóstico (módulos no disponibles y por qué), créditos y
     licencias (fuentes OFL/Apache, código propio).
4. **Kabegami** (Mod+Shift+W): rejilla de `~/Imágenes/Fondos` + incluidos, miniaturas 480 px en caché (vips, por
   hash de ruta+mtime, en segundo plano), vista previa grande con flechas, aplicar con la transición de tinta,
   favoritos, «tema desde este fondo» (matugen), rotación opcional (solo con CA). Pestaña opcional **Explorar**:
   Wallhaven (API pública, solo SFW, búsqueda, descarga a `~/Imágenes/Fondos/wallhaven/`) — pregunta a Ayoub.

## Criterios de aceptación
- [ ] Captura en Kōhaku ≈ mockup 07; también correcta en Kurenai.
- [ ] Cada ajuste persiste tras reiniciar la shell y se aplica en vivo (lista de comprobación en evidencias).
- [ ] Enlaces profundos y búsqueda funcionan. Kabegami: 200 imágenes indexadas < 10 s la primera vez, instantáneo después.
- [ ] Página Pantalla ≈ mockup 12. Con el monitor de Ayoub: guardar perfil, desconectar y reconectar → se aplica solo;
      «revertir en 15 s» deshace un cambio de escala; Duplicar y salir sin dejar `wl-mirror` vivo; tapa cerrada probada.

## Al terminar
PROGRESS.md, commit; pide a Ayoub que recorra Ajustes 5 minutos y te diga qué echa en falta.
