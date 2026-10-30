-- Testing/test_base_reach.lua
-- Every enemy that walks to the base hits it. An enemy landing exactly on its
-- hit line used to stop there for good: the navigator doesn't move an enemy
-- that's already at its target, and the hit needed it past the line.

package.path = package.path .. ";./?.lua"

-- Mock love2d (every love.* function is a no-op; GameManager pulls in the whole game)
local noop = function() end
local fontStub = { getWidth = function() return 10 end, getHeight = function() return 10 end, getWrap = function() return 10, { "" } end }
_G.love = setmetatable({
    math = setmetatable({ random = math.random, colorFromBytes = function(...) return ... end }, { __index = function() return noop end }),
    timer = { getTime = function() return 0 end },
    mouse = setmetatable({ getPosition = function() return 0, 0 end }, { __index = function() return noop end }),
    keyboard = { isDown = function() return false end },
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
_G.paused = 0
math.atan2 = math.atan2 or math.atan

local log = print
print = noop -- silence game logging

local failures = 0
local function assert(condition, message)
    if not condition then
        log("[FAIL] " .. message)
        failures = failures + 1
    else
        log("[PASS] " .. message)
    end
end

math.randomseed(1)

local menu = require("Scenes.menu_scene")
local game = require("Game.Core.GameManager")
local Enemy = require("Enemies.Enemy")
local EnemyRegistry = require("Game.Spawning.EnemyRegistry")

menu.scene_manager = { switch = noop }
menu:keypressed("return")
_G.PersistentState.selectedMainTurret = "MainLazer"
_G.PersistentState.discoveredEnemies = { Grunt = true }
_G.PersistentState.artifacts = {}
_G.PersistentState.upcomingWaves = { {}, {} } -- more waves to come: the battle isn't won when these die
game:load(nil, false)
game:setState("wave")
game.base.maxHp, game.base.hp = 1e12, 1e12

-- 1. Landing exactly on the hit line is a hit
local e = Enemy:new({ game = game, x = 600, y = 300, size = 20, damage = 5 })
game:addObject(e)
e:getTargetPos()
e.x = e.target
local hp = game.base.hp
e:update(1 / 60)
assert(e.destroyed and e.reachedBase, "an enemy exactly on the hit line hits the base")
assert(game.base.hp < hp, "and damages it")

-- 2. A step that lands exactly on the line (speed 15 at 60 fps moves exactly 0.25)
e = Enemy:new({ game = game, x = 600, y = 300, size = 20, speed = 15 })
game:addObject(e)
e:getTargetPos()
e.x = e.target + 1
for _ = 1, 10 do
    if not e.destroyed then e:update(1 / 60) end
end
assert(e.destroyed and e.reachedBase, "an enemy whose steps land exactly on the line still hits the base")

-- The navigator doesn't stop at the line either: it walks on into the base
e = Enemy:new({ game = game, x = 600, y = 300, size = 20, speed = 30 })
e:getTargetPos()
e.x = e.target
e.navigator:update(0.1)
assert(e.x < e.target - 2.9, "the navigator walks an enemy on the line on into the base")
e:destroy()

-- 3. Every enemy type, spawned the way waves (and the dev spawner) spawn them,
-- reaches the base. They're made unkillable so only the base can end them.
local spawned = {}
for _, entry in ipairs(EnemyRegistry.allEnemies) do
    for _ = 1, 3 do
        local before = #game.objects
        game.WaveSpawner:spawnEnemy(entry.class)
        for i = before + 1, #game.objects do
            local obj = game.objects[i]
            if obj.isType and obj:isType("enemy") then
                obj.typeId = entry.id
                obj.maxHp, obj.hp = 1e12, 1e12
                table.insert(spawned, obj)
            end
        end
    end
end
for _ = 1, 60 * 240 do
    game:update(1 / 60)
end

local stuck = {}
for _, obj in ipairs(game.objects) do
    if obj.isType and obj:isType("enemy") and not obj.destroyed then
        table.insert(stuck, string.format("%s at x=%.2f (hit line %.2f)", tostring(obj.typeId or obj.name), obj.x, obj.target or -1))
    end
end
assert(#spawned > 0, "enemies were spawned (" .. #spawned .. ")")
assert(#stuck == 0, "every enemy type reaches the base" .. (#stuck > 0 and (": stuck " .. table.concat(stuck, "; ")) or ""))

log("--- Base Reach Tests Completed with " .. failures .. " failures ---")
os.exit(failures == 0 and 0 or 1)
