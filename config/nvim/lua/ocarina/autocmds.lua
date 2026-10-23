local grp = vim.api.nvim_create_augroup("ocarina", { clear = true })
local au = function(ev, opts)
  opts.group = grp
  vim.api.nvim_create_autocmd(ev, opts)
end

-- brief 紅 flash on yank (no animation loop; 0 when motion is off)
au("TextYankPost", {
  callback = function()
    vim.hl.on_yank({ higroup = "CurSearch", timeout = require("ocarina.fx").state().motion and 180 or 1 })
  end,
})

-- back to the last position when reopening a file
au("BufReadPost", {
  callback = function(ev)
    local ft = vim.bo[ev.buf].filetype
    if ft == "gitcommit" or ft == "gitrebase" or vim.b[ev.buf].ocarina_last_loc then return end
    vim.b[ev.buf].ocarina_last_loc = true
    local mark = vim.api.nvim_buf_get_mark(ev.buf, '"')
    if mark[1] > 0 and mark[1] <= vim.api.nvim_buf_line_count(ev.buf) then
      pcall(vim.api.nvim_win_set_cursor, 0, mark)
    end
  end,
})

au("VimResized", {
  callback = function()
    local tab = vim.fn.tabpagenr()
    vim.cmd("tabdo wincmd =")
    vim.cmd("tabnext " .. tab)
  end,
})

-- files changed outside (git checkout, the theme engine…)
au({ "FocusGained", "TermClose", "TermLeave" }, {
  callback = function()
    if vim.o.buftype ~= "nofile" then vim.cmd("checktime") end
  end,
})

-- q closes the auxiliary windows
au("FileType", {
  pattern = { "help", "qf", "checkhealth", "man", "lspinfo", "notify", "grug-far", "startuptime", "query" },
  callback = function(ev)
    vim.bo[ev.buf].buflisted = false
    vim.keymap.set("n", "q", "<cmd>close<cr>", { buffer = ev.buf, silent = true, desc = "Cerrar" })
  end,
})

-- create missing directories on save
au("BufWritePre", {
  callback = function(ev)
    if ev.match:match("^%w%w+:[\\/][\\/]") then return end
    local file = vim.uv.fs_realpath(ev.match) or ev.match
    vim.fn.mkdir(vim.fn.fnamemodify(file, ":p:h"), "p")
  end,
})

-- prose: soft wrap
au("FileType", {
  pattern = { "markdown", "gitcommit", "text" },
  callback = function() vim.opt_local.wrap = true end,
})

-- QML: 4 spaces (repo style) and the qmljs tree-sitter parser
vim.treesitter.language.register("qmljs", "qml")

-- diagnostics with the kanji of the statusline
vim.diagnostic.config({
  severity_sort = true,
  underline = true,
  update_in_insert = false,
  -- the message only on the cursor line (mockup 01: the code stays clean; signs + statusline count the rest)
  virtual_text = { spacing = 2, prefix = "●", source = "if_many", current_line = true },
  float = { border = "rounded", source = "if_many", header = "" },
  signs = {
    text = {
      [vim.diagnostic.severity.ERROR] = "誤",
      [vim.diagnostic.severity.WARN] = "警",
      [vim.diagnostic.severity.INFO] = "報",
      [vim.diagnostic.severity.HINT] = "示",
    },
  },
})
