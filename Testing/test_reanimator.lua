-- Testing/test_reanimator.lua
-- The Reanimator (tier 3, green) raises up to 5 enemies that died near it every
-- 10 seconds, as zombies: same enemy, half health, and they can't be healed.
-- It channels (rising and shaking), then slams the ground to raise them; a stun
-- or freeze during the channel cancels the cast and restarts its cooldown.

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
local Reanimator = require("Enemies.Reanimator")
local Zombie = require("Enemies.Zombie")
local EnemyDemo = require("Game.GUI.EnemyDemo")
local Stun = require("Game.Effects.StatusEffects.Stun")
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
local function kill(e) e:takeDamage(1e6, "energy") end
local function zombies()
    local list = {}
    for _, obj in ipairs(game.objects) do
        if obj.isZombie and not obj.destroyed then table.insert(list, obj) end
    end
    return list
end
local function run(e, seconds)
    for _ = 1, math.floor(seconds / 0.05 + 0.5) do e:update(0.05) end
end

-- 1. Its entry
local info = entry("Reanimator")
assert(info and info.tier == 3 and info.types.green, "The Reanimator is a tier 3 green enemy")
assert(info and info.maxHp == 250, "It has 250 HP")
assert(info and info.speed < entry("Grunt").speed, "It moves slower than average (a Grunt)")
assert(info and info.shape == "diamond" and Reanimator.WIDTH_RATIO < 1, "It's a diamond, narrower than it is tall")

