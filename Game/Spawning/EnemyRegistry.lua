local EnemyRegistry = {
    -- Current pools for mutations
    inactivePool = {
        {
            id = "Speeder",
            type = "Speeder",
            class = require("Enemies.Speeder"),
            spawnCost = 10,
            spawnWeight = 50,
            description = "Fast but fragile. Often spawns in large numbers.",
            mutations = {
                { id = "speeder_speed", name = "Overdrive", description = "Speed +20%", modifiers = { speed = 1.2 }, target = "Speeder" },
                { id = "speeder_hp", name = "Hardened Shell", description = "HP +30%", modifiers = { maxHp = 1.3, hp = 1.3 }, target = "Speeder" },
                { id = "speeder_fly", name = "Anti-Grav Plating", description = "Speeders can now fly over blockers.", modifiers = { isFlying = { set = true } }, target = "Speeder" }
            }
        },
        {
            id = "Tank",
            type = "Tank",
            class = require("Enemies.Tank"),
            spawnCost = 45,
            spawnWeight = 35,
            description = "Slow and heavy. Can soak up massive damage.",
            mutations = {
                { id = "tank_hp", name = "Behemoth Plating", description = "HP +50%", modifiers = { maxHp = 1.5, hp = 1.5 }, target = "Tank" },
                { id = "tank_speed", name = "Turbo Engines", description = "Speed +25%", modifiers = { speed = 1.25 }, target = "Tank" }
            }
        },
        {
            id = "Flyer",
            type = "Flyer",
            class = require("Enemies.Flyer"),
            spawnCost = 25,
            spawnWeight = 40,
            description = "Airborne threat. Flies over blockers and walls.",
            mutations = {
                { id = "flyer_speed", name = "Swift Swarm", description = "Speed +20%", modifiers = { speed = 1.2 }, target = "Flyer" },
                { id = "flyer_hp", name = "Precision Wings", description = "HP +40%", modifiers = { maxHp = 1.4, hp = 1.4 }, target = "Flyer" }
            }
        },
        {
            id = "Carrier",
            type = "Carrier",
            class = require("Enemies.Carrier"),
            spawnCost = 40,
            spawnWeight = 40,
            description = "Swarm mother. Periodically spawns speeders.",
            mutations = {
                { id = "carrier_hp", name = "Reinforced Hull", description = "HP +40%", modifiers = { maxHp = 1.4, hp = 1.4 }, target = "Carrier" },
                { id = "carrier_rate", name = "Rapid Deployment", description = "Spawn Rate +30%", modifiers = { spawnInterval = 0.7 }, target = "Carrier" }
            }
        },
        {
            id = "Armored",
            type = "Armored",
            class = require("Enemies.Armored"),
            spawnCost = 35,
            spawnWeight = 30,
            description = "Heavily resistant to normal damage.",
            mutations = {
                { id = "armored_hp", name = "Dreadnought Plating", description = "HP +40%", modifiers = { maxHp = 1.4, hp = 1.4 }, target = "Armored" },
                { id = "armored_resist", name = "Even Stronger Armor", description = "Normal resistance +10%", modifiers = { normal = 0.9 }, target = "Armored" }
            }
        }
    },
    
    activePool = {
        {
            id = "Basic",
            type = "Basic",
            class = require("Enemies.Enemy"),
            spawnCost = 10,
            spawnWeight = 80,
            description = "The backbone of the invasion. Average speed and health.",
            mutations = {
                { id = "basic_hp", name = "Veteran Training", description = "HP +25%", modifiers = { maxHp = 1.25, hp = 1.25 }, target = "Basic" },
                { id = "basic_speed", name = "Adrenaline", description = "Speed +15%", modifiers = { speed = 1.15 }, target = "Basic" },
                { id = "basic_Explosive_armour", name = "Blast Shields", description = "Take 30% less explosive damage.", modifiers = { explosive = 0.7 }, target = "Basic" }
            }
        },
    },

    availableUpgrades = {}, -- Upgrades waiting to be picked
    activeUpgrades = {}     -- Picked upgrades currently in effect
}

-- Initialize starting enemy upgrades into available pool
for _, enemy in ipairs(EnemyRegistry.activePool) do
    if enemy.mutations then
        for _, mut in ipairs(enemy.mutations) do
            table.insert(EnemyRegistry.availableUpgrades, mut)
        end
    end
end

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
                    local val = isSet and modifier.set or modifier
                    
                    if enemyInstance[stat] ~= nil then
                        if isSet then
                            enemyInstance[stat] = val
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
