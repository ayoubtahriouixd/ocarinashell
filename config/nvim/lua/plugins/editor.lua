-- Editor: which-key (groups in Spanish with kanji), flash, oil, gitsigns, todo-comments, trouble, persistence and
-- smear-cursor (only with AC power, outside 忍 Shinobi and outside Ghostty: lua/ocarina/fx.lua loads and toggles it).
return {
  {
    "folke/which-key.nvim",
    event = "VeryLazy",
    opts = {
      preset = "helix",
      delay = 300,
      icons = { mappings = false, separator = "›", group = "" },
      win = { border = "rounded", title = true, title_pos = "center" },
      spec = {
        { "<leader>b", group = "札 Buffers" },
        { "<leader>c", group = "符 Código" },
        { "<leader>f", group = "探 Archivos" },
        { "<leader>g", group = "枝 Git" },
        { "<leader>q", group = "保 Sesión" },
        { "<leader>s", group = "検 Buscar" },
        { "<leader>u", group = "切 Alternar" },
        { "<leader>w", group = "窓 Ventanas" },
        { "<leader>x", group = "診 Diagnósticos" },
        { "gs", group = "囲 Rodear" },
        { "[", group = "← Anterior" },
        { "]", group = "→ Siguiente" },
        { "g", group = "行 Ir a" },
        { "z", group = "畳 Pliegues" },
      },
    },
    keys = {
      { "<leader>?", function() require("which-key").show({ global = false }) end, desc = "Atajos de este buffer" },
    },
  },
  {
    "folke/flash.nvim",
    opts = { prompt = { prefix = { { " 跳 ", "FlashPromptIcon" } } }, modes = { search = { enabled = false } } },
    keys = {
      { "s", mode = { "n", "x", "o" }, function() require("flash").jump() end, desc = "Saltar (flash)" },
      { "S", mode = { "n", "x", "o" }, function() require("flash").treesitter() end, desc = "Seleccionar nodo" },
      { "r", mode = "o", function() require("flash").remote() end, desc = "Flash remoto" },
    },
  },
  {
    "stevearc/oil.nvim",
    cmd = "Oil",
    keys = { { "-", "<cmd>Oil<cr>", desc = "Carpeta del archivo (oil)" } },
    opts = {
      default_file_explorer = true,
      view_options = { show_hidden = true },
      float = { border = "rounded" },
      confirmation = { border = "rounded" },
      keymaps = { ["q"] = { "actions.close", mode = "n" } },
    },
    init = function()
      -- `nvim <dir>` opens oil (netrw is disabled)
      if vim.fn.argc() == 1 then
        local stat = vim.uv.fs_stat(vim.fn.argv(0) --[[@as string]])
        if stat and stat.type == "directory" then require("lazy").load({ plugins = { "oil.nvim" } }) end
      end
    end,
  },
  {
    "lewis6991/gitsigns.nvim",
    event = { "BufReadPre", "BufNewFile" },
    opts = {
      signs = {
        add = { text = "▎" },
        change = { text = "▎" },
        delete = { text = "▁" },
        topdelete = { text = "▔" },
        changedelete = { text = "▎" },
        untracked = { text = "┆" },
      },
      signs_staged = {
        add = { text = "▎" },
        change = { text = "▎" },
        delete = { text = "▁" },
        topdelete = { text = "▔" },
        changedelete = { text = "▎" },
      },
      preview_config = { border = "rounded" },
      on_attach = function(buf)
        local gs = require("gitsigns")
        local function map(mode, l, r, desc) vim.keymap.set(mode, l, r, { buffer = buf, desc = desc }) end
        map("n", "]h", function() gs.nav_hunk("next") end, "Siguiente cambio")
        map("n", "[h", function() gs.nav_hunk("prev") end, "Cambio anterior")
        map({ "n", "x" }, "<leader>ghs", ":Gitsigns stage_hunk<cr>", "Preparar cambio")
        map({ "n", "x" }, "<leader>ghr", ":Gitsigns reset_hunk<cr>", "Deshacer cambio")
        map("n", "<leader>ghp", gs.preview_hunk_inline, "Ver cambio")
        map("n", "<leader>ghb", function() gs.blame_line({ full = true }) end, "Autor (completo)")
        map("n", "<leader>ghd", gs.diffthis, "Diff con el índice")
        map({ "o", "x" }, "ih", ":<C-u>Gitsigns select_hunk<cr>", "Cambio (objeto)")
      end,
    },
  },
  {
    "folke/todo-comments.nvim",
    event = { "BufReadPost", "BufNewFile" },
    opts = { signs = false },
    keys = {
      { "]t", function() require("todo-comments").jump_next() end, desc = "Siguiente TODO" },
      { "[t", function() require("todo-comments").jump_prev() end, desc = "TODO anterior" },
      { "<leader>st", function() Snacks.picker.todo_comments() end, desc = "TODO del proyecto" },
    },
  },
  {
    "folke/trouble.nvim",
    cmd = "Trouble",
    opts = { focus = true },
    keys = {
      { "<leader>xx", "<cmd>Trouble diagnostics toggle<cr>", desc = "Diagnósticos del proyecto" },
      { "<leader>xX", "<cmd>Trouble diagnostics toggle filter.buf=0<cr>", desc = "Diagnósticos del buffer" },
      { "<leader>xs", "<cmd>Trouble symbols toggle<cr>", desc = "Símbolos" },
      { "<leader>xq", "<cmd>Trouble qflist toggle<cr>", desc = "Lista quickfix" },
    },
  },
  {
    "folke/persistence.nvim",
    event = "BufReadPre",
    opts = {},
    keys = {
      { "<leader>qs", function() require("persistence").load() end, desc = "Restaurar sesión (carpeta)" },
      { "<leader>qS", function() require("persistence").select() end, desc = "Elegir sesión" },
      { "<leader>ql", function() require("persistence").load({ last = true }) end, desc = "Última sesión" },
      { "<leader>qd", function() require("persistence").stop() end, desc = "No guardar esta sesión" },
    },
  },
  {
    "sphamba/smear-cursor.nvim",
    -- loaded by lua/ocarina/fx.lua only while effects.json says cursor = true, and never inside Ghostty
    -- (its own ink-cursor shader draws the trail there). The colour is the Cursor highlight (紅).
    opts = {
      stiffness = 0.8,
      trailing_stiffness = 0.6,
      distance_stop_animating = 0.5,
      hide_target_hack = false,
      never_draw_over_target = true,
    },
  },
}
