local BattleTemplate = {}
BattleTemplate.__index = BattleTemplate

function BattleTemplate:new(config)
    assert(config.id, "BattleTemplate requires an 'id'")
    assert(config.validBattleRange and config.validBattleRange.min and config.validBattleRange.max, "BattleTemplate requires a validBattleRange {min, max}")
    assert(config.numWaves, "BattleTemplate requires 'numWaves'")
    assert(config.lanesPerWave, "BattleTemplate requires 'lanesPerWave' array")
    assert(config.battleDangerTiers, "BattleTemplate requires 'battleDangerTiers'")

    local obj = setmetatable({}, self)
    
    -- Required Fields
    obj.id = config.id
    obj.validBattleRange = config.validBattleRange
    obj.numWaves = config.numWaves
    obj.lanesPerWave = config.lanesPerWave
    obj.battleDangerTiers = config.battleDangerTiers
    
    -- Optional Fields with safe defaults
    obj.weight = config.weight or 10
    obj.relativeDifficulty = config.relativeDifficulty or {}
    obj.waveDangerTiers = config.waveDangerTiers or {}
    obj.allowedTypes = config.allowedTypes or {}
    obj.specificEnemies = config.specificEnemies or {}
    obj.specificWaveEnemies = config.specificWaveEnemies or {}
    obj.budgets = config.budgets

    return obj
end

-- Checks if this template can be rolled for the current battle
function BattleTemplate:isValidForBattle(battleNumber)
    return battleNumber >= self.validBattleRange.min and battleNumber <= self.validBattleRange.max
end

-- Safely retrieves lane counts to prevent nil errors in WaveDirector
function BattleTemplate:getLanesForWave(waveIndex)
    if self.lanesPerWave[waveIndex] then
        return self.lanesPerWave[waveIndex]
    end
    -- Fallback in case of data entry error
    return self.lanesPerWave[#self.lanesPerWave] or 1 
end

return BattleTemplate