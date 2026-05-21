local TestingEnemyIndex = {
    inactivePool = {},
    activePool = {
        {
            id = "Basic",
            type = "Basic",
            class = require("Enemies.Enemy"),
            spawnCost = 10,
            spawnWeight = 60,
            description = "The backbone of the invasion. Average speed and health.",
            mutations = {
                { id = "basic_hp", name = "Veteran Training", description = "HP +25%", modifiers = { maxHp = 1.25, hp = 1.25 }, target = "Basic" },
                { id = "basic_speed", name = "Adrenaline", description = "Speed +15%", modifiers = { speed = 1.15 }, target = "Basic" },
                { id = "basic_Explosive_armour", name = "Blast Shields", description = "Take 30% less explosive damage.", modifiers = { explosive = 0.7 }, target = "Basic" },
                { id = "basic_mitosis", name = "Mitosis", description = "10% chance to split into 2 Basic enemies on death.", modifiers = { splitOnDeathChance = { set = 0.1 } }, target = "Basic" }
            }
        },
        {
            id = "Duplicator",
            type = "Duplicator",
            class = require("Enemies.Duplicator"),
            spawnCost = 20,
            spawnWeight = 40,
            description = "A cellular mass that divides upon death. Multiplies quickly if unchecked.",
            mutations = {
                { id = "duplicator_burst", name = "Symbiotic Burst", description = "On duplication, releases a healing wave affecting all enemies.", modifiers = { healWaveOnSplit = { set = true } }, target = "Duplicator" },
                { id = "duplicator_speed", name = "Accelerated Mitosis", description = "Each duplication stage has increased movement speed.", modifiers = { acceleratedMitosis = { set = true } }, target = "Duplicator" },
                { id = "duplicator_hyper", name = "Hyper-Replication", description = "The last duplication stage spawns 1 extra clone.", modifiers = { extraFinalClone = { set = true } }, target = "Duplicator" }
            }
        }
    }
}

return TestingEnemyIndex
