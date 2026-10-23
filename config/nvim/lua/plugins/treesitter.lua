-- nvim-treesitter, `main` branch (the one for Neovim 0.12): it only installs parsers and queries; highlighting,
-- folds and indent are started per buffer with the core API. Parsers are compiled by tree-sitter-cli.
local parsers = {
  "bash",
  "css",
  "diff",
  "fish",
  "git_rebase",
  "gitcommit",
  "glsl",
  "html",
  "javascript",
  "json",
  "kdl",
  "lua",
  "luadoc",
  "markdown",
  "markdown_inline",
  "python",
  "qmljs",
  "query",
  "regex",
  "toml",
  "tsx",
  "typescript",
  "vim",
  "vimdoc",
  "yaml",
}

local qml_injections = false

return {
  {
    "nvim-treesitter/nvim-treesitter",
    branch = "main",
    lazy = false, -- does not support lazy loading; it is a few file lookups at start-up
    build = ":TSUpdate",
    config = function()
      local ts = require("nvim-treesitter")
      -- install what is missing, in the background, only when the compiler is there
      if vim.fn.executable("tree-sitter") == 1 then
        local have = {}
        for _, p in ipairs(ts.get_installed()) do
          have[p] = true
        end
        local missing = vim.tbl_filter(function(p) return not have[p] end, parsers)
        if #missing > 0 then ts.install(missing) end
      end
      vim.api.nvim_create_autocmd("FileType", {
        group = vim.api.nvim_create_augroup("ocarina_ts", { clear = true }),
        callback = function(ev)
          local lang = vim.treesitter.language.get_lang(vim.bo[ev.buf].filetype)
          if lang == "qmljs" and not qml_injections then
            -- nvim-treesitter's qmljs injections inherit the whole ecma set (~200 lines of html/sql/graphql/css
            -- template-string rules that never occur in QML): 57 ms to compile on the first .qml file. Only regex
            -- literals are injected. query.set replaces the query (file overrides would still inherit ecma);
            -- :checkhealth ocarina checks that it still compiles after a parser update.
            qml_injections = true
            pcall(vim.treesitter.query.set, "qmljs", "injections", require("ocarina.ts").qml_injections)
          end
          if not lang or not pcall(vim.treesitter.start, ev.buf, lang) then return end
          vim.wo[0][0].foldmethod = "expr"
          vim.wo[0][0].foldexpr = "v:lua.vim.treesitter.foldexpr()"
          if vim.treesitter.query.get(lang, "indents") then
            vim.bo[ev.buf].indentexpr = "v:lua.require'nvim-treesitter'.indentexpr()"
          end
        end,
      })
    end,
  },
}
