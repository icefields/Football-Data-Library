-- football/service.lua
local Models = require("football.models")
local ApiClient = require("football.api_client")
local Repository = require("football.repository")
local config = require("football.config")

local Service = {}

function Service.new(apiClient, repository)
    local self = setmetatable({}, {__index = Service})
    self.apiClient = apiClient
    self.repository = repository
    self.rateLimitDelay = tonumber(config.env.RATE_LIMIT_DELAY) or 6
    return self
end

function Service:fetchWithRateLimit()
    os.execute("sleep " .. self.rateLimitDelay)
end

-- Helper to filter out scheduled matches
local function filterScheduled(matches, showScheduled)
    if showScheduled then
        return matches
    end
    local filtered = {}
    for _, match in ipairs(matches) do
        if match.status ~= "SCHEDULED" then
            table.insert(filtered, match)
        end
    end
    return filtered
end

-- Helper to sort matches by date (descending - most recent first)
local function sortByDateDesc(matches)
    table.sort(matches, function(a, b)
        local dateA = a.utcDate or ""
        local dateB = b.utcDate or ""
        return dateA > dateB
    end)
    return matches
end

function Service:listLeagues()
    local response = self.apiClient:getCompetitions()
    
    for _, competition in ipairs(response.competitions) do
        local competitionData = {
            id = competition.id,
            code = competition.code,
            name = competition.name,
            plan = competition.plan,
            emblem = competition.emblem,
            currentSeason = competition.currentSeason and competition.currentSeason.startDate or nil
        }
        self.repository:saveCompetition(competitionData)
    end
    
    return response.competitions
end

function Service:getLatestScores(leagueCode, showScheduled)
    showScheduled = (showScheduled == nil) and true or showScheduled
    self:fetchWithRateLimit()
    
    local response = self.apiClient:getCompetitionMatches(leagueCode, {limit = 50})
    
    if response.matches then
        self.repository:saveMatches(response.matches, leagueCode)
    end
    
    local filtered = filterScheduled(response.matches, showScheduled)
    return sortByDateDesc(filtered)
end

function Service:getTeamScores(teamId, limit, showScheduled)
    limit = limit or 1
    showScheduled = (showScheduled == nil) and true or showScheduled
    self:fetchWithRateLimit()
    
    -- Fetch more matches to account for filtering
    local response = self.apiClient:getTeamMatches(teamId, {limit = limit * 5})
    
    if response.matches then
        local competitionCode = response.matches[1].competition and response.matches[1].competition.code or "unknown"
        self.repository:saveMatches(response.matches, competitionCode)
    end
    
    local filtered = filterScheduled(response.matches, showScheduled)
    local sorted = sortByDateDesc(filtered)
    
    -- Limit after filtering and sorting
    local result = {}
    for i = 1, math.min(limit, #sorted) do
        table.insert(result, sorted[i])
    end
    
    return result
end

function Service:getStandings(leagueCode)
    self:fetchWithRateLimit()
    
    local response = self.apiClient:getCompetitionStandings(leagueCode)
    
    if response.standings and response.standings[1] then
        local standing = response.standings[1]
        self.repository:saveStandings(standing.table, leagueCode)
        return standing.table
    end
    
    return {}
end

function Service:getTeams(leagueCode)
    self:fetchWithRateLimit()
    
    local response = self.apiClient:getCompetitionTeams(leagueCode)
    
    if response.teams then
        for _, team in ipairs(response.teams) do
            self.repository:saveTeam(team)
        end
    end
    
    return response.teams
end

function Service:getCachedMatchesByCompetition(code, limit)
    return self.repository:getMatchesByCompetition(code, limit)
end

function Service:getCachedMatchesByTeam(teamId, limit)
    return self.repository:getMatchesByTeam(teamId, limit)
end

function Service:getCachedStandings(code)
    return self.repository:getStandingsByCompetition(code)
end

return Service

