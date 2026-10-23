# 03 · Atajos y comportamiento del ratón

Fuente: `config/niri/ocarina/binds.kdl` (y el conmutador Alt+Tab en `recent-windows.kdl`). Parte de los binds que
Ayoub usaba con DankMaterialShell (`reference/binds-dms-original.kdl`), adaptados al teclado español (D-021).
`Mod` = Super. Todo lo de la shell pasa por el CLI `ocarina`, que tiene respaldo si la shell no responde.
**Super+?** abre la chuleta con todos, y en **Ajustes › 技 Atajos** se cambian (ver abajo).

## Equivalencias DMS → OcarinaShell
| Atajo | Antes (`dms ipc call …`) | Ahora (`ocarina …`) → módulo |
|---|---|---|
| Ctrl+Alt+Supr · Mod+M | `processlist focusOrToggle` | `tasks` → 見張り Mihari |
| Mod+Ctrl+Mayús+R | `workspace-rename open` (era Ctrl+Mayús+R) | `rename-workspace` → edición en la isla |
| Ctrl+Vol−/Vol+ | `mpris decrement/increment 3` | `media down/up` (volumen del reproductor) |
| Mod+A | `spotlight toggle` | `launcher` → 鳥居 Torii |
| Mod+Alt+L | `lock lock` | `lock` → 鍵 Kagi |
| Mod+Coma | `settings focusOrToggle` | `settings` → 設定 Settei |
| Mod+N | `notepad toggle` | `notes` → 手帳 Techō |
| Mod+Mayús+N | `notifications toggle` | `notifications` → 文 Fumi |
| Mod+Mayús+W | `dankdash wallpaper` | `wallpaper browse` → 壁紙 Kabegami (Ajustes → Fondos) |
| Mod+Mayús+Y | `window-rules toggle` | `rules` → 窓 Mado |
| Mod+V | `clipboard toggle` | `clipboard` → 蔵 Kura |
| Super+X | `powermenu toggle` | `power` → 電源 Dengen |
| Teclas multimedia, micro y brillo | `audio …` · `mpris …` · `brightness …` | `audio …` · `media …` · `brightness …` (con OSD en la isla; funcionan con la pantalla bloqueada; el brillo va a la pantalla con el foco —ajustable en Settei → Pantalla— y el OSD dice cuál) |
| Mod+T · Mod+E | `alacritty` · `alacritty -e yazi` | Ghostty (ventana nueva instantánea, 67 ms) · Ghostty + yazi |
| Mod+B · Mod+Mayús+E | Chrome · Nautilus | igual |

Ctrl+Mayús+R se movió a Mod+Ctrl+Mayús+R para no robarle al navegador la «recarga forzada».

## Propios de OcarinaShell
| Atajo | Acción |
|---|---|
| Mod+Mayús+C | 縁側 Engawa, el centro de control |
| Mod+D | 器 Cajón de apps de la ocarina (`ocarina apps`; sin la shell abre Torii) |
| Mod+Alt+S | 忍 Shinobi on/off (ahorro extremo) |
| Mod+Alt+O | 鬼 Oni on/off (rendimiento extremo) |
| Mod+Alt+F | 滑 Nameraka on/off: genera fotogramas en el vídeo a pantalla completa |
| Mod+Alt+Mayús+F | 滑 Nameraka: siguiente modo (×2 → ×4 → ×6 → A medida) |
| Mod+Alt+W | 船 Fune: panel de apps de Windows |
| Mod+Mayús+A | 蛇 Snake: asistente de IA local (Mod+A sigue siendo el lanzador) |
| Mod+Alt+A | 声 Snake por voz: escucha hasta una pausa y pregunta (whisper.cpp local; otra vez = parar). Dentro del panel: el micro o Ctrl+Espacio |
| Mod+Alt+R | 録 Grabar pantalla |
| Mod+º (keysym `masculine`) | 端 Terminal desplegable (Ghostty quick terminal) |
| Mod+Alt+P | 色 Iro: cuentagotas con el color tradicional japonés más cercano (07-IDEAS) |
| Mod+Alt+T | 読 Yomu: leer el texto de una zona y traducirlo con Snake (07-IDEAS) |
| Mayús + teclas de brillo | Brillo de todas las pantallas a la vez (cada una en su escala) |
| Botón de encendido | Menú Dengen (`input { disable-power-key-handling }`); con la pantalla bloqueada, suspende |
| ★ (`XF86Favorites`, ThinkPad) | Engawa, si tu teclado emite ese keysym (compruébalo con `wev`) |
| Mod+? (Mayús + `'`) | Chuleta de atajos de OcarinaShell · Mod+Ctrl+`'`: la nativa de niri |
| Alt+Tab · Alt+Mayús+Tab | Conmutador nativo de niri (recent-windows) |
| Alt+º · Alt+Mayús+º | El mismo conmutador, solo ventanas de la app actual |
| Mod+Tab | Vista general |
| Mod+F | Maximizar la columna (`ocarina maximize`: con apps de Windows de Fune maximiza también dentro de Windows) |

