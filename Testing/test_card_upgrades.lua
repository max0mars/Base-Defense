_G.love = {
    graphics = {
        getFont = function()
            return {
                getHeight = function() return 10 end,
                getWidth = function() return 10 end,
                getWrap = function(_, _) return 10, {"text"} end
            }
        end,
        print = function() end,
        printf = function() end,
        rectangle = function() end,
        setColor = function() end,
        setLineWidth = function() end,
        push = function() end,
        pop = function() end,
        translate = function() end,
        scale = function() end,
        circle = function() end,
        line = function() end,
        polygon = function() end
    },
    mouse = {
        getPosition = function() return 0, 0 end,
        setVisible = function() end,
        setCursor = function() end,
        getSystemCursor = function() return {} end
    },
    math = { colorFromBytes = function() return 1, 1, 1, 1 end, random = math.random },
    timer = { getTime = function() return 0 end }
}

_G.VIRTUAL_WIDTH = 1280
_G.VIRTUAL_HEIGHT = 720
_G.Cursor = { wantHand = false }
_G.PersistentState = {
    cash = 2000, -- Tier I -> V costs 955 gold, leave room for the custom-cost card test
    materials = { scrap = 20 },
    deck = nil
}

local Card = require("Game.Cards.Card")
local CardDraw = require("Game.Cards.CardDraw")
local PlayerDeck = require("Game.Cards.PlayerDeck")
local ExecutionType = require("Game.Cards.ExecutionType")
local CardUpgradeConfig = require("Game.Cards.CardUpgradeConfig")
local TurretIndex = require("Buildings.TurretIndex")

-- 1. Test Card starts at Tier 1 (Tier I)
local sentryTemplate = TurretIndex.common[1]
local card = Card:new({
    id = "sentry",
    name = "Sentry",
    description = "Test Sentry",
    executionType = ExecutionType.Placement,
    payload = {
        buildingClass = sentryTemplate.building,
        config = {
            name = "Sentry",
            types = {"turret", "building"},
            damage = 10,
            range = 400,
            fireRate = 1.0,
            bulletSpeed = 400,
            firingArc = { direction = 0, minRange = 0, angle = math.pi/4 }
        }
    }
})

assert(card:getTier() == 1, "Card should initialize at Tier 1")

-- 2. Test initial visual card stats: at Tier 1, bonus stats should be 0
local cd1 = card:getCardDraw()
assert(cd1.tier == 1, "CardDraw tier should be 1")
assert(cd1.damageBarsBonus == 0, "Tier 1 damageBarsBonus should be 0")
assert(cd1.rangeBarsBonus == 0, "Tier 1 rangeBarsBonus should be 0")
assert(cd1.firerateBarsBonus == 0, "Tier 1 firerateBarsBonus should be 0")

-- 3. Test modular cost querying
local nextCost = card:getNextUpgradeCost()
assert(nextCost.gold == 30 or nextCost.cash == 30, "Tier 2 upgrade cost should require 30 gold")
assert(nextCost.scrap == 1, "Tier 2 upgrade cost should require 1 Scrap (Sentry is a normal gun)")
assert(nextCost.material == nil, "Material placeholder should be resolved to a real material")

-- 4. Test sequential upgrading and economy deduction
local canUp, _, cost = card:canUpgrade()
assert(canUp == true, "Card should be upgradeable with sufficient funds")

local initialCash = _G.PersistentState.cash
local initialMats = _G.PersistentState.materials.scrap

local success, newTier = card:upgrade()
assert(success == true, "Upgrade to Tier 2 should succeed")
assert(newTier == 2, "New tier should be 2")
assert(card:getTier() == 2, "card:getTier() should return 2")
assert(_G.PersistentState.cash == initialCash - 30, "30 gold should be deducted")
assert(_G.PersistentState.materials.scrap == initialMats - 1, "1 Scrap should be deducted")

-- 5. Test Tier 2 stat scaling: flat 20% stat increase
local cd2 = card:getCardDraw()
assert(cd2.tier == 2, "CardDraw tier should be 2")
local expectedDmgBonus = cd2.damageBars * 0.20
assert(math.abs(cd2.damageBarsBonus - expectedDmgBonus) < 0.0001, "Tier 2 bonus should be flat +20% of base")

