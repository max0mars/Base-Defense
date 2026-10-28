-- Testing/test_phantom.lua
-- The Phantom (tier 3, yellow) blinks 15-35% of the battlefield's height up or
-- down when hit. First it's wiped away left to right (still hittable), then it's
-- invisible and untargetable for 0.5s, and its 1.5s cooldown starts when it
-- reappears. It holds still throughout.

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
local Phantom = require("Enemies.Phantom")
local Stun = require("Game.Effects.StatusEffects.Stun")
local TurretIndex = require("Buildings.TurretIndex")
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
local function run(e, seconds)
    for _ = 1, math.floor(seconds / 0.05 + 0.5) do e:update(0.05) end
end
--- Runs through the wipe, until it's gone (or the wipe never started).
local function finishVanish(e)
    for _ = 1, 100 do
        if not e.vanishTime then return end
        e:update(0.01)
    end
end

local grid = game.battlefieldGrid
local fieldH = grid.height * grid.cellSize
local top, bottom = grid.y + grid.cellSize, grid.y + fieldH - grid.cellSize

-- 1. Its entry
local info = entry("Phantom")
assert(info and info.tier == 3 and info.types.yellow, "The Phantom is a tier 3 yellow enemy")
assert(info and info.maxHp == 150, "It has 150 HP")
assert(info and info.speed > entry("Scout").speed / 2 and info.speed > entry("Grunt").speed * 2, "It moves fast")
assert(info and info.shape == "arrow" and info.size > entry("Grunt").size, "It's a large arrow")

-- 2. A hit starts the wipe: it holds still and can still be hit
local cx, cy = grid.x + fieldH, grid.y + fieldH / 2
local p = spawn("Phantom", cx, cy)
p.speed = info.speed
p:takeDamage(10, "ballistic")
assert(p.vanishTime ~= nil and not p.untargetable and p:isType("enemy"), "A hit starts it vanishing; it's still targetable")
run(p, Phantom.VANISH_TIME * 0.5)
assert(p.x == cx and p.y == cy and p.vanishTime ~= nil, "Halfway through the wipe it hasn't moved")
p:takeDamage(10, "ballistic")
assert(math.abs(p.hp - 130) < 1e-6, "Hits during the wipe still land")
assert(p.vanishTime ~= nil and not p.blinkTime, "and don't restart or skip the wipe")
assert(pcall(function() p:drawAnimated() end) and SetGameScissor == noop, "The wipe draws and puts SetGameScissor back")

-- Then it's gone: moved 15-35% of the field's height, invisible and untargetable
finishVanish(p)
p.speed = 0 -- hold it in place
local dy = math.abs(p.y - cy)
assert(p.blinkTime ~= nil and p.untargetable, "After the wipe it's gone")
assert(dy >= fieldH * 0.15 - 1e-6 and dy <= fieldH * 0.35 + 1e-6,
    string.format("It moves %.0f px: between 15%% and 35%% of the field's %d px height", dy, fieldH))
assert(math.abs(p.hp - 130) < 1e-6, "The hits that triggered it still landed")
assert(not p:isType("enemy"), "While blinking it doesn't count as an enemy (nothing can target it)")

local sentry
for _, list in pairs(TurretIndex) do
    for _, e in ipairs(list) do if e.id == "sentry" then sentry = e end end
end
local cfg = {}
for k, v in pairs(sentry) do cfg[k] = v end
cfg.game, cfg.x, cfg.y = game, p.x - 50, p.y
local turret = sentry.building:new(cfg)
turret.target = p
turret:getTarget()
assert(turret.target ~= p, "A turret drops it as a target when it blinks out")
assert(not turret:isInFiringArc(p), "and won't pick it up while it's gone")

local hp = p.hp
p:takeDamage(50, "explosive", nil, nil, { "aoe" })
assert(p.hp == hp, "Damage can't reach it while it's blinking")

-- 3. Reappears after 0.5s, without having moved; the 1.5s cooldown only starts then
p.speed = info.speed
local blinkX, blinkY = p.x, p.y
run(p, Phantom.BLINK_TIME - 0.1)
assert(p.untargetable, "Still gone just before 0.5s")
assert(p.x == blinkX and p.y == blinkY, "It doesn't move forward while blinking")
p.speed = 0
run(p, 0.2)
assert(not p.untargetable and not p.blinkTime and p:isType("enemy"), "It reappears after 0.5s, targetable again")
local y = p.y
p:takeDamage(10, "ballistic")
assert(p.y == y and not p.blinkTime, "Hit straight after reappearing: no blink (cooldown)")
run(p, Phantom.BLINK_COOLDOWN - 0.2)
p:takeDamage(10, "ballistic")
assert(not p.blinkTime, "Still on cooldown just before 1.5s")
run(p, 0.3)
p:takeDamage(10, "ballistic")
assert(p.vanishTime ~= nil, "It blinks again 1.5s after reappearing")
finishVanish(p)
run(p, Phantom.BLINK_TIME + 0.1)
run(p, Phantom.BLINK_COOLDOWN + 0.1)

-- 4. Damage over time doesn't make it blink, and it can't while stunned
p:takeDamage(5, "poison", nil, nil, { "dot" })
assert(not p:isBlinking(), "Damage over time doesn't trigger a blink")
p.effectManager:applyEffect(Stun:new({ duration = 0.5 }))
p.effectManager:update(0)
p:takeDamage(10, "ballistic")
assert(not p:isBlinking(), "It can't blink while stunned")
run(p, 0.6)
p:takeDamage(10, "ballistic")
assert(p.vanishTime ~= nil, "It can once the stun wears off")
finishVanish(p)
run(p, Phantom.BLINK_TIME + 0.1)

-- 5. Always stays on the field: near an edge it blinks the other way
local inBounds, awayFromTop, inRange = true, true, true
for _ = 1, 200 do
    for _, fromY in ipairs({ top + 5, bottom - 5, (top + bottom) / 2 }) do
        local toY = Phantom.pickBlinkY(fromY, top, bottom, fieldH)
        local d = math.abs(toY - fromY)
        inBounds = inBounds and toY >= top and toY <= bottom
        inRange = inRange and d >= fieldH * 0.15 - 1e-6 and d <= fieldH * 0.35 + 1e-6
        if fromY == top + 5 then awayFromTop = awayFromTop and toY > fromY end
    end
end
assert(inBounds, "Blinks always land on the field")
assert(awayFromTop, "Near the top it always blinks down")
assert(inRange, "Every blink is 15-35% of the field's height")

-- 6. A blinking Phantom still counts as alive (the wave doesn't end without it)
run(p, Phantom.BLINK_COOLDOWN + 0.1)
p:takeDamage(10, "ballistic")
finishVanish(p)
assert(p.untargetable and not p.destroyed, "Blinking again")
local alive = 0
for _, obj in ipairs(game.objects) do
    if (obj:isType("enemy") or obj.untargetable) and not obj.destroyed then alive = alive + 1 end
end
assert(alive >= 1, "Wave completion still sees it")

-- 7. Codex demo: the turret hits it and it blinks out and back
local demo = EnemyDemo.new("Phantom", { x = 0, y = 0, w = 600, h = 160 })
local blinked, reappeared = false, false
for _ = 1, 160 do
    demo:update(0.05)
    local s = demo.star
    if s.blinkTime then blinked = true elseif blinked and not s.vanishTime and not s.demoDead then reappeared = true end
end
assert(blinked and reappeared, "Codex demo: it blinks away and reappears")
assert(pcall(function() demo:draw() end), "Codex demo draws")

print(string.format("\n%d failure(s)", failures))
if failures > 0 then os.exit(1) end
