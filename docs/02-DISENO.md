# 02 · Sistema de diseño

Unidades en **px lógicos** (escala 1,75 → 1 px lógico = 1,75 px físicos). Los mockups (`assets/mockups/*.png`,
2880×1800) se diseñaron así: lo que mide 40 px en `mock.css` mide 40 en QML. Valores exactos en
`assets/mockups/src/mock.css` y `tools/mockups.py`.

## 1. Color — tokens (`Theme.colors.*`, cargados de `assets/data/themes/<id>.json`)
| Token | Kurenai (oscuro) | Kōhaku (claro) | Uso |
|---|---|---|---|
| `bg` | `#0b0a0c` | `#f4f1ec` | fondo base / bloqueo |
| `surface0` | `#141216` | `#ffffff` | barra, paneles |
| `surface1` | `#1b181d` | `#f8f5f0` | tarjetas, mosaicos |
| `surface2` | `#241f26` | `#efeae3` | hover, fila seleccionada, pistas de slider |
| `surface3` | `#2e2830` | `#e6e0d7` | controles en reposo, icono de mosaico apagado |
| `outline` / `outlineStrong` | `#2c262e` / `#463e48` | `#e3ddd4` / `#cdc5ba` | bordes 1 px, separadores |
| `text` / `textMuted` / `textDim` | `#f4efe6` / `#aaa39b` / `#6f6862` | `#18171c` / `#5f5953` / `#9d968f` | jerarquía de texto |
| `accent` / `accentHover` | `#e60033` / `#ff1f4f` | `#e60033` / `#c8002d` | 赤 marca: activo, foco, primario, hanko |
| `accentSoft` | `#e6003329` | `#e600331f` | fondo de estado activo |
| `accent2` | `#e6b422` (金) | `#a8770a` | estación 七十二候, detalles especiales |
| `success` · `warning` · `error` · `info` | `#68be8d` · `#f8b500` · `#ff4d6a` · `#a0d8ef` | `#2c7a52` · `#946300` · `#c4002b` · `#1f6f99` | estados |
| `onAccent` | `#ffffff` | `#ffffff` | texto/icono sobre `accent` |
**Vidrio**: superficie `surface0` con alfa 0,72 + blur del compositor (`BackgroundEffect.blurRegion`, «xray»
de niri) + borde `rgba(255,255,255,.07)` + brillo interior superior 1 px `rgba(255,255,255,.045)`.
Sin blur disponible (o Shinobi) → alfa 0,94 automáticamente. Los temas cambian con `ColorAnimation` (Motion.slow).
Regla: el rojo nunca supera ~8 % del área visible salvo en momentos deliberados (Dengen seleccionado, Shinobi, Oni).
Contraste mínimo AA (4,5:1) para texto normal en todos los temas: `tools/build_data.py` lo verifica al generar los
JSON (texto, texto atenuado, acento ≥ 3:1, paleta ANSI ≥ 3:1); vuelve a comprobarlo en pantalla en la fase 17.
Color secundario de sistema: **浅葱 asagi `#00a3af`** solo para lo que viene «de fuera» (ventanas de Windows de Fune).

## 2. Tipografía (`Theme.font.*`)
| Rol | Familia | Uso |
|---|---|---|
| `ui` | **Geist** (variable) | todo el texto latino de la interfaz |
| `jp` | **Zen Kaku Gothic New** | texto japonés funcional (saludos, subtítulos) |
| `display` | **Shippori Mincho B1** | kanji decorativos: espacios, fechas, cabeceras, marcas de agua |
| `brush` | **Yuji Syuku** | kanji de pincel: Dengen, sellos especiales |
| `mono` | **JetBrains Mono** (Nerd Font) + respaldo CJK | terminal, editor, código |
| `brand` | **Unbounded** 600 | solo el wordmark |
| `icon` | **Material Symbols Rounded** (variable: FILL/wght/GRAD/opsz) | iconos por ligadura (`text: "wifi"`) |
Escala: caption 11,5 · small 12,5 · body 13,5 · title 15/600 · h3 18/600 · h2 22/600 · h1 26/600 ·
display 48/300 · reloj isla 14,5/600 · reloj bloqueo 196/200 (`letterSpacing: -0.03em`).
Números tabulares en relojes, porcentajes y tiempos (`font.features: { "tnum": 1 }`).
Iconos: 18–22 px, `wght 400`; estado activo = `FILL 1` animado (`font.variableAxes`).

