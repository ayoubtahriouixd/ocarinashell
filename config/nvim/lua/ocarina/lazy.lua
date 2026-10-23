-- lazy.nvim: every plugin lazy by default, pinned by lazy-lock.json (in git). Updates go through 守 Mamori
-- (`bin/ocarina-nvim-health`: branch → sync → checkhealth → start-up time → merge), never on their own.
local root = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not vim.uv.fs_stat(root) then
  local out = vim.fn.system({
    "git",
    "clone",
    "--filter=blob:none",
    "--branch=stable",
    "https://github.com/folke/lazy.nvim.git",
    root,
  })
  if vim.v.shell_error ~= 0 then
    vim.api.nvim_echo({ { "No se pudo clonar lazy.nvim:\n", "ErrorMsg" }, { out, "WarningMsg" } }, true, {})
    return
  end
end
vim.opt.rtp:prepend(root)

require("lazy").setup({
  spec = { { import = "plugins" } },
  defaults = { lazy = true },
  install = { missing = true, colorscheme = { "ocarina", "habamax" } },
  checker = { enabled = false }, -- Mamori decides when to update
  change_detection = { enabled = false },
  rocks = { enabled = false },
  ui = {
    border = "rounded",
    backdrop = 100,
    title = " 具 Complementos ",
  },
  performance = {
    rtp = {
      disabled_plugins = { "gzip", "netrwPlugin", "rplugin", "tarPlugin", "tohtml", "tutor", "zipPlugin" },
    },
  },
})
