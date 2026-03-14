#!/usr/bin/env lua

local FootballData = require("init")
local View = require("view")

local CLI = {}

-- Parse command line args and flags
function CLI.parseArgs(args)
    local command = args[1]
    local params = {}
    local flags = {}
    
    for i = 2, #args do
        local arg = args[i]
        if arg:sub(1, 2) == "--" then
            local flag = arg:sub(3)
            flags[flag] = true
        else
            table.insert(params, arg)
        end
    end
    
    return command, params, flags
end

-- Helper to check for flag
local function hasFlag(flags, flagName)
    return flags[flagName] ~= nil
end

function CLI.showHelp()
    print([[
Football Data CLI

Usage: lua cli.lua <command> [options] [flags]

Commands:
  list-leagues              List all available leagues with codes
  teams <code>              List teams in a league
  scores <code>             Get latest scores for a league
  team-scores <teamId> [n]  Get last n matches for a team (default: 1)
  standings <code>          Get league standings
  cache-scores <code>       Get cached scores from database
  cache-standings <code>    Get cached standings from database
  help                      Show this help message

Flags:
  --hide-scheduled          Hide scheduled matches (only show played/in-progress)

Examples:
  lua cli.lua list-leagues
  lua cli.lua teams SA
  lua cli.lua scores SA
  lua cli.lua scores SA --hide-scheduled
  lua cli.lua team-scores 108 6
  lua cli.lua team-scores 108 10 --hide-scheduled
  lua cli.lua standings PL

Common Competition Codes:
  SA   - Serie A
  PL   - Premier League
  PD   - La Liga
  BL1  - Bundesliga
  FL1  - Ligue 1
  CL   - UEFA Champions League
  WC   - FIFA World Cup
]])
end

function CLI.execute(command, params, flags)
    if not command or command == "help" then
        CLI.showHelp()
        return
    end
    
    local showScheduled = not hasFlag(flags, "hide-scheduled")
    local app = FootballData.initialize()
    
    if command == "list-leagues" then
        local leagues = app.service:listLeagues()
        View.printLeagues(leagues)
    
    elseif command == "teams" then
        if not params[1] then
            print("Error: League code required")
            os.exit(1)
        end
        local teams = app.service:getTeams(params[1])
        View.printTeams(teams)
    
    elseif command == "scores" then
        if not params[1] then
            print("Error: League code required")
            os.exit(1)
        end
        local scores = app.service:getLatestScores(params[1], showScheduled)
        print(params[1]:upper())
        print("")
        View.printMatches(scores, false)
    
    elseif command == "team-scores" then
        if not params[1] then
            print("Error: Team ID required")
            os.exit(1)
        end
        local limit = params[2] and tonumber(params[2]) or 1
        local scores = app.service:getTeamScores(tonumber(params[1]), limit, showScheduled)
        View.printMatches(scores, true)
    
    elseif command == "standings" then
        if not params[1] then
            print("Error: League code required")
            os.exit(1)
        end
        local standings = app.service:getStandings(params[1])
        View.printStandings(standings, params[1]:upper())
    
    elseif command == "cache-scores" then
        if not params[1] then
            print("Error: League code required")
            os.exit(1)
        end
        local scores = app.service:getCachedMatchesByCompetition(params[1], 10)
        for _, match in ipairs(scores) do
            View.printCachedMatch(match)
        end
    
    elseif command == "cache-standings" then
        if not params[1] then
            print("Error: League code required")
            os.exit(1)
        end
        local standings = app.service:getCachedStandings(params[1])
        for _, standing in ipairs(standings) do
            View.printCachedStanding(standing)
        end
    
    else
        print("Unknown command: " .. command)
        CLI.showHelp()
    end
    
    app.database:close()
end

-- Entry point
local args = {...}
local command, params, flags = CLI.parseArgs(args)
CLI.execute(command, params, flags)

return CLI

