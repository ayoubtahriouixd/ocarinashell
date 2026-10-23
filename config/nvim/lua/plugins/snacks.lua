-- snacks.nvim: dashboard, picker, explorer, notifier, indent, scroll, zen, lazygit, words, input, bigfile.
-- Animations follow theme/effects.json (lua/ocarina/fx.lua): vim.g.snacks_animate and Snacks.scroll.
return {
  {
    "folke/snacks.nvim",
    lazy = false,
    priority = 1000,
    opts = function()
      require("ocarina.dashboard").setup()
      return {
        bigfile = { enabled = true },
        quickfile = { enabled = true },
        dashboard = require("ocarina.dashboard").opts(),
        image = { enabled = true, doc = { enabled = false } }, -- PNG/JPG in buffers + the dashboard logo
        explorer = { enabled = true, replace_netrw = false },
        indent = {
          enabled = true,
          indent = { char = "│" },
          scope = { char = "│" },
          animate = { duration = { step = 15, total = 200 } },
        },
        input = { enabled = true },
        notifier = {
          enabled = true,
          timeout = 3500,
          style = "compact",
          top_down = false,
          icons = { error = "誤 ", warn = "警 ", info = "報 ", debug = "検 ", trace = "跡 " },
        },
        picker = {
          enabled = true,
          prompt = " 探 ",
          ui_select = true,
          layout = { preset = "default" },
          icons = { ui = { selected = "● ", unselected = "○ " } },
          sources = {
            explorer = { layout = { preset = "sidebar", preview = false } },
          },
        },
        scroll = {
          enabled = require("ocarina.fx").state().motion,
          animate = { duration = { step = 10, total = 160 }, easing = "outQuad" },
        },
        words = { enabled = true, debounce = 150 },
        zen = { enabled = true, toggles = { dim = false, git_signs = false, diagnostics = false } },
        lazygit = { configure = false }, -- the theme engine writes ~/.config/lazygit/config.yml
        styles = {
          notification = { border = "rounded", wo = { wrap = true } },
          zen = { backdrop = { transparent = false, blend = 0 }, width = 110 },
        },
      }
    end,
    keys = {
      { "<leader><space>", function() Snacks.picker.smart() end, desc = "Buscar archivos (listo)" },
      { "<leader>,", function() Snacks.picker.buffers() end, desc = "Buffers abiertos" },
      { "<leader>/", function() Snacks.picker.grep() end, desc = "Buscar texto (grep)" },
      { "<leader>:", function() Snacks.picker.command_history() end, desc = "Historial de órdenes" },
      { "<leader>e", function() Snacks.explorer() end, desc = "Explorador" },
      { "<leader>n", function() Snacks.picker.notifications() end, desc = "Historial de avisos" },
      -- find
      { "<leader>ff", function() Snacks.picker.files() end, desc = "Archivos" },
      { "<leader>fr", function() Snacks.picker.recent() end, desc = "Recientes" },
      { "<leader>fp", function() Snacks.picker.projects() end, desc = "Proyectos" },
      {
        "<leader>fc",
        function() Snacks.picker.files({ cwd = vim.fn.stdpath("config") }) end,
        desc = "Config de Neovim",
      },
      { "<leader>fg", function() Snacks.picker.git_files() end, desc = "Archivos de git" },
      -- search
      { "<leader>sb", function() Snacks.picker.lines() end, desc = "Líneas del buffer" },
      { "<leader>sw", function() Snacks.picker.grep_word() end, desc = "Palabra o selección", mode = { "n", "x" } },
      { "<leader>sh", function() Snacks.picker.help() end, desc = "Ayuda" },
      { "<leader>sk", function() Snacks.picker.keymaps() end, desc = "Atajos" },
      { "<leader>sd", function() Snacks.picker.diagnostics() end, desc = "Diagnósticos" },
      { "<leader>sr", function() Snacks.picker.resume() end, desc = "Reanudar búsqueda" },
      { "<leader>ss", function() Snacks.picker.lsp_symbols() end, desc = "Símbolos (LSP)" },
      { "<leader>sS", function() Snacks.picker.lsp_workspace_symbols() end, desc = "Símbolos del proyecto" },
      { "<leader>su", function() Snacks.picker.undo() end, desc = "Historial de cambios" },
      { "<leader>sc", function() Snacks.picker.colorschemes() end, desc = "Esquemas de color" },
      -- git
      { "<leader>gg", function() Snacks.lazygit() end, desc = "Lazygit" },
      { "<leader>gl", function() Snacks.picker.git_log() end, desc = "Historial" },
      { "<leader>gs", function() Snacks.picker.git_status() end, desc = "Estado" },
      { "<leader>gd", function() Snacks.picker.git_diff() end, desc = "Cambios (diff)" },
      { "<leader>gb", function() Snacks.git.blame_line() end, desc = "Autor de la línea" },
      { "<leader>gB", function() Snacks.gitbrowse() end, desc = "Abrir en el navegador", mode = { "n", "x" } },
      -- lsp
      { "gd", function() Snacks.picker.lsp_definitions() end, desc = "Ir a la definición" },
      { "gD", function() Snacks.picker.lsp_declarations() end, desc = "Ir a la declaración" },
      -- the built-in gr* prefix (grn rename, gra action) stays; these replace its lists with the picker
      { "grr", function() Snacks.picker.lsp_references() end, desc = "Referencias" },
      { "gri", function() Snacks.picker.lsp_implementations() end, desc = "Implementaciones" },
      { "grt", function() Snacks.picker.lsp_type_definitions() end, desc = "Definición del tipo" },
      -- ui
      { "<leader>z", function() Snacks.zen() end, desc = "Zen" },
      { "<leader>.", function() Snacks.scratch() end, desc = "Borrador" },
      { "<leader>bd", function() Snacks.bufdelete() end, desc = "Cerrar buffer" },
      { "<leader>bo", function() Snacks.bufdelete.other() end, desc = "Cerrar los demás" },
      { "<leader>un", function() Snacks.notifier.hide() end, desc = "Ocultar avisos" },
      { "<c-/>", function() Snacks.terminal() end, desc = "Terminal", mode = { "n", "t" } },
      { "]]", function() Snacks.words.jump(vim.v.count1) end, desc = "Siguiente referencia", mode = { "n", "t" } },
      { "[[", function() Snacks.words.jump(-vim.v.count1) end, desc = "Referencia anterior", mode = { "n", "t" } },
    },
  },
}
