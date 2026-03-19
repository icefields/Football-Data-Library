-- awesome/awesome_config.lua
-- Configuration constants for AwesomeWM football widget
-- Override these by passing your own table to match_window.create({ config = ... })

local config = {}

--------------------------------------------------------------------------------
-- PATHS
--------------------------------------------------------------------------------
config.paths = {
    cache_file = os.getenv("HOME") .. "/.cache/football_data.json",
}

--------------------------------------------------------------------------------
-- COLORS
--------------------------------------------------------------------------------
config.colors = {
    -- Text colors (foreground)
    fg_text = "#ffffff",
    fg_text_dim = "#aaaaaa",

    -- Icon colors
    icon_color = "#ffffff",
    icon_hover = "#3a3a5a",

    -- Tab colors
    tab_active = "#3a3a5a",
    tab_inactive = "#1a1a2e",
    tab_hover = "#5a5a8a",

    -- Background colors
    bg_header = "#3a3a5a",
    bg_tab_bar = "#0d0d1a",
    bg_window = "#1a1a2e",
    bg_button = "#00000000",
}

--------------------------------------------------------------------------------
-- FONTS
--------------------------------------------------------------------------------
-- Font handling: use beautiful.font as fallback
-- Icons use Nerd Font, scaled down 90% to prevent clipping
config.fonts = {
    -- Main content font (set to nil to use beautiful.font)
    content = nil,

    -- Icon font (set to nil to use beautiful.topBar_button_font or beautiful.font)
    icon = nil,

    -- Icon scale factor (Nerd Font glyphs extend beyond bounds)
    icon_scale = 0.90,
}

--------------------------------------------------------------------------------
-- SIZES
--------------------------------------------------------------------------------
config.sizes = {
    -- Window dimensions
    window_min_width = 750,
    window_max_width = 750,
    window_min_height = 400,  -- Minimum window height
    window_max_height = 900,  -- Max height to fit 1080p screens
    
    -- Content width
    content_width = 700,
    
    -- Scroll settings
    scroll_step = 30,  -- Pixels per scroll step

    -- Button (wibar icon)
    button_size = 24,  -- Fallback if beautiful.topBar_buttonSize not set

    -- Tab buttons
    tab_width = 150,
    tab_height = 30,

    -- Close button
    close_button_size = 24,

    -- Competition buttons
    competition_btn_width = 80,
    competition_btn_height = 24,
}

--------------------------------------------------------------------------------
-- PADDINGS & MARGINS
--------------------------------------------------------------------------------
config.paddings = {
    -- Icon padding (prevents clipping of Nerd Font glyphs)
    icon = 2,

    -- Button margins (spacing from wibar edges)
    button_top = 2,
    button_bottom = 2,
    button_left = 2,
    button_right = 2,

    -- Header margin
    header = 8,

    -- Tab bar margin
    tab_bar = 4,

    -- Content area margin
    content = 8,

    -- Competition selector margin
    competition = { left = 8, right = 8, bottom = 4, top = 4 },
}

--------------------------------------------------------------------------------
-- ICONS (Nerd Font)
--------------------------------------------------------------------------------
config.icons = {
    football = "󰒸",  -- Soccer/football icon
    close = "✕",
    results = "\u{f080}",   -- Chart/bar chart icon
    standings = "\u{f091}", -- Trophy icon
    champions = "\u{f19c}", -- University/trophy icon for Champions League
}

--------------------------------------------------------------------------------
-- STRINGS (UI Text)
--------------------------------------------------------------------------------
config.strings = {
    -- Window title
    title = "Football",

    -- Tab labels (will be combined with icons)
    results = "Results",
    standings = "Standings",
    champions = "Champions League",

    -- Content placeholders
    loading = "Loading...",
    click_to_load = "Click a tab to load data...",
}

--------------------------------------------------------------------------------
-- TEAMS
--------------------------------------------------------------------------------
config.TEAMS = {
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

--------------------------------------------------------------------------------
-- COMPETITIONS
--------------------------------------------------------------------------------
config.COMPETITIONS = {
    { name = "Serie A", code = "SA" },
    { name = "Premier League", code = "PL" },
    { name = "La Liga", code = "PD" },
    { name = "Bundesliga", code = "BL1" },
    { name = "Champions League", code = "CL" },
}

--------------------------------------------------------------------------------
-- DEFAULTS (for internal use)
--------------------------------------------------------------------------------
config.defaults = {
    team_id = 108,  -- Inter Milan
    match_count = 10,
    show_scheduled = false,
    auto_refresh = true,
    refresh_interval = 300,  -- 5 minutes
    cache_timeout = 300,     -- Cache data for 5 minutes
    champions_league_code = "CL",  -- Champions League competition code
    champions_match_count = 15,     -- Number of recent CL matches to show (finished only)
}

return config

