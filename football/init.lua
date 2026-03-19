-- football/init.lua
-- Entry point for the Football Data library
-- Usage: local FootballData = require("football")

local config = require("football.config")
local Models = require("football.models")
local Database = require("football.database")
local ApiClient = require("football.api_client")
local Repository = require("football.repository")
local Service = require("football.service")

local FootballData = {}

function FootballData.initialize(envPath)
    envPath = envPath or config.getDefaultEnvPath()
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