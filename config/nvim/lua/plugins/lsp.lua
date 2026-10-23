-- LSP with the native API (vim.lsp.config / vim.lsp.enable, Neovim ≥ 0.11); nvim-lspconfig only provides the
-- server definitions (its lsp/*.lua). Servers come from the official repos (scripts/root/fase-09.sh, D-054), so
-- pacman and 守 Mamori keep them current; a server is enabled only when its binary exists (a missing one never
-- shows errors, `:checkhealth ocarina` lists it). mason stays available on demand for anything else.
local servers = {
  lua_ls = "lua-language-server",
  pyright = "pyright-langserver",
  ts_ls = "typescript-language-server",
  bashls = "bash-language-server",
  jsonls = "vscode-json-language-server",
  yamlls = "yaml-language-server",
  marksman = "marksman",
  taplo = "taplo",
  qmlls = "qmlls6",
}

return {
  {
    "neovim/nvim-lspconfig",
    event = { "BufReadPre", "BufNewFile" },
    dependencies = { "saghen/blink.cmp" },
    config = function()
      vim.lsp.config("*", { capabilities = require("blink.cmp").get_lsp_capabilities() })

      vim.lsp.config("lua_ls", {
        settings = {
          Lua = {
            runtime = { version = "LuaJIT" },
            workspace = { checkThirdParty = false },
            completion = { callSnippet = "Replace" },
            hint = { enable = true, arrayIndex = "Disable" },
            telemetry = { enable = false },
          },
        },
      })
      -- Qt 6 ships qmlls as qmlls6 on Arch; shell/.qmlls.ini (written by Quickshell) gives it the qs.* imports
      vim.lsp.config("qmlls", { cmd = { "qmlls6" } })
      vim.lsp.config("pyright", {
        settings = { python = { analysis = { typeCheckingMode = "basic", diagnosticMode = "openFilesOnly" } } },
      })
      vim.lsp.config("jsonls", { settings = { json = { validate = { enable = true } } } })
      vim.lsp.config("yamlls", { settings = { yaml = { keyOrdering = false } } })

      local enabled = {}
      for name, bin in pairs(servers) do
        if vim.fn.executable(bin) == 1 then enabled[#enabled + 1] = name end
      end
      vim.lsp.enable(enabled)
    end,
  },
  {
    "mason-org/mason.nvim",
    cmd = "Mason",
    opts = {
      PATH = "append", -- the system (pacman) binaries always win
      ui = {
        border = "rounded",
        icons = { package_installed = "●", package_pending = "◐", package_uninstalled = "○" },
      },
    },
  },
  {
    "folke/lazydev.nvim",
    ft = "lua",
    opts = { library = { { path = "${3rd}/luv/library", words = { "vim%.uv" } }, "snacks.nvim" } },
  },
}