-- 2. Enemies that die near it leave corpses; it raises up to 5, strongest first
local cx, cy = game.base.x + 500, game.base.y + game.base.h / 2
local rean = spawn("Reanimator", cx, cy)
rean.speed = 0 -- hold it in place for the test
local soldier = spawn("Soldier", cx - 40, cy)
for i = 1, 6 do kill(spawn("Grunt", cx - 20 + i * 8, cy + 20)) end
kill(soldier)
kill(spawn("Grunt", cx + Reanimator.REVIVE_RADIUS + 60, cy)) -- too far away
assert(#game.corpses == 8, "Every death leaves a corpse (" .. #game.corpses .. ")")

local CAST = Reanimator.CHANNEL_TIME + Reanimator.SLAM_TIME
run(rean, Reanimator.REVIVE_COOLDOWN - 0.2)
assert(#zombies() == 0 and not rean.phase, "It spawns with its full cooldown: nothing happens before then")
run(rean, 0.4)
assert(rean.phase == "channel" and #zombies() == 0, "Once ready it starts channelling (nothing raised yet)")
assert(rean:isHalted(), "It stands still while channelling")
run(rean, Reanimator.CHANNEL_TIME * 0.5)
assert(rean:getLift() > 0, "It rises off the ground as it channels")
run(rean, Reanimator.CHANNEL_TIME - rean.phaseTime + 0.03)
assert(rean.phase == "slam" and #zombies() == 0, "Then it slams down")
run(rean, Reanimator.SLAM_TIME + 0.1)
local raised = zombies()
assert(not rean.phase and rean:getLift() == 0, "The slam lands and it's back on the ground")
assert(#raised == Reanimator.MAX_REVIVES, "It raises " .. Reanimator.MAX_REVIVES .. " at once (" .. #raised .. ")")
local gotSoldier, allNear = false, true
for _, z in ipairs(raised) do
    if z.name == "Soldier" then gotSoldier = true end
    if z.x > cx + Reanimator.REVIVE_RADIUS then allNear = false end
end
assert(gotSoldier, "The strongest corpse (the Soldier) is raised first")
assert(allNear, "The far-away corpse isn't raised")
assert(#game.corpses == 3, "The raised corpses are used up")

-- 3. Zombies: same enemy, half health, can't be healed
local z = raised[1]
assert(math.abs(z.hp - z:getStat("maxHp") * 0.5) < 1e-6, "A zombie comes back at half health")
assert(z:getStat("speed") == entry(z.name).speed and z:getStat("damage") == entry(z.name).damage,
    "and keeps its normal speed and damage")
local hp = z.hp
assert(z:heal(50) == 0 and z.hp == hp, "Healing does nothing to a zombie")
local medic = spawn("Medic", z.x + 10, z.y)
medic:update(0.6)
assert(#medic.attachedTargets == 0, "A Medic doesn't latch onto zombies")
medic.destroyed = true

-- 4. Cooldown: the next cast is 10 seconds later
-- (the cooldown restarts when the slam lands)
run(rean, Reanimator.REVIVE_COOLDOWN - 0.5)
assert(#zombies() == Reanimator.MAX_REVIVES and not rean.phase, "No second cast before the cooldown is up")
run(rean, 1 + CAST)
assert(#zombies() == Reanimator.MAX_REVIVES + 2, "After the cooldown it raises the 2 nearby corpses left")

-- 4b. Stunned or frozen while channelling: the cast is cancelled and the cooldown restarts
kill(spawn("Grunt", cx - 20, cy - 20))
rean.reviveTimer = Reanimator.REVIVE_COOLDOWN - 0.05
run(rean, 0.1)
assert(rean.phase == "channel", "It starts channelling for the new corpse")
local zombiesBefore = #zombies()
rean.effectManager:applyEffect(Stun:new({ duration = 0.5 }))
run(rean, 0.1)
assert(not rean.phase and rean.reviveTimer == 0, "A stun interrupts the channel and resets the cooldown")
run(rean, CAST + 1)
assert(#zombies() == zombiesBefore and not rean.phase, "It doesn't just try again once the stun wears off")
run(rean, Reanimator.REVIVE_COOLDOWN - rean.reviveTimer + 0.1)
assert(rean.phase == "channel", "It tries again after a full cooldown")
local Chill = require("Game.Effects.StatusEffects.Chill")
local realIsFrozen = Chill.isFrozen
Chill.isFrozen = function(t) return t == rean end
run(rean, 0.1)
Chill.isFrozen = realIsFrozen
assert(not rean.phase and rean.reviveTimer < 0.2, "Freezing it interrupts the channel too")
game.corpses = {}

-- 5. Zombies leave no corpse, nor do enemies that reach the base; corpses expire
local before = #game.corpses
kill(z)
assert(#game.corpses == before, "A zombie that dies again leaves no corpse")
local runner = spawn("Grunt", cx, cy)
runner.reachedBase = true
runner:died()
assert(#game.corpses == before, "An enemy that reached the base leaves no corpse")
kill(spawn("Grunt", cx, cy))
game:updateCorpses(game.CORPSE_LIFETIME + 0.1)
assert(#game.corpses == 0, "Corpses rot away after " .. game.CORPSE_LIFETIME .. " seconds")

-- 6. Slimes leave corpses that come back as the same generation; a zombie Slime splits into zombies
local slime = spawn("Slime", cx - 30, cy)
kill(slime)
assert(#game.corpses == 1 and game.corpses[1].overrides and game.corpses[1].overrides.generation == 0,
    "A Slime leaves a corpse (remembering its generation)")
local small = spawn("Slime", cx - 30, cy)
small.generation = 2
kill(small)
local smallCorpse = game.corpses[#game.corpses]
local raisedSmall = rean:raise(smallCorpse)
assert(raisedSmall and raisedSmall.generation == 2 and raisedSmall.isZombie, "A small Slime comes back small (no more splits)")
game.corpses = {}
local zSlime = spawn("Slime", cx - 30, cy)
Zombie.apply(zSlime)
local count = #game.objects
kill(zSlime)
local children, allZombies = 0, true
for i = count + 1, #game.objects do
    local obj = game.objects[i]
    if obj.name == "Slime" then
        children = children + 1
        allZombies = allZombies and obj.isZombie == true
    end
end
assert(children == 2 and allZombies, "A zombie Slime splits into zombie Slimes")

-- 7. Codex demo: the turret drops the Grunts and the Reanimator raises them
local demo = EnemyDemo.new("Reanimator", { x = 0, y = 0, w = 600, h = 160 })
local sawZombies = false
for _ = 1, 200 do
    demo:update(0.05)
    for _, e in ipairs(demo.actors) do
        if e.isZombie and not e.demoDead then sawZombies = true end
    end
end
assert(sawZombies, "Codex demo: the fallen Grunts come back as zombies")
assert(pcall(function() demo:draw() end), "Codex demo draws")

print(string.format("\n%d failure(s)", failures))
if failures > 0 then os.exit(1) end
