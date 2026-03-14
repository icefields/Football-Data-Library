-- debug_env.lua
local function startsWith(str, prefix)
    return string.sub(str, 1, #prefix) == prefix
end

local function stripQuotes(str)
    return str:gsub("^['\"](.+)['\"]$", "%1")
end

local function debugLoadEnv(filePath)
    local file = io.open(filePath, "r")
    if not file then
        print("ERROR: Cannot open file: " .. filePath)
        print("Current directory: " .. (os.getenv("PWD") or "unknown"))
        return nil
    end
    
    print("=== DEBUG: Parsing " .. filePath .. " ===")
    print("")
    
    local envTable = {}
    local lineNum = 0
    
    for line in file:lines() do
        lineNum = lineNum + 1
        local rawLine = line
        local trimmedLine = line:match("^%s*(.-)%s*$")  -- trim whitespace
        
        print(string.format("Line %d: [%s]", lineNum, rawLine))
        print(string.format("  Trimmed: [%s]", trimmedLine))
        print(string.format("  Starts with #: %s", tostring(startsWith(trimmedLine, "#"))))
        print(string.format("  Has =: %s", tostring(trimmedLine:find("=") ~= nil)))
        
        if not startsWith(trimmedLine, "#") and trimmedLine ~= "" and trimmedLine:find("=") then
            local key, value = trimmedLine:match("^([%w_]+)=(.+)$")
            if key and value then
                value = stripQuotes(value)
                envTable[key] = value
                print(string.format("  >>> Parsed: key=[%s] value=[%s]", key, value))
            else
                print(string.format("  >>> FAILED to parse"))
            end
        else
            print("  >>> Skipped (comment/empty/no =)")
        end
        print("")
    end
    file:close()
    
    print("=== FINAL RESULT ===")
    for k, v in pairs(envTable) do
        print(string.format("  %s = [%s]", k, v))
    end
    
    return envTable
end

-- Run debug
debugLoadEnv(".env")

