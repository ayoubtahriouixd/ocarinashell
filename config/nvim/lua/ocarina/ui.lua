-- Bars of the editor: statusline (modes in kanji), tabline (buffers + breadcrumbs + theme kanji).
local M = {}

function M.setup()
  require("ocarina.statusline").setup()
  require("ocarina.winbar").setup()
  require("ocarina.tabline").setup()
  -- the theme kanji and colours change with the theme engine
  vim.api.nvim_create_autocmd("User", {
    pattern = "OcarinaTheme",
    group = vim.api.nvim_create_augroup("ocarina_ui", { clear = true }),
    callback = function()
      vim.cmd.redrawtabline()
      vim.cmd.redrawstatus()
    end,
  })
end

return M
