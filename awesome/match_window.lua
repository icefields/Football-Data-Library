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
local cjson = require("cjson")

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
    cache_file = os.getenv("HOME") .. "/.cache/football_data.json",  -- Persistent cache
}

-- Singleton for football app
local footballApp = nil

-- In-memory cache
local cache = {
    matches = { data = nil, timestamp = 0 },
    standings = { data = nil, timestamp = 0, competition = nil },
}

-- Load cache from file
local function loadCacheFromFile(cacheFile)
    local file = io.open(cacheFile, "r")
    if not file then
        return { matches = { data = nil, timestamp = 0 }, standings = { data = nil, timestamp = 0, competition = nil } }
    end
    
    local content = file:read("*all")
    file:close()
    
    local success, data = pcall(function()
        return require("cjson").decode(content)
    end)
    
    if success and data then
        return {
            matches = data.matches or { data = nil, timestamp = 0 },
            standings = data.standings or { data = nil, timestamp = 0, competition = nil },
        }
    end
    
    return { matches = { data = nil, timestamp = 0 }, standings = { data = nil, timestamp = 0, competition = nil } }
end

-- Save cache to file
local function saveCacheToFile(cacheFile, cacheData)
    local file = io.open(cacheFile, "w")
    if not file then
        return false
    end
    
    -- Create directory if it doesn't exist
    local cacheDir = cacheFile:match("^(.*)/[^/]+$")
    if cacheDir then
        os.execute("mkdir -p " .. cacheDir)
    end
    
    local success, content = pcall(function()
        return require("cjson").encode({
            matches = cacheData.matches,
            standings = cacheData.standings,
        })
    end)
    
    if success and content then
        file:write(content)
        file:close()
        return true
    end
    
    file:close()
    return false
end

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

-- Initialize cache from file on first use
local function ensureCacheLoaded(cacheFile)
    if cache.matches.timestamp == 0 and cache.standings.timestamp == 0 then
        local fileCache = loadCacheFromFile(cacheFile)
        if fileCache then
            cache = fileCache
        end
    end
end

-- Fetch team matches (with caching)
local function getTeamMatches(config, cacheFile)
    ensureCacheLoaded(cacheFile)
    
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
        saveCacheToFile(cacheFile, cache)
        return result
    else
        return nil, result
    end
end

