local EnemyRegistry = {}

function EnemyRegistry:reset(game)
    local isTesting = game and game.testingMode
    local index = isTesting and require("Game.Spawning.TestingEnemyIndex") or require("Game.Spawning.EnemyIndex")
    
    local Utils = require("Classes.Utils")
    self.allEnemies = Utils.deepCopy(index)

    _G.PersistentState = _G.PersistentState or {}
    _G.PersistentState.activeMutations = _G.PersistentState.activeMutations or {}
    
    -- Ensure discoveredEnemies exists in persistent state as a set
    _G.PersistentState.discoveredEnemies = _G.PersistentState.discoveredEnemies or { ["Grunt"] = true, ["Basic"] = true }
    
    -- Sync local discovered lists
    self.discoveredEnemiesMap = {}
    self.discoveredEnemies = {}
    
    -- Load from persistent state
    for _, enemy in ipairs(self.allEnemies) do
        local baseClass = enemy.class
        if baseClass then
            local subclass = setmetatable({}, { __index = baseClass })
            subclass.__index = subclass
            subclass.baseSpawnDelay = enemy.baseSpawnDelay or 1.0
            subclass.enemyId = enemy.id -- lets saved waves name the class (SaveGame)
            function subclass:new(config)
                config = config or {}
                config.name = enemy.id
                config.enemyId = enemy.id
                local instance = baseClass.new(self, config)
                if instance then
                    instance.name = enemy.id
                    instance.enemyId = enemy.id
                end
                return instance
            end
            enemy.class = subclass
        end
        
        if _G.PersistentState.discoveredEnemies[enemy.id] then
            self.discoveredEnemiesMap[enemy.id] = true
            table.insert(self.discoveredEnemies, enemy.id)
        end
    end
    
    -- Safety: always make sure at least the starter enemy ("Grunt" or "Basic") is discovered if available
    local starterId = isTesting and "Basic" or "Grunt"
    if not self.discoveredEnemiesMap[starterId] then
        for _, enemy in ipairs(self.allEnemies) do
            if enemy.id == starterId then
                self.discoveredEnemiesMap[starterId] = true
                table.insert(self.discoveredEnemies, starterId)
                _G.PersistentState.discoveredEnemies[starterId] = true
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

local ALIAS_MAP = {
    ["Turret Debuffer"] = "Drone",
    ["Spawner"] = "Broodmother",
    ["Portal Master"] = "PortalMaster",
    ["Duplicator"] = "Slime",
}

function EnemyRegistry:canonicalEnemyId(nameOrId)
    if not nameOrId then return nil end
    if ALIAS_MAP[nameOrId] then return ALIAS_MAP[nameOrId] end
    if self.allEnemies then
        for _, e in ipairs(self.allEnemies) do
            if e.id == nameOrId or e.type == nameOrId then
                return e.id
            end
        end
    end
    return nameOrId
end

function EnemyRegistry:discoverEnemy(enemyId)
    local canonicalId = self:canonicalEnemyId(enemyId) or enemyId
    _G.PersistentState = _G.PersistentState or {}
    _G.PersistentState.discoveredEnemies = _G.PersistentState.discoveredEnemies or {}

    local function mark(id)
        if id and not self.discoveredEnemiesMap[id] then
            self.discoveredEnemiesMap[id] = true
            table.insert(self.discoveredEnemies, id)
            _G.PersistentState.discoveredEnemies[id] = true
            print("[EnemyRegistry] Discovered new enemy: " .. id)
        end
        if id then
            _G.PersistentState.discoveredEnemies[id] = true
        end
    end

    mark(canonicalId)
    if enemyId and enemyId ~= canonicalId then
        mark(enemyId)
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

-- Accepts both spawned instances and plain index entries (getAvailableEnemies),
-- so it reads fields directly instead of calling object:isType.
local function isMutationTarget(enemy, target)
    if target == "All" then return true end
    if (enemy.enemyId or enemy.id) == target then return true end
    return enemy.types ~= nil and enemy.types[target:lower()] == true
end

function EnemyRegistry:applyActiveMutations(enemyInstance)
    if not _G.PersistentState or not _G.PersistentState.activeMutations then return end
    for _, upgrade in ipairs(_G.PersistentState.activeMutations) do
        if isMutationTarget(enemyInstance, upgrade.target) then
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
