local sqlite3 = require("lsqlite3")
local config = require("config")

local Database = {}

function Database.new(dbPath)
    local self = setmetatable({}, {__index = Database})
    self.dbPath = dbPath
    self.db = nil
    return self
end

function Database:open()
    local dir = self.dbPath:match("(.*)/[^/]+$")
    if dir then
        os.execute("mkdir -p " .. dir)
    end
    
    self.db = sqlite3.open(self.dbPath)
    if not self.db then
        error("Failed to open database: " .. self.dbPath)
    end
    
    self:createTables()
    return self
end

function Database:createTables()
    local schema = [[
    CREATE TABLE IF NOT EXISTS leagues (
        id TEXT PRIMARY KEY,
        code TEXT UNIQUE NOT NULL,
        name TEXT NOT NULL,
        plan TEXT,
        emblem TEXT,
        currentSeason TEXT,
        lastUpdated DATETIME DEFAULT CURRENT_TIMESTAMP
    );
    
    CREATE TABLE IF NOT EXISTS teams (
        id INTEGER PRIMARY KEY,
        name TEXT NOT NULL,
        shortName TEXT,
        tla TEXT,
        crest TEXT,
        founded INTEGER,
        venue TEXT,
        lastUpdated DATETIME DEFAULT CURRENT_TIMESTAMP
    );
    
    CREATE TABLE IF NOT EXISTS matches (
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
    
    CREATE TABLE IF NOT EXISTS standings (
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
    
    CREATE INDEX IF NOT EXISTS idx_matches_competition ON matches(competitionId);
    CREATE INDEX IF NOT EXISTS idx_matches_date ON matches(utcDate);
    CREATE INDEX IF NOT EXISTS idx_standings_competition ON standings(competitionId);
    ]]
    
    local result = self.db:exec(schema)
    if result ~= sqlite3.OK then
        error("Failed to create schema: " .. self.db:errmsg())
    end
end

function Database:close()
    if self.db then
        self.db:close()
        self.db = nil
    end
end

function Database:upsertLeague(leagueData)
    local sql = [[
    INSERT OR REPLACE INTO leagues (id, code, name, plan, emblem, currentSeason)
    VALUES (?, ?, ?, ?, ?, ?)
    ]]
    local stmt = self.db:prepare(sql)
    stmt:bind(1, leagueData.id)
    stmt:bind(2, leagueData.code)
    stmt:bind(3, leagueData.name)
    stmt:bind(4, leagueData.plan)
    stmt:bind(5, leagueData.emblem)
    stmt:bind(6, leagueData.currentSeason)
    stmt:step()
    stmt:finalize()
end

function Database:upsertTeam(teamData)
    local sql = [[
    INSERT OR REPLACE INTO teams (id, name, shortName, tla, crest, founded, venue)
    VALUES (?, ?, ?, ?, ?, ?, ?)
    ]]
    local stmt = self.db:prepare(sql)
    stmt:bind(1, teamData.id)
    stmt:bind(2, teamData.name)
    stmt:bind(3, teamData.shortName)
    stmt:bind(4, teamData.tla)
    stmt:bind(5, teamData.crest)
    stmt:bind(6, teamData.founded)
    stmt:bind(7, teamData.venue)
    stmt:step()
    stmt:finalize()
end

function Database:insertMatch(matchData)
    local sql = [[
    INSERT OR REPLACE INTO matches 
    (id, competitionId, season, matchday, utcDate, status, homeTeamId, awayTeamId, homeScore, awayScore, winner)
    VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
    ]]
    local stmt = self.db:prepare(sql)
    stmt:bind(1, matchData.id)
    stmt:bind(2, matchData.competitionId)
    stmt:bind(3, matchData.season)
    stmt:bind(4, matchData.matchday)
    stmt:bind(5, matchData.utcDate)
    stmt:bind(6, matchData.status)
    stmt:bind(7, matchData.homeTeamId)
    stmt:bind(8, matchData.awayTeamId)
    stmt:bind(9, matchData.homeScore)
    stmt:bind(10, matchData.awayScore)
    stmt:bind(11, matchData.winner)
    stmt:step()
    stmt:finalize()
end

function Database:upsertStanding(standingData)
    local sql = [[
    INSERT OR REPLACE INTO standings 
    (competitionId, season, type, stage, groupText, position, teamId, playedGames, won, draw, lost, points, goalsFor, goalsAgainst, goalDifference)
    VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
    ]]
    local stmt = self.db:prepare(sql)
    stmt:bind(1, standingData.competitionId)
    stmt:bind(2, standingData.season)
    stmt:bind(3, standingData.type)
    stmt:bind(4, standingData.stage)
    stmt:bind(5, standingData.groupText)
    stmt:bind(6, standingData.position)
    stmt:bind(7, standingData.teamId)
    stmt:bind(8, standingData.playedGames)
    stmt:bind(9, standingData.won)
    stmt:bind(10, standingData.draw)
    stmt:bind(11, standingData.lost)
    stmt:bind(12, standingData.points)
    stmt:bind(13, standingData.goalsFor)
    stmt:bind(14, standingData.goalsAgainst)
    stmt:bind(15, standingData.goalDifference)
    stmt:step()
    stmt:finalize()
end

function Database:getMatchesByCompetition(code, limit)
    local sql = [[
    SELECT m.*, ht.name as homeTeamName, at.name as awayTeamName
    FROM matches m
    JOIN teams ht ON m.homeTeamId = ht.id
    JOIN teams at ON m.awayTeamId = at.id
    WHERE m.competitionId = ?
    ORDER BY m.utcDate DESC
    LIMIT ?
    ]]
    local stmt = self.db:prepare(sql)
    stmt:bind(1, code)
    stmt:bind(2, limit)
    local results = {}
    for row in stmt:nrows() do
        table.insert(results, row)
    end
    stmt:finalize()
    return results
end

function Database:getMatchesByTeam(teamId, limit)
    local sql = [[
    SELECT m.*, ht.name as homeTeamName, at.name as awayTeamName, l.name as leagueName
    FROM matches m
    JOIN teams ht ON m.homeTeamId = ht.id
    JOIN teams at ON m.awayTeamId = at.id
    JOIN leagues l ON m.competitionId = l.code
    WHERE m.homeTeamId = ? OR m.awayTeamId = ?
    ORDER BY m.utcDate DESC
    LIMIT ?
    ]]
    local stmt = self.db:prepare(sql)
    stmt:bind(1, teamId)
    stmt:bind(2, teamId)
    stmt:bind(3, limit)
    local results = {}
    for row in stmt:nrows() do
        table.insert(results, row)
    end
    stmt:finalize()
    return results
end

function Database:getStandingsByCompetition(code)
    local sql = [[
    SELECT s.*, t.name as teamName
    FROM standings s
    JOIN teams t ON s.teamId = t.id
    WHERE s.competitionId = ?
    ORDER BY s.position ASC
    ]]
    local stmt = self.db:prepare(sql)
    stmt:bind(1, code)
    local results = {}
    for row in stmt:nrows() do
        table.insert(results, row)
    end
    stmt:finalize()
    return results
end

return Database

