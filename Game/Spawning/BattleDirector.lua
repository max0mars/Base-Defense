local WaveDirector = require("Game.Spawning.WaveDirector")

local BattleDirector = {}
BattleDirector.__index = BattleDirector

function BattleDirector:new(game)
    local obj = setmetatable({}, self)
    obj.game = game
    return obj
end

function BattleDirector:generateBattle(globalDifficulty)
    local wd = WaveDirector:new(self.game)
    
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
