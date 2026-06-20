local EnemyIndex = {
    {
        id = "Grunt",
        type = "Grunt",
        class = require("Enemies.Enemy"),
        tier = 0,
        spawnCost = 10,
        spawnWeight = 1,
        maxHp = 100,
        damage = 10,
        speed = 25,
        color = {1, 0, 0, 1}, -- Red
        shape = "rectangle",
        size = 20,
        types = { enemy = true, red = true },
        baseSpawnDelay = 1,
        description = "Nothing special about this guy...",
        mutations = {}
    },
    {
        id = "Scout",
        type = "Scout",
        class = require("Enemies.Enemy"),
        tier = 0,
        spawnCost = 10,
        spawnWeight = 1,
        maxHp = 20,
        damage = 10,
        speed = 80,
        color = {1, 1, 0, 1}, -- Yellow
        shape = "rectangle",
        size = 15,
        types = { enemy = true, yellow = true },
        baseSpawnDelay = 0.5,
        description = "Fast, but fragile.",
        mutations = {}
    },
    {
        id = "Critter",
        type = "Critter",
        class = require("Enemies.Enemy"),
        tier = 0,
        spawnCost = 3,
        spawnWeight = 4,
        maxHp = 25,
        damage = 5,
        speed = 30,
        color = {0, 1, 0, 1}, -- Green
        shape = "rectangle",
        size = 12,
        types = { enemy = true, green = true },
        baseSpawnDelay = 0.2,
        description = "You'll never find just one",
        mutations = {}
    },
    {
        id = "Drone",
        type = "Drone",
        class = require("Enemies.TurretDebuffer"),
        tier = 0,
        spawnCost = 15,
        spawnWeight = 0.7,
        maxHp = 150,
        damage = 10,
        speed = 23,
        color = {0, 1, 1, 1}, -- Cyan/Blue
        shape = "rectangle",
        size = 20,
        types = { enemy = true, blue = true },
        baseSpawnDelay = 1.0,
        numTargets = 1,
        debuffStacks = 999,
        debuffDuration = nil,
        debuffFrequency = 3.0,
        stickyTargets = true,
        debuffStat = "fireRate",
        debuffAmount = -0.01,
        description = "Reduces turret efficiency with debuffs.",
        mutations = {}
    },
    {
        id = "Soldier",
        type = "Soldier",
        class = require("Enemies.Enemy"),
        tier = 1,
        spawnCost = 15,
        spawnWeight = 0.8,
        maxHp = 150,
        damage = 12,
        speed = 22,
        color = {1, 0, 0, 1}, -- Red
        shape = "rectangle",
        size = 22,
        types = { enemy = true, red = true, armour = true },
        baseSpawnDelay = 1.0,
        affinities = {
            normal = 0.75,
            explosive = 0.75
        },
        description = "A trained combatant with light armour.",
        mutations = {}
    },
    {
        id = "Broodmother",
        type = "Broodmother",
        class = require("Enemies.Spawner"),
        tier = 1,
        spawnCost = 25,
        spawnWeight = 0.5,
        maxHp = 300,
        damage = 15,
        speed = 18,
        color = {0, 1, 0, 1}, -- Green
        shape = "hexagon",
        size = 24,
        types = { enemy = true, green = true, spawner = true },
        baseSpawnDelay = 1.5,
        spawnAmount = 4,
        spawnFrequency = 5,
        spawnReference = "Critter",
        description = "Hatches Critters.",
        mutations = {}
    }
}

return EnemyIndex