-- 6. Upgrade sequentially up to Tier 5 (Tier V)
card:upgrade() -- Tier 3 (+40%)
assert(card:getTier() == 3, "Should be Tier 3")
local cd3 = card:getCardDraw()
assert(math.abs(cd3.damageBarsBonus - cd3.damageBars * 0.40) < 0.0001, "Tier 3 bonus should be flat +40% of base")

card:upgrade() -- Tier 4 (+60%)
assert(card:getTier() == 4, "Should be Tier 4")
local cd4 = card:getCardDraw()
assert(math.abs(cd4.damageBarsBonus - cd4.damageBars * 0.60) < 0.0001, "Tier 4 bonus should be flat +60% of base")

card:upgrade() -- Tier 5 (+80%)
assert(card:getTier() == 5, "Should be Tier 5")
local cd5 = card:getCardDraw()
assert(math.abs(cd5.damageBarsBonus - cd5.damageBars * 0.80) < 0.0001, "Tier 5 bonus should be flat +80% of base")

-- 7. Test max tier cap
assert(card:getNextUpgradeCost() == nil, "Tier 5 should have nil next cost")
local canUpMax, reasonMax = card:canUpgrade()
assert(canUpMax == false, "Tier 5 should not be upgradeable")
assert(reasonMax == "max_tier", "Reason should be max_tier")
local upFail = card:upgrade()
assert(upFail == false, "Upgrading beyond Tier 5 should fail")
assert(card:getTier() == 5, "Tier should remain 5")

-- 8. Test modularity: custom resource costs per card
local customCard = Card:new({
    id = "cryo_turret",
    name = "Cryo Turret",
    tier = 1,
    upgradable = true,
    upgradeCosts = {
        [2] = { gold = 75, ["Cryo Core"] = 2 }
    }
})
local customCost = customCard:getNextUpgradeCost()
assert(customCost.gold == 75, "Custom gold cost should be 75")
assert(customCost["Cryo Core"] == 2, "Custom resource Cryo Core should be 2")

-- Should fail without Cryo Cores
local canUpCustom, reasonCustom = customCard:canUpgrade()
assert(canUpCustom == false, "Should fail without required custom resource")
assert(reasonCustom == "insufficient_resources", "Reason should be insufficient_resources")

-- Add Cryo Cores to inventory
CardUpgradeConfig.Economy.addResource("Cryo Core", 2)
assert(CardUpgradeConfig.Economy.getResource("Cryo Core") == 2, "Cryo Core balance should be 2")
local canUpCustom2 = customCard:canUpgrade()
assert(canUpCustom2 == true, "Should succeed once Cryo Cores are available")
local upSuccess = customCard:upgrade()
assert(upSuccess == true, "Custom card upgrade should succeed")
assert(CardUpgradeConfig.Economy.getResource("Cryo Core") == 0, "Cryo Cores should be consumed")

-- 9. Test in-game turret combat stat scaling on card:execute
local testDeck = PlayerDeck:new()
_G.PersistentState.deck = testDeck
testDeck:addCard(card) -- card is Tier 5 (+80% stats)

local dummyGame = {}
local turretInstance = card:execute(dummyGame)
assert(turretInstance ~= nil, "Turret should be instantiated")
-- Base damage was 10. Tier 5 (+80%) should be 18!
assert(math.abs(turretInstance.damage - 18) < 0.001, "Turret damage should scale by +80% (10 -> 18), got " .. tostring(turretInstance.damage))
-- Base range was 400. Tier 5 (+15% range per tier = +60%) should be 640!
assert(math.abs(turretInstance.range - 640) < 0.001, "Turret range should scale by +60% (400 -> 640), got " .. tostring(turretInstance.range))
-- Base fireRate was 1.0. Tier 5 (+10% fire rate per tier = +40%) should be 1.4!
assert(math.abs(turretInstance.fireRate - 1.4) < 0.001, "Turret fireRate should scale by +40% (1.0 -> 1.4), got " .. tostring(turretInstance.fireRate))

-- 10. Test preparation_scene Upgrade Window UI logic
local prepScene = require("Scenes.preparation_scene")
prepScene:load(false)
assert(prepScene.upgradeCardsButton ~= nil, "prepScene should have upgradeCardsButton")
assert(prepScene.viewingUpgrades == false, "viewingUpgrades should initially be false")

-- Simulate clicking Upgrade Cards button
prepScene:mousepressed(prepScene.upgradeCardsButton.x + 5, prepScene.upgradeCardsButton.y + 5, 1)
assert(prepScene.viewingUpgrades == true, "viewingUpgrades should be true after button click")
assert(prepScene.viewingDeck == false, "viewingDeck should be closed")

