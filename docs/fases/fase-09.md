# Fase 09 · Neovim

**Objetivo**: un Neovim propio, precioso y rápido (< 30 ms): el del mockup 01 (mitad derecha), con dashboard que
muestra la ocarina de verdad, statusline con modos en kanji y tema generado.
**Lee antes**: mockup 01, `assets/data/kanji-ui.json` (`nvimModes`), `nvim --version` (adapta APIs: `vim.lsp.config`,
`vim.pack` si es 0.12+ — aun así usa lazy.nvim por su carga diferida).

## Tareas
1. **Snapshot**; mueve cualquier `~/.config/nvim` previo a copia.
2. **Estructura** `config/nvim/`: `init.lua`, `lua/ocarina/{options,keymaps,autocmds,lazy,statusline,winbar}.lua`,
   `lua/plugins/*.lua`, `colors/ocarina.lua`. Líder = Espacio. Opciones sensatas (números relativos con el actual en
   absoluto, `signcolumn`, `scrolloff`, `undofile`, portapapeles del sistema, `splitkeep=screen`, sin `swapfile`).
3. **Colorscheme `ocarina`**: lee `~/.local/state/ocarinashell/nvim/palette.lua` (motor de temas) y define ~300 grupos:
   básicos, treesitter (`@keyword` rojo, `@type` oro, `@string` verde, `@function` azul, `@comment` tenue en cursiva…
   como el mockup), LSP semántico, diagnósticos, diff/gitsigns, picker, completado, which-key, notificaciones.
   Recarga en caliente con `vim.uv.new_fs_event` sobre el fichero de paleta.
4. **Plugins** (todo perezoso): lazy.nvim; snacks.nvim (dashboard, picker, explorer, notifier, indent, scroll, zen,
   lazygit, words); blink.cmp; nvim-lspconfig + mason (lua_ls, basedpyright o pyright, vtsls/ts_ls, bashls, jsonls,
   yamlls, marksman, taplo; **qmlls** del sistema para editar OcarinaShell); nvim-treesitter (lua, python, bash, fish,
   json, yaml, toml, markdown, qmljs, kdl, glsl, javascript, typescript, css, html, regex, vim, vimdoc); conform
   (stylua, ruff, prettierd, shfmt, qmlformat); gitsigns; which-key (grupos en español con kanji); flash; oil.nvim;
   mini.ai/surround/pairs; todo-comments; trouble; persistence; smear-cursor (solo con CA y fuera de Shinobi).
   Opcional: autocompletado/explicación con **Snake** (fase 15) mediante un plugin que hable con un endpoint
   OpenAI-compatible local, desactivado por defecto y nunca en Shinobi.
5. **Dashboard** (snacks): la ocarina PNG real por protocolo kitty en Ghostty (fallback: arte en braille), «OcarinaShell»
   + オカリナ・シェル, proverbio del día, 七十二候 actual, archivos recientes, proyectos, tiempo de arranque.
6. **Statusline propia** (sin lualine si puedes; es más ligera): modo en bloque rojo con kanji (常 NORMAL, 挿 INSERT,
   視 VISUAL, 行 V-LINE, 塊 V-BLOCK, 換 REPLACE, 令 COMMAND, 端 TERMINAL), rama `枝`, diff, nombre con icono,
   diagnósticos, LSP activo, codificación, posición. **Winbar** con migas de pan (símbolos LSP).
7. **Shinobi**: vigila `~/.local/state/ocarinashell/mode` → desactiva smear-cursor, scroll suave y animaciones de snacks.
8. **Mantenible por Mamori**: `lazy-lock.json` en git y un comando headless de salud (`nvim --headless "+Lazy! sync" …` en
   una rama de prueba + `:checkhealth` sin errores + tiempo de arranque) que la fase 16 usará para actualizar plugins solo.

## Criterios de aceptación
- [ ] Captura ≈ mitad derecha del mockup 01 (editando `shell/modules/obi/Obi.qml`).
- [ ] `nvim --startuptime` < 30 ms; `:checkhealth` sin errores; LSP de QML/Lua/Python funcionando.
- [ ] Cambio de tema y Shinobi se reflejan en caliente.

## Al terminar
PROGRESS.md (tiempo de arranque), commit; chuleta breve para Ayoub (10 atajos esenciales con `<leader>`).
