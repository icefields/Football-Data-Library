local View = {}

-- Helper to sanitize values (convert cjson.null userdata to nil)
function View.sanitize(val)
    if val == nil then return nil end
    if type(val) == "userdata" then return nil end
    return val
end

-- Helper to get nested value safely
function View.get(tbl, ...)
    local current = tbl
    for _, key in ipairs({...}) do
        if current == nil or type(current) ~= "table" then
            return nil
        end
        current = View.sanitize(current[key])
    end
    return current
end

-- Helper to format date (YYYY-MM-DD only)
function View.formatDate(dateStr)
    if not dateStr then return "N/A" end
    return dateStr:sub(1, 10)
end

-- Format a single match line
function View.formatMatch(match)
    local homeTeam = View.get(match, "homeTeam", "name") or "Unknown"
    local awayTeam = View.get(match, "awayTeam", "name") or "Unknown"
    local homeScore = View.get(match, "score", "fullTime", "home")
    local awayScore = View.get(match, "score", "fullTime", "away")
    local status = View.sanitize(match.status) or "UNKNOWN"
    local date = View.formatDate(View.sanitize(match.utcDate))
    local competition = View.get(match, "competition", "name") or "Unknown"
    
    if status == "SCHEDULED" or status == "POSTPONED" or status == "CANCELLED" then
        return string.format("[%s] %s vs %s (%s) - %s", 
            date, homeTeam, awayTeam, status, competition)
    else
        return string.format("[%s] %s %d - %d %s (%s) - %s", 
            date, homeTeam, homeScore or 0, awayScore or 0, awayTeam, status, competition)
    end
end

-- Format a single match line for scores (without competition)
function View.formatMatchShort(match)
    local homeTeam = View.get(match, "homeTeam", "name") or "Unknown"
    local awayTeam = View.get(match, "awayTeam", "name") or "Unknown"
    local homeScore = View.get(match, "score", "fullTime", "home")
    local awayScore = View.get(match, "score", "fullTime", "away")
    local status = View.sanitize(match.status) or "UNKNOWN"
    local date = View.formatDate(View.sanitize(match.utcDate))
    
    if status == "SCHEDULED" or status == "POSTPONED" or status == "CANCELLED" then
        return string.format("[%s] %s vs %s (%s)", date, homeTeam, awayTeam, status)
    else
        return string.format("[%s] %s %d - %d %s (%s)", 
            date, homeTeam, homeScore or 0, awayScore or 0, awayTeam, status)
    end
end

-- Format a standing row
function View.formatStanding(standing)
    local teamName = View.get(standing, "team", "name") or "Unknown"
    return string.format("%-4d %-30s %-4d %-4d %-4d %-4d %-4d %-+6d",
        View.sanitize(standing.position) or 0, 
        teamName, 
        View.sanitize(standing.playedGames) or 0,
        View.sanitize(standing.won) or 0,
        View.sanitize(standing.draw) or 0,
        View.sanitize(standing.lost) or 0,
        View.sanitize(standing.points) or 0,
        View.sanitize(standing.goalDifference) or 0)
end

-- Format a team row
function View.formatTeam(team)
    return string.format("%-8d %-35s %-8s %-30s",
        View.sanitize(team.id) or 0,
        View.sanitize(team.name) or "Unknown",
        View.sanitize(team.tla) or "N/A",
        View.sanitize(team.venue) or "N/A")
end

-- Format a league row
function View.formatLeague(league)
    return string.format("%-8s %-40s %-10s",
        View.sanitize(league.code) or "N/A",
        View.sanitize(league.name) or "Unknown",
        View.sanitize(league.plan) or "N/A")
end

-- Print leagues table
function View.printLeagues(leagues)
    print(string.format("%-8s %-40s %-10s", "CODE", "NAME", "PLAN"))
    print(string.rep("-", 60))
    for _, league in ipairs(leagues) do
        print(View.formatLeague(league))
    end
end

-- Print teams table
function View.printTeams(teams)
    print(string.format("%-8s %-35s %-8s %-30s", "ID", "NAME", "TLA", "VENUE"))
    print(string.rep("-", 85))
    for _, team in ipairs(teams) do
        print(View.formatTeam(team))
    end
end

-- Print matches
function View.printMatches(matches, showCompetition)
    showCompetition = showCompetition ~= false
    for _, match in ipairs(matches) do
        if showCompetition then
            print(View.formatMatch(match))
        else
            print(View.formatMatchShort(match))
        end
    end
end

-- Print standings table
function View.printStandings(standings, title)
    if title then
        print(title)
        print("")
    end
    print(string.format("%-4s %-30s %-4s %-4s %-4s %-4s %-4s %-6s", "POS", "TEAM", "P", "W", "D", "L", "PTS", "GD"))
    print(string.rep("-", 70))
    for _, standing in ipairs(standings) do
        print(View.formatStanding(standing))
    end
end

-- Print cached match (from database)
function View.printCachedMatch(match)
    local homeTeam = View.sanitize(match.homeTeamName) or "Unknown"
    local awayTeam = View.sanitize(match.awayTeamName) or "Unknown"
    local homeScore = View.sanitize(match.homeScore)
    local awayScore = View.sanitize(match.awayScore)
    local status = View.sanitize(match.status) or "UNKNOWN"
    
    if status == "SCHEDULED" or status == "POSTPONED" or status == "CANCELLED" then
        print(string.format("%s vs %s (%s)", homeTeam, awayTeam, status))
    else
        print(string.format("%s %d - %d %s (%s)", 
            homeTeam, homeScore or 0, awayScore or 0, awayTeam, status))
    end
