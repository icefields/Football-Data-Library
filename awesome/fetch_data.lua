#!/usr/bin/env lua
-- fetch_data.lua - Standalone script to fetch football data
-- Called by match_window widget via awful.spawn (async)
-- Usage: 
--   lua fetch_data.lua <cache_file> <team_id> <match_count> <competition_code>
--   lua fetch_data.lua <cache_file> champions <competition_code> <match_count>

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
local mode = arg[2]

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

local result

if mode == "champions" then
    -- Fetch Champions League matches
    local competitionCode = arg[3] or "CL"
    local matchCount = tonumber(arg[4]) or 20
    
    local matches = app.service:getLatestScores(competitionCode, false)
    
    result = {
        champions = {
            data = matches,
            timestamp = os.time(),
        },
    }
else
    -- Fetch team matches and standings
    local teamId = tonumber(arg[2]) or 108
    local matchCount = tonumber(arg[3]) or 10
    local competitionCode = arg[4] or "SA"
    
    local matches = app.service:getTeamScores(teamId, matchCount, false)
    local standings = app.service:getStandings(competitionCode)
    
    result = {
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
end

-- Save to cache file
local file = io.open(cacheFile, "w")
if file then
    file:write(cjson.encode(result))
    file:close()
end

-- Output result as JSON (for callback)
print(cjson.encode(result))

app.database:close()