## 3. Forma y espacio
Rejilla de 4 px. Radios: barra 14 · isla 15 (píldora) · paneles 22 · tarjetas/mosaicos 16 · controles 10–12 ·
chips 13 · ventanas niri 14 · menús 12 · hanko 7–8. Bordes de 1 px. Objetivos táctiles ≥ 32 px.
Sombras: las da niri a las capas (`layer-rule { shadow { on } }`), no se pintan en QML (salvo el brillo del hanko).

## 4. Movimiento (`Motion.*`) — un solo interruptor lo apaga todo
- `Motion.enabled` (false en Shinobi, Oni o «movimiento reducido») y `Motion.scale` (Ajustes: 0,5–1,5).
  `Motion.d(ms) = enabled ? ms * scale : 0`. Con duración 0, todo salta a su estado final sin romper nada.
- Duraciones: micro 90 · fast 150 · base 220 · slow 320 · emphasized 450 · page 600 (ms).
- Curvas (BezierSpline): `standard [0.2,0,0,1,1,1]` · `decel [0.05,0.7,0.1,1,1,1]` · `accel [0.3,0,0.8,0.15,1,1]` ·
  `sakuga` = OutBack (overshoot 1,3). Muelles (`SpringAnimation`): morph de la isla `spring 4.2 · damping 0.32`,
  hanko de espacios `spring 5 · damping 0.38` (ajústalos a ojo con capturas de vídeo).
- Coreografía: entrar = opacidad + desplazamiento 8 px (decel, base); salir = opacidad + escala 0,98 (accel, fast);
  listas escalonadas 18 ms por elemento (máx. 8); nada de animar ancho/alto de elementos grandes cada frame salvo
  la isla (pequeña); preferir `OpacityAnimator`/`ScaleAnimator`/`XAnimator` (hilo de render).
- En reposo **nada** se anima. Bucles solo mientras algo los justifica (música sonando, grabando, bloqueo visible).

