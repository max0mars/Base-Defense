-- Late waves (6-8) of the default budget curve ramp up instead of flattening, and
-- late-game templates mix in low-tier "filler" enemies capped to a share of each wave's budget.

local BattleIndex = require("Game.Spawning.BattleIndex")
local BattleTemplate = require("Game.Spawning.BattleTemplate")
local BattleDirector = require("Game.Spawning.BattleDirector")
local WaveDirector = require("Game.Spawning.WaveDirector")
local EnemyRegistry = require("Game.Spawning.EnemyRegistry")

print("--- STARTING LATE WAVE AND FILLER VERIFICATION ---")

-- 1. Waves 1-5 keep their budgets; waves 6-8 accelerate
local budgets = BattleIndex.DEFAULT_BUDGETS
local expected = { 34, 45, 65, 101, 152, 221, 326, 470 }
for wave, value in ipairs(expected) do
    assert(budgets[wave] == value, string.format("Wave %d budget should be %d, got %s", wave, value, tostring(budgets[wave])))
end
for wave = 6, 8 do
    local step = budgets[wave] - budgets[wave - 1]
    local prevStep = budgets[wave - 1] - budgets[wave - 2]
    assert(step > prevStep, string.format("Wave %d step (%d) should exceed wave %d step (%d)", wave, step, wave - 1, prevStep))
end
print("[PASS] Waves 6-8 ramp harder while waves 1-5 are unchanged.")

-- 2. Tier limit parsing shared by danger and filler tiers
local limits = BattleTemplate.parseTierLimits({ tier0min = 1, tier0max = 2, tier2min = 1 })
assert(limits[0].min == 1 and limits[0].max == 2, "tier0 limits should parse to 1-2")
assert(limits[2].min == 1 and limits[2].max == 1, "tier2 max should default to its min")
assert(BattleTemplate.parseTierLimits({ tier0min = 1 }, 2)[2], "Offset should shift tier numbers (testing mode)")
print("[PASS] parseTierLimits reads min/max keys.")

-- 3. Every late-game template can field tier 0-1 enemies
for id, template in pairs(BattleIndex) do
    if type(template) == "table" and template.minimumLevel and template.minimumLevel >= 14 then
        local danger = BattleTemplate.parseTierLimits(template.battleDangerTiers)
        local filler = BattleTemplate.parseTierLimits(template.fillerTiers)
        assert(danger[0] or danger[1] or filler[0] or filler[1], id .. " should allow tier 0 or 1 enemies")
    end
end
print("[PASS] All late-game templates include low-tier enemies.")

-- 4. Roster picks discovered filler enemies
_G.PersistentState = { battlesCompleted = 15, discoveredEnemies = { Grunt = true, Captain = true, Medic = true } }
local lateTemplate = BattleTemplate:new({
    id = "test_late",
    battleDangerTiers = { tier2min = 1, tier2max = 1 },
    fillerTiers = { tier0min = 1, tier0max = 1 },
    budgets = { 500 }
})
local bd = BattleDirector:new({})
local roster = bd:buildBattleRoster(lateTemplate)
local tierCounts = {}
for _, e in ipairs(roster) do tierCounts[e.tier] = (tierCounts[e.tier] or 0) + 1 end
assert(tierCounts[2] == 1, "Roster should have exactly one tier 2 enemy")
assert(tierCounts[0] == 1, "Roster should have exactly one tier 0 filler")
for _, e in ipairs(roster) do
    if e.tier == 0 then assert(e.id == "Grunt", "Filler should be the only discovered tier 0 enemy, got " .. e.id) end
end
print("[PASS] Roster adds discovered filler enemies.")

-- 5. Fillers spawn but stay within their budget share
local function find(id)
    for _, e in ipairs(EnemyRegistry.allEnemies) do if e.id == id then return e end end
end
local grunt, captain = find("Grunt"), find("Captain")
local wd = WaveDirector:new({})
for _ = 1, 50 do
    local _, summary = wd:generateWaveList(1, { captain, grunt }, lateTemplate, 500, false, 1)
    local fillerSpend, coreSpend = 0, 0
    for _, s in ipairs(summary) do
        if s.id == "Grunt" then fillerSpend = fillerSpend + s.count * s.spawnCost
        else coreSpend = coreSpend + s.count * s.spawnCost end
    end
    assert(fillerSpend > 0, "Filler enemies should spawn in a late wave")
    assert(fillerSpend <= 500 * WaveDirector.FILLER_BUDGET_SHARE, "Filler spend " .. fillerSpend .. " exceeds its share")
    assert(coreSpend >= 500 * (1 - WaveDirector.FILLER_BUDGET_SHARE) - captain.spawnCost, "Core enemies should use the rest of the budget")
end
print("[PASS] Fillers spawn within their budget share.")

-- 6. Templates without fillerTiers spend the whole budget on the roster as before
local plain = BattleTemplate:new({ id = "test_plain", battleDangerTiers = { tier0min = 1 } })
local _, summary = wd:generateWaveList(1, { grunt }, plain, 100, false, 1)
assert(summary[1].count == 10, "Plain template should spend the full budget on its roster")
print("[PASS] Templates without fillers are unchanged.")

print("--- ALL LATE WAVE AND FILLER TESTS PASSED ---")
