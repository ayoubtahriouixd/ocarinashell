-- Live link with the shell. Watches ~/.local/state/ocarinashell/theme/ (the directory: ocarina-theme replaces files
-- atomically with a rename, which would orphan a watch on the file itself):
--   palette.lua  → re-applies the colourscheme (theme change, accent from the wallpaper…)
--   effects.json → {cursor, motion} written by the shell (services/TermFx.qml):
--                  cursor = AC power, outside 忍 Shinobi, motion allowed → smear-cursor, except in Ghostty: its
--                           墨 ink-cursor shader already draws the trail there (two trails would fight, D-055)
--                  motion = outside Shinobi, motion allowed               → smooth scroll, snacks animations
local M = {}

local dir = require("ocarina.palette").dir
local effects_file = dir .. "/effects.json"
local state -- { cursor = bool, motion = bool }
local in_ghostty = vim.env.TERM_PROGRAM == "ghostty" or vim.env.TERM == "xterm-ghostty"

local function read_effects()
  local fd = io.open(effects_file, "r")
  if not fd then return { cursor = false, motion = true } end
  local ok, data = pcall(vim.json.decode, fd:read("*a"))
  fd:close()
  if not ok or type(data) ~= "table" then return { cursor = false, motion = true } end
  return { cursor = data.cursor == true, motion = data.motion ~= false }
end

--- current effects (read once, then kept up to date by the watcher)
function M.state()
  if not state then
    state = read_effects()
    vim.g.snacks_animate = state.motion
  end
  return state
end

local function apply_effects()
  local s = M.state()
  vim.g.snacks_animate = s.motion
  local snacks = package.loaded["snacks"]
  if snacks and snacks.scroll then
    if s.motion then
      snacks.scroll.enable()
    else
      snacks.scroll.disable()
    end
  end
  local smear = package.loaded["smear_cursor"]
  local trail = s.cursor and not in_ghostty
  if trail and not smear then
    pcall(function() require("lazy").load({ plugins = { "smear-cursor.nvim" } }) end)
  elseif smear then
    smear.enabled = trail
  end
end
M.apply_effects = apply_effects

local pending = {}
local timer

local function flush()
  local p = pending
  pending = {}
  if p.palette then
    local ok, err = pcall(vim.cmd.colorscheme, "ocarina")
    if not ok then vim.notify("Tema: " .. tostring(err), vim.log.levels.WARN) end
  end
  if p.effects then
    local new = read_effects()
    if not state or new.cursor ~= state.cursor or new.motion ~= state.motion then
      state = new
      apply_effects()
    end
  end
end

function M.setup()
  M.state()
  -- smear-cursor and the scroll start after the first screen (VeryLazy), never in the start-up path
  vim.api.nvim_create_autocmd("User", {
    pattern = "VeryLazy",
    once = true,
    callback = apply_effects,
  })
  local w = vim.uv.new_fs_event()
  if not w then return end
  timer = assert(vim.uv.new_timer())
  local ok = w:start(dir, {}, function(err, fname)
    if err or not fname then return end
    if fname == "palette.lua" then
      pending.palette = true
    elseif fname == "effects.json" then
      pending.effects = true
    else
      return
    end
    -- one apply per burst of events (write + rename)
    timer:stop()
    timer:start(80, 0, vim.schedule_wrap(flush))
  end)
  if not ok then w:close() end
end

return M
