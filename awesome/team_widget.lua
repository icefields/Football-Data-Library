-- awesome/team_widget.lua
-- AwesomeWM widget for displaying team match results
--
-- Usage in rc.lua:
--   package.path = "/path/to/Football-Data-Library/?.lua;/path/to/Football-Data-Library/?/init.lua;" .. package.path
--   local football = require("football")
--   local team_widget = require("awesome.team_widget")
--   local widget = team_widget.create({
--     team_id = 108,  -- Inter Milan
--     awful = awful,
--     beautiful = beautiful,
--     wibox = wibox,
--     gears = gears,
--   })

local FootballData = require("football")
local View = require("football.view")

local team_widget = {}

-- Team ID constants for popular teams
team_widget.TEAMS = {
    INTER_MILAN = 108,
    AC_MILAN = 98,
    JUVENTUS = 109,
    NAPOLI = 113,
    ROMA = 100,
    LAZIO = 110,
    ARSENAL = 57,
    CHELSEA = 61,
    MAN_UNITED = 66,
    MAN_CITY = 65,
    LIVERPOOL = 64,
    TOTTENHAM = 73,
    BARCELONA = 81,
    REAL_MADRID = 86,
    ATLETICO_MADRID = 78,
    BAYERN_MUNICH = 5,
    DORTMUND = 165,
    PSG = 85,
    LYON = 523,
    MARSEILLE = 516,
}

-- Default configuration
local default_config = {
    team_id = 108,
    match_count = 10,
    show_scheduled = false,
    show_competition = true,
    auto_refresh = true,
    refresh_interval = 300,
}

-- Singleton for football app
local footballApp = nil

-- Get or initialize football app
local function getFootballApp()
    if not footballApp then
        footballApp = FootballData.initialize()
    end
    return footballApp
end

-- Fetch team matches
local function getTeamMatches(config)
    local success, result = pcall(function()
        local app = getFootballApp()
        return app.service:getTeamScores(config.team_id, config.match_count, config.show_scheduled)
    end)
    
    if success and result then
        return result
    else
        return nil, result
    end
end

-- Create team widget
-- @param args table - Widget configuration
-- @return wibox.widget, table - The widget and controls table
function team_widget.create(args)
    args = args or {}
    
    -- Merge config with defaults
    local config = {}
    for k, v in pairs(default_config) do
        config[k] = args[k] ~= nil and args[k] or v
    end
    
    -- Required modules
    local awful = args.awful
    local beautiful = args.beautiful
    local wibox = args.wibox
    local gears = args.gears
    
    -- Validate required modules
    if not awful or not beautiful or not wibox or not gears then
        error("team_widget requires 'awful', 'beautiful', 'wibox', and 'gears' modules")
    end
    
    -- Widget icon
    local icon = args.icon or "⚽"
    local font = args.font or beautiful.font
    
    -- Create button widget
    local button = wibox.widget {
        {
            id = "icon",
            text = icon,
            widget = wibox.widget.textbox,
            align = "center",
            valign = "center",
            font = font
        },
        widget = wibox.container.background,
        bg = "#00000000",
        fg = beautiful.fg_normal or "#ffffff",
        shape = gears.shape.rounded_bar,
        forced_height = beautiful.wibar_height or 24
    }
    
    -- Create tooltip
    local tooltip = awful.tooltip {
        objects = { button },
        mode = "outside",
        align = "top",
        margin_leftright = 8,
        margin_topbottom = 4,
        preferred_positions = { "top", "bottom" },
        text = "Loading...",
        bg = args.tooltip_bg or beautiful.bg_normal or "#1a1a2e",
        fg = args.tooltip_fg or beautiful.fg_normal or "#ffffff",
        font = font
    }
    
    -- Update tooltip with match data
    local function updateTooltip()
        tooltip.text = "Loading..."
        
        local matches, err = getTeamMatches(config)
        
        if matches and #matches > 0 then
            local text = View.getMatchesString(matches, config.show_competition)
            tooltip.text = text
        elseif err then
            tooltip.text = "Error: " .. tostring(err)
        else
            tooltip.text = "No matches found"
        end
    end
    
    -- Mouse hover
    button:connect_signal("mouse::enter", function(c)
        c.bg = beautiful.bg_focus or "#3a3a5a"
        updateTooltip()
    end)
    
    -- Mouse leave
    button:connect_signal("mouse::leave", function(c)
        c.bg = nil
    end)
    
    -- Button press (refresh)
    button:connect_signal("button::press", function()
        button.bg = nil
        tooltip.text = "Refreshing..."
        updateTooltip()
    end)
    
    button:connect_signal("button::release", function(c)
        c.bg = beautiful.bg_focus or "#3a3a5a"
    end)
    
    -- Auto-refresh timer
    local refresh_timer = nil
    if config.auto_refresh then
        refresh_timer = gears.timer {
            timeout = config.refresh_interval,
            autostart = true,
            call_now = false,
            callback = updateTooltip
        }
    end
    
    -- Cleanup on exit
    awesome.connect_signal("exit", function()
        if refresh_timer then
            refresh_timer:stop()
        end
        if footballApp then
            footballApp.database:close()
        end
    end)
    
    -- Return widget with margin and controls
    return wibox.container.margin(button, 2, 2, 0, 0), {
        refresh = updateTooltip,
        timer = refresh_timer
    }
end

return team_widget