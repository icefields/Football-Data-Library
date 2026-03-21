-- awesome/football_config.lua
-- Football-specific configuration for match_window.lua
-- Team IDs, competitions, API settings, cache paths
--
-- Split from awesome_config.lua to allow tabbed_window_config.lua
-- to be reused for other widgets.

local config = {}

--------------------------------------------------------------------------------
-- PATHS
--------------------------------------------------------------------------------
-- cache_file: JSON file for caching API responses (reduces API calls)
-- Set to nil to disable caching (not recommended - hits API rate limits)
config.paths = {
    cache_file = os.getenv("HOME") .. "/.cache/football_data.json",
}

--------------------------------------------------------------------------------
-- TEAMS
--------------------------------------------------------------------------------
-- Common team IDs for quick reference
-- Use in config.defaults.team_id or pass to setTeamId()
config.TEAMS = {
    -- Italian Serie A
    INTER_MILAN = 108,
    AC_MILAN = 98,
    JUVENTUS = 109,
    NAPOLI = 113,
    ROMA = 100,
    LAZIO = 110,
    -- English Premier League
    ARSENAL = 57,
    CHELSEA = 61,
    MAN_UNITED = 66,
    MAN_CITY = 65,
    LIVERPOOL = 64,
    TOTTENHAM = 73,
    -- Spanish La Liga
    BARCELONA = 81,
    REAL_MADRID = 86,
    ATLETICO_MADRID = 78,
    -- German Bundesliga
    BAYERN_MUNICH = 5,
    DORTMUND = 165,
    -- French Ligue 1
    PSG = 85,
}

--------------------------------------------------------------------------------
-- COMPETITIONS
--------------------------------------------------------------------------------
-- Competitions available in the Standings tab competition selector
-- Add or remove entries to customize the dropdown
config.COMPETITIONS = {
    { name = "Serie A", code = "SA" },           -- Italy
    { name = "Premier League", code = "PL" },     -- England
    { name = "La Liga", code = "PD" },            -- Spain
    { name = "Bundesliga", code = "BL1" },        -- Germany
    { name = "Champions League", code = "CL" },    -- Europe
}

--------------------------------------------------------------------------------
-- ICONS (Football-specific Nerd Font icons)
--------------------------------------------------------------------------------
-- These use Nerd Font codepoints. Change to different icons if desired.
-- Find icons at: https://www.nerdfonts.com/cheat-sheet
config.icons = {
    football = "󰒸",           -- Soccer/football icon (shown in wibar and header)
    results = "\u{f080}",      -- Bar chart icon for Results tab
    standings = "\u{f091}",    -- Trophy icon for Standings tab
    champions = "\u{f19c}",    -- University/trophy icon for Champions League tab
}

--------------------------------------------------------------------------------
-- STRINGS (Football-specific UI Text)
--------------------------------------------------------------------------------
-- Customizable text strings for the football widget UI
config.strings = {
    title = "Football",
    results = "Results",      -- Results tab label
    standings = "Standings",  -- Standings tab label
    champions = "Champions",  -- Champions League tab label
    loading = "Loading...",
    click_to_load = "Click a tab to load data...",
}

--------------------------------------------------------------------------------
-- DEFAULTS (Football-specific)
--------------------------------------------------------------------------------
-- These control API fetching behavior and pagination
config.defaults = {
    team_id = 108,              -- Default team for Results tab (Inter Milan)
                                -- Change this to your favorite team
    match_count = 30,           -- Number of matches to fetch for Results tab
    show_scheduled = false,     -- Show scheduled matches (true) or only played (false)
    cache_timeout = 300,        -- Cache validity in seconds (5 minutes)
                                -- Increase to reduce API calls, decrease for fresher data

    -- Champions League settings
    champions_match_count = 50, -- Total CL matches to fetch (finished only)
    matches_per_page = 10,     -- Matches per page for Results and Champions tabs
}

-- Champions League code (DRY - from COMPETITIONS)
config.CHAMPIONS_LEAGUE_CODE = config.COMPETITIONS[5] and config.COMPETITIONS[5].code or "CL"

-- Helper to get competition code by name (DRY)
function config.getCompetitionCode(name)
    for _, comp in ipairs(config.COMPETITIONS) do
        if comp.name == name or comp.code == name then
            return comp.code
        end
    end
    return nil
end

return config