-- 11. Test "upgradable" flag and turret-only constraints
assert(card:isUpgradable() == true, "Turret card should be upgradable by default")
assert(card.upgradable == true, "Card obj.upgradable should be true")

local nonTurretCard = Card:new({
    id = "energy_buffer",
    name = "Energy Buffer",
    executionType = ExecutionType.Placement,
    payload = {
        config = {
            name = "Energy Buffer",
            iconCategory = "buff"
        }
    }
})
assert(nonTurretCard:isUpgradable() == false, "Buffer card should not be upgradable")
assert(nonTurretCard:canUpgrade() == false, "Buffer card cannot be upgraded")

local disabledTurret = Card:new({
    id = "locked_turret",
    name = "Locked Turret",
    upgradable = false,
    executionType = ExecutionType.Placement,
    payload = {
        config = {
            name = "Locked Turret",
            iconCategory = "turret",
            damage = 10, range = 300, fireRate = 1
        }
    }
})
assert(disabledTurret:isUpgradable() == false, "Turret with upgradable=false flag should not be upgradable")
assert(disabledTurret:canUpgrade() == false, "Locked turret cannot be upgraded")

-- 12. Test deck with mixed card types: only upgradable cards appear in Upgrade Window
local InstantCard = require("Instants.Instant")
local Spell = require("Spells.Spell")

local inst = InstantCard.new({ id = "test_instant", name = "Test Instant", cost = 1 })
local spell = Spell.new({ id = "test_spell", name = "Test Spell", cost = 2 })
assert(inst:isUpgradable() == false, "InstantCard should not be upgradable")
assert(spell:isUpgradable() == false, "Spell should not be upgradable")

local mixedDeck = PlayerDeck:new()
mixedDeck:addCard(card)          -- upgradable turret, but at Tier 5 (shows MAX TIER)
mixedDeck:addCard(customCard)    -- upgradable turret at Tier 2 (shows Upgrade Button)
mixedDeck:addCard(nonTurretCard) -- not upgradable buffer (filtered out)
mixedDeck:addCard(disabledTurret)-- not upgradable (upgradable = false, filtered out)
mixedDeck:addCard(inst)          -- not upgradable instant (filtered out)
mixedDeck:addCard(spell)         -- not upgradable spell (filtered out)

_G.PersistentState.deck = mixedDeck
prepScene.viewingUpgrades = true
prepScene:drawUpgradeWindow()

