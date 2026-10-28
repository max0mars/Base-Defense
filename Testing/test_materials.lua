-- Testing/test_materials.lua
-- Typed upgrade materials: turret -> material mapping, per-material costs,
-- Universal Essence covering shortfalls, battle rewards, starting stock and
-- per-stat tier scaling.

package.path = package.path .. ";./?.lua"

local noop = function() end
_G.love = setmetatable({
    math = setmetatable({ random = math.random }, { __index = function() return noop end }),
    timer = { getTime = function() return 0 end },
}, { __index = function() return setmetatable({}, { __index = function() return noop end }) end })
_G.VIRTUAL_WIDTH = 1280
_G.VIRTUAL_HEIGHT = 720

local failures = 0
local function assert(condition, message)
    if not condition then
        print("[FAIL] " .. message)
        failures = failures + 1
    else
        print("[PASS] " .. message)
    end
end

local MaterialRegistry = require("Game.Cards.MaterialRegistry")
local CardUpgradeConfig = require("Game.Cards.CardUpgradeConfig")
local BattleManager = require("Game.Core.BattleManager")
local TurretIndex = require("Buildings.TurretIndex")
local Card = require("Game.Cards.Card")
local ExecutionType = require("Game.Cards.ExecutionType")
local Economy = CardUpgradeConfig.Economy

local function reset(materials, cash)
    _G.PersistentState = { cash = cash or 0, materials = materials or {} }
end

local function findTurret(id)
    for _, rarity in ipairs({ "common", "uncommon", "rare", "epic", "legendary" }) do
        for _, e in ipairs(TurretIndex[rarity] or {}) do
            if e.id == id then return e end
        end
    end
end

-- 1. Every current turret maps to the agreed material
local expected = {
    sentry = "scrap", autoCannon = "scrap", shotgunTurret = "scrap", heavygun = "scrap",
    airburst = "scrap", gator = "scrap", sequenceTurret = "scrap", hookTurret = "scrap", sniper = "scrap", heavyShotgun = "scrap",
    blaster = "energy_cells", fluxCannon = "energy_cells", plasmaScattershot = "energy_cells", chainLaser = "energy_cells",
    grenadier = "blast_powder", missileLauncher = "blast_powder", mortar = "blast_powder",
    poisonTurret = "elemental_essence", slushCannon = "elemental_essence", iceShard = "elemental_essence",
    frostCannon = "elemental_essence", cryoBeam = "elemental_essence",
    icicleBallista = "elemental_essence", glacialMonolith = "elemental_essence",
}
for id, mat in pairs(expected) do
    local got = MaterialRegistry.resolve(findTurret(id))
    assert(got == mat, string.format("%s uses %s (got %s)", id, mat, tostring(got)))
end
local count = 0
for _, rarity in ipairs({ "common", "uncommon", "rare", "epic", "legendary" }) do
    count = count + #(TurretIndex[rarity] or {})
end
local covered = 0
for _ in pairs(expected) do covered = covered + 1 end
assert(covered == count, string.format("Mapping covers every turret in the index (%d/%d)", covered, count))

-- 2. Modularity: explicit override and set-style types
assert(MaterialRegistry.resolve({ types = {"turret"}, upgradeMaterial = "blast_powder" }) == "blast_powder",
    "Explicit upgradeMaterial overrides type matching")
assert(MaterialRegistry.resolve({ types = { turret = true, energy = true } }) == "energy_cells",
    "Set-style types ({energy = true}) are matched")
assert(MaterialRegistry.resolve({ damageType = "fire" }) == "elemental_essence", "Fire damage maps to Elemental Dust")
assert(MaterialRegistry.resolve(nil) == "scrap", "Unknown turrets fall back to Scrap")

table.insert(MaterialRegistry.list, 1, { id = "test_cryo", name = "Cryo Cores", match = { types = {"cryo"} } })
assert(MaterialRegistry.resolve({ types = {"turret", "cryo"} }) == "test_cryo",
    "A new registry entry is picked up by its match rule")
table.remove(MaterialRegistry.list, 1)

-- 3. Starting materials match the main turret
local MainLazer = require("Buildings.MainTurrets.MainLazer")
local FastMainTurret = require("Buildings.MainTurrets.FastMainTurret")
assert(MaterialRegistry.resolve(MainLazer.template) == "energy_cells", "Main Lazer run starts with Energy Cells")
assert(MaterialRegistry.resolve(FastMainTurret.template) == "scrap", "Fast Main Turret run starts with Scrap")
assert(MaterialRegistry.STARTING_AMOUNT == 2, "A run starts with 2 of that material")

-- 4. Cards cost their own material at the agreed amounts
local function cardFor(id, tier)
    local e = findTurret(id)
    return Card:new({ id = id, name = e.name, executionType = ExecutionType.Placement, tier = tier or 1,
        payload = { buildingClass = e.building, config = e } })
