-- awesome/tabbed_window_config.lua
-- Generic theming configuration for tabbed_window.lua
-- Override these by passing your own table to tabbed_window.create({ config = ... })
--
-- This config is reusable for any tabbed popup widget, not just football.
-- Split from awesome_config.lua to allow standalone use of tabbed_window.lua.

local config = {}

--------------------------------------------------------------------------------
-- COLORS
--------------------------------------------------------------------------------
-- All colors use hex format: "#RRGGBB" or "#RRGGBBAA" for transparency
-- Default fallbacks are used when beautiful theme colors are not available
local colors = {
    -- ═══════════════════════════════════════════════════════════════════════
    -- TEXT COLORS (foreground)
    -- ═══════════════════════════════════════════════════════════════════════
    fg_content = "#ffffff",       -- Content text (match results, standings data)
    fg_header = "#ffffff",        -- Header text (title, X button)

    -- ═══════════════════════════════════════════════════════════════════════
    -- TOP BAR (header with title and X close button)
    -- ═══════════════════════════════════════════════════════════════════════
    bg_header = "#3a3a5a",        -- Background color of the header bar

    -- ═══════════════════════════════════════════════════════════════════════
    -- BOTTOM BAR (pagination: Prev/Next buttons and "Page X/Y" label)
    -- ═══════════════════════════════════════════════════════════════════════
    fg_pagination_button = "#ffffff",  -- Text color for "◀ Prev" and "Next ▶" buttons
    fg_pagination_label = "#aaaaaa",    -- Text color for "Page 1/3" indicator
    bg_pagination = "#0d0d1a",          -- Background color of pagination bar

    -- ═══════════════════════════════════════════════════════════════════════
    -- WIBAR BUTTON (the icon in your status bar)
    -- ═══════════════════════════════════════════════════════════════════════
    icon_color = "#ffffff",       -- Default icon color (overridden by beautiful.topBar_fg)
    icon_hover = "#3a3a5a",       -- Icon background color on mouse hover
    bg_button = "#00000000",      -- Wibar button background (transparent)

    -- ═══════════════════════════════════════════════════════════════════════
    -- TAB BAR (tab buttons)
    -- ═══════════════════════════════════════════════════════════════════════
    fg_tab = "#ffffff",           -- Text color for tab labels
    tab_active = "#3a3a5a",       -- Background color of the currently selected tab
    tab_inactive = "#1a1a2e",      -- Background color of non-selected tabs
    tab_hover = "#5a5a8a",        -- Tab background color on mouse hover

    -- ═══════════════════════════════════════════════════════════════════════
    -- BACKGROUND COLORS
    -- ═══════════════════════════════════════════════════════════════════════
    bg_tab_bar = "#0d0d1a",       -- Background behind the tab buttons
    bg_window = "#0d0d1a",        -- Background of the content area
    bg_popup = "#0d0d1a",         -- Main popup background (overridden by beautiful.tooltip_bg_color)
}

--------------------------------------------------------------------------------
-- FONTS
--------------------------------------------------------------------------------
-- Font handling: set to nil to use beautiful theme fonts as fallback
-- Font strings should be in format: "FontName Size" (e.g., "JetBrains Mono 12")
local fonts = {
    -- ═══════════════════════════════════════════════════════════════════════
    -- CONTENT FONTS
    -- ═══════════════════════════════════════════════════════════════════════
    content = nil,        -- Main content font
                          -- Falls back to beautiful.font
    title = nil,          -- Window title font
                          -- Falls back to beautiful.mainFont or content font
    tab = nil,            -- Tab labels font
                          -- Falls back to beautiful.labelFontSans or content font

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
    icon = nil,          -- Font for wibar icon
                          -- Falls back to beautiful.topBar_button_font or beautiful.font
    icon_scale = 0.90,   -- Nerd Font glyphs extend beyond bounds, scale to prevent clipping
}

