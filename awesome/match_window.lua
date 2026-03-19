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
local default_config = require("awesome.awesome_config")

local match_window = {}

-- Re-export from config for backwards compatibility
match_window.TEAMS = default_config.TEAMS
match_window.COMPETITIONS = default_config.COMPETITIONS

-- Singleton for football app
local footballApp = nil

-- In-memory cache
local cache = {
    matches = { data = nil, timestamp = 0 },
    standings = { data = nil, timestamp = 0, competition = nil },
    champions = { data = nil, timestamp = 0 },  -- Champions League matches
}

-- Load cache from file
local function loadCacheFromFile(cacheFile)
    local file = io.open(cacheFile, "r")
    if not file then
        return { 
            matches = { data = nil, timestamp = 0 }, 
            standings = { data = nil, timestamp = 0, competition = nil },
            champions = { data = nil, timestamp = 0 },
        }
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
            champions = data.champions or { data = nil, timestamp = 0 },
        }
    end

    return { 
        matches = { data = nil, timestamp = 0 }, 
        standings = { data = nil, timestamp = 0, competition = nil },
        champions = { data = nil, timestamp = 0 },
    }
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
            champions = cacheData.champions,
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
    timeout = timeout or default_config.defaults.cache_timeout
    return cacheEntry.data and (os.time() - cacheEntry.timestamp) < timeout
end

-- Initialize cache from file on first use
local function ensureCacheLoaded(cacheFile)
    if cache.matches.timestamp == 0 and cache.standings.timestamp == 0 and cache.champions.timestamp == 0 then
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

