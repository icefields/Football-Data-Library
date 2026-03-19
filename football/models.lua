local Models = {}

-- Enum-style Competition class
Models.Competition = {
    SERIE_A = "seriea",
    CHAMPIONS_LEAGUE = "champions",
    WORLD_CUP = "world",
    PREMIER_LEAGUE = "pl",
    LA_LIGA = "pd",
    BUNDESLIGA = "bl1",
    LIGUE_1 = "fl1",
    EREDIVISIE = "ded",
    CHAMPIONSHIP = "elm",
    EUROPEAN_CHAMPIONSHIP = "ec",
    COPA_AMERICA = "ca",
    CLUB_WORLD_CUP = "cwc"
}

Models.Competition.names = {
    ["seriea"] = "Serie A",
    ["champions"] = "UEFA Champions League",
    ["world"] = "FIFA World Cup",
    ["pl"] = "Premier League",
    ["pd"] = "La Liga",
    ["bl1"] = "Bundesliga",
    ["fl1"] = "Ligue 1",
    ["ded"] = "Eredivisie",
    ["elm"] = "Championship",
    ["ec"] = "European Championship",
    ["ca"] = "Copa América",
    ["cwc"] = "Club World Cup"
}

Models.Competition.list = function()
    local leagues = {}
    for key, code in pairs(Models.Competition) do
        if type(code) == "string" then
            table.insert(leagues, {code = code, name = Models.Competition.names[code], key = key})
        end
    end
    return leagues
end

-- Match model
Models.Match = {
    id = nil,
    homeTeam = nil,
    awayTeam = nil,
    homeScore = nil,
    awayScore = nil,
    status = nil,
    matchday = nil,
    utcDate = nil,
    competition = nil
}

-- Team model
Models.Team = {
    id = nil,
    name = nil,
    shortName = nil,
    tla = nil,
    crest = nil,
    founded = nil,
    venue = nil
}

-- Standing model
Models.Standing = {
    position = nil,
    team = nil,
    playedGames = nil,
    won = nil,
    draw = nil,
    lost = nil,
    points = nil,
    goalsFor = nil,
    goalsAgainst = nil,
    goalDifference = nil
}

return Models

