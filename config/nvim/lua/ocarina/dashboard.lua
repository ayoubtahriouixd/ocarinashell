-- Start screen (snacks.dashboard): the real ocarina (PNG over the kitty graphics protocol in Ghostty; braille
-- fallback elsewhere), OcarinaShell + オカリナ・シェル, the proverb and the 七十二候 of the day (the same pick as Kagi
-- and the fish greeting: ~/.cache/ocarinashell/daily.json from bin/ocarina-daily), shortcuts, recent files,
-- projects and the start-up time.
local M = {}

local LOGO_ROWS = 8 -- rows reserved for the image (the braille fallback has 8 lines too)
local cache_dir = (vim.env.XDG_CACHE_HOME or (vim.env.HOME .. "/.cache")) .. "/ocarinashell"
local placement

local function logo_png()
  local cfg = vim.uv.fs_realpath(vim.fn.stdpath("config"))
  local png = cfg and vim.fs.normalize(cfg .. "/../../assets/logo/png/ocarinashell-mark-512.png")
  return png and vim.uv.fs_stat(png) and png or nil
end

-- decided from the environment: snacks' own probe asks the terminal and blocks start-up until it answers
local function use_image()
  if M._image == nil then
    local env = vim.env
    local kitty_proto = env.TERM_PROGRAM == "ghostty"
      or env.TERM == "xterm-ghostty"
      or env.TERM == "xterm-kitty"
      or env.KITTY_WINDOW_ID ~= nil
    M._image = kitty_proto and not env.TMUX and not env.SSH_CONNECTION and logo_png() ~= nil
  end
  return M._image
end

local function daily()
  local fd = io.open(cache_dir .. "/daily.json", "r")
  local data
  if fd then
    local ok, d = pcall(vim.json.decode, fd:read("*a"))
    fd:close()
    data = ok and type(d) == "table" and d or nil
  end
  if not data or data.day ~= os.date("%Y-%m-%d") then
    -- yesterday's (or nothing) for now; tomorrow's start-up reads the fresh one
    local bin = vim.env.HOME .. "/.local/bin/ocarina-daily"
    if vim.uv.fs_stat(bin) then pcall(vim.system, { bin, "--quiet" }, { detach = true }) end
  end
  return data or {}
end

local function startup()
  local stats = require("lazy.stats").stats()
  local ms = math.floor(stats.startuptime * 10 + 0.5) / 10
  return {
    align = "center",
    text = {
      { "速 ", hl = "SnacksDashboardIcon" },
      { ms .. " ms", hl = "special" },
      { " · ", hl = "footer" },
      { stats.loaded .. "/" .. stats.count, hl = "special" },
      { " complementos", hl = "footer" },
    },
  }
end

-- the image goes over the reserved blank rows, centred; re-placed after every dashboard redraw (resize, …)
local function place_logo()
  if not use_image() or #vim.api.nvim_list_uis() == 0 then return end
  local buf = vim.api.nvim_get_current_buf()
  if vim.bo[buf].filetype ~= "snacks_dashboard" then return end
  local win = vim.api.nvim_get_current_win()
  local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
  local title
  for i, l in ipairs(lines) do
    if l:find("OcarinaShell", 1, true) then
      title = i
      break
    end
  end
  if not title or title - 1 - LOGO_ROWS < 1 then return end
  local first = title - 1 - LOGO_ROWS -- one blank row of padding above the title
  local width = vim.api.nvim_win_get_width(win)
  -- the mark is 512×321 and a terminal cell about 1:2, so 8 rows are ~26 columns
  local cols = math.floor(LOGO_ROWS * 2 * 512 / 321 + 0.5)
  local col = math.max(0, math.floor((width - cols) / 2))
  if placement then pcall(placement.close, placement) end
  local ok, p = pcall(Snacks.image.placement.new, buf, logo_png(), {
    inline = true,
    conceal = true,
    pos = { first, col },
    range = { first, col, first + LOGO_ROWS - 1, col + cols },
    width = cols,
    height = LOGO_ROWS,
    min_height = LOGO_ROWS,
  })
  placement = ok and p or nil
end

