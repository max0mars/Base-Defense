local WaveDirector = require("Game.Spawning.WaveDirector")
local BattleTemplate = require("Game.Spawning.BattleTemplate")

local BattleDirector = {}
BattleDirector.__index = BattleDirector

BattleDirector.MAX_LANES = 3

BattleDirector.LEVEL_BRACKETS = {
    { minLevel = 1,  maxLevel = 1,   numWaves = 3, lanesPerWave = {1, 1, 2} },
    { minLevel = 2,  maxLevel = 4,   numWaves = 3, lanesPerWave = {1, 2, 2} },
    { minLevel = 5,  maxLevel = 8,   numWaves = 4, lanesPerWave = {1, 2, 2, 3} },
    { minLevel = 9,  maxLevel = 13,  numWaves = 5, lanesPerWave = {2, 2, 3, 3, 4} },
    { minLevel = 14, maxLevel = 17,  numWaves = 6, lanesPerWave = {2, 2, 3, 3, 4, 4} },
    { minLevel = 18, maxLevel = 19,  numWaves = 7, lanesPerWave = {2, 3, 3, 4, 4, 5, 5} },
    { minLevel = 20, maxLevel = 999, numWaves = 8, lanesPerWave = {3, 3, 4, 4, 5, 5, 5, 6} },
}

function BattleDirector:getCurrentLevel()
    if _G.PersistentState and _G.PersistentState.battlesCompleted then
        return _G.PersistentState.battlesCompleted + 1
    end
    return 1
end

