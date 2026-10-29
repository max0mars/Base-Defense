-- Testing/test_vanguard.lua
-- The Vanguard (tier 3, red): a frontal shield stops 75% of damage coming at
-- its front. Shots into its back or sides, area damage and damage over time get
-- through in full, and the shield is down while it's stunned or frozen.

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

local EnemyIndex = require("Game.Spawning.EnemyIndex")
local EnemyRegistry = require("Game.Spawning.EnemyRegistry")
local Vanguard = require("Enemies.Vanguard")
local Stun = require("Game.Effects.StatusEffects.Stun")
local Chill = require("Game.Effects.StatusEffects.Chill")
local EnemyDemo = require("Game.GUI.EnemyDemo")
local game = require("Game.Core.GameManager")

_G.PersistentState = {
    selectedMainTurret = "MainLazer",
    battlesCompleted = 0,
    globalDifficulty = 1,
    discoveredEnemies = { Grunt = true },
    startingTokens = 3,
}
game:load(nil, false)

local function entry(id)
    for _, e in ipairs(EnemyIndex) do if e.id == id then return e end end
end
local function spawn(id, x, y)
    for _, e in ipairs(EnemyRegistry.allEnemies) do
        if e.id == id then
            local obj = e.class:new({ game = game, x = x, y = y })
            game:addObject(obj)
            return obj
        end
    end
end
-- A bullet travelling at `angle` (0 = rightward, toward the field from the base)
local function bullet(angle)
    return { angle = angle, x = 0, y = 0, isType = function(_, t) return t == "bullet" end }
end
-- HP lost to one hit
local function hit(v, amount, damageType, tags, source)
    local before = v.hp
    v:takeDamage(amount, damageType or "physical", nil, nil, tags, source)
    local lost = before - v.hp
    v.hp = v.maxHp
    return lost
end
local function near(a, b) return math.abs(a - b) < 1e-6 end

-- 1. Its entry
local info = entry("Vanguard")
assert(info and info.tier == 3 and info.types.red, "The Vanguard is a tier 3 red enemy")
assert(info and info.maxHp == 400, "It has 400 HP")
assert(info and info.speed < entry("Grunt").speed, "It moves slowly")

-- 2. The shield faces the way it walks (toward the base) and stops 75% from the front
local grid = game.battlefieldGrid
local v = spawn("Vanguard", grid.x + 500, grid.y + 200)
v.speed = 0
assert(v.facingX == -1 and v.facingY == 0, "It starts facing the base")
assert(near(hit(v, 100, "physical", nil, bullet(0)), 25), "A bullet into its front does 25% damage")
assert(near(hit(v, 100, "physical", nil, bullet(math.rad(30))), 25), "So does one coming in at an angle")
assert(near(hit(v, 100, "physical", nil, bullet(math.pi)), 100), "A bullet into its back does full damage")
assert(near(hit(v, 100, "physical", nil, bullet(math.pi / 2)), 100), "So does one straight into its side")
local turret = { x = v.x - 150, y = v.y }
assert(near(hit(v, 100, "energy", { "beam" }, turret), 25), "A beam from a turret in front is blocked too")
assert(near(hit(v, 100, "energy", nil, { x = v.x + 150, y = v.y }), 100), "but not from one behind it")

-- 3. Area damage, damage over time and true damage go around it
assert(near(hit(v, 100, "explosive", { "aoe" }, bullet(0)), 100), "Explosions do full damage")
assert(near(hit(v, 100, "poison", { "dot" }), 100), "Poison ticks do full damage")
assert(near(hit(v, 100, "fire", { "dot" }), 100), "Burn ticks do full damage")
assert(near(hit(v, 100, "trueDamage", nil, turret), 100), "True damage ignores the shield")
assert(near(hit(v, 100, "physical"), 100), "A hit with no known source isn't blocked")

-- 4. Stunned or frozen: the shield is down
v.effectManager:applyEffect(Stun:new({ duration = 0.5 }))
v.effectManager:update(0)
assert(not v:isShielded(), "Stunned, its shield is down")
assert(near(hit(v, 100, "physical", nil, bullet(0)), 100), "and frontal shots do full damage")
local function run(seconds) for _ = 1, math.floor(seconds / 0.05 + 0.5) do v:update(0.05) end end
run(0.6)
assert(v:getStat("stunned", 0) <= 0, "The stun wears off")
assert(not v:isShielded() and near(hit(v, 100, "physical", nil, bullet(0)), 100),
    "but the shield stays down a while longer, so frontal shots still land in full")
run(Vanguard.RECOVER_DELAY) -- (the stun ended partway through the 0.6s above)
assert(v.shieldState == "raising" and not v:isShielded(), "Then it starts raising (not blocking yet)")
run(Vanguard.RAISE_TIME + 0.1)
assert(v:isShielded(), "Once fully raised the shield is back")
assert(near(hit(v, 100, "physical", nil, bullet(0)), 25), "and blocks again")
local realIsFrozen = Chill.isFrozen
Chill.isFrozen = function(t) return t == v end
assert(not v:isShielded() and near(hit(v, 100, "physical", nil, bullet(0)), 100), "Frozen, its shield is down too")
Chill.isFrozen = realIsFrozen

-- 5. It turns its shield with the path
for _ = 1, 40 do
    v.y = v.y - 1 -- walking up the field
    v:update(0.05)
end
assert(v.facingY < -0.9, "Walking up, it faces up")
assert(near(hit(v, 100, "physical", nil, bullet(math.pi / 2)), 25), "so a shot coming down at it hits the shield")
assert(near(hit(v, 100, "physical", nil, bullet(0)), 100), "and a shot from the base hits its side")

-- 6. Codex demo: blocked shots, full-damage explosions, then full shots while stunned
local demo = EnemyDemo.new("Vanguard", { x = 0, y = 0, w = 600, h = 160 })
local seen, wentDown = {}, false
for _ = 1, 240 do
    demo:update(0.05)
    for _, t in ipairs(demo.texts) do seen[t.str] = true end
    if demo.star and not demo.star:isShielded() then wentDown = true end
end
assert(seen["5"], "Codex demo: shots into the shield do a quarter of their damage")
assert(seen["20"], "Codex demo: explosions and shots while it's stunned do full damage")
assert(wentDown, "Codex demo: it gets stunned and the shield drops")
assert(pcall(function() demo:draw() end), "Codex demo draws")

print(string.format("\n%d failure(s)", failures))
if failures > 0 then os.exit(1) end
