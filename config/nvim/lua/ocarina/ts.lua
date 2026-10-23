-- Tree-sitter queries of our own (used by lua/plugins/treesitter.lua and :checkhealth ocarina).
local M = {}

-- QML only needs regex literals injected (see lua/plugins/treesitter.lua)
M.qml_injections = '((regex_pattern) @injection.content (#set! injection.language "regex"))'

return M
