-- Editor keymaps that need no plugin. Plugin keys live in their spec (lua/plugins/*.lua) so lazy.nvim loads them
-- on first use; which-key shows everything under <leader> with Spanish names and kanji (lua/plugins/editor.lua).
local map = vim.keymap.set

map("n", "<Esc>", "<cmd>nohlsearch<cr><Esc>", { desc = "Quitar resaltado de búsqueda" })
map({ "n", "i", "x", "s" }, "<C-s>", "<cmd>write<cr><Esc>", { desc = "Guardar" })

-- windows
map("n", "<C-h>", "<C-w>h", { desc = "Ventana izquierda" })
map("n", "<C-j>", "<C-w>j", { desc = "Ventana de abajo" })
map("n", "<C-k>", "<C-w>k", { desc = "Ventana de arriba" })
map("n", "<C-l>", "<C-w>l", { desc = "Ventana derecha" })
map("n", "<leader>-", "<C-w>s", { desc = "Dividir abajo" })
map("n", "<leader>|", "<C-w>v", { desc = "Dividir a la derecha" })
map("n", "<leader>wd", "<C-w>c", { desc = "Cerrar ventana" })
map("n", "<leader>wo", "<C-w>o", { desc = "Solo esta ventana" })
map("n", "<C-Up>", "<cmd>resize +2<cr>", { desc = "Más alta" })
map("n", "<C-Down>", "<cmd>resize -2<cr>", { desc = "Más baja" })
map("n", "<C-Left>", "<cmd>vertical resize -2<cr>", { desc = "Más estrecha" })
map("n", "<C-Right>", "<cmd>vertical resize +2<cr>", { desc = "Más ancha" })

-- buffers
map("n", "<S-h>", "<cmd>bprevious<cr>", { desc = "Buffer anterior" })
map("n", "<S-l>", "<cmd>bnext<cr>", { desc = "Buffer siguiente" })
map("n", "<leader>bb", "<cmd>e #<cr>", { desc = "Alternar con el anterior" })

-- lines
map("n", "<A-j>", "<cmd>execute 'move .+' . v:count1<cr>==", { desc = "Bajar línea" })
map("n", "<A-k>", "<cmd>execute 'move .-' . (v:count1 + 1)<cr>==", { desc = "Subir línea" })
map("x", "<A-j>", ":<C-u>execute \"'<,'>move '>+\" . v:count1<cr>gv=gv", { desc = "Bajar selección" })
map("x", "<A-k>", ":<C-u>execute \"'<,'>move '<-\" . (v:count1 + 1)<cr>gv=gv", { desc = "Subir selección" })
map("x", "<", "<gv")
map("x", ">", ">gv")

-- j/k over wrapped lines unless a count is given
map({ "n", "x" }, "j", "v:count == 0 ? 'gj' : 'j'", { expr = true, silent = true })
map({ "n", "x" }, "k", "v:count == 0 ? 'gk' : 'k'", { expr = true, silent = true })

-- diagnostics ([d ]d are built in)
map("n", "<leader>cd", vim.diagnostic.open_float, { desc = "Diagnóstico de la línea" })

-- LSP (also the built-in gra / grn / K)
map({ "n", "x" }, "<leader>ca", vim.lsp.buf.code_action, { desc = "Acción de código" })
map("n", "<leader>cr", vim.lsp.buf.rename, { desc = "Renombrar símbolo" })

-- toggles
map("n", "<leader>uf", function()
  vim.g.ocarina_autoformat = not vim.g.ocarina_autoformat
  vim.notify("Formatear al guardar: " .. (vim.g.ocarina_autoformat and "sí" or "no"))
end, { desc = "Formatear al guardar" })
map("n", "<leader>uw", "<cmd>set wrap!<cr>", { desc = "Ajuste de línea" })
map("n", "<leader>ur", "<cmd>set relativenumber!<cr>", { desc = "Números relativos" })
map(
  "n",
  "<leader>uh",
  function() vim.lsp.inlay_hint.enable(not vim.lsp.inlay_hint.is_enabled({ bufnr = 0 }), { bufnr = 0 }) end,
  { desc = "Pistas en línea (LSP)" }
)

map("n", "<leader>qq", "<cmd>qa<cr>", { desc = "Salir" })
map("n", "<leader>l", "<cmd>Lazy<cr>", { desc = "Complementos (lazy)" })
