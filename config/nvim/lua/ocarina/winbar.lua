-- Breadcrumbs from the LSP document symbols (Row › Repeater › delegate). One textDocument/documentSymbol request per
-- buffer change (debounced), never per cursor move: moving only walks the cached tree. The crumbs are drawn on the
-- right of the tabline (one bar, like mockup 01) for the current window.
local M = {}

local cache = {} -- bufnr → { tick = changedtick, symbols = tree }
local timers = {}
local crumbs = ""

local function contains(range, line, col)
  local s, e = range.start, range["end"]
  if line < s.line or line > e.line then return false end
  if line == s.line and col < s.character then return false end
  if line == e.line and col > e.character then return false end
  return true
end

local function path(symbols, line, col, out)
  for _, sym in ipairs(symbols or {}) do
    local range = sym.range or (sym.location and sym.location.range)
    if range and contains(range, line, col) then
      out[#out + 1] = sym.name
      if sym.children then path(sym.children, line, col, out) end
      return out
    end
  end
  return out
end

local function update_crumbs()
  local buf = vim.api.nvim_get_current_buf()
  local entry = cache[buf]
  local new = ""
  if entry and entry.symbols then
    local pos = vim.api.nvim_win_get_cursor(0)
    local names = path(entry.symbols, pos[1] - 1, pos[2], {})
    -- only the two innermost levels: a whisper next to the tabs, not a path
    if #names > 2 then names = { names[#names - 1], names[#names] } end
    for i, n in ipairs(names) do
      names[i] = n:gsub("%%", "%%%%"):gsub("\n.*", "")
    end
    new = table.concat(names, " › ")
  end
  if new ~= crumbs then
    crumbs = new
    vim.cmd.redrawtabline()
  end
end

local function request(buf)
  if not vim.api.nvim_buf_is_valid(buf) then return end
  local client = vim.lsp.get_clients({ bufnr = buf, method = "textDocument/documentSymbol" })[1]
  if not client then
    cache[buf] = nil
    return
  end
  local tick = vim.b[buf].changedtick
  local params = { textDocument = vim.lsp.util.make_text_document_params(buf) }
  client:request("textDocument/documentSymbol", params, function(err, result)
    if err or not result or not vim.api.nvim_buf_is_valid(buf) then return end
    cache[buf] = { tick = tick, symbols = result }
    if buf == vim.api.nvim_get_current_buf() then update_crumbs() end
  end, buf)
end

local function schedule_request(buf, delay)
  local t = timers[buf]
  if not t then
    t = assert(vim.uv.new_timer())
    timers[buf] = t
  end
  t:stop()
  t:start(delay, 0, vim.schedule_wrap(function() request(buf) end))
end

function M.get() return crumbs end

function M.setup()
  local grp = vim.api.nvim_create_augroup("ocarina_winbar", { clear = true })
  vim.api.nvim_create_autocmd("LspAttach", {
    group = grp,
    callback = function(ev)
      local client = vim.lsp.get_client_by_id(ev.data.client_id)
      if client and client:supports_method("textDocument/documentSymbol") then schedule_request(ev.buf, 100) end
    end,
  })
  vim.api.nvim_create_autocmd({ "TextChanged", "InsertLeave", "BufWritePost" }, {
    group = grp,
    callback = function(ev)
      if cache[ev.buf] then schedule_request(ev.buf, 400) end
    end,
  })
  vim.api.nvim_create_autocmd({ "CursorMoved", "BufEnter", "WinEnter" }, {
    group = grp,
    callback = update_crumbs,
  })
  vim.api.nvim_create_autocmd("BufWipeout", {
    group = grp,
    callback = function(ev)
      cache[ev.buf] = nil
      if timers[ev.buf] then
        timers[ev.buf]:stop()
        timers[ev.buf]:close()
        timers[ev.buf] = nil
      end
    end,
  })
end

return M
