# Fase 08 · Ghostty, fish, starship y herramientas CLI

**Objetivo**: una terminal que deje boquiabierto y vuele: la del mockup 01 (fastfetch con logo y kanji, prompt de dos
líneas con estado de git en kanji, cursor con estela de tinta).
**Lee antes**: mockup 01 (mitad izquierda), `assets/data/kanji-ui.json` (`gitStatus`), referencia de config de Ghostty
de la versión instalada (ghostty.org/docs/config/reference; `ghostty +show-config --default --docs`).

## Tareas
1. **Snapshot**.
2. **Ghostty** (`config/ghostty/config` + `themes/ocarina` generado en la fase 2 + include opcional de efectos):
   fuente JetBrains Mono (Nerd) con respaldo CJK japonés (varias líneas `font-family`), tamaño ≈12 a escala 1,75 (ajústalo
   con capturas), ligaduras, `window-padding-x 14` / `y 12` + `window-padding-balance`, `window-decoration` acorde a niri
   (sin CSD), `background-opacity 1` (cuando Ghostty soporte `ext-background-effect` se valorará 0,94 + blur),
   `cursor-style bar`, `cursor-style-blink false`, `shell-integration fish` con features cursor/sudo/title,
   `mouse-hide-while-typing`, `confirm-close-surface false`, `copy-on-select` según Ayoub, splits/pestañas con
   atajos coherentes, scrollback search, `notify-on-command-finish = unfocused` + `…-after = 10s` (llega a Fumi),
   **quick terminal** desde arriba (Mod+` → `ocarina quickterm` mediante la vía soportada en Linux para tu versión),
   arranque instantáneo de ventanas (instancia única / servicio D-Bus de Ghostty; mide).
   **Shader de cursor** «estela de tinta» (`shaders/ink-cursor.glsl`, uniforms de cursor de la versión instalada):
   estela corta roja que se desvanece en ~120 ms; `custom-shader-animation` solo con CA; Shinobi lo desactiva
   (fichero de efectos incluido opcionalmente que gestiona el motor de temas).
3. **fish** (`config/fish/conf.d/ocarina.fish`, sin pisar la config de CachyOS): abreviaturas (paru/pacman con
   `yay → paru` para la memoria muscular de Ayoub, git, niri msg, ocarina), `zoxide`, `fzf` (Ctrl+R/Ctrl+T con colores
   del tema y vista previa con bat/eza), `eza` con iconos, `bat` como paginador de man, editor nvim, saludo instantáneo
   (< 5 ms) leído de una caché diaria: saludo por hora (こんばんは, Ayoub) + proverbio del día; `fastfetch` solo con `ff`
   o la primera terminal del día. Función `snake` (fase 15) para preguntar a la IA local desde la terminal.
4. **starship** (`config/starship.toml`): dos líneas como el mockup: `╭─ 寒露 ~/ruta 枝 main 変2 新1 · 0.4s` /
   `╰─❯` (el kanji del 節気 actual sale de la caché diaria), símbolos de git de `gitStatus`, `❯` rojo/gris según el
   último código, prompt transitorio en fish, tiempos < 15 ms (`starship timings`).
5. **fastfetch** (`config/fastfetch/config.jsonc`): logo PNG por protocolo kitty, claves en kanji (機 OS · 核 Kernel ·
   窓 WM · 殻 Shell · 端 Term · 脳 CPU · 絵 GPU · 記 Mem · 電 Bat · 季 Kō) como el mockup, paleta de colores.
6. **Herramientas**: btop (tema), yazi (flavor + previsualización de imágenes en Ghostty + atajos), bat, eza, fzf,
   lazygit (tema), `less`/man con colores.
7. **本番 Honban · SSH sin sustos** (`docs/07-IDEAS.md`): `ocarina ssh <host>` abre Ghostty con título `ssh · <host>`
   (con completado en fish). Producción = lista `ssh.prodHosts` en Ajustes o comentario `# ocarina: prod` dentro de
   su bloque `Host`. Para esos hosts la shell genera una regla de ventana (en su include `honban-rules.kdl`,
   validado; nunca en `user-rules.kdl`, que es de Mado) con anillo rojo sólido sin degradado y borde de 2 px; Obi
   muestra el sello 本番 junto al título y la primera conexión del día lanza un aviso discreto. Solo se leen los
   nombres `Host`: nunca claves ni `known_hosts`.

## Criterios de aceptación
- [ ] Captura de Ghostty ≈ mitad izquierda del mockup 01.
- [ ] Ventana nueva < 80 ms; `fish -i -c exit` < 40 ms; prompt < 15 ms (anota medidas).
- [ ] Quick terminal y aviso de fin de comando funcionando; Shinobi apaga el shader de cursor.
- [ ] Honban: con `tests/ssh_config` (un host marcado `prod`), su ventana sale con anillo rojo sólido y 本番 en Obi; un
      host normal, con el anillo de siempre.

## Al terminar
PROGRESS.md (medidas), commit; enseña a Ayoub los 5 atajos de Ghostty más útiles.
