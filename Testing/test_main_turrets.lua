-- Testing/test_main_turrets.lua
-- Main turret tuning: Heavy Laser damage and starting deck, Machine Gun Heavy Rounds.

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
local MainLazer = require("Buildings.MainTurrets.MainLazer")
local FastMainTurret = require("Buildings.MainTurrets.FastMainTurret")

local function deckCounts(deck)
    local counts = {}
    for _, card in ipairs(deck:getCards()) do
        counts[card.id] = (counts[card.id] or 0) + (card.quantity or 1)
    end
    return counts
end

-- 1. Heavy Laser: 55 damage; starting deck has a Flux Cannon and no Unstable Laser
assert(MainLazer.template.damage == 60, "Heavy Laser deals 60 damage")
local laserDeck = deckCounts(MainLazer.getStartingDeck())
assert(laserDeck.fluxCannon == 1, "Heavy Laser deck starts with 1 Flux Cannon")
assert(laserDeck.unstable_laser == nil, "Heavy Laser deck no longer has Unstable Laser")
assert(laserDeck.sentry == 2 and laserDeck.blaster == 2, "Heavy Laser deck keeps its Sentries and Blasters")

-- 2. Machine Gun: Heavy Rounds is a rare unique upgrade
local heavyRounds
for _, card in ipairs(FastMainTurret.getUniqueCards().rare or {}) do
    if card.id == "heavy_rounds" then heavyRounds = card end
end
assert(heavyRounds and heavyRounds.type == "main_upgrade", "Heavy Rounds is in the Machine Gun's unique pool")

-- 3. In a battle: -30% fire rate, +50% damage, offered only once and only to the Machine Gun
menu.scene_manager = { switch = noop }
menu:keypressed("return")
_G.PersistentState.selectedMainTurret = "FastMainTurret"
_G.PersistentState.discoveredEnemies = { Grunt = true }
game:load(nil, false)
local mg = game.base.mainLazer
assert(mg.id == "fast_main", "Battle loaded with the Machine Gun")
assert(heavyRounds.isEligible(game), "Heavy Rounds is offered before it's taken")
local baseDamage, baseRate = mg:getStat("damage"), mg:getStat("fireRate")
mg:applyUpgrade(heavyRounds)
assert(math.abs(mg:getStat("damage") - baseDamage * 1.5) < 1e-6, "Heavy Rounds: +50% damage")
assert(math.abs(mg:getStat("fireRate") - baseRate * 0.8) < 1e-6, "Heavy Rounds: -20% fire rate")
assert(not heavyRounds.isEligible(game), "Heavy Rounds isn't offered again")

local lowPower
for _, card in ipairs(MainLazer.getUniqueCards().rare) do
    if card.id == "low_power_operating" then lowPower = card end
end
assert(not lowPower.isEligible(game), "Low Power Ops isn't offered to the Machine Gun")

-- 4. The main turret only fires during a wave, not while placing
for _, state in ipairs({ "startup", "preparing" }) do
    game:setState(state)
    mg.cooldown = 0
    assert(mg:PlayerClick(mg.x + 200, mg.y) == false, "main turret doesn't fire in the " .. state .. " phase")
end
game:setState("wave")
mg.cooldown = 0
assert(mg:PlayerClick(mg.x + 200, mg.y) == true, "main turret fires during a wave")

-- 5. Battle summary: only the base is drawn, and hovering a turret finds it for its stats
local cx, cy = mg:getCenterPosition()
assert(game:buildingAt(cx, cy) == mg, "hovering the main turret finds it")
assert(game:buildingAt(cx + 300, cy) == nil, "hovering empty field finds nothing")
local Layout = require("Game.GUI.Layout")
local scene = require("Scenes.game_scene")
local drewStats
local realStats = scene.drawTurretStats
scene.drawTurretStats = function(self, turret) drewStats = turret end
love.mouse.getPosition = function() return Layout.worldToScreen(cx, cy) end
scene.showingSummary = true
scene.summaryTopTurrets, scene.summaryOtherRewards = {}, {}
scene.summaryDamage, scene.summaryIncome, scene.summaryPerfectBonus = 0, 0, 0
scene.summaryInterest, scene.summaryTotalCash, scene.summaryIceMarket = 0, 0, 0
scene.settings = { draw = noop }
local ok, err = pcall(function() scene:draw() end)
assert(ok, "the summary draws" .. (ok and "" or (": " .. tostring(err))))
assert(drewStats == mg, "the summary shows the hovered turret's stats")
scene.drawTurretStats = realStats
assert(pcall(function() scene:drawTurretStats(mg, 100, 100) end), "the turret stats card draws")
scene.showingSummary = false

