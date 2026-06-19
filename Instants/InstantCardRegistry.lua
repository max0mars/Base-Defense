-- Game/Cards/InstantCardRegistry.lua
local InstantCard = require("Instants.instant")

local CardRegistry = {}

-- ==========================================
-- TIER 1: COMMON CARDS
-- ==========================================
CardRegistry.Overclock = InstantCard.new({
    id = "inst_overclock_1",
    name = "Overclock",
    description = "Give a turret +10% Damage.",
    cost = 1,
    rarity = "Common",
    executionType = InstantCard.ExecutionType.Targeted,
    statModifiers = { damage = { mult = 0.10 } }
})

CardRegistry.RangeFinder = InstantCard.new({
    id = "inst_range_1",
    name = "Range Finder",
    description = "Give a turret +100 Range.",
    cost = 1,
    rarity = "Common",
    executionType = InstantCard.ExecutionType.Targeted,
    statModifiers = { range = { add = 100 } }
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
    customExecute = function()
        -- Assuming you have a global Game state or Base object
        if Base.hp < Base.maxHp then
            Base.hp = math.min(Base.hp + 10, Base.maxHp)
            print("Base healed for 10 HP!")
            -- Trigger visual heal effect here
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

return CardRegistry
