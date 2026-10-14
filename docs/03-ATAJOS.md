# 03 · Atajos y comportamiento del ratón

Base: los binds que Ayoub usaba con DankMaterialShell (`reference/binds-dms-original.kdl`). Borrador adaptado y
verificado sintácticamente: `reference/binds-ocarina.kdl` (conserva los 134 originales, adaptados, y añade 17).
La fase 1 lo instala como `config/niri/ocarina/binds.kdl` tras ajustar keysyms a la distribución real.

## Equivalencias DMS → OcarinaShell
| Atajo | Antes (`dms ipc call …`) | Ahora (`ocarina …`) → módulo |
|---|---|---|
| Ctrl+Alt+Supr · Mod+M | `processlist focusOrToggle` | `tasks` → 見張り Mihari |
| Ctrl+Shift+R | `workspace-rename open` | `rename-workspace` → edición en la isla ⚠ |
| Ctrl+Vol−/Vol+ | `mpris decrement/increment 3` | `media down/up` (volumen del reproductor) |
| Mod+A | `spotlight toggle` | `launcher` → 鳥居 Torii |
| Mod+Alt+L | `lock lock` | `lock` → 鍵 Kagi |
| Mod+Coma | `settings focusOrToggle` | `settings` → 設定 Settei |
| Mod+N | `notepad toggle` | `notes` → 手帳 Techō |
| Mod+Shift+N | `notifications toggle` | `notifications` → 文 Fumi |
| Mod+Shift+W | `dankdash wallpaper` | `wallpaper browse` → 壁紙 Kabegami |
| Mod+Shift+Y | `window-rules toggle` | `rules` → 窓 Mado |
| Mod+V | `clipboard toggle` | `clipboard` → 蔵 Kura |
| Super+X | `powermenu toggle` | `power` → 電源 Dengen |
| Teclas multimedia / brillo | `audio …` · `mpris …` · `brightness …` | `audio …` · `media …` · `brightness …` (con OSD en la isla; el brillo va a la pantalla con el foco —ajustable en Settei → Pantalla— y el OSD dice cuál) |
| Mod+T · Mod+E | `alacritty` · `alacritty -e yazi` | Ghostty (ventana nueva instantánea) · Ghostty + yazi |
| Mod+B · Mod+Shift+E | Chrome · Nautilus | igual |
| Resto (espacios, columnas, monitores, capturas, overview…) | acciones nativas de niri | **sin cambios** |

⚠ Ctrl+Shift+R lo captura niri en todo el sistema: deja de funcionar la «recarga forzada» del navegador.
Se mantiene porque era tu atajo; si molesta, propón Mod+Shift+Ctrl+R (pregúntale a Ayoub en la fase 1).

## Nuevos (sin conflictos)
| Atajo | Acción |
|---|---|
| Mod+Shift+C | Centro de control (縁側 Engawa) |
| Mod+Alt+S | 忍 Shinobi on/off |
| Mod+Alt+O | 鬼 Oni on/off (rendimiento extremo) |
| Mod+Alt+W | 船 Fune: panel de apps de Windows |
| Mod+Shift+A | 蛇 Snake: asistente de IA local (Mod+A sigue siendo el lanzador) |
| Mod+Alt+R | Grabar pantalla (録) |
| Mod+` (en teclado ES: tecla `º`, keysym `masculine`) | Terminal desplegable (Ghostty quick terminal) |
| Impr Pant | Captura de región (UI nativa de niri) |
| Mayús + teclas de brillo | Brillo de todas las pantallas a la vez (cada una en su escala) |
| Mod+Alt+P | 色 Iro: cuentagotas con el color tradicional japonés más cercano (07-IDEAS) |
| Mod+Alt+T | 読 Yomu: leer el texto de una zona y traducirlo con Snake (07-IDEAS) |
| Mod+Alt+F | 滑 Fluido on/off: genera fotogramas en el vídeo a pantalla completa (Nameraka, fase 11) |
| Mod+Alt+Shift+F | 滑 Fluido: siguiente modo (×2 → ×4 → ×6 → A medida) |
| Botón de encendido | Menú Dengen (con `input { disable-power-key-handling }`) |
| ★ (XF86Favorites, ThinkPad) | Centro de control — verificar keysym |
| Mod+Shift+/ | Chuleta de atajos de OcarinaShell (antes: overlay nativo) · el nativo pasa a Mod+Ctrl+/ |
| Alt+Tab · Alt+Shift+Tab · Alt+` | Conmutador nativo de niri (recent-windows); Mod+Tab sigue siendo la vista general |

## Ratón: «el cursor sigue a las ventanas»
```kdl
input {
    focus-follows-mouse max-scroll-amount="0%"   // pasar el ratón por una ventana la enfoca, sin desplazar la vista
    warp-mouse-to-focus                          // y al enfocar con teclado, el cursor salta a la ventana
}
```
Con ambos, ratón y teclado nunca se contradicen. `max-scroll-amount="0%"` evita que rozar una columna medio
visible desplace toda la tira (molesto en el layout de scroll). Si Ayoub prefiere que también enfoque las
parcialmente visibles, subir a `"25%"`. `warp-mouse-to-focus mode="center-xy"` centra el cursor (opcional).
Ojo: el conmutador recent-windows ignora ventanas por las que solo se pasa (debounce 750 ms), así que el
foco por ratón no ensucia el Alt+Tab.

## Comprobación de keysyms (fase 1)
- Distribución: `localectl status` y la sección `input.keyboard.xkb` de niri. Para cada tecla dudosa de los binds
  (Equal, Minus, BracketLeft/Right, Comma, Period, Slash, grave), calcula el keysym real con
  `xkbcli compile-keymap --layout <xx>` / `xkbcli how-to-type` o pide a Ayoub que las pulse con `wev` abierto.
  Decide junto a Ayoub qué teclas físicas quiere y documenta el resultado aquí.
  Pistas para teclado **ES** (compruébalas, no las des por buenas): las posiciones físicas US de `[` `]` son
  `dead_grave` y `plus`; `=` solo existe con Shift (posición US de `=` es `exclamdown`); la posición US de `/` es
  `minus`; la de `'` es `dead_acute`; la de `` ` `` es `masculine`. Mantén la **posición física** que Ayoub usaba
  y cambia solo el keysym.
- Fila Fn del ThinkPad (F7–F12): pide a Ayoub pulsarlas con `wev` y anota keysyms.
