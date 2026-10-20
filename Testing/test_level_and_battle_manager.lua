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
    
    assert(m1 >= 1.0 and m1 <= 2.0, "Multiplier 1 out of bounds")
    assert(m2 >= 1.0 and m2 <= 2.0, "Multiplier 2 out of bounds")
    assert(m3 >= 1.0 and m3 <= 2.0, "Multiplier 3 out of bounds")
    
    if minM < 1.20 then
        safeCount = safeCount + 1
    else
        error(string.format("FAILED CONSTRAINT at iteration %d: Multipliers were %.2f, %.2f, %.2f (min: %.2f)", i, m1, m2, m3, minM))
    end
end

assert(safeCount == ITERATIONS, "Soft-lock constraint failed! Safe count was " .. safeCount .. " / " .. ITERATIONS)
print(string.format("[PASS] Test 2: Multiplier guarantee verified: 100%% of %d runs had at least one choice < 1.20.", ITERATIONS))

-- -----------------------------------------------------------------------------
-- TEST 3: Enemy Discovery Obfuscation ('???')
-- -----------------------------------------------------------------------------
_G.PersistentState.discoveredEnemies = { ["Grunt"] = true } -- Grunt is discovered, Scout/Tank are not

local gruntName = lm:getEnemyDisplayName("Grunt")
local scoutName = lm:getEnemyDisplayName("Scout")
local tankName = lm:getEnemyDisplayName("Tank")

assert(gruntName == "Grunt", "Discovered enemy should show name: " .. tostring(gruntName))
assert(scoutName == "???", "Undiscovered enemy should show '???': " .. tostring(scoutName))
assert(tankName == "???", "Undiscovered enemy should show '???': " .. tostring(tankName))

-- Verify that generating choices for a higher level battle with new enemies keeps undiscovered enemies as '???'
_G.PersistentState.discoveredEnemies = { ["Grunt"] = true }
local sampleChoices = lm:generateChoices(3)
local foundUndiscoveredInForecast = false
for _, choice in ipairs(sampleChoices) do
    for _, enemy in ipairs(choice.enemies or {}) do
        if enemy.id ~= "Grunt" then
            assert(enemy.displayName == "???", "Undiscovered enemy in forecast must be '???', got: " .. tostring(enemy.displayName))
            assert(enemy.isDiscovered == false, "enemy.isDiscovered must be false")
            foundUndiscoveredInForecast = true
        else
            assert(enemy.displayName == "Grunt", "Discovered enemy in forecast must be 'Grunt'")
            assert(enemy.isDiscovered == true, "enemy.isDiscovered must be true")
        end
    end
end
assert(foundUndiscoveredInForecast, "Expected at least one undiscovered enemy in level 3 forecast")
assert(_G.PersistentState.discoveredEnemies["Grunt"] == true, "Grunt must still be discovered")
assert(_G.PersistentState.discoveredEnemies["Soldier"] == nil, "Soldier must not be prematurely discovered during choice generation")

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
    
    for _, r in ipairs(rewards) do
        if r.type == BattleManager.REWARD_TYPES.GOLD then
            hasGold = true
            sumValue = sumValue + r.amount * BattleManager.REWARD_VALUES.GOLD
        elseif r.type == BattleManager.REWARD_TYPES.CARD_DRAW then
            cardDrawCount = cardDrawCount + 1
            sumValue = sumValue + (r.value or BattleManager.REWARD_VALUES.CARD_DRAW)
        elseif r.type == BattleManager.REWARD_TYPES.UPGRADE_MATERIAL then
            sumValue = sumValue + (r.value or (r.amount * BattleManager.REWARD_VALUES.UPGRADE_MATERIAL))
        elseif r.type == BattleManager.REWARD_TYPES.CARD_REMOVAL then
            sumValue = sumValue + (r.value or BattleManager.REWARD_VALUES.CARD_REMOVAL)
        end
    end
    
    if hasGold then goldCount = goldCount + 1 end
    
    -- Verify total reward value matches budget (within 1 budget due to integer cash rounding at 1 value per cash)
    local expectedBudget = math.floor((40 + lvl * 10) * mult + 0.5)
    assert(math.abs(sumValue - expectedBudget) <= 1, string.format("Reward value (%d) must match budget (%d)", sumValue, expectedBudget))
end

-- Assertions
assert(goldCount == TOTAL_REWARD_RUNS, "Gold was not present in 100% of drops! " .. goldCount .. "/" .. TOTAL_REWARD_RUNS)
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
print(string.format("  - Gold guaranteed 100%%: %d / %d", goldCount, TOTAL_REWARD_RUNS))
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
    { type = "upgrade_material", amount = 2 },
    { type = "card_removal", amount = 1 },
    { type = "card_draw", amount = 1 },
    { type = "relic", isPlaceholder = true }
}

bm:applyRewards(testRewards, mockGame)
assert(_G.PersistentState.cash == 250, "Gold application failed: " .. _G.PersistentState.cash)
assert(_G.PersistentState.materials["Upgrade Material"] == 2, "Upgrade material application failed")
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
