-- awesome/tabbed_window.lua
-- Generic tabbed popup window for AwesomeWM
--
-- This module provides a reusable tabbed popup UI that is completely
-- decoupled from any data source. The caller provides:
--   - Tab configuration (labels, icons, pagination flags)
--   - Content provider function (returns text for each tab/page)
--   - Optional selector configuration (for dropdown-like selectors)
--   - Config from tabbed_window_config for theming
--
-- Usage:
--   local tabbed_window = require("awesome.tabbed_window")
--   local tabbed_window_config = require("awesome.tabbed_window_config")
--   local widget, popup, controls = tabbed_window.create({
--     tabs = {
--       { id = "results", label = "Results", icon = "📊", has_pagination = true },
--       { id = "standings", label = "Standings", icon = "🏆", has_pagination = false },
--     },
--     content_provider = function(tab_id, page, selector)
--       return "Content here...", 100
--     end,
--     config = tabbed_window_config,
--     title_icon = "󰒸",
--     title_text = "My Widget",
--     awful = awful,
--     beautiful = beautiful,
--     wibox = wibox,
--     gears = gears,
--   })
--
-- Controls returned:
--   controls.popup - the popup widget
--   controls.show() - show popup
--   controls.hide() - hide popup
--   controls.toggle() - toggle popup
--   controls.refresh() - refresh content
--   controls.set_tab(id) - switch tabs
--   controls.set_selector(item) - change selector
--   controls.set_page(n) - change page
--   controls.get_state() - returns { tab, page, selector }
--   controls.destroy() - cleanup signal handlers

local tabbed_window = {}

