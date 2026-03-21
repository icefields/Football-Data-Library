# Football Data Lua Library

A Lua library for fetching football (soccer) data from the football-data.org API. Supports caching to SQLite, filtering scheduled matches, and integrates easily with AwesomeWM widgets.

## Table of Contents

- [Features](#features)
- [Requirements](#requirements)
- [Installation](#installation)
- [Configuration](#configuration)
- [Project Structure](#project-structure)
- [Architecture](#architecture)
- [CLI Usage](#cli-usage)
- [Library API Reference](#library-api-reference)
- [View Functions Reference](#view-functions-reference)
- [AwesomeWM Integration](#awesomewm-integration)
- [Database Schema](#database-schema)
- [API Rate Limits](#api-rate-limits)
- [Examples](#examples)
- [Troubleshooting](#troubleshooting)

---

## Features

- Fetch live scores, standings, teams, and match data
- Filter out scheduled matches (show only played/in-progress)
- SQLite caching to reduce API calls
- Rate limiting to respect API quotas
- Clean separation of concerns (Service, Repository, View)
- AwesomeWM widget-ready output functions
- CLI tool for quick queries

## Requirements

- Lua 5.3+
- LuaSocket (`luarocks install luasocket`)
- LuaSec (`luarocks install luasec`)
- Lua-cjson (`luarocks install lua-cjson`)
- SQLite3 (`luarocks install lsqlite3`)

### Installation on Arch Linux

```bash
sudo pacman -S lua lua-socket lua-sec lua-cjson lua-sqlite
```

### Installation on Debian

```bash
sudo apt install lua5.3 lua-socket lua-sec lua-cjson lua-sql-sqlite3
```

### Installation via LuaRocks

```bash
luarocks install luasocket
luarocks install luasec
luarocks install lua-cjson
luarocks install lsqlite3
```

---

## Installation

```bash
# Clone the repository
git clone https://github.com/yourusername/football-lua.git
cd football-lua

# Create .env file from example
cp .env-example .env

# Edit .env with your API key
nvim .env

# Test the installation
lua cli.lua list-leagues
```

---

## Configuration

### Environment Variables

| Variable | Description | Required | Default |
|----------|-------------|----------|---------|
| `FOOTBALL_DATA_API_KEY` | Your API key from football-data.org | Yes | - |
| `DATABASE_PATH` | Path to SQLite database file | Yes | - |
| `API_BASE_URL` | API endpoint URL | Yes | `https://api.football-data.org/v4` |
| `REQUEST_TIMEOUT` | HTTP request timeout in seconds | No | `30` |
| `RATE_LIMIT_DELAY` | Delay between API calls in seconds | No | `6` |

### Getting an API Key

1. Visit https://www.football-data.org/client/register
2. Register for a free account
3. Check your email for the API key
4. Add it to your `.env` file

### Free Tier Limits

- 10 requests per minute
- Tier One competitions only (Premier League, La Liga, Bundesliga, Serie A, Ligue 1, Champions League, etc.)

---

## Project Structure

```
football-lua/
├── .env                    # Environment configuration (gitignore)
├── .env-example            # Example environment file
├── init.lua                # Module initialization
├── config.lua              # Environment loader
├── models.lua              # Data models and enums
├── api_client.lua          # HTTP client for football-data.org API
├── database.lua            # SQLite schema and queries
├── repository.lua          # Data access layer
├── service.lua             # Business logic and API orchestration
├── view.lua                # Formatting and display functions
├── cli.lua                 # Command-line interface
└── README.md               # This file
```

---

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                          CLI / Widget                            │
│                         (cli.lua / view.lua)                     │
└─────────────────────────────────────────────────────────────────┘
                                │
                                ▼
┌─────────────────────────────────────────────────────────────────┐
│                        Service Layer                            │
│                        (service.lua)                             │
│  • Business logic                                                │
│  • Rate limiting                                                 │
│  • Match filtering (hide scheduled)                             │
│  • Date sorting                                                  │
└─────────────────────────────────────────────────────────────────┘
                                │
                    ┌───────────┴───────────┐
                    ▼                       ▼
┌───────────────────────────┐   ┌───────────────────────────────┐
│     Repository Layer       │   │       API Client Layer        │
│     (repository.lua)       │   │     (api_client.lua)          │
│  • Data sanitization       │   │  • HTTP requests              │
│  • CRUD operations         │   │  • JSON parsing               │
│  • Type conversion         │   │  • Error handling             │
└───────────────────────────┘   └───────────────────────────────┘
                    │
                    ▼
┌─────────────────────────────────────────────────────────────────┐
│                      Database Layer                              │
│                      (database.lua)                              │
│  • SQLite schema                                                │
│  • Prepared statements                                          │
│  • Query execution                                              │
└─────────────────────────────────────────────────────────────────┘
```

---

## CLI Usage

### General Syntax

```bash
lua cli.lua <command> [parameters] [flags]
```

### Available Commands

#### `list-leagues`

List all available leagues with their codes.

```bash
lua cli.lua list-leagues
```

Output:
```
CODE    NAME                                     PLAN
------------------------------------------------------------
SA      Serie A                                  TIER_ONE
PL      Premier League                           TIER_ONE
PD      La Liga                                  TIER_ONE
...
```

---

#### `teams <code>`

List all teams in a league.

**Parameters:**
- `<code>` - League code (e.g., `SA`, `PL`, `PD`)

```bash
lua cli.lua teams SA
```

Output:
```
ID       NAME                                  TLA        VENUE
-------------------------------------------------------------------------------------
109      FC Internazionale Milano              INT        Stadio Giuseppe Meazza
102      AC Milan                              ACM        San Siro
...
```

---

#### `scores <code> [--hide-scheduled]`

Get latest scores for a league.

**Parameters:**
- `<code>` - League code (e.g., `SA`, `PL`, `PD`)

**Flags:**
- `--hide-scheduled` - Hide scheduled matches, show only played/in-progress

```bash
# Show all matches
lua cli.lua scores SA

# Show only played matches
lua cli.lua scores SA --hide-scheduled
```

Output:
```
SA

[2026-03-22] ACF Fiorentina vs FC Internazionale Milano (SCHEDULED)
[2026-03-17] FC Internazionale Milano 2 - 1 Feyenoord (FINISHED)
...
```

---

#### `team-scores <teamId> [count] [--hide-scheduled]`

Get latest matches for a specific team.

**Parameters:**
- `<teamId>` - Team ID (get from `teams` command)
- `[count]` - Number of matches to return (default: 1)

**Flags:**
- `--hide-scheduled` - Hide scheduled matches, show only played/in-progress

```bash
# Get last 5 matches for team 108 (Inter Milan)
lua cli.lua team-scores 108 5

# Get last 5 played matches
lua cli.lua team-scores 108 5 --hide-scheduled
```

Output:
```
[2026-03-22] ACF Fiorentina 0 - 0 FC Internazionale Milano (TIMED) - Serie A
[2026-03-17] FC Internazionale Milano 2 - 1 Feyenoord (FINISHED) - UEFA Champions League
...
```

---

#### `standings <code>`

Get current league standings.

**Parameters:**
- `<code>` - League code (e.g., `SA`, `PL`, `PD`)

```bash
lua cli.lua standings SA
```

Output:
```
SA

POS  TEAM                              P    W    D    L    PTS  GD
----------------------------------------------------------------------
1    FC Internazionale Milano          28   20   5    3    65   +42
2    AC Milan                          28   18   6    4    60   +30
...
```

---

#### `cache-scores <code>`

Get cached scores from local database (no API call).

**Parameters:**
- `<code>` - League code

```bash
lua cli.lua cache-scores SA
```

---

#### `cache-standings <code>`

Get cached standings from local database (no API call).

**Parameters:**
- `<code>` - League code

```bash
lua cli.lua cache-standings SA
```

---

### Common Competition Codes

| Code | Competition |
|------|-------------|
| `SA` | Serie A (Italy) |
| `PL` | Premier League (England) |
| `PD` | La Liga (Spain) |
| `BL1` | Bundesliga (Germany) |
| `FL1` | Ligue 1 (France) |
| `CL` | UEFA Champions League |
| `WC` | FIFA World Cup |
| `EC` | European Championship |
| `DED` | Eredivisie (Netherlands) |

---

## Library API Reference

### Initialization

```lua
local FootballData = require("init")
local app = FootballData.initialize([envPath])
```

**Parameters:**
- `envPath` (optional) - Path to `.env` file. Default: `.env`

**Returns:**
- Table with:
  - `config` - Configuration module
  - `models` - Models module
  - `database` - Database instance
  - `apiClient` - API client instance
  - `repository` - Repository instance
  - `service` - Service instance

**Example:**
```lua
local FootballData = require("init")

-- Initialize with default .env
local app = FootballData.initialize()

-- Or with custom path
local app = FootballData.initialize("/path/to/.env")
```

---

### Service Functions

#### `app.service:listLeagues()`

Fetch all available competitions/leagues.

**Returns:**
- Array of competition tables

**Example:**
```lua
local leagues = app.service:listLeagues()
for _, league in ipairs(leagues) do
    print(league.code, league.name)
end
```

---

#### `app.service:getLatestScores(leagueCode, showScheduled)`

Fetch latest matches for a competition.

**Parameters:**
- `leagueCode` (string) - Competition code (e.g., `"SA"`, `"PL"`)
- `showScheduled` (boolean, optional) - Include scheduled matches. Default: `true`

**Returns:**
- Array of match tables, sorted by date (most recent first)

**Example:**
```lua
-- Get all matches
local matches = app.service:getLatestScores("SA", true)

-- Get only played matches
local matches = app.service:getLatestScores("SA", false)

for _, match in ipairs(matches) do
    print(match.utcDate, match.homeTeam.name, match.awayTeam.name)
end
```

---

#### `app.service:getTeamScores(teamId, limit, showScheduled)`

Fetch latest matches for a specific team.

**Parameters:**
- `teamId` (number) - Team ID
- `limit` (number, optional) - Number of matches to return. Default: `1`
- `showScheduled` (boolean, optional) - Include scheduled matches. Default: `true`

**Returns:**
- Array of match tables, sorted by date (most recent first)

**Example:**
```lua
-- Get last 5 matches for team 108 (Inter Milan)
local matches = app.service:getTeamScores(108, 5, true)

-- Get last 5 played matches only
local matches = app.service:getTeamScores(108, 5, false)

for _, match in ipairs(matches) do
    print(match.utcDate, match.homeTeam.name, match.awayTeam.name, match.status)
end
```

---

#### `app.service:getStandings(leagueCode)`

Fetch current league standings.

**Parameters:**
- `leagueCode` (string) - Competition code

**Returns:**
- Array of standing tables

**Example:**
```lua
local standings = app.service:getStandings("SA")
for _, standing in ipairs(standings) do
    print(standing.position, standing.team.name, standing.points)
end
```

---

#### `app.service:getTeams(leagueCode)`

Fetch all teams in a competition.

**Parameters:**
- `leagueCode` (string) - Competition code

**Returns:**
- Array of team tables

**Example:**
```lua
local teams = app.service:getTeams("SA")
for _, team in ipairs(teams) do
    print(team.id, team.name, team.tla)
end
```

---

#### `app.service:getCachedMatchesByCompetition(code, limit)`

Get cached matches from local database (no API call).

**Parameters:**
- `code` (string) - Competition code
- `limit` (number) - Maximum number of matches

**Returns:**
- Array of match tables from database

**Example:**
```lua
local matches = app.service:getCachedMatchesByCompetition("SA", 10)
```

---

#### `app.service:getCachedMatchesByTeam(teamId, limit)`

Get cached matches for a team from local database.

**Parameters:**
- `teamId` (number) - Team ID
- `limit` (number) - Maximum number of matches

**Returns:**
- Array of match tables from database

---

#### `app.service:getCachedStandings(code)`

Get cached standings from local database.

**Parameters:**
- `code` (string) - Competition code

**Returns:**
- Array of standing tables from database

---

### Cleanup

Always close the database connection when done:

```lua
app.database:close()
```

---

## View Functions Reference

The `view.lua` module provides formatting functions for displaying data. These are useful for CLI output and widget integration.

### Loading the View Module

```lua
local View = require("view")
```

---

### Helper Functions

#### `View.sanitize(val)`

Convert `cjson.null` userdata to `nil`.

**Parameters:**
- `val` - Any value

**Returns:**
- `nil` if value is `nil` or `cjson.null`, otherwise the original value

---

#### `View.get(tbl, ...)`

Safely get nested table values.

**Parameters:**
- `tbl` - Table to access
- `...` - Keys to traverse

**Returns:**
- Value at path, or `nil` if any key is missing

**Example:**
```lua
local homeTeam = View.get(match, "homeTeam", "name")  -- match.homeTeam.name
local score = View.get(match, "score", "fullTime", "home")  -- match.score.fullTime.home
```

---

#### `View.formatDate(dateStr)`

Format ISO date string to `YYYY-MM-DD`.

**Parameters:**
- `dateStr` - ISO date string (e.g., `"2026-03-22T15:00:00Z"`)

**Returns:**
- `YYYY-MM-DD` string or `"N/A"`

---

### Formatting Functions

#### `View.formatMatch(match)`

Format a match with competition name.

**Parameters:**
- `match` - Match table

**Returns:**
- Formatted string (e.g., `"[2026-03-22] Inter vs Milan (FINISHED) - Serie A"`)

---

#### `View.formatMatchShort(match)`

Format a match without competition name.

**Parameters:**
- `match` - Match table

**Returns:**
- Formatted string (e.g., `"[2026-03-22] Inter 2 - 1 Milan (FINISHED)"`)

---

#### `View.formatStanding(standing)`

Format a standing row.

**Parameters:**
- `standing` - Standing table

**Returns:**
- Formatted string with position, team, games, wins, draws, losses, points, goal difference

---

#### `View.formatTeam(team)`

Format a team row.

**Parameters:**
- `team` - Team table

**Returns:**
- Formatted string with ID, name, TLA, venue

---

#### `View.formatLeague(league)`

Format a league row.

**Parameters:**
- `league` - Competition table

**Returns:**
- Formatted string with code, name, plan

---

### Print Functions

#### `View.printLeagues(leagues)`

Print leagues table.

**Example:**
```lua
local leagues = app.service:listLeagues()
View.printLeagues(leagues)
```

---

#### `View.printTeams(teams)`

Print teams table.

**Example:**
```lua
local teams = app.service:getTeams("SA")
View.printTeams(teams)
```

---

#### `View.printMatches(matches, showCompetition)`

Print matches.

**Parameters:**
- `matches` - Array of match tables
- `showCompetition` (boolean, optional) - Show competition name. Default: `true`

**Example:**
```lua
local matches = app.service:getTeamScores(108, 5, false)
View.printMatches(matches, true)  -- With competition
View.printMatches(matches, false) -- Without competition
```

---

#### `View.printStandings(standings, title)`

Print standings table.

**Parameters:**
- `standings` - Array of standing tables
- `title` (string, optional) - Title to print above table

**Example:**
```lua
local standings = app.service:getStandings("SA")
View.printStandings(standings, "SERIE A")
```

---

### String Functions (for Widgets)

#### `View.getStandingsString(standings, title)`

Get standings as a formatted string.

**Parameters:**
- `standings` - Array of standing tables
- `title` (string, optional) - Title to include

**Returns:**
- Formatted string (multi-line)

**Example:**
```lua
local standings = app.service:getStandings("SA")
local text = View.getStandingsString(standings, "SERIE A")
print(text)
-- Use in widget popup/tooltip
```

---

#### `View.getMatchesString(matches, showCompetition)`

Get matches as a formatted string.

**Parameters:**
- `matches` - Array of match tables
- `showCompetition` (boolean, optional) - Show competition name. Default: `true`

**Returns:**
- Formatted string (multi-line)

**Example:**
```lua
local matches = app.service:getTeamScores(108, 5, false)
local text = View.getMatchesString(matches, true)
print(text)
-- Use in widget popup/tooltip
```

---

## AwesomeWM Integration

### Match Window Widget (Recommended)

The library includes a full-featured popup widget with tabs, pagination, and selectors.

**Features:**
- Three tabs: Results, Standings, Champions League
- **Results tab selector**: Switch between Inter matches (team) or competition matches (Serie A, Premier League, La Liga, etc.)
- **Standings tab selector**: Switch between competitions (Serie A, Premier League, etc.)
- Pagination for Results and Champions League (10 matches per page)
- Per-tab selector state (remembers your choice when switching tabs)
- JSON file caching (5-minute timeout, no API calls on reload)
- Beautiful theme color integration
- Auto-refresh timer (configurable)

**Basic Usage:**

```lua
-- In your rc.lua
local awful = require("awful")
local wibox = require("wibox")
local gears = require("gears")
local beautiful = require("beautiful")

-- Add library paths
package.path = package.path .. ";/path/to/Football-Data-Library/?.lua;"
    .. ";/path/to/Football-Data-Library/?/init.lua;"

-- Require the match_window module
local match_window = require("awesome.match_window")

-- Create the widget
local football_widget, football_controls = match_window.create({
    awful = awful,
    wibox = wibox,
    gears = gears,
    beautiful = beautiful,
})

-- Add to your wibar
mywibar:setup({
    layout = wibox.layout.align.horizontal,
    {
        -- Left widgets
        mylauncher,
        s.mytaglist,
        s.mylayoutbox,
        football_widget,  -- Add here or wherever fits your layout
        -- ...
    },
    -- Middle and right widgets...
})

-- Cleanup on exit
awesome.connect_signal("exit", function()
    if football_controls.timer then
        football_controls.timer:stop()
    end
end)
```

---

### Configuration

Override default settings by passing a config table:

```lua
local football_widget, controls = match_window.create({
    awful = awful,
    wibox = wibox,
    gears = gears,
    beautiful = beautiful,
    -- Custom configuration
    config = {
        defaults = {
            team_id = 108,           -- Your team (Inter Milan default)
            match_count = 20,         -- Matches to fetch
            matches_per_page = 10,    -- Pagination
            cache_timeout = 300,      -- 5-minute cache
            auto_refresh = true,      -- Enable auto-refresh
            refresh_interval = 300,   -- 5 minutes
        },
        colors = {
            fg_text = "#ffffff",
            bg_popup = "#1a1a2e",
            -- ... see awesome_config.lua for all options
        },
        sizes = {
            window_min_width = 750,
            window_max_height = 950,
            -- ... see awesome_config.lua for all options
        },
    },
})
```

#### Key Configuration Options

| Option | Default | Description |
|--------|---------|-------------|
| `team_id` | 108 | Team ID for Results tab (108 = Inter Milan) |
| `match_count` | 30 | Number of matches to fetch |
| `matches_per_page` | 10 | Matches per page (pagination) |
| `cache_timeout` | 300 | Cache validity in seconds |
| `auto_refresh` | true | Enable automatic refresh timer |
| `refresh_interval` | 300 | Refresh interval in seconds |

#### Colors (from Beautiful Theme)

The widget uses these `beautiful` theme colors when available, falling back to config defaults:

| Beautiful Variable | Purpose |
|-------------------|---------|
| `topBar_fg` | Football icon color |
| `tooltip_bg_color` | Popup background |
| `tooltip_fg_color` | Popup text color |

#### Window Dimensions

| Size Option | Default | Description |
|-------------|---------|-------------|
| `window_min_width` | 750 | Minimum popup width |
| `window_max_width` | 750 | Maximum popup width |
| `window_min_height` | 740 | Minimum popup height |
| `window_max_height` | 950 | Maximum popup height |
| `content_max_height` | 700 | Maximum content area height |

---

### Adding or Removing Tabs

The widget has three tabs defined in `TAB_CONFIG` (in `match_window.lua`):

```lua
local TAB_CONFIG = {
    scores = { cache_key = "matches", has_pagination = true, fetch_mode = "team" },
    standings = { cache_key = "standings", has_pagination = false, fetch_mode = "team" },
    champions = { cache_key = "champions", has_pagination = true, fetch_mode = "champions" },
}
```

#### To Remove a Tab

Edit `match_window.lua` and:

1. Remove the tab from `TAB_CONFIG`
2. Remove the tab button widget (e.g., `championsTab`)
3. Remove the tab button click handler
4. Remove the tab hover effects

Example - Remove Champions League tab:

```lua
-- Remove from TAB_CONFIG
local TAB_CONFIG = {
    scores = { cache_key = "matches", has_pagination = true, fetch_mode = "team" },
    standings = { cache_key = "standings", has_pagination = false, fetch_mode = "team" },
    -- champions removed
}

-- Remove tab button declaration (around line 340)
-- local championsTab = ... (delete this)

-- Remove from tab bar layout (around line 700)
-- {
--     championsTab,  -- Remove this line
--     ...
-- }

-- Remove click handler (around line 890)
-- championsTab:buttons(...)

-- Remove hover effects (around line 920)
-- championsTab:connect_signal(...)
```

#### To Add a New Tab

1. Add entry to `TAB_CONFIG`:

```lua
local TAB_CONFIG = {
    scores = { cache_key = "matches", has_pagination = true, fetch_mode = "team" },
    standings = { cache_key = "standings", has_pagination = false, fetch_mode = "team" },
    champions = { cache_key = "champions", has_pagination = true, fetch_mode = "champions" },
    -- New tab for team stats
    stats = { cache_key = "stats", has_pagination = false, fetch_mode = "team" },
}
```

2. Create tab button widget:

```lua
local statsTab = wibox.widget {
    {
        {
            text = cfg.icons.results .. " Stats",  -- Use appropriate icon
            widget = wibox.widget.textbox,
            font = tabFont,
            align = "center",
        },
        widget = wibox.container.margin,
        margins = 10,
    },
    bg = colors.tab_inactive,
    fg = colors.fg_text,
    widget = wibox.container.background,
    forced_width = sizes.tab_width,
    forced_height = sizes.tab_height,
    shape = gears.shape.rounded_bar,
}
```

3. Add click handler:

```lua
statsTab:buttons(gears.table.join(
    awful.button({}, 1, function()
        setActiveTab("stats")
        updateContent()
    end)
))
```

4. Add hover effects:

```lua
statsTab:connect_signal("mouse::enter", function(c)
    if currentTab ~= "stats" then
        c.bg = colors.tab_hover
    end
end)
statsTab:connect_signal("mouse::leave", function(c)
    if currentTab ~= "stats" then
        c.bg = colors.tab_inactive
    end
end)
```

5. Add to tab bar layout (after `championsTab`).

6. Add fetch logic in `updateContent()` function.

---

### Pagination System

The Results and Champions League tabs use pagination (10 matches per page by default).

**How it works:**
- `matches_per_page` config controls items per page
- Prev/Next buttons appear when multiple pages exist
- Page indicator shows current page (e.g., "Page 1/3")
- Pagination state resets when switching tabs

**Adjust pagination:**

```lua
local football_widget, controls = match_window.create({
    -- ...
    config = {
        defaults = {
            matches_per_page = 15,  -- Show 15 matches per page
        },
    },
})
```

---

### Caching System

The widget uses JSON file caching to minimize API calls:

- **Cache file:** `~/.cache/football_data.json`
- **Cache timeout:** 5 minutes (configurable via `cache_timeout`)
- **Structure:** Separate cache entries for matches, standings, and champions

**Cache behavior:**
1. On widget open, load cached data immediately
2. If cache expired, fetch new data in background
3. Show cached data while fetching
4. Update display when new data arrives

**Force refresh:**
- Close and reopen widget after cache timeout
- Or invalidate cache programmatically:

```lua
controls.setTeamId(108)  -- This invalidates the matches cache
```

---

### Tab Selectors

Both Results and Standings tabs have selectors for switching data views.

**Results tab selector:**
- **Inter** - Shows Inter Milan's recent matches (team-specific)
- **Serie A, Premier League, La Liga, etc.** - Shows all matches from that competition

**Standings tab selector:**
- **Serie A, Premier League, La Liga, etc.** - Shows standings for that competition

**Customize Results selectors:**

```lua
local football_widget, controls = match_window.create({
    -- ...
    results_selectors = {
        { name = "Inter", code = "INTER", type = "team", team_id = 108 },
        { name = "Milan", code = "MILAN", type = "team", team_id = 98 },
        { name = "Serie A", code = "SA", type = "competition" },
        { name = "Premier League", code = "PL", type = "competition" },
    },
})
```

**Customize Standings competitions:**

```lua
local football_widget, controls = match_window.create({
    -- ...
    competitions = {
        { name = "Serie A", code = "SA" },
        { name = "Premier League", code = "PL" },
        { name = "Ligue 1", code = "FL1" },
    },
})
```

**Selector state persistence:**
- Each tab remembers its selector choice independently
- Switching tabs preserves your selections
- Data is fetched on-demand when changing selectors

---

### Data Fetching and Caching

**How data flows:**

1. **Widget opens** → Load cache from `~/.cache/football_data.json`
2. **Cache valid?** → Show cached data immediately
3. **Cache expired?** → Fetch fresh data in background
4. **User changes selector** → Fetch data for that selection

**Cache structure:**
```json
{
  "results": {
    "INTER": { "data": [...], "timestamp": 1234567890 },
    "SA": { "data": [...], "timestamp": 1234567890 },
    "PL": { "data": [...], "timestamp": 1234567890 }
  },
  "standings": {
    "SA": { "data": [...], "timestamp": 1234567890 },
    "PL": { "data": [...], "timestamp": 1234567890 }
  },
  "champions": { "data": [...], "timestamp": 1234567890 }
}
```

**Per-selector caching:**
- Each selector option has its own cache entry
- Switching between "Inter" and "Serie A" doesn't refetch if both are cached
- Cache timeout: 5 minutes (configurable via `cache_timeout`)

**Fetch modes (internal):**

| Mode | Command | Description |
|------|---------|-------------|
| `team` | `team <team_id> <count>` | Fetch matches for a specific team |
| `competition` | `competition <code> <count>` | Fetch matches for a competition |
| `standings` | `standings <code>` | Fetch standings for a competition |
| `champions` | `champions <code> <count>` | Fetch Champions League matches |

---

### Callbacks

**`on_selector_change(item, tabId)`**

Called when user clicks a selector button.

```lua
local football_widget, controls = match_window.create({
    -- ...
    on_selector_change = function(item, tabId)
        -- item = { name = "Serie A", code = "SA", type = "competition" }
        -- tabId = "standings" or "scores"
        print("User selected:", item.name, "on tab:", tabId)
    end,
})
```

**`content_provider(tabId, page, selector)`**

Called to render content for each tab/page/selector combination.

```lua
local football_widget, controls = match_window.create({
    -- ...
    content_provider = function(tabId, page, selector)
        -- tabId = "scores", "standings", or "champions"
        -- page = current page number (for pagination)
        -- selector = { name = "Serie A", code = "SA", ... } or nil
        
        if tabId == "standings" then
            local standings = getStandings(selector.code)
            return formatStandings(standings), 0
        elseif tabId == "scores" then
            local matches = getMatches(selector.code, page)
            return formatMatches(matches), #matches
        end
    end,
})
```

---

### Controls API

The `controls` table returned by `match_window.create()` provides methods for programmatic control:

```lua
local football_widget, controls = match_window.create({...})

-- Show/hide the popup
controls.show()
controls.hide()
controls.toggle()

-- Get current state
local state = controls.get_state()
-- Returns: { tab = "standings", page = 1, selector = { name = "Serie A", code = "SA" } }

-- Switch tabs programmatically
controls.set_tab("standings")

-- Change selector programmatically
controls.set_selector({ name = "Premier League", code = "PL" })

-- Change page (for paginated tabs)
controls.set_page(2)

-- Refresh content (refetch from API)
controls.refresh()
```

---

### Lifecycle

1. **Widget creation** (`match_window.create()`)
   - Initialize in-memory cache
   - Load persisted cache from disk
   - Build UI widgets
   - Return widget and controls

2. **First open** (`controls.show()`)
   - Build selector buttons for current tab
   - Call `content_provider()` with cached data
   - Fetch fresh data if cache expired

3. **User interaction**
   - Click tab → `setActiveTab()` → rebuild selectors if needed → fetch data
   - Click selector → `on_selector_change()` → fetch data for new selection
   - Click pagination → `updateContent()` with new page

4. **Cache persistence**
   - Save to disk after each successful fetch
   - Load from disk on widget creation
   - Legacy format auto-migrated to new format

---

### Team IDs Reference

| Team | ID |
|------|-----|
| Inter Milan | 108 |
| AC Milan | 98 |
| Juventus | 109 |
| Napoli | 113 |
| Arsenal | 57 |
| Chelsea | 61 |
| Manchester United | 66 |
| Manchester City | 65 |
| Liverpool | 64 |
| Barcelona | 81 |
| Real Madrid | 86 |
| Bayern Munich | 5 |

Find more team IDs using:
```bash
lua cli.lua teams SA  # List all Serie A teams
```

---

### Basic Widget (Simple Popup)

```lua
-- In your rc.lua
local awful = require("awful")
local wibox = require("wibox")
local gears = require("gears")

-- Add library path (adjust to your actual path)
package.path = package.path .. ";/path/to/football-lua/?.lua"

local FootballData = require("init")
local View = require("view")

-- Initialize (do this once at startup)
local footballApp = FootballData.initialize()

-- Create widget
local football_widget = wibox.widget({
    text = "⚽",
    widget = wibox.widget.textbox,
})

-- Create popup for standings
local standings_popup = awful.popup({
    widget = wibox.widget({
        {
            id = "content",
            text = "Loading...",
            widget = wibox.widget.textbox,
        },
        margins = 10,
        widget = wibox.container.margin,
    }),
    visible = false,
    ontop = true,
    placement = awful.placement.centered,
})

-- Update standings function
local function updateStandings(leagueCode)
    local standings = footballApp.service:getStandings(leagueCode)
    local text = View.getStandingsString(standings, leagueCode)
    standings_popup.widget.content.text = text
end

-- Toggle popup on click
football_widget:buttons(gears.table.join(
    awful.button({}, 1, function()
        if standings_popup.visible then
            standings_popup.visible = false
        else
            updateStandings("SA")  -- Serie A
            standings_popup.visible = true
        end
    end)
))

-- Add to wibar
mywibar:setup({
    {
        -- ... other widgets ...
        football_widget,
        -- ... other widgets ...
    },
    widget = wibox.container.align,
})
```

---

### Advanced Widget with Multiple Leagues

```lua
-- football_widget.lua
local awful = require("awful")
local wibox = require("wibox")
local gears = require("gears")
local beautiful = require("beautiful")

package.path = package.path .. ";/home/youruser/scripts/football-lua/?.lua"

local FootballData = require("init")
local View = require("view")

local app = FootballData.initialize()

local football = {}

-- Widget buttons
local buttons = {
    { "Serie A", "SA" },
    { "Premier League", "PL" },
    { "La Liga", "PD" },
    { "Bundesliga", "BL1" },
    { "Champions League", "CL" },
}

-- Create main widget
football.widget = wibox.widget({
    {
        id = "icon",
        text = "⚽",
        widget = wibox.widget.textbox,
    },
    margins = 4,
    widget = wibox.container.margin,
})

-- Create popup
football.popup = awful.popup({
    visible = false,
    ontop = true,
    placement = awful.placement.centered,
    widget = wibox.widget({
        {
            {
                {
                    text = "Football Standings",
                    font = beautiful.title_font,
                    widget = wibox.widget.textbox,
                },
                widget = wibox.container.margin,
                margins = 10,
            },
            {
                id = "buttons_container",
                layout = wibox.layout.flex.horizontal,
            },
            {
                id = "content",
                text = "Select a league",
                widget = wibox.widget.textbox,
            },
            layout = wibox.layout.align.vertical,
        },
        bg = beautiful.bg_normal,
        widget = wibox.container.background,
    }),
})

-- Add league buttons
for _, btn in ipairs(buttons) do
    local name, code = btn[1], btn[2]
    local button = wibox.widget({
        {
            text = name,
            widget = wibox.widget.textbox,
        },
        forced_width = 100,
        buttons = gears.table.join(
            awful.button({}, 1, function()
                local standings = app.service:getStandings(code)
                local text = View.getStandingsString(standings, name)
                football.popup.widget.content.text = text
            end)
        ),
        widget = wibox.container.background,
    })
    football.popup.widget.buttons_container:add(button)
end

-- Toggle popup on click
football.widget:buttons(gears.table.join(
    awful.button({}, 1, function()
        football.popup.visible = not football.popup.visible
    end)
))

-- Cleanup on awesome exit
awesome.connect_signal("exit", function()
    app.database:close()
end)

return football
```

---

### Team-Specific Widget

```lua
-- inter_widget.lua - Widget for Inter Milan
local awful = require("awful")
local wibox = require("wibox")
local gears = require("gears")
local beautiful = require("beautiful")

package.path = package.path .. ";/path/to/football-lua/?.lua"

local FootballData = require("init")
local View = require("view")

local app = FootballData.initialize()

-- Inter Milan team ID
local TEAM_ID = 108

-- Create widget showing last 5 match results
local function createTeamWidget()
    local widget = wibox.widget({
        {
            {
                id = "team_name",
                text = "Inter Milan",
                font = beautiful.font_name .. " bold 12",
                widget = wibox.widget.textbox,
            },
            {
                id = "matches",
                text = "Loading...",
                font = beautiful.font_name .. " 10",
                widget = wibox.widget.textbox,
            },
            layout = wibox.layout.fixed.vertical,
        },
        margins = 10,
        widget = wibox.container.margin,
    })

    local function refresh()
        -- Get last 5 played matches
        local matches = app.service:getTeamScores(TEAM_ID, 5, false)
        local text = View.getMatchesString(matches, true)
        widget.matches.text = text
    end

    -- Refresh on click
    widget:buttons(gears.table.join(
        awful.button({}, 1, refresh)
    ))

    -- Auto-refresh every 5 minutes
    local refresh_timer = gears.timer({
        timeout = 300,
        autostart = true,
        call_now = true,
        callback = refresh,
    })

    return widget
end

return createTeamWidget()
```

---

### Using in Naughty Notifications

```lua
local naughty = require("naughty")

local FootballData = require("init")
local View = require("view")

local app = FootballData.initialize()

-- Show standings notification
local function showStandingsNotification(leagueCode)
    local standings = app.service:getStandings(leagueCode)
    local text = View.getStandingsString(standings, leagueCode)
    
    naughty.notification({
        title = leagueCode .. " Standings",
        text = text,
        timeout = 10,
        position = "top_right",
    })
end

-- Usage
showStandingsNotification("SA")
```

---

## Database Schema

```sql
-- Leagues table
CREATE TABLE leagues (
    id TEXT PRIMARY KEY,
    code TEXT UNIQUE NOT NULL,
    name TEXT NOT NULL,
    plan TEXT,
    emblem TEXT,
    lastUpdated DATETIME DEFAULT CURRENT_TIMESTAMP
);

-- Teams table
CREATE TABLE teams (
    id INTEGER PRIMARY KEY,
    name TEXT NOT NULL,
    shortName TEXT,
    tla TEXT,
    crest TEXT,
    founded INTEGER,
    venue TEXT,
    lastUpdated DATETIME DEFAULT CURRENT_TIMESTAMP
);

-- Matches table
CREATE TABLE matches (
    id INTEGER PRIMARY KEY,
    competitionId TEXT NOT NULL,
    season TEXT,
    matchday INTEGER,
    utcDate TEXT NOT NULL,
    status TEXT,
    homeTeamId INTEGER,
    awayTeamId INTEGER,
    homeScore INTEGER,
    awayScore INTEGER,
    winner TEXT,
    lastUpdated DATETIME DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (competitionId) REFERENCES leagues(code),
    FOREIGN KEY (homeTeamId) REFERENCES teams(id),
    FOREIGN KEY (awayTeamId) REFERENCES teams(id)
);

-- Standings table
CREATE TABLE standings (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    competitionId TEXT NOT NULL,
    season TEXT,
    type TEXT,
    stage TEXT,
    groupText TEXT,
    position INTEGER,
    teamId INTEGER,
    playedGames INTEGER,
    won INTEGER,
    draw INTEGER,
    lost INTEGER,
    points INTEGER,
    goalsFor INTEGER,
    goalsAgainst INTEGER,
    goalDifference INTEGER,
    lastUpdated DATETIME DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (competitionId) REFERENCES leagues(code),
    FOREIGN KEY (teamId) REFERENCES teams(id),
    UNIQUE(competitionId, season, type, teamId)
);

-- Indexes for performance
CREATE INDEX idx_matches_competition ON matches(competitionId);
CREATE INDEX idx_matches_date ON matches(utcDate);
CREATE INDEX idx_standings_competition ON standings(competitionId);
```

---

## API Rate Limits

| Tier | Requests/Minute | Competitions |
|------|-----------------|--------------|
| Free | 10 | Tier One only |
| Standard | 30 | All competitions |
| Professional | 60+ | All competitions |

### Rate Limiting in Code

The library automatically adds delays between API calls based on the `RATE_LIMIT_DELAY` setting in `.env`:

```lua
function Service:fetchWithRateLimit()
    os.execute("sleep " .. self.rateLimitDelay)
end
```

Default is 6 seconds (10 requests/minute for free tier).

---

## Examples

### Complete Usage Example

```lua
#!/usr/bin/env lua

local FootballData = require("init")
local View = require("view")

-- Initialize
local app = FootballData.initialize()

-- List all leagues
print("=== AVAILABLE LEAGUES ===")
local leagues = app.service:listLeagues()
View.printLeagues(leagues)
print("")

-- Get teams in Serie A
print("=== SERIE A TEAMS ===")
local teams = app.service:getTeams("SA")
View.printTeams(teams)
print("")

-- Get Inter Milan's last 5 played matches
print("=== INTER MILAN LAST 5 MATCHES ===")
local matches = app.service:getTeamScores(108, 5, false)  -- team 108, limit 5, hide scheduled
View.printMatches(matches, true)
print("")

-- Get Serie A standings
print("=== SERIE A STANDINGS ===")
local standings = app.service:getStandings("SA")
View.printStandings(standings, "SERIE A")
print("")

-- Get latest Serie A scores (played only)
print("=== LATEST SERIE A RESULTS ===")
local scores = app.service:getLatestScores("SA", false)  -- hide scheduled
View.printMatches(scores, false)
print("")

-- Cleanup
app.database:close()
```

---

### Get String for Widget

```lua
local FootballData = require("init")
local View = require("view")

local app = FootballData.initialize()

-- Get standings as string for widget
local standings = app.service:getStandings("SA")
local standingsText = View.getStandingsString(standings, "SERIE A")

-- Get team matches as string
local matches = app.service:getTeamScores(108, 5, false)
local matchesText = View.getMatchesString(matches, true)

-- Use in your widget
print(standingsText)
print("---")
print(matchesText)

app.database:close()
```

---

### Error Handling Example

```lua
local FootballData = require("init")
local app = FootballData.initialize()

-- Wrap API calls in pcall for error handling
local success, result = pcall(function()
    return app.service:getStandings("SA")
end)

if success then
    print("Got " .. #result .. " standings")
    for _, standing in ipairs(result) do
        print(standing.position, standing.team.name, standing.points)
    end
else
    print("Error fetching standings: " .. result)
end

app.database:close()
```

---

## Troubleshooting

### Common Errors

#### `module 'socket.http' not found`

Install LuaSocket:
```bash
luarocks install luasocket
```

#### `module 'ssl.https' not found`

Install LuaSec:
```bash
luarocks install luasec
```

#### `module 'cjson' not found`

Install lua-cjson:
```bash
luarocks install lua-cjson
```

#### `module 'lsqlite3' not found`

Install lsqlite3:
```bash
luarocks install lsqlite3
```

#### `API request failed: HTTP 400`

Invalid competition code or parameters. Check the competition code against the list from `list-leagues`.

#### `API request failed: HTTP 403`

Invalid API key. Verify your key in `.env` and ensure it's active at football-data.org.

#### `API request failed: HTTP 429`

Rate limit exceeded. Wait a minute and try again. Increase `RATE_LIMIT_DELAY` in `.env`.

#### `Database error: unable to open database file`

Ensure the directory in `DATABASE_PATH` exists:
```bash
mkdir -p $(dirname /path/to/your/database.db)
```

### Debug Mode

Enable verbose output for debugging:

```lua
-- Add to your script for debugging
local function debugPrint(...)
    print("[DEBUG]", ...)
end

-- Use in service calls
local success, result = pcall(function()
    return app.service:getStandings("SA")
end)

if not success then
    debugPrint("Error:", result)
end
```

---

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Submit a pull request

---

## Acknowledgments

- football-data.org for providing the API
- LuaSocket/LuaSec for HTTP support
- lsqlite3 for SQLite bindings
```

---

This comprehensive README covers everything: installation, configuration, architecture, all CLI commands with parameters, the complete library API reference, view functions, AwesomeWM integration examples, database schema, rate limits, troubleshooting, and usage examples. The `.env-example` provides all necessary configuration placeholders. 🐧

