local EnemyRegistry = require("Game.Spawning.EnemyRegistry")

local WaveDirector = {}
WaveDirector.__index = WaveDirector

function WaveDirector:new(game)
    local obj = setmetatable({}, self)
    obj.game = game
    
    -- Accelerated scaling for a 40-wave game (Wave 1 = 30)
    -- obj.baseBudget = 30
    -- obj.linearRamp = 25
    -- obj.exponentialKicker = 3.5
    
    return obj
end

function WaveDirector:generateWaveList(waveIndex, battleRoster, template, budget, isBossWave)
    assert(battleRoster, "WaveDirector:generateWaveList requires a battleRoster")
    assert(budget, "WaveDirector:generateWaveList requires a budget")

    local totalBudget = budget
    local laneCount = 1

    if template then
        if template.getLanesForWave then
            laneCount = template:getLanesForWave(waveIndex)
        elseif template.lanesPerWave then
            laneCount = template.lanesPerWave[waveIndex] or template.lanesPerWave[#template.lanesPerWave] or 1
        end
    end

    local available = {}
    if template and template.waveDangerTiers and template.waveDangerTiers[waveIndex] then
        local allowedTiers = {}
        for key, _ in pairs(template.waveDangerTiers[waveIndex]) do
            local tierName = key:match("^(tier%d+)m[axin]+$")
            if tierName then
                local tierNum = tonumber(tierName:match("tier(%d+)"))
                if tierNum then
                    local offset = (self.game and self.game.testingMode) and 2 or 0
                    allowedTiers[tierNum + offset] = true
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

    if isBossWave then
        local tier5Enemy = nil
        local tier5Candidates = {}
        for _, e in ipairs(EnemyRegistry.allEnemies) do
            if e.tier == 5 then
                table.insert(tier5Candidates, e)
            end
        end
        if #tier5Candidates > 0 then
            tier5Enemy = tier5Candidates[math.random(1, #tier5Candidates)]
        end
        if tier5Enemy then
            addEnemySpawns(tier5Enemy, 1)
        end
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

        local r = math.random() * totalWeight
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

    local laneQueues = {}
    for i = 1, laneCount do
        laneQueues[i] = {}
    end
    for i, enemyClass in ipairs(waveList) do
        local laneIndex = ((i - 1) % laneCount) + 1
        table.insert(laneQueues[laneIndex], enemyClass)
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
    return laneQueues, summary, laneCount
end

function WaveDirector:checkConstraints(enemy, currentCounts)
    -- Placeholder for future min/max constraints per enemy type
    return true
end

return WaveDirector
