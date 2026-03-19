-- init.lua
-- Convenience entry point - re-exports football module
-- Usage: local FootballData = require("football")

-- Get the directory where this module is located
local modulePath = debug.getinfo(1, "S").source:match("^@(.+)/init.lua$")
if modulePath then
    -- Add patterns for both file.lua and dir/init.lua styles
    package.path = modulePath .. "/?.lua;" .. modulePath .. "/?/init.lua;" .. package.path
end

return require("football")