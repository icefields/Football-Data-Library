-- awesome/awesome_config.lua
-- Configuration constants for AwesomeWM football widget
-- Override these by passing your own table to match_window.create({ config = ... })
--
-- USAGE EXAMPLE:
--   local football_widget = match_window.create({
--       awful = awful,
--       wibox = wibox,
--       gears = gears,
--       beautiful = beautiful,
--       config = {
--           colors = { fg_text = "#ff0000" },  -- Override specific colors
--           fonts = { content = "JetBrains Mono 12" },  -- Override fonts
--           sizes = { window_min_width = 600 },  -- Override sizes
--       },
--   })

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
-- COLORS
--------------------------------------------------------------------------------
-- All colors use hex format: "#RRGGBB" or "#RRGGBBAA" for transparency
-- Default fallbacks are used when beautiful theme colors are not available
-- match_window.lua overrides these with beautiful.* theme colors where applicable:
--   - icon_color: overridden by beautiful.topBar_fg
--   - bg_popup: overridden by beautiful.tooltip_bg_color
--   - fg_text: overridden by beautiful.tooltip_fg_color
local colors = {
    -- ═══════════════════════════════════════════════════════════════════════
    -- TEXT COLORS (foreground)
    -- ═══════════════════════════════════════════════════════════════════════
    fg_content = "#ffffff",       -- Content text (match results, standings data)
    fg_header = "#ffffff",        -- Header text ("Football" title, X button)

    -- ═══════════════════════════════════════════════════════════════════════
    -- TOP BAR (header with "Football" title and X close button)
    -- ═══════════════════════════════════════════════════════════════════════
    bg_header = "#3a3a5a",        -- Background color of the header bar

    -- ═══════════════════════════════════════════════════════════════════════
    -- BOTTOM BAR (pagination: Prev/Next buttons and "Page X/Y" label)
    -- ═══════════════════════════════════════════════════════════════════════
    fg_pagination_button = "#ffffff",  -- Text color for "◀ Prev" and "Next ▶" buttons
    fg_pagination_label = "#aaaaaa",    -- Text color for "Page 1/3" indicator
    bg_pagination = "#0d0d1a",          -- Background color of pagination bar

    -- ═══════════════════════════════════════════════════════════════════════
    -- WIBAR BUTTON (the football icon in your status bar)
    -- ═══════════════════════════════════════════════════════════════════════
    icon_color = "#ffffff",       -- Default icon color (overridden by beautiful.topBar_fg)
    icon_hover = "#3a3a5a",       -- Icon background color on mouse hover

    -- ═══════════════════════════════════════════════════════════════════════
    -- TAB BAR (Results / Standings / Champions tabs)
    -- ═══════════════════════════════════════════════════════════════════════
    fg_tab = "#ffffff",           -- Text color for tab labels
    tab_active = "#3a3a5a",       -- Background color of the currently selected tab
    tab_inactive = "#1a1a2e",      -- Background color of non-selected tabs
    tab_hover = "#5a5a8a",        -- Tab background color on mouse hover

    -- ═══════════════════════════════════════════════════════════════════════
    -- BACKGROUND COLORS
    -- ═══════════════════════════════════════════════════════════════════════
    bg_tab_bar = "#0d0d1a",       -- Background behind the tab buttons
    bg_window = "#0d0d1a",        -- Background of the content area (matches/standings)
    bg_popup = "#0d0d1a",         -- Main popup background (overridden by beautiful.tooltip_bg_color)
    bg_button = "#00000000",      -- Wibar button background (transparent)
}

