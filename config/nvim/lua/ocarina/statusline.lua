-- Global statusline (laststatus=3), no plugin: mode in a 紅 block with its kanji (assets/data/kanji-ui.json
-- nvimModes), 枝 branch and diff, file, diagnostics, active LSP, filetype · encoding · position. Pure string
-- building; the only cached parts are the LSP names (LspAttach/LspDetach) and the gitsigns buffer variables.
local M = {}

local modes = {
  n = { "常", "NORMAL" },
  no = { "常", "NORMAL" },
  nt = { "常", "NORMAL" },
  i = { "挿", "INSERT" },
  ic = { "挿", "INSERT" },
  ix = { "挿", "INSERT" },
  v = { "視", "VISUAL" },
  vs = { "視", "VISUAL" },
  V = { "行", "V-LINE" },
  Vs = { "行", "V-LINE" },
  ["\22"] = { "塊", "V-BLOCK" },
  ["\22s"] = { "塊", "V-BLOCK" },
  s = { "選", "SELECT" },
  S = { "選", "S-LINE" },
  ["\19"] = { "選", "S-BLOCK" },
  R = { "換", "REPLACE" },
  Rv = { "換", "V-REPLACE" },
  Rc = { "換", "REPLACE" },
  Rx = { "換", "REPLACE" },
  c = { "令", "COMMAND" },
  cv = { "令", "EX" },
  ce = { "令", "EX" },
  r = { "令", "PROMPT" },
  rm = { "令", "MORE" },
  ["r?"] = { "令", "CONFIRM" },
  ["!"] = { "端", "SHELL" },
  t = { "端", "TERMINAL" },
}

local diag = {
  { vim.diagnostic.severity.ERROR, "誤", "OcStError" },
  { vim.diagnostic.severity.WARN, "警", "OcStWarn" },
  { vim.diagnostic.severity.INFO, "報", "OcStInfo" },
  { vim.diagnostic.severity.HINT, "示", "OcStHint" },
}

local lsp_names = {} -- bufnr → "qmlls, lua_ls"

local function esc(s) return (s:gsub("%%", "%%%%")) end

local function mode()
  local m = modes[vim.api.nvim_get_mode().mode] or { "常", vim.api.nvim_get_mode().mode:upper() }
  return "%#OcStMode# " .. m[1] .. " " .. m[2] .. " "
end

local function git()
  local head = vim.b.gitsigns_head or vim.g.gitsigns_head
  if not head or head == "" then return "" end
  local s = "%#OcStGit# 枝 %#OcStRight#" .. esc(head)
  local d = vim.b.gitsigns_status_dict
  if d then
    if (d.added or 0) > 0 then s = s .. " %#OcStGitAdd#新%#OcStRight#" .. d.added end
    if (d.changed or 0) > 0 then s = s .. " %#OcStGitChange#変%#OcStRight#" .. d.changed end
    if (d.removed or 0) > 0 then s = s .. " %#OcStGitDelete#消%#OcStRight#" .. d.removed end
  end
  return s .. " "
end

local function file()
  local bt = vim.bo.buftype
  local name
  if vim.bo.filetype == "snacks_dashboard" then
    return ""
  elseif bt == "terminal" then
    name = "端 " .. vim.fn.fnamemodify(vim.b.term_title or vim.o.shell, ":t")
  elseif bt == "help" then
    name = "助 " .. vim.fn.expand("%:t:r")
  else
    name = vim.fn.expand("%:~:.")
    if name == "" then name = "[sin nombre]" end
  end
  -- %< : when the bar does not fit, the path is what gets cut (never the mode block)
  local s = "%<%#OcStFile# " .. esc(name)
  if vim.bo.modified then
    s = s .. " %#OcStModified#●"
  elseif vim.bo.readonly or not vim.bo.modifiable then
    s = s .. " %#OcStRight#鍵"
  end
  return s .. " "
end

local function diagnostics()
  local counts = vim.diagnostic.count(0)
  local s = ""
  for _, d in ipairs(diag) do
    local n = counts[d[1]]
    if n and n > 0 then s = s .. "%#" .. d[3] .. "# " .. d[2] .. " " .. n end
  end
  return s ~= "" and (s .. " ") or ""
end

local function right()
  local parts = {}
  local lsp = lsp_names[vim.api.nvim_get_current_buf()]
  -- the server name only when there is room (laststatus=3: the bar spans the whole editor)
  if lsp and lsp ~= "" and vim.o.columns >= 110 then
    parts[#parts + 1] = "%#OcStLsp#" .. esc(lsp) .. " %#OcStRight#· "
  end
  local ft = vim.bo.filetype
  local enc = vim.bo.fileencoding ~= "" and vim.bo.fileencoding or vim.o.encoding
  local ff = vim.bo.fileformat ~= "unix" and (" · " .. vim.bo.fileformat) or ""
  local line, total = vim.fn.line("."), vim.fn.line("$")
  local pct = total > 0 and math.floor(line * 100 / total) or 0
  local info = (ft ~= "" and (ft .. " · ") or "")
    .. enc
    .. ff
    .. " · "
    .. line
    .. ":"
    .. vim.fn.virtcol(".")
    .. " · "
    .. pct
    .. " %%"
  local rec = vim.fn.reg_recording()
  if rec ~= "" then parts[#parts + 1] = "%#OcStRec#録 " .. rec .. " %#OcStRight#· " end
  parts[#parts + 1] = "%#OcStRight#" .. info .. " "
  return table.concat(parts)
end

function M.render()
  if vim.bo.filetype == "snacks_dashboard" then return mode() .. "%#StatusLine#" end
  return mode() .. git() .. file() .. diagnostics() .. "%#StatusLine#%=" .. right()
end

local function refresh_lsp(buf)
  local names = {}
  for _, c in ipairs(vim.lsp.get_clients({ bufnr = buf })) do
    if c.name ~= "copilot" then names[#names + 1] = c.name end
  end
  lsp_names[buf] = table.concat(names, ", ")
end

function M.setup()
  vim.o.statusline = "%!v:lua.require'ocarina.statusline'.render()"
  local grp = vim.api.nvim_create_augroup("ocarina_statusline", { clear = true })
  vim.api.nvim_create_autocmd({ "LspAttach", "LspDetach" }, {
    group = grp,
    callback = function(ev)
      -- LspDetach fires before the client leaves the list
      vim.schedule(function()
        if vim.api.nvim_buf_is_valid(ev.buf) then
          refresh_lsp(ev.buf)
          vim.cmd.redrawstatus()
        end
      end)
    end,
  })
  vim.api.nvim_create_autocmd("BufWipeout", {
    group = grp,
    callback = function(ev) lsp_names[ev.buf] = nil end,
  })
  vim.api.nvim_create_autocmd({ "RecordingEnter", "RecordingLeave" }, {
    group = grp,
    callback = function() vim.schedule(vim.cmd.redrawstatus) end,
  })
end

return M
