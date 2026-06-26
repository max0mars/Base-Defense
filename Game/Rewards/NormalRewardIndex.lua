local RewardIndex = {
    common = {
        {
            id = "sentry",
            name = "Sentry",
            description = "Balanced range and damage.",
            building = require("Buildings.Turrets.Sentry"),
            type = "building",
            iconCategory = "turret",
            cost = 1,
            damageBars = 2,
            rangeBars = 3,
            firerateBars = 3
        },
        {
            id = "blaster",
            name = "Blaster",
            description = "Fires energy bolts, effective against armor.",
            building = require("Buildings.Turrets.Blaster"),
            type = "building",
            iconCategory = "turret",
            cost = 1,
            damageBars = 2,
            rangeBars = 3,
            firerateBars = 2
        },
        {
            id = "autoCannon",
            name = "Auto Cannon",
            description = "High fire rate, low damage, short range.",
            type = "building",
            building = require("Buildings.Turrets.AutoCannon"),
            iconCategory = "turret",
            cost = 1,
            damageBars = 1,
            rangeBars = 1,
            firerateBars = 4
        },
        {
            id = "shotgunTurret",
            name = "Shotgun Turret",
            description = "Shreds close-range targets.",
            type = "building",
            building = require("Buildings.Turrets.ShotgunTurret"),
            iconCategory = "turret",
            cost = 1,
            damageBars = 4,
            rangeBars = 1,
            firerateBars = 2
        },
        {
            id = "heavygun",
            name = "Heavy Gun",
            description = "Long range, high damage.",
            type = "building",
            building = require("Buildings.Turrets.HeavyGun"),
            iconCategory = "turret",
            cost = 1,
            damageBars = 3,
            rangeBars = 4,
            firerateBars = 1
        },
    },
    uncommon = {
        {
            id = "poisonTurret",
            name = "Poison Turret",
            description = "Fires toxic darts that damage over time.",
            type = "building",
            building = require("Buildings.Turrets.PoisonTurret"),
            iconCategory = "turret",
            cost = 2,
            damageBars = 1,
            rangeBars = 3,
            firerateBars = 3
        },
        {
            id = "unstable_laser",
            name = "Unstable Laser",
            description = "Increases adjacent Energy Turrets' attacks with a 25% chance to burn enemies.",
            type = "building",
            building = require("Buildings.Passives.UnstableLaser"),
            iconCategory = "buff",
            cost = 2,
            affectedSlots = {{-1, 0}, {0, 1}, {0, -1}, {1, 0}}
        },
        {
            id = "airburst",
            name = "Airburst Turret",
            description = "Fires shells that explode mid-air into shrapnel.",
            type = "building",
            building = require("Buildings.Turrets.AirburstTurret"),
            iconCategory = "turret",
            cost = 1,
            damageBars = 2,
            rangeBars = 3,
            firerateBars = 2
        },
        {
            id = "ammoCache",
            name = "Ammo Cache",
            description = "Increase nearby turret damage by 30%",
            type = "building",
            building = require("Buildings.Passives.Buff"),
            iconCategory = "buff",
            cost = 2,
            affectedSlots = {{1,0},{-1,0},{0,1},{0,-1}}
        },
        {
            id = "shatterRounds",
            name = "Recursive Rounds",
            description = "Bullets will now split on inpact.",
            type = "building",
            building = require("Buildings.Passives.ShardBullets"),
            iconCategory = "buff",
            cost = 2,
            affectedSlots = {{-1, 0}, {1, 0}}
        },
        {
            id = "fluxCannon",
            name = "Flux Cannon",
            description = "Energy damage that ignores heavy armor.",
            type = "building",
            building = require("Buildings.Turrets.FluxCannon"),
            iconCategory = "turret",
            cost = 2,
            damageBars = 3,
            rangeBars = 2,
            firerateBars = 4
        },
        {
            id = "bank",
            name = "Bank",
            description = "Generates 1 Token per wave if adjacent slots are occupied.",
            type = "building",
            building = require("Buildings.Passives.Bank"),
            iconCategory = "buff",
            cost = 2,
            affectedSlots = {{1,0},{-1,0},{0,1},{0,-1}}
        },
        {
            id = "grenadier",
            name = "Grenadier",
            description = "Lobs grenades that explode after a short delay.",
            type = "building",
            iconCategory = "turret",
            building = require("Buildings.Turrets.Grenadier"),
            cost = 1,
            damageBars = 3,
            rangeBars = 3,
            firerateBars = 2
        },
        {
            id = "slushCannon",
            name = "Slush Cannon",
            description = "Fires heavy clumps of slush that slow enemies on impact.",
            type = "building",
            building = require("Buildings.Turrets.SlushCannon"),
            iconCategory = "turret",
            cost = 1,
            damageBars = 1,
            rangeBars = 3,
            firerateBars = 1
        },
    },
    rare = {
        {
            id = "toxicTotem",
            name = "Chem Lab",
            description = "Spreads deadly toxins. Highly contagious.",
            type = "building",
            building = require("Buildings.Passives.ToxicTotem"),
            iconCategory = "buff",
            cost = 2,
            affectedSlots = {{1,0},{-1,0},{0,1},{0,-1}}
        },
        {
            id = "conduit",
            name = "Conduit",
            description = "Provides 10 Mana each wave.",
            type = "building",
            building = require("Buildings.Passives.Conduit"),
            iconCategory = "buff",
            cost = 2,
            affectedSlots = {}
        },
        -- {
        --     id = "industrialBattery",
        --     name = "Industrial Battery",
        --     description = "Increases all Energy damage by 50% when adjacent to the Main Turret.",
        --     type = "building",
        --     building = require("Buildings.Passives.IndustrialBattery"),
        --     iconCategory = "buff",
        --     cost = 2,
        --     affectedSlots = {}
        -- },
        {
            id = "gator",
            name = "GTR-55 Gator",
            description = "Hard hitting rounds go right through enemies.",
            type = "building",
            building = require("Buildings.Turrets.Gator"),
            iconCategory = "turret",
            cost = 2,
            damageBars = 3,
            rangeBars = 3,
            firerateBars = 3
        },
        {
            id = "missileLauncher",
            name = "Missile Launcher",
            description = "Wouldn't want to get in the way of one of these.",
            type = "building",
            building = require("Buildings.Turrets.MissileLauncher"),
            iconCategory = "turret",
            cost = 2,
            damageBars = 4,
            rangeBars = 3,
            firerateBars = 2
        },
        {
            id = "plasmaScattershot",
            name = "Plasma Scattershot",
            description = "Fires plamsa rounds at high speed but has limited ammo. Reloads slowly.",
            type = "building",
            building = require("Buildings.Turrets.PlasmaScattershot"),
            iconCategory = "turret",
            cost = 2,
            damageBars = 2,
            rangeBars = 1,
            firerateBars = 4
        },
        {
            id = "sequenceTurret",
            name = "CSR-8 Sequence",
            description = "Shoots faster the longer it stays locked onto a target.",
            type = "building",
            building = require("Buildings.Turrets.SequenceTurret"),
            iconCategory = "turret",
            cost = 2,
            damageBars = 2,
            rangeBars = 3,
            firerateBars = 2
        },
        {
            id = "slowBlocker",
            name = "Frost Trap",
            description = "Slows down nearby enemies.",
            type = "building",
            building = require("Buildings.Blockers.SlowBlocker"),
            iconCategory = "blocker",
            cost = 1,
            affectedSlots = {{0,0}}
        },
        {
            id = "hookTurret",
            name = "The Hook",
            description = "Fires a heavy shot that stuns enemies in their tracks.",
            type = "building",
            building = require("Buildings.Turrets.HookTurret"),
            iconCategory = "turret",
            cost = 1,
            damageBars = 3,
            rangeBars = 2,
            firerateBars = 1
        },
    },
    epic = {
        {
            id = "sniper",
            name = "Sniper Turret",
            description = "High damage, long range.",
            type = "building",
            building = require("Buildings.Turrets.Sniper"),
            iconCategory = "turret",
            cost = 2,
            damageBars = 4,
            rangeBars = 4,
            firerateBars = 1
        },
        {
            id = "mortar",
            name = "Mortar",
            description = "KABOOM!",
            type = "building",
            building = require("Buildings.Turrets.Mortar"),
            iconCategory = "turret",
            cost = 2,
            damageBars = 4,
            rangeBars = 3,
            firerateBars = 1
        },
        {
            id = "explosiveBullets",
            name = "Explosive Bullets",
            description = "Adds a little extra something to nearby turrets.",
            type = "building",
            building = require("Buildings.Passives.ExplosiveTotem"),
            iconCategory = "buff",
            cost = 2,
            affectedSlots = {{1, 0}, {2, 0}}
        },

    },
    legendary = {

        {
            id = "chainLaser",
            name = "PROJECT CHIMERA",
            description = "No one is safe",
            type = "building",
            building = require("Buildings.Turrets.ChainLaser"),
            iconCategory = "turret",
            cost = 3,
            damageBars = 3,
            rangeBars = 3,
            firerateBars = 3
        }
    }
}
function RewardIndex.injectSpells(registry)
    if not registry then return end
    for _, spell in pairs(registry) do
        if type(spell) == "table" and spell.id and spell.rarity then
            local rarityKey = spell.rarity:lower()
            if RewardIndex[rarityKey] then
                -- Avoid duplicates
                local exists = false
                for _, item in ipairs(RewardIndex[rarityKey]) do
                    if item.id == spell.id then
                        exists = true
                        break
                    end
                end
                if not exists then
                    table.insert(RewardIndex[rarityKey], {
                        id = spell.id,
                        name = spell.name,
                        description = spell.description,
                        type = "spell",
                        cost = spell.cost or 1,
                        rarity = rarityKey
                    })
                end
            end
        end
    end
end

function RewardIndex.injectInstants(registry)
    if not registry then return end
    for _, inst in pairs(registry) do
        if type(inst) == "table" and inst.id and inst.rarity then
            local rarityKey = inst.rarity:lower()
            if RewardIndex[rarityKey] then
                -- Avoid duplicates
                local exists = false
                for _, item in ipairs(RewardIndex[rarityKey]) do
                    if item.id == inst.id then
                        exists = true
                        break
                    end
                end
                if not exists then
                    table.insert(RewardIndex[rarityKey], {
                        id = inst.id,
                        name = inst.name,
                        description = inst.description,
                        type = "instant",
                        cost = inst.cost or 1,
                        rarity = rarityKey
                    })
                end
            end
        end
    end
end

function RewardIndex.injectCards(cards)
    if not cards then return end
    for rarity, rarityCards in pairs(cards) do
        if RewardIndex[rarity] then
            for _, card in ipairs(rarityCards) do
                table.insert(RewardIndex[rarity], card)
            end
        end
    end
end

return RewardIndex
