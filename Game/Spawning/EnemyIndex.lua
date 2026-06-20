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
        description = "Sturdy and expendable.",
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
        description = "Fast and light.",
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
        description = "Tends to move in groups.",
        mutations = {}
    },
    {
        id = "Drone",
        type = "Drone",
        class = require("Enemies.TurretDebuffer"),
        tier = 0,
        spawnCost = 15,
        spawnWeight = 0.7,
        maxHp = 120,
        damage = 10,
        speed = 23,
        color = {0, 1, 1, 1}, -- Cyan
        shape = "rectangle",
        size = 20,
        types = { enemy = true, cyan = true },
        baseSpawnDelay = 1.0,
        numTargets = 1,
        debuffStacks = 999,
        debuffDuration = nil,
        debuffFrequency = 3.0,
        stickyTargets = true,
        debuffStat = "fireRate",
        debuffAmount = -0.01,
        description = "Gives debuffs that get stronger the longer it lives.",
        mutations = {}
    }
}

return EnemyIndex
