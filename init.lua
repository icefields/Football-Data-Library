local config = require("config")
local Models = require("models")
local Database = require("database")
local ApiClient = require("api_client")
local Repository = require("repository")
local Service = require("service")

local FootballData = {}

function FootballData.initialize(envPath)
    envPath = envPath or ".env"
    config.env = config.loadEnv(envPath)
    config.validateEnv(config.env)
    
    local db = Database.new(config.env.DATABASE_PATH):open()
    local apiClient = ApiClient.new(
        config.env.FOOTBALL_DATA_API_KEY,
        config.env.API_BASE_URL,
        tonumber(config.env.REQUEST_TIMEOUT)
    )
    local repository = Repository.new(db)
    local service = Service.new(apiClient, repository)
    
    return {
        config = config,
        models = Models,
        database = db,
        apiClient = apiClient,
        repository = repository,
        service = service
    }
end

return FootballData