## Nativos de niri
**Espacios** (numerales kanji en la barra)
| Atajo | Acción |
|---|---|
| Mod+1…9 · Mod+Mayús+1…9 | Ir al espacio n · llevar la columna al espacio n |
| Mod+U / Mod+I (o Mod+AvPág / Mod+RePág) | Espacio de abajo / de arriba |
| Mod+Ctrl+U / Mod+Ctrl+I (o Mod+Ctrl+↓ / ↑, Mod+Ctrl+rueda) | Llevar la columna al espacio de abajo / de arriba |
| Mod+Mayús+U / Mod+Mayús+I (o Mod+Mayús+AvPág / RePág) | Mover el espacio entero abajo / arriba |

**Foco**
| Atajo | Acción |
|---|---|
| Mod+H / Mod+L (o ← / →, Mod+rueda, Mod+Mayús+rueda) | Columna a la izquierda / derecha |
| Mod+J / Mod+K (o ↓ / ↑) | Ventana de abajo / de arriba en la columna |
| Mod+Inicio / Mod+Fin | Primera / última columna |
| Mod+Ctrl+H/J/K/L (o Mod+Ctrl+← / →) | Otra pantalla |
| Mod+Mayús+V | Alternar entre flotantes y mosaico |

**Mover**
| Atajo | Acción |
|---|---|
| Mod+Mayús+H / L (o ← / →) | Columna a la izquierda / derecha (también Mod+Ctrl+rueda horizontal y Mod+Ctrl+Mayús+rueda) |
| Mod+Mayús+J / K (o ↓ / ↑) | Ventana abajo / arriba en la columna |
| Mod+Ctrl+Inicio / Fin | Columna al principio / al final |
| Mod+Ctrl+Mayús+H/J/K/L (o flechas) | Columna a otra pantalla |
| Mod+` / Mod+´ (teclas a la derecha de P y de Ñ) | Meter o sacar la ventana de la columna de la izquierda / derecha |
| Mod+. | Sacar la ventana de su columna |

**Tamaño y disposición**
| Atajo | Acción |
|---|---|
| Mod+R · Mod+Mayús+R · Mod+Ctrl+R | Anchos predefinidos · altos predefinidos · alto automático |
| Mod++ / Mod+- | Columna un 10 % más ancha / estrecha |
| Mod+Mayús++ / Mod+Mayús+- | Ventana un 10 % más alta / baja |
| Mod+Ctrl+F · Mod+Mayús+F | Ocupar el ancho libre · pantalla completa |
| Mod+C · Mod+Ctrl+C | Centrar la columna · centrar las columnas visibles |
| Mod+Mayús+T · Mod+Y | Ventana flotante · columna en pestañas |
| Mod+Q | Cerrar la ventana |

**Capturas y sistema**
| Atajo | Acción |
|---|---|
| Impr Pant · Mod+S · `XF86Launch1` | Captura de región (interfaz de niri) |
| Ctrl+Impr Pant · Ctrl+`XF86Launch1` | Captura de la pantalla |
| Alt+Impr Pant · Mod+Mayús+S | Captura de la ventana |
| Mod+P | Apagar las pantallas |
| Mod+Esc | Dejar pasar los atajos a la app (p. ej. una VM); otra vez para recuperarlos |
| Mod+Mayús+P | Salir de niri (pide confirmación) |

## 技 Cambiar atajos (Ajustes › Atajos)
La página enseña los mismos atajos que la chuleta, y el lápiz de cada fila abre un editor (chips de modificadores + la
tecla principal). `bin/ocarina-binds` guarda tus cambios en `~/.config/ocarinashell/binds.json` y genera el include
`~/.local/state/ocarinashell/niri/user-binds.kdl`, que niri lee después de `binds.kdl` (gana la última definición). Solo
se pueden asignar acciones que ya existen en `binds.kdl`; el include se valida (contenido + `niri validate`) antes de
instalarse y, si la config entera no pasa, vuelve el anterior. Una combinación ocupada pide confirmación y deja sin
tecla al otro atajo. Desde la terminal: `ocarina-binds list` (los cambiados llevan `*`) · `set <teclas> <nuevas>` ·
`disable <teclas>` · `reset <teclas>` · `reset-all`. Si algo se tuerce: 05-RESCATE.

## Ratón: «el cursor sigue a las ventanas»
```kdl
input {
    focus-follows-mouse max-scroll-amount="0%"   // pasar el ratón por una ventana la enfoca, sin desplazar la vista
    warp-mouse-to-focus                          // y al enfocar con teclado, el cursor salta a la ventana
}
```
Con ambos, ratón y teclado nunca se contradicen. `max-scroll-amount="0%"` evita que rozar una columna medio
visible desplace toda la tira (molesto en el layout de scroll). Los dos se activan y desactivan en Settei → Teclado y
ratón (viven en el include generado `overrides.kdl`, D-046). El conmutador recent-windows ignora ventanas por las que
solo se pasa (debounce 750 ms), así que el foco por ratón no ensucia el Alt+Tab.

## Teclado español (D-021)
niri compara el keysym de la tecla sin Mayús, así que los keysyms US se cambiaron conservando la posición física:
| Acción | Tecla física | Keysym en `binds.kdl` |
|---|---|---|
| Columna ±10 % | `-` (junto a Mayús dcha.) · `+` (junto a Intro) | `Mod+minus` · `Mod+plus` |
| Ventana ±10 % de alto | Mayús + las mismas | `Mod+Shift+minus` · `Mod+Shift+plus` |
| Meter/sacar ventana ← → | `` ` `` (dcha. de P) · `´` (dcha. de Ñ) | `Mod+dead_grave` · `Mod+dead_acute` |
| Chuleta de OcarinaShell | `?` (Mayús + `'`) | `Mod+Shift+apostrophe` |
| Atajos nativos de niri | Ctrl + `'` | `Mod+Ctrl+apostrophe` |
| Terminal desplegable | `º` | `Mod+masculine` |
| Conmutador por aplicación | Alt + `º` | `Alt+masculine` (recent-windows) |
| Renombrar espacio | Mod+Ctrl+Mayús+R | `Mod+Ctrl+Shift+R` |