function M.opts()
  local d = daily()
  local header
  if use_image() then
    header = string.rep(" \n", LOGO_ROWS - 1) .. " "
  else
    header = table.concat(require("ocarina.logo"), "\n")
  end

  local sections = {
    { header = header, padding = 1 },
    { text = { { "OcarinaShell", hl = "OcDashBrand" } }, align = "center" },
    { text = { { "オカリナ・シェル", hl = "OcDashKana" } }, align = "center", padding = 1 },
  }
  if d.proverb and d.proverb.jp ~= "" then
    sections[#sections + 1] = { text = { { d.proverb.jp, hl = "OcDashJp" } }, align = "center" }
    sections[#sections + 1] = { text = { { d.proverb.es, hl = "OcDashEs" } }, align = "center" }
  end
  if d.ko and d.ko.kanji ~= "" then
    sections[#sections + 1] = {
      text = {
        { "候 ", hl = "OcDashTime" },
        { d.ko.kanji .. " · " .. d.ko.es, hl = "OcDashKo" },
        { d.sekki and d.sekki.kanji ~= "" and (" (" .. d.sekki.kanji .. ")") or "", hl = "OcDashTime" },
      },
      align = "center",
    }
  end
  sections[#sections].padding = 1
  vim.list_extend(sections, {
    { section = "keys", gap = 0, padding = 1 },
    { icon = "歴", title = "Recientes", section = "recent_files", limit = 5, padding = 1 },
    { icon = "案", title = "Proyectos", section = "projects", limit = 3, padding = 1 },
    startup,
  })

  return {
    enabled = true,
    width = 64,
    preset = {
      keys = {
        { icon = "探", key = "f", desc = "Buscar archivo", action = ":lua Snacks.picker.smart()" },
        { icon = "新", key = "n", desc = "Archivo nuevo", action = ":ene | startinsert" },
        { icon = "検", key = "g", desc = "Buscar texto", action = ":lua Snacks.picker.grep()" },
        { icon = "近", key = "r", desc = "Recientes", action = ":lua Snacks.picker.recent()" },
        { icon = "保", key = "s", desc = "Restaurar sesión", section = "session" },
        {
          icon = "設",
          key = "c",
          desc = "Configuración",
          action = ":lua Snacks.picker.files({ cwd = vim.fn.stdpath('config') })",
        },
        { icon = "具", key = "L", desc = "Complementos", action = ":Lazy" },
        { icon = "出", key = "q", desc = "Salir", action = ":qa" },
      },
    },
    formats = {
      icon = function(item)
        if item.file and (item.icon == "file" or item.icon == "directory") then
          -- 3 cells like the kanji, so paths start in the column of the labels
          local ic = Snacks.dashboard.icon(item.file, item.icon)
          ic.width = 3
          return ic
        end
        return { item.icon .. " ", width = 3, hl = "icon" }
      end,
      key = function(item) return { { "[", hl = "special" }, { item.key, hl = "key" }, { "]", hl = "special" } } end,
    },
    sections = sections,
  }
end

-- no cursor block over the first entry: the TUI hides the cursor when its highlight has blend=100
local saved_guicursor
local function hide()
  vim.api.nvim_set_hl(0, "OcHiddenCursor", { blend = 100, nocombine = true })
  saved_guicursor = saved_guicursor or vim.o.guicursor
  vim.o.guicursor = "a:OcHiddenCursor"
end
local function show()
  if saved_guicursor then vim.o.guicursor = saved_guicursor end
  saved_guicursor = nil
end
local function hide_cursor(buf)
  hide()
  vim.api.nvim_create_autocmd("BufEnter", { buffer = buf, callback = hide })
  vim.api.nvim_create_autocmd({ "BufLeave", "BufWipeout" }, { buffer = buf, callback = show })
end

function M.setup()
  local grp = vim.api.nvim_create_augroup("ocarina_dashboard", { clear = true })
  vim.api.nvim_create_autocmd("User", {
    pattern = "SnacksDashboardUpdatePost",
    group = grp,
    callback = function() vim.schedule(place_logo) end,
  })
  vim.api.nvim_create_autocmd("FileType", {
    pattern = "snacks_dashboard",
    group = grp,
    callback = function(ev) hide_cursor(ev.buf) end,
  })
end

return M
