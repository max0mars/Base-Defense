-- Testing/test_battle_tuning.lua
-- Battle tweaks: turret tuning, Cryo Beam retarget delay, thaw credit, popup text and the artifact bar.


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
local Enemy = require("Enemies.Enemy")
local TurretIndex = require("Buildings.TurretIndex")
local Chill = require("Game.Effects.StatusEffects.Chill")
local ArtifactIndex = require("Game.Artifacts.ArtifactIndex")
local ArtifactManager = require("Game.Artifacts.ArtifactManager")
local Layout = require("Game.GUI.Layout")

menu.scene_manager = { switch = noop }
menu:keypressed("return")
_G.PersistentState.selectedMainTurret = "MainLazer"
_G.PersistentState.discoveredEnemies = { Grunt = true }
_G.PersistentState.artifacts = {}
game:load(nil, false)
game:setState("wave")

local function findTurret(id)
    for _, rarity in ipairs({ "common", "uncommon", "rare", "epic", "legendary" }) do
        for _, entry in ipairs(TurretIndex[rarity] or {}) do
            if entry.id == id then return entry end
        end
    end
end
local grid = game.base.buildGrid
local function place(id, x, y)
    local entry = findTurret(id)
    local cfg = {}
    for k, v in pairs(entry) do cfg[k] = v end
    cfg.game = game
    local t = entry.building:new(cfg)
    local slot = y * grid.width + x + 1
    grid.unlocked[slot] = true
    game:newBuilding(t, slot)
    return t
end
local function enemyAt(x, y)
    local e = Enemy:new({ game = game, x = x, y = y, name = "Grunt", maxHp = 1e6 })
    e.speed = 0
    game:addObject(e)
    return e
end

-- 1. Tuning
local missile, shotgun = findTurret("missileLauncher"), findTurret("shotgunTurret")
assert(missile.damage == 50 and missile.explosionDamage == 50 and missile.radius == 40, "missile launcher: 50 damage, 40 blast radius")
assert(shotgun.damage == 6, "shotgun: 6 damage per pellet")

-- Heavy Shotgun: uncommon, 2 tokens, a long-range tight-spread shotgun
local heavy = findTurret("heavyShotgun")
assert(heavy and heavy.cost == 2 and heavy.pelletCount == 7 and heavy.damage == 16 and heavy.pierce == 2,
    "heavy shotgun: 2 tokens, 7 x 16 dmg pellets that pierce once")
local isUncommon = false
for _, e in ipairs(TurretIndex.uncommon) do isUncommon = isUncommon or e.id == "heavyShotgun" end
assert(isUncommon, "heavy shotgun is uncommon")
assert(heavy.range > shotgun.range * 2 and heavy.spread < shotgun.spread / 2, "heavy shotgun: over twice the range, under half the spread")
assert(heavy.bulletSpeed * 0.9 * heavy.lifespan >= heavy.range, "heavy shotgun pellets reach max range")
local heavyHits = heavy.pelletCount * (20 / heavy.range) / heavy.spread
assert(heavyHits >= 3 and heavyHits <= 4, string.format("heavy shotgun: %.2f pellets on a 20px enemy at max range", heavyHits))

-- 2. Cryo Beam waits before locking onto a new target
local beam = place("cryoBeam", 1, 2)
beam.firingArc.direction = 0
local bx, by = beam:getCenterPosition()
local first = enemyAt(bx + 100, by)
local ticks = 0
local realTick = beam.tick
beam.tick = function(self, target) ticks = ticks + 1; return realTick(self, target) end
beam:update(0.01)
assert(beam.target == first and ticks == 1, "the first lock ticks straight away")
first.destroyed = true
local second = enemyAt(bx + 120, by)
ticks = 0
for _ = 1, 25 do beam:update(0.01) end -- 0.25s
assert(beam.target == second and ticks == 0, "a new target isn't hit during the 0.3s retarget delay")
for _ = 1, 10 do beam:update(0.01) end -- past 0.3s
assert(ticks >= 1, "then the beam locks on and ticks")
second.destroyed = true
game:takeOutTheTrash()

