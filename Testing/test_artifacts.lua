-- Testing/test_artifacts.lua
-- Artifacts: persistent ownership, stat effects reaching turrets through the
-- player EffectManager, board-dependent effects re-evaluating, and event /
-- hooks (kills, enemy damage, base damage, tokens, wave end).

package.path = package.path .. ";./?.lua"

-- Mock love2d (every love.* function is a no-op; GameManager pulls in the whole game)
local noop = function() end
local fontStub = { getWidth = function() return 10 end, getHeight = function() return 10 end, getWrap = function() return 10, { "" } end }
_G.love = setmetatable({
    math = setmetatable({ random = math.random, colorFromBytes = function(...) return ... end }, { __index = function() return noop end }),
    timer = { getTime = function() return 0 end },
    graphics = setmetatable({
        getFont = function() return fontStub end,
        newFont = function() return fontStub end,
        newCanvas = function() return {} end,
        getWidth = function() return 1280 end,
        getHeight = function() return 720 end,
    }, { __index = function() return noop end }),
}, { __index = function() return setmetatable({}, { __index = function() return noop end }) end })
_G.VIRTUAL_WIDTH = 1280
_G.VIRTUAL_HEIGHT = 720
_G.SetGameScissor = noop
math.atan2 = math.atan2 or math.atan

local failures = 0
local function assert(condition, message)
    if not condition then
        print("[FAIL] " .. message)
        failures = failures + 1
    else
        print("[PASS] " .. message)
    end
end
local function near(a, b) return math.abs(a - b) < 1e-6 end

local ArtifactIndex = require("Game.Artifacts.ArtifactIndex")
local ArtifactManager = require("Game.Artifacts.ArtifactManager")
local TurretIndex = require("Buildings.TurretIndex")
local Enemy = require("Enemies.Enemy")
local game = require("Game.Core.GameManager")

-- 1. Definitions are well formed
for _, def in ipairs(ArtifactIndex.list) do
    local ok = def.id and def.name and def.description and def.color and def.icon and def.rarity == nil
    assert(ok, "Artifact '" .. tostring(def.id) .. "' has id, name, description, color and icon (and no rarity)")
end

