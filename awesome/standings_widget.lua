-- awesome/standings_widget.lua
-- AwesomeWM widget for displaying league standings with competition selection
--
-- Usage in rc.lua:
--   package.path = "/path/to/Football-Data-Library/?.lua;/path/to/Football-Data-Library/?/init.lua;" .. package.path
--   local football = require("football")
--   local standings_widget = require("awesome.standings_widget")
--   local widget = standings_widget.create({
--     awful = awful,
--     beautiful = beautiful,
--     wibox = wibox,
--     gears = gears,
--   })

local FootballData = require("football")
local View = require("football.view")

local standings_widget = {}

-- Competition codes
standings_widget.COMPETITIONS = {
    SERIE_A = "SA",
    PREMIER_LEAGUE = "PL",
    LA_LIGA = "PD",
    BUNDESLIGA = "BL1",
    LIGUE_1 = "FL1",
    CHAMPIONS_LEAGUE = "CL",
    WORLD_CUP = "WC",
}

-- Default configuration
local default_config = {
    show_competition = true,
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

-- Fetch standings
local function getStandings(config)
    local success, result = pcall(function()
        local app = getFootballApp()
        return app.service:getStandings(config.competition)
    end)
    
    if success and result then
        return result
    else
        return nil, result
    end
end

-- Create standings widget with multiple competition buttons
-- @param args table - Widget configuration
-- @return wibox.widget, table - The widget and controls table
function standings_widget.create(args)
    args = args or {}
    
    -- Required modules
    local awful = args.awful
    local beautiful = args.beautiful
    local wibox = args.wibox
    local gears = args.gears
    
    if not awful or not beautiful or not wibox or not gears then
        error("standings_widget requires 'awful', 'beautiful', 'wibox', and 'gears' modules")
    end
    
    -- Available competitions
    local competitions = args.competitions or {
        { name = "Serie A", code = "SA" },
        { name = "Premier League", code = "PL" },
        { name = "La Liga", code = "PD" },
        { name = "Bundesliga", code = "BL1" },
        { name = "Champions League", code = "CL" },
    }
    
    -- Current competition
    local currentCompetition = competitions[1]
    
    -- Create main button
    local button = wibox.widget {
        {
            id = "icon",
            text = args.icon or "🏆",
            widget = wibox.widget.textbox,
            align = "center",
            valign = "center",
            font = args.font or beautiful.font
        },
        widget = wibox.container.background,
        bg = "#00000000",
        fg = beautiful.fg_normal or "#ffffff",
        shape = gears.shape.rounded_bar,
        forced_height = beautiful.wibar_height or 24
    }
    
    -- Create popup
    local popup = awful.popup {
        visible = false,
        ontop = true,
        placement = awful.placement.centered,
        widget = wibox.widget {
            {
                {
                    -- Competition buttons
                    {
                        id = "buttons_container",
                        layout = wibox.layout.flex.horizontal,
                        spacing = 4,
                    },
                    widget = wibox.container.margin,
                    margins = 4,
                },
                {
                    -- Standings content
                    {
                        id = "content",
                        text = "Select a competition",
                        widget = wibox.widget.textbox,
                        font = args.font or beautiful.font,
                    },
                    widget = wibox.container.margin,
                    margins = 8,
                },
                layout = wibox.layout.align.vertical
            },
            bg = args.popup_bg or beautiful.bg_normal or "#1a1a2e",
            fg = args.popup_fg or beautiful.fg_normal or "#ffffff",
            widget = wibox.container.background
        }
    }
    
    -- Update standings display
    local function updateStandings(competitionCode, competitionName)
        popup.widget.content.text = "Loading..."
        
        local standings, err = getStandings({ competition = competitionCode })
        
        if standings and #standings > 0 then
            local text = View.getStandingsString(standings, competitionName)
            popup.widget.content.text = text
        elseif err then
            popup.widget.content.text = "Error: " .. tostring(err)
        else
            popup.widget.content.text = "No standings found"
        end
    end
    
    -- Create competition buttons
    for _, comp in ipairs(competitions) do
        local compButton = wibox.widget {
            {
                id = "label",
                text = comp.name,
                widget = wibox.widget.textbox,
                align = "center",
                font = args.font or beautiful.font
            },
            bg = beautiful.bg_focus or "#3a3a5a",
            fg = beautiful.fg_normal or "#ffffff",
            widget = wibox.container.background,
            buttons = gears.table.join(
                awful.button({}, 1, function()
                    currentCompetition = comp
                    updateStandings(comp.code, comp.name)
                end)
            )
        }
        
        -- Hover effect
        compButton:connect_signal("mouse::enter", function(c)
            c.bg = beautiful.bg_urgent or "#5a5a8a"
        end)
        compButton:connect_signal("mouse::leave", function(c)
            c.bg = beautiful.bg_focus or "#3a3a5a"
        end)
        
        popup.widget.buttons_container:add(compButton)
    end
    
    -- Toggle popup on button click
    button:buttons(gears.table.join(
        awful.button({}, 1, function()
            if popup.visible then
                popup.visible = false
            else
                updateStandings(currentCompetition.code, currentCompetition.name)
                popup.visible = true
            end
        end)
    ))
    
    -- Hover effect
    button:connect_signal("mouse::enter", function(c)
        c.bg = beautiful.bg_focus or "#3a3a5a"
    end)
    button:connect_signal("mouse::leave", function(c)
        c.bg = nil
    end)
    
    -- Cleanup on exit
    awesome.connect_signal("exit", function()
        if footballApp then
            footballApp.database:close()
        end
    end)
    
    return wibox.container.margin(button, 2, 2, 0, 0), {
        popup = popup,
        update = function(code, name)
            updateStandings(code, name)
        end
    }
end

return standings_widget