-- 3. Thaw damage (Heart of the Tundra) is credited to whoever froze the enemy
ArtifactManager.grant("heart_of_the_tundra")
game.artifacts:addInstance("heart_of_the_tundra")
game.artifacts:refresh()
local freezer = place("frostCannon", 2, 12)
local victim = enemyAt(400, 300)
victim.maxHp, victim.hp = 100, 10
Chill.apply(victim, 99, { source = { source = freezer } }) -- via a bullet, like a real hit
assert(Chill.isFrozen(victim) and Chill.getFreezer(victim).source == freezer, "the freeze remembers who froze it")
for _ = 1, 200 do victim:update(0.01) end -- 2s: thaw starts at 1.5s
local stats = game.damageStats:get(freezer)
assert(victim.destroyed and stats.kills == 1 and stats.damage > 0, "the thaw kill and damage go to the turret that froze it")

-- The Glacial Monolith gets the credit too
local monolith = place("glacialMonolith", 1, 6)
local v2 = enemyAt(400, 300)
v2.maxHp, v2.hp = 100, 1
monolith.chillPerWave = 99
monolith.firingArc.direction = math.atan2(300 - select(2, monolith:getCenterPosition()), 400 - monolith:getCenterPosition())
for _ = 1, 800 do monolith:update(0.01); v2:update(0.01); if v2.destroyed then break end end -- wave travel ~2.75s + 1.5s thaw
assert(v2.destroyed and game.damageStats:get(monolith).kills == 1, "a monolith freeze earns the thaw kill")

