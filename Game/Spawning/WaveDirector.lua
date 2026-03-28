local EnemyRegistry = require("Game.Spawning.EnemyRegistry")

local WaveDirector = {}
WaveDirector.__index = WaveDirector

function WaveDirector:new(game)
    local obj = setmetatable({}, self)
    obj.game = game
    return obj
end

function WaveDirector:getBudgetForWave(waveNumber)
    --return 150
    return 30 + (waveNumber-1)*25
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