-- Fetch standings (with caching)
local function getStandings(competitionCode, cacheFile)
    ensureCacheLoaded(cacheFile)
    
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
        saveCacheToFile(cacheFile, cache)
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
    
    -- Color scheme (customizable via args.colors)
    local colors = args.colors or {
        -- Text colors
        text = "#ffffff",
        text_dim = "#aaaaaa",
        
        -- Icon colors
        icon_color = "#ffffff",      -- Football icon color
        icon_hover = "#3a3a5a",      -- Icon hover background
        
        -- Tab colors
        tab_active = "#3a3a5a",
        tab_inactive = "#1a1a2e",
        tab_hover = "#5a5a8a",
        
        -- Background colors
        bg_header = "#3a3a5a",
        bg_tab_bar = "#0d0d1a",
        bg_content = "#1a1a2e",
        bg_button = "#00000000",
        
        -- Button padding (for wibar icon)
        button_margin_top = 2,
        button_margin_bottom = 2,
        button_margin_left = 2,
        button_margin_right = 2,
        
        -- Icon padding (inside button)
        icon_padding_top = 2,
        icon_padding_bottom = 2,
        icon_padding_left = 4,
        icon_padding_right = 4,
    }
    
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
            {
                id = "icon",
                text = args.icon or "󰒸",  -- Nerd Font soccer/football icon
                widget = wibox.widget.textbox,
                align = "center",
                valign = "center",
                font = iconFont
            },
            widget = wibox.container.margin,
            top = colors.icon_padding_top,
            bottom = colors.icon_padding_bottom,
            left = colors.icon_padding_left,
            right = colors.icon_padding_right,
        },
        widget = wibox.container.background,
        bg = colors.bg_button,
        fg = colors.icon_color,
        shape = gears.shape.rounded_bar,
        forced_height = beautiful.wibar_height or 24
    }
    
    -- Wrap button in margin container for spacing
    local buttonContainer = wibox.widget {
        button,
        widget = wibox.container.margin,
        top = colors.button_margin_top,
        bottom = colors.button_margin_bottom,
        left = colors.button_margin_left,
        right = colors.button_margin_right,
    }
    
    -- Create content text widget (shared by both tabs)
    local contentText = wibox.widget {
        id = "content",
        text = "Click a tab to load data...",
        widget = wibox.widget.textbox,
        font = args.font or beautiful.font,
        fg = colors.text,
        forced_width = 650,
    }
    
    -- Create tab buttons
    local scoresTab = wibox.widget {
        {
            id = "label",
            text = "📊 Results",
            widget = wibox.widget.textbox,
            align = "center",
            valign = "center",
            font = font
        },
        bg = colors.tab_active,
        fg = colors.text,
        widget = wibox.container.background,
        forced_width = 150,
        forced_height = 30,
        shape = gears.shape.rounded_rect,
        shape_border_width = 0,
    }
    
    local standingsTab = wibox.widget {
        {
            id = "label",
            text = "🏆 Standings",
            widget = wibox.widget.textbox,
            align = "center",
            valign = "center",
            font = font
        },
        bg = colors.tab_inactive,
        fg = colors.text,
        widget = wibox.container.background,
        forced_width = 150,
        forced_height = 30,
        shape = gears.shape.rounded_rect,
        shape_border_width = 0,
    }
    
    -- Competition selector dropdown
    local competitionButtons = wibox.widget {
        layout = wibox.layout.flex.horizontal,
        spacing = 2,
    }
    
    local competitions = args.competitions or match_window.COMPETITIONS
    
    -- Forward declaration for popup (needed for close button)
    local popup = nil
    
    -- Forward declaration for updateContent (needed for setActiveTab)
    local updateContent = nil
    
    -- Cache file path
    local cacheFile = config.cache_file or default_config.cache_file
    
    -- Path to fetch script (same directory as this file)
    local fetchScript = debug.getinfo(1, "S").source:match("^@(.+/)match_window%.lua$") .. "fetch_data.lua"
    
    -- Update content based on current tab (async version)
    updateContent = function()
        -- Load cache first to show immediately if available
        ensureCacheLoaded(cacheFile)
        
        -- Show cached data immediately if available
        if currentTab == "scores" and cache.matches.data then
            contentText.text = View.getMatchesString(cache.matches.data, true)
        elseif currentTab == "standings" and cache.standings.data then
            contentText.text = View.getStandingsString(cache.standings.data, currentCompetition.name)
        else
            contentText.text = "Loading..."
        end
        
        -- Check if cache is still valid (no need to fetch)
        if currentTab == "scores" and isCacheValid(cache.matches) then
            return  -- Cache is fresh, no need to fetch
        end
        if currentTab == "standings" and isCacheValid(cache.standings) and cache.standings.competition == currentCompetition.code then
            return  -- Cache is fresh, no need to fetch
        end
        
        -- Build command for async fetch
        local cmd = string.format(
            "cd %s && lua %s %s %d %d %s",
            fetchScript:match("^(.+)/[^/]+$") or ".",
            fetchScript,
            cacheFile,
            config.team_id,
            config.match_count,
            currentCompetition.code
        )
        
        -- Run async
        awful.spawn.easy_async(cmd, function(stdout, stderr, exitreason, exitcode)
            if exitcode ~= 0 then
                -- Only show error if we don't have cached data
                if not cache.matches.data and not cache.standings.data then
                    contentText.text = "Error: " .. (stderr or "fetch failed")
                end
                return
            end
            
            local success, data = pcall(function()
                return cjson.decode(stdout)
            end)
            
            if not success or not data then
                return
            end
            
            -- Update in-memory cache
            if data.matches and data.matches.data then
                cache.matches = data.matches
            end
            if data.standings and data.standings.data then
                cache.standings = data.standings
            end
            
            -- Save to file
            saveCacheToFile(cacheFile, cache)
            
            -- Update display if still on same tab
            if currentTab == "scores" and cache.matches.data then
                contentText.text = View.getMatchesString(cache.matches.data, true)
            elseif currentTab == "standings" and cache.standings.data then
                contentText.text = View.getStandingsString(cache.standings.data, currentCompetition.name)
            end
        end)
    end
    
    -- Tab switching logic
    local function setActiveTab(tab)
        currentTab = tab
        if tab == "scores" then
            scoresTab.bg = colors.tab_active
            standingsTab.bg = colors.tab_inactive
            if popup then
                local container = popup.widget:get_children_by_id("competitionContainer")[1]
                if container then container.visible = false end
            end
            updateContent()
        else
            scoresTab.bg = colors.tab_inactive
            standingsTab.bg = colors.tab_active
            if popup then
                local container = popup.widget:get_children_by_id("competitionContainer")[1]
                if container then container.visible = true end
            end
            updateContent()
        end
    end
    
    -- Create the popup window
    popup = awful.popup {
        visible = false,
        ontop = true,
        placement = awful.placement.centered,
        minimum_width = 700,
        maximum_width = 700,
        minimum_height = 550,
        widget = wibox.widget {
            layout = wibox.layout.fixed.vertical,
            -- Header with close button
            {
                {
                    {
                        {
                            text = "󰒸  Football",
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
                bg = colors.bg_header,
                fg = colors.text,
                widget = wibox.container.background,
            },
            -- Tab bar
            {
                {
                    {
                        scoresTab,
                        standingsTab,
                        layout = wibox.layout.fixed.horizontal,
                        spacing = 4,
                    },
                    widget = wibox.container.margin,
                    margins = 4,
                },
                widget = wibox.container.background,
                bg = colors.bg_tab_bar,
            },
            -- Competition selector (for standings tab)
            {
                id = "competitionContainer",
                {
                    competitionButtons,
                    widget = wibox.container.background,
                    bg = colors.bg_content,
                },
                widget = wibox.container.margin,
                margins = { left = 8, right = 8, bottom = 4, top = 4 },
                visible = false,
            },
            -- Content area
            {
                {
                    contentText,
                    widget = wibox.container.background,
                    bg = colors.bg_content,
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
                valign = "center",
                font = font
            },
            bg = comp.code == currentCompetition.code and colors.tab_active or colors.tab_inactive,
            fg = colors.text,
            widget = wibox.container.background,
            forced_width = 80,
            forced_height = 24,
            buttons = gears.table.join(
                awful.button({}, 1, function()
                    currentCompetition = comp
                    -- Update button highlights
                    for _, btn in ipairs(competitionButtons.children) do
                        btn.bg = colors.tab_inactive
                    end
                    compBtn.bg = colors.tab_active
                    -- Refresh standings
                    updateContent()
                end)
            )
        }
        compBtn:connect_signal("mouse::enter", function(c)
            c.bg = colors.tab_hover
        end)
        compBtn:connect_signal("mouse::leave", function(c)
            if comp.code == currentCompetition.code then
                c.bg = colors.tab_active
            else
                c.bg = colors.tab_inactive
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
            c.bg = colors.tab_hover
        end
    end)
    scoresTab:connect_signal("mouse::leave", function(c)
        if currentTab ~= "scores" then
            c.bg = colors.tab_inactive
        end
    end)
    
    standingsTab:connect_signal("mouse::enter", function(c)
        if currentTab ~= "standings" then
            c.bg = colors.tab_hover
        end
    end)
    standingsTab:connect_signal("mouse::leave", function(c)
        if currentTab ~= "standings" then
            c.bg = colors.tab_inactive
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
        c.bg = colors.icon_hover
    end)
    button:connect_signal("mouse::leave", function(c)
        c.bg = colors.bg_button
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
    
    return buttonContainer, {
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