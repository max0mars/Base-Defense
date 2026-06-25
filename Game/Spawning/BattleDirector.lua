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
    
    local EnemyRegistry = require("Game.Spawning.EnemyRegistry")
    EnemyRegistry:reset(game)
    obj.discoveredEnemies = EnemyRegistry.discoveredEnemies
    return obj
end

function BattleDirector:getBudgetForWave(template, waveNumber, globalDifficulty)
    local baseBudgets = template and template.budgets or require("Game.Spawning.BattleTemplateDictionary").DEFAULT_BUDGETS
    local wave = math.max(1, math.min(#baseBudgets, waveNumber))
    local base = baseBudgets[wave]
    local multiplier = 1.25 ^ (globalDifficulty - 1)
    return math.floor(base * multiplier)
end

function BattleDirector:generateBattle(globalDifficulty, profile)
    local wd = WaveDirector:new(self.game)
    
    if profile then
        print("maxDistinctEnemyTypes from profile: " .. tostring(profile.maxDistinctEnemyTypes))
    else
        print("maxDistinctEnemyTypes from profile: nil")
    end
    
    -- Select template based on current battle number in state
    local battleNum = _G.PersistentState and _G.PersistentState.battlesCompleted and (_G.PersistentState.battlesCompleted + 1) or 1
    local template = self:selectTemplate(battleNum)
    if template then
        self:updateDiscoveryPool(template)
    end
    local roster = self:buildBattleRoster(template)

    local upcomingWaves = {}
    local upcomingSummaries = {}
    local forecastTotals = {}
    
    local numWaves = template and template.numWaves or 5
    for i = 1, numWaves do
        -- Calculate budget
        local budget = self:getBudgetForWave(template, i, globalDifficulty or 1)
        if template and template.relativeDifficulty and template.relativeDifficulty[i] then
            budget = math.floor(budget * template.relativeDifficulty[i])
        end

        local list, summary, lanes = wd:generateWaveList(i, roster, template, budget)
        table.insert(upcomingWaves, list)
        table.insert(upcomingSummaries, summary)
        
        for _, s in ipairs(summary) do
            forecastTotals[s.type] = (forecastTotals[s.type] or 0) + s.count
        end
    end
    
    return upcomingWaves, upcomingSummaries, forecastTotals
end

function BattleDirector:selectTemplate(currentBattleNumber)
    local templates = require("Game.Spawning.BattleTemplateDictionary")
    local validTemplates = {}
    local totalWeight = 0

    for key, template in pairs(templates) do
        if type(template) == "table" and type(template.isValidForBattle) == "function" and template:isValidForBattle(currentBattleNumber) then
            table.insert(validTemplates, template)
            totalWeight = totalWeight + (template.weight or 10)
        end
    end

    if #validTemplates == 0 then
        return nil
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
                local currentCount = 0
                for _, enemyId in ipairs(self.discoveredEnemies) do
                    local enemyData = nil
                    for _, e in ipairs(EnemyRegistry.allEnemies) do
                        if e.id == enemyId then enemyData = e break end
                    end
                    if enemyData and enemyData.tier == targetDanger then
                        currentCount = currentCount + 1
                    end
                end

                if currentCount < reqMin then
                    local needed = reqMin - currentCount
                    while needed > 0 do
                        local candidates = {}
                        for _, e in ipairs(EnemyRegistry.allEnemies) do
                            if e.tier == targetDanger and not EnemyRegistry.discoveredEnemiesMap[e.id] then
                                table.insert(candidates, e)
                            end
                        end

                        if #candidates == 0 then
                            break
                        end

                        local r = math.random(1, #candidates)
                        local chosen = candidates[r]

                        EnemyRegistry:discoverEnemy(chosen.id)
                        print("Newly Discovered Enemy ID: " .. chosen.id)

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

    local function matchesAllowedTypes(enemy)
        if not selectedTemplate.allowedTypes or #selectedTemplate.allowedTypes == 0 then
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

    if selectedTemplate.battleDangerTiers then
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

                    if enemyData and enemyData.tier == targetDanger and matchesAllowedTypes(enemyData) then
                        table.insert(candidates, enemyData)
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

    if selectedTemplate.specificEnemies then
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

    return battleRoster
end

return BattleDirector
