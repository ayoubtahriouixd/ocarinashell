# 00 · Visión — OcarinaShell オカリナシェル

> Un escritorio que se toca como un instrumento: cada gesto es una nota, cada pantalla tiene silencio alrededor.

## Concepto
**和モダン × アニメ.** Modernismo japonés (espacio, papel, tinta, sello rojo) con el *timing* del anime
(anticipación, golpe, rebote: momentos de *sakuga*). La ocarina es la metáfora: el sistema «suena» al usarlo
(ondas, agujeros que se iluminan, notas suaves), pero en reposo está en silencio absoluto: cero animaciones
y cero CPU cuando no haces nada.

## Principios
| | Principio | En la práctica |
|---|---|---|
| 間 | **Ma**, el espacio negativo | Pocos elementos visibles. Lo secundario aparece al necesitarlo. Márgenes generosos. |
| 紅白 | **Kōhaku**, rojo sobre blanco | El rojo `#E60033` es la firma: estados activos, foco, acciones primarias, sellos *hanko*. Nunca grandes masas rojas sin intención. |
| 渋い | **Shibui**, elegancia sobria | Paletas contenidas, tipografía impecable, un solo acento por pantalla. |
| 侘寂 | **Wabi-sabi** | Texturas sutiles (papel washi, grano), trazos de pincel, asimetría intencionada. |
| 作画 | **Sakuga** | Pocas animaciones, pero memorables: muelles con rebote, sellos que «estampan», tinta que se expande. |
| 静 | **Silencio** | En reposo nada se mueve ni consulta nada. El modo 忍 Shinobi lo lleva al extremo. |

## Marca
- **Logo**: ocarina roja lacada sobre blanco, ondas sonoras rojas y un sello *hanko* que alterna `❯_` (shell)
  y 殻 (*kara*, «cáscara/concha»: el *shell* en japonés). Activos en `assets/logo/` (ver `preview.html`).
- **Wordmark**: «Ocarina» en tinta + «Shell» en rojo (Unbounded 600) y オカリナ・シェル debajo.
- **Uso**: sobre claro, el icono completo (cuadrado blanco). Sobre oscuro, la marca sola (`mark.svg`) o el icono
  blanco como «tarjeta». En la barra, la versión plana (`mark-flat`). En Shinobi, la monocroma en tono apagado.
- Tamaño mínimo del icono con sello: 24 px; por debajo, `icon-flat` sin detalles.
- El componente QML `assets/logo/qml/OcarinaLogo.qml` ya está verificado (renderizado offscreen con Qt 6.12):
  úsalo, no lo redibujes.

## Momentos de firma (lo que tiene que dejar boquiabierto)
1. **Hanko de espacios**: los espacios de trabajo son numerales kanji 一 二 三…; el activo es un sello rojo que
   **se desliza con muelle** hasta el nuevo espacio.
2. **Shima, la isla viva**: en el centro de la barra, una píldora negra que se transforma (*morph* con muelle)
   entre reloj → música (portada + ecualizador real de PipeWire) → OSD de volumen/brillo → aviso de notificación
   → grabación. Al pasar el ratón muestra la fecha en kanji y la microestación del día (七十二候).
3. **Kagi, el bloqueo que suena**: cada tecla de la contraseña ilumina un agujero de la ocarina y lanza una onda;
   los puntos de la contraseña son pétalos de sakura; contraseña errónea → la ocarina tiembla y las ondas se
   apagan; correcta → estallido de ondas y la pantalla se disuelve. Reloj gigante, fecha en kanji, proverbio del
   día en vertical (縦書き) con su sello.
4. **Shinobi 忍**: al activarlo, un sello 忍 se estampa en la isla y todo se funde a negro OLED como tinta
   diluyéndose; al salir, el color vuelve. (La animación de entrada es la ÚNICA permitida en ese modo.)
5. **Fondo con transición de tinta**: cambiar de fondo es una mancha de tinta que se expande (shader).
6. **Ventanas que florecen**: shaders personalizados de niri para abrir (florecer de tinta) y cerrar (disolución).
7. **Torii**: el lanzador aparece como quien cruza una puerta torii; resultados con escalonado sutil.
8. **Dengen**: menú de energía con kanji de pincel enormes (鍵 眠 退 再 終); las acciones destructivas se confirman
   manteniendo pulsado mientras la tarjeta se llena de tinta.
9. **El calendario vivo**: 72 microestaciones, meses tradicionales (神無月), fase lunar, proverbio del día: presentes
   con mesura en bloqueo, isla, calendario, terminal y Neovim.
10. **Sonido**: notas originales con timbre de ocarina (`assets/sounds/`), sutiles, desactivables; silencio en
    Shinobi y No molestar.
11. **鬼 Oni, el despertar (覚醒)**: el modo rendimiento entra como un *power-up* de anime: el sello 鬼 se estampa en la
    isla con onda expansiva y un brillo rojo recorre los bordes una vez; después, silencio y todo el hardware para el juego.
12. **Arranque y apagado continuos**: Limine con la marca, Plymouth con la ocarina que toca (ようこそ / おやすみなさい /
    また後で), greeter y despedida en la misma posición: nunca se ve una consola ni un salto.
