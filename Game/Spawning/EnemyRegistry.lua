local EnemyRegistry = {}

function EnemyRegistry:reset(game)
    local isTesting = game and game.testingMode
    local index = isTesting and require("Game.Spawning.TestingEnemyIndex") or require("Game.Spawning.NormalEnemyIndex")
    
    local Utils = require("Classes.Utils")
    self.inactivePool = Utils.deepCopy(index.inactivePool)
    self.activePool = Utils.deepCopy(index.activePool)

    self.availableUpgrades = {} -- Upgrades waiting to be picked
    self.activeUpgrades = {}     -- Picked upgrades currently in effect

    -- Initialize starting enemy upgrades into available pool
    for _, enemy in ipairs(self.activePool) do
        if enemy.mutations then
            for _, mut in ipairs(enemy.mutations) do
                table.insert(self.availableUpgrades, mut)
            end
        end
    end
end

EnemyRegistry:reset()

function EnemyRegistry:getAvailableEnemies()
    return self.activePool
end

function EnemyRegistry:getMutationOptions(count)
    local options = {}
    local poolCopy = {}
    for i, v in ipairs(self.inactivePool) do table.insert(poolCopy, {idx = i, data = v, type = "enemy"}) end
    
    for i = 1, math.min(count, #poolCopy) do
        local r = math.random(1, #poolCopy)
        table.insert(options, table.remove(poolCopy, r))
    end
    return options
end

function EnemyRegistry:getUpgradeOptions(count)
    local options = {}
    local poolCopy = {}
    for i, v in ipairs(self.availableUpgrades) do table.insert(poolCopy, {idx = i, data = v, type = "upgrade"}) end
    
    for i = 1, math.min(count, #poolCopy) do
        local r = math.random(1, #poolCopy)
        table.insert(options, table.remove(poolCopy, r))
    end
    return options
end

function EnemyRegistry:activateMutation(option)
    if option.type == "enemy" then
        -- option.idx is index in current inactivePool
        local enemyData = table.remove(self.inactivePool, option.idx)
        table.insert(self.activePool, enemyData)
        
        -- Add this enemy's specific mutations to the available pool
        if enemyData.mutations then
            for _, mut in ipairs(enemyData.mutations) do
                table.insert(self.availableUpgrades, mut)
            end
        end
    elseif option.type == "upgrade" then
        -- option.idx is index in availableUpgrades
        local upgrade = table.remove(self.availableUpgrades, option.idx)
        table.insert(self.activeUpgrades, upgrade)
    end
end

function EnemyRegistry:applyActiveMutations(enemyInstance)
    for _, upgrade in ipairs(self.activeUpgrades) do
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
                    elseif enemyInstance.affinities and enemyInstance.affinities[stat] then
                        enemyInstance.affinities[stat] = enemyInstance.affinities[stat] * val
                    end
                end
            end
        end
    end
end

return EnemyRegistry
