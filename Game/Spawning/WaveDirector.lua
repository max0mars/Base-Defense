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

function WaveDirector:generateWaveList(waveIndex, battleRoster, template, globalDifficulty)
    if type(battleRoster) == "number" then
        globalDifficulty = battleRoster
        battleRoster = nil
    end

    globalDifficulty = globalDifficulty or 1
    local totalBudget = self:getBudgetForWave(waveIndex, globalDifficulty)
    local laneCount = 1

    if template then
        if template.getLanesForWave then
            laneCount = template:getLanesForWave(waveIndex)
        elseif template.lanesPerWave then
            laneCount = template.lanesPerWave[waveIndex] or template.lanesPerWave[#template.lanesPerWave] or 1
        end

        if template.relativeDifficulty and template.relativeDifficulty[waveIndex] then
            totalBudget = math.floor(totalBudget * template.relativeDifficulty[waveIndex])
        end
    end

    if not battleRoster then
        battleRoster = EnemyRegistry:getAvailableEnemies()
    end

    local available = {}
    if template and template.waveDangerTiers and template.waveDangerTiers[waveIndex] then
        local allowedTiers = {}
        for key, _ in pairs(template.waveDangerTiers[waveIndex]) do
            local tierName = key:match("^(tier%d+)m[axin]+$")
            if tierName then
                local tierNum = tonumber(tierName:match("tier(%d+)"))
                if tierNum then
                    allowedTiers[tierNum + 2] = true
                end
            end
        end

        for _, e in ipairs(battleRoster) do
            if allowedTiers[e.tier] then
                table.insert(available, e)
            end
        end
    else
        available = battleRoster
    end

    local waveList = {}
    local currentCounts = {}
    local summaryCounts = {}
    local summaryMeta = {}
    local summaryOrder = {}

    local remainingBudget = totalBudget

    local function addEnemySpawns(enemy, count)
        if count <= 0 then return end
        for _ = 1, count do
            table.insert(waveList, enemy.class)
        end
        remainingBudget = remainingBudget - (count * enemy.spawnCost)
        currentCounts[enemy.type] = (currentCounts[enemy.type] or 0) + count

        if not summaryMeta[enemy.id] then
            summaryMeta[enemy.id] = enemy
            summaryCounts[enemy.id] = 0
            table.insert(summaryOrder, enemy.id)
        end
        summaryCounts[enemy.id] = summaryCounts[enemy.id] + count
    end

    if template and template.specificWaveEnemies and template.specificWaveEnemies[waveIndex] then
        local composition = template.specificWaveEnemies[waveIndex]
        local function findEnemy(name)
            local lowerName = name:lower()
            for _, e in ipairs(battleRoster) do
                if e.id:lower() == lowerName or e.type:lower() == lowerName then
                    return e
                end
            end
            for _, e in ipairs(EnemyRegistry.allEnemies) do
                if e.id:lower() == lowerName or e.type:lower() == lowerName then
                    return e
                end
            end
            return nil
        end

        for name, ratio in pairs(composition) do
            local enemy = findEnemy(name)
            if enemy then
                local allocated = totalBudget * ratio
                local count = math.floor(allocated / enemy.spawnCost)
                addEnemySpawns(enemy, count)
            end
        end
    end

    while remainingBudget > 0 do
        local affordable = {}
        local totalWeight = 0

        for _, e in ipairs(available) do
            if e.spawnCost <= remainingBudget and self:checkConstraints(e, currentCounts) then
                table.insert(affordable, e)
                totalWeight = totalWeight + (e.spawnWeight or 10)
            end
        end

        if #affordable == 0 then break end

        local r = math.random(1, totalWeight)
        local runningWeight = 0
        for _, e in ipairs(affordable) do
            runningWeight = runningWeight + (e.spawnWeight or 10)
            if r <= runningWeight then
                addEnemySpawns(e, 1)
                break
            end
        end
    end

    for i = #waveList, 2, -1 do
        local j = math.random(i)
        waveList[i], waveList[j] = waveList[j], waveList[i]
    end

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

    print(string.format("[WaveDirector] Wave %d | Budget: %d | Enemies: %d | Lanes: %d", waveIndex, totalBudget, #waveList, laneCount))
    return waveList, summary, laneCount
end

function WaveDirector:checkConstraints(enemy, currentCounts)
    -- Placeholder for future min/max constraints per enemy type
    return true
end

return WaveDirector
