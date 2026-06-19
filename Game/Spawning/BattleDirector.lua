local WaveDirector = require("Game.Spawning.WaveDirector")

local BattleDirector = {}
BattleDirector.__index = BattleDirector

BattleDirector.ExampleProfiles = {
    Standard = {
        isSpecialEvent = false,
        allowedTiers = {1, 2, 3},
        maxDistinctEnemyTypes = 5,
        allowedTypes = {"melee", "ranged", "magic", "goblin"}
    },
    BossAmbush = {
        isSpecialEvent = true,
        allowedTiers = {3, 4, 5},
        maxDistinctEnemyTypes = 2,
        allowedTypes = {"boss", "elite", "melee"}
    }
}

function BattleDirector:new(game)
    local obj = setmetatable({}, self)
    obj.game = game
    return obj
end

function BattleDirector:generateBattle(globalDifficulty, profile)
    local wd = WaveDirector:new(self.game)
    
    if profile then
        print("maxDistinctEnemyTypes from profile: " .. tostring(profile.maxDistinctEnemyTypes))
    else
        print("maxDistinctEnemyTypes from profile: nil")
    end
    
    local upcomingWaves = {}
    local upcomingSummaries = {}
    local forecastTotals = {}
    
    -- Always calculate waves 1 through 5 for the battle
    for i = 1, 5 do
        local list, summary = wd:generateWaveList(i, globalDifficulty)
        table.insert(upcomingWaves, list)
        table.insert(upcomingSummaries, summary)
        
        for _, s in ipairs(summary) do
            forecastTotals[s.type] = (forecastTotals[s.type] or 0) + s.count
        end
    end
    
    return upcomingWaves, upcomingSummaries, forecastTotals
end

return BattleDirector
