local BattleTemplate = {}
BattleTemplate.__index = BattleTemplate

function BattleTemplate:new(config)
    assert(config.id, "BattleTemplate requires an 'id'")
    assert(config.battleDangerTiers, "BattleTemplate requires 'battleDangerTiers'")

    local obj = setmetatable({}, self)
    
    -- Required Fields
    obj.id = config.id
    obj.battleDangerTiers = config.battleDangerTiers
    
    -- Level criteria (can be left empty / nil)
    obj.minimumLevel = config.minimumLevel or (config.validBattleRange and config.validBattleRange.min)
    obj.maximumLevel = config.maximumLevel or (config.validBattleRange and config.validBattleRange.max)
    
    -- Optional Fields with safe defaults
    obj.numWaves = config.numWaves
    obj.lanesPerWave = config.lanesPerWave
    obj.weight = config.weight or 10
    obj.relativeDifficulty = config.relativeDifficulty or {}
    obj.waveDangerTiers = config.waveDangerTiers or {}
    obj.allowedTypes = config.allowedTypes or {}
    obj.specificEnemies = config.specificEnemies or {}
    obj.specificWaveEnemies = config.specificWaveEnemies or {}
    obj.budgets = config.budgets
    obj.count = 0
    obj.limit = config.limit

    return obj
end

-- Checks if this template can be rolled for the current battle
-- A template should only be used if it meets the minimum and maximum criteria
function BattleTemplate:isValidForBattle(battleNumber)
    if self.limit and self.count >= self.limit then
        return false
    end
    if self.minimumLevel and battleNumber < self.minimumLevel then
        return false
    end
    if self.maximumLevel and battleNumber > self.maximumLevel then
        return false
    end
    return true
end

-- Safely retrieves lane counts if defined on template (fallback for custom overrides)
function BattleTemplate:getLanesForWave(waveIndex)
    if self.lanesPerWave and self.lanesPerWave[waveIndex] then
        return self.lanesPerWave[waveIndex]
    end
    if self.lanesPerWave and #self.lanesPerWave > 0 then
        return self.lanesPerWave[#self.lanesPerWave]
    end
    return nil
end

return BattleTemplate