## 5. Componentes (medidas de los mockups)
**Obi (barra)** — flotante, `top 8 · left/right 10 · alto 40 · radio 14`, vidrio. Izquierda: marca plana roja
36×21 · separador 1×18 · espacios · separador · título de ventana (icono 17 + texto 13 `textMuted`, máx. 360).
Espacios: celdas 26×26, gap 4, kanji 一二三… `display` 15/600; activo = hanko rojo (radio 8, borde interior blanco
18 %, sombra roja), ocupado = `textMuted` con puntitos (3 px, uno por ventana, máx. 3), vacío = `textDim` 70 %,
urgente = pulso del borde en `accent`. Rueda sobre los espacios = cambiar; clic = ir; clic derecho = renombrar.
Derecha: bandeja (iconos atenuados) · indicadores 船 (VM de Windows activa), 蛇 (IA local cargada) y 新 (reinicio pendiente)
solo cuando aplican · separador · clúster (Wi-Fi, BT, volumen, anillo de batería 18 px con %, insignia de perfil
省/均/速) · campana con punto rojo si hay pendientes. Clic en el clúster → Engawa.
**Shima (isla)** — centrada, `top 13 · alto 30 · radio 15 · fondo #050405 · borde blanco 7 %`. Reposo:
ecualizador (si suena música) + `21:38` + `火 13` + `菊` (kanji de la microestación en `accent2`).
Música: alto 38, portada circular 28, título/artista 12,5/11. OSD: crece a ~260×44 con icono, barra y valor (con
varias pantallas, el OSD de brillo dice cuál: «Portátil», «Monitor 27″»);
vuelve a reposo tras 1,2 s. Aviso de notificación: icono + resumen 1 línea durante 2,5 s. Grabando: punto 録 rojo.
Shinobi: hanko 忍 + hora + día. Oni: hanko 鬼 (negro sobre rojo, borde dorado) + `脳 78°` `絵 71°` `電 34 W`.
Hover: fecha completa en kanji + `菊花開 · florecen los crisantemos`. Clic → Koyomi. Rueda → volumen.
**Fumi (toast)** — `right 14 · top 62 · ancho 372 · radio 18`, vidrio; barra de acento 3 px a la izquierda;
kanji 文 de marca de agua (64 px, 4,5 %); acciones como botones de 30 px; barra de tiempo restante 2 px.
Crítica: borde `accent`, no expira, sonido `critical`. Pila con gap 10, máx. 3 visibles + «+N».
**Engawa (centro de control)** — `right 10 · top 56 · ancho 420 · radio 22 · padding 16`. Cabecera (icono de
marca, nombre, tiempo encendido, ajustes/bloquear/apagar 34×34). Mosaicos 2 columnas de 62 px (icono 38×38 radio
12; activo con degradado rojo suave, icono rojo con sombra; kanji de marca de agua 42 px al 7 %; chevron a página
de detalle). Sliders gruesos 34 px con icono dentro del relleno. **Brillo multipantalla** (mockup 02): con una sola
pantalla, un slider; al conectar más (en caliente, sin recargar), uno por pantalla en el mismo bloque y en el orden
físico de niri: ☀ `light_mode` en el relleno y, a la derecha, icono de la pantalla (`laptop`/`desktop_windows`/`tv`,
15 px) + nombre corto (500) + valor (600) («Portátil 45 %», «Monitor 27″ 78 %»). El texto que queda bajo el relleno se
dibuja invertido en `surface0` (segunda capa recortada al ancho del relleno): nunca se pierde. Cada slider controla SOLO
su pantalla; Mayús + arrastrar mueve todas. Sin DDC/CI: atenuación por software con chip «SW» y la pista «activa DDC/CI
en el menú del monitor para brillo real» (tooltip). La fila entra con la animación de entrada al conectar y se va con la
de salida al desconectar. Segmentado 省 Ahorro · 均 Equilibrado · 速 Rendimiento.
Tarjeta multimedia teñida con el color dominante de la portada (`ColorQuantizer`). Pie de batería: %, tiempo restante,
vatios, chip de límite de carga.
**Modos de energía** — en Engawa, dos tarjetas a media anchura: 忍 Shinobi (borde discontinuo rojo, hanko 忍,
«Máx. batería») y 鬼 Oni (hanko negro sobre rojo con borde dorado, «Máx. potencia»; activo = degradado rojo intenso
y brillo). Activación «覚醒» de Oni: estampado 1,6→1 con onda circular + brillo rojo en los bordes 600 ms.
**Torii (lanzador)** — `ancho 680 · top 150 · radio 22`, fondo vidrio fuerte, telón 42 % detrás. Campo 60 px con
torii rojo dibujado, texto 24 px y cursor rojo 2 px; pista `探す · …`. Chips de modo. Filas 56 px: icono 36
(radio 11), título 15 con coincidencias en rojo, subtítulo 12,5; seleccionada = `surface2` + barra roja 3 px con
resplandor. Grupos con cabecera en versalitas. Pie con atajos. Apps de Windows con insignia 船 (asagi) junto al icono.
**Kagi (bloqueo)** — columna izquierda en x=104: marca + `お帰りなさい、Ayoub` (top 150) · fecha kanji
(top 262, `display` 22, tracking .18em) · reloj 196/200 (top 300) · fecha en español + 晴 22° + 菊花開 (top 500) ·
campo de contraseña 392×56 radio 28 con pétalos y botón hanko → (top 600) · pistas (huella, distribución).
Derecha: proverbio vertical 縦書き (`display` 40, tracking .32em), romaji vertical, sello 殻 y traducción.
Abajo-izquierda: mini reproductor. Arriba-derecha: Wi-Fi y batería. Fondo: el de pantalla pre-difuminado + viñeta.
**Dengen (energía)** — título `お疲れさま、Ayoub` 30 px + subtítulo; 5 tarjetas 168×212 radio 26 gap 22 con kanji
de pincel 86 px y tecla (L S E R P); seleccionada roja, elevada 8 px, con barra de «mantén pulsado» (1,2 s). Si hay
reinicio pendiente por actualización, la tarjeta 再 muestra la etiqueta «Actualizar y reiniciar».
**Fune (apps de Windows)** — panel `right 10 · top 56 · ancho 420 · radio 22` desde el indicador 船 de la barra.
Cabecera con hanko 船 y «Windows · KVM · RemoteApp». Tarjeta de estado: punto (activo `success`, en pausa `warning`,
apagado `textDim`), tiempo activo, barras finas de vCPU/RAM/disco (datos solo con el panel abierto), botones Pausar ·
Escritorio · Apagar. Rejilla 3×2 de apps (mosaico 62 px, icono Material en `surface3`, nombre 12,5) y «Añadir app».
Interruptores: pausa automática (minutos), arrancar con cargador. Pie: carpeta compartida y Wine/Proton.
Ventanas RemoteApp en niri: anillo de foco **asagi** en vez del rojo, para distinguir de un vistazo lo que es Windows.
**Snake (asistente)** — panel `right 10 · top 56 · ancho 460 · alto máx. 70 % · radio 22` (mockup 11): cabecera con
serpiente blanca minimalista (trazo, no ilustración) y «蛇 Snake · local», estado del modelo (chip «en tu equipo · 0 nube»);
mensajes del usuario a la derecha en `surface2`, respuestas a la izquierda sin burbuja con texto 13,5 y código en mono;
tarjetas de contexto adjunto (journal, portapapeles) como chips; acciones propuestas como botones con el comando
visible y confirmación; campo de entrada 44 px con prefijo 蛇. Sin animación de «escribiendo» continua: tres puntos
estáticos que cambian de opacidad solo mientras se genera.
**Settei (ajustes)** — ventana flotante 1240×924 radio 18; lateral 262 px con wordmark, búsqueda y navegación
(glifo kanji 26×26 + etiqueta; seleccionado = hanko rojo). Cabecera de página `外観 Apariencia` (kanji 30 en rojo +
título 26). Tarjetas de tema 3×2 con miniatura, mini barra y ventanas, muestras de color. Acentos tradicionales
(赤 朱 金 若竹 浅葱 瑠璃 紫 紅梅 + «Desde el fondo»). Filas con interruptor/slider/desplegable.
**Mamori (mantenimiento)** — página 守 de Settei (mockup 10): tarjeta de estado grande («Todo en orden», última y
próxima revisión), línea temporal de acciones (icono + texto + hora; las retenciones con su motivo y fecha de
liberación), mosaicos de salud (disco, SSD, batería, temperaturas, snapshots) y botón secundario «Deshacer la última
actualización». Notificaciones de Mamori: discretas, agrupadas, con hanko 守; solo urgentes si requieren a Ayoub.
**Pantalla · 配置 Haichi** — página 画 de Settei (mockup 12): aviso de prueba arriba (fondo `accent` 10 %, borde 35 %,
cuenta atrás en cifras tabulares, «Revertir» fantasma + «Mantener» primario). Lienzo `surface0` con retícula de puntos
cada 14 px; cada pantalla es una tarjeta radio 9 con degradado `surface3→surface2`, numeral formal 壱 弐 参 de marca de
agua (50 px al 20 %, por encima de la etiqueta), nombre 12,5/600 y modo en cifras tabulares; la seleccionada lleva
borde `accent` + halo `accent-soft` de 4 px y la principal el hanko 主; al arrastrar, la guía del imán es una línea
discontinua `accent`. Debajo, segmentado de 4 (拡 Extender · 鏡 Duplicar · 外 Solo monitor · 内 Solo portátil) y chips de
perfil (el activo en rojo). Brillo: una fila por pantalla con su tipo (Interna · OLED / DDC/CI / Software).