Con otra distribución, comprueba esas teclas con `wev` o `xkbcli how-to-type` y cámbialas en Ajustes › Atajos.

## Ghostty — Ctrl+Mayús para la terminal; Super es de niri
| Atajo | Acción |
|---|---|
| **Mod+º** | 端 Terminal desplegable: aparece arriba; con foco, la vuelve a esconder (sigue viva) |
| **Ctrl+Mayús+T** · Ctrl+Tab · Alt+1…9 · Ctrl+Mayús+W | Pestaña nueva · siguiente · ir a la n · cerrar |
| **Ctrl+Mayús+D** / Ctrl+Mayús+S (también O / E) | Dividir a la derecha / abajo · Ctrl+Mayús+X cierra el panel |
| Ctrl+Alt+flechas · Ctrl+Alt+Mayús+flechas · Ctrl+Alt+= · Ctrl+Mayús+Intro | Moverse entre paneles · redimensionar · igualar · zoom del panel |
| **Ctrl+Mayús+F** · Ctrl+Mayús+G / H · Esc | Buscar en el historial · siguiente / anterior · terminar |
| **Ctrl+Mayús+↑ / ↓** | Saltar al prompt anterior / siguiente (marcas de la integración de fish) |
| Ctrl+Mayús+K · Ctrl+Mayús+P · Ctrl+Mayús+, | Limpiar · paleta de órdenes · recargar la config |
| Ctrl+= / Ctrl+- / Ctrl+0 | Tamaño de letra (solo esa ventana) |
| Selección con el ratón · clic central | Copia a la selección primaria y la pega (Ctrl+Mayús+C/V: portapapeles) |