-- Verify that ONLY customCard has an upgrade button (card is max tier, non-turrets are filtered out)
assert(#prepScene.upgradeButtons == 1, "Only upgradable non-max turret cards should have an upgrade button, got " .. tostring(#prepScene.upgradeButtons))
assert(prepScene.upgradeButtons[1].card.id == customCard.id, "Button should correspond to the upgradable customCard")

-- 13. Test "Unstable Laser" and other passive buildings are NOT upgradable
local UnstableLaser = require("Buildings.Passives.UnstableLaser")
local unstableCard = Card:new({
    id = "unstable_laser",
    name = "Unstable Laser",
    description = "Increases adjacent Energy Turrets' attacks with a 25% chance to burn enemies.",
    executionType = ExecutionType.Placement,
    cost = 2,
    quantity = 1,
    payload = {
        buildingClass = UnstableLaser,
        config = {},
        rarity = "rare",
        iconCategory = "buff",
        affectedSlots = {{-1, 0}, {0, 1}, {0, -1}, {1, 0}}
    }
})
assert(unstableCard:isTurret() == false, "Unstable Laser must not be recognized as a turret")
assert(unstableCard:isUpgradable() == false, "Unstable Laser must not be upgradable")
local canUpUnstable, reasonUnstable = unstableCard:canUpgrade()
assert(canUpUnstable == false and reasonUnstable == "not_upgradable", "Unstable Laser cannot be upgraded")

local SmallBox = require("Buildings.Blockers.SmallBox")
local blockerCard = Card:new({
    id = "small_box",
    name = "Small Box",
    executionType = ExecutionType.Placement,
    cost = 1,
    payload = {
        buildingClass = SmallBox,
        config = {},
        iconCategory = "blocker"
    }
})
assert(blockerCard:isTurret() == false, "Small Box blocker must not be recognized as a turret")
assert(blockerCard:isUpgradable() == false, "Small Box blocker must not be upgradable")

local BuffClass = require("Buildings.Passives.Buff")
local ammoCacheCard = Card:new({
    id = "ammoCache",
    name = "Ammo Cache",
    executionType = ExecutionType.Placement,
    cost = 2,
    payload = {
        buildingClass = BuffClass,
        config = { iconCategory = "buff" },
        iconCategory = "buff",
        affectedSlots = {{1,0},{-1,0},{0,1},{0,-1}}
    }
})
assert(ammoCacheCard:isTurret() == false, "Ammo Cache must not be recognized as a turret")
assert(ammoCacheCard:isUpgradable() == false, "Ammo Cache must not be upgradable")

-- 14. Test that Upgrade Tier improves turret's BASE value and compounds with in-combat buffs
-- User Requirement: "if a tier 2 turret is buffed with an additional 50% damage, the math should workout to 120% * 1.5"
local buffTestTurretTemplate = {
    name = "BuffTestTurret",
    damage = 10,
    range = 400,
    fireRate = 1.0,
    bulletSpeed = 300,
    firingArc = { direction = 0, minRange = 0, angle = math.pi / 4 },
    building = require("Buildings.Turrets.Turret"),
    iconCategory = "turret",
    types = { "turret", "building" }
}

local buffTurretCard = Card:new({
    id = "buff_test_turret",
    name = "Buff Test Turret",
    executionType = ExecutionType.Placement,
    payload = {
        buildingClass = buffTestTurretTemplate.building,
        config = {
            name = buffTestTurretTemplate.name,
            damage = buffTestTurretTemplate.damage,
            range = buffTestTurretTemplate.range,
            fireRate = buffTestTurretTemplate.fireRate,
            bulletSpeed = buffTestTurretTemplate.bulletSpeed,
            firingArc = buffTestTurretTemplate.firingArc,
            iconCategory = "turret",
            types = { turret = true, building = true }
        }
    }
})

-- Upgrade to Tier 2 (+20% base stat increase)
CardUpgradeConfig.Economy.addResource("gold", 500)
for _, mat in ipairs(require("Game.Cards.MaterialRegistry").getTyped()) do CardUpgradeConfig.Economy.addResource(mat.id, 10) end
local canUpBuffTurret = buffTurretCard:canUpgrade()
assert(canUpBuffTurret == true, "Buff turret card should be upgradable")
buffTurretCard:upgrade()
assert(buffTurretCard.tier == 2, "Card should now be Tier 2")

-- Instantiate turret via card:execute
local mockGame = {
    objects = {},
    base = { buildGrid = { width = 10, height = 10, cellSize = 30, unlocked = {} } }
}
local turretT2 = buffTurretCard:execute(mockGame)
assert(turretT2 ~= nil, "Turret T2 should be instantiated")

-- The base value must be 12 (10 * 1.20)
assert(math.abs(turretT2.damage - 12) < 0.001, "Turret base damage should be 12 (10 * 1.20), got " .. tostring(turretT2.damage))
assert(math.abs(turretT2:getStat("damage") - 12) < 0.001, "Turret initial getStat damage should be 12")

-- Apply in-combat buff: +50% damage modifier
turretT2.effectManager:applyEffect({
    name = "AttackSurgeBuff",
    statModifiers = {
        damage = { mult = 0.50 }
    }
})
turretT2.effectManager:recalculateStats()

-- Calculation check:
-- Base value = 12 (120% of Tier 1)
-- Multiplier = 1 + 0.50 = 1.50
-- Result = 12 * 1.50 = 18 = (120% * 1.5)
local buffedDamage = turretT2:getStat("damage")
assert(math.abs(buffedDamage - 18) < 0.001, 
    "Tier 2 turret buffed with +50% damage must equal 120% * 1.5 = 18 (NOT 17 additive), got " .. tostring(buffedDamage))

-- Also verify fireRate base value and compounding:
-- Base fireRate was 1.0, Tier 2 is 1.10 (+10% fire rate per tier)
assert(math.abs(turretT2.fireRate - 1.10) < 0.001, "Turret base fireRate should be 1.10")
turretT2.effectManager:applyEffect({
    name = "FireRateOverclock",
    statModifiers = {
        fireRate = { mult = 0.25 }
    }
})
turretT2.effectManager:recalculateStats()
-- 1.10 * 1.25 = 1.375
local buffedFireRate = turretT2:getStat("fireRate")
assert(math.abs(buffedFireRate - 1.375) < 0.001,
    "Tier 2 turret fireRate with +25% buff must equal 1.10 * 1.25 = 1.375, got " .. tostring(buffedFireRate))

-- 15. Test upgrading a single card from duplicates: duplicates should NOT all be upgraded
local dupDeck = PlayerDeck:new()
_G.PersistentState.deck = dupDeck

-- Add 3 copies of Blaster at Tier 1
local blasterCard = Card:new({
    id = "test_blaster",
    name = "Test Blaster",
    executionType = ExecutionType.Placement,
    cost = 1,
    quantity = 3,
    tier = 1,
    payload = {
        buildingClass = buffTestTurretTemplate.building,
        config = {
            name = "Test Blaster",
            damage = 10,
            range = 300,
            fireRate = 1.0,
            bulletSpeed = 300,
            firingArc = { direction = 0, minRange = 0, angle = math.pi / 4 },
            iconCategory = "turret",
            types = { turret = true, building = true }
        }
    }
})
dupDeck:addCard(blasterCard)

assert(#dupDeck.cards == 1, "Deck should have 1 card entry")
assert(dupDeck.cards[1].quantity == 3, "Blaster stack should have quantity 3")
assert(dupDeck.cards[1].tier == 1, "Blaster stack should initially be Tier 1")

-- Upgrade ONE copy from the stack of 3
CardUpgradeConfig.Economy.addResource("gold", 1000)
for _, mat in ipairs(require("Game.Cards.MaterialRegistry").getTyped()) do CardUpgradeConfig.Economy.addResource(mat.id, 10) end
local upSuccess, upTier = dupDeck.cards[1]:upgrade(dupDeck)
assert(upSuccess == true, "Upgrade should succeed")
assert(upTier == 2, "Upgraded card should be Tier 2")

-- Verify: original stack should have quantity reduced to 2 (still Tier 1!)
-- AND a new entry for Tier 2 should exist with quantity 1!
assert(#dupDeck.cards == 2, "Deck should now have 2 card entries (Tier 1 stack + Tier 2 stack)")
local t1Card, t2Card
for _, c in ipairs(dupDeck.cards) do
    if (c.tier or 1) == 1 then t1Card = c end
    if (c.tier or 1) == 2 then t2Card = c end
end
assert(t1Card ~= nil, "Tier 1 stack must still exist")
assert(t1Card.quantity == 2, "Tier 1 stack quantity must be 2 (was 3), got " .. tostring(t1Card.quantity))
assert(t2Card ~= nil, "Tier 2 entry must exist")
assert(t2Card.quantity == 1, "Tier 2 entry quantity must be 1, got " .. tostring(t2Card.quantity))

-- Upgrade another copy from Tier 1 stack
local upSuccess2, upTier2 = t1Card:upgrade(dupDeck)
assert(upSuccess2 == true, "Second upgrade should succeed")
assert(t1Card.quantity == 1, "Tier 1 stack quantity must now be 1, got " .. tostring(t1Card.quantity))
assert(t2Card.quantity == 2, "Tier 2 stack quantity must now be 2 (merged), got " .. tostring(t2Card.quantity))

-- Upgrade the Tier 2 stack (has 2 copies) -> should create 1x Tier 3 copy, leaving 1x Tier 2 copy
local upSuccess3, upTier3 = t2Card:upgrade(dupDeck)
assert(upSuccess3 == true, "Tier 2 upgrade should succeed")
assert(upTier3 == 3, "Upgraded tier should be 3")
assert(t2Card.quantity == 1, "Tier 2 stack quantity must now be 1 (was 2), got " .. tostring(t2Card.quantity))

local t3Card
for _, c in ipairs(dupDeck.cards) do
    if (c.tier or 1) == 3 then t3Card = c end
end
assert(t3Card ~= nil, "Tier 3 entry must exist")
assert(t3Card.quantity == 1, "Tier 3 entry quantity must be 1, got " .. tostring(t3Card.quantity))

-- Verify adding a new Tier 1 copy only stacks with Tier 1
local newT1 = Card:new({
    id = "test_blaster",
    name = "Test Blaster",
    executionType = ExecutionType.Placement,
    quantity = 1,
    tier = 1
})
dupDeck:addCard(newT1)
assert(t1Card.quantity == 2, "Tier 1 stack should now have 2 copies")
assert(t2Card.quantity == 1, "Tier 2 stack should remain at 1 copy")
assert(t3Card.quantity == 1, "Tier 3 stack should remain at 1 copy")

print("All card upgrade tests passed successfully!")

