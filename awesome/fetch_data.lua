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
    -- Extract error message (after last colon, or full message)
    local errMsg = tostring(app):match(": ([^:]+)$") or tostring(app):match("^[^:]+: (.+)$") or tostring(app)
    io.stderr:write(errMsg .. "\n")
    os.exit(1)
end

local result

local success, err = pcall(function()
    if mode == "champions" then
        -- Fetch Champions League matches
        local competitionCode = arg[3] or "CL"
        local matchCount = tonumber(arg[4]) or 15
        
        local allMatches = app.service:getLatestScores(competitionCode, false)
        
        -- Filter to only finished matches and limit to count
        local matches = {}
        for _, match in ipairs(allMatches) do
            if match.status == "FINISHED" then
                table.insert(matches, match)
                if #matches >= matchCount then
                    break
                end
            end
        end
        
        result = {
            champions = {
                data = matches,
                timestamp = os.time(),
            },
        }
    elseif mode == "standings" then
        -- Fetch standings for ALL competitions
        -- Usage: lua fetch_data.lua <cache_file> standings
        local competitions = {
            { name = "Serie A", code = "SA" },
            { name = "Premier League", code = "PL" },
            { name = "La Liga", code = "PD" },
            { name = "Bundesliga", code = "BL1" },
            { name = "Champions League", code = "CL" },
        }
        
        local standingsCache = {}
        for _, comp in ipairs(competitions) do
            local standings = app.service:getStandings(comp.code)
            if standings then
                standingsCache[comp.code] = {
                    data = standings,
                    timestamp = os.time(),
                }
            end
        end
        
        result = {
            standings = standingsCache,
        }
    else
        -- Fetch team matches and standings for current competition
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
                [competitionCode] = {
                    data = standings,
                    timestamp = os.time(),
                },
            },
        }
    end
end)

if not success then
    -- Extract error message (after last colon, or full message)
    local errMsg = tostring(err):match(": ([^:]+)$") or tostring(err):match("^[^:]+: (.+)$") or tostring(err)
    io.stderr:write(errMsg .. "\n")
    os.exit(1)
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