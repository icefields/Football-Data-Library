-- awesome/match_window.lua
-- AwesomeWM widget for displaying football data in a popup window with tabs
--
-- Usage in rc.lua:
--   local gears = require("gears")
--   local awesome_dir = gears.filesystem.get_configuration_dir()
--   package.path = awesome_dir .. "/football_widget/?.lua;" .. awesome_dir .. "/football_widget/?/init.lua;" .. package.path
--
--   local match_window = require("awesome.match_window")
--   local widget = match_window.create({
--     team_id = 108,  -- Inter Milan
--     awful = awful,
--     beautiful = beautiful,
--     wibox = wibox,
--     gears = gears,
--   })

local FootballData = require("football")
local View = require("football.view")

local match_window = {}

-- Team ID constants
match_window.TEAMS = {
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
}

-- Competition codes
match_window.COMPETITIONS = {
    { name = "Serie A", code = "SA" },
    { name = "Premier League", code = "PL" },
    { name = "La Liga", code = "PD" },
    { name = "Bundesliga", code = "BL1" },
    { name = "Champions League", code = "CL" },
}

-- Default configuration
local default_config = {
    team_id = 108,
    match_count = 10,
    show_scheduled = false,
    auto_refresh = true,
    refresh_interval = 300,  -- 5 minutes
    cache_timeout = 300,      -- Cache data for 5 minutes
}

-- Singleton for football app
local footballApp = nil

-- Cache storage
local cache = {
    matches = { data = nil, timestamp = 0 },
    standings = { data = nil, timestamp = 0, competition = nil },
}

-- Get or initialize football app
local function getFootballApp()
    if not footballApp then
        footballApp = FootballData.initialize()
    end
    return footballApp
end

-- Check if cache is valid
local function isCacheValid(cacheEntry, timeout)
    timeout = timeout or default_config.cache_timeout
    return cacheEntry.data and (os.time() - cacheEntry.timestamp) < timeout
end

-- Fetch team matches (with caching)
local function getTeamMatches(config)
    if isCacheValid(cache.matches) then
        return cache.matches.data
    end
    
    local success, result = pcall(function()
        local app = getFootballApp()
        return app.service:getTeamScores(config.team_id, config.match_count, config.show_scheduled)
    end)
    
    if success and result then
        cache.matches.data = result
        cache.matches.timestamp = os.time()
        return result
    else
        return nil, result
    end
end

-- Fetch standings (with caching)
local function getStandings(competitionCode)
    if isCacheValid(cache.standings) and cache.standings.competition == competitionCode then
        return cache.standings.data
    end
    
    local success, result = pcall(function()
        local app = getFootballApp()
        return app.service:getStandings(competitionCode)
    end)
    
    if success and result then
        cache.standings.data = result
        cache.standings.timestamp = os.time()
        cache.standings.competition = competitionCode
        return result
    else
        return nil, result
    end
end

