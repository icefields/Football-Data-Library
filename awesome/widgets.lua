-- awesome/widgets.lua
-- AwesomeWM widget module loader for football-lua library
--
-- Usage in rc.lua:
--   local gears = require("gears")
--   local awesome_dir = gears.filesystem.get_configuration_dir()
--   package.path = awesome_dir .. "/football_widget/?.lua;" .. awesome_dir .. "/football_widget/?/init.lua;" .. package.path
--
--   local widgets = require("awesome.widgets")
--   local match_window = widgets.match_window.create({...})
--   -- or:
--   local match_window = require("awesome.match_window")
--   local widget = match_window.create({...})

local team_widget = require("awesome.team_widget")
local standings_widget = require("awesome.standings_widget")
local match_window = require("awesome.match_window")

return {
    team_widget = team_widget,
    standings_widget = standings_widget,
    match_window = match_window,
}