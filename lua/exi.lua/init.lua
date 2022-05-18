local export = require"exi.lua.export"
local link = require"exi.lua.link"
local config = require"exi.lua.config"

local M = { }

M.setup = function(opts)
  config.setup(opts)
end

return M