-- Create the match window widget
-- @param args table - Widget configuration
-- @return wibox.widget, table - The widget and controls table
function match_window.create(args)
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
    
    if not awful or not beautiful or not wibox or not gears then
        error("match_window requires 'awful', 'beautiful', 'wibox', and 'gears' modules")
    end
    
    local font = args.font or beautiful.font
    local currentCompetition = config.competitions and config.competitions[1] or match_window.COMPETITIONS[1]
    local iconFont = args.icon_font or "Symbols Nerd Font Mono 14"
    
    -- Current tab: "scores" or "standings"
    local currentTab = "scores"
    
    -- Create the button widget (icon in wibar)
    local button = wibox.widget {
        {
            id = "icon",
            text = args.icon or "",  -- Soccer ball Nerd Font icon
            widget = wibox.widget.textbox,
            align = "center",
            valign = "center",
            font = iconFont
        },
        widget = wibox.container.background,
        bg = "#00000000",
        fg = beautiful.fg_normal or "#ffffff",
        shape = gears.shape.rounded_bar,
        forced_height = beautiful.wibar_height or 24
    }
    
    -- Create content text widget (shared by both tabs)
    local contentText = wibox.widget {
        id = "content",
        text = "Click a tab to load data...",
        widget = wibox.widget.textbox,
        font = args.font or beautiful.font,
        fg = beautiful.fg_normal or "#ffffff",
        forced_width = 550,
    }
    
    -- Create tab buttons
    local scoresTab = wibox.widget {
        {
            id = "label",
            text = "📊 Results",
            widget = wibox.widget.textbox,
            align = "center",
            font = font
        },
        bg = beautiful.bg_focus or "#3a3a5a",
        fg = beautiful.fg_normal or "#ffffff",
        widget = wibox.container.background,
        forced_width = 150,
        forced_height = 30,
    }
    
    local standingsTab = wibox.widget {
        {
            id = "label",
            text = "🏆 Standings",
            widget = wibox.widget.textbox,
            align = "center",
            font = font
        },
        bg = beautiful.bg_normal or "#1a1a2e",
        fg = beautiful.fg_normal or "#ffffff",
        widget = wibox.container.background,
        forced_width = 150,
        forced_height = 30,
    }
    
    -- Competition selector dropdown
    local competitionButtons = wibox.widget {
        layout = wibox.layout.flex.horizontal,
        spacing = 2,
    }
    
    local competitions = args.competitions or match_window.COMPETITIONS
    
    -- Forward declaration for popup (needed for close button)
    local popup = nil
    
    -- Tab switching logic
    local function setActiveTab(tab)
        currentTab = tab
        if tab == "scores" then
            scoresTab.bg = beautiful.bg_focus or "#3a3a5a"
            standingsTab.bg = beautiful.bg_normal or "#1a1a2e"
            if popup then
                local container = popup.widget:get_children_by_id("competitionContainer")[1]
                if container then container.visible = false end
            end
            updateContent()
        else
            scoresTab.bg = beautiful.bg_normal or "#1a1a2e"
            standingsTab.bg = beautiful.bg_focus or "#3a3a5a"
            if popup then
                local container = popup.widget:get_children_by_id("competitionContainer")[1]
                if container then container.visible = true end
            end
            updateContent()
        end
    end
    
    -- Update content based on current tab
    local function updateContent()
        contentText.text = "Loading..."
        
        if currentTab == "scores" then
            local matches, err = getTeamMatches(config)
            if matches and #matches > 0 then
                contentText.text = View.getMatchesString(matches, true)
            elseif err then
                contentText.text = "Error: " .. tostring(err)
            else
                contentText.text = "No matches found"
            end
        else
            local standings, err = getStandings(currentCompetition.code)
            if standings and #standings > 0 then
                contentText.text = View.getStandingsString(standings, currentCompetition.name)
            elseif err then
                contentText.text = "Error: " .. tostring(err)
            else
                contentText.text = "No standings found"
            end
        end
    end
    
    -- Create the popup window
    popup = awful.popup {
        visible = false,
        ontop = true,
        placement = awful.placement.centered,
        minimum_width = 600,
        maximum_width = 600,
        minimum_height = 500,
        widget = wibox.widget {
            layout = wibox.layout.fixed.vertical,
            -- Header with close button
            {
                {
                    {
                        {
                            text = "  Football",
                            widget = wibox.widget.textbox,
                            font = iconFont
                        },
                        nil,
                        {
                            id = "closeBtn",
                            text = "✕",
                            widget = wibox.widget.textbox,
                            font = font,
                            align = "center",
                            valign = "center",
                            forced_width = 24,
                            forced_height = 24,
                            buttons = gears.table.join(
                                awful.button({}, 1, function()
                                    popup.visible = false
                                end)
                            )
                        },
                        layout = wibox.layout.align.horizontal,
                    },
                    widget = wibox.container.margin,
                    margins = 8,
                },
                bg = beautiful.bg_focus or "#3a3a5a",
                fg = beautiful.fg_normal or "#ffffff",
                widget = wibox.container.background,
            },
            -- Tab bar
            {
                {
                    scoresTab,
                    standingsTab,
                    layout = wibox.layout.flex.horizontal,
                    spacing = 2,
                },
                widget = wibox.container.margin,
                margins = { left = 8, right = 8, top = 4, bottom = 4 }
            },
            -- Competition selector (for standings tab)
            {
                id = "competitionContainer",
                competitionButtons,
                widget = wibox.container.margin,
                margins = { left = 8, right = 8, bottom = 4 },
                visible = false,
            },
            -- Content area
            {
                {
                    contentText,
                    widget = wibox.container.background,
                    bg = beautiful.bg_normal or "#1a1a2e",
                    forced_height = 400,
                },
                widget = wibox.container.margin,
                margins = 8,
            },
        }
    }
    
    -- Populate competition buttons
    for _, comp in ipairs(competitions) do
        local compBtn = wibox.widget {
            {
                text = comp.name,
                widget = wibox.widget.textbox,
                align = "center",
                font = font
            },
            bg = comp.code == currentCompetition.code and (beautiful.bg_focus or "#3a3a5a") or (beautiful.bg_normal or "#1a1a2e"),
            fg = beautiful.fg_normal or "#ffffff",
            widget = wibox.container.background,
            forced_width = 80,
            buttons = gears.table.join(
                awful.button({}, 1, function()
                    currentCompetition = comp
                    -- Update button highlights
                    for _, btn in ipairs(competitionButtons.children) do
                        btn.bg = beautiful.bg_normal or "#1a1a2e"
                    end
                    compBtn.bg = beautiful.bg_focus or "#3a3a5a"
                    -- Refresh standings
                    updateContent()
                end)
            )
        }
        compBtn:connect_signal("mouse::enter", function(c)
            c.bg = beautiful.bg_urgent or "#5a5a8a"
        end)
        compBtn:connect_signal("mouse::leave", function(c)
            if comp.code == currentCompetition.code then
                c.bg = beautiful.bg_focus or "#3a3a5a"
            else
                c.bg = beautiful.bg_normal or "#1a1a2e"
            end
        end)
        competitionButtons:add(compBtn)
    end
    
    -- Tab click handlers
    scoresTab:buttons(gears.table.join(
        awful.button({}, 1, function()
            setActiveTab("scores")
            updateContent()
        end)
    ))
    
    standingsTab:buttons(gears.table.join(
        awful.button({}, 1, function()
            setActiveTab("standings")
            updateContent()
        end)
    ))
    
    -- Hover effects for tabs
    scoresTab:connect_signal("mouse::enter", function(c)
        if currentTab ~= "scores" then
            c.bg = beautiful.bg_urgent or "#5a5a8a"
        end
    end)
    scoresTab:connect_signal("mouse::leave", function(c)
        if currentTab ~= "scores" then
            c.bg = beautiful.bg_normal or "#1a1a2e"
        end
    end)
    
    standingsTab:connect_signal("mouse::enter", function(c)
        if currentTab ~= "standings" then
            c.bg = beautiful.bg_urgent or "#5a5a8a"
        end
    end)
    standingsTab:connect_signal("mouse::leave", function(c)
        if currentTab ~= "standings" then
            c.bg = beautiful.bg_normal or "#1a1a2e"
        end
    end)
    
    -- Button click handler
    button:buttons(gears.table.join(
        awful.button({}, 1, function()
            if popup.visible then
                popup.visible = false
            else
                setActiveTab("scores")  -- Reset to scores tab and load data
                popup.visible = true
            end
        end)
    ))
    
    -- Hover effect for button
    button:connect_signal("mouse::enter", function(c)
        c.bg = beautiful.bg_focus or "#3a3a5a"
    end)
    button:connect_signal("mouse::leave", function(c)
        c.bg = nil
    end)
    
    -- Auto-refresh timer
    local refresh_timer = nil
    if config.auto_refresh then
        refresh_timer = gears.timer {
            timeout = config.refresh_interval,
            autostart = true,
            call_now = false,
            callback = function()
                -- Invalidate cache to force refresh
                cache.matches.timestamp = 0
                cache.standings.timestamp = 0
                if popup.visible then
                    updateContent()
                end
            end
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
    
    return wibox.container.margin(button, 2, 2, 0, 0), {
        popup = popup,
        refresh = updateContent,
        timer = refresh_timer,
        setTeamId = function(teamId)
            config.team_id = teamId
            cache.matches.timestamp = 0  -- Invalidate cache
            if popup.visible and currentTab == "scores" then
                updateContent()
            end
        end,
        setCompetition = function(code)
            for _, comp in ipairs(competitions) do
                if comp.code == code then
                    currentCompetition = comp
                    cache.standings.timestamp = 0  -- Invalidate cache
                    if popup.visible and currentTab == "standings" then
                        updateContent()
                    end
                    break
                end
            end
        end,
    }
end

return match_window