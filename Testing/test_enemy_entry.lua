-- Testing/test_enemy_entry.lua
-- Enemy entries: opened from the INCOMING list, pause the battle, and play a demo of each enemy.


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
        getColor = function() return 1, 1, 1, 1 end,
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
local scene = require("Scenes.game_scene")
local EnemyIndex = require("Game.Spawning.EnemyIndex")
local EnemyDemo = require("Game.GUI.EnemyDemo")
local Chill = require("Game.Effects.StatusEffects.Chill")
local Layout = require("Game.GUI.Layout")

menu.scene_manager = { switch = noop }
scene.scene_manager = { switch = noop }
menu:keypressed("return")
_G.PersistentState.selectedMainTurret = "MainLazer"
_G.PersistentState.discoveredEnemies = { Grunt = true }
game:load(nil, false)
game:setState("startup")

-- 1. Descriptions: every enemy has one, with no numbers in it
for _, e in ipairs(EnemyIndex) do
    assert(type(e.description) == "string" and #e.description > 20 and not e.description:find("%d"),
        e.id .. " has a number-free description")
end
local guardian
for _, e in ipairs(EnemyIndex) do if e.id == "Guardian" then guardian = e end end
assert(guardian.grantsShield == true and guardian.hasAura == false, "the Guardian gives shields; its aura is a mutation")
assert(guardian.mutations[1].modifiers.hasAura, "the Guardian's mutation is the damage-reducing aura")

-- 2. Clicking an enemy in the INCOMING list opens that enemy's entry, and only it
local entry = game.gui.enemyEntry
local column = game.gui.infoColumn
column.hordeCards = function() return { { id = "Medic", type = "Medic", total = 1, remaining = 1, flashUntil = 0 },
    { id = "Grunt", type = "Grunt", total = 3, remaining = 3, flashUntil = 0 } }, 1, false end
local col = Layout.leftColumn
local cardW = math.floor(((col.w - 24) - 2 * 8) / 3)
game.gui:mousepressed(col.x + 12 + cardW / 2, 104 + 26 + 30, 1)
assert(entry.isActive and entry.entry.id == "Medic", "clicking the Medic card opens the Medic's entry")
assert(entry.open and not entry.tab and not entry.turretEntries and not entry.enemyEntries, "the entry has no tabs or list of other entries")
column.hordeCards = nil

-- 3. The battle is paused while it's open
game:setState("wave")
game.WaveSpawner.waveState = "active"
local before = game.pulseTimer
scene:update(0.5)
assert(game.pulseTimer == before, "the battle is paused while an entry is open")
entry:draw()
assert(entry.demo ~= nil, "the entry plays a demo")

-- 4. Closing: Esc, or clicking outside the window (clicks inside are swallowed)
local r = entry:rect()
game.gui:mousepressed(r.x + 10, r.y + 10, 1)
assert(entry.isActive, "clicking inside the entry keeps it open")
game.gui:mousepressed(5, 5, 1)
assert(not entry.isActive, "clicking outside closes it")
entry:open("Grunt")
scene:keypressed("escape")
assert(not entry.isActive and paused ~= 1, "Esc closes the entry (not the pause menu)")
game:setState("startup")

-- 5. Each demo shows its enemy at its in-game speed and plays its ability
local rect = { x = 100, y = 100, w = 520, h = 170 }
local function run(id, seconds, watch)
    local demo = EnemyDemo.new(id, rect)
    local seen = {}
    local steps = math.floor(seconds / 0.02)
    for _ = 1, steps do
        demo:update(0.02)
        if watch then watch(demo, seen) end
    end
    local ok, err = pcall(function() demo:draw() end)
    assert(ok, id .. " demo draws" .. (ok and "" or (": " .. tostring(err))))
    return demo, seen
end

for _, e in ipairs(EnemyIndex) do
    local demo = EnemyDemo.new(e.id, rect)
    local star = demo.star
    local x0 = star.x
    demo:update(0.5)
    assert(math.abs((x0 - star.x) - star:getStat("speed") * 0.5) < 1e-6, e.id .. " walks left at its in-game speed")