end
local costs = { { 30, 1 }, { 75, 2 }, { 250, 4 }, { 600, 7 } }
for i, c in ipairs(costs) do
    local cost = cardFor("blaster", i):getNextUpgradeCost()
    assert(cost.gold == c[1] and cost.energy_cells == c[2] and cost.material == nil,
        string.format("Blaster tier %d -> %d costs $%d + %d Energy Cells", i, i + 1, c[1], c[2]))
end
assert(cardFor("mortar"):getNextUpgradeCost().blast_powder == 1, "Mortar upgrades with Blast Powder")
-- Card without payload type info falls back to its reward index entry
local bare = Card:new({ id = "grenadier", name = "Grenadier", executionType = ExecutionType.Placement })
assert(bare:getNextUpgradeCost().blast_powder == 1, "Bare card resolves its material from the reward index")

-- 5. Universal Essence covers shortfalls of typed materials only
reset({ energy_cells = 2, universal_essence = 5 }, 1000)
local plan = Economy.planSpend({ gold = 250, energy_cells = 4 })
assert(plan and plan.energy_cells == 2 and plan.universal_essence == 2, "Typed material spent first, Universal covers the rest")
assert(Economy.deduct({ gold = 250, energy_cells = 4 }), "Deduct succeeds with Universal covering the shortfall")
assert(Economy.getResource("energy_cells") == 0 and Economy.getResource("universal_essence") == 3 and Economy.getResource("cash") == 750,
    "Deduct spends 2 Cells, 2 Universal and the gold")

reset({ energy_cells = 4, universal_essence = 5 }, 1000)
Economy.deduct({ gold = 250, energy_cells = 4 })
assert(Economy.getResource("universal_essence") == 5, "Universal is untouched when typed material is enough")

reset({ universal_essence = 1 }, 1000)
assert(not Economy.canAfford({ gold = 250, energy_cells = 4 }), "Not enough Universal to cover the shortfall: can't afford")
reset({ universal_essence = 10 }, 100)
assert(not Economy.canAfford({ gold = 250, energy_cells = 1 }), "Universal never covers gold")
reset({ universal_essence = 10, ["Card Removal"] = 0 }, 1000)
assert(not Economy.canAfford({ ["Card Removal"] = 1 }), "Universal never covers non-material resources")

-- 6. Upgrading a real card spends its material
reset({ blast_powder = 1 }, 100)
local mortar = cardFor("mortar")
assert(mortar:upgrade(nil), "Mortar upgrades to tier II with 1 Blast Powder + $30")
assert(Economy.getResource("blast_powder") == 0 and Economy.getResource("cash") == 70, "Blast Powder and gold were spent")

-- 7. Battle rewards roll a specific material, Universal rarely and singly
math.randomseed(1234)
local seen, universal, total = {}, 0, 20000
for _ = 1, total do
    local id = BattleManager.rollMaterial()
    seen[id] = (seen[id] or 0) + 1
    if id == MaterialRegistry.UNIVERSAL then universal = universal + 1 end
end
for _, mat in ipairs(MaterialRegistry.getTyped()) do
    assert((seen[mat.id] or 0) > universal, string.format("%s is more common than Universal (%d vs %d)", mat.name, seen[mat.id] or 0, universal))
end
local share = universal / total
assert(share > 0.07 and share < 0.13, string.format("Universal is ~10%% of material rolls (%.1f%%)", share * 100))

local materialRewards, universalRewards = 0, 0
for _ = 1, 3000 do
    for _, r in ipairs(BattleManager:new():generateRewards(2.0, 10)) do
        if r.type == BattleManager.REWARD_TYPES.UPGRADE_MATERIAL then
            materialRewards = materialRewards + 1
            if not MaterialRegistry.isMaterial(r.materialId) then
                assert(false, "Material reward has a real material id: " .. tostring(r.materialId))
            end
            if r.description ~= string.format("+%d %s", r.amount, MaterialRegistry.getName(r.materialId)) then
                assert(false, "Material reward preview names the material: " .. tostring(r.description))
            end
            if r.materialId == MaterialRegistry.UNIVERSAL then
                universalRewards = universalRewards + 1
                if r.amount ~= 1 then assert(false, "Universal Essence is awarded singly") end
            end
        end
    end
end
assert(materialRewards > 0 and universalRewards > 0, string.format("Battles award typed and Universal materials (%d / %d)", materialRewards, universalRewards))

-- 8. Per-stat tier scaling: +20% damage, +10% fire rate, +15% range per tier
local function near(a, b) return math.abs(a - b) < 1e-9 end
assert(near(CardUpgradeConfig.getTierMultiplier("damage", 5), 1.8), "Tier V damage x1.8")
assert(near(CardUpgradeConfig.getTierMultiplier("fireRate", 5), 1.4), "Tier V fire rate x1.4")
assert(near(CardUpgradeConfig.getTierMultiplier("range", 5), 1.6), "Tier V range x1.6")
assert(near(CardUpgradeConfig.getTierMultiplier("damage", 1), 1.0), "Tier I is unscaled")

if failures > 0 then
    print(failures .. " test(s) failed")
    os.exit(1)
end
print("All material tests passed")