--------------------------------------------------------------------------------
-- FONTS
--------------------------------------------------------------------------------
-- Font handling: set to nil to use beautiful theme fonts as fallback
-- Font strings should be in format: "FontName Size" (e.g., "JetBrains Mono 12")
-- Icons use Nerd Font, scaled down 90% to prevent clipping
local fonts = {
    -- ═══════════════════════════════════════════════════════════════════════
    -- CONTENT FONTS
    -- ═══════════════════════════════════════════════════════════════════════
    content = nil,        -- Main content font (match results, standings text)
                          -- Falls back to beautiful.font
    title = nil,          -- Window title font ("Football" in header)
                          -- Falls back to beautiful.mainFont or content font

    -- ═══════════════════════════════════════════════════════════════════════
    -- TAB FONTS (Results / Standings / Champions)
    -- ═══════════════════════════════════════════════════════════════════════
    tab = nil,              -- Font for tab labels ("Results", "Standings", "Champions")
                            -- Falls back to beautiful.labelFontSansSmall or content font

    -- ═══════════════════════════════════════════════════════════════════════
    -- PAGINATION FONTS (bottom bar)
    -- ═══════════════════════════════════════════════════════════════════════
    pagination_button = nil,  -- Font for "◀ Prev" and "Next ▶" buttons
                               -- Falls back to content font
    pagination_label = nil,    -- Font for "Page 1/3" indicator
                               -- Falls back to content font

    -- ═══════════════════════════════════════════════════════════════════════
    -- ICON FONT
    -- ═══════════════════════════════════════════════════════════════════════
    icon = nil,          -- Font for wibar football icon (󰒸)
                          -- Falls back to beautiful.topBar_button_font or beautiful.font

    -- ═══════════════════════════════════════════════════════════════════════
    -- ICON SCALING
    -- ═══════════════════════════════════════════════════════════════════════
    icon_scale = 0.90,   -- Nerd Font glyphs extend beyond bounds, scale to prevent clipping
                         -- 0.90 = 90% of original size
}

