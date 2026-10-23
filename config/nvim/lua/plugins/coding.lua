-- Completion (blink.cmp), formatting (conform), text objects / surround / pairs (mini).
return {
  {
    "saghen/blink.cmp",
    version = "1.*", -- release tags ship the prebuilt fuzzy matcher (checksum verified); Lua fallback otherwise
    event = { "InsertEnter", "CmdlineEnter" },
    opts = {
      keymap = { preset = "default", ["<CR>"] = { "accept", "fallback" } },
      appearance = { nerd_font_variant = "mono" },
      completion = {
        menu = {
          border = "rounded",
          scrollbar = false,
          draw = { treesitter = { "lsp" }, columns = { { "kind_icon" }, { "label", "label_description", gap = 1 } } },
        },
        documentation = { auto_show = true, auto_show_delay_ms = 250, window = { border = "rounded" } },
        ghost_text = { enabled = false },
        list = { selection = { preselect = true, auto_insert = false } },
      },
      signature = { enabled = true, window = { border = "rounded" } },
      sources = {
        default = { "lazydev", "lsp", "path", "snippets", "buffer" },
        providers = {
          lazydev = { name = "LazyDev", module = "lazydev.integrations.blink", score_offset = 100 },
        },
      },
      cmdline = { completion = { menu = { auto_show = true } } },
      fuzzy = { implementation = "prefer_rust" },
    },
  },
  {
    "stevearc/conform.nvim",
    event = "BufWritePre",
    cmd = "ConformInfo",
    keys = {
      {
        "<leader>cf",
        function() require("conform").format({ async = true }) end,
        mode = { "n", "x" },
        desc = "Formatear",
      },
    },
    opts = {
      formatters_by_ft = {
        lua = { "stylua" },
        python = { "ruff_organize_imports", "ruff_format" },
        sh = { "shfmt" },
        bash = { "shfmt" },
        fish = { "fish_indent" },
        qml = { "qmlformat" },
        javascript = { "prettier" },
        typescript = { "prettier" },
        json = { "prettier" },
        jsonc = { "prettier" },
        yaml = { "prettier" },
        markdown = { "prettier" },
        css = { "prettier" },
        html = { "prettier" },
        toml = { "taplo" },
      },
      formatters = {
        qmlformat = { command = "/usr/lib/qt6/bin/qmlformat" },
        shfmt = { prepend_args = { "-i", "2", "-ci" } },
      },
      default_format_opts = { lsp_format = "fallback" },
      -- off by default: the repo has its own style (<leader>uf turns it on for the session)
      format_on_save = function()
        if vim.g.ocarina_autoformat then return { timeout_ms = 1500 } end
      end,
    },
  },
  { "echasnovski/mini.ai", event = "VeryLazy", opts = { n_lines = 500 } },
  {
    "echasnovski/mini.surround",
    keys = { { "gs", mode = { "n", "x" }, desc = "Rodear (mini.surround)" } },
    opts = {
      mappings = {
        add = "gsa",
        delete = "gsd",
        find = "gsf",
        find_left = "gsF",
        highlight = "gsh",
        replace = "gsr",
        update_n_lines = "gsn",
      },
    },
  },
  { "echasnovski/mini.pairs", event = "InsertEnter", opts = { modes = { insert = true, command = false } } },
  {
    "echasnovski/mini.icons",
    opts = {},
    init = function()
      package.preload["nvim-web-devicons"] = function()
        require("mini.icons").mock_nvim_web_devicons()
        return package.loaded["nvim-web-devicons"]
      end
    end,
  },
}