-- Create a tabbed window widget
-- @param args table - Configuration
--   args.tabs = {{ id, label, icon, has_pagination }, ...}
--   args.content_provider = function(tab_id, page) -> string, total_items
--   args.selector_items = {{ name, code }, ...} or nil (for selector dropdown)
--   args.on_selector_change = function(item) ... or nil
--   args.config = tabbed_window_config table
--   args.awful, args.beautiful, args.wibox, args.gears = required modules
-- @return widget, popup, controls table
function tabbed_window.create(args)
    args = args or {}

    -- Required modules
    local awful = args.awful
    local beautiful = args.beautiful
    local wibox = args.wibox
    local gears = args.gears

    if not awful or not beautiful or not wibox or not gears then
        error("tabbed_window requires 'awful', 'beautiful', 'wibox', and 'gears' modules")
    end

    -- Config
    local cfg = args.config
    if not cfg then
        error("tabbed_window requires 'config' (from tabbed_window_config)")
    end

    -- Get config sections
    local colors = cfg.getColors(beautiful)
    local fonts = cfg.getFonts(beautiful)
    local sizes = cfg.getSizes(beautiful)
    local paddings = cfg.getPaddings()

    -- Font references
    local contentFont = fonts.content
    local titleFont = fonts.title
    local tabFont = fonts.tab
    local iconFontRaw = fonts.icon
    local iconFontSize = tonumber(iconFontRaw:match("(%d+)$")) or 12
    local iconFontScaled = iconFontRaw:gsub("(%d+)$", tostring(math.floor(iconFontSize * fonts.icon_scale)))
    local paginationButtonFont = fonts.pagination_button
    local paginationLabelFont = fonts.pagination_label

    -- Tab configuration
    local tabs = args.tabs or {}
    if #tabs == 0 then
        error("tabbed_window requires at least one tab")
    end

    -- Current state
    local currentTab = tabs[1].id
    local currentPage = 1
    local itemsPerPage = cfg.defaults and cfg.defaults.matches_per_page or 10

    -- Content provider
    local contentProvider = args.content_provider
    if not contentProvider then
        error("tabbed_window requires 'content_provider' function")
    end

    -- Selector configuration (optional)
    local selectorItems = args.selector_items
    local onSelectorChange = args.on_selector_change
    local currentSelectorItem = selectorItems and selectorItems[1]

    -- Window title
    local titleIcon = args.title_icon or ""
    local titleText = args.title_text or "Window"

    -- Forward declarations
    local popup = nil
    local contentText = nil
    local prevPageBtn = nil
    local nextPageBtn = nil
    local pageIndicatorWidget = nil
    local paginationContainer = nil
    local selectorContainer = nil
    local selectorButtons = nil
    local tabWidgets = {}
    
    -- Signal handlers for cleanup (prevents memory leaks)
    local tabEnterHandlers = {}
    local tabLeaveHandlers = {}
    local buttonEnterHandler = nil
    local buttonLeaveHandler = nil
    local selectorButtonHandlers = { enter = {}, leave = {} }

    -- Forward declaration for updateContent and setActiveTab (needed for closures)
    local updateContent = nil
    local setActiveTab = nil

    -- Build tab widgets
    -- Store signal handlers for cleanup (prevents memory leaks)
    local tabEnterHandlers = {}
    local tabLeaveHandlers = {}
    for i, tab in ipairs(tabs) do
        tabEnterHandlers[tab.id] = function(c)
            c.bg = colors.tab_hover
        end
        tabLeaveHandlers[tab.id] = function(c)
            if currentTab == tab.id then
                c.bg = colors.tab_active
            else
                c.bg = colors.tab_inactive
            end
        end
        
        tabWidgets[tab.id] = wibox.widget {
            {
                id = "label",
                text = (tab.icon or "") .. "  " .. tab.label,
                widget = wibox.widget.textbox,
                align = "center",
                valign = "center",
                font = tabFont,
            },
            bg = i == 1 and colors.tab_active or colors.tab_inactive,
            fg = colors.fg_tab,
            widget = wibox.container.background,
            forced_width = sizes.tab_width,
            forced_height = sizes.tab_height,
            shape = gears.shape.rounded_rect,
            shape_border_width = 0,
        }
    end

    -- Build wibar button
    local buttonSize = sizes.button_size
    local button = wibox.widget {
        {
            {
                id = "icon",
                text = titleIcon,
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

    local buttonContainer = wibox.widget {
        button,
        widget = wibox.container.margin,
        top = paddings.button_top,
        bottom = paddings.button_bottom,
        left = paddings.button_left,
        right = paddings.button_right,
    }

    local centeredButton = wibox.widget {
        buttonContainer,
        widget = wibox.container.place,
        valign = "center",
        halign = "center",
    }

    -- Content text widget
    contentText = wibox.widget {
        id = "content",
        text = cfg.strings and cfg.strings.loading or "Loading...",
        widget = wibox.widget.textbox,
        font = contentFont,
    }

    -- Build selector buttons if selector_items provided
    selectorButtons = wibox.widget {
        layout = wibox.layout.flex.horizontal,
        spacing = 2,
    }

    if selectorItems then
        for i, item in ipairs(selectorItems) do
            -- Store handlers for cleanup
            selectorButtonHandlers.enter[i] = function(c)
                c.bg = colors.tab_hover
            end
            selectorButtonHandlers.leave[i] = function(c)
                if currentSelectorItem and currentSelectorItem.code == item.code then
                    c.bg = colors.tab_active
                else
                    c.bg = colors.tab_inactive
                end
            end
            
            local btn = wibox.widget {
                {
                    text = item.name,
                    widget = wibox.widget.textbox,
                    align = "center",
                    valign = "center",
                    font = contentFont,
                },
                bg = item.code == currentSelectorItem.code and colors.tab_active or colors.tab_inactive,
                fg = colors.fg_tab,
                widget = wibox.container.background,
                forced_width = sizes.selector_btn_width,
                forced_height = sizes.selector_btn_height,
            }
            -- Button click handler (separate to avoid 'btn' reference inside its own definition)
            btn:buttons(gears.table.join(
                awful.button({}, 1, function()
                    currentSelectorItem = item
                    -- Update button highlights
                    for _, b in ipairs(selectorButtons.children) do
                        b.bg = colors.tab_inactive
                    end
                    btn.bg = colors.tab_active
                    -- Callback
                    if onSelectorChange then
                        onSelectorChange(item)
                    end
                    -- Refresh content
                    currentPage = 1
                    updateContent()
                end)
            ))
            btn:connect_signal("mouse::enter", selectorButtonHandlers.enter[i])
            btn:connect_signal("mouse::leave", selectorButtonHandlers.leave[i])
            selectorButtons:add(btn)
        end
    end

    -- Update content based on current tab
    updateContent = function()
        local content, totalItems = contentProvider(currentTab, currentPage, currentSelectorItem)
        
        if not content then
            contentText.text = cfg.strings and cfg.strings.loading or "Loading..."
            if paginationContainer then paginationContainer.visible = false end
            return
        end

        contentText.text = content

        -- Update pagination visibility
        local tab = nil
        for _, t in ipairs(tabs) do
            if t.id == currentTab then
                tab = t
                break
            end
        end

        if tab and tab.has_pagination and totalItems and totalItems > 0 then
            local totalPages = math.ceil(totalItems / itemsPerPage)
            if paginationContainer then paginationContainer.visible = true end
            if prevPageBtn then prevPageBtn.visible = currentPage > 1 end
            if nextPageBtn then nextPageBtn.visible = currentPage < totalPages end
            if pageIndicatorWidget then
                pageIndicatorWidget.text = string.format("Page %d/%d", currentPage, totalPages)
            end
        else
            if paginationContainer then paginationContainer.visible = false end
        end
    end

    -- Set active tab
    setActiveTab = function(tabId)
        currentTab = tabId
        currentPage = 1

        -- Update tab backgrounds
        for _, tab in ipairs(tabs) do
            if tabWidgets[tab.id] then
                tabWidgets[tab.id].bg = tab.id == tabId and colors.tab_active or colors.tab_inactive
            end
        end

        -- Update selector visibility
        if selectorContainer then
            local tab = nil
            for _, t in ipairs(tabs) do
                if t.id == tabId then
                    tab = t
                    break
                end
            end
            selectorContainer.visible = tab and tab.has_selector or false
        end

        -- Update pagination visibility
        if paginationContainer then
            local tab = nil
            for _, t in ipairs(tabs) do
                if t.id == tabId then
                    tab = t
                    break
                end
            end
            paginationContainer.visible = tab and tab.has_pagination or false
        end

        updateContent()
    end

    -- Tab button click handlers
    for _, tab in ipairs(tabs) do
        if tabWidgets[tab.id] then
            tabWidgets[tab.id]:buttons(gears.table.join(
                awful.button({}, 1, function()
                    setActiveTab(tab.id)
                end)
            ))
            tabWidgets[tab.id]:connect_signal("mouse::enter", tabEnterHandlers[tab.id])
            tabWidgets[tab.id]:connect_signal("mouse::leave", tabLeaveHandlers[tab.id])
        end
    end

    -- Build tab bar layout dynamically (supports any number of tabs)
    local tabBarLayout = wibox.layout.fixed.horizontal()
    tabBarLayout.spacing = 4
    for _, tab in ipairs(tabs) do
        tabBarLayout:add(tabWidgets[tab.id])
    end

    -- Create popup
    popup = awful.popup {
        visible = false,
        ontop = true,
        placement = awful.placement.centered,
        minimum_width = sizes.window_min_width,
        maximum_width = sizes.window_max_width,
        minimum_height = sizes.window_min_height,
        maximum_height = sizes.window_max_height,
        widget = wibox.widget {
            {
                id = "popupLayout",
                layout = wibox.layout.align.vertical,
                -- Top section (header, tabs, content)
                {
                    id = "contentArea",
                    layout = wibox.layout.fixed.vertical,
                    -- Header with close button
                    {
                        {
                            {
                                {
                                    text = titleIcon .. "  " .. titleText,
                                    widget = wibox.widget.textbox,
                                    font = titleFont,
                                },
                                nil,
                                {
                                    id = "closeBtn",
                                    text = cfg.icons and cfg.icons.close or "✕",
                                    widget = wibox.widget.textbox,
                                    font = titleFont,
                                    align = "center",
                                    valign = "center",
                                    forced_width = sizes.close_button_size,
                                    forced_height = sizes.close_button_size,
                                    buttons = gears.table.join(
                                        awful.button({}, 1, function()
                                            popup.visible = false
                                        end)
                                    ),
                                },
                                layout = wibox.layout.align.horizontal,
                            },
                            widget = wibox.container.margin,
                            margins = paddings.header,
                        },
                        bg = colors.bg_header,
                        fg = colors.fg_header,
                        widget = wibox.container.background,
                    },
                    -- Tab bar
                    {
                        tabBarLayout,
                        widget = wibox.container.margin,
                        margins = paddings.tab_bar,
                    },
                    -- Selector (optional)
                    {
                        id = "competitionContainer",
                        {
                            selectorButtons,
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
                            {
                                contentText,
                                widget = wibox.container.background,
                                bg = colors.bg_window,
                                fg = colors.fg_content,
                            },
                            widget = wibox.container.margin,
                            margins = paddings.content,
                        },
                        widget = wibox.container.constraint,
                        strategy = "max",
                        height = sizes.content_max_height,
                    },
                },
                nil, -- Middle expands to push pagination to bottom
                -- Pagination buttons (anchored to bottom)
                {
                    {
                        {
                            id = "paginationContainer",
                            layout = wibox.layout.flex.horizontal,
                            spacing = 20,
                            {
                                {
                                    id = "prevPageBtn",
                                    text = "◀ Prev",
                                    widget = wibox.widget.textbox,
                                    align = "center",
                                    valign = "center",
                                    font = paginationButtonFont,
                                },
                                widget = wibox.container.background,
                                fg = colors.fg_pagination_button,
                            },
                            {
                                {
                                    id = "pageIndicator",
                                    text = "Page 1/1",
                                    widget = wibox.widget.textbox,
                                    align = "center",
                                    valign = "center",
                                    font = paginationLabelFont,
                                },
                                widget = wibox.container.background,
                                fg = colors.fg_pagination_label,
                            },
                            {
                                {
                                    id = "nextPageBtn",
                                    text = "Next ▶",
                                    widget = wibox.widget.textbox,
                                    align = "center",
                                    valign = "center",
                                    font = paginationButtonFont,
                                },
                                widget = wibox.container.background,
                                fg = colors.fg_pagination_button,
                            },
                            visible = false,
                        },
                        widget = wibox.container.margin,
                        margins = 10,
                    },
                    widget = wibox.container.background,
                    bg = colors.bg_pagination,
                },
            },
            widget = wibox.container.background,
            bg = colors.bg_popup,
        },
    }

    -- Get pagination buttons by ID
    prevPageBtn = popup.widget:get_children_by_id("prevPageBtn")[1]
    nextPageBtn = popup.widget:get_children_by_id("nextPageBtn")[1]
    pageIndicatorWidget = popup.widget:get_children_by_id("pageIndicator")[1]
    paginationContainer = popup.widget:get_children_by_id("paginationContainer")[1]
    selectorContainer = popup.widget:get_children_by_id("competitionContainer")[1]

    -- Pagination button handlers
    if prevPageBtn then
        prevPageBtn:buttons(gears.table.join(
            awful.button({}, 1, function()
                if currentPage > 1 then
                    currentPage = currentPage - 1
                    updateContent()
                end
            end)
        ))
    end

    if nextPageBtn then
        nextPageBtn:buttons(gears.table.join(
            awful.button({}, 1, function()
                -- Content provider should handle total pages
                currentPage = currentPage + 1
                updateContent()
            end)
        ))
    end

    -- Button click handler
    button:buttons(gears.table.join(
        awful.button({}, 1, function()
            if popup.visible then
                popup.visible = false
            else
                popup.visible = true
                updateContent()
            end
        end)
    ))

    -- Hover effects (store handlers for cleanup)
    buttonEnterHandler = function(c)
        c.bg = colors.icon_hover
    end
    buttonLeaveHandler = function(c)
        c.bg = colors.bg_button
    end
    button:connect_signal("mouse::enter", buttonEnterHandler)
    button:connect_signal("mouse::leave", buttonLeaveHandler)

    -- Controls table returned to caller
    local controls = {
        popup = popup,  -- Expose popup for external manipulation
        -- Show the popup
        show = function()
            popup.visible = true
            updateContent()
        end,
        -- Hide the popup
        hide = function()
            popup.visible = false
        end,
        -- Toggle the popup
        toggle = function()
            if popup.visible then
                popup.visible = false
            else
                popup.visible = true
                updateContent()
            end
        end,
        -- Refresh content
        refresh = updateContent,
        -- Set current tab
        set_tab = setActiveTab,
        -- Set current selector item
        set_selector = function(item)
            currentSelectorItem = item
            currentPage = 1
            updateContent()
        end,
        -- Set current page
        set_page = function(page)
            currentPage = page
            updateContent()
        end,
        -- Get current state
        get_state = function()
            return {
                tab = currentTab,
                page = currentPage,
                selector = currentSelectorItem,
            }
        end,
        -- Cleanup (call before removing widget to prevent memory leaks)
        destroy = function()
            -- Disconnect signal handlers from button
            button:disconnect_signal("mouse::enter", buttonEnterHandler)
            button:disconnect_signal("mouse::leave", buttonLeaveHandler)
            
            -- Disconnect signal handlers from tab widgets
            for _, tab in ipairs(tabs) do
                if tabWidgets[tab.id] then
                    tabWidgets[tab.id]:disconnect_signal("mouse::enter", tabEnterHandlers[tab.id])
                    tabWidgets[tab.id]:disconnect_signal("mouse::leave", tabLeaveHandlers[tab.id])
                end
            end
            
            -- Disconnect signal handlers from selector buttons
            if selectorItems and selectorButtonHandlers then
                for i, child in ipairs(selectorButtons.children or {}) do
                    if selectorButtonHandlers.enter[i] then
                        child:disconnect_signal("mouse::enter", selectorButtonHandlers.enter[i])
                    end
                    if selectorButtonHandlers.leave[i] then
                        child:disconnect_signal("mouse::leave", selectorButtonHandlers.leave[i])
                    end
                end
            end
            
            -- Clear references
            tabWidgets = {}
            tabEnterHandlers = {}
            tabLeaveHandlers = {}
            selectorButtons = nil
        end,
    }

    return centeredButton, popup, controls
end

return tabbed_window