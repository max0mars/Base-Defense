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

function WaveDirector:getBudgetForWave(waveNumber, globalDifficulty)
    -- Phase 5 dual-difficulty scaling formula
    -- baseBudgets for 5 waves
    local baseBudgets = {30, 45, 65, 95, 150}
    
    local wave = math.max(1, math.min(5, waveNumber))
    local base = baseBudgets[wave]
    
    local multiplier = 1 + (globalDifficulty - 1) * (0.3 + (wave - 1) * 0.1)
    return math.floor(base * multiplier)
end

function WaveDirector:generateWaveList(waveNumber, globalDifficulty)
    globalDifficulty = globalDifficulty or 1
    local totalBudget = self:getBudgetForWave(waveNumber, globalDifficulty)
    local available = EnemyRegistry:getAvailableEnemies()
    local waveList = {}
    local currentCounts = {} -- Placeholder for constraints tracker

    -- Composition tracking for the wave preview UI (counts spawn-events per enemy id)
    local summaryCounts = {} -- [id] = count
    local summaryMeta = {}   -- [id] = index entry
    local summaryOrder = {}  -- ids in order of first appearance

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

                if not summaryMeta[e.id] then
                    summaryMeta[e.id] = e
                    summaryCounts[e.id] = 0
                    table.insert(summaryOrder, e.id)
                end
                summaryCounts[e.id] = summaryCounts[e.id] + 1
                break
            end
        end
    end

    -- Shuffle waveList for variety (optional but recommended)
    for i = #waveList, 2, -1 do
        local j = math.random(i)
        waveList[i], waveList[j] = waveList[j], waveList[i]
    end

    -- Build an ordered summary, hardest (most expensive) enemies first
    local summary = {}
    for _, id in ipairs(summaryOrder) do
        local e = summaryMeta[id]
        table.insert(summary, {
            id = id,
            type = e.type,
            count = summaryCounts[id],
            spawnCost = e.spawnCost or 0
        })
    end
    table.sort(summary, function(a, b) return a.spawnCost > b.spawnCost end)

    print(string.format("[WaveDirector] Wave %d | Budget: %d | Enemies: %d", waveNumber, totalBudget, #waveList))
    return waveList, summary
end

function WaveDirector:checkConstraints(enemy, currentCounts)
    -- Placeholder for future min/max constraints per enemy type
    return true
end

return WaveDirector
