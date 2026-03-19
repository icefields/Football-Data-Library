local http = require("socket.http")
local ltn12 = require("ltn12")
local ssl = require("ssl.https")
local cjson = require("cjson")

local ApiClient = {}

function ApiClient.new(apiKey, baseUrl, timeout)
    local self = setmetatable({}, {__index = ApiClient})
    self.apiKey = apiKey
    self.baseUrl = baseUrl
    self.timeout = timeout or 30
    return self
end

function ApiClient:request(endpoint, params)
    local url = self.baseUrl .. endpoint
    
    -- Build query string
    if params then
        local parts = {}
        for key, value in pairs(params) do
            table.insert(parts, key .. "=" .. tostring(value))
        end
        if #parts > 0 then
            url = url .. "?" .. table.concat(parts, "&")
        end
    end
    
    -- Response body collector
    local responseBody = {}
    
    -- Build request table
    local request = {
        url = url,
        method = "GET",
        headers = {
            ["X-Auth-Token"] = self.apiKey,
            ["Accept"] = "application/json"
        },
        sink = ltn12.sink.table(responseBody)
    }
    
    -- Make request
    -- When using table format with sink, returns: ok, code, headers
    -- ok is 1 on success, code is HTTP status
    local ok, statusCode
    
    if url:find("^https://") then
        ok, statusCode = ssl.request(request)
    else
        ok, statusCode = http.request(request)
    end
    
    -- Check response
    if not ok then
        error("API request failed: network error")
    end
    
    if statusCode ~= 200 then
        local bodyStr = table.concat(responseBody)
        error("API request failed: HTTP " .. tostring(statusCode) .. " - " .. bodyStr)
    end
    
    -- Parse JSON response
    local bodyStr = table.concat(responseBody)
    return cjson.decode(bodyStr)
end

function ApiClient:getCompetitions()
    return self:request("/competitions")
end

function ApiClient:getCompetitionMatches(code, params)
    return self:request("/competitions/" .. code .. "/matches", params)
end

function ApiClient:getTeamMatches(teamId, params)
    return self:request("/teams/" .. teamId .. "/matches", params)
end

function ApiClient:getCompetitionStandings(code, params)
    return self:request("/competitions/" .. code .. "/standings", params)
end

function ApiClient:getTeam(teamId)
    return self:request("/teams/" .. teamId)
end

function ApiClient:getCompetitionTeams(code)
    return self:request("/competitions/" .. code .. "/teams")
end

return ApiClient

