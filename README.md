<div align="center">

<picture>
  <source media="(prefers-color-scheme: dark)" srcset="assets/logo/svg/ocarinashell-hero-animated-dark.svg">
  <img src="assets/logo/svg/ocarinashell-hero-animated-light.svg" alt="OcarinaShell · オカリナシェル" width="500">
</picture>

### Un escritorio que se toca como un instrumento.

Escritorio completo con estética japonesa para **CachyOS + niri + Quickshell**,<br>
que **Claude Code construye en tu equipo** fase a fase, con un snapshot y pruebas en cada paso.

[![versión](https://img.shields.io/github/v/release/ayoubtahriouixd/ocarinashell?style=flat-square&color=e60033&label=versi%C3%B3n)](https://github.com/ayoubtahriouixd/ocarinashell/releases/latest)
[![comprobaciones](https://img.shields.io/github/actions/workflow/status/ayoubtahriouixd/ocarinashell/comprobaciones.yml?branch=main&style=flat-square&label=comprobaciones)](https://github.com/ayoubtahriouixd/ocarinashell/actions/workflows/comprobaciones.yml)
![CachyOS · niri · Quickshell](https://img.shields.io/badge/CachyOS-niri%20%C2%B7%20Quickshell-1b181d?style=flat-square)
![Claude Code](https://img.shields.io/badge/construido%20con-Claude%20Code-d97757?style=flat-square)

**[Instalar](#instalar)** · [Capturas](#capturas) · [Qué incluye](#incluye) · [Fases](#fases) · [Seguridad](#seguridad) · [Preguntas](#preguntas)

</div>

<p align="center"><img src="docs/img/recorrido.webp" alt="Recorrido por OcarinaShell: arranque, bloqueo, escritorio, centro de control, vídeo fluido, lanzador, ajustes, Shinobi, Oni, Fune, Snake y energía" width="100%"></p>
<p align="center"><sub>El arranque son capturas reales (Limine en QEMU, Plymouth en plymouthd). El resto son los mockups a tamaño real
(2880×1800): el objetivo visual que cada fase reproduce y compara con una captura de verdad.</sub></p>

```bash
curl -fsSL https://raw.githubusercontent.com/ayoubtahriouixd/ocarinashell/main/install.sh | bash
```

## 殻 Qué es

OcarinaShell no es un paquete de *dotfiles*: es un **kit de construcción**. Trae todo lo que hace falta para que
[Claude Code](https://code.claude.com/docs/en/overview) levante en tu equipo un escritorio entero, pieza a pieza, sin
romper nada.

| Pieza | Qué trae |
|---|---|
| **設計 Especificación** | Arquitectura, diseño a píxel (tokens, tipografía, movimiento) y 18 fases con criterios de aceptación medibles. |
| **美 Arte original** | Logo animado rojo sobre blanco, 6 fondos, 6 sonidos de ocarina, 7 temas con colores tradicionales japoneses y tema de arranque Limine + Plymouth probado de verdad. |
| **守 Redes de seguridad** | Snapshot antes de cada fase, un *hook* que bloquea lo peligroso (201 pruebas), modo seguro de la shell y reversión automática. |
| **自 Piloto automático** | 守 Mamori se actualiza, se adapta y se repara solo; su cerebro es 蛇 Snake, una IA local gratuita que funciona sin nube. |

Está pensado para el **ThinkPad P14s Gen 6 AMD** de su autor (OLED 2880×1800, escala 1,75). La fase 0 inspecciona tu
equipo y adapta lo que cambie: pantalla, sensores, teclas o cargador de arranque.

<a id="capturas"></a>
## 景 Capturas

<sub>Haz clic en cualquier imagen para verla a tamaño real (2880×1800).</sub>

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
| Sistema | **CachyOS** con **niri** | En Arch también funciona (con aviso). Mejor recién instalado. |
| Disco | ~10 GB para la base | Más ~70 GB si usas Windows (Fune) y ~20 GB para la IA local (Snake). |
| Seguridad | Btrfs + snapper | Es lo que CachyOS instala por defecto: un snapshot antes de cada fase. |
| Claude Code | Plan **Pro, Max, Team, Enterprise** o **Console** | El plan gratuito de claude.ai no incluye Claude Code. |
| Red | Internet durante la construcción | Después, todo funciona en local. |

### En un comando

```bash
curl -fsSL https://raw.githubusercontent.com/ayoubtahriouixd/ocarinashell/main/install.sh | bash
```

Ejecútalo **como tu usuario, sin `sudo`**. En unos segundos verás esto (con los datos de tu equipo):

```text
  OcarinaShell  オカリナシェル
  instalador del kit · ayoubtahriouixd/ocarinashell

1 · Tu equipo
  ✓ CachyOS
  ✓ x86_64
  ✓ niri 26.04
  ✓ sesión de niri activa
  ✓ / en Btrfs (snapshots)
  ✓ snapper
  ✓ Limine
  ✓ 31 GB de RAM · 870 GB libres en tu carpeta personal
  ✓ git
  ✓ python3
  ✓ Claude Code 2.1.299

2 · Descarga
    descargando v1.0.0 desde https://github.com/ayoubtahriouixd/ocarinashell.git…
  ✓ kit v1.0.0 en /home/tu-usuario/ocarinashell
    tu trabajo irá en la rama local main; las actualizaciones llegan de «upstream»

3 · Comprobación
  ✓ versión v1.0.0 · 4f1c2ab
    probando la red de seguridad de Claude Code (unos segundos)…
  ✓ hook de guardia: 201/201 ok (126 bloqueos, 75 permitidos)

4 · Opcional: sudo temporal
  ? ¿Activarlo ahora? [s/N]

  Kit de OcarinaShell listo en ~/ocarinashell (v1.0.0)

  Siguiente:
    cd ~/ocarinashell
    claude --permission-mode acceptEdits            # acepta «confiar en esta carpeta»
    /fase 0                                         # dentro de Claude Code
```

<details>
<summary><b>Qué hace exactamente (y qué no)</b></summary>

1. **Comprueba tu equipo**: sistema, niri, Btrfs, snapper, Limine, RAM, espacio, `git`, `python3` y Claude Code. Si
   falta `git` o `python3`, te ofrece instalarlos con pacman. Lo demás solo lo avisa.
2. **Descarga la última versión publicada** con `git` en `~/ocarinashell`. Si ya había algo en esa carpeta, lo mueve a
   `~/ocarinashell.bak-<fecha>`: nunca borra nada.
3. **Deja el repo listo para trabajar**: tu progreso irá en la rama local `main` y las actualizaciones llegarán del
   remoto `upstream`. No queda configurado ningún sitio al que hacer `push`, así que tu progreso no se publica por
   accidente.
4. **Verifica la red de seguridad**: pasa las 201 pruebas del *hook* que impide a Claude Code hacer cosas peligrosas.
5. **Opcional, si lo aceptas**: activa sudo sin contraseña **solo durante la construcción**, para que Claude Code no se
   pare a cada paquete. Lo elimina la fase 17 (o tú, con `sudo rm /etc/sudoers.d/90-ocarinashell-temporal`).

**No** instala paquetes (salvo `git` o `python3` si faltan y le dices que sí), **no** toca `/etc` ni `/boot` y **no**
cambia tu escritorio. Todo eso lo hace Claude Code en las fases, con un snapshot previo.

</details>

<details>
<summary><b>¿Prefieres leerlo antes de ejecutarlo?</b> (recomendable con cualquier <code>curl | bash</code>)</summary>

```bash
curl -fsSLO https://raw.githubusercontent.com/ayoubtahriouixd/ocarinashell/main/install.sh
less install.sh
bash install.sh
```

</details>

<details>
<summary><b>Opciones</b></summary>

```bash
curl -fsSL https://raw.githubusercontent.com/ayoubtahriouixd/ocarinashell/main/install.sh | bash -s -- --check
```

| Opción | Qué hace |
|---|---|
| `--check` | Solo comprueba el equipo: no descarga ni cambia nada. |
| `--version v1.1.0` | Instala una versión concreta (por defecto, la última publicada; `main` = lo más reciente). |
| `--update` | Actualiza un kit ya instalado y fusiona la nueva versión con tu trabajo de las fases. |
| `--sudo-temporal` | Activa el sudo temporal de la construcción sin preguntar. |
| `--no-sudo-temporal` | No pregunta por el sudo temporal. |
| `-y`, `--yes` | Sin preguntas. Nunca activa el sudo temporal por sí solo. |
| `--force` | Continúa aunque el sistema no sea CachyOS/Arch. |
| `--dir <ruta>` | Otra carpeta, solo para pruebas: el kit espera `~/ocarinashell`. |

</details>

<details>
<summary><b>Sin <code>curl</code>: desde la release (zip con suma de comprobación)</b></summary>

Descarga `ocarinashell-kit-v1.1.0.zip` y `SHA256SUMS` de la
[última release](https://github.com/ayoubtahriouixd/ocarinashell/releases/latest). Después:

```bash
cd ~/Descargas            # o ~/Downloads
sha256sum -c SHA256SUMS --ignore-missing
unzip ocarinashell-kit-v1.1.0.zip -d ~
cd ~/ocarinashell && git init -q -b main && git add -A && git commit -qm "kit v1.1.0"
```

El último paso inicializa git, porque las fases guardan su progreso con commits. Con el zip no hay `--update`: las
versiones nuevas se descargan a mano (o instala con `curl` y las tendrás con un comando).

</details>

### Si aún no tienes Claude Code

```bash
curl -fsSL https://claude.ai/install.sh | bash   # instalador oficial
claude --version                                 # en una terminal nueva
```

La primera vez que ejecutes `claude` te pedirá iniciar sesión en el navegador. Más detalles en la
[documentación oficial](https://code.claude.com/docs/en/setup).

<a id="empezar"></a>
## 始 Primeros pasos: construir tu escritorio

1. **Abre Claude Code en la carpeta del kit** y acepta «confiar en esta carpeta» (eso activa los permisos y los *hooks*
   del proyecto):
   ```bash
   cd ~/ocarinashell
   claude --permission-mode acceptEdits
   ```
   Elige con `/model` el modelo más capaz de tu plan.
2. Escribe **`/fase 0`**. Claude Code examina el equipo, crea el primer snapshot, te hace unas preguntas (escala, tema,
   navegador, huella…) e instala la base.
3. Sigue con **`/fase 1`**, **`/fase 2`**… hasta la **17**, una por sesión. Al final de cada fase te dice qué probar:
   pruébalo y dale tu opinión antes de seguir. Si la sesión se alarga, `/compact`. Para retomar: `claude --continue`.

<details>
<summary><b>Modo autónomo</b> (más rápido, solo si vas a estar pendiente)</summary>

`claude --dangerously-skip-permissions` no pide confirmaciones. Siguen activas las capas que no dependen de
preguntarte: el *hook* de guardia (bloquea arranque, sudoers, PAM, snapshots, copias de seguridad, discos y apagar o
matar la sesión, y por DDC/CI solo deja tocar el brillo y el contraste de los monitores), las reglas `deny` de
`.claude/settings.json` y los snapshots. Ninguna red de seguridad es perfecta: con el sudo temporal activo, en este modo
Claude Code instala y configura sin pedirte nada.

</details>

### Comandos del proyecto (dentro de Claude Code)

| Comando | Para qué |
|---|---|
| `/fase N` | Ejecuta o retoma la fase N. |
| `/estado` | Qué está hecho, qué falta y cuál es el siguiente paso. |
| `/pulir <componente>` | Pulido visual contra el mockup (isla, barra, kagi, fune, limine…). |
| `/auditar rendimiento·visual·qml` | Revisión independiente con agentes especializados. |
| `/actualizar` | Actualización guiada a mano (normalmente la hace Mamori). |
| `/actualizar-kit` | Trae una versión nueva del kit y la fusiona con tu progreso. |
| `/mantener` | Lo que ejecuta Mamori en segundo plano, ahora y completo. |
| `/rescate <problema>` | Diagnóstico y recuperación. |

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
| **蛇 Snake** · **守 Mamori** | IA local gratuita y mantenimiento autónomo con snapshot, pruebas y reversión. |
| **Terminal y editor** | Ghostty, fish, starship y Neovim con el mismo diseño. |
| **Arranque** | Limine + Plymouth animado + despedida enlazada: nunca se ve una consola. |

Y [13 ideas extra](docs/07-IDEAS.md), todas desactivables: cuidado del OLED, organizar pantallas y brillo por monitor,
copias de seguridad reales, restaurar la sesión, SSH de producción marcado en rojo, cuentagotas con colores japoneses,
modo foco, leer y traducir japonés de la pantalla, kaomoji, gestos táctiles y más.

<a id="fases"></a>
## 段 Las 18 fases

| # | Fase | Qué obtienes |
|:---:|---|---|
| 0 | Reconocimiento y cimientos | Inventario del hardware, snapshot, entrevista, paru optimizado, paquetes y fuentes. |
| 1 | niri | Tus atajos adaptados, el cursor sigue a las ventanas, animaciones de tinta. |
| 2 | Identidad | Motor de temas: niri, GTK, Qt, terminal y editor con un solo comando. |
| 3 | Núcleo de la shell | Barra Obi, isla Shima, fondos con transición de tinta, IPC y modo seguro. |
| 4 | Centro de control y avisos | Engawa, notificaciones propias y calendario con las 72 microestaciones. |
| 5 | Herramientas | Lanzador Torii, portapapeles, notas, monitor, reglas de ventana y chuleta. |
| 6 | Bloqueo y energía | Bloqueo que «suena», inactividad, energía, polkit y greeter. |
| 7 | Ajustes | App de ajustes completa, pantallas y explorador de fondos. |
| 8 | Terminal | Ghostty, fish, starship y CLI con el diseño. |
| 9 | Neovim | Editor propio, rápido, con barra de estado en kanji. |
| 10 | 忍 Shinobi | Ahorro extremo de batería, medido. |
| 11 | 鬼 Oni · 滑 Nameraka | Rendimiento extremo y juegos; vídeo fluido en todo el sistema (esta parte, `/fase 11b`, puede adelantarse). |
| 12 | 船 Fune | Apps de Windows como ventanas nativas, y Wine/Proton sin sobrecoste. |
| 13 | Arranque y apagado | Limine + Plymouth animado + despedida enlazada. |
| 14 | Blindaje | Modo seguro, pruebas de humo, reversión automática, simulacros y copias de seguridad. |
| 15 | 蛇 Snake | IA local gratuita y privada: cerebro de Mamori y asistente sin conexión. |
| 16 | 守 Mamori | Piloto automático: se actualiza, investiga, se adapta y se repara solo. |
| 17 | Pulido final | QA visual y de rendimiento independiente, limpieza y v1.0 de tu sistema. |

<a id="seguridad"></a>
## 安 Seguridad: por qué no se va a romper

- **Snapshot de snapper antes de cada fase**, arrancables desde Limine, y kernel LTS de respaldo.
- **Hook de guardia** ([`scripts/hooks/guard.py`](scripts/hooks/guard.py), 201 pruebas): Claude Code no puede borrar
  discos ni copias de seguridad, matar la sesión, reiniciar, tocar `/boot`, PAM o sudoers, quitar paquetes críticos
  ni borrar el disco de Windows.
- **Lo del arranque lo ejecutas tú**: `/boot`, initramfs y kernel van en scripts revisables, y Limine se prueba antes en
  QEMU.
- **La shell se recupera sola**: si falla en bucle arranca un modo seguro, y las teclas esenciales tienen respaldo.
- **Mamori nunca actualiza sin snapshot ni sin pruebas**, y revierte solo. El sudo temporal desaparece en la fase 17.
- Recuperación paso a paso: [`docs/05-RESCATE.md`](docs/05-RESCATE.md).

## 守 Mantenimiento: ninguno

Cuando termines la fase 16, el sistema se cuida solo. Cada día, con el cargador puesto y sin molestarte, revisa su
salud, lee las noticias de Arch y CachyOS y los changelogs, actualiza con snapshot, pasa las pruebas, se adapta si algo
cambió y, si algo falla, vuelve atrás. Su cerebro es **蛇 Snake**, una IA local gratuita: sin nube ni suscripciones.
Tú solo ves un resumen semanal y, muy de vez en cuando, un aviso que de verdad te necesita (BIOS, reinicio de
seguridad). Detalles en [`docs/06-ACTUALIZACIONES.md`](docs/06-ACTUALIZACIONES.md).

## 更 Actualizar y desinstalar

```bash
curl -fsSL https://raw.githubusercontent.com/ayoubtahriouixd/ocarinashell/main/install.sh | bash -s -- --update
```

Trae la última versión del kit y la fusiona con tu progreso de las fases (con el instalador más reciente; también vale
`bash ~/ocarinashell/install.sh --update`). Si algo choca con cambios tuyos, no toca nada y te dice qué pedirle a Claude
Code; desde la 1.1.0, dentro de Claude Code basta con `/actualizar-kit`. Lo nuevo de cada versión, en
[`CHANGELOG.md`](CHANGELOG.md).

- **Antes de empezar las fases**, desinstalar es borrar la carpeta: `rm -rf ~/ocarinashell`.
- **Con fases hechas**: `bash ~/ocarinashell/scripts/install.sh --uninstall` (restaura tus ficheros originales),
  `bash ~/ocarinashell/scripts/install-system.sh --uninstall` (ficheros de sistema) y, si quieres volver al punto de
  partida exacto, el snapshot «antes de fase 0». Paso a paso en [`docs/05-RESCATE.md`](docs/05-RESCATE.md).

<a id="preguntas"></a>
## 問 Preguntas frecuentes

<details>
<summary><b>¿Funciona en otro portátil o en un PC?</b></summary>

Sí. Los mockups son del panel del P14s (2880×1800 a escala 1,75), pero la fase 0 inventaría tu hardware y las fases
adaptan medidas, escala, sensores y teclas. Lo específico de ese modelo (umbral de carga, luz de teclado, NPU) se
detecta y, si no existe, se oculta.

</details>

<details>
<summary><b>¿Cuánto cuesta?</b></summary>

El kit es gratis. Construirlo necesita Claude Code (plan de pago de Anthropic). Una vez construido, el sistema se
mantiene con Snake, que es gratis y local; Claude Code queda como extra opcional.

</details>

<details>
<summary><b>¿Qué datos salen de mi equipo?</b></summary>

Ninguna telemetría. Solo hay red para paquetes y actualizaciones, el tiempo (Open-Meteo) y lo que tú actives (fondos de
Wallhaven, el destino de tus copias). Snake, la lectura y traducción de pantalla y el resto de la IA local funcionan sin
conexión.

</details>

<details>
<summary><b>¿Fluido funciona con YouTube, Netflix o cualquier vídeo?</b></summary>

Con cualquier app que muestre el vídeo a **pantalla completa**: Chrome, Firefox, mpv, apps Electron… Como Lossless
Scaling en Windows, captura la ventana, genera los fotogramas intermedios y los presenta encima, a los Hz de tu
pantalla; el ratón y el teclado siguen yendo al vídeo. «A medida 120» lleva un vídeo de 24 fps a 120 (×5) y uno de 30 a
120 (×4). Añade la latencia de un fotograma, que se compensa retrasando igual el audio. El vídeo con DRM debería
funcionar porque en Linux el navegador lo compone como cualquier otro, pero la fase 11 lo comprueba antes de
prometerlo.

</details>

<details>
<summary><b>¿Necesito Lossless Scaling para el vídeo fluido?</b></summary>

Para el motor recomendado, sí: [Lossless Scaling](https://store.steampowered.com/app/993090/Lossless_Scaling/) en
Steam (rama `lsfg-vk`), que en Linux se usa con [lsfg-vk](https://lsfg-vk.dev). Es el que mejor rinde en una iGPU. Sin
él queda una alternativa libre con IA (RIFE), solo hasta donde la aguante tu GPU; la fase 11 lo mide.

</details>

<details>
<summary><b>¿Puedo guardar mi progreso en GitHub?</b></summary>

Sí, y conviene, pero en un repositorio **privado**, porque las fases guardan capturas y ajustes de tu equipo:

```bash
cd ~/ocarinashell
git remote add origin git@github.com:<tu-usuario>/<repo-privado>.git
git push -u origin main
```

</details>

<details>
<summary><b>El instalador dice «No se pudo descargar»</b></summary>

Comprueba la conexión y que la versión existe (`--version vX.Y.Z`, con la `v`). Si el repositorio fuera privado,
`curl` y `git` necesitarían credenciales: este instalador está pensado para un repositorio público.

</details>

<details>
<summary><b><code>claude: command not found</code> después de instalarlo</b></summary>

Abre una terminal nueva: el instalador oficial deja `claude` en `~/.local/bin`. Si aún no aparece, sigue la guía
[Fix your PATH](https://code.claude.com/docs/en/troubleshoot-install).

</details>

<details>
<summary><b>Algo se ha roto</b></summary>

No te preocupes: hay un snapshot de antes de cada fase y el modo seguro de la shell. En Claude Code escribe
`/rescate <qué pasa>`. A mano, sigue [`docs/05-RESCATE.md`](docs/05-RESCATE.md). Si no arranca, elige en Limine el
snapshot anterior o el kernel LTS.

</details>

## 構 Estructura

```
install.sh          instalador del kit (curl … | bash)
CLAUDE.md           memoria del proyecto para Claude Code (reglas de oro)
.claude/            permisos, hooks, skills (/fase, /estado, /pulir, /rescate, /actualizar-kit…) y agentes
docs/               visión, arquitectura, diseño, rendimiento, rescate, ideas y fases 00–17
assets/logo/        logo: SVG estáticos y animados, PNG y componente QML verificado
assets/mockups/     13 pantallas objetivo a 2880×1800 + su fuente HTML/CSS
assets/boot/        temas de Limine (probado en QEMU) y Plymouth (probado en plymouthd)
assets/wallpapers/  6 fondos originales
assets/sounds/      6 sonidos originales tipo ocarina
assets/data/        temas, 72 microestaciones, proverbios, glosario kanji y kaomoji
reference/          atajos de partida y adaptados · paru.conf y makepkg.conf optimizados
scripts/            hooks, captura y comparación de pantalla, medición de batería
tools/              generadores de todos los assets y de las imágenes de este README
tests/              datos falsos para pruebas (config SSH ficticia)
```

## 礼 Créditos

- El arte, el logo, los fondos y los sonidos son **originales** y se regeneran con [`tools/`](tools/README.md).
- Las fuentes (Geist, Unbounded, JetBrains Mono, Zen Kaku Gothic New, Shippori Mincho B1, Yuji Syuku y Material Symbols,
  con licencia OFL o Apache) se descargan en la fase 0; no se incluyen aquí.
- Construido sobre [niri](https://github.com/YaLTeR/niri), [Quickshell](https://quickshell.org) y
  [CachyOS](https://cachyos.org). OcarinaShell se escribe desde cero: no copia código de otras shells.
- El vídeo fluido usa [lsfg-vk](https://lsfg-vk.dev) (CC BY-NC-ND) con tu copia de
  [Lossless Scaling](https://store.steampowered.com/app/993090/Lossless_Scaling/): el kit los instala y configura, nunca
  los copia ni los modifica.
- Diseñado y especificado con [Claude Code](https://code.claude.com/docs/en/overview).

---

<details>
<summary><b>In English</b></summary>

OcarinaShell is a **build kit** for a complete Japanese-styled desktop on **CachyOS + niri + Quickshell**. It is not a
dotfiles dump. It ships the full spec (architecture, pixel-exact mockups, 18 phases with acceptance criteria), original
assets (animated logo, wallpapers, ocarina UI sounds, Limine and Plymouth themes tested for real) and safety nets: a
snapshot before every phase, a command guard with 201 tests, a safe mode and automatic rollback. Since 1.1 it also
specifies system-wide frame generation for any full-screen video (Lossless Scaling's LSFG through lsfg-vk, ×2 · ×4 · ×6
or a custom fps target). Claude Code then builds the desktop on your machine, phase by phase. Install the kit with
`curl -fsSL https://raw.githubusercontent.com/ayoubtahriouixd/ocarinashell/main/install.sh | bash`, then run
`claude --permission-mode acceptEdits` in `~/ocarinashell` and type `/fase 0`. Docs are in Spanish.

</details>

<p align="center"><img src="assets/logo/svg/ocarinashell-seal.svg" alt="殻" width="36"></p>