end

-- Print cached standing (from database)
function View.printCachedStanding(standing)
    print(string.format("%d. %s - %d pts", 
        View.sanitize(standing.position) or 0, 
        View.sanitize(standing.teamName) or "Unknown",
        View.sanitize(standing.points) or 0))
end

-- Return standings as a formatted string (for widgets)
function View.getStandingsString(standings, title)
    local lines = {}
    if title then
        table.insert(lines, title)
        table.insert(lines, "")
    end
    table.insert(lines, string.format("%-4s %-30s %-4s %-4s %-4s %-4s %-4s %-6s", "POS", "TEAM", "P", "W", "D", "L", "PTS", "GD"))
    table.insert(lines, string.rep("-", 70))
    for _, standing in ipairs(standings) do
        table.insert(lines, View.formatStanding(standing))
    end
    return table.concat(lines, "\n")
end

-- Return matches as a formatted string (for widgets)
function View.getMatchesString(matches, showCompetition)
    showCompetition = showCompetition ~= false
    local lines = {}
    for _, match in ipairs(matches) do
        if showCompetition then
            table.insert(lines, View.formatMatch(match))
        else
            table.insert(lines, View.formatMatchShort(match))
        end
    end
    return table.concat(lines, "\n")
end

-- Month names for date formatting
local MONTHS = {
    "January", "February", "March", "April", "May", "June",
    "July", "August", "September", "October", "November", "December"
}

-- Format date from YYYY-MM-DD to "Month Day Year"
local function formatDateReadable(dateStr)
    if not dateStr then return "N/A" end
    local year, month, day = dateStr:match("^(%d%d%d%d)%-(%d%d)%-(%d%d)")
    if not year then return dateStr end
    local monthNum = tonumber(month)
    if monthNum < 1 or monthNum > 12 then return dateStr end
    local monthName = MONTHS[monthNum]
    local dayNum = tonumber(day)
    -- Remove leading zero from day
    return string.format("%s %d %s", monthName, dayNum, year)
end

-- Format results in a more readable format (for widgets)
-- Input: raw text from View.getMatchesString
-- Output: formatted with date on one line, teams + score on next
-- Format:
--   April 5 2026 (Serie A)
--   FC Internazionale Milano - AS Roma
-- or for finished:
--   March 14 2026 (Serie A)
--   FC Internazionale Milano - Atalanta BC 1 - 1
function View.getFormattedResults(rawResultsText)
    local lines = {}
    local foundFinished = false
    
    -- Collect all matches first to find the TIMED/FINISHED boundary
    local matches = {}
    for line in rawResultsText:gmatch("[^\n]+") do
        -- Parse: [YYYY-MM-DD] home-team score - score away-team (STATUS) - Competition
        local dateStr, homeTeam, homeScore, awayScore, awayTeam, status, competition = line:match(
            "^%[([^%]]+)%]%s*(.-)%s+(%d*)%s*-%s*(%d*)%s*(.-)%s+%(([^)]+)%)%s*-%s*(.+)$"
        )
        
        -- Try alternate format for scheduled/timed matches without scores
        if not dateStr then
            dateStr, homeTeam, awayTeam, status, competition = line:match(
                "^%[([^%]]+)%]%s*(.-)%s+vs%s+(.-)%s+%(([^)]+)%)%s*-%s*(.+)$"
            )
        end
        
        if dateStr then
            local isFinished = status and status ~= "TIMED" and status ~= "SCHEDULED" and status ~= "POSTPONED"
            table.insert(matches, {
                dateStr = dateStr,
                homeTeam = homeTeam or "Unknown",
                awayTeam = awayTeam or "Unknown",
                homeScore = homeScore,
                awayScore = awayScore,
                status = status,
                competition = competition or "Unknown",
                isFinished = isFinished
            })
        end
    end
    
    -- Now format with separator between TIMED and FINISHED
    local lastWasTimed = false
    for i, match in ipairs(matches) do
        -- Add separator before first finished match after timed ones
        if not match.isFinished then
            lastWasTimed = true
        elseif match.isFinished and lastWasTimed then
            table.insert(lines, "────────────────────────────────────────")
            lastWasTimed = false
        end
        
        -- Format date line
        local formattedDate = formatDateReadable(match.dateStr)
        table.insert(lines, string.format("%s (%s)", formattedDate, match.competition))
        
        -- Format match line
        local matchLine = string.format("%s - %s", match.homeTeam, match.awayTeam)
        
        -- Add score for finished matches only
        if match.isFinished and match.homeScore and match.awayScore then
            matchLine = matchLine .. string.format(" %s - %s", match.homeScore, match.awayScore)
        end
        
        table.insert(lines, matchLine)
        table.insert(lines, "")  -- Empty line between matches
    end
    
    -- Remove trailing empty line
    if #lines > 0 and lines[#lines] == "" then
        lines[#lines] = nil
    end
    
    return table.concat(lines, "\n")
end

return View

