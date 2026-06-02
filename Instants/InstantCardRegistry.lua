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
    cost = 2,
    rarity = "Common",
    executionType = InstantCard.ExecutionType.Targeted,
    statModifiers = { range = { add = 100 } }
})

-- ==========================================
-- TIER 2: UNCOMMON CARDS
-- ==========================================
CardRegistry.Frenzy = InstantCard.new({
    id = "inst_frenzy_1",
    name = "Global Frenzy",
    description = "All turrets fire 15% faster.",
    cost = 3,
    rarity = "Uncommon",
    executionType = InstantCard.ExecutionType.Global,
    statModifiers = { fireRate = { mult = 0.15 } }
})

-- ==========================================
-- COMPLEX CARDS (Using customExecute)
-- ==========================================
CardRegistry.EmergencyRepairs = InstantCard.new({
    id = "inst_repair_1",
    name = "Emergency Repairs",
    description = "Heal your Base for 10 HP. Cannot exceed Max HP.",
    cost = 2,
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

return CardRegistry