-- Monolith rings shed small frost motes that fade away
local sawMotes = false
local v3 = enemyAt(400, 300)
for _ = 1, 50 do monolith:update(0.01); sawMotes = sawMotes or #monolith.motes > 0 end
assert(sawMotes, "monolith rings shed frost motes")
v3.destroyed = true
game:takeOutTheTrash()
for _ = 1, 500 do monolith:update(0.01) end
assert(#monolith.waves == 0 and #monolith.motes == 0, "the motes fade once the rings are gone")
assert(pcall(function() monolith:draw() end), "the monolith draws its rings and motes")

-- 4. Message popups are centred on where they're aimed, with no jitter
local DamageNumber = require("Graphics.Animations.DamageNumber")
game.animations = {}
game:spawnScreenText("Not enough tokens!", 640, 600, {1, 0, 0, 1})
local t = game.animations[1]
assert(t.isUI and t.centered and t.x == 640 and t.y == 600 and t.velX == 0, "screen popups start exactly at the mouse, centred, over the HUD")
game:spawnFloatingText("+$5", 200, 300, {0, 1, 0, 1})
local w = game.animations[2]
assert(not w.isUI and w.centered and w.x == 200, "world popups are centred too")
local drawnAt
local realPrint = love.graphics.print
love.graphics.print = function(text, x, y) drawnAt = x end
t:draw()
love.graphics.print = realPrint
assert(drawnAt and drawnAt < 640, "the text is drawn centred on its point")

-- 5. Artifacts are listed in the left column, just above the tokens and mana
-- (off the battlefield, so they never cover base slots); hovering shows the tooltip
local ArtifactViewerUI = require("Game.GUI.ArtifactViewerUI")
local HandUI = require("Game.GUI.HandUI")
local tooltipFor
local realTooltip = ArtifactViewerUI.drawTooltip
ArtifactViewerUI.drawTooltip = function(def, mx, my, below) tooltipFor = { def = def, below = below } end
local iconBottom = HandUI.resourceRowTop(game) - 8
local iconX, iconY = Layout.leftColumn.x + 12, iconBottom - 24
love.mouse.getPosition = function() return iconX + 12, iconY + 12 end
game.gui:draw()
ArtifactViewerUI.drawTooltip = realTooltip
assert(tooltipFor and tooltipFor.def.id == "heart_of_the_tundra" and not tooltipFor.below, "hovering the artifact icon shows its tooltip above it")
assert(iconX + 24 <= Layout.leftColumn.x + Layout.leftColumn.w, "the icons sit in the left column, off the battlefield")
assert(iconY >= 104 + 264, "and below the incoming-wave cards")

-- 6. Hovering a building shows its stats & modifiers in a window at the mouse
local hovered = place("sentry", 0, 3)
game.damageStats:record(hovered, 120, true)
game.inputHandler.hoveredBuilding = hovered
local texts, boxes = {}, {}
local realPrintf, realRect = love.graphics.printf, love.graphics.rectangle
love.graphics.printf = function(text, x, y) table.insert(texts, { text = tostring(text), x = x, y = y }) end
love.graphics.rectangle = function(mode, x, y, w, h) if mode == "fill" then table.insert(boxes, { x = x, y = y, w = w, h = h }) end end
love.mouse.getPosition = function() return 700, 300 end
game.gui.infoColumn:drawHoverStats()
love.graphics.printf, love.graphics.rectangle = realPrintf, realRect
local window = boxes[1]
assert(window and window.x == 718 and window.y == 318, "the stats window sits just beside the mouse")
assert(hovered.rarity == "common", "a placed turret stores its rarity (the window is coloured by it)")
assert(game.mainLazer.rarity == "main_weapon", "the main turret uses the main-weapon colour")
local function windowTexts(building)
    local out = {}
    game.inputHandler.hoveredBuilding = building
    local realPrint = love.graphics.print
    love.graphics.printf = function(text) out[tostring(text)] = true end
    love.graphics.print = function(text) out[tostring(text)] = true end
    game.gui.infoColumn:drawHoverStats()
    love.graphics.printf, love.graphics.print = realPrintf, realPrint
    return out
end
assert(windowTexts(hovered)["I"], "a turret's window shows its tier numeral beside the name")
hovered.tier = 3
assert(windowTexts(hovered)["III"], "an upgraded turret shows its higher tier")
hovered.tier = 1
local mainTexts = windowTexts(game.mainLazer)
local mainTier = false
for t in pairs(mainTexts) do if t == "I" then mainTier = true end end
assert(not mainTier, "the main turret has no tier")
game.inputHandler.hoveredBuilding = hovered
do
    local function entryFor(index, id)
        for _, list in pairs(index) do for _, e in ipairs(list) do if e.id == id then return e end end end
    end
    local function build(entry, dropRarity)
        local cfg = {}
        for k, v in pairs(entry) do cfg[k] = v end
        if dropRarity then cfg.rarity = nil end
        cfg.game = game
        return entry.building:new(cfg)
    end
    local gator = entryFor(require("Buildings.TurretIndex"), "gator")
    local cache = entryFor(require("Buildings.PassiveIndex"), "ammoCache")
    assert(build(gator).rarity == "rare", "a rare turret stores its rarity")
    assert(build(cache).rarity == "uncommon", "passives store their rarity too")
    assert(build(gator, true).rarity == "rare", "a building from a config without rarity (older save) still gets it")

    -- Passives (no damage stats) still get the window, describing what they do
    local passive = build(cache)
    local stubWrap = fontStub.getWrap
    fontStub.getWrap = function(_, text) return 10, { text } end -- the stub wraps to "" otherwise
    local passiveLines = game.gui.infoColumn:buildingExtrasLines(passive)
    fontStub.getWrap = stubWrap
    local joined = {}
    for _, ln in ipairs(passiveLines) do joined[#joined + 1] = ln.text end
    joined = table.concat(joined, " ")
    assert(#passiveLines > 0 and joined:find("damage", 1, true), "a hovered passive's window lists its description")
end
local killsAt
for _, t in ipairs(texts) do if t.text == "Kills: 1" then killsAt = t end end
assert(killsAt and killsAt.x > window.x and killsAt.y > window.y, "it lists the hovered turret's stats")

-- It flips to stay on screen near the edges, and moves with the mouse
boxes = {}
love.graphics.rectangle = function(mode, x, y, w, h) if mode == "fill" then table.insert(boxes, { x = x, y = y, w = w, h = h }) end end
love.mouse.getPosition = function() return VIRTUAL_WIDTH - 20, VIRTUAL_HEIGHT - 20 end
game.gui.infoColumn:drawHoverStats()
love.graphics.rectangle = realRect
assert(boxes[1].x + boxes[1].w <= VIRTUAL_WIDTH and boxes[1].y + boxes[1].h <= VIRTUAL_HEIGHT, "near the corner it flips to stay on screen")

-- The INSPECT panel no longer lists the stats
texts = {}
love.graphics.printf = function(text, x, y) table.insert(texts, { text = tostring(text), x = x, y = y }) end
game.gui.infoColumn:draw()
love.graphics.printf = realPrintf
local inPanel = false
for _, t in ipairs(texts) do if t.text == "Kills: 1" or t.text == "STATS & MODIFIERS" then inPanel = true end end
assert(not inPanel, "the bottom-left panel no longer shows stats & modifiers")
game.inputHandler.hoveredBuilding = nil

print(string.format("\n%d failure(s)", failures))
if failures > 0 then os.exit(1) end
