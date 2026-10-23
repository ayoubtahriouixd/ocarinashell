local o = vim.opt

-- numbers: relative, the current one absolute (and in the accent, see colors)
o.number = true
o.relativenumber = true
o.signcolumn = "yes"
-- number first, then the sign: the numbers sit near the edge like the mockup gutter (no Lua, a plain expression)
o.statuscolumn = "%=%{&nu||&rnu?(v:virtnum>0?'':(v:relnum?v:relnum:v:lnum)):''} %s"
o.cursorline = true
o.cursorlineopt = "both"

-- scrolling and windows
o.scrolloff = 8
o.sidescrolloff = 8
o.smoothscroll = true
o.splitkeep = "screen"
o.splitright = true
o.splitbelow = true
o.wrap = false
o.linebreak = true
o.jumpoptions = "view"
o.winborder = "rounded"

-- files
o.undofile = true
o.swapfile = false
o.confirm = true
o.autowrite = true

-- editing
o.expandtab = true
o.shiftwidth = 4
o.tabstop = 4
o.softtabstop = 4
o.shiftround = true
o.smartindent = true
o.ignorecase = true
o.smartcase = true
o.inccommand = "split"
o.virtualedit = "block"
o.updatetime = 250
o.timeoutlen = 400
o.mouse = "a"
o.grepprg = "rg --vimgrep --smart-case"
o.grepformat = "%f:%l:%c:%m"
o.completeopt = "menu,menuone,noselect"

-- looks: one global statusline, tabline with the buffers, no mode text (the statusline shows it in kanji)
o.termguicolors = true
o.laststatus = 3
o.showtabline = 2
o.showmode = false
o.ruler = false
o.pumheight = 12
o.list = true
o.listchars = { tab = "» ", trail = "·", nbsp = "␣" }
o.fillchars = { eob = " ", fold = " ", foldopen = "\u{f078}", foldclose = "\u{f054}", foldsep = " ", diff = "╱" }
o.foldlevel = 99
o.foldtext = ""
o.shortmess:append({ W = true, I = true, c = true, C = true, s = true })
o.title = true
o.titlestring = "nvim · %{expand('%:~:.')}"

-- the clipboard provider probes wl-copy: do it after the first screen, not in the start-up path
vim.schedule(function() o.clipboard = "unnamedplus" end)

-- providers nobody here uses (each one costs a probe)
for _, p in ipairs({ "node", "perl", "python3", "ruby" }) do
  vim.g["loaded_" .. p .. "_provider"] = 0
end