-- 2. Persistent ownership
_G.PersistentState = {}
assert(#ArtifactManager.getOwnedIds() == 0, "A new run owns no artifacts")
assert(ArtifactManager.grant("arms_race"), "Granting an artifact succeeds")
assert(ArtifactManager.owns("arms_race"), "Granted artifact is owned")
assert(not ArtifactManager.grant("arms_race"), "Artifacts are unique: granting a duplicate fails")
assert(#_G.PersistentState.artifacts == 1, "Ownership is stored in PersistentState.artifacts")
assert(ArtifactManager.remove("arms_race") and not ArtifactManager.owns("arms_race"), "Removing an artifact works")
assert(not pcall(ArtifactManager.grant, "not_a_real_artifact"), "Granting an unknown id is a developer error")
for _ = 1, #ArtifactIndex.list do ArtifactManager.grantRandom() end
assert(#ArtifactManager.getOwnedIds() == #ArtifactIndex.list, "grantRandom eventually grants every artifact, once each")
assert(ArtifactManager.grantRandom() == nil, "grantRandom returns nil when everything is owned")

-- Helpers for a loaded game ----------------------------------------------------
local function loadGame(artifactIds)
    _G.PersistentState = {
        selectedMainTurret = "MainLazer",
        battlesCompleted = 0,
        globalDifficulty = 1,
        discoveredEnemies = { Grunt = true },
        startingTokens = 3,
        artifacts = artifactIds,
    }
    game:load(nil, false)
    return game
end

local function findEntry(id)
    for _, rarity in pairs(TurretIndex) do
        if type(rarity) == "table" then
            for _, e in ipairs(rarity) do
                if e.id == id then return e end
            end
        end
    end
end

--- Places a building from an index entry on the first slot it can legally occupy.
local function placeEntry(entry)
    local c = {}
    for k, v in pairs(entry) do c[k] = v end
    c.game = game
    local b = entry.building:new(c)
    local grid = game.base.buildGrid
    for slot = 1, grid.width * grid.height do
        if game.base:areSlotsAvailable(b, b:getSlotsFromPattern(slot), slot) then
            game:newBuilding(b, slot)
            return b
        end
    end
    error("No free slot for " .. tostring(entry.id))
end

local function placeTurret(id) return placeEntry(findEntry(id)) end

local function makeEnemy(hp)
    local e = Enemy:new({ game = game, x = 400, y = 300, size = 20, maxHp = hp, hp = hp })
    game:addObject(e)
    return e
end

-- 3. No artifacts: nothing changes
loadGame({})
local plainBlaster = placeTurret("blaster")
assert(near(plainBlaster:getStat("fireRate"), plainBlaster.fireRate), "Without artifacts, turret stats are unmodified")
assert(game:getMaxTokens() == 3, "Without artifacts, max tokens are unchanged")

-- 4. Static damage-type effects reach matching turrets only
loadGame({ "overclocked_capacitor", "prismatic_core", "buckshot_choke", "volatile_payload" })
local blaster = placeTurret("blaster")
local sentry = placeTurret("sentry")
local shotgun = placeTurret("shotgunTurret")
local grenadier = placeTurret("grenadier")
assert(near(blaster:getStat("fireRate"), blaster.fireRate * 1.3), "Overclocked Capacitor: energy turret fires 30% faster")
assert(near(sentry:getStat("fireRate"), sentry.fireRate), "Overclocked Capacitor: physical turret is unaffected")
assert(shotgun:getStat("pelletCount") == shotgun.pelletCount + 5, "Buckshot Choke: shotgun fires 5 extra pellets")
assert(sentry:getStat("pelletCount") == sentry.pelletCount, "Buckshot Choke: non-shotgun turret is unaffected")
assert(grenadier.radius > 0 and near(grenadier:getStat("radius"), grenadier.radius * 1.4), "Volatile Payload: explosive blasts are 40% larger")
assert(near(grenadier:getStat("damage"), grenadier.damage * 1.15), "Volatile Payload: explosive turret deals 15% more damage")
assert(near(sentry:getStat("damage"), sentry.damage), "Volatile Payload: non-explosive turret is unaffected")
-- The default main turret (Heavy Laser) is energy, so Overclocked Capacitor stacks additively on it
local main = game.mainLazer
assert(near(main:getStat("damage"), main.damage * 1.4), "Prismatic Core: main turret deals 40% more damage")
assert(near(main:getStat("fireRate"), main.fireRate * 1.5), "Prismatic Core + Overclocked Capacitor stack additively on an energy main turret (+50%)")

loadGame({ "prismatic_core" })
main = game.mainLazer
assert(near(main:getStat("fireRate"), main.fireRate * 1.2), "Prismatic Core: main turret fires 20% faster")
loadGame({ "overclocked_capacitor", "prismatic_core", "buckshot_choke", "volatile_payload" })
blaster = placeTurret("blaster")

-- Effects survive the pre-wave buff recalculation and wave completion
game:recalculateAllBuffs()
game:waveComplete()
assert(near(blaster:getStat("fireRate"), blaster.fireRate * 1.3), "Artifact effects persist through buff recalculation and wave end")

-- Each battle starts clean: artifacts aren't applied twice on reload
loadGame({ "overclocked_capacitor" })
local blaster2 = placeTurret("blaster")
assert(near(blaster2:getStat("fireRate"), blaster2.fireRate * 1.3), "Reloading a battle applies each artifact exactly once")

-- 5. Board-dependent effects re-evaluate when buildings change
loadGame({ "arms_race" })
main = game.mainLazer
assert(main.damageType == "energy", "Default main turret (Heavy Laser) is energy")
assert(near(main:getStat("damage"), main.damage * 1.06), "Arms Race: the main turret's damage type counts on its own (+6%)")
local s1 = placeTurret("sentry")
assert(near(s1:getStat("damage"), s1.damage * 1.12), "Arms Race: main turret (energy) + physical = +12%")
placeTurret("sentry")
assert(near(s1:getStat("damage"), s1.damage * 1.12), "Arms Race: a second turret of the same type adds nothing")
local b1 = placeTurret("blaster")
assert(near(s1:getStat("damage"), s1.damage * 1.12), "Arms Race: an energy turret adds nothing when the main turret is already energy")
local p1 = placeTurret("poisonTurret")
assert(near(b1:getStat("damage"), b1.damage * 1.18), "Arms Race: three damage types = +18% on every turret")
assert(near(main:getStat("damage"), main.damage * 1.18), "Arms Race: the main turret gets the bonus too")
p1:remove()
game:takeOutTheTrash()
assert(near(s1:getStat("damage"), s1.damage * 1.12), "Arms Race: removing a turret lowers the bonus again")

loadGame({ "specialist_doctrine" })
local a, b, c = placeTurret("sentry"), placeTurret("sentry"), placeTurret("blaster")
assert(near(a:getStat("damage"), a.damage * 1.10), "Specialist Doctrine: 2 physical turrets = +10% for physical")
assert(near(c:getStat("damage"), c.damage), "Specialist Doctrine: off-type turrets get nothing")

-- 6. Engine hooks (no shipped artifact uses these yet; exercised with a test-only one)
local probe = {
    id = "test_probe", name = "Test Probe", icon = "star", color = {1, 1, 1, 1},
    description = "Test only.",
    modifyMaxTokens = function(self, game, max) return max + 2 end,
    modifyBaseDamage = function(self, game, amount) return amount * 0.5 end,
    modifyEnemyDamage = function(self, game, amount) return amount * 2 end,
    onEnemyKilled = function(self, game, enemy, killingBlow)
        self.state.kills = (self.state.kills or 0) + 1
        self.state.lastType = killingBlow and killingBlow.damageType
    end,
    onWaveComplete = function(self) self.state.waves = (self.state.waves or 0) + 1 end,
}
ArtifactIndex.byId[probe.id] = probe
loadGame({ "test_probe" })
local state = game.artifacts.artifacts[1].state
assert(game:getMaxTokens() == 5, "modifyMaxTokens adjusts the token cap")
local hp0 = game.base.hp
game.base:takeDamage(40, "physical")
assert(near(hp0 - game.base.hp, 20), "modifyBaseDamage adjusts damage to the base")
local tough = makeEnemy(1000)
tough:takeDamage(100, "physical")
assert(near(1000 - tough.hp, 200), "modifyEnemyDamage adjusts damage to enemies")
makeEnemy(10):takeDamage(50, "explosive")
assert(state.kills == 1 and state.lastType == "explosive", "onEnemyKilled fires with the killing blow")
local leaker = makeEnemy(10)
leaker.reachedBase = true
leaker:died()
assert(state.kills == 1, "onEnemyKilled skips enemies that reached the base")
game:waveComplete()
assert(state.waves == 1, "onWaveComplete fires")
ArtifactIndex.byId[probe.id] = nil

-- 7. Every artifact survives a full lifecycle without errors
local allIds = {}
for _, def in ipairs(ArtifactIndex.list) do table.insert(allIds, def.id) end
local ok, err = pcall(function()
    loadGame(allIds)
    placeTurret("sentry"); placeTurret("grenadier"); placeTurret("poisonTurret")
    game.artifacts:trigger("onWaveStart")
    local e = makeEnemy(50)
    e:takeDamage(100, "explosive", nil, nil, nil, nil)
    game.base:takeDamage(10, "physical")
    game:waveComplete()
end)
assert(ok, "All artifacts together survive battle start, kills, base damage and wave end" .. (ok and "" or (": " .. tostring(err))))

print(string.format("\n%d failure(s)", failures))
if failures > 0 then os.exit(1) end
