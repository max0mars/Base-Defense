-- Testing/test_stormbreaker.lua
-- PROJECT STORMBREAKER: the player aims it. Each shot strikes up to 3 random
-- enemies inside the targeting area around the cursor.

package.path = package.path .. ";./?.lua"

-- Mock love2d (every love.* function is a no-op; GameManager pulls in the whole game)
local noop = function() end
local fontStub = { getWidth = function() return 10 end, getHeight = function() return 10 end, getWrap = function() return 10, { "" } end }
_G.love = setmetatable({
    math = setmetatable({ random = math.random, colorFromBytes = function(...) return ... end,
        triangulate = function() return {} end }, { __index = function() return noop end }),
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

local menu = require("Scenes.menu_scene")
local game = require("Game.Core.GameManager")
local Enemy = require("Enemies.Enemy")
local MainLazer = require("Buildings.MainTurrets.MainLazer")
local Cursor = require("Game.GUI.Cursor")

menu.scene_manager = { switch = noop }
menu:keypressed("return")
_G.PersistentState.selectedMainTurret = "MainLazer"
_G.PersistentState.discoveredEnemies = { Grunt = true }
_G.PersistentState.artifacts = {}
game:load(nil, false)
game:setState("wave")

local mt = game.mainLazer
local stormbreaker = MainLazer.getUniqueCards().legendary[1]
assert(stormbreaker.id == "electric_field", "PROJECT STORMBREAKER is the Heavy Laser's legendary upgrade")
mt:applyUpgrade(stormbreaker)

local function enemyAt(x, y)
    local e = Enemy:new({ game = game, x = x, y = y, size = 10, maxHp = 1000, hp = 1000, speed = 0 })
    game:addObject(e)
    return e
end
local function hurt(e) return e.hp < e.maxHp end
local function clearEnemies()
    for _, o in ipairs(game.objects) do
        if o:isType("enemy") then o.destroyed = true end
    end
    mt.pendingZaps = {}
end

-- 1. It no longer fires on its own
local lone = enemyAt(600, 300)
mt.cooldown = 0
for _ = 1, 30 do mt:update(0.1) end
assert(not hurt(lone), "without a click, nothing gets struck")

-- 2. A click with no enemies in the area does nothing and keeps the charge
assert(mt:PlayerClick(900, 300) == false, "a click away from every enemy doesn't fire")
assert(mt.cooldown <= 0, "an empty click doesn't spend the shot")

-- 3. Up to 3 enemies inside the area are struck, in a quick ripple; ones outside aren't
clearEnemies()
local inside = {}
for i = 1, 5 do inside[i] = enemyAt(600 + i * 5, 300) end
local outside = enemyAt(600 + MainLazer.STORM_RADIUS + 20, 300)
mt.cooldown = 0
assert(mt:PlayerClick(600, 300) == true, "a click on enemies fires")
local function struck()
    local n = 0
    for _, e in ipairs(inside) do if hurt(e) then n = n + 1 end end
    return n
end
assert(struck() == 1, "the first strike lands at once")
mt:update(MainLazer.STORM_ZAP_GAP * 3)
assert(struck() == 3, "3 of the 5 enemies in the area get struck")
assert(not hurt(outside), "enemies outside the area aren't struck")
assert(math.abs(mt.cooldown - 1 / mt:getStat("fireRate")) < 0.5, "the shot starts the reload")
assert(mt:PlayerClick(600, 300) == false, "it can't fire again while reloading")

-- 4. With fewer enemies than strikes, each is struck once
clearEnemies()
local a, b = enemyAt(600, 300), enemyAt(610, 300)
mt.cooldown = 0
mt:PlayerClick(600, 300)
mt:update(1)
local dmg = mt:getStat("damage")
assert(a.maxHp - a.hp <= dmg * 2 + 1e-6 and hurt(a) and hurt(b), "both enemies are struck, once each")

-- 5. It doesn't fire into the base or between waves
clearEnemies()
enemyAt(game.base.x, game.base.y)
mt.cooldown = 0
assert(mt:PlayerClick(game.base.x, game.base.y) == false, "clicking the base doesn't fire")
game:setState("startup")
enemyAt(600, 300)
assert(mt:PlayerClick(600, 300) == false, "it doesn't fire between waves")

-- 6. The storm cursor draws at any charge
for _, charge in ipairs({ 0, 0.5, 1 }) do
    local ok, err = pcall(Cursor.drawStorm, 100, 100, charge, 50)
    assert(ok, "the storm cursor draws at charge " .. charge .. " (" .. tostring(err) .. ")")
end
Cursor.use("storm", 1, 50)
assert(Cursor.current() == "storm" and Cursor.radius == 50, "the battle can pick the storm cursor with its radius")
Cursor.usePointer()
assert(Cursor.radius == nil, "going back to the pointer drops the radius")

-- 7. Unique cards keep their rarity when the deck is rebuilt from a save
local SaveGame = require("Game.Core.SaveGame")
local saved = SaveGame.decodeCard({ id = "electric_field", tier = 1, quantity = 1 }, "MainLazer")
assert(saved and saved:getCardDraw().rarity == "legendary", "a saved PROJECT STORMBREAKER card is still legendary")
saved = SaveGame.decodeCard({ id = "low_power_operating", tier = 1, quantity = 1 }, "MainLazer")
assert(saved and saved:getCardDraw().rarity == "rare", "a saved Low Power Ops card is still rare")

log(string.format("\n%d failure(s)", failures))
if failures > 0 then os.exit(1) end
