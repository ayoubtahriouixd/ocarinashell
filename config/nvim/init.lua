-- OcarinaShell · Neovim (docs/historia/fases/fase-09.md). Budget: < 30 ms to the first screen (docs/04-RENDIMIENTO).
-- Everything that is not on screen loads lazily; the colourscheme follows the theme engine and 忍 Shinobi live.
vim.loader.enable()

vim.g.mapleader = " "
vim.g.maplocalleader = "\\"

require("ocarina.options")
require("ocarina.lazy")
vim.cmd.colorscheme("ocarina")
require("ocarina.ui").setup() -- statusline, tabline, breadcrumbs
require("ocarina.keymaps")
require("ocarina.autocmds")
require("ocarina.fx").setup() -- theme/effects watcher (hot reload, Shinobi)