Ghostty y Neovim son translúcidos con el fondo desenfocado detrás (80 % por defecto); la opacidad se cambia en
Ajustes › Apariencia › Terminal y vuelve a opaca en Shinobi, en Oni o sin transparencias.

fish: Ctrl+R historial (fzf) · Ctrl+T ficheros con vista previa · Alt+C carpetas · `z <trozo>` (zoxide) · `y` (yazi y
quedarse en la carpeta) · `ff` (fastfetch) · `ossh <host>` / `ocarina ssh <host>` (本番 Honban) · `lg` (lazygit) ·
`snake "pregunta"` (蛇, lo que entra por la tubería es contexto).

## Neovim — líder = Espacio; `<leader>` solo, o `<leader>?`, enseña todo (which-key, grupos con kanji)
| Atajo | Acción |
|---|---|
| **␣ ␣** · ␣ , · ␣ / | 探 Buscar archivo (inteligente) · buffers abiertos · buscar texto (grep) |
| **␣ e** · **-** | Explorador lateral · carpeta del archivo como buffer editable (oil) |
| ␣ f r · ␣ f p · ␣ f c | Recientes · proyectos · config de Neovim |
| **gd** · grr · gri · grt · **K** | Definición · referencias · implementaciones · tipo · documentación |
| **␣ c a** (o gra) · ␣ c r (o grn) · **␣ c f** | Acción de código · renombrar · formatear (al guardar: apagado, ␣ u f) |
| ␣ c d · ]d / [d · **␣ x x** | Diagnóstico de la línea · siguiente / anterior · lista del proyecto (trouble) |
| **␣ g g** · ]h / [h · ␣ g h s / r / p | Lazygit · siguiente / anterior cambio · preparar / deshacer / ver el cambio |
| **s** · S | Saltar a cualquier sitio (flash) · seleccionar un nodo de treesitter |
| gsa / gsd / gsr · ai/ii, af/if… | Rodear (añadir / borrar / cambiar) · objetos de texto de mini.ai |
| Mayús+H / Mayús+L · ␣ b d | Buffer anterior / siguiente (las pestañas de arriba) · cerrar buffer |
| Ctrl+h/j/k/l · ␣ - / ␣ \| | Moverse entre ventanas · dividir abajo / a la derecha |
| **␣ q s** · ␣ q l | Restaurar la sesión de esta carpeta · la última |
| ␣ z · ␣ n · Ctrl+/ | Zen · historial de avisos · terminal flotante |
| Ctrl+S · Alt+j/k | Guardar · mover línea o selección |

Statusline: 常 NORMAL · 挿 INSERT · 視 VISUAL · 行 V-LINE · 塊 V-BLOCK · 換 REPLACE · 令 COMMAND · 端 TERMINAL · 選 SELECT;
枝 rama, 新/変/消 líneas añadidas/cambiadas/borradas, 誤 警 報 示 errores/avisos/info/pistas, 録 grabando macro.
