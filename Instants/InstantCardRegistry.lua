-- Game/Cards/InstantCardRegistry.lua
local InstantCard = require("Instants.instant")

local CardRegistry = {}

-- ==========================================
-- TIER 1: COMMON CARDS
-- ==========================================
CardRegistry.Overclock = InstantCard.new({
    id = "inst_overclock_1",
    name = "Overclock",
    description = "Give a turret +15% Damage.",
    cost = 1,
    rarity = "Common",
    executionType = InstantCard.ExecutionType.Targeted,
    statModifiers = { damage = { mult = 0.15 } }
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
    description = "All turrets fire 15% faster.",
    cost = 3,
    rarity = "Uncommon",
    executionType = InstantCard.ExecutionType.Group,
    statModifiers = { fireRate = { mult = 0.15 } }
})

-- ==========================================
-- COMPLEX CARDS (Using customExecute)
-- ==========================================
CardRegistry.EmergencyRepairs = InstantCard.new({
    id = "inst_repair_1",
    name = "Emergency Repairs",
    description = "Heal your Base for 10 HP. Consume.",
    cost = 1,
    isConsume = true,
    rarity = "Rare",
    executionType = InstantCard.ExecutionType.Global,
    
    -- We don't use statModifiers here, we write custom logic
    customExecute = function(gameObj)
        if not gameObj or not gameObj.base then return end
        local base = gameObj.base
        if base.hp < base.maxHp then
            base.hp = math.min(base.hp + 10, base.maxHp)
            print("Base healed for 10 HP!")
        end
    end
})

CardRegistry.HastyDefenses = InstantCard.new({
    id = "inst_hasty_1",
    name = "Hasty Defenses",
    description = "Spawn 3 Sentries in random unoccupied slots on the base.",
    cost = 2,
    isConsume = true,
    rarity = "Uncommon",
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
        
        local SentryClass = require("Buildings.Turrets.Sentry")
        
        local count = 0
        -- Pick 3 random empty slots and spawn sentries
        while count < 3 and #emptySlots > 0 do
            local randIndex = love.math.random(1, #emptySlots)
            local slot = emptySlots[randIndex]
            table.remove(emptySlots, randIndex)
            
            -- Force unlock the slot so Base:addBuilding's visibility check doesn't fail
            grid.unlocked[slot] = true
            
            local newSentry = SentryClass:new({game = gameObj})
            gameObj:newBuilding(newSentry, slot)
            count = count + 1
        end
    end
})

CardRegistry.PocketDefenses = InstantCard.new({
    id = "inst_pocket_defenses_1",
    name = "Pocket Defenses",
    description = "Add 3 random 1-cost turrets to your hand. They cost 0. Consume",
    cost = 2,
    isConsume = true,
    rarity = "Rare",
    executionType = InstantCard.ExecutionType.Global,
    
    customExecute = function(gameObj)
        if not gameObj or not gameObj.hand then return end
        
        local Card = require("Game.Cards.Card")
        local ExecutionType = require("Game.Cards.ExecutionType")
        local RewardIndex = require("Game.Rewards.NormalRewardIndex")
        
        -- Collect all cost-1 turrets from the reward index
        local pool = {}
        for _, rarityGroup in pairs(RewardIndex) do
            if type(rarityGroup) == "table" then
                for _, reward in ipairs(rarityGroup) do
                    if reward.cost == 1 and reward.building and reward.type == "building"
                       and reward.iconCategory == "turret" then
                        table.insert(pool, reward)
                    end
                end
            end
        end
        
        if #pool == 0 then return end
        
        local added = 0
        for i = 1, 3 do
            if #gameObj.hand >= 8 then
                gameObj:spawnFloatingText("Hand is full!", 400, 300, {0.8, 0.2, 0.2, 1})
                break
            end
            
            local pick = pool[love.math.random(1, #pool)]
            
            local card = Card:new({
                id = pick.id,
                name = pick.name,
                description = pick.description,
                cost = 0,
                executionType = ExecutionType.Placement,
                isConsume = true, -- temporary: consumed after use, never enters discard
                payload = {
                    buildingClass = pick.building,
                    config = {},
                    rarity = "common",
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

return CardRegistry