-- 6. Edit mode: A selects every turret (not the main turret)
local TurretIndex = require("Buildings.TurretIndex")
local grid = game.base.buildGrid
local placed = {}
for i, cell in ipairs({ { 0, 2 }, { 3, 2 }, { 0, 12 } }) do
    local cfg = {}
    for k, v in pairs(TurretIndex.common[1]) do cfg[k] = v end
    cfg.game = game
    local t = cfg.building:new(cfg)
    local slot = cell[2] * grid.width + cell[1] + 1
    grid.unlocked[slot] = true
    game:newBuilding(t, slot)
    placed[i] = t
end
game:setState("preparing")
game.inputMode = "idle"
local ih = game.inputHandler
ih:keypressed("a")
assert(#ih.editSelection == 0, "A does nothing outside edit mode")
ih:keypressed("q")
assert(ih.editMode, "Q enters edit mode")
ih:keypressed("a")
local selected = {}
for _, t in ipairs(ih.editSelection) do selected[t] = true end
assert(#ih.editSelection == 3 and selected[placed[1]] and selected[placed[2]] and selected[placed[3]], "A selects every turret")
assert(not selected[mg], "the main turret isn't part of the group aim")
-- A while aiming starts over: the old group's aim is undone first
local before = placed[1].firingArc.direction
ih.mouseX, ih.mouseY = 600, 50
ih:updateEditAim()
assert(placed[1].firingArc.direction ~= before, "the group turns to the cursor")
ih:keypressed("a")
assert(placed[1].firingArc.direction == before and #ih.editSelection == 3, "pressing A again restores the aim and reselects all")
ih:keypressed("q")
assert(not ih.editMode, "Q leaves edit mode")

-- 7. Clicking a placed turret selects it without re-aiming it
game:setState("preparing")
game.inputMode = "idle"
local t1 = placed[1]
local dirBefore = t1.firingArc.direction
ih:selectBuilding(t1)
love.mouse.getPosition = function() return 1200, 50 end
ih:update(0.016)
assert(ih.selectedBuilding == t1 and t1.firingArc.direction == dirBefore, "a selected turret keeps its aim while the mouse moves")
ih:clearSelection()
-- ...but a turret that was just placed is aimed by the mouse until the click
game.inputMode = "aiming"
ih:selectBuilding(t1)
ih:update(0.016)
assert(t1.firingArc.direction ~= dirBefore, "a just-placed turret follows the mouse to be aimed")
t1.firingArc.direction = dirBefore
game.inputMode = "idle"
ih:clearSelection()

-- 8. Tokens, mana and the pile buttons sit in the left column; the hand holds 10
local Layout = require("Game.GUI.Layout")
local printedAt = {}
local realPrint = love.graphics.print
love.graphics.print = function(text, x, y) printedAt[tostring(text)] = x end
game.gui.hand:draw()
love.graphics.print = realPrint
local col = Layout.leftColumn
local drawX = printedAt["VIEW DRAW"]
assert(drawX and drawX >= col.x and drawX < col.x + col.w, "the pile buttons are in the left column")
assert(game.MAX_HAND_SIZE == 10, "the hand holds up to 10 cards")
game.hand, game.drawPile = {}, {}
for i = 1, 12 do game.drawPile[i] = { name = "c" .. i, getCost = function() return 0 end } end
game:drawCard(12)
assert(#game.hand == 10, "drawing stops at 10 cards")
game.hand = {}

print(string.format("\n%d failure(s)", failures))
if failures > 0 then os.exit(1) end