function BattleDirector:getBracketForLevel(level)
    local lvl = level or self:getCurrentLevel()
    for _, bracket in ipairs(self.LEVEL_BRACKETS) do
        if lvl >= bracket.minLevel and lvl <= bracket.maxLevel then
            return bracket
        end
    end
    return self.LEVEL_BRACKETS[#self.LEVEL_BRACKETS]
end

function BattleDirector:getNumWavesForLevel(level)
    local bracket = self:getBracketForLevel(level)
    return bracket and bracket.numWaves or 5
end

BattleDirector.getNumWaves = BattleDirector.getNumWavesForLevel

function BattleDirector:getLanesForWave(level, waveIndex, maxLanes)
    local bracket = self:getBracketForLevel(level)
    local cap = (maxLanes == nil) and self.MAX_LANES or maxLanes
    if bracket and bracket.lanesPerWave then
        local lanes = bracket.lanesPerWave[waveIndex] or bracket.lanesPerWave[#bracket.lanesPerWave] or 1
        if cap then
            lanes = math.min(cap, lanes)
        end
        return lanes
    end
    return 1
end

function BattleDirector:new(game)
    local obj = setmetatable({}, self)
    obj.game = game
    
    local EnemyRegistry = require("Game.Spawning.EnemyRegistry")
    EnemyRegistry:reset(game)
    obj.discoveredEnemies = EnemyRegistry.discoveredEnemies
    return obj
end

-- Spawn budget grows linearly with the player's level: +10% per level above 1.
BattleDirector.BUDGET_GROWTH_PER_LEVEL = 0.10

function BattleDirector:getLevelBudgetMultiplier(level)
    return 1 + self.BUDGET_GROWTH_PER_LEVEL * (math.max(1, level or 1) - 1)
end

function BattleDirector:getBudgetForWave(template, waveNumber, level)
    local baseBudgets = template and template.budgets or require("Game.Spawning.BattleIndex").DEFAULT_BUDGETS
    local wave = math.max(1, math.min(#baseBudgets, waveNumber))
    local base = baseBudgets[wave]
    return math.floor(base * self:getLevelBudgetMultiplier(level or self:getCurrentLevel()))
end

-- @param difficultyMultiplier number: the chosen battle's difficulty (1.0-2.0), applied once on top of level scaling
-- @param profile table: optional { template, roster, level, difficultyMultiplier }
function BattleDirector:generateBattle(difficultyMultiplier, profile)
    local wd = WaveDirector:new(self.game)
    
    if profile then
        print("maxDistinctEnemyTypes from profile: " .. tostring(profile.maxDistinctEnemyTypes))
    else
        print("maxDistinctEnemyTypes from profile: nil")
    end
    
    -- Select template based on passed profile/template or current battle number in state
    local battleNum = (profile and profile.level) or self:getCurrentLevel()
    local template = (profile and profile.template) or self:selectTemplate(battleNum)
    if template then
        self:updateDiscoveryPool(template)
    end
    local roster = (profile and profile.roster) or self:buildBattleRoster(template)

    local upcomingWaves = {}
    local upcomingSummaries = {}
    local forecastTotals = {}
    local numWaves = (template and template.numWaves) or self:getNumWavesForLevel(battleNum)
    for i = 1, numWaves do
        -- Calculate budget, scaled by player level and battle choice difficulty multiplier
        local budget = self:getBudgetForWave(template, i, battleNum)
        local diffMult = (profile and profile.difficultyMultiplier) or difficultyMultiplier or 1
        if diffMult ~= 1 then
            budget = math.floor(budget * diffMult)
        end
        if template and template.relativeDifficulty and template.relativeDifficulty[i] then
            budget = math.floor(budget * template.relativeDifficulty[i])
        end

        local isBossWave = (battleNum == 20 and i == numWaves)
        local laneCount = (template and template.getLanesForWave and template:getLanesForWave(i)) or self:getLanesForWave(battleNum, i)
        local list, summary, lanes = wd:generateWaveList(i, roster, template, budget, isBossWave, laneCount)
        table.insert(upcomingWaves, list)
        table.insert(upcomingSummaries, summary)
        
        for _, s in ipairs(summary) do
            forecastTotals[s.type] = (forecastTotals[s.type] or 0) + s.count
        end
    end
    
    return upcomingWaves, upcomingSummaries, forecastTotals
end

function BattleDirector:selectTemplate(currentBattleNumber)
    local templates = require("Game.Spawning.BattleIndex")
    local validTemplates = {}
    local totalWeight = 0

    for key, template in pairs(templates) do
        if type(template) == "table" and type(template.isValidForBattle) == "function" and template:isValidForBattle(currentBattleNumber) then
            table.insert(validTemplates, template)
            totalWeight = totalWeight + (template.weight or 10)
        end
    end

    if #validTemplates == 0 then
        local bestTemplate = nil
        local maxRange = -1
        for key, template in pairs(templates) do
            local maxLvl = template.maximumLevel or (template.validBattleRange and template.validBattleRange.max)
            if type(template) == "table" and maxLvl and (not template.limit or template.count < template.limit) and maxLvl > maxRange then
                maxRange = maxLvl
                bestTemplate = template
            end
        end
        if bestTemplate then
            table.insert(validTemplates, bestTemplate)
            totalWeight = bestTemplate.weight or 10
        else
            return nil
        end
    end

    local roll = math.random(1, totalWeight)
    local currentSum = 0
    local selectedTemplate = nil

    for _, template in ipairs(validTemplates) do
        currentSum = currentSum + (template.weight or 10)
        if roll <= currentSum then
            selectedTemplate = template
            break
        end
    end

    if selectedTemplate then
        print("Selected Template ID: " .. selectedTemplate.id)
        selectedTemplate.count = selectedTemplate.count + 1
    end

    return selectedTemplate
end

function BattleDirector:updateDiscoveryPool(selectedTemplate)
    if not selectedTemplate or not selectedTemplate.battleDangerTiers then return end

    local EnemyRegistry = require("Game.Spawning.EnemyRegistry")

    local function getTier(tierName)
        local tierNum = tonumber(tierName:match("tier(%d+)"))
        if not tierNum then return nil end
        local offset = (self.game and self.game.testingMode) and 2 or 0
        return tierNum + offset
    end

    for key, reqMin in pairs(selectedTemplate.battleDangerTiers) do
        local tierName = key:match("^(tier%d+)min$")
        if tierName then
            local targetDanger = getTier(tierName)
            if targetDanger then
                -- Count how many currently discovered enemies match this tier AND allowedTypes
                local currentMatchingCount = 0
                for _, enemyId in ipairs(self.discoveredEnemies) do
                    local enemyData = nil
                    for _, e in ipairs(EnemyRegistry.allEnemies) do
                        if e.id == enemyId then enemyData = e break end
                    end
                    if enemyData and enemyData.tier == targetDanger and self:matchesAllowedTypes(selectedTemplate, enemyData) then
                        currentMatchingCount = currentMatchingCount + 1
                    end
                end

                if currentMatchingCount < reqMin then
                    local needed = reqMin - currentMatchingCount
                    while needed > 0 do
                        local candidates = {}
                        for _, e in ipairs(EnemyRegistry.allEnemies) do
                            if e.tier == targetDanger and not EnemyRegistry.discoveredEnemiesMap[e.id] and self:matchesAllowedTypes(selectedTemplate, e) then
                                table.insert(candidates, e)
                            end
                        end

                        if #candidates == 0 then
                            -- Fallback: if all matching enemies are already discovered, or none match, check all candidates for this tier
                            for _, e in ipairs(EnemyRegistry.allEnemies) do
                                if e.tier == targetDanger and not EnemyRegistry.discoveredEnemiesMap[e.id] then
                                    table.insert(candidates, e)
                                end
                            end
                        end

                        if #candidates == 0 then
                            break
                        end

                        needed = needed - 1
                    end
                end
            end
        end
    end
end

function BattleDirector:forceDiscoverEnemy(enemyId)
    local EnemyRegistry = require("Game.Spawning.EnemyRegistry")
    EnemyRegistry:discoverEnemy(enemyId)
end

function BattleDirector:matchesAllowedTypes(selectedTemplate, enemy)
    if not selectedTemplate or not selectedTemplate.allowedTypes or #selectedTemplate.allowedTypes == 0 then
        return true
    end
    local classTypes = enemy.class and enemy.class.types
    for _, t in ipairs(selectedTemplate.allowedTypes) do
        local lowerT = t:lower()
        if classTypes and classTypes[lowerT] then
            return true
        end
        if enemy.type and enemy.type:lower() == lowerT then
            return true
        end
        if enemy.id and enemy.id:lower() == lowerT then
            return true
        end
    end
    return false
end

function BattleDirector:buildBattleRoster(selectedTemplate)
    local EnemyRegistry = require("Game.Spawning.EnemyRegistry")
    local battleRoster = {}
    local addedIds = {}

    local function addUnique(enemy)
        if enemy and not addedIds[enemy.id] then
            table.insert(battleRoster, enemy)
            addedIds[enemy.id] = true
        end
    end

    local function getTier(tierName)
        local tierNum = tonumber(tierName:match("tier(%d+)"))
        if not tierNum then return nil end
        local offset = (self.game and self.game.testingMode) and 2 or 0
        return tierNum + offset
    end

    if selectedTemplate and selectedTemplate.battleDangerTiers then
        local tiers = {}
        for key, val in pairs(selectedTemplate.battleDangerTiers) do
            local tierName = key:match("^(tier%d+)m[axin]+$")
            if tierName then
                tiers[tierName] = tiers[tierName] or {}
                if key:find("min$") then
                    tiers[tierName].min = val
                elseif key:find("max$") then
                    tiers[tierName].max = val
                end
            end
        end

        for tierName, limits in pairs(tiers) do
            local targetDanger = getTier(tierName)
            if targetDanger then
                local minLimit = limits.min or 0
                local maxLimit = limits.max or minLimit
                local selectCount = math.random(minLimit, maxLimit)

                local candidates = {}
                for _, enemyId in ipairs(self.discoveredEnemies) do
                    local enemyData = nil
                    for _, e in ipairs(EnemyRegistry.allEnemies) do
                        if e.id == enemyId then
                            enemyData = e
                            break
                        end
                    end

                    if enemyData and enemyData.tier == targetDanger and self:matchesAllowedTypes(selectedTemplate, enemyData) then
                        table.insert(candidates, enemyData)
                    end
                end

                -- If discovered candidates are fewer than selectCount, pull additional candidates from allEnemies
                if #candidates < selectCount then
                    local existingCandidateIds = {}
                    for _, c in ipairs(candidates) do
                        existingCandidateIds[c.id] = true
                    end
                    for _, e in ipairs(EnemyRegistry.allEnemies) do
                        if not existingCandidateIds[e.id] and e.tier == targetDanger and self:matchesAllowedTypes(selectedTemplate, e) then
                            table.insert(candidates, e)
                            existingCandidateIds[e.id] = true
                        end
                    end
                end

                -- Secondary fallback: if still empty, pick any enemy of targetDanger
                if #candidates == 0 then
                    for _, e in ipairs(EnemyRegistry.allEnemies) do
                        if e.tier == targetDanger then
                            table.insert(candidates, e)
                        end
                    end
                end

                local pickedCount = 0
                while pickedCount < selectCount and #candidates > 0 do
                    local r = math.random(1, #candidates)
                    local picked = table.remove(candidates, r)
                    addUnique(picked)
                    pickedCount = pickedCount + 1
                end
            end
        end
    end

    if selectedTemplate and selectedTemplate.specificEnemies then
        for _, enemyId in ipairs(selectedTemplate.specificEnemies) do
            local enemyData = nil
            for _, e in ipairs(EnemyRegistry.allEnemies) do
                if e.id == enemyId then
                    enemyData = e
                    break
                end
            end
            if enemyData then
                addUnique(enemyData)
            end
        end
    end

    -- Filler tiers: familiar low-tier fodder (discovered only); WaveDirector caps their budget share
    if selectedTemplate and selectedTemplate.fillerTiers then
        local offset = (self.game and self.game.testingMode) and 2 or 0
        for tier, limits in pairs(BattleTemplate.parseTierLimits(selectedTemplate.fillerTiers, offset)) do
            local candidates = {}
            for _, e in ipairs(EnemyRegistry.allEnemies) do
                if e.tier == tier and EnemyRegistry.discoveredEnemiesMap[e.id] and not addedIds[e.id] then
                    table.insert(candidates, e)
                end
            end
            local selectCount = math.random(limits.min, limits.max)
            for _ = 1, math.min(selectCount, #candidates) do
                addUnique(table.remove(candidates, math.random(1, #candidates)))
            end
        end
    end

    -- Absolute safety net: If roster is somehow still empty, add default Tier 0 (Grunt)
    if #battleRoster == 0 then
        for _, e in ipairs(EnemyRegistry.allEnemies) do
            if e.id == "Grunt" or e.tier == 0 then
                addUnique(e)
                break
            end
        end
    end

    return battleRoster
end

return BattleDirector
