-- awesome/match_window.lua
-- AwesomeWM widget for displaying football data in a popup window
--
-- Usage in rc.lua:
--   local gears = require("gears")
--   local awesome_dir = gears.filesystem.get_configuration_dir()
--   package.path = awesome_dir .. "/football_widget/?.lua;" .. package.path
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
local tabbed_window = require("awesome.tabbed_window")

local match_window = {}

-- Re-export from config for backwards compatibility
match_window.TEAMS = default_config.TEAMS
match_window.COMPETITIONS = default_config.COMPETITIONS

-- In-memory cache
local cache = {
    matches = { data = nil, timestamp = 0 },
    standings = { data = nil, timestamp = 0, competition = nil },
    champions = { data = nil, timestamp = 0 },
}

-- Tab configuration
local TAB_CONFIG = {
    scores = {
        cache_key = "matches",
        has_pagination = true,
        fetch_mode = "team",
    },
    standings = {
        cache_key = "standings",
        has_pagination = false,
        fetch_mode = "team",
    },
    champions = {
        cache_key = "champions",
        has_pagination = true,
        fetch_mode = "champions",
    },
}

-- Helper: Get paginated matches from cache
local function getPaginatedMatches(cacheData, pageNum, perPage)
    if not cacheData or #cacheData == 0 then
        return {}, 0
    end
    local startIdx = (pageNum - 1) * perPage + 1
    local endIdx = math.min(startIdx + perPage - 1, #cacheData)
    local pageMatches = {}
    for i = startIdx, endIdx do
        table.insert(pageMatches, cacheData[i])
    end
    return pageMatches, #cacheData
end

-- Load cache from file
local function loadCacheFromFile(cacheFile)
    local file = io.open(cacheFile, "r")
    if not file then return nil end
    local content = file:read("*all")
    file:close()
    local success, data = pcall(cjson.decode, content)
    if not success then return nil end
    return data
end

-- Save cache to file
local function saveCacheToFile(cacheFile, data)
    local file = io.open(cacheFile, "w")
    if not file then return end
    file:write(cjson.encode(data))
    file:close()
end

-- Check if cache is still valid
local function isCacheValid(cacheEntry, maxAge)
    maxAge = maxAge or 300  -- 5 minutes default
    if not cacheEntry or not cacheEntry.timestamp then
        return false
    end
    return (os.time() - cacheEntry.timestamp) < maxAge
end

-- Ensure cache is loaded from file
local function ensureCacheLoaded(cacheFile)
    local data = loadCacheFromFile(cacheFile)
    if data then
        if data.matches then cache.matches = data.matches end
        if data.standings then cache.standings = data.standings end
        if data.champions then cache.champions = data.champions end
    end
end

-- Create the match window widget
-- @param args table - Widget configuration
-- @return wibox.widget, table - The widget and controls table
function match_window.create(args)
    args = args or {}

    -- Required modules
    local awful = args.awful
    local beautiful = args.beautiful
    local wibox = args.wibox
    local gears = args.gears

    if not awful or not beautiful or not wibox or not gears then
        error("match_window requires 'awful', 'beautiful', 'wibox', and 'gears' modules")
    end

    -- Use config defaults (can override via args.config)
    local cfg = args.config or default_config

    -- Current competition for standings
    local currentCompetition = args.competitions and args.competitions[1] or cfg.COMPETITIONS[1]

    -- Current page state (for pagination)
    local currentPage = 1
    local matchesPerPage = cfg.defaults.matches_per_page or 10

    -- Cache file path
    local cacheFile = cfg.paths.cache_file

    -- Path to fetch script
    local fetchScript = debug.getinfo(1, "S").source:match("^@(.+/)match_window%.lua$") .. "fetch_data.lua"

    -- Ensure cache is loaded
    ensureCacheLoaded(cacheFile)

    -- Content provider function for tabbed_window
    local function contentProvider(tabId, page, selector)
        local config = TAB_CONFIG[tabId]
        if not config then
            return "Unknown tab", 0
        end

        local cacheData = cache[config.cache_key]
        if not cacheData or not cacheData.data then
            return cfg.strings.loading, 0
        end

        if config.has_pagination then
            local pageMatches, totalMatches = getPaginatedMatches(cacheData.data, page, matchesPerPage)
            local rawResults = View.getMatchesString(pageMatches, true)
            local formattedResults = View.getFormattedResults(rawResults)
            local totalPages = math.ceil(totalMatches / matchesPerPage)
            local pageIndicator = string.format("\n\n─── Page %d/%d ───", page, totalPages)
            return formattedResults .. pageIndicator, totalMatches
        elseif tabId == "standings" then
            return View.getStandingsString(cacheData.data, selector and selector.name or "Serie A"), 0
        else
            local rawResults = View.getMatchesString(cacheData.data, true)
            return View.getFormattedResults(rawResults), 0
        end
    end

    -- Tab configuration for tabbed_window
    local tabs = {
        { id = "scores", label = cfg.strings.results, icon = cfg.icons.results, has_pagination = true },
        { id = "standings", label = cfg.strings.standings, icon = cfg.icons.standings, has_pagination = false, has_selector = true },
        { id = "champions", label = cfg.strings.champions, icon = cfg.icons.champions, has_pagination = true },
    }

    -- Create the tabbed window
    local centeredButton, popup, controls = tabbed_window.create({
        tabs = tabs,
        content_provider = contentProvider,
        selector_items = args.competitions or cfg.COMPETITIONS,
        on_selector_change = function(item)
            currentCompetition = item
        end,
        config = cfg,
        title_icon = cfg.icons.football,
        title_text = cfg.strings.title,
        awful = awful,
        beautiful = beautiful,
        wibox = wibox,
        gears = gears,
    })

    -- Override the content provider to fetch data asynchronously
    local originalRefresh = controls.refresh
    local fetchInProgress = {}

    local function fetchContent(tabId, page)
        if fetchInProgress[tabId] then return end
        fetchInProgress[tabId] = true

        -- Build command for async fetch
        local cmd
        if tabId == "champions" then
            cmd = string.format(
                "lua %s %s champions %s %d",
                fetchScript,
                cacheFile,
                cfg.CHAMPIONS_LEAGUE_CODE,
                cfg.defaults.champions_match_count
            )
        else
            cmd = string.format(
                "lua %s %s %d %d %s",
                fetchScript,
                cacheFile,
                cfg.defaults.team_id,
                cfg.defaults.match_count,
                currentCompetition.code
            )
        end

        awful.spawn.easy_async(cmd, function(stdout, stderr, exitreason, exitcode)
            fetchInProgress[tabId] = nil

            if exitcode ~= 0 then
                -- Error - show cached data with error
                local config = TAB_CONFIG[tabId]
                if config and cache[config.cache_key] and cache[config.cache_key].data then
                    -- Could update content with error message here
                end
                return
            end

            local success, data = pcall(function()
                return cjson.decode(stdout)
            end)

            if not success or not data then
                return
            end

            -- Update cache
            if data.champions and data.champions.data then
                cache.champions = data.champions
            end
            if data.matches and data.matches.data then
                cache.matches = data.matches
            end
            if data.standings and data.standings.data then
                cache.standings = data.standings
            end

            -- Save to file
            saveCacheToFile(cacheFile, cache)

            -- Refresh display
            originalRefresh()
        end)
    end

    -- Enhanced refresh that checks cache validity
    controls.refresh = function()
        local config = TAB_CONFIG[controls.get_state().tab]
        if config then
            local cacheEntry = cache[config.cache_key]
            if not isCacheValid(cacheEntry) then
                fetchContent(controls.get_state().tab, controls.get_state().page)
            end
        end
        originalRefresh()
    end

    -- Enhanced show that triggers fetch if needed
    local originalShow = controls.show
    controls.show = function()
        originalShow()
        local config = TAB_CONFIG[controls.get_state().tab]
        if config then
            local cacheEntry = cache[config.cache_key]
            if not cacheEntry or not cacheEntry.data or not isCacheValid(cacheEntry) then
                fetchContent(controls.get_state().tab, 1)
            end
        end
    end

    -- Enhanced toggle that triggers fetch if needed
    local originalToggle = controls.toggle
    controls.toggle = function()
        originalToggle()
        if popup.visible then
            local config = TAB_CONFIG[controls.get_state().tab]
            if config then
                local cacheEntry = cache[config.cache_key]
                if not cacheEntry or not cacheEntry.data or not isCacheValid(cacheEntry) then
                    fetchContent(controls.get_state().tab, 1)
                end
            end
        end
    end

    return centeredButton, controls
end

return match_window