## 6. Estados e interacción
Hover: `surface2` (150 ms). Pulsado: escala 0,97 + `surface3`. Foco teclado: contorno 2 px `accent` con 2 px de
separación (siempre visible al navegar con teclado). Deshabilitado: opacidad 0,4. Todo popup se cierra con Esc,
clic fuera o la misma tecla; navegación completa con teclado (flechas, Tab, Enter) y táctil (tap, arrastrar).
Gestos táctiles (07-IDEAS): arrastrar hacia abajo desde el clúster de estado = Engawa (sigue al dedo), desde la isla =
Koyomi, desde la marca = Torii; deslizar la isla en horizontal con música = otra canción; mantener pulsado = menú
contextual.

## 7. Sonido (`Sounds`)
`startup` (inicio de sesión/greeter) · `notify` · `critical` · `lock` · `unlock` · `tick` (opcional, al soltar el
volumen). Volumen de UI propio (por defecto 60 %). Nunca en Shinobi, No molestar o con la pantalla bloqueada
(salvo `unlock`). Reproducción con `pw-play`, sin QtMultimedia.

## 8. Accesibilidad
Movimiento reducido (Ajustes) = `Motion.enabled=false`. Escala de fuente 0,9–1,3. Roles y nombres
`Accessible.*` en controles. Nada se comunica solo con color (iconos/forma además del rojo).
