local NormalEnemyIndex = {
    inactivePool = {
        {
            id = "Speeder",
            type = "Speeder",
            class = require("Enemies.SpeederGroup"),
            spawnCost = 25,
            spawnWeight = 45,
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
            spawnCost = 55,
            spawnWeight = 25,
            description = "Slow and heavy. Can soak up massive damage.",
            mutations = {
                { id = "tank_hp", name = "Behemoth Plating", description = "HP +30%", modifiers = { maxHp = 1.3, hp = 1.3 }, target = "Tank" },
                { id = "tank_speed", name = "Turbo Engines", description = "Speed +30%", modifiers = { speed = 1.3 }, target = "Tank" }
            }
        },
        {
            id = "Flyer",
            type = "Flyer",
            class = require("Enemies.Flyer"),
            spawnCost = 50,
            spawnWeight = 25,
            description = "Airborne threat. Flies over blockers and walls.",
            mutations = {
                { id = "flyer_speed", name = "Swift Swarm", description = "Speed +40%", modifiers = { speed = 1.4 }, target = "Flyer" },
                { id = "flyer_hp", name = "Precision Wings", description = "HP +40%", modifiers = { maxHp = 1.4, hp = 1.4 }, target = "Flyer" }
            }
        },
        {
            id = "Carrier",
            type = "Carrier",
            class = require("Enemies.Carrier"),
            spawnCost = 45,
            spawnWeight = 30,
            description = "Strong mothership that sends out fast flying enemies.",
            mutations = {
                { id = "carrier_rate", name = "Rapid Deployment", description = "Spawn Rate +30%", modifiers = { spawnInterval = 0.7 }, target = "Carrier" },
                { id = "carrier_count", name = "Swarm Brood", description = "Carrier spawns +1 Speeder.", modifiers = { spawnCount = { add = 1 } }, target = "Carrier" }
            }
        },
        {
            id = "Armored",
            type = "Armored",
            class = require("Enemies.Armored"),
            spawnCost = 40,
            spawnWeight = 30,
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
            spawnCost = 80,
            spawnWeight = 20,
            description = "Support unit. Periodically grants shields to nearby allies.",
            mutations = {
                { id = "guardian_aura", name = "Guardian Aura", description = "Guardian projects a 25% damage reduction aura to nearby allies.", modifiers = { hasAura = { set = true } }, target = "Guardian" },
                { id = "guardian_shield", name = "Shield Overcharge", description = "Doubles the amount of shields granted to allies.", modifiers = { shieldAmount = 2 }, target = "Guardian" }
            }
        },
        {
            id = "Duplicator",
            type = "Duplicator",
            class = require("Enemies.Duplicator"),
            spawnCost = 40,
            spawnWeight = 40,
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
            spawnCost = 70,
            spawnWeight = 20,
            description = "A powerful commander that summons swarms of beasts to protect himself.",
            mutations = {
                { id = "beastmaster_blood", name = "Blood Pack", description = "The summon effect also fully heals his currently active beasts.", modifiers = { bloodPackHeal = { set = true } }, target = "BeastMaster" },
                { id = "beastmaster_endless", name = "Endless Pack", description = "Increases beasts per summon to 4 and max beasts to 8.", modifiers = { spawnCount = { add = 1 }, maxBeasts = { add = 2 } }, target = "BeastMaster" }
            }
        }
    },
    activePool = {
        {
            id = "Basic",
            type = "Basic",
            class = require("Enemies.Enemy"),
            spawnCost = 10,
            spawnWeight = 60,
            description = "The backbone of the invasion. Average speed and health.",
            mutations = {
                { id = "basic_Explosive_armour", name = "Blast Shields", description = "Take 30% less explosive damage.", modifiers = { explosive = 0.7 }, target = "Basic" },
                { id = "basic_mitosis", name = "Mitosis", description = "10% chance to split into 2 Basic enemies on death.", modifiers = { splitOnDeathChance = { set = 0.1 } }, target = "Basic" }
            }
        }
    }
}

return NormalEnemyIndex
