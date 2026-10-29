-- Game/Cards/InstantCardRegistry.lua
local InstantCard = require("Instants.Instant")
local Chill = require("Game.Effects.StatusEffects.Chill")

local CardRegistry = {}

-- ==========================================
-- TIER 1: COMMON CARDS
-- ==========================================
CardRegistry.Overclock = InstantCard.new({
    id = "inst_overclock_1",
    name = "Overclock",
    description = "Give a turret +25% Damage.",
    cost = 1,
    rarity = "Common",
    executionType = InstantCard.ExecutionType.Targeted,
    statModifiers = { damage = { mult = 0.25 } }
})

CardRegistry.RangeFinder = InstantCard.new({
    id = "inst_range_1",
    name = "Binoculars",
    description = "Give a turret extra Range.",
    cost = 1,
    rarity = "Common",
    executionType = InstantCard.ExecutionType.Targeted,
    statModifiers = { range = { add = 50 } }
})

-- ==========================================
-- TIER 2: UNCOMMON CARDS
-- ==========================================
CardRegistry.Frenzy = InstantCard.new({
    id = "inst_frenzy_1",
    name = "Frenzy",
    description = "All turrets fire 20% faster.",
    cost = 3,
    rarity = "Uncommon",
    executionType = InstantCard.ExecutionType.Group,
    statModifiers = { fireRate = { mult = 0.2 } }
})

-- Global, so ice turrets placed later in the battle get it too
CardRegistry.Permafrost = InstantCard.new({
    id = "inst_permafrost_1",
    name = "Permafrost",
    description = "Ice turrets deal 20% more damage this battle.",
    cost = 2,
    rarity = "Uncommon",
    executionType = InstantCard.ExecutionType.Global,
    statModifiers = { ice_damage = { mult = 0.2 } }
})

CardRegistry.Cannibalize = InstantCard.new({
    id = "inst_cannibalize_1",
    name = "Cannibalize",
    description = "Destroy a building. Your main turret gains +50% Damage.",
    cost = 1,
    rarity = "Uncommon",
    executionType = InstantCard.ExecutionType.Targeted,
    targetsBuildings = true,
    destroysTarget = true,
    canTarget = function(target)
        return not target:isType("mainturret")
    end,
    customExecute = function(targetEntity)
        local gameObj = targetEntity.game
        -- Read position and size before removal clears the building's grid
        local tx, ty = targetEntity:getCenterPosition()
        local cellSize = targetEntity.buildGrid and targetEntity.buildGrid.cellSize or 40
        local color = targetEntity.color or {1, 1, 1, 1}
        targetEntity:remove()

        gameObj:spawnParticleExplosion(color, cellSize, tx, ty, 0.7, 14)
        gameObj:spawnParticleExplosion({1, 0.55, 0.15, 1}, cellSize * 0.6, tx, ty, 0.5, 10)
        gameObj:spawnExpandingCircle(tx, ty, cellSize * 0.2, cellSize * 1.2, {1, 0.45, 0.1}, 0.35)
        if AUDIO then AUDIO:playSFX("explosion_01") end

        -- Auras from a destroyed passive have to come off its neighbours
        gameObj:recalculateAllBuffs()

        local main = gameObj.base and gameObj.base.mainLazer
        if main and main.effectManager then
            main.effectManager:applyEffect({
                name = "inst_cannibalize_1_eff",
                displayName = "Cannibalize",
                statModifiers = { damage = { mult = 0.5 } },
            })
            gameObj:spawnBuffPluses(main:getCenterPosition())
        end
    end
})

-- ==========================================
-- TIER 3: RARE CARDS
-- ==========================================
-- Chill per second grows with the square root of the turret's base fire rate:
-- fast turrets chill faster overall in small hits, slow turrets chill slower in
-- big hits (which also lose more to decay between shots). One shot never adds
-- more than CRYOELECTRONICS_MAX_PER_SHOT, so nothing freezes in a hit or two.
local CRYOELECTRONICS_CHILL_PER_SECOND = 1.2 -- at 1 shot per second
local CRYOELECTRONICS_RATE_SCALING = 0.5
local CRYOELECTRONICS_PELLET_SCALING = 0.5 -- shotguns: 10 pellets count as ~3.2x fire rate
local CRYOELECTRONICS_MAX_PER_SHOT = 2
CardRegistry.Cryoelectronics = InstantCard.new({
    id = "inst_cryoelectronics_1",
    name = "Cryoelectronics",
    description = "Give an energy turret's attacks a chilling effect.",
    cost = 1,
    rarity = "Rare",
    executionType = InstantCard.ExecutionType.Targeted,
    canTarget = function(target)
        if target.damageType ~= "energy" then return false end
        -- Already converted: playing it again would do nothing
        return not (target.effectManager and target.effectManager:getEffect("inst_cryoelectronics_1_eff"))
    end,
    customExecute = function(targetEntity)
        if targetEntity and targetEntity.effectManager then
            targetEntity.effectManager:applyEffect({
                name = "inst_cryoelectronics_1_eff",
                displayName = "Cryoelectronics",
                grantedHitEffect = Chill.onHit({
                    name = "cryoelectronics_chill",
                    perSecond = CRYOELECTRONICS_CHILL_PER_SECOND,
                    rateScaling = CRYOELECTRONICS_RATE_SCALING,
                    pelletScaling = CRYOELECTRONICS_PELLET_SCALING,
                    maxPerShot = CRYOELECTRONICS_MAX_PER_SHOT,
                }),
            })
        end
    end
})