end

local _, seen = run("Scout", 3, function(d, s) s.passed = s.passed or (d.star.x < d.actors[2].x - 50) end)
assert(seen.passed, "Scout: outruns the Grunt beside it")

_, seen = run("Drone", 12, function(d, s) s.slowed = s.slowed or (d.turret and d.turret.slowed > 0) end)
assert(seen.slowed, "Drone: its shots slow the turret down")

_, seen = run("Soldier", 4, function(d, s)
    for _, t in ipairs(d.texts) do s[t.str] = true end
end)
assert(seen["8"] and seen["10"], "Soldier: bullets do reduced damage, energy shots full")

_, seen = run("Sapper", 4, function(d, s) s.hit = s.hit or (d.wall and d.wall.flash > 0) end)
assert(seen.hit, "Sapper: hits the base wall")

_, seen = run("Broodmother", 4, function(d, s)
    local n = 0
    for _, a in ipairs(d.actors) do if a.name == "Critter" then n = n + 1 end end
    s.critters = math.max(s.critters or 0, n)
end)
assert(seen.critters == 3, "Broodmother: hatches Critters")

_, seen = run("Guardian", 3, function(d, s)
    for _, g in ipairs(d.grunts or {}) do if (g.shield or 0) > 0 then s.shielded = true end end
end)
assert(seen.shielded, "Guardian: shields the Grunts beside it")

_, seen = run("Captain", 6, function(d, s)
    for _, g in ipairs(d.grunts or {}) do
        if Chill.getStacks(g) > 0 then s.chilled = true end
        if s.chilled and Chill.getStacks(g) == 0 then s.cleared = true end
    end
end)
assert(seen.chilled and seen.cleared, "Captain: clears the chill off nearby Grunts")

_, seen = run("PortalMaster", 3, function(d, s)
    local g = d.grunts and d.grunts[1]
    if g then
        if s.lastX and s.lastX - g.x > 10 then s.jumped = true end
        s.lastX = g.x
    end
end)
assert(seen.jumped, "Portal Master: pulls Grunts forward")

_, seen = run("Medic", 10, function(d, s)
    local g = d.grunts and d.grunts[1]
    if g then s.healed = s.healed or g.hp >= g:getStat("maxHp") end
    s.tether = s.tether or (d.star.attachedTargets and #d.star.attachedTargets > 0)
end)
assert(seen.healed and seen.tether, "Medic: latches on and heals a Grunt to full")

_, seen = run("Slime", 12, function(d, s)
    local n, smallest = 0, math.huge
    for _, a in ipairs(d:alive()) do n = n + 1; smallest = math.min(smallest, a.w) end
    s.most = math.max(s.most or 0, n)
    s.gen2 = s.gen2 or (smallest < 12)
end)
assert(seen.most >= 2 and seen.gen2, "Slime: splits into smaller slimes, which split again")

_, seen = run("Tank", 6, function(d, s)
    for _, t in ipairs(d.texts) do if t.str:sub(1, 1) == "+" then s.heal = tonumber(t.str:sub(2)) end end
end)
assert(seen.heal and seen.heal > 7.5 + 0.5, "Tank: a Medic's healing lands extra hard on it")

-- 6. Demos loop: the star walks off and the scene starts over
local demo = EnemyDemo.new("Scout", rect)
local first = demo.star
for _ = 1, 400 do demo:update(0.02) end
assert(demo.star ~= first, "the demo restarts once the enemy has walked off")

-- 7. Mutations: the demo uses the enemy's mutated stats; the entry has a spot for them later
_G.PersistentState.activeMutations = { { target = "Grunt", modifiers = { speed = 2 } } }
demo = EnemyDemo.new("Grunt", rect)
assert(demo.star.speed == 50, "the demo enemy uses its mutated speed")
_G.PersistentState.activeMutations = {}
assert(#entry:activeMutations("Grunt") == 0, "no mutations are listed yet")

print(string.format("\n%d failure(s)", failures))
if failures > 0 then os.exit(1) end
