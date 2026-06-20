local TestingEnemyIndex = {
    {
        id = "Basic",
        type = "Basic",
        class = require("Enemies.Enemy"),
        tier = 1,
        spawnCost = 10,
        spawnWeight = 60,
        maxHp = 100,
        damage = 10,
        speed = 25,
        color = {1, 0, 0, 1},
        shape = "rectangle",
        size = 20,
        types = { enemy = true, basic = true },
        baseSpawnDelay = 1.0,
        description = "The backbone of the invasion. Average speed and health.",
        mutations = {
            { id = "basic_hp", name = "Veteran Training", description = "HP +25%", modifiers = { maxHp = 1.25, hp = 1.25 }, target = "Basic" },
            { id = "basic_speed", name = "Adrenaline", description = "Speed +15%", modifiers = { speed = 1.15 }, target = "Basic" },
            { id = "basic_Explosive_armour", name = "Blast Shields", description = "Take 30% less explosive damage.", modifiers = { explosive = 0.7 }, target = "Basic" },
            { id = "basic_mitosis", name = "Mitosis", description = "10% chance to split into 2 Basic enemies on death.", modifiers = { splitOnDeathChance = { set = 0.1 } }, target = "Basic" }
        }
    },
    {
        id = "Speeder",
        type = "Speeder",
        class = require("Enemies.SpeederGroup"),
        tier = 2,
        spawnCost = 25,
        spawnWeight = 45,
        maxHp = 25,
        damage = 10,
        speed = 110,
        color = {0.8, 1, 0, 1},
        shape = "dart",
        size = 15,
        isFlying = false,
        types = { enemy = true, speeder = true },
        baseSpawnDelay = 0.4,
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
        class = require("Enemies.Enemy"), -- CHANGED
        tier = 3,
        spawnCost = 55,
        spawnWeight = 25,
        maxHp = 1000,
        damage = 30,
        speed = 15,
        color = {1, 1, 0, 1},
        shape = "tank",
        size = 30,
        types = { enemy = true, tank = true },
        baseSpawnDelay = 2.5,
        description = "Slow and heavy. Can soak up massive damage.",
        mutations = {
            { id = "tank_hp", name = "Behemoth Plating", description = "HP +50%", modifiers = { maxHp = 1.5, hp = 1.5 }, target = "Tank" },
            { id = "tank_speed", name = "Turbo Engines", description = "Speed +25%", modifiers = { speed = 1.25 }, target = "Tank" }
        }
    },
    {
        id = "Flyer",
        type = "Flyer",
        class = require("Enemies.Enemy"), -- CHANGED
        tier = 4,
        spawnCost = 50,
        spawnWeight = 25,
        maxHp = 800,
        damage = 30,
        speed = 16,
        color = {1, 0.5, 0, 1},
        shape = "arrow",
        size = 30,
        isFlying = true,
        types = { enemy = true, flyer = true },
        baseSpawnDelay = 1.0,
        description = "Airborne threat. Flies over blockers and walls.",
        mutations = {
            { id = "flyer_speed", name = "Swift Swarm", description = "Speed +20%", modifiers = { speed = 1.2 }, target = "Flyer" },
            { id = "flyer_hp", name = "Precision Wings", description = "HP +40%", modifiers = { maxHp = 1.4, hp = 1.4 }, target = "Flyer" }
        }
    },
    {
        id = "Carrier",
        type = "Carrier",
        class = require("Enemies.Spawner"),
        tier = 3,
        spawnCost = 45,
        spawnWeight = 30,
        maxHp = 300,
        damage = 20,
        speed = 18,
        color = {0.2, 0.8, 1, 1},
        shape = "hexagon",
        size = 22,
        types = { enemy = true, carrier = true, tank = true },
        baseSpawnDelay = 2.0,
        description = "Swarm mother. Periodically spawns speeders.",
        mutations = {
            { id = "carrier_hp", name = "Reinforced Hull", description = "HP +40%", modifiers = { maxHp = 1.4, hp = 1.4 }, target = "Carrier" },
            { id = "carrier_rate", name = "Rapid Deployment", description = "Spawn Rate +30%", modifiers = { spawnInterval = 0.7 }, target = "Carrier" },
            { id = "carrier_count", name = "Swarm Brood", description = "Carrier spawns +1 Speeder.", modifiers = { spawnCount = { add = 1 } }, target = "Carrier" }
        }
    },
    {
        id = "Armored",
        type = "Armored",
        class = require("Enemies.Enemy"), -- CHANGED
        tier = 2,
        spawnCost = 40,
        spawnWeight = 30,
        maxHp = 300,
        damage = 15,
        speed = 20,
        color = {0.3, 0.6, 0.9, 1},
        shape = "octagon",
        size = 20,
        types = { enemy = true, armored = true },
        baseSpawnDelay = 1.2,
        affinities = {
            normal = 0.5,
        },
        description = "Heavily resistant to normal damage.",
        mutations = {
            { id = "armored_hp", name = "Dreadnought Plating", description = "HP +40%", modifiers = { maxHp = 1.4, hp = 1.4 }, target = "Armored" },
            { id = "armored_resist", name = "Even Stronger Armor", description = "Normal resistance +20%", modifiers = { normal = 0.8 }, target = "Armored" },
            { id = "armored_energy_resist", name = "Energy Shielding", description = "Energy resistance +25%", modifiers = { energy = 0.75 }, target = "Armored" }
        }
    },
    {
        id = "Guardian",
        type = "Guardian",
        class = require("Enemies.Guardian"),
        tier = 5,
        spawnCost = 75,
        spawnWeight = 25,
        maxHp = 250,
        damage = 20,
        speed = 18,
        color = {0.2, 0.7, 1, 1},
        shape = "cross",
        size = 24,
        types = { enemy = true, guardian = true },
        baseSpawnDelay = 1.5,
        description = "Support unit. Periodically grants shields to nearby allies.",
        mutations = {
            { id = "guardian_hp", name = "Sanctuary Plating", description = "HP +40%", modifiers = { maxHp = 1.4, hp = 1.4 }, target = "Guardian" },
            { id = "guardian_aura", name = "Guardian Aura", description = "Guardian projects a 25% damage reduction aura to nearby allies.", modifiers = { hasAura = { set = true } }, target = "Guardian" },
            { id = "guardian_shield", name = "Shield Overcharge", description = "Doubles the amount of shields granted to allies.", modifiers = { shieldAmount = 2 }, target = "Guardian" }
        }
    },
    {
        id = "Duplicator",
        type = "Duplicator",
        class = require("Enemies.Duplicator"),
        tier = 4,
        spawnCost = 40,
        spawnWeight = 40,
        maxHp = 150,
        damage = 20,
        speed = 22,
        color = {0.2, 0.8, 0.4, 1},
        shape = "diamond",
        size = 18,
        types = { enemy = true, duplicator = true, bio = true },
        baseSpawnDelay = 1.0,
        description = "A cellular mass that divides upon death. Multiplies quickly if unchecked.",
        mutations = {
            { id = "duplicator_burst", name = "Symbiotic Burst", description = "On duplication, releases a healing wave affecting all enemies.", modifiers = { healWaveOnSplit = { set = true } }, target = "Duplicator" },
            { id = "duplicator_speed", name = "Accelerated Mitosis", description = "Each duplication stage has increased movement speed.", modifiers = { acceleratedMitosis = { set = true } }, target = "Duplicator" },
            { id = "duplicator_hyper", name = "Hyper-Replication", description = "The last duplication stage spawns 1 extra clone.", modifiers = { extraFinalClone = { set = true } }, target = "Duplicator" }
        }
    },
    {
        id = "BeastMaster",
        type = "BeastMaster",
        class = require("Enemies.BeastMaster"),
        tier = 5,
        spawnCost = 120,
        spawnWeight = 20,
        maxHp = 350,
        damage = 25,
        speed = 20,
        color = {0.5, 0.1, 0.5, 1},
        shape = "rectangle",
        size = 26,
        types = { enemy = true, beastmaster = true },
        baseSpawnDelay = 2.5,
        description = "A powerful commander that summons swarms of beasts.",
        mutations = {
            { id = "beastmaster_blood", name = "Blood Pack", description = "The summon effect also fully heals his currently active beasts.", modifiers = { bloodPackHeal = { set = true } }, target = "BeastMaster" },
            { id = "beastmaster_endless", name = "Endless Pack", description = "Increases beasts per summon to 4 and max beasts to 8.", modifiers = { spawnCount = { set = 4 }, maxBeasts = { set = 8 } }, target = "BeastMaster" }
        }
    },
    {
        id = "Beast",
        type = "Beast",
        class = require("Enemies.Beast"),
        maxHp = 30,
        damage = 5,
        speed = 140,
        color = {0.8, 0.4, 0.1, 1},
        shape = "rectangle",
        size = 12,
        types = { enemy = true, beast = true },
        baseSpawnDelay = 0.2,
        description = "A swift beast summoned by the Beast Master."
    }
}

return TestingEnemyIndex
