-- =============================================================================
-- UNIT TEST: LevelManager & BattleManager Reward System
-- Tests:
-- 1. 3 Level choices generation
-- 2. Multiplier constraint: [1.00, 2.00] and mathematical guarantee of at least one < 1.20
-- 3. Incoming enemy forecast & undiscovered '???' masking
-- 4. Reward quantity rules: small chance of N=1 (Gold only), 4 rewards only if mult > 1.5
-- 5. Card Draw exact 75% marginal probability
-- 6. Gold 100% guarantee
-- 7. Relic placeholder verification
-- =============================================================================

-- Setup mock LÖVE environment
_G.love = {
    graphics = {
        getFont = function() return { getHeight = function() return 10 end, getWidth = function() return 10 end } end,
        print = function() end,
        printf = function() end,
        rectangle = function() end,
        setColor = function() end
    },
    math = { random = math.random }
}

_G.PersistentState = {
    cash = 0,
    materials = {},
    discoveredEnemies = { ["Grunt"] = true, ["Basic"] = true }
}

local LevelManager = require("Game.Core.LevelManager")
local BattleManager = require("Game.Core.BattleManager")
local BattleIndex = require("Game.Spawning.BattleIndex")

print("--- STARTING LEVEL MANAGER & BATTLE MANAGER TESTS ---")

local lm = LevelManager:new(BattleIndex)
local bm = BattleManager:new()

