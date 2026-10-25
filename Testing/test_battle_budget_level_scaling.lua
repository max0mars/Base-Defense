-- Per-level spawn budget scaling: each wave's budget grows +10% per level above 1,
-- then the chosen battle's difficulty multiplier is applied exactly once.
-- Regression: the level-choice path passed the difficulty multiplier where the
-- level was expected, so the budget never grew with the player's level.

local BattleDirector = require("Game.Spawning.BattleDirector")
local WaveDirector = require("Game.Spawning.WaveDirector")

print("--- STARTING BATTLE BUDGET LEVEL SCALING VERIFICATION ---")

local function approx(a, b) return math.abs(a - b) < 1e-9 end

-- 1. Linear multiplier curve
local bd = BattleDirector:new({})
assert(approx(bd:getLevelBudgetMultiplier(1), 1.0), "Level 1 multiplier should be 1.0")
assert(approx(bd:getLevelBudgetMultiplier(5), 1.4), "Level 5 multiplier should be 1.4")
assert(approx(bd:getLevelBudgetMultiplier(11), 2.0), "Level 11 multiplier should be 2.0")
assert(approx(bd:getLevelBudgetMultiplier(0), 1.0), "Levels below 1 clamp to 1.0")
print("[PASS] Budget multiplier grows +10% per level.")

-- 2. Wave budget applies the level multiplier to the template base
local template = { id = "flat", budgets = { 100, 200, 300 }, numWaves = 3 }
assert(bd:getBudgetForWave(template, 1, 1) == 100, "Level 1 wave 1 budget should equal the base")
assert(bd:getBudgetForWave(template, 3, 6) == 450, "Level 6 wave 3 budget should be 300 * 1.5")
print("[PASS] getBudgetForWave scales the template base by level.")

-- 3. generateBattle (level-choice path) scales by level and applies difficulty once
local captured
local realGenerate = WaveDirector.generateWaveList
WaveDirector.generateWaveList = function(_, waveIndex, _, _, budget)
    captured[waveIndex] = budget
    return {}, {}, 1
end

local function budgetsFor(level, difficultyMultiplier)
    captured = {}
    BattleDirector:new({}):generateBattle(difficultyMultiplier, { template = template, roster = {}, level = level })
    return captured
end

local level1 = budgetsFor(1, 1.0)
local level11 = budgetsFor(11, 1.0)
for wave = 1, 3 do
    assert(level11[wave] == level1[wave] * 2,
        string.format("Wave %d: level 11 budget %s should double level 1 budget %s", wave, tostring(level11[wave]), tostring(level1[wave])))
end
print("[PASS] Level 11 battle has double the level 1 spawn budget.")

local hard = budgetsFor(1, 1.5)
assert(hard[1] == 150, "Difficulty 1.5 at level 1 should give 150, got " .. tostring(hard[1]))
local hardHigh = budgetsFor(6, 1.5)
assert(hardHigh[2] == 450, "Difficulty 1.5 at level 6 should give 200 * 1.5 * 1.5 = 450, got " .. tostring(hardHigh[2]))
print("[PASS] Difficulty multiplier is applied once on top of level scaling.")

-- 4. Without an explicit level, the current level comes from PersistentState
_G.PersistentState = { battlesCompleted = 4 }
captured = {}
BattleDirector:new({}):generateBattle(1.0, { template = template, roster = {} })
assert(captured[1] == 140, "Level 5 (4 battles completed) wave 1 should be 140, got " .. tostring(captured[1]))
print("[PASS] Level defaults to battlesCompleted + 1.")

WaveDirector.generateWaveList = realGenerate
print("--- ALL BATTLE BUDGET LEVEL SCALING TESTS PASSED ---")
