-- football/repository.lua
local Models = require("football.models")
local Database = require("football.database")

local Repository = {}

-- Helper to convert cjson.null to nil and handle userdata
local function sanitizeValue(value)
    if value == nil then return nil end
    if type(value) == "userdata" then return nil end
    return value
end

-- Helper to convert nested values safely
local function safeGet(tbl, ...)
    local current = tbl
    for _, key in ipairs({...}) do
        if current == nil or type(current) ~= "table" then
            return nil
        end
        current = current[key]
    end
    return sanitizeValue(current)
end

function Repository.new(database)
    local self = setmetatable({}, {__index = Repository})
    self.db = database
    return self
end

function Repository:saveCompetition(competitionData)
    self.db:upsertLeague({
        id = sanitizeValue(competitionData.id),
        code = sanitizeValue(competitionData.code),
        name = sanitizeValue(competitionData.name),
        plan = sanitizeValue(competitionData.plan),
        emblem = sanitizeValue(competitionData.emblem),
        currentSeason = safeGet(competitionData, "currentSeason", "startDate")
    })
end

function Repository:saveTeam(teamData)
    self.db:upsertTeam({
        id = sanitizeValue(teamData.id),
        name = sanitizeValue(teamData.name),
        shortName = sanitizeValue(teamData.shortName),
        tla = sanitizeValue(teamData.tla),
        crest = sanitizeValue(teamData.crest),
        founded = sanitizeValue(teamData.founded),
        venue = sanitizeValue(teamData.venue)
    })
end

function Repository:saveMatch(matchData)
    self.db:insertMatch({
        id = sanitizeValue(matchData.id),
        competitionId = sanitizeValue(matchData.competitionId),
        season = safeGet(matchData, "season", "startDate"),
        matchday = sanitizeValue(matchData.matchday),
        utcDate = sanitizeValue(matchData.utcDate),
        status = sanitizeValue(matchData.status),
        homeTeamId = safeGet(matchData, "homeTeam", "id"),
        awayTeamId = safeGet(matchData, "awayTeam", "id"),
        homeScore = safeGet(matchData, "score", "fullTime", "home"),
        awayScore = safeGet(matchData, "score", "fullTime", "away"),
        winner = safeGet(matchData, "score", "winner")
    })
end

function Repository:saveStanding(standingData)
    self.db:upsertStanding({
        competitionId = sanitizeValue(standingData.competitionId),
        season = safeGet(standingData, "season", "startDate"),
        type = sanitizeValue(standingData.type),
        stage = sanitizeValue(standingData.stage),
        groupText = sanitizeValue(standingData.group),
        position = sanitizeValue(standingData.position),
        teamId = safeGet(standingData, "team", "id"),
        playedGames = sanitizeValue(standingData.playedGames),
        won = sanitizeValue(standingData.won),
        draw = sanitizeValue(standingData.draw),
        lost = sanitizeValue(standingData.lost),
        points = sanitizeValue(standingData.points),
        goalsFor = sanitizeValue(standingData.goalsFor),
        goalsAgainst = sanitizeValue(standingData.goalsAgainst),
        goalDifference = sanitizeValue(standingData.goalDifference)
    })
end

function Repository:saveMatches(matches, competitionCode)
    for _, match in ipairs(matches) do
        -- Save teams first
        if match.homeTeam then
            self:saveTeam(match.homeTeam)
        end
        if match.awayTeam then
            self:saveTeam(match.awayTeam)
        end
        
        -- Save match
        self:saveMatch(match)
    end
end

function Repository:saveStandings(standings, competitionCode)
    for _, standing in ipairs(standings) do
        if standing.team then
            self:saveTeam(standing.team)
        end
        self:saveStanding(standing)
    end
end

function Repository:getMatchesByCompetition(code, limit)
    return self.db:getMatchesByCompetition(code, limit)
end

function Repository:getMatchesByTeam(teamId, limit)
    return self.db:getMatchesByTeam(teamId, limit)
end

function Repository:getStandingsByCompetition(code)
    return self.db:getStandingsByCompetition(code)
end

return Repository

