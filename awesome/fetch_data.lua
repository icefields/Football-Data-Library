#!/usr/bin/env lua
-- fetch_data.lua - Standalone script to fetch football data
-- Called by match_window widget via awful.spawn (async)
-- Usage: 
--   lua fetch_data.lua <cache_file> <team_id> <match_count> <competition_code>
--   lua fetch_data.lua <cache_file> team <team_id> <match_count>
--   lua fetch_data.lua <cache_file> competition <competition_code> <match_count>
--   lua fetch_data.lua <cache_file> champions <competition_code> <match_count>
--   lua fetch_data.lua <cache_file> standings <competition_code>

-- Get script directory and add to package.path
local scriptPath = debug.getinfo(1, "S").source:match("^@(.+/)[^/]+$")
if scriptPath then
    -- Add library paths (relative to this script's location)
    package.path = scriptPath .. "../?.lua;" .. scriptPath .. "../?/init.lua;" .. package.path
    -- Add C module paths for luarocks-installed modules (cjson, etc.)
    local home = os.getenv("HOME") or ""
    package.cpath = home .. "/.luarocks/lib/lua/5.4/?.so;" .. package.cpath
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
    elseif mode == "team" then
        -- Fetch team matches
        -- Usage: lua fetch_data.lua <cache_file> team <team_id> <match_count>
        local teamId = tonumber(arg[3]) or 108
        local matchCount = tonumber(arg[4]) or 30
        
        local matches = app.service:getTeamScores(teamId, matchCount, false)
        
        result = {
            results = {
                INTER = {  -- Use "INTER" as key for Inter team
                    data = matches,
                    timestamp = os.time(),
                },
            },
        }
    elseif mode == "competition" then
        -- Fetch competition matches
        -- Usage: lua fetch_data.lua <cache_file> competition <code> <match_count>
        local competitionCode = arg[3] or "SA"
        local matchCount = tonumber(arg[4]) or 30
        
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
            results = {
                [competitionCode] = {
                    data = matches,
                    timestamp = os.time(),
                },
            },
        }
    elseif mode == "standings" then
        -- Fetch standings for one or all competitions
        -- Usage: 
        --   lua fetch_data.lua <cache_file> standings          (all competitions)
        --   lua fetch_data.lua <cache_file> standings SA       (single competition)
        local singleComp = arg[3]
        
        local competitions
        if singleComp then
            competitions = { { name = singleComp, code = singleComp } }
        else
            competitions = {
                { name = "Serie A", code = "SA" },
                { name = "Premier League", code = "PL" },
                { name = "La Liga", code = "PD" },
                { name = "Bundesliga", code = "BL1" },
                { name = "Champions League", code = "CL" },
            }
        end
        
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