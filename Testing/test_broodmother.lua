-- Testing/test_broodmother.lua
-- Broodmother: hatched critters fan out side by side in front of it and keep their lanes.


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

local game = require("Game.Core.GameManager")
local menu = require("Scenes.menu_scene")

local game = require("Game.Core.GameManager")
local menu = require("Scenes.menu_scene")
local EnemyIndex = require("Game.Spawning.EnemyIndex")
local Spawner = require("Enemies.Spawner")

local function entry(id)
    for _, e in ipairs(EnemyIndex) do if e.id == id then return e end end
end
assert(entry("Broodmother").speed == 13.5, "Broodmother moves 10% slower (15 -> 13.5)")

menu.scene_manager = { switch = noop }
menu:keypressed("return")
_G.PersistentState.selectedMainTurret = "MainLazer"
_G.PersistentState.discoveredEnemies = { Grunt = true }
game:load(nil, false)
game:setState("wave")

local function critters()
    local list = {}
    for _, obj in ipairs(game.objects) do
        if obj.name == "Critter" and not obj.destroyed then table.insert(list, obj) end
    end
    return list
end

local function spawnBatch(y)
    local bm = Spawner:new({ game = game, x = 700, y = y, name = "Broodmother" })
    game:addObject(bm)
    bm.spawnTimer = bm:getStat("spawnFrequency")
    for _ = 1, 60 do bm:update(0.01) end
    return bm
end

local worstGap, closest = 0, math.huge
for run = 1, 30 do
    for _, c in ipairs(critters()) do c.destroyed = true end
    game:takeOutTheTrash()
    local bm = spawnBatch(300)
    local batch = critters()
    assert(#batch == 3, "a batch hatches 3 critters")
    if #batch ~= 3 then break end
    table.sort(batch, function(a, b) return a.y < b.y end)
    local size = batch[1]:getStat("size")
    for i = 2, 3 do
        local gap = batch[i].y - batch[i - 1].y - size
        worstGap = math.max(worstGap, gap)
        closest = math.min(closest, gap)
    end
    for _, c in ipairs(batch) do
        if c.x >= bm.x then assert(false, "critters hatch in front of the broodmother") end
    end
    assert(math.abs(batch[2].y - bm.batchY) <= 1.01, "the middle critter is centred on where the broodmother hatched them")
    bm.destroyed = true
    for _, c in ipairs(batch) do c.destroyed = true end
    game:takeOutTheTrash()
end
assert(closest >= 0, string.format("critters never overlap (closest gap %.2f)", closest))
assert(worstGap <= 4.01, string.format("and stay close together (widest gap %.2f)", worstGap))

-- Walking keeps them in their lanes
local bm = spawnBatch(300)
bm.destroyed = true
for _ = 1, 300 do
    for _, c in ipairs(critters()) do c:update(0.01) end
end
local batch = critters()
table.sort(batch, function(a, b) return a.y < b.y end)
local size = batch[1]:getStat("size")
local apart, close = true, true
for i = 2, #batch do
    local gap = batch[i].y - batch[i - 1].y - size
    apart = apart and gap >= -0.5
    close = close and gap <= 4.5
end
assert(#batch == 3 and apart, "after 3 seconds of walking they're still side by side")
assert(close, "and still close together, not drifting apart")

print(string.format("\n%d failure(s)", failures))
if failures > 0 then os.exit(1) end
