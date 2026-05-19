local TestingEnemyIndex = {
    inactivePool = {},
    activePool = {
        {
            id = "Tank",
            type = "Tank",
            class = require("Enemies.Tank"),
            spawnCost = 45,
            spawnWeight = 30,
            description = "Slow and heavy. Can soak up massive damage.",
            mutations = {
                { id = "tank_hp", name = "Behemoth Plating", description = "HP +50%", modifiers = { maxHp = 1.5, hp = 1.5 }, target = "Tank" },
                { id = "tank_speed", name = "Turbo Engines", description = "Speed +25%", modifiers = { speed = 1.25 }, target = "Tank" }
            }
        }
    }
}

return TestingEnemyIndex
