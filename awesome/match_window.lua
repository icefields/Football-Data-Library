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
local football_config = require("awesome.football_config")
local tabbed_window_config = require("awesome.tabbed_window_config")
local tabbed_window = require("awesome.tabbed_window")

local match_window = {}

-- Re-export from football_config for backwards compatibility
match_window.TEAMS = football_config.TEAMS
match_window.COMPETITIONS = football_config.COMPETITIONS

-- In-memory cache
-- standings is now keyed by competition code: { ["SA"] = { data = ..., timestamp = ... }, ... }
local cache = {
    matches = { data = nil, timestamp = 0 },
    standings = {},  -- Per-competition cache
    champions = { data = nil, timestamp = 0 },
}

-- Track fetch progress per tab
local fetchInProgress = {}

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
        fetch_mode = "standings",  -- Fetches all competitions
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
local function saveCacheToFile(cacheFile, cacheData)
    local file = io.open(cacheFile, "w")
    if not file then return end
    file:write(cjson.encode(cacheData))
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
        if data.standings then 
            -- Handle both old format (single) and new format (per-competition)
            if data.standings.data then
                -- Old format: convert to new format
                local compCode = data.standings.competition or "SA"
                cache.standings[compCode] = {
                    data = data.standings.data,
                    timestamp = data.standings.timestamp,
                }
            else
                -- New format: standings is already keyed by competition
                cache.standings = data.standings
            end
        end
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

    -- Use merged config (football_config for data, tabbed_window_config for theming)
    local cfg = args.config or setmetatable({
        -- Football-specific config
        TEAMS = football_config.TEAMS,
        COMPETITIONS = football_config.COMPETITIONS,
        CHAMPIONS_LEAGUE_CODE = football_config.CHAMPIONS_LEAGUE_CODE,
        defaults = football_config.defaults,
        paths = football_config.paths,
        icons = football_config.icons,
        strings = football_config.strings,
        -- Theming config (merged)
        getColors = function(beautiful) return tabbed_window_config.getColors(beautiful) end,
        getFonts = function(beautiful) return tabbed_window_config.getFonts(beautiful) end,
        getSizes = function(beautiful) return tabbed_window_config.getSizes(beautiful) end,
        getPaddings = function() return tabbed_window_config.getPaddings() end,
    }, { __index = tabbed_window_config })

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

    -- Forward declarations
    local refreshCallback = nil

    -- Content provider function for tabbed_window
    local function contentProvider(tabId, page, selector)
        local config = TAB_CONFIG[tabId]
        if not config then
            return "Unknown tab", 0
        end

        if tabId == "standings" then
            -- Standings: use per-competition cache
            local compCode = selector and selector.code or "SA"
            local cacheData = cache.standings[compCode]
            if not cacheData or not cacheData.data then
                return cfg.strings.loading, 0
            end
            return View.getStandingsString(cacheData.data, selector and selector.name or "Serie A"), 0
        end

        -- Other tabs: use single cache
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
        else
            local rawResults = View.getMatchesString(cacheData.data, true)
            return View.getFormattedResults(rawResults), 0
        end
    end
    
    -- Fetch data for a specific tab (on demand)
    local function fetchTabData(tabId, selector)
        if fetchInProgress[tabId] then return end
        fetchInProgress[tabId] = true

        local cmd
        if tabId == "champions" then
            cmd = string.format(
                "lua %s %s champions %s %d",
                fetchScript,
                cacheFile,
                cfg.CHAMPIONS_LEAGUE_CODE,
                cfg.defaults.champions_match_count
            )
        elseif tabId == "standings" then
            -- Fetch standings for specific competition
            local compCode = selector and selector.code or "SA"
            cmd = string.format(
                "lua %s %s standings %s",
                fetchScript,
                cacheFile,
                compCode
            )
        else
            -- Scores tab
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
            if data.standings then
                -- Could be single competition or all
                if data.standings.data then
                    -- Single competition format
                    local compCode = data.standings.competition or "SA"
                    cache.standings[compCode] = data.standings
                else
                    -- Per-competition format
                    for compCode, compData in pairs(data.standings) do
                        cache.standings[compCode] = compData
                    end
                end
            end

            -- Save to file
            saveCacheToFile(cacheFile, cache)

            -- Refresh display via the controls.refresh callback
            if refreshCallback then
                refreshCallback()
            end
        end)
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
            -- Fetch data for the new competition when selector changes
            fetchTabData("standings", item)
        end,
        config = cfg,
        title_icon = cfg.icons.football,
        title_text = cfg.strings.title,
        awful = awful,
        beautiful = beautiful,
        wibox = wibox,
        gears = gears,
    })

    -- Wire up refresh callback so fetchTabData can trigger UI update
    refreshCallback = controls.refresh

    -- Wire up tab changes to fetch data on demand
    local originalShow = controls.show
    controls.show = function()
        originalShow()
        local state = controls.get_state()
        fetchTabData(state.tab, state.selector)
    end

    return centeredButton, controls
end

return match_window