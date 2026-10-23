<div align="center">

<picture>
  <source media="(prefers-color-scheme: dark)" srcset="assets/logo/svg/ocarinashell-hero-animated-dark.svg">
  <img src="assets/logo/svg/ocarinashell-hero-animated-light.svg" alt="OcarinaShell · オカリナシェル" width="500">
</picture>

### Un escritorio que se toca como un instrumento.

Escritorio completo con estética japonesa para **CachyOS + niri + Quickshell**:<br>
los dotfiles OcarinaShell, terminados, probados a fondo y listos para instalar.

[![versión](https://img.shields.io/github/v/release/ayoubtahriouixd/ocarinashell?style=flat-square&color=e60033&label=versi%C3%B3n)](https://github.com/ayoubtahriouixd/ocarinashell/releases/latest)
[![comprobaciones](https://img.shields.io/github/actions/workflow/status/ayoubtahriouixd/ocarinashell/comprobaciones.yml?branch=main&style=flat-square&label=comprobaciones)](https://github.com/ayoubtahriouixd/ocarinashell/actions/workflows/comprobaciones.yml)
![CachyOS · niri · Quickshell](https://img.shields.io/badge/CachyOS-niri%20%C2%B7%20Quickshell-1b181d?style=flat-square)

**[Instalar](#instalar)** · [Capturas](#capturas) · [Qué incluye](#incluye) · [Primeros pasos](#empezar) · [Seguridad](#seguridad) · [Preguntas](#preguntas)

</div>

<p align="center"><img src="docs/img/recorrido.webp" alt="Recorrido por OcarinaShell: arranque, bloqueo, escritorio, centro de control, vídeo fluido, lanzador, ajustes, Shinobi, Oni, Fune, Snake y energía" width="100%"></p>

```bash
git clone https://github.com/ayoubtahriouixd/ocarinashell ~/ocarinashell
cd ~/ocarinashell && ./install.sh
```

## 殻 Qué es

Un escritorio entero, no un tema: barra e isla vivas, lanzador, centro de control, bloqueo, ajustes, fondos, IA
local, mantenimiento que se hace solo, apps de Windows como ventanas, vídeo fluido a 120 fps, y Ghostty, fish y
Neovim con el mismo diseño. Todo con colores tradicionales japoneses, kanji y la marca rojo sobre blanco (紅白).

| | |
|---|---|
| **美 Diseño** | 7 temas con colores tradicionales, logo animado, 6 fondos y 6 sonidos originales, arranque Limine + Plymouth propio. |
| **速 Rendimiento** | Un solo proceso de Quickshell, eventos en vez de sondeo, ~160 MB, nada se anima si no se ve. |
| **守 Se cuida solo** | 守 Mamori actualiza con snapshot, prueba, se adapta y revierte; su cerebro es 蛇 Snake, una IA local sin nube. |
| **安 No se rompe** | Modo seguro, pruebas de humo, reversión automática y una guía de rescate probada. |

Hecho para el **ThinkPad P14s Gen 6 AMD** de su autor (OLED 2880×1800, escala 1,75), pero lo específico de ese
equipo (umbral de carga, luz del teclado, NPU…) se detecta y, si no existe, se oculta.

<a id="capturas"></a>
## 景 Capturas

<sub>Capturas <b>reales</b> de OcarinaShell 1.0 en el ThinkPad (2880×1800, escala 1,75), con el tema 紅 Kurenai y su fondo. Haz clic para verlas más grandes.</sub>

<table>
  <tr>
    <td align="center" width="50%"><a href="docs/img/real/escritorio.jpg"><img src="docs/img/real/escritorio.jpg" alt="帯 Escritorio"></a><br><b>帯 Escritorio</b> · barra Obi en islas, isla Shima con reloj y 七十二候</td>
    <td align="center" width="50%"><a href="docs/img/real/engawa.jpg"><img src="docs/img/real/engawa.jpg" alt="縁 Engawa"></a><br><b>縁 Engawa</b> · centro de control: Wi-Fi, Shinobi, Oni, 滑 Nameraka, brillo y música</td>
  </tr>
  <tr>
    <td align="center" width="50%"><a href="docs/img/real/torii.jpg"><img src="docs/img/real/torii.jpg" alt="鳥 Torii"></a><br><b>鳥 Torii</b> · lanzador: apps, archivos, calculadora, ajustes, kanji y kaomoji</td>
    <td align="center" width="50%"><a href="docs/img/real/cajon.jpg"><img src="docs/img/real/cajon.jpg" alt="器 Cajón de apps"></a><br><b>器 Cajón de apps</b> · nace de la ocarina: categorías, frecuentes y A→Z (Super+D)</td>
  </tr>
  <tr>
    <td align="center" width="50%"><a href="docs/img/real/hiroba.jpg"><img src="docs/img/real/hiroba.jpg" alt="広 Hiroba"></a><br><b>広 Hiroba</b> · la isla abierta: calendario, tiempo por horas, música y el equipo en anillos</td>
    <td align="center" width="50%"><a href="docs/img/real/kagi.jpg"><img src="docs/img/real/kagi.jpg" alt="鍵 Kagi"></a><br><b>鍵 Kagi</b> · bloqueo con fecha en kanji y un proverbio vertical</td>
  </tr>
  <tr>
    <td align="center" width="50%"><a href="docs/img/real/dengen.jpg"><img src="docs/img/real/dengen.jpg" alt="電 Dengen"></a><br><b>電 Dengen</b> · energía: mantén pulsado mientras la tinta llena la tarjeta</td>
    <td align="center" width="50%"><a href="docs/img/real/snake.jpg"><img src="docs/img/real/snake.jpg" alt="蛇 Snake"></a><br><b>蛇 Snake</b> · IA local, gratis y privada; también por voz (Super+Alt+A)</td>
  </tr>
  <tr>
    <td align="center" width="50%"><a href="docs/img/real/shinobi.jpg"><img src="docs/img/real/shinobi.jpg" alt="忍 Shinobi"></a><br><b>忍 Shinobi</b> · ahorro extremo en negro OLED</td>
    <td align="center" width="50%"><a href="docs/img/real/oni.jpg"><img src="docs/img/real/oni.jpg" alt="鬼 Oni"></a><br><b>鬼 Oni</b> · rendimiento extremo para jugar</td>
  </tr>
  <tr>
    <td align="center" width="50%"><a href="docs/img/real/fune.jpg"><img src="docs/img/real/fune.jpg" alt="船 Fune"></a><br><b>船 Fune</b> · apps de Windows como ventanas nativas</td>
    <td align="center" width="50%"><a href="docs/img/real/fluido.jpg"><img src="docs/img/real/fluido.jpg" alt="滑 Nameraka"></a><br><b>滑 Nameraka</b> · vídeo fluido hasta 120 fps (×2 · ×4 · ×6 · A medida)</td>
  </tr>
  <tr>
    <td align="center" width="50%"><a href="docs/img/real/ajustes-kohaku.jpg"><img src="docs/img/real/ajustes-kohaku.jpg" alt="設 Settei"></a><br><b>設 Settei</b> · ajustes en el tema claro 紅白 Kōhaku</td>
    <td align="center" width="50%"><a href="docs/img/real/mamori.jpg"><img src="docs/img/real/mamori.jpg" alt="守 Mamori"></a><br><b>守 Mamori</b> · el sistema se cuida solo (tema 紅 Kurenai)</td>
  </tr>
  <tr>
    <td align="center" width="50%"><a href="docs/img/real/pantallas.jpg"><img src="docs/img/real/pantallas.jpg" alt="画 Pantallas"></a><br><b>画 Pantallas</b> · monitores, brillo y cuidado del OLED</td>
    <td align="center" width="50%"><a href="docs/img/real/atajos.jpg"><img src="docs/img/real/atajos.jpg" alt="技 Atajos"></a><br><b>技 Atajos</b> · todos los atajos, editables desde la propia página</td>
  </tr>
</table>

<details>
<summary><b>Los mockups</b>: el objetivo visual que cada fase reprodujo y comparó con una captura de verdad</summary>

<table>
  <tr>
    <td align="center" colspan="2"><a href="assets/mockups/13-fluido.png"><img src="docs/img/mockups/13-fluido.jpg" alt="Vídeo fluido"></a><br><b>滑 Fluido</b> · <b>nuevo en 1.1</b>: cualquier vídeo a pantalla completa, hasta 120 fps, generando fotogramas con Lossless Scaling desde Engawa (×2 · ×4 · ×6 · A medida)</td>
  </tr>
  <tr>
    <td align="center" width="50%"><a href="assets/mockups/01-escritorio.png"><img src="docs/img/mockups/01-escritorio.jpg" alt="Escritorio"></a><br><b>帯 Escritorio</b> · barra Obi, isla Shima, espacios <i>hanko</i>, Ghostty y Neovim</td>
    <td align="center" width="50%"><a href="assets/mockups/02-centro-de-control.png"><img src="docs/img/mockups/02-centro-de-control.jpg" alt="Centro de control"></a><br><b>縁 Engawa</b> · centro de control: brillo de cada pantalla y 滑 Fluido</td>
  </tr>
  <tr>
    <td align="center" width="50%"><a href="assets/mockups/03-bloqueo.png"><img src="docs/img/mockups/03-bloqueo.jpg" alt="Bloqueo"></a><br><b>鍵 Kagi</b> · bloqueo: cada tecla ilumina un agujero de la ocarina</td>
    <td align="center" width="50%"><a href="assets/mockups/04-lanzador.png"><img src="docs/img/mockups/04-lanzador.jpg" alt="Lanzador"></a><br><b>鳥 Torii</b> · lanzador con calculadora, archivos, ventanas y kaomoji</td>
  </tr>
  <tr>
    <td align="center" width="50%"><a href="assets/mockups/05-energia.png"><img src="docs/img/mockups/05-energia.jpg" alt="Energía"></a><br><b>電 Dengen</b> · energía: mantén pulsado mientras la tinta llena la tarjeta</td>
    <td align="center" width="50%"><a href="assets/mockups/06-shinobi.png"><img src="docs/img/mockups/06-shinobi.jpg" alt="Shinobi"></a><br><b>忍 Shinobi</b> · ahorro extremo en negro OLED</td>
  </tr>
  <tr>
    <td align="center" width="50%"><a href="assets/mockups/07-ajustes-kohaku.png"><img src="docs/img/mockups/07-ajustes-kohaku.jpg" alt="Ajustes en tema claro"></a><br><b>設 Settei</b> · ajustes en el tema claro 紅白 Kōhaku</td>
    <td align="center" width="50%"><a href="assets/mockups/08-oni.png"><img src="docs/img/mockups/08-oni.jpg" alt="Oni"></a><br><b>鬼 Oni</b> · rendimiento extremo para jugar</td>
  </tr>
  <tr>
    <td align="center" width="50%"><a href="assets/mockups/09-fune.png"><img src="docs/img/mockups/09-fune.jpg" alt="Fune"></a><br><b>船 Fune</b> · apps de Windows como ventanas nativas</td>
    <td align="center" width="50%"><a href="assets/mockups/10-mamori.png"><img src="docs/img/mockups/10-mamori.jpg" alt="Mamori"></a><br><b>守 Mamori</b> · el sistema se cuida solo</td>
  </tr>
  <tr>
    <td align="center" width="50%"><a href="assets/mockups/11-snake.png"><img src="docs/img/mockups/11-snake.jpg" alt="Snake"></a><br><b>蛇 Snake</b> · IA local, gratis y privada</td>
    <td align="center" width="50%"><a href="assets/mockups/12-pantallas.png"><img src="docs/img/mockups/12-pantallas.jpg" alt="Pantallas"></a><br><b>画 Pantallas</b> · organizar monitores, brillo y cuidado del OLED</td>
  </tr>
</table>

</details>

### Arranque y apagado · capturas reales

<table>
  <tr>
    <td align="center" width="50%"><a href="assets/boot/limine/preview-dark.png"><img src="docs/img/arranque/limine-oscuro.jpg" alt="Limine oscuro"></a><br><b>Limine</b> oscuro · real en QEMU</td>
    <td align="center" width="50%"><a href="assets/boot/limine/preview-light.png"><img src="docs/img/arranque/limine-claro.jpg" alt="Limine claro"></a><br><b>Limine</b> claro · real en QEMU</td>
  </tr>
  <tr>
    <td align="center" width="50%"><a href="assets/boot/plymouth/preview-boot-dark.png"><img src="docs/img/arranque/plymouth-arranque.jpg" alt="Plymouth arranque"></a><br><b>Plymouth</b> · arranque (ようこそ)</td>
    <td align="center" width="50%"><a href="assets/boot/plymouth/preview-shutdown-dark.png"><img src="docs/img/arranque/plymouth-apagado.jpg" alt="Plymouth apagado"></a><br><b>Plymouth</b> · apagado (おやすみなさい)</td>
  </tr>
  <tr>
    <td align="center" width="50%"><a href="assets/boot/plymouth/preview-reboot-light.png"><img src="docs/img/arranque/plymouth-reinicio.jpg" alt="Plymouth reinicio"></a><br><b>Plymouth</b> · reinicio, variante clara (また後で)</td>
    <td align="center" width="50%"><a href="assets/boot/plymouth/preview-password-dark.png"><img src="docs/img/arranque/plymouth-contrasena.jpg" alt="Plymouth contraseña"></a><br><b>Plymouth</b> · contraseña del disco con pétalos</td>
  </tr>
</table>

### Marca y fondos

<p align="center">
  <img src="assets/logo/svg/ocarinashell-icon-animated.svg" alt="Icono animado" width="150">
  &nbsp;&nbsp;
  <img src="assets/wallpapers/preview/preview.jpg" alt="Los 6 fondos originales" width="560">
</p>
<p align="center"><sub>Todas las variantes animadas del logo: <code>assets/logo/preview.html</code> (descarga el repo y ábrelo en el navegador).</sub></p>

<a id="instalar"></a>
## 入 Instalación

### Requisitos

| | Necesitas | Notas |
|---|---|---|
| Sistema | **CachyOS** (o Arch) | Con **Btrfs + snapper** para tener snapshot antes de instalar (CachyOS lo trae). |
| Disco | ~10 GB para la base | Más ~20 GB para la IA local (Snake) y ~70 GB si usas Windows (Fune). |
| Red | Internet durante la instalación | Después, todo funciona en local. |

### El instalador

```bash
git clone https://github.com/ayoubtahriouixd/ocarinashell ~/ocarinashell
cd ~/ocarinashell && ./install.sh
```

Ejecútalo **como tu usuario, sin `sudo`**: lo pide solo para lo que lo necesita, una vez. Es un pequeño espectáculo en
la terminal:

1. **紅 Apertura** — un sol rojo crece y las nubes lo cruzan mientras el nombre aparece tinta a tinta.
2. **確 Tu equipo** — sistema, red, disco, gráfica y sudo, cada prueba con su latido.
3. **彩 Tu tema** — las siete tarjetas con sus colores de verdad; la pantalla entera se tiñe del tema que señalas.
4. **包 Qué instalar** — la base va siempre; marca la IA local, los juegos, el vídeo fluido, Windows… ([la lista](scripts/paquetes.txt)).
5. **結 La instalación** — una línea de tiempo con sellos (記 包 字 結 系 彩 起 診), un pincel de progreso y el
   registro en vivo; antes de tocar el sistema, un snapshot.
6. **ようこそ** — pétalos de sakura y los primeros atajos.

| Opción | Para qué |
|---|---|
| `--demo` | Todo el recorrido, animaciones incluidas, **sin cambiar nada**. Pruébalo primero. |
| `--tema <id>` | `kurenai` · `kohaku` · `sumi` · `ai` · `matcha` · `yozakura` · `shinobi`, sin preguntar. |
| `--si` | Sin preguntas: grupos por defecto y el tema elegido (o Kurenai). |
| `--sin-paquetes` · `--sin-sistema` | Solo dotfiles, fuentes y tema; o sin los ficheros de root. |
| `--simple` | Sin animaciones (también sin terminal o con `NO_MOTION=1`). |

**Qué toca**: paquetes de los repos oficiales (y dos del AUR con `paru`, si lo tienes), tus dotfiles (enlaces, con
copia de seguridad de lo que ya tuvieras: `scripts/install.sh --uninstall` lo devuelve todo), unos ficheros de root
(reglas de polkit, el ayudante de mantenimiento y la única regla de sudo sin contraseña, solo para ese ayudante,
comprobada con `visudo -c`) y tus servicios de usuario. **Qué no toca**: `/boot`, el kernel,
PAM ni el greeter; el tema de arranque es opcional y va aparte (ver Primeros pasos). El registro completo queda en
`~/.cache/ocarinashell/install.log`.

<a id="empezar"></a>
## 始 Primeros pasos

1. **Cierra la sesión y entra en niri.** La shell arranca sola.
2. **Los atajos que vas a usar todo el rato** (la lista completa con **Super+?** o en [`docs/03-ATAJOS.md`](docs/03-ATAJOS.md)):

   | Atajo | | Atajo | |
   |---|---|---|---|
   | **Super+A** | 鳥 Lanzador | **Super+D** | 器 Cajón de apps |
   | **Super+,** | 設 Ajustes | **Super+Shift+C** | 縁 Centro de control |
   | **Super+V** | 蔵 Portapapeles | **Super+N** | 手帳 Notas |
   | **Super+Shift+A** | 蛇 Snake | **Super+Alt+A** | 蛇 Snake por voz |
   | **Super+Alt+S** | 忍 Shinobi | **Super+Alt+O** | 鬼 Oni |
   | **Super+X** | 電 Energía | **Super+Alt+L** | 鍵 Bloquear |

3. **Ajustes** (Super+,): tema y acento, fondos (y rotación por estación 七十二候), barra, pantallas, energía, atajos
   (se cambian ahí mismo) y cada módulo.
4. **Opcional**, cuando quieras:
   - IA local: `ocarina-snake models pull gpt-oss-20b` (12 GB) y la voz `ocarina-snake models pull whisper`.
   - Apps de Windows: [`docs/WINDOWS.md`](docs/WINDOWS.md) · vídeo fluido: [`docs/FLUIDO.md`](docs/FLUIDO.md) ·
     juegos: [`docs/JUEGOS.md`](docs/JUEGOS.md) · batería: [`docs/ENERGIA.md`](docs/ENERGIA.md).
   - Arranque y apagado con la marca: `sudo bash scripts/root/fase-13.sh` (Limine y Plymouth, cada uno con su snapshot);
     después, si quieres, el greeter (`scripts/root/greeter.sh`) y que el arranque siga solo al tema
     (`scripts/root/arranque-auto.sh instalar`). Lee antes [`docs/05-RESCATE.md`](docs/05-RESCATE.md).
5. **`ocarina doctor`** te dice en segundos si todo está en orden.

<a id="incluye"></a>
## 具 Qué incluye

| Módulo | Qué es |
|---|---|
| **帯 Obi** · **島 Shima** | Barra de cristal con espacios en numerales kanji y un *hanko* que se desliza con muelle; isla viva que pasa de reloj a música (ecualizador real), OSD y avisos. |
| **縁 Engawa** · **文 Fumi** · **暦 Koyomi** | Centro de control, notificaciones propias y calendario con las 72 microestaciones (七十二候). |
| **鳥 Torii** · **蔵 Kura** · **手帳 Techō** · **見張 Mihari** | Lanzador, portapapeles, notas y monitor del sistema. |
| **鍵 Kagi** · **電源 Dengen** | Bloqueo que «suena» (cada tecla, una nota) y menú de energía con pincel. |
| **設定 Settei** · **壁紙 Kabegami** | Ajustes completos (claro y oscuro) y explorador de fondos con transición de tinta. |
| **忍 Shinobi** · **鬼 Oni** | Ahorro extremo de batería y rendimiento extremo para jugar (gamescope + FSR, MangoHud, GameMode). |
| **滑 Nameraka** | Vídeo fluido en todo el sistema: lo que veas a pantalla completa (Chrome, Firefox, mpv…) hasta 120 fps generando fotogramas con Lossless Scaling (LSFG 3.1 vía lsfg-vk), con ×2 · ×4 · ×6 · A medida desde Engawa. Al apagarlo, todo como estaba. |
| **船 Fune** | Apps de Windows como ventanas nativas (Windows en KVM + RemoteApp), con pausa automática. |
| **蛇 Snake** · **守 Mamori** | IA local gratuita (también por voz, con whisper.cpp) y mantenimiento autónomo con snapshot, pruebas y reversión. |
| **器 Cajón de apps** · **技 Atajos** | La ocarina de la barra abre las apps por categorías (Super+D); todos los atajos se cambian desde Ajustes, validados. |
| **Terminal y editor** | Ghostty translúcido, fish, starship y Neovim con el mismo diseño. |
| **Arranque** | Limine + Plymouth animado + despedida enlazada: nunca se ve una consola. |

Y [13 ideas extra](docs/07-IDEAS.md), todas desactivables: cuidado del OLED, organizar pantallas y brillo por monitor,
copias de seguridad reales, restaurar la sesión, SSH de producción marcado en rojo, cuentagotas con colores japoneses,
modo foco, leer y traducir japonés de la pantalla, kaomoji, gestos táctiles y más.

<a id="seguridad"></a>
## 安 Seguridad: por qué no se va a romper

- **Snapshot antes de cambiar el sistema** (el instalador, Mamori en cada actualización), arrancables desde Limine, y
  el kernel LTS de respaldo.
- **La shell se recupera sola**: si falla en bucle arranca un modo seguro, y las teclas esenciales tienen respaldo.
- **Mamori nunca actualiza sin snapshot ni pruebas**, retiene lo que huele mal (noticias de Arch, PKGBUILD sospechosos,
  kernels que no arrancan) y revierte solo. Sin contraseña solo puede usar un ayudante con órdenes fijas.
- **Lo del arranque lo ejecutas tú**, en scripts revisables que se prueban antes en QEMU.
- Si usas un agente de IA en el repo, un *hook* de guardia (201 pruebas) le impide tocar discos, arranque, PAM,
  sudoers o tu sesión. Guía para agentes: [`AGENTS.md`](AGENTS.md).
- Recuperación paso a paso: [`docs/05-RESCATE.md`](docs/05-RESCATE.md).

## 守 Mantenimiento: ninguno

El sistema se cuida solo. Cada noche, con el cargador puesto y sin molestarte, revisa su salud, lee las noticias de
Arch y CachyOS y los changelogs, deja madurar los cambios grandes, actualiza con snapshot, pasa las pruebas, se adapta
si algo cambió y, si algo falla, vuelve atrás. Su cerebro es **蛇 Snake**, una IA local gratuita. Tú solo ves un
resumen semanal y, muy de vez en cuando, un aviso que de verdad te necesita (BIOS, reinicio). Detalles en
[`docs/06-ACTUALIZACIONES.md`](docs/06-ACTUALIZACIONES.md).

## 更 Actualizar y desinstalar

```bash
cd ~/ocarinashell && git pull && ./install.sh
```

Tus ajustes viven fuera del repo (`~/.config/ocarinashell`, `~/.local/state/ocarinashell`): actualizar no los toca.
Lo nuevo de cada versión, en [`CHANGELOG.md`](CHANGELOG.md).

Desinstalar: `bash scripts/install.sh --uninstall` (devuelve tus ficheros originales) y
`sudo bash scripts/install-system.sh --uninstall` (ficheros de root); los paquetes se quedan. Si quieres volver al
punto de partida exacto, el snapshot «OcarinaShell: antes de instalar».

## 史 Cómo se hizo

OcarinaShell se construyó con 18 fases de instalacion
con criterios de aceptación medibles: snapshot antes de cada una, capturas comparadas con los mockups, medidas de
rendimiento, revisiones independientes con agentes y simulacros de averías. Todo está en el repo: las fases en
[`docs/historia/fases`](docs/historia/fases), el porqué de cada decisión en [`docs/DECISIONES.md`](docs/DECISIONES.md)
y el estado en [`docs/PROGRESS.md`](docs/PROGRESS.md).

<a id="preguntas"></a>
## 問 Preguntas frecuentes

<details>
<summary><b>¿Funciona en otro portátil o en un PC?</b></summary>

Sí. Las medidas siguen la escala de tu pantalla, y lo que es propio del P14s (umbral de carga, luz del teclado, NPU,
ventilador) se detecta y, si no existe, se oculta. En la primera sesión, `ocarina doctor` te dice qué ha encontrado.

</details>

<details>
<summary><b>¿Qué datos salen de mi equipo?</b></summary>

Ninguna telemetría. Solo hay red para paquetes y actualizaciones, el tiempo (Open-Meteo) y lo que tú actives (fondos de
Wallhaven, Claude como IA de Mamori). Snake, la voz, la lectura y traducción de pantalla y el resto de la IA local
funcionan sin conexión.

</details>

<details>
<summary><b>¿Fluido funciona con YouTube, Netflix o cualquier vídeo?</b></summary>

Con cualquier app que muestre el vídeo a **pantalla completa**: Chrome, Firefox, mpv, apps Electron… Como Lossless
Scaling en Windows, captura la ventana, genera los fotogramas intermedios y los presenta encima, a los Hz de tu
pantalla; el ratón y el teclado siguen yendo al vídeo. Necesita tu copia de
[Lossless Scaling](https://store.steampowered.com/app/993090/Lossless_Scaling/) (rama `lsfg-vk` en Steam).

</details>

<details>
<summary><b>¿Y si no uso CachyOS?</b></summary>

En Arch funciona igual (el instalador avisa). Otras distribuciones no están soportadas: los paquetes y el
mantenimiento automático dan por hecho pacman.

</details>

<details>
<summary><b>Algo se ha roto</b></summary>

Hay un snapshot de antes de instalar y de cada actualización, y el modo seguro de la shell. Empieza por
`ocarina doctor` y sigue [`docs/05-RESCATE.md`](docs/05-RESCATE.md). Si no arranca, elige en Limine el snapshot
anterior o el kernel LTS.

</details>

## 構 Estructura

```
install.sh          el instalador (./install.sh --demo para verlo sin cambiar nada)
shell/              la shell en QML (Quickshell): servicios, componentes, módulos, IPC, modo seguro
config/             niri, Ghostty, fish, starship, Neovim y demás dotfiles
bin/ · lib/         la CLI `ocarina` y sus herramientas (bash y Python sin dependencias)
native/             código nativo (滑 Nameraka: C++/Vulkan)
system/ · systemd/  ficheros de root (polkit, ayudante de Mamori, greeter) y servicios de usuario
snake/              la IA local: modelos, tareas con esquema, acciones permitidas y evaluaciones
scripts/            enlaces, sistema, fuentes, doctor, pruebas de humo, paquetes; root/ para el arranque
assets/             logo, temas, fondos, sonidos, datos (72 microestaciones, kanji…), arranque y mockups
docs/               visión, diseño, arquitectura, atajos, rendimiento, rescate, guías, decisiones e historia
tests/              comprobaciones (QML, contraste, simulacros de Mamori, robustez…)
AGENTS.md           guía para agentes de IA · CLAUDE.md memoria del proyecto para Claude Code
```

## 礼 Créditos

- El arte, el logo, los fondos y los sonidos son **originales** y se regeneran con [`tools/`](tools/README.md).
- Las fuentes (Geist, Unbounded, JetBrains Mono, Zen Kaku Gothic New, Shippori Mincho B1, Yuji Syuku y Material Symbols,
  con licencia OFL o Apache) las descarga el instalador; no se incluyen aquí.
- Construido sobre [niri](https://github.com/YaLTeR/niri), [Quickshell](https://quickshell.org) y
  [CachyOS](https://cachyos.org). OcarinaShell se escribe desde cero: no copia código de otras shells.
- El vídeo fluido usa [lsfg-vk](https://lsfg-vk.dev) (CC BY-NC-ND) con tu copia de
  [Lossless Scaling](https://store.steampowered.com/app/993090/Lossless_Scaling/): OcarinaShell los configura, nunca
  los copia ni los modifica.

## 約 Licencia

**Created by Ayoub.** Código bajo [GPL-3.0-or-later](LICENSE); arte original bajo
[CC BY-SA 4.0](docs/LICENCIA-ARTE.txt); el nombre y el logo identifican el proyecto original. Sin garantía, sin
telemetría. Condiciones completas en español: [`docs/LICENCIA.md`](docs/LICENCIA.md).

---

<details>
<summary><b>In English</b></summary>

OcarinaShell is a complete Japanese-styled desktop for **CachyOS + niri + Quickshell**: Ayoub's dotfiles, finished
and tested in depth. Bar and live island, launcher, control centre, lock screen, settings, wallpapers, a local AI
(also by voice), maintenance that runs by itself with snapshots and rollback, Windows apps as native windows,
system-wide frame generation for full-screen video, and Ghostty, fish and Neovim in the same design. Install with
`git clone https://github.com/ayoubtahriouixd/ocarinashell ~/ocarinashell && cd ~/ocarinashell && ./install.sh`
(`./install.sh --demo` shows the whole animated installer without changing anything). (`docs/historia`). Docs are in Spanish; `AGENTS.md` guides AI agents working on the repo.

</details>

<p align="center"><img src="assets/logo/svg/ocarinashell-seal.svg" alt="殻" width="36"></p>
