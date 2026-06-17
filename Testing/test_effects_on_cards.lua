-- Testing/test_effects_on_cards.lua
-- Standalone test suite verifying effects on Spell and Instant cards

package.path = package.path .. ";./?.lua"

local Spell = require("Spells.Spell")
local Instant = require("Instants.Instant")
local EffectManager = require("Game.Effects.EffectManager")

print("--- Starting Effects on Spells & Instants Tests ---")

local failures = 0

local function assert(condition, message)
    if not condition then
        print("[FAIL] " .. message)
        failures = failures + 1
    else
        print("[PASS] " .. message)
    end
end

-- 1. Setup direct effects on Spells and Instants
do
    local spellCard = Spell.new({
        id = "test_spell",
        name = "Test Spell",
        cost = 3,
        radius = 50
    })

    local instantCard = Instant.new({
        id = "test_instant",
        name = "Test Instant",
        cost = 2
    })

    -- Ensure they are created with effect managers and correct types
    assert(spellCard.effectManager ~= nil, "Spell has an effect manager")
    assert(spellCard:isType("spell") == true, "Spell reports type 'spell'")
    assert(spellCard:isType("instant") == false, "Spell does not report type 'instant'")

    assert(instantCard.effectManager ~= nil, "Instant has an effect manager")
    assert(instantCard:isType("instant") == true, "Instant reports type 'instant'")
    assert(instantCard:isType("spell") == false, "Instant does not report type 'spell'")

    -- Apply effect directly to spell (e.g., -1 cost, +20 radius)
    spellCard.effectManager:applyEffect({
        name = "spell_buff",
        statModifiers = {
            cost = { add = -1 },
            radius = { add = 20 }
        }
    })
    spellCard.effectManager:recalculateStats()

    assert(spellCard:getCost() == 2, "Spell cost reduced from 3 to 2 directly")
    assert(spellCard:getStat("radius", spellCard.radius) == 70, "Spell radius increased from 50 to 70 directly")

    -- Apply effect directly to instant (e.g., -1 cost)
    instantCard.effectManager:applyEffect({
        name = "instant_buff",
        statModifiers = {
            cost = { add = -1 }
        }
    })
    instantCard.effectManager:recalculateStats()

    assert(instantCard:getCost() == 1, "Instant cost reduced from 2 to 1 directly")
end

-- 2. Setup parent propagation and targetTypes filtering
do
    -- Create player effect manager (parent)
    local playerEM = EffectManager:new(nil, nil)

    local spellCard = Spell.new({
        id = "fireball_test",
        cost = 3,
        radius = 40
    })

    local instantCard = Instant.new({
        id = "heal_test",
        cost = 2
    })

    -- Wire parent propagation
    spellCard.effectManager.parent = playerEM
    instantCard.effectManager.parent = playerEM

    -- Apply +50% spell radius, -1 spell cost
    playerEM:applyEffect({
        name = "global_spell_boost",
        statModifiers = {
            cost = { add = -1 },
            radius = { mult = 0.50 }
        },
        targetTypes = { spell = true }
    })

    -- Apply -1 cost to instants
    playerEM:applyEffect({
        name = "global_instant_boost",
        statModifiers = {
            cost = { add = -1 }
        },
        targetTypes = { instant = true }
    })

    spellCard.effectManager:recalculateStats()
    instantCard.effectManager:recalculateStats()

    -- Assert spell scaling
    assert(spellCard:getCost() == 2, "Spell inherited -1 cost from parent (3 -> 2)")
    assert(spellCard:getStat("radius", spellCard.radius) == 60, "Spell inherited +50% radius from parent (40 -> 60)")

    -- Assert instant scaling
    assert(instantCard:getCost() == 1, "Instant inherited -1 cost from parent (2 -> 1)")

    -- Verify that spell ignored instant boost, and instant ignored spell boost
    -- Spell cost should be 2, not 1 (meaning it only got -1, not -2)
    assert(spellCard:getCost() == 2, "Spell ignored instant-only cost reduction")
    assert(instantCard:getStat("radius", 40) == 40, "Instant ignored spell-only radius boost")
end

print("--- Effects on Spells & Instants Tests Completed with " .. failures .. " failures ---")
os.exit(failures == 0 and 0 or 1)