--------------------------------------------------------------------------------
-- SIZES
--------------------------------------------------------------------------------
-- All sizes in pixels
local sizes = {
    -- ═══════════════════════════════════════════════════════════════════════
    -- WINDOW DIMENSIONS
    -- ═══════════════════════════════════════════════════════════════════════
    window_min_width = 650,       -- Minimum popup width (can't shrink below this)
    window_max_width = 750,       -- Maximum popup width (can't expand beyond this)
    window_min_height = 740,      -- Minimum popup height
    window_max_height = 950,      -- Maximum popup height (fits 1080p screens)

    -- ═══════════════════════════════════════════════════════════════════════
    -- CONTENT AREA
    -- ═══════════════════════════════════════════════════════════════════════
    content_min_height = 300,     -- Minimum height for match/standings text area
    content_max_height = 700,     -- Maximum height for match/standings text area
    -- Note: content width is dynamic, follows window width

    -- ═══════════════════════════════════════════════════════════════════════
    -- WIBAR BUTTON (football icon in status bar)
    -- ═══════════════════════════════════════════════════════════════════════
    button_size = 24,            -- Icon size (fallback if beautiful.topBar_buttonSize not set)

    -- ═══════════════════════════════════════════════════════════════════════
    -- TAB BUTTONS (Results / Standings / Champions)
    -- ═══════════════════════════════════════════════════════════════════════
    tab_width = 150,             -- Width of each tab button
    tab_height = 30,             -- Height of each tab button

    -- ═══════════════════════════════════════════════════════════════════════
    -- CLOSE BUTTON (X in header)
    -- ═══════════════════════════════════════════════════════════════════════
    close_button_size = 24,      -- Size of the X close button in header

    -- ═══════════════════════════════════════════════════════════════════════
    -- COMPETITION BUTTONS (Serie A / Premier League / etc. for Standings tab)
    -- ═══════════════════════════════════════════════════════════════════════
    competition_btn_width = 80,   -- Width of each competition button
    competition_btn_height = 24,  -- Height of each competition button
}

--------------------------------------------------------------------------------
-- PADDINGS & MARGINS
--------------------------------------------------------------------------------
-- All values in pixels
local paddings = {
    -- ═══════════════════════════════════════════════════════════════════════
    -- WIBAR BUTTON PADDING
    -- ═══════════════════════════════════════════════════════════════════════
    icon = 2,           -- Padding around football icon (prevents clipping)

    -- ═══════════════════════════════════════════════════════════════════════
    -- WIBAR BUTTON MARGINS (spacing from status bar edges)
    -- ═══════════════════════════════════════════════════════════════════════
    button_top = 2,     -- Margin above the button
    button_bottom = 2,  -- Margin below the button
    button_left = 2,    -- Margin left of the button
    button_right = 2,   -- Margin right of the button

    -- ═══════════════════════════════════════════════════════════════════════
    -- POPUP INTERNAL PADDING
    -- ═══════════════════════════════════════════════════════════════════════
    header = 8,         -- Padding inside the header bar (around title/close)
    tab_bar = 4,        -- Padding inside the tab bar
    content = 8,        -- Padding around the content area (matches/standings)

    -- ═══════════════════════════════════════════════════════════════════════
    -- COMPETITION SELECTOR PADDING (for Standings tab)
    -- ═══════════════════════════════════════════════════════════════════════
    competition = { left = 8, right = 8, bottom = 4, top = 4 },
}

--------------------------------------------------------------------------------
-- ICONS (Nerd Font)
--------------------------------------------------------------------------------
-- These use Nerd Font codepoints. Change to different icons if desired.
-- Find icons at: https://www.nerdfonts.com/cheat-sheet
config.icons = {
    football = "󰒸",           -- Soccer/football icon (shown in wibar and header)
    close = "✕",               -- Close button in header
    results = "\u{f080}",      -- Bar chart icon for Results tab
    standings = "\u{f091}",    -- Trophy icon for Standings tab
    champions = "\u{f19c}",    -- University/trophy icon for Champions League tab
}

--------------------------------------------------------------------------------
-- STRINGS (UI Text)
--------------------------------------------------------------------------------
-- Customizable text strings for the widget UI
config.strings = {
    -- ═══════════════════════════════════════════════════════════════════════
    -- WINDOW TITLE (shown in header bar)
    -- ═══════════════════════════════════════════════════════════════════════
    title = "Football",

    -- ═══════════════════════════════════════════════════════════════════════
    -- TAB LABELS (combined with icons)
    -- ═══════════════════════════════════════════════════════════════════════
    results = "Results",      -- Results tab label
    standings = "Standings",  -- Standings tab label
    champions = "Champions",  -- Champions League tab label

    -- ═══════════════════════════════════════════════════════════════════════
    -- CONTENT PLACEHOLDERS (shown before data loads)
    -- ═══════════════════════════════════════════════════════════════════════
    loading = "Loading...",              -- Shown while fetching data
    click_to_load = "Click a tab to load data...",  -- Initial placeholder
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
-- DEFAULTS (for internal use)
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

function config.getColors(beautiful)
    -- Beautiful theme takes priority over config defaults
    if beautiful then
        colors.icon_color = beautiful.topBar_fg or colors.icon_color
        colors.bg_popup = beautiful.tooltip_bg_color or colors.bg_popup
        colors.fg_content = beautiful.tooltip_fg_color or colors.fg_content
        colors.fg_header = beautiful.tooltip_fg_color or colors.fg_header
        colors.fg_tab = beautiful.tooltip_fg_color or colors.fg_tab
        colors.fg_pagination_button = beautiful.tooltip_fg_color or colors.fg_pagination_button
        colors.fg_pagination_label = beautiful.tooltip_fg_color or colors.fg_pagination_label
        colors.bg_pagination = beautiful.colour2.shade9 
    end
    return colors
end

function config.getFonts(beautiful)
    local f = {}
    -- Content font: fallback chain
    f.content = fonts.content or beautiful.font
    -- Title font: fallback chain
    f.title = fonts.title or beautiful.labelFontSans or beautiful.tooltip_font or f.content
    -- Tab font: fallback chain
    f.tab = fonts.tab or beautiful.labelFontSans or f.content
    -- Pagination fonts: fallback to content
    f.pagination_button = fonts.pagination_button or beautiful.labelFontSansSmall or f.content
    f.pagination_label = fonts.pagination_label or beautiful.labelFontSansSmall or f.content
    -- Icon font: fallback chain
    f.icon = fonts.icon or beautiful.topBar_button_font or beautiful.font
    -- Scale factor
    f.icon_scale = fonts.icon_scale
    return f
end

function config.getSizes(beautiful)
    local s = {}
    for k, v in pairs(sizes) do
        s[k] = v
    end
    -- Override with beautiful theme if available
    if beautiful and beautiful.topBar_buttonSize then
        s.button_size = beautiful.topBar_buttonSize
    end
    return s
end

function config.getPaddings()
    return paddings
end


-- Helper to get competition code by name (DRY)
function config.getCompetitionCode(name)
    for _, comp in ipairs(config.COMPETITIONS) do
        if comp.name == name or comp.code == name then
            return comp.code
        end
    end
    return nil
end

-- Champions League code (DRY - from COMPETITIONS)
config.CHAMPIONS_LEAGUE_CODE = config.COMPETITIONS[5] and config.COMPETITIONS[5].code or "CL"

return config

