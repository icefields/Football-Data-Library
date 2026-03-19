#!/usr/bin/env lua
-- fetch_data.lua - Standalone script to fetch football data
-- Called by match_window widget via awful.spawn (async)
-- Usage: lua fetch_data.lua <cache_file> <team_id> <match_count> <competition_code>

-- Get script directory and add to package.path
local scriptPath = debug.getinfo(1, "S").source:match("^@(.+/)[^/]+$")
if scriptPath then
    -- Add library paths (relative to this script's location)
    package.path = scriptPath .. "../?.lua;" .. scriptPath .. "../?/init.lua;" .. package.path
end

local FootballData = require("football")
local cjson = require("cjson")

-- Get args
local cacheFile = arg[1]
local teamId = tonumber(arg[2]) or 108
local matchCount = tonumber(arg[3]) or 10
local competitionCode = arg[4] or "SA"

-- Find .env file (relative to library, not this script)
local envPath = scriptPath and (scriptPath .. "../.env") or ".env"

-- Initialize football app
local ok, app = pcall(function()
    return FootballData.initialize(envPath)
end)

if not ok then
    io.stderr:write("Failed to initialize: " .. tostring(app) .. "\n")
    os.exit(1)
end

-- Fetch both matches and standings
local matches = app.service:getTeamScores(teamId, matchCount, false)
local standings = app.service:getStandings(competitionCode)

-- Build result
local result = {
    matches = {
        data = matches,
        timestamp = os.time(),
    },
    standings = {
        data = standings,
        timestamp = os.time(),
        competition = competitionCode,
    },
}

-- Save to cache file
local file = io.open(cacheFile, "w")
if file then
    file:write(cjson.encode(result))
    file:close()
end

-- Output result as JSON (for callback)
print(cjson.encode(result))

app.database:close()