local EnemyRegistry = require("Game.Spawning.EnemyRegistry")

local WaveDirector = {}
WaveDirector.__index = WaveDirector

function WaveDirector:new(game)
    local obj = setmetatable({}, self)
    obj.game = game
    
    -- Accelerated scaling for a 40-wave game (Wave 1 = 30)
    obj.baseBudget = 30
    obj.linearRamp = 25
    obj.exponentialKicker = 3.5
    
    return obj
end

-- Faster Early Scaling Table (Wave 1 = 30):
-- Wave 1:  30
-- Wave 10: 255 (Fast early ramp)
-- Wave 20: 855
-- Wave 30: 2135
-- Wave 40: 4155 (Final Challenge)

function WaveDirector:getBudgetForWave(waveNumber)
    -- Wave 1 starts at exactly baseBudget.
    -- Subsequent early waves scale linearly, then exponentially after Wave 10.
    local linearPart = (waveNumber - 1) * self.linearRamp
    local exponentialPart = (math.max(0, waveNumber - 10) ^ 2) * self.exponentialKicker
    
    return self.baseBudget + linearPart + exponentialPart
end

function WaveDirector:generateWaveList(waveNumber)
    local totalBudget = self:getBudgetForWave(waveNumber)
    local available = EnemyRegistry:getAvailableEnemies(waveNumber)
    local waveList = {}
    local currentCounts = {} -- Placeholder for constraints tracker
    
    local remainingBudget = totalBudget
    
    while remainingBudget > 0 do
        local affordable = {}
        local totalWeight = 0
        
        for _, e in ipairs(available) do
            if e.spawnCost <= remainingBudget and self:checkConstraints(e, currentCounts) then
                table.insert(affordable, e)
                totalWeight = totalWeight + (e.spawnWeight or 10)
            end
        end
        
        -- Stop if no more enemies can be afforded
        if #affordable == 0 then break end
        
        -- Weighted random selection
        local r = math.random(1, totalWeight)
        local runningWeight = 0
        for _, e in ipairs(affordable) do
            runningWeight = runningWeight + (e.spawnWeight or 10)
            if r <= runningWeight then
                table.insert(waveList, e.class)
                remainingBudget = remainingBudget - e.spawnCost
                currentCounts[e.type] = (currentCounts[e.type] or 0) + 1
                break
            end
        end
    end
    
    -- Shuffle waveList for variety (optional but recommended)
    for i = #waveList, 2, -1 do
        local j = math.random(i)
        waveList[i], waveList[j] = waveList[j], waveList[i]
    end
    
    print(string.format("[WaveDirector] Wave %d | Budget: %d | Enemies: %d", waveNumber, totalBudget, #waveList))
    return waveList
end

function WaveDirector:checkConstraints(enemy, currentCounts)
    -- Placeholder for future min/max constraints per enemy type
    return true
end

return WaveDirector
