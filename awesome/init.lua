-- awesome/init.lua
-- AwesomeWM widget module loader for football-lua library

local team_widget = require("football_widget.awesome.team_widget")
local standings_widget = require("football_widget.awesome.standings_widget")

return {
    team_widget = team_widget,
    standings_widget = standings_widget
}

