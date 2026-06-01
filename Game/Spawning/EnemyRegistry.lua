local EnemyRegistry = {}

function EnemyRegistry:reset(game)
    local isTesting = game and game.testingMode
    local index = isTesting and require("Game.Spawning.TestingEnemyIndex") or require("Game.Spawning.NormalEnemyIndex")
    
    local Utils = require("Classes.Utils")
    self.inactivePool = Utils.deepCopy(index.inactivePool)
    self.activePool = Utils.deepCopy(index.activePool)

    _G.PersistentState = _G.PersistentState or {}
    _G.PersistentState.activeMutations = _G.PersistentState.activeMutations or {}
    _G.PersistentState.discoveredEnemies = _G.PersistentState.discoveredEnemies or { ["Basic"] = true }

    -- Move any previously discovered enemies from inactive to active pool
    for i = #self.inactivePool, 1, -1 do
        local enemy = self.inactivePool[i]
        if _G.PersistentState.discoveredEnemies[enemy.id] then
            table.insert(self.activePool, table.remove(self.inactivePool, i))
        end
    end
end

EnemyRegistry:reset()

function EnemyRegistry:getAvailableEnemies()
    return self.activePool
end

function EnemyRegistry:updatePools(globalDifficulty)
    local candidates = {}
    for i, enemy in ipairs(self.inactivePool) do
        if enemy.dangerLevel and enemy.dangerLevel <= globalDifficulty then
            table.insert(candidates, {index = i, enemy = enemy})
        end
    end

    -- Discover exactly one new enemy if candidates exist
    if #candidates > 0 then
        local r = math.random(1, #candidates)
        local selected = candidates[r]
        _G.PersistentState.discoveredEnemies[selected.enemy.id] = true
        table.insert(self.activePool, table.remove(self.inactivePool, selected.index))
        print("[EnemyRegistry] Discovered new enemy: " .. selected.enemy.id)
    end
end

function EnemyRegistry:triggerRandomMutation()
    if #self.activePool == 0 then return end
    local r = math.random(1, #self.activePool)
    local enemy = self.activePool[r]
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

return EnemyRegistry