--------------------------------------------------------------------------------
-- SIZES
--------------------------------------------------------------------------------
-- All sizes in pixels
local sizes = {
    -- ═══════════════════════════════════════════════════════════════════════
    -- WINDOW DIMENSIONS
    -- ═══════════════════════════════════════════════════════════════════════
    window_min_width = 650,       -- Minimum popup width
    window_max_width = 750,       -- Maximum popup width
    window_min_height = 740,      -- Minimum popup height
    window_max_height = 950,      -- Maximum popup height

    -- ═══════════════════════════════════════════════════════════════════════
    -- CONTENT AREA
    -- ═══════════════════════════════════════════════════════════════════════
    content_min_height = 300,     -- Minimum height for content text area
    content_max_height = 700,     -- Maximum height for content text area

    -- ═══════════════════════════════════════════════════════════════════════
    -- WIBAR BUTTON (icon in status bar)
    -- ═══════════════════════════════════════════════════════════════════════
    button_size = 24,            -- Icon size (fallback if beautiful.topBar_buttonSize not set)

    -- ═══════════════════════════════════════════════════════════════════════
    -- TAB BUTTONS
    -- ═══════════════════════════════════════════════════════════════════════
    tab_width = 150,             -- Width of each tab button
    tab_height = 30,             -- Height of each tab button

    -- ═══════════════════════════════════════════════════════════════════════
    -- CLOSE BUTTON (X in header)
    -- ═══════════════════════════════════════════════════════════════════════
    close_button_size = 24,      -- Size of the X close button in header

    -- ═══════════════════════════════════════════════════════════════════════
    -- SELECTOR BUTTONS (optional dropdown-like buttons)
    -- ═══════════════════════════════════════════════════════════════════════
    selector_btn_width = 80,     -- Width of each selector button
    selector_btn_height = 24,    -- Height of each selector button
}

--------------------------------------------------------------------------------
-- PADDINGS & MARGINS
--------------------------------------------------------------------------------
-- All values in pixels
local paddings = {
    -- ═══════════════════════════════════════════════════════════════════════
    -- WIBAR BUTTON PADDING
    -- ═══════════════════════════════════════════════════════════════════════
    icon = 2,           -- Padding around icon (prevents clipping)

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
    content = 8,        -- Padding around the content area
    selector = 8,       -- Padding around selector buttons
}

--------------------------------------------------------------------------------
-- ICONS (Nerd Font)
--------------------------------------------------------------------------------
-- Generic icons for tabbed window UI
config.icons = {
    close = "✕",               -- Close button in header
}

--------------------------------------------------------------------------------
-- STRINGS (UI Text)
--------------------------------------------------------------------------------
-- Generic text strings for the widget UI
config.strings = {
    loading = "Loading...",              -- Shown while fetching data
}

--------------------------------------------------------------------------------
-- DEFAULTS
--------------------------------------------------------------------------------
-- Default pagination settings
config.defaults = {
    matches_per_page = 10,     -- Items per page for pagination
}

--------------------------------------------------------------------------------
-- GETTER FUNCTIONS
--------------------------------------------------------------------------------
-- These merge config values with beautiful theme overrides

function config.getColors(beautiful)
    if beautiful then
        colors.icon_color = beautiful.topBar_fg or colors.icon_color
        colors.bg_popup = beautiful.tooltip_bg_color or colors.bg_popup
        colors.fg_content = beautiful.tooltip_fg_color or colors.fg_content
        colors.fg_header = beautiful.tooltip_fg_color or colors.fg_header
        colors.fg_tab = beautiful.tooltip_fg_color or colors.fg_tab
        colors.fg_pagination_button = beautiful.tooltip_fg_color or colors.fg_pagination_button
        colors.fg_pagination_label = beautiful.tooltip_fg_color or colors.fg_pagination_label
        colors.bg_pagination = beautiful.colour2 and beautiful.colour2.shade9 or colors.bg_pagination
    end
    return colors
end

function config.getFonts(beautiful)
    local f = {}
    f.content = fonts.content or beautiful.font
    f.title = fonts.title or beautiful.labelFontSans or beautiful.tooltip_font or f.content
    f.tab = fonts.tab or beautiful.labelFontSans or f.content
    f.pagination_button = fonts.pagination_button or beautiful.labelFontSansSmall or f.content
    f.pagination_label = fonts.pagination_label or beautiful.labelFontSansSmall or f.content
    f.icon = fonts.icon or beautiful.topBar_button_font or beautiful.font
    f.icon_scale = fonts.icon_scale
    return f
end

function config.getSizes(beautiful)
    local s = {}
    for k, v in pairs(sizes) do
        s[k] = v
    end
    if beautiful and beautiful.topBar_buttonSize then
        s.button_size = beautiful.topBar_buttonSize
    end
    return s
end

function config.getPaddings()
    return paddings
end

return config