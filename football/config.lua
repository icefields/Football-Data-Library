-- football/config.lua
local config = {}

-- Get the directory where this module is located
local modulePath = debug.getinfo(1, "S").source:match("^@(.+)/football/config.lua$")

local function startsWith(str, prefix)
    if not str or not prefix then return false end
    return string.sub(str, 1, #prefix) == prefix
end

local function trim(str)
    if not str then return "" end
    return str:match("^%s*(.-)%s*$") or ""
end

local function stripQuotes(str)
    if not str then return "" end
    return str:gsub("^['\"](.+)['\"]$", "%1")
end

function config.loadEnv(filePath)
    local file = io.open(filePath, "r")
    if not file then
        error("Environment file not found: " .. filePath)
    end
    
    local envTable = {}
    for line in file:lines() do
        local trimmedLine = trim(line)
        -- Skip comments and empty lines
        if not startsWith(trimmedLine, "#") and trimmedLine ~= "" then
            local eqPos = trimmedLine:find("=")
            if eqPos then
                local key = trim(trimmedLine:sub(1, eqPos - 1))
                local value = trim(trimmedLine:sub(eqPos + 1))
                value = stripQuotes(value)
                envTable[key] = value
            end
        end
    end
    file:close()
    
    return envTable
end

function config.getDefaultEnvPath()
    -- Return path to .env relative to this module's location
    if modulePath then
        return modulePath .. "/.env"
    end
    return ".env"
end

function config.validateEnv(envTable)
    local requiredKeys = {"FOOTBALL_DATA_API_KEY", "DATABASE_PATH", "API_BASE_URL"}
    for _, key in ipairs(requiredKeys) do
        if not envTable[key] then
            error("Missing required env variable: " .. key)
        end
    end
    return envTable
end

return config

