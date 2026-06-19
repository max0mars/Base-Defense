local EnemyRegistry = {}

function EnemyRegistry:reset(game)
    local isTesting = game and game.testingMode
    local index = isTesting and require("Game.Spawning.TestingEnemyIndex") or require("Game.Spawning.EnemyIndex")
    
    local Utils = require("Classes.Utils")
    self.allEnemies = Utils.deepCopy(index)

    _G.PersistentState = _G.PersistentState or {}
    _G.PersistentState.activeMutations = _G.PersistentState.activeMutations or {}
    
    -- Ensure discoveredEnemies exists in persistent state as a set
    _G.PersistentState.discoveredEnemies = _G.PersistentState.discoveredEnemies or { ["Basic"] = true }
    
    -- Sync local discovered lists
    self.discoveredEnemiesMap = {}
    self.discoveredEnemies = {}
    
    -- Load from persistent state
    for _, enemy in ipairs(self.allEnemies) do
        if _G.PersistentState.discoveredEnemies[enemy.id] then
            self.discoveredEnemiesMap[enemy.id] = true
            table.insert(self.discoveredEnemies, enemy.id)
        end
    end
    
    -- Safety: always make sure at least "Basic" is discovered if it exists
    if not self.discoveredEnemiesMap["Basic"] then
        for _, enemy in ipairs(self.allEnemies) do
            if enemy.id == "Basic" then
                self.discoveredEnemiesMap["Basic"] = true
                table.insert(self.discoveredEnemies, "Basic")
                _G.PersistentState.discoveredEnemies["Basic"] = true
                break
            end
        end
    end
end

function EnemyRegistry:getAvailableEnemies()
    local Utils = require("Classes.Utils")
    local active = {}
    for _, enemy in ipairs(self.allEnemies) do
        if self.discoveredEnemiesMap[enemy.id] then
            local copy = Utils.deepCopy(enemy)
            self:applyActiveMutations(copy)
            table.insert(active, copy)
        end
    end
    return active
end

function EnemyRegistry:discoverEnemy(enemyId)
    if not self.discoveredEnemiesMap[enemyId] then
        self.discoveredEnemiesMap[enemyId] = true
        table.insert(self.discoveredEnemies, enemyId)
        _G.PersistentState.discoveredEnemies[enemyId] = true
        print("[EnemyRegistry] Discovered new enemy: " .. enemyId)
    end
end

function EnemyRegistry:updatePools(globalDifficulty)
    local candidates = {}
    for _, enemy in ipairs(self.allEnemies) do
        if not self.discoveredEnemiesMap[enemy.id] then
            if enemy.tier and enemy.tier <= globalDifficulty then
                table.insert(candidates, enemy)
            end
        end
    end

    if #candidates > 0 then
        local r = math.random(1, #candidates)
        local selected = candidates[r]
        self:discoverEnemy(selected.id)
    end
end

function EnemyRegistry:triggerRandomMutation()
    local activePool = self:getAvailableEnemies()
    if #activePool == 0 then return end
    local r = math.random(1, #activePool)
    local enemy = activePool[r]
    if enemy.mutations and #enemy.mutations > 0 then
        local mr = math.random(1, #enemy.mutations)
        local mutation = enemy.mutations[mr]
        
        _G.PersistentState.activeMutations = _G.PersistentState.activeMutations or {}
        table.insert(_G.PersistentState.activeMutations, mutation)
        print("[EnemyRegistry] Mutation Triggered: " .. mutation.name .. " on " .. enemy.id)
    end
end

function EnemyRegistry:applyActiveMutations(enemyInstance)
    if not _G.PersistentState or not _G.PersistentState.activeMutations then return end
    for _, upgrade in ipairs(_G.PersistentState.activeMutations) do
        if enemyInstance:isType(upgrade.target:lower()) or upgrade.target == "All" then
            if upgrade.modifiers then
                for stat, modifier in pairs(upgrade.modifiers) do
                    local isSet = type(modifier) == "table" and modifier.set ~= nil
                    local isAdd = type(modifier) == "table" and modifier.add ~= nil
                    local val = (isSet and modifier.set) or (isAdd and modifier.add) or modifier
                    
                    if enemyInstance[stat] ~= nil then
                        if isSet then
                            enemyInstance[stat] = val
                        elseif isAdd then
                            enemyInstance[stat] = enemyInstance[stat] + val
                        else
                            enemyInstance[stat] = enemyInstance[stat] * val
                        end
                    elseif enemyInstance.affinities then
                        enemyInstance.affinities[stat] = (enemyInstance.affinities[stat] or 1) * val
                    end
                end
            end
        end
    end
end

-- Initialize self
EnemyRegistry:reset()

return EnemyRegistry