13. **船 Fune, el barco de Windows**: las apps de Windows llegan como ventanas nativas de niri (con su anillo de foco
    浅葱 y el sello 船), aparecen en Torii como cualquier app y la máquina virtual se duerme sola cuando no la usas.
14. **守 Mamori, el guardián (お守り)**: el sistema se cuida solo. Investiga, actualiza, se adapta y se repara mientras
    duermes; Ayoub solo ve un resumen semanal sereno y, si algo no le convence, un botón de «deshacer».
15. **蛇 Snake, la serpiente blanca (白蛇)**: en Japón, guardiana de la casa y mensajera de buena fortuna. Aquí es una IA
    local que piensa sin nube ni suscripciones: aparece cuando hace falta (un discreto 蛇 en la barra) y desaparece después.

## Idioma y tono
- UI en **español** claro. El japonés es ornamento y poesía: kanji junto a la etiqueta, nunca en su lugar.
  Glosario: `assets/data/kanji-ui.json`. Saludos por hora (おはよう/こんにちは/こんばんは/おやすみ).
- Kanji siempre con fuentes japonesas (formas JP, no chinas): Shippori Mincho B1 (decorativo),
  Zen Kaku Gothic New (texto), Yuji Syuku (pincel).

## Temas (assets/data/themes/*.json)
| Tema | Modo | Carácter |
|---|---|---|
| 紅 **Kurenai** (por defecto) | oscuro | tinta sumi + rojo laca; apto OLED |
| 紅白 **Kōhaku** | claro | el logo hecho tema: washi blanco + sello rojo |
| 墨 **Sumi** | oscuro | grises de tinta; solo el sello y los errores en rojo |
| 藍 **Ai** | oscuro | índigo aizome + oro |
| 抹茶 **Matcha** | claro | té verde y papel kinari |
| 夜桜 **Yozakura** | oscuro | violeta nocturno + rosa sakura |
| 忍 **Shinobi** | negro puro | lo usa el modo ahorro; luminancia mínima |

Cada tema trae su fondo original (`assets/wallpapers/`, generado por `tools/wallpapers.py`). El usuario puede
añadir los suyos (anime incluido) desde Kabegami; nosotros nunca distribuimos arte con derechos.

## Mockups (objetivo visual)
| Fichero | Qué fija |
|---|---|
| `01-escritorio.png` | barra Obi, isla, espacios hanko, ventanas niri (radio 14, anillo de foco degradado), Ghostty con fastfetch kanji y prompt, Neovim con statusline kanji, notificación |
| `02-centro-de-control.png` | Engawa: rápidos con kanji de marca de agua, tarjetas 忍 Shinobi y 鬼 Oni, tarjeta 滑 Fluido (×2 · ×4 · ×6 · A medida; llega con la fase 11 B), sliders (brillo por pantalla: portátil + monitor externo), perfiles 省/均/速, música, batería |
| `03-bloqueo.png` | Kagi: composición asimétrica, reloj 196 px, fecha kanji, pétalos, proverbio vertical con sello |
| `04-lanzador.png` | Torii: búsqueda, chips de modo, resultados con coincidencias en rojo, acciones, pie de atajos |
| `05-energia.png` | Dengen: kanji de pincel, selección roja, «mantén para apagar» |
| `06-shinobi.png` | negro OLED, todo atenuado, sello 忍 en la isla, aviso con la autonomía estimada |
| `07-ajustes-kohaku.png` | Settei en el tema claro: barra lateral con kanji, tarjetas de tema, acentos tradicionales |
| `08-oni.png` | 鬼 Oni activo: juego en gamescope con MangoHud kanji, isla con temperaturas y vatios, aviso de activación |
| `09-fune.png` | 船 Fune: panel de apps de Windows (estado de la VM, recursos, apps, pausa automática) y ventana RemoteApp en niri |
| `10-mamori.png` | 守 Mamori en Settei (tema Kurenai): estado, línea temporal de acciones, retenciones con motivo, salud, tarjeta de Snake |
| `11-snake.png` | 蛇 Snake: asistente local en un panel, respuesta con contexto del sistema y acción propuesta con confirmación |
| `12-pantallas.png` | Settei → Pantalla: 配置 Haichi (pantallas a escala, principal 主, perfiles, «revertir en 15 s»), brillo de cada pantalla y 保護 cuidado del OLED |
| `13-fluido.png` | 滑 Nameraka activo sobre un vídeo a pantalla completa: página Fluido de Engawa (30 → 120 fps, tira de ritmo, modos, motor, calidad) y OSD de la isla |
| `assets/boot/limine/preview-*.png` | menú de Limine real (QEMU) con el tema oscuro y claro |
| `assets/boot/plymouth/preview-*.png` | Plymouth: arranque, apagado, reinicio y contraseña de disco |

## Anti-objetivos
Nada de neón RGB, animaciones en bucle en reposo, transparencias que dañen la lectura, iconos mezclados de
varios estilos, ni copiar configuraciones ajenas. Si una idea es bonita pero gasta batería sin aportar, fuera.
