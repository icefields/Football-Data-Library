-- awesome/init.lua
-- AwesomeWM widget module loader for football-lua library
-- 
-- Usage in rc.lua:
--   package.path = os.getenv("HOME") .. "/.config/awesome/football_widget/?.lua;" .. package.path
--   local football_widgets = require("awesome")
--   local team_widget = football_widgets.team_widget.create({...})

local team_widget = require("awesome.team_widget")
local standings_widget = require("awesome.standings_widget")

return {
    team_widget = team_widget,
    standings_widget = standings_widget
}