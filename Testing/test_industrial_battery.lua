-- Testing/test_industrial_battery.lua
local EffectManager = require("Game.Effects.EffectManager")
local IndustrialBattery = require("Buildings.Passives.IndustrialBattery")

print("--- Starting Industrial Battery Tests ---")

local failures = 0
local function assert(condition, message)
    if not condition then
        print("[FAIL] " .. message)
        failures = failures + 1
    else
        print("[PASS] " .. message)
    end
end

-- Mock build grid
local mockGrid = {
    width = 10,
    height = 10,
    cellSize = 32,
    buildings = {},
    removeBuilding = function() end
}

-- Mock game
local mockGame = {
    objects = {},
    addObject = function(self, obj) table.insert(self.objects, obj) end
}
mockGame.playerEffectManager = EffectManager:new(nil, mockGame)
mockGame.enemyEffectManager = EffectManager:new(nil, mockGame)

-- Mock Base and main turret
local mockBase = {
    buildGrid = mockGrid
}
mockGame.base = mockBase

-- Main turret occupying slots 45, 46, 55, 56 (2x2)
local mockMainTurret = {
    slot = 45,
    isType = function(self, t) return t == "turret" or t == "mainturret" end,
    shapePattern = {{0,0}, {1,0}, {0,1}, {1,1}},
    buildGrid = mockGrid,
    destroyed = false
}
mockGrid.buildings[45] = mockMainTurret
mockGrid.buildings[46] = mockMainTurret
mockGrid.buildings[55] = mockMainTurret
mockGrid.buildings[56] = mockMainTurret

-- Energy turret placed at slot 34
local mockEnergyTurret = {
    slot = 34,
    isType = function(self, t) return t == "turret" or t == "energy" end,
    damage = 10,
    buildGrid = mockGrid,
    destroyed = false
}
mockEnergyTurret.effectManager = EffectManager:new(mockEnergyTurret, mockGame)
mockEnergyTurret.effectManager.parent = mockGame.playerEffectManager
mockGrid.buildings[34] = mockEnergyTurret

-- Apply inherent stats to energy turret
function mockEnergyTurret:getStat(name)
    return self.effectManager:getStat(name, self[name])
end

-- Non-energy turret placed at slot 33
local mockBallisticTurret = {
    slot = 33,
    isType = function(self, t) return t == "turret" or t == "ballistic" end,
    damage = 10,
    buildGrid = mockGrid,
    destroyed = false
}
mockBallisticTurret.effectManager = EffectManager:new(mockBallisticTurret, mockGame)
mockBallisticTurret.effectManager.parent = mockGame.playerEffectManager
mockGrid.buildings[33] = mockBallisticTurret
function mockBallisticTurret:getStat(name)
    return self.effectManager:getStat(name, self[name])
end

-- Spells
local mockEnergySpell = {
    damage = 20,
    isType = function(self, t) return t == "spell" or t == "energy" end
}
mockEnergySpell.effectManager = EffectManager:new(mockEnergySpell, mockGame)
mockEnergySpell.effectManager.parent = mockGame.playerEffectManager
function mockEnergySpell:getStat(name)
    return self.effectManager:getStat(name, self[name])
end

local mockPhysicalSpell = {
    damage = 20,
    isType = function(self, t) return t == "spell" or t == "physical" end
}
mockPhysicalSpell.effectManager = EffectManager:new(mockPhysicalSpell, mockGame)
mockPhysicalSpell.effectManager.parent = mockGame.playerEffectManager
function mockPhysicalSpell:getStat(name)
    return self.effectManager:getStat(name, self[name])
end

-- Instants
local mockEnergyInstant = {
    damage = 30,
    isType = function(self, t) return t == "instant" or t == "energy" end
}
mockEnergyInstant.effectManager = EffectManager:new(mockEnergyInstant, mockGame)
mockEnergyInstant.effectManager.parent = mockGame.playerEffectManager
function mockEnergyInstant:getStat(name)
    return self.effectManager:getStat(name, self[name])
end

local mockPhysicalInstant = {
    damage = 30,
    isType = function(self, t) return t == "instant" or t == "physical" end
}
mockPhysicalInstant.effectManager = EffectManager:new(mockPhysicalInstant, mockGame)
mockPhysicalInstant.effectManager.parent = mockGame.playerEffectManager
function mockPhysicalInstant:getStat(name)
    return self.effectManager:getStat(name, self[name])
end

-- Place Industrial Battery at slot 35
local battery = IndustrialBattery:new({
    game = mockGame,
    slot = 35
})
mockGrid.buildings[35] = battery
table.insert(mockGame.objects, battery)
table.insert(mockGame.objects, mockEnergyTurret)
table.insert(mockGame.objects, mockBallisticTurret)

