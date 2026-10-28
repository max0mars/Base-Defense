-- Testing/test_tier3_templates.lua
-- Templates can ask for tier 3 enemies before any exist: the tier 3 slots stay
-- empty and the wave budget goes to the template's other tiers. Once a tier 3
-- enemy exists, those templates field it.

package.path = package.path .. ";./?.lua"
local noop = function() end
_G.love = setmetatable({}, { __index = function() return setmetatable({}, { __index = function() return noop end }) end })

local failures = 0
local function assert(condition, message)
    if not condition then
        print("[FAIL] " .. message)
        failures = failures + 1
    else
        print("[PASS] " .. message)
    end
end

local realPrint = print
local function quiet(fn) print = noop; local a, b, c = fn(); print = realPrint; return a, b, c end

local BattleIndex = require("Game.Spawning.BattleIndex")
local BattleTemplate = require("Game.Spawning.BattleTemplate")
local BattleDirector = require("Game.Spawning.BattleDirector")
local WaveDirector = require("Game.Spawning.WaveDirector")
local EnemyRegistry = require("Game.Spawning.EnemyRegistry")

_G.PersistentState = { battlesCompleted = 19, discoveredEnemies = { Grunt = true } }
local bd = quiet(function() return BattleDirector:new({}) end)
for _, e in ipairs(EnemyRegistry.allEnemies) do quiet(function() EnemyRegistry:discoverEnemy(e.id) end) end

local function hasTier(id, tier)
    for _, e in ipairs(EnemyRegistry.allEnemies) do if e.id == id then return e.tier == tier end end
end

-- 1. Collect the templates that ask for tier 3
local tier3Templates = {}
for id, template in pairs(BattleIndex) do
    if type(template) == "table" and template.battleDangerTiers
        and BattleTemplate.parseTierLimits(template.battleDangerTiers)[3] then
        tier3Templates[#tier3Templates + 1] = id
    end
end
table.sort(tier3Templates)
assert(#tier3Templates >= 6, "There are tier 3 templates (" .. #tier3Templates .. ")")

local noTier3 = true
for _, e in ipairs(EnemyRegistry.allEnemies) do if e.tier == 3 then noTier3 = false end end
assert(noTier3, "No tier 3 enemies exist yet (this test covers the empty case first)")

-- 2. With no tier 3 enemies: no tier 3 in the roster, and every wave spends its budget elsewhere
local wd = WaveDirector:new({})
for _, id in ipairs(tier3Templates) do
    local template = BattleIndex[id]
    local okRoster, okSpend = true, true
    local danger = BattleTemplate.parseTierLimits(template.battleDangerTiers)
    local filler = BattleTemplate.parseTierLimits(template.fillerTiers)
    for _ = 1, 30 do
        local roster = bd:buildBattleRoster(template)
        -- Fillers stop at their capped share, so the leftover only has to be below the cheapest core enemy
        local cheapest, cheapestAny = math.huge, math.huge
        for _, e in ipairs(roster) do
            if e.tier == 3 then okRoster = false end
            cheapestAny = math.min(cheapestAny, e.spawnCost)
            if danger[e.tier] or not filler[e.tier] then cheapest = math.min(cheapest, e.spawnCost) end
        end
        if cheapest == math.huge then cheapest = cheapestAny end
        if #roster == 0 then okRoster = false end
        for wave = 1, 8 do
            local budget = bd:getBudgetForWave(template, wave, 20)
            local _, summary = quiet(function() return wd:generateWaveList(wave, roster, template, budget, false, 1) end)
            local spent = 0
            for _, s in ipairs(summary) do spent = spent + s.count * s.spawnCost end
            -- Everything that can be bought is bought (only change smaller than the cheapest enemy is left)
            if budget - spent >= cheapest then okSpend = false end
        end
    end
    assert(okRoster, id .. ": roster has no tier 3 and isn't empty")
    assert(okSpend, id .. ": the tier 3 share of the budget goes to the other tiers")
end

-- 3. A tier 3 template that has no other danger tier falls back fully onto its fillers
local juggernaut = BattleIndex.battle_late_juggernaut
local roster = bd:buildBattleRoster(juggernaut)
local lowOnly = #roster > 0
for _, e in ipairs(roster) do lowOnly = lowOnly and e.tier <= 1 end
assert(lowOnly, "Juggernaut without tier 3 fields only its tier 0-1 escort")
local _, summary = quiet(function() return wd:generateWaveList(8, roster, juggernaut, 500, false, 1) end)
local spent = 0
for _, s in ipairs(summary) do spent = spent + s.count * s.spawnCost end
assert(spent > 500 * WaveDirector.FILLER_BUDGET_SHARE, "and the escort gets the whole budget, not just the filler share")

-- 4. Once a tier 3 enemy exists, the templates field it
local heavy
for _, e in ipairs(EnemyRegistry.allEnemies) do
    if e.id == "Captain" then
        heavy = {}
        for k, v in pairs(e) do heavy[k] = v end
    end
end
heavy.id, heavy.type, heavy.tier, heavy.spawnCost = "TestHeavy", "TestHeavy", 3, 60
table.insert(EnemyRegistry.allEnemies, heavy)
quiet(function() EnemyRegistry:discoverEnemy("TestHeavy") end)

local fielded = true
for _, id in ipairs(tier3Templates) do
    local found = false
    for _, e in ipairs(bd:buildBattleRoster(BattleIndex[id])) do
        if e.tier == 3 then found = true end
    end
    fielded = fielded and found
end
assert(fielded, "Every tier 3 template puts the tier 3 enemy in its roster")

local _, heavySummary = quiet(function()
    return wd:generateWaveList(8, bd:buildBattleRoster(juggernaut), juggernaut, 500, false, 1)
end)
local heavyCount = 0
for _, s in ipairs(heavySummary) do if s.id == "TestHeavy" then heavyCount = s.count end end
assert(heavyCount > 0, "and it spawns in the waves")
assert(hasTier("Grunt", 0), "Sanity: registry lookups still work")

print(string.format("\n%d failure(s)", failures))
if failures > 0 then os.exit(1) end
