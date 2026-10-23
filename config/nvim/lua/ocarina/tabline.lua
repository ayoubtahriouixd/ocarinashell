-- Tabline like mockup 01: the listed buffers as tabs (the current one on surface2), clickable; on the right the LSP
-- breadcrumbs of the current window and the kanji of the active theme (紅, 墨, 琥…). One quiet document glyph for every
-- tab, as in the mockup (the coloured per-type icons stay in the picker and the explorer).
local M = {}

local function icon(buf) return vim.bo[buf].buftype == "terminal" and "\u{f120}" or "󰈙" end

-- unique short names: "Theme.qml", or "obi/Theme.qml" when two buffers share the tail
local function names(bufs)
  local out, seen = {}, {}
  for _, b in ipairs(bufs) do
    local full = vim.api.nvim_buf_get_name(b)
    local tail = full == "" and "[sin nombre]" or vim.fn.fnamemodify(full, ":t")
    out[b] = tail
    seen[tail] = (seen[tail] or 0) + 1
  end
  for _, b in ipairs(bufs) do
    if seen[out[b]] > 1 then out[b] = vim.fn.fnamemodify(vim.api.nvim_buf_get_name(b), ":h:t") .. "/" .. out[b] end
  end
  return out
end

function M.click(buf)
  if vim.api.nvim_buf_is_valid(buf) then vim.api.nvim_set_current_buf(buf) end
end

function M.render()
  local cur = vim.api.nvim_get_current_buf()
  local bufs = vim.tbl_filter(function(b) return vim.bo[b].buflisted end, vim.api.nvim_list_bufs())
  local short = names(bufs)

  local theme = require("ocarina.colors").palette
  local right = "%#OcTabKanji#" .. (theme and theme.kanji or "墨") .. " "
  local right_w = vim.api.nvim_eval_statusline(right, { use_tabline = true }).width
  local crumbs = require("ocarina.winbar").get()
  local crumbs_w = crumbs ~= "" and (vim.api.nvim_strwidth(crumbs) + 2) or 0

  local tabs, widths, cur_i = {}, {}, 1
  for i, b in ipairs(bufs) do
    local sel = b == cur
    if sel then cur_i = i end
    local hl = sel and "OcTabSel" or "OcTab"
    local mod = vim.bo[b].modified and ((sel and "%#OcTabSelModified#" or "%#OcTabModified#") .. " ●") or ""
    local label = short[b]:gsub("%%", "%%%%")
    local text = "%"
      .. b
      .. "@v:lua.OcarinaTabClick@"
      .. "%#"
      .. hl
      .. "Icon# "
      .. icon(b)
      .. " %#"
      .. hl
      .. "#"
      .. label
      .. mod
      .. "%#"
      .. hl
      .. "# %X"
    tabs[i] = text
    widths[i] = vim.api.nvim_strwidth(short[b]) + 4 + (vim.bo[b].modified and 2 or 0)
  end

  -- drop tabs from the far side until the current one fits
  local room = vim.o.columns - right_w - 2
  local first, last = 1, #tabs
  local function width()
    local w = 0
    for i = first, last do
      w = w + widths[i] + 1
    end
    return w
  end
  while width() > room and first < last do
    if cur_i - first > last - cur_i then
      first = first + 1
    else
      last = last - 1
    end
  end

  local out = { "%#TabLineFill# " }
  if first > 1 then out[#out + 1] = "%#OcTabCrumbSep#‹ " end
  for i = first, last do
    out[#out + 1] = tabs[i] .. "%#TabLineFill# "
  end
  if last < #tabs then out[#out + 1] = "%#OcTabCrumbSep#›" end
  -- the breadcrumbs only when they fit next to the visible tabs (tabs win)
  if crumbs_w > 0 and width() + crumbs_w <= room then
    right = "%#OcTabCrumb#" .. crumbs:gsub("›", "%%#OcTabCrumbSep#›%%#OcTabCrumb#") .. "  " .. right
  end
  out[#out + 1] = "%#TabLineFill#%=" .. right
  return table.concat(out)
end

function M.setup()
  -- %N@...@ click handlers must be global; they receive (minwid, clicks, button, mods), minwid = buffer number
  _G.OcarinaTabClick = function(minwid) M.click(minwid) end
  vim.o.tabline = "%!v:lua.require'ocarina.tabline'.render()"
end

return M