-- ==========================================
-- COMPLEX CARDS (Using customExecute)
-- ==========================================
CardRegistry.EmergencyRepairs = InstantCard.new({
    id = "inst_repair_1",
    name = "Emergency Repairs",
    description = "Heal your Base for 15 HP. Consume.",
    cost = 1,
    isConsume = true,
    rarity = "Rare",
    executionType = InstantCard.ExecutionType.Global,
    
    -- We don't use statModifiers here, we write custom logic
    customExecute = function(gameObj)
        if not gameObj or not gameObj.base then return end
        local base = gameObj.base
        if base.hp < base.maxHp then
            base.hp = math.min(base.hp + 15, base.maxHp)
            print("Base healed for 15 HP!")
        end
    end
})

CardRegistry.HastyDefenses = InstantCard.new({
    id = "inst_hasty_1",
    name = "Hasty Defenses",
    description = "Spawn 3 Sentries in random unoccupied slots on the base.",
    cost = 2,
    isConsume = true,
    rarity = "Rare",
    executionType = InstantCard.ExecutionType.Global,
    
    customExecute = function(gameObj)
        if not gameObj or not gameObj.base or not gameObj.base.buildGrid then return end
        
        local grid = gameObj.base.buildGrid
        local emptySlots = {}
        
        -- The condition is that slots are not already occupied.
        -- We loop through all possible slots on the grid (width * height).
        local totalSlots = grid.width * grid.height
        for i = 1, totalSlots do
            if not grid.buildings[i] then
                table.insert(emptySlots, i)
            end
        end
        
        local TurretClass = require("Buildings.Turrets.Turret")
        local TurretIndex = require("Buildings.TurretIndex")
        local sentryConfig = {}
        for k, v in pairs(TurretIndex.common[1]) do
            sentryConfig[k] = v
        end
        local count = 0
        -- Pick 3 random empty slots and spawn sentries
        while count < 3 and #emptySlots > 0 do
            local randIndex = love.math.random(1, #emptySlots)
            local slot = emptySlots[randIndex]
            table.remove(emptySlots, randIndex)
            
            -- Force unlock the slot so Base:addBuilding's visibility check doesn't fail
            grid.unlocked[slot] = true
            
            sentryConfig.game = gameObj
            local newSentry = TurretClass:new(sentryConfig)
            gameObj:newBuilding(newSentry, slot)
            count = count + 1
        end
    end
})

-- Flat rarity odds for Pocket Defenses turrets (no epic/legendary 1-cost turrets exist)
local POCKET_DEFENSES_RARITY_WEIGHTS = { common = 65, uncommon = 28, rare = 7, epic = 0, legendary = 0 }

CardRegistry.PocketDefenses = InstantCard.new({
    id = "inst_pocket_defenses_1",
    name = "Pocket Defenses",
    description = "Add 3 random 1-cost turrets to your hand. They cost 0. Consume",
    cost = 2,
    isConsume = true,
    rarity = "Uncommon",
    executionType = InstantCard.ExecutionType.Global,
    
    customExecute = function(gameObj)
        if not gameObj or not gameObj.hand then return end
        
        local Card = require("Game.Cards.Card")
        local ExecutionType = require("Game.Cards.ExecutionType")
        local RewardIndex = require("Game.Rewards.RewardIndex")
        local RewardPool = require("Game.Rewards.RewardPool")

        -- Collect all cost-1 turrets from the reward index, grouped by rarity
        local poolByRarity = {}
        local poolSize = 0
        for _, rarity in ipairs(RewardPool.RarityOrder) do
            poolByRarity[rarity] = {}
            for _, reward in ipairs(RewardIndex[rarity] or {}) do
                if reward.cost == 1 and reward.building and reward.type == "building"
                   and reward.iconCategory == "turret" then
                    table.insert(poolByRarity[rarity], reward)
                    poolSize = poolSize + 1
                end
            end
        end

        if poolSize == 0 then return end

        -- Each turret's rarity is rolled at a flat rate, independent of battle level
        local weights = POCKET_DEFENSES_RARITY_WEIGHTS

        -- Falls back to the next lower rarity that has a cost-1 turret
        local function pickTurret(rolledRarity)
            local foundStart = false
            for _, rarity in ipairs(RewardPool.RarityOrder) do
                if rarity == rolledRarity then foundStart = true end
                local group = poolByRarity[rarity]
                if foundStart and #group > 0 then
                    return group[love.math.random(1, #group)], rarity
                end
            end
            -- Nothing at or below the rolled rarity: take the lowest rarity that has any
            for i = #RewardPool.RarityOrder, 1, -1 do
                local rarity = RewardPool.RarityOrder[i]
                local group = poolByRarity[rarity]
                if #group > 0 then
                    return group[love.math.random(1, #group)], rarity
                end
            end
        end

        local added = 0
        for i = 1, 3 do
            if #gameObj.hand >= (gameObj.MAX_HAND_SIZE or 10) then
                gameObj:spawnFloatingText("Hand is full!", 400, 300, {0.8, 0.2, 0.2, 1})
                break
            end
            
            local pick, rarity = pickTurret(RewardPool.rollRarity(weights))

            local card = Card:new({
                id = pick.id,
                name = pick.name,
                description = pick.description,
                cost = 0,
                executionType = ExecutionType.Placement,
                isConsume = true, -- temporary: consumed after use, never enters discard
                payload = {
                    buildingClass = pick.building,
                    config = pick,
                    rarity = rarity,
                    cost = 0,
                }
            })
            
            table.insert(gameObj.hand, card)
            added = added + 1
        end
        
        if added > 0 then
            gameObj:spawnFloatingText("+" .. added .. " Turrets!", 400, 280, {0.3, 1.0, 0.5, 1})
        end
    end
})

-- Area: the player picks a 2x2 square of grid cells (see InputHandler:getAreaTarget)
CardRegistry.SquadTactics = InstantCard.new({
    id = "inst_squad_tactics_1",
    name = "Squad Tactics",
    description = "Give turrets in a 2x2 square +20% Damage. Can't target the main turret.",
    cost = 1,
    rarity = "Rare",
    executionType = InstantCard.ExecutionType.Area,
    areaSize = 2,
    statModifiers = { damage = { mult = 0.2 } }
})

-- Moves card-style buffs only: debuffs, totem auras (reapplied by recalculateAllBuffs)
-- and main turret upgrades stay where they are
local function isTransferableBuff(effect)
    return not (effect.isDebuff or effect.isBuffTotem or effect.isUpgrade or effect.isIndependent)
end

CardRegistry.PowerDispersal = InstantCard.new({
    id = "inst_power_dispersal_1",
    name = "Power Dispersal",
    description = "Remove all buffs from your main turret and give them to every other turret. Consume.",
    cost = 1,
    isConsume = true,
    rarity = "Rare",
    executionType = InstantCard.ExecutionType.Global,

    customExecute = function(gameObj)
        local main = gameObj and gameObj.base and gameObj.base.mainLazer
        if not main or not main.effectManager then return end

        local buffs = {}
        for _, effect in ipairs(main.effectManager.activeEffects) do
            if isTransferableBuff(effect) then table.insert(buffs, effect) end
        end
        if #buffs == 0 then
            gameObj:spawnFloatingText("No buffs to disperse!", 400, 300, {0.8, 0.2, 0.2, 1})
            return
        end

        for _, effect in ipairs(buffs) do
            main.effectManager:removeEffect(effect)
        end

        for _, obj in ipairs(gameObj.objects) do
            if obj ~= main and not obj.destroyed and obj:isType("turret") and obj.effectManager then
                for _, effect in ipairs(buffs) do
                    -- Each turret gets its own statModifiers, since iterative
                    -- effects (Accelerating Core) grow theirs in place each wave
                    local copy = setmetatable({}, getmetatable(effect))
                    for k, v in pairs(effect) do copy[k] = v end
                    if effect.statModifiers then
                        copy.statModifiers = {}
                        for stat, mod in pairs(effect.statModifiers) do
                            local modCopy = {}
                            for k, v in pairs(mod) do modCopy[k] = v end
                            copy.statModifiers[stat] = modCopy
                        end
                    end
                    obj.effectManager:applyEffect(copy)
                end
                if gameObj.spawnBuffPluses then
                    gameObj:spawnBuffPluses(obj:getCenterPosition())
                end
            end
        end
    end
})

CardRegistry.AcceleratingCore = InstantCard.new({
    id = "inst_accel_core_1",
    name = "Accelerating Core",
    description = "Give a turret +10% Fire Rate, and an additional +10% Fire Rate each wave.",
    cost = 2,
    rarity = "Rare",
    executionType = InstantCard.ExecutionType.Targeted,
    customExecute = function(targetEntity)
        if targetEntity and targetEntity.effectManager then
            local IterativeEffect = require("Game.Effects.StatusEffects.IterativeEffect")
            local eff = IterativeEffect:new({
                name = "inst_accel_core_1_eff",
                displayName = "Accelerating Core",
                statModifiers = { fireRate = { mult = 0.1 } },
                iterativeChanges = { fireRate = { mult = 0.1 } },
                iterativeLimits = { fireRate = { max_mult = 0.5 } }
            })
            targetEntity.effectManager:applyEffect(eff)
            targetEntity.effectManager:recalculateStats()
        end
    end
})

return CardRegistry