-- Test 1: Industrial Battery is adjacent to main turret
assert(battery:isAdjacentToMainTurret() == true, "Industrial Battery at slot 35 is adjacent to Main Turret at slot 45")

-- Reset and recalculate/apply buffs
mockEnergyTurret.effectManager.activeEffects = {}
mockBallisticTurret.effectManager.activeEffects = {}
mockGame.playerEffectManager.activeEffects = {}

battery:applyBuffs()

-- Recalculate stats on targets
mockEnergyTurret.effectManager:recalculateStats()
mockBallisticTurret.effectManager:recalculateStats()
mockEnergySpell.effectManager:recalculateStats()
mockPhysicalSpell.effectManager:recalculateStats()
mockEnergyInstant.effectManager:recalculateStats()
mockPhysicalInstant.effectManager:recalculateStats()

-- Asserts
assert(mockEnergyTurret:getStat("damage") == 12, "Energy turret damage increased by 20% (10 -> 12)")
assert(mockBallisticTurret:getStat("damage") == 10, "Ballistic turret damage remains unmodified (10)")
assert(mockEnergySpell:getStat("damage") == 24, "Energy spell damage increased by 20% (20 -> 24)")
assert(mockPhysicalSpell:getStat("damage") == 20, "Physical spell damage remains unmodified (20)")
assert(mockEnergyInstant:getStat("damage") == 36, "Energy instant damage increased by 20% (30 -> 36)")
assert(mockPhysicalInstant:getStat("damage") == 30, "Physical instant damage remains unmodified (30)")

-- Simulate recalculateAllBuffs multiple times to test stacking prevention
local function simulateRecalculate()
    if mockGame.playerEffectManager.activeEffects then
        for i = #mockGame.playerEffectManager.activeEffects, 1, -1 do
            local effect = mockGame.playerEffectManager.activeEffects[i]
            if effect.isBuffTotem then
                table.remove(mockGame.playerEffectManager.activeEffects, i)
            end
        end
    end
    battery:applyBuffs()
    mockEnergySpell.effectManager:recalculateStats()
end

simulateRecalculate()
simulateRecalculate()
simulateRecalculate()

assert(mockEnergySpell:getStat("damage") == 24, "Energy spell damage does not stack indefinitely after multiple recalculations")

-- Test 2: Inactive if not adjacent (battery placed at slot 15, which is not adjacent to 45/46/55/56)
local farBattery = IndustrialBattery:new({
    game = mockGame,
    slot = 15
})
mockGrid.buildings[15] = farBattery

assert(farBattery:isAdjacentToMainTurret() == false, "Industrial Battery at slot 15 is NOT adjacent to Main Turret")

mockEnergyTurret.effectManager.activeEffects = {}
mockBallisticTurret.effectManager.activeEffects = {}
mockGame.playerEffectManager.activeEffects = {}

farBattery:applyBuffs()

mockEnergyTurret.effectManager:recalculateStats()
mockBallisticTurret.effectManager:recalculateStats()
mockEnergySpell.effectManager:recalculateStats()
mockPhysicalSpell.effectManager:recalculateStats()
mockEnergyInstant.effectManager:recalculateStats()
mockPhysicalInstant.effectManager:recalculateStats()

assert(mockEnergyTurret:getStat("damage") == 10, "Energy turret damage remains unmodified (10) when battery is NOT adjacent")
assert(mockEnergySpell:getStat("damage") == 20, "Energy spell damage remains unmodified (20) when battery is NOT adjacent")
assert(mockEnergyInstant:getStat("damage") == 30, "Energy instant damage remains unmodified (30) when battery is NOT adjacent")

-- Test Card affectedSlots retrieval
local Card = require("Game.Cards.Card")
local ibCard = Card:new({
    id = "industrialBattery",
    name = "Industrial Battery",
    executionType = require("Game.Cards.ExecutionType").Placement,
    payload = {
        buildingClass = IndustrialBattery,
        rarity = "rare",
        iconCategory = "buff",
        affectedSlots = {{-1, 0}, {0, 1}, {0, -1}, {1, 0}}
    }
})
local cardDraw = ibCard:getCardDraw()
assert(#cardDraw.affectedSlots == 4, "Industrial Battery CardDraw object contains 4 affectedSlots")
assert(cardDraw.affectedSlots[1][1] == -1 and cardDraw.affectedSlots[1][2] == 0, "First affectedSlot is {-1, 0}")

-- Check cost resolution
local deckCard = Card:new({
    id = "industrialBattery",
    name = "Industrial Battery",
    cost = 2,
    payload = { rarity = "rare" }
})
assert(deckCard:getCost() == 2, "Industrial Battery Card returns correct cost (2)")

print("--- Industrial Battery Tests Completed: " .. failures .. " failures ---")
os.exit(failures == 0 and 0 or 1)