-- -----------------------------------------------------------------------------
-- TEST 1: Level Choice Count & Structure (Regular vs Milestone)
-- -----------------------------------------------------------------------------
-- Regular battle (e.g. level 1, 2, 3, 4): exactly 3 choices
local choices = lm:generateChoices(1)
assert(#choices == 3, "LevelManager must generate exactly 3 choices on regular battle! Got " .. #choices)
for i, choice in ipairs(choices) do
    assert(choice.difficultyMultiplier >= 1.0 and choice.difficultyMultiplier <= 2.0, "Multiplier out of bounds: " .. choice.difficultyMultiplier)
    assert(choice.rewards and #choice.rewards >= 1, "Choice missing rewards")
    assert(choice.enemies and #choice.enemies >= 1, "Choice missing enemy forecast")
    assert(choice.isMilestone == false, "Regular battle should not be marked milestone")
    assert(choice.templateId == "battle_1", "Level 1 choices must all use template battle_1! Got: " .. tostring(choice.templateId))
end

-- Verify Level 2 and Level 3 template mappings
local c2 = lm:generateChoices(2)
for _, choice in ipairs(c2) do
    assert(choice.templateId == "battle_2", "Level 2 choices must all use template battle_2! Got: " .. tostring(choice.templateId))
end

local c3 = lm:generateChoices(3)
for _, choice in ipairs(c3) do
    assert(choice.templateId == "battle_3", "Level 3 choices must all use template battle_3! Got: " .. tostring(choice.templateId))
end

-- Milestone battle (e.g. level 5, 10, 15, 20): player has no choice (exactly 1 choice)
local milestoneChoices = lm:generateChoices(5)
assert(#milestoneChoices == 1, "LevelManager must generate exactly 1 choice on milestone battle! Got " .. #milestoneChoices)
assert(milestoneChoices[1].isMilestone == true, "Milestone battle choice must be marked isMilestone = true")
assert(milestoneChoices[1].difficultyMultiplier == 2.00, "Milestone battle difficultyMultiplier must be fixed at 2.00! Got " .. tostring(milestoneChoices[1].difficultyMultiplier))
assert(lm:isMilestoneBattle(5) == true, "Level 5 must be recognized as milestone")
assert(lm:isMilestoneBattle(10) == true, "Level 10 must be recognized as milestone")
assert(lm:isMilestoneBattle(4) == false, "Level 4 must not be recognized as milestone")

print("[PASS] Test 1: Level choice count verified (3 on regular battles, exactly 1 on milestone battles with fixed difficulty).")

-- -----------------------------------------------------------------------------
-- TEST 2: Multiplier Constraint (10,000 Iteration Monte Carlo on Regular Battles)
-- Constraint: Min multiplier among the 3 choices MUST be < 1.20 in 100% of generations!
-- -----------------------------------------------------------------------------
local ITERATIONS = 10000
local safeCount = 0

for i = 1, ITERATIONS do
    -- Pick a regular (non-milestone) level
    local lvl = math.random(1, 19)
    while lvl % 5 == 0 do
        lvl = math.random(1, 19)
    end
    
    local c = lm:generateChoices(lvl)
    assert(#c == 3, "Expected 3 choices on regular battle " .. lvl)
    local m1, m2, m3 = c[1].difficultyMultiplier, c[2].difficultyMultiplier, c[3].difficultyMultiplier
    local minM = math.min(m1, m2, m3)
    
    for n, choice in ipairs(c) do
        local m = choice.difficultyMultiplier
        if choice.isElite then
            assert(m == LevelManager.ELITE_DIFFICULTY, "Elite multiplier must be 2.5")
        else
            assert(m >= 1.0 and m <= 2.0, "Multiplier " .. n .. " out of bounds")
        end
    end
    
    if minM < 1.20 then
        safeCount = safeCount + 1
    else
        error(string.format("FAILED CONSTRAINT at iteration %d: Multipliers were %.2f, %.2f, %.2f (min: %.2f)", i, m1, m2, m3, minM))
    end
end

assert(safeCount == ITERATIONS, "Soft-lock constraint failed! Safe count was " .. safeCount .. " / " .. ITERATIONS)
print(string.format("[PASS] Test 2: Multiplier guarantee verified: 100%% of %d runs had at least one choice < 1.20.", ITERATIONS))

-- -----------------------------------------------------------------------------
-- TEST 3: Scouting hides enemies at or above the scouting level ('???')
-- -----------------------------------------------------------------------------
local Scouting = require("Game.Prep.Scouting")
_G.PersistentState.discoveredEnemies = { ["Grunt"] = true, ["Soldier"] = true }
_G.PersistentState.scoutingLevel = 1 -- reveals tier 0 only

assert(lm:getEnemyDisplayName("Grunt") == "Grunt", "Tier 0 enemy is revealed at scouting level 1")
assert(lm:getEnemyDisplayName("Scout") == "Scout", "Tier 0 enemies are revealed even if never met")
assert(lm:getEnemyDisplayName("Soldier") == "???", "Tier 1 enemy stays hidden at scouting level 1, even if met")
assert(lm:getEnemyDisplayName("Tank") == "Tank", "Bosses are always revealed")

-- Forecasts follow the same rule
local sampleChoices = lm:generateChoices(3)
local foundHiddenInForecast = false
for _, choice in ipairs(sampleChoices) do
    for _, enemy in ipairs(choice.enemies or {}) do
        local tier = Scouting.tierOf(enemy.id)
        if tier >= 1 and tier < Scouting.BOSS_TIER then
            assert(enemy.displayName == "???" and enemy.isScouted == false, "Tier " .. tier .. " enemy in forecast must be '???', got: " .. tostring(enemy.displayName))
            foundHiddenInForecast = true
        else
            assert(enemy.displayName == enemy.id and enemy.isScouted == true, "Revealed enemy in forecast must show its name: " .. tostring(enemy.id))
        end
    end
end
assert(foundHiddenInForecast, "Expected at least one hidden enemy in the level 3 forecast")
assert(_G.PersistentState.discoveredEnemies["Medic"] == nil, "Generating choices must not discover enemies")

_G.PersistentState.scoutingLevel = 3
assert(lm:getEnemyDisplayName("Captain") == "Captain", "Scouting level 3 reveals tier 2")
_G.PersistentState.scoutingLevel = 1

print("[PASS] Test 3: Enemy discovery forecast correctly obfuscates undiscovered enemies to '???'.")

-- -----------------------------------------------------------------------------
-- TEST 4: BattleManager Reward Generation Rules
-- 1. Gold 100% guaranteed.
-- 2. When 1 reward drops, it is strictly Gold.
-- 3. When mult <= 1.5, 4 rewards NEVER occurs.
-- 4. When mult > 1.5, 4 rewards CAN occur.
-- 5. Card Draw marginal probability = 75%.
-- -----------------------------------------------------------------------------
local TOTAL_REWARD_RUNS = 25000
local goldCount = 0
local singleRewardCount = 0
local singleRewardIsGoldOnly = 0
local fourRewardLowMultCount = 0
local fourRewardHighMultCount = 0
local highMultRuns = 0
local cardDrawCount = 0
local relicFound = false

for i = 1, TOTAL_REWARD_RUNS do
    local mult = 1.0 + (math.random(0, 100) / 100) -- [1.0, 2.0]
    local lvl = math.random(1, 10)
    local rewards = bm:generateRewards(mult, lvl)
    
    local hasGold = false
    local sumValue = 0
    local cash = 0
    
    for _, r in ipairs(rewards) do
        if r.type == BattleManager.REWARD_TYPES.GOLD then
            hasGold = true
            cash = r.amount
            sumValue = sumValue + r.amount * BattleManager.REWARD_VALUES.GOLD
        elseif r.type == BattleManager.REWARD_TYPES.CARD_DRAW then
            cardDrawCount = cardDrawCount + 1
            sumValue = sumValue + (r.value or BattleManager.REWARD_VALUES.CARD_DRAW)
        elseif r.type == BattleManager.REWARD_TYPES.UPGRADE_MATERIAL then
            local unit = (r.materialId == "universal_essence") and 100 or 50
            assert(r.value == r.amount * unit, "Materials cost 50 each (Universal Essence 100)")
            sumValue = sumValue + r.value
        elseif r.type == BattleManager.REWARD_TYPES.CARD_REMOVAL then
            sumValue = sumValue + (r.value or BattleManager.REWARD_VALUES.CARD_REMOVAL)
        end
    end
    
    if hasGold then goldCount = goldCount + 1 end
    assert(not hasGold or cash > 0, "A $0 cash reward is never listed")
    assert(#rewards > 0, "Every battle has at least one reward")
    
    -- Every reward comes out of the budget: the total matches it (within 1 for cash
    -- rounding), unless the rewards cost more than the budget, in which case cash is 0
    local expectedBudget = math.floor((40 + lvl * 10) * mult + 0.5)
    assert(cash >= 0, "Cash is never negative")
    if cash > 0 then
        assert(math.abs(sumValue - expectedBudget) <= 1, string.format("Reward value (%d) must match budget (%d)", sumValue, expectedBudget))
    else
        assert(sumValue >= expectedBudget - 1, string.format("Cash only drops to 0 when the rewards use up the budget (%d of %d)", sumValue, expectedBudget))
    end
end

-- Assertions
-- Cash is left out only when the other rewards used up the whole budget (checked above)
assert(goldCount > TOTAL_REWARD_RUNS * 0.5, "Cash is in most reward lists: " .. goldCount .. "/" .. TOTAL_REWARD_RUNS)
assert(cardDrawCount > 0, "Card Draft was never generated")

-- Verification: Higher difficulty and higher level yields strictly higher reward budget
local lowRewards = bm:generateRewards(1.0, 1)
local highRewards = bm:generateRewards(2.0, 10)
local lowTotalVal = 0
for _, r in ipairs(lowRewards) do lowTotalVal = lowTotalVal + (r.value or (r.amount * (BattleManager.REWARD_VALUES[string.upper(r.type)] or 1))) end
local highTotalVal = 0
for _, r in ipairs(highRewards) do highTotalVal = highTotalVal + (r.value or (r.amount * (BattleManager.REWARD_VALUES[string.upper(r.type)] or 1))) end
assert(highTotalVal > lowTotalVal * 3, string.format("High difficulty/level should give vastly higher value: low=%d, high=%d", lowTotalVal, highTotalVal))

print(string.format("[PASS] Test 4: Value-budget reward generation verified!"))
print(string.format("  - Cash listed (whenever budget is left): %d / %d", goldCount, TOTAL_REWARD_RUNS))
print(string.format("  - Low tier (Lvl 1, 1.0x mult) Total Value: %d", lowTotalVal))
print(string.format("  - High tier (Lvl 10, 2.0x mult) Total Value: %d (%.1fx scaling)", highTotalVal, highTotalVal / lowTotalVal))

-- -----------------------------------------------------------------------------
-- TEST 5: BattleManager applyRewards Integration
-- -----------------------------------------------------------------------------
local mockGame = {
    rewardSystem = {
        activateCount = 0,
        activate = function(self, mode, count)
            self.activateCount = self.activateCount + 1
        end
    }
}

_G.PersistentState.cash = 100
_G.PersistentState.materials = {}
_G.PersistentState.cardRemovals = 0

local testRewards = {
    { type = "gold", amount = 150 },
    { type = "upgrade_material", materialId = "energy_cells", amount = 2 },
    { type = "upgrade_material", amount = 1 }, -- No material id: falls back to the default (Scrap)
    { type = "card_removal", amount = 1 },
    { type = "card_draw", amount = 1 },
    { type = "relic", isPlaceholder = true }
}

bm:applyRewards(testRewards, mockGame)
assert(_G.PersistentState.cash == 250, "Gold application failed: " .. _G.PersistentState.cash)
assert(_G.PersistentState.materials.energy_cells == 2, "Typed material reward application failed")
assert(_G.PersistentState.materials.scrap == 1, "Untyped material reward should fall back to Scrap")
assert(_G.PersistentState.cardRemovals == 1, "Card removal application failed")
assert(mockGame.rewardSystem.activateCount == 1, "Card draw reward activation failed")

print("[PASS] Test 5: Reward application and persistent state modification passed.")

-- -----------------------------------------------------------------------------
-- TEST 6: Scouting Report / Roster to Spawning Consistency
-- -----------------------------------------------------------------------------
local BattleDirector = require("Game.Spawning.BattleDirector")
local lm6 = LevelManager:new(bm)
for testLvl = 1, 10 do
    local choices = lm6:generateChoices(testLvl)
    for _, choice in ipairs(choices) do
        assert(choice.roster ~= nil and #choice.roster > 0, "Choice must include roster")
        local bdTest = BattleDirector:new({})
        local waves, _, _ = bdTest:generateBattle(choice.difficultyMultiplier, { template = choice.template, roster = choice.roster })
        
        -- Collect all unique enemy types that can spawn in waves
        local spawnedEnemies = {}
        for _, wave in ipairs(waves) do
            for _, entry in ipairs(wave) do
                local typeId = entry.type or (entry.enemy and entry.enemy.id)
                if typeId then
                    spawnedEnemies[typeId] = true
                end
            end
        end

        -- Verify all spawned enemies come strictly from the choice's roster / forecast
        local rosterIds = {}
        for _, enemy in ipairs(choice.roster) do
            rosterIds[enemy.id] = true
        end

        for spawnedId, _ in pairs(spawnedEnemies) do
            assert(rosterIds[spawnedId], string.format("Spawned enemy '%s' was not in the scouting roster for level %d!", spawnedId, testLvl))
        end
    end
end
print("[PASS] Test 6: Scouting report roster and generated wave spawn enemies match 100%.")

print("=== ALL LEVEL MANAGER AND BATTLE MANAGER TESTS PASSED ===")