-- Fetch Champions League matches (all teams, with caching)
local function getChampionsLeague(cacheFile)
    ensureCacheLoaded(cacheFile)

    if isCacheValid(cache.champions) then
        return cache.champions.data
    end

    local success, result = pcall(function()
        local app = getFootballApp()
        local allMatches = app.service:getLatestScores("CL", false)
        -- Limit to configured count
        local limited = {}
        for i = 1, math.min(default_config.defaults.champions_match_count, #allMatches) do
            table.insert(limited, allMatches[i])
        end
        return limited
    end)

    if success and result then
        cache.champions.data = result
        cache.champions.timestamp = os.time()
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

    -- Use config defaults (can override via args.config)
    local cfg = args.config or default_config

    -- Color scheme (from config, can override via args.colors)
    local colors = args.colors or cfg.colors

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

    -- Fonts (from config or beautiful theme)
    local contentFont = args.font or cfg.fonts.content or beautiful.font
    local titleFont = beautiful.mainFont or contentFont
    local iconFontRaw = args.icon_font or cfg.fonts.icon or beautiful.topBar_button_font or beautiful.font
    local iconFontSize = tonumber(iconFontRaw:match("(%d+)$")) or 12
    local iconFontScaled = iconFontRaw:gsub("(%d+)$", tostring(math.floor(iconFontSize * cfg.fonts.icon_scale)))

    -- Icons (from config)
    local footballIcon = args.icon or cfg.icons.football

    -- Sizes (from config)
    local sizes = cfg.sizes
    local paddings = cfg.paddings

    local currentCompetition = args.competitions and args.competitions[1] or cfg.COMPETITIONS[1]

    -- Button size from beautiful theme or config
    local buttonSize = beautiful.topBar_buttonSize or beautiful.wibar_height or sizes.button_size

    -- Current tab: "scores", "standings", or "champions"
    local currentTab = "scores"

    local button = wibox.widget {
        {
            {
                id = "icon",
                text = footballIcon,
                widget = wibox.widget.textbox,
                align = "center",
                valign = "center",
                font = iconFontScaled,
            },
            widget = wibox.container.margin,
            margins = paddings.icon,
        },
        widget = wibox.container.background,
        bg = colors.bg_button,
        fg = colors.icon_color,
        shape = gears.shape.rounded_bar,
        forced_height = buttonSize,
    }

    -- Wrap button in margin container for spacing from bar edges
    local buttonContainer = wibox.widget {
        button,
        widget = wibox.container.margin,
        top = paddings.button_top,
        bottom = paddings.button_bottom,
        left = paddings.button_left,
        right = paddings.button_right,
    }

    -- Center the button vertically in the wibar
    local centeredButton = wibox.widget {
        buttonContainer,
        widget = wibox.container.place,
        valign = "center",
        halign = "center",
    }

    -- Create content text widget (shared by both tabs)
    local contentText = wibox.widget {
        id = "content",
        text = cfg.strings.click_to_load,
        widget = wibox.widget.textbox,
        font = contentFont,
        fg = colors.fg_text,
        forced_width = sizes.content_width,
    }

    -- Create tab buttons
    local scoresTab = wibox.widget {
        {
            id = "label",
            text = cfg.icons.results .. "  " .. cfg.strings.results,
            widget = wibox.widget.textbox,
            align = "center",
            valign = "center",
            font = contentFont
        },
        bg = colors.tab_active,
        fg = colors.fg_text,
        widget = wibox.container.background,
        forced_width = sizes.tab_width,
        forced_height = sizes.tab_height,
        shape = gears.shape.rounded_rect,
        shape_border_width = 0,
    }

    local standingsTab = wibox.widget {
        {
            id = "label",
            text = cfg.icons.standings .. "  " .. cfg.strings.standings,
            widget = wibox.widget.textbox,
            align = "center",
            valign = "center",
            font = contentFont
        },
        bg = colors.tab_inactive,
        fg = colors.fg_text,
        widget = wibox.container.background,
        forced_width = sizes.tab_width,
        forced_height = sizes.tab_height,
        shape = gears.shape.rounded_rect,
        shape_border_width = 0,
    }

    local championsTab = wibox.widget {
        {
            id = "label",
            text = cfg.icons.champions .. "  " .. cfg.strings.champions,
            widget = wibox.widget.textbox,
            align = "center",
            valign = "center",
            font = contentFont
        },
        bg = colors.tab_inactive,
        fg = colors.fg_text,
        widget = wibox.container.background,
        forced_width = sizes.tab_width,
        forced_height = sizes.tab_height,
        shape = gears.shape.rounded_rect,
        shape_border_width = 0,
    }

    -- Competition selector dropdown
    local competitionButtons = wibox.widget {
        layout = wibox.layout.flex.horizontal,
        spacing = 2,
    }

    local competitions = args.competitions or cfg.COMPETITIONS

    -- Forward declaration for popup (needed for close button)
    local popup = nil

    -- Forward declaration for updateContent (needed for setActiveTab)
    local updateContent = nil

    -- Cache file path
    local cacheFile = cfg.paths.cache_file

    -- Path to fetch script (same directory as this file)
    local fetchScript = debug.getinfo(1, "S").source:match("^@(.+/)match_window%.lua$") .. "fetch_data.lua"

    -- Update content based on current tab (async version)
    updateContent = function()
        -- Load cache first to show immediately if available
        ensureCacheLoaded(cacheFile)

        -- Show cached data immediately if available
        if currentTab == "scores" and cache.matches.data then
            local rawResults = View.getMatchesString(cache.matches.data, true)
            contentText.text = View.getFormattedResults(rawResults)
        elseif currentTab == "standings" and cache.standings.data then
            contentText.text = View.getStandingsString(cache.standings.data, currentCompetition.name)
        elseif currentTab == "champions" and cache.champions.data then
            local rawResults = View.getMatchesString(cache.champions.data, true)
            contentText.text = View.getFormattedResults(rawResults)
        else
            contentText.text = cfg.strings.loading
        end

        -- Check if cache is still valid (no need to fetch)
        if currentTab == "scores" and isCacheValid(cache.matches) then
            return  -- Cache is fresh, no need to fetch
        end
        if currentTab == "standings" and isCacheValid(cache.standings) and cache.standings.competition == currentCompetition.code then
            return  -- Cache is fresh, no need to fetch
        end
        if currentTab == "champions" and isCacheValid(cache.champions) then
            return  -- Cache is fresh, no need to fetch
        end

        -- Build command for async fetch
        local cmd
        if currentTab == "champions" then
            cmd = string.format(
                "cd %s && lua %s %s champions %s %d",
                fetchScript:match("^(.+)/[^/]+$") or ".",
                fetchScript,
                cacheFile,
                cfg.defaults.champions_league_code,
                cfg.defaults.champions_match_count
            )
        else
            cmd = string.format(
                "cd %s && lua %s %s %d %d %s",
                fetchScript:match("^(.+)/[^/]+$") or ".",
                fetchScript,
                cacheFile,
                cfg.defaults.team_id,
                cfg.defaults.match_count,
                currentCompetition.code
            )
        end

        -- Run async
        awful.spawn.easy_async(cmd, function(stdout, stderr, exitreason, exitcode)
            if exitcode ~= 0 then
                -- Only show error if we don't have cached data
                if not cache.matches.data and not cache.standings.data and not cache.champions.data then
                    contentText.text = "Error: " .. (stderr or "fetch failed") .. " (code: " .. tostring(exitcode) .. ")"
                end
                return
            end

            local success, data = pcall(function()
                return cjson.decode(stdout)
            end)

            if not success then
                contentText.text = "JSON parse error"
                return
            end
            
            if not data then
                contentText.text = "No data received"
                return
            end

            -- Update in-memory cache
            if data.matches and data.matches.data then
                cache.matches = data.matches
            end
            if data.standings and data.standings.data then
                cache.standings = data.standings
            end
            if data.champions and data.champions.data then
                cache.champions = data.champions
            end

            -- Save to file
            saveCacheToFile(cacheFile, cache)

            -- Update display if still on same tab
            if currentTab == "scores" and cache.matches.data then
                local rawResults = View.getMatchesString(cache.matches.data, true)
                contentText.text = View.getFormattedResults(rawResults)
            elseif currentTab == "standings" and cache.standings.data then
                contentText.text = View.getStandingsString(cache.standings.data, currentCompetition.name)
            elseif currentTab == "champions" and cache.champions.data then
                local rawResults = View.getMatchesString(cache.champions.data, true)
                contentText.text = View.getFormattedResults(rawResults)
            end
        end)
    end

    -- Tab switching logic
    local function setActiveTab(tab)
        currentTab = tab
        -- Reset all tabs to inactive
        scoresTab.bg = colors.tab_inactive
        standingsTab.bg = colors.tab_inactive
        championsTab.bg = colors.tab_inactive
        
        -- Set active tab
        if tab == "scores" then
            scoresTab.bg = colors.tab_active
            if popup then
                local container = popup.widget:get_children_by_id("competitionContainer")[1]
                if container then container.visible = false end
            end
        elseif tab == "standings" then
            standingsTab.bg = colors.tab_active
            if popup then
                local container = popup.widget:get_children_by_id("competitionContainer")[1]
                if container then container.visible = true end
            end
        else  -- champions
            championsTab.bg = colors.tab_active
            if popup then
                local container = popup.widget:get_children_by_id("competitionContainer")[1]
                if container then container.visible = false end
            end
        end
        updateContent()
    end

    -- Create the popup window
    popup = awful.popup {
        visible = false,
        ontop = true,
        placement = awful.placement.centered,
        minimum_width = sizes.window_min_width,
        maximum_width = sizes.window_max_width,
        widget = wibox.widget {
            layout = wibox.layout.fixed.vertical,
            -- Header with close button
            {
                {
                    {
                        {
                            text = cfg.icons.football .. "  " .. cfg.strings.title,
                            widget = wibox.widget.textbox,
                            font = titleFont
                        },
                        nil,
                        {
                            id = "closeBtn",
                            text = cfg.icons.close,
                            widget = wibox.widget.textbox,
                            font = contentFont,
                            align = "center",
                            valign = "center",
                            forced_width = sizes.close_button_size,
                            forced_height = sizes.close_button_size,
                            buttons = gears.table.join(
                                awful.button({}, 1, function()
                                    popup.visible = false
                                end)
                            )
                        },
                        layout = wibox.layout.align.horizontal,
                    },
                    widget = wibox.container.margin,
                    margins = paddings.header,
                },
                bg = colors.bg_header,
                fg = colors.fg_text,
                widget = wibox.container.background,
            },
            -- Tab bar
            {
                {
                    {
                        scoresTab,
                        standingsTab,
                        championsTab,
                        layout = wibox.layout.fixed.horizontal,
                        spacing = 4,
                    },
                    widget = wibox.container.margin,
                    margins = paddings.tab_bar,
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
                    bg = colors.bg_window,
                },
                widget = wibox.container.margin,
                margins = paddings.competition,
                visible = false,
            },
            -- Content area
            {
                {
                    contentText,
                    widget = wibox.container.background,
                    bg = colors.bg_window,
                },
                widget = wibox.container.margin,
                margins = paddings.content,
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
                font = contentFont
            },
            bg = comp.code == currentCompetition.code and colors.tab_active or colors.tab_inactive,
            fg = colors.fg_text,
            widget = wibox.container.background,
            forced_width = sizes.competition_btn_width,
            forced_height = sizes.competition_btn_height,
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

    championsTab:buttons(gears.table.join(
        awful.button({}, 1, function()
            setActiveTab("champions")
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

    championsTab:connect_signal("mouse::enter", function(c)
        if currentTab ~= "champions" then
            c.bg = colors.tab_hover
        end
    end)
    championsTab:connect_signal("mouse::leave", function(c)
        if currentTab ~= "champions" then
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
    if cfg.defaults.auto_refresh then
        refresh_timer = gears.timer {
            timeout = cfg.defaults.refresh_interval,
            autostart = true,
            call_now = false,
            callback = function()
                -- Invalidate cache to force refresh
                cache.matches.timestamp = 0
                cache.standings.timestamp = 0
                cache.champions.timestamp = 0
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

    return centeredButton, {
        popup = popup,
        refresh = updateContent,
        timer = refresh_timer,
        setTeamId = function(teamId)
            cfg.defaults.team_id = teamId
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
