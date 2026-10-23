-- :checkhealth ocarina — what this config needs from the system. Missing optional pieces are warnings (the feature
-- hides itself); errors are only things that break the editor. bin/ocarina-nvim-health (守 Mamori) runs it headless.
local M = {}

local h = vim.health

local servers = {
  { "qmlls6", "QML (qt6-declarative)" },
  { "lua-language-server", "Lua (lua-language-server)" },
  { "pyright-langserver", "Python (pyright)" },
  { "typescript-language-server", "JS/TS (typescript-language-server)" },
  { "bash-language-server", "Bash (bash-language-server)" },
  { "vscode-json-language-server", "JSON (vscode-json-languageserver)" },
  { "yaml-language-server", "YAML (yaml-language-server)" },
  { "marksman", "Markdown (marksman)" },
  { "taplo", "TOML (taplo-cli)" },
}

local formatters = {
  { "stylua", "Lua" },
  { "ruff", "Python" },
  { "shfmt", "sh" },
  { "prettier", "JS/JSON/YAML/MD" },
  { "/usr/lib/qt6/bin/qmlformat", "QML" },
  { "fish_indent", "fish" },
}

function M.check()
  h.start("OcarinaShell · versión y tema")
  if vim.fn.has("nvim-0.11") == 1 then
    h.ok("Neovim " .. tostring(vim.version()))
  else
    h.error("Neovim " .. tostring(vim.version()) .. ": hace falta ≥ 0.11 (vim.lsp.config, winborder)")
  end
  local colors = require("ocarina.colors")
  if colors.from_file then
    h.ok(("Paleta del motor de temas: %s %s"):format(colors.palette.kanji, colors.palette.name))
  else
    h.warn("Sin paleta generada; uso 墨 Sumi por defecto", { "Ejecuta `ocarina-theme apply <tema>`" })
  end
  local fx = require("ocarina.fx").state()
  h.info(("Efectos: estela %s · movimiento %s"):format(fx.cursor and "sí" or "no", fx.motion and "sí" or "no"))

  h.start("OcarinaShell · servidores LSP (repos oficiales)")
  for _, s in ipairs(servers) do
    if vim.fn.executable(s[1]) == 1 then
      h.ok(s[2])
    else
      h.warn(s[2] .. ": no instalado (se desactiva solo)", { "sudo bash scripts/root/fase-09.sh" })
    end
  end

  h.start("OcarinaShell · formateadores")
  for _, f in ipairs(formatters) do
    if vim.fn.executable(f[1]) == 1 then
      h.ok(f[2] .. " (" .. vim.fn.fnamemodify(f[1], ":t") .. ")")
    else
      h.warn(f[2] .. ": " .. f[1] .. " no instalado")
    end
  end

  h.start("OcarinaShell · tree-sitter")
  if vim.fn.executable("tree-sitter") == 1 then
    h.ok("tree-sitter-cli presente (compila los parsers)")
  else
    h.warn("tree-sitter-cli no instalado: no se compilan parsers nuevos", { "sudo bash scripts/root/fase-09.sh" })
  end
  local ok, ts = pcall(require, "nvim-treesitter")
  if ok then
    local have = {}
    for _, p in ipairs(ts.get_installed()) do
      have[p] = true
    end
    local missing = {}
    for _, p in ipairs({ "qmljs", "lua", "python", "bash", "fish", "json", "yaml", "toml", "markdown", "kdl" }) do
      if not have[p] and not pcall(vim.treesitter.language.add, p) then missing[#missing + 1] = p end
    end
    if have.qmljs then
      local qok, qerr = pcall(vim.treesitter.query.parse, "qmljs", require("ocarina.ts").qml_injections)
      if qok then
        h.ok("Query propia de injections de QML válida")
      else
        h.error("La query propia de injections de QML ya no compila: " .. tostring(qerr), {
          "Revisa lua/ocarina/ts.lua contra queries/ecma/injections.scm de nvim-treesitter",
        })
      end
    end
    if #missing == 0 then
      h.ok("Parsers principales instalados")
    else
      h.warn(
        "Faltan parsers: " .. table.concat(missing, ", "),
        { ":TSUpdate (o espera a que terminen en segundo plano)" }
      )
    end
  end

  h.start("OcarinaShell · dashboard")
  local png = vim.uv.fs_realpath(vim.fn.stdpath("config"))
  png = png and vim.fs.normalize(png .. "/../../assets/logo/png/ocarinashell-mark-512.png")
  if png and vim.uv.fs_stat(png) then
    h.ok("Logo PNG: " .. png)
  else
    h.warn("No encuentro el logo PNG del repo: el dashboard usa el braille")
  end
  local daily = (vim.env.XDG_CACHE_HOME or (vim.env.HOME .. "/.cache")) .. "/ocarinashell/daily.json"
  if vim.uv.fs_stat(daily) then
    h.ok("Proverbio y 候 del día: " .. daily)
  else
    h.warn("Sin " .. daily, { "ocarina-daily --force" })
  end
end

return M
