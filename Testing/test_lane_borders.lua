-- Testing/test_lane_borders.lua
-- The battlefield is split into three lanes by two border rows. Enemies stay in
-- their lane (a Phantom's blink is the exception), and each border has three
-- pairs of building slots (1 / 2 / 3 tokens each, nearest the base first) that
-- turrets and passive buildings can be placed on.

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

local menu = require("Scenes.menu_scene")
local game = require("Game.Core.GameManager")
local Layout = require("Game.GUI.Layout")
local BattlefieldGrid = require("Game.Core.BattlefieldGrid")
local TurretIndex = require("Buildings.TurretIndex")
local PassiveIndex = require("Buildings.PassiveIndex")
local Enemy = require("Enemies.Enemy")
local Phantom = require("Enemies.Phantom")

menu.scene_manager = { switch = noop }
menu:keypressed("return")
_G.PersistentState.selectedMainTurret = "MainLazer"
_G.PersistentState.discoveredEnemies = { Grunt = true }
_G.PersistentState.artifacts = {}
game:load(nil, false)
game:setState("startup")

local grid = game.battlefieldGrid
local cs = grid.cellSize
local function rowOf(slot) return math.ceil(slot / grid.width) end
local function colOf(slot) return ((slot - 1) % grid.width) + 1 end
local function slotAt(col, row) return (row - 1) * grid.width + col end

-- 1. Layout: three lanes, two borders, six priced slots per border
assert(#BattlefieldGrid.LANES == 3 and #BattlefieldGrid.BORDER_ROWS == 2, "three lanes split by two borders")
local perBorder = {}
local count = 0
for slot, price in pairs(grid.slotPrices) do
    count = count + 1
    local row = rowOf(slot)
    perBorder[row] = perBorder[row] or {}
    table.insert(perBorder[row], { col = colOf(slot), price = price })
end
assert(count == 12, "12 border slots in total (got " .. count .. ")")
for _, row in ipairs(BattlefieldGrid.BORDER_ROWS) do
    local list = perBorder[row] or {}
    table.sort(list, function(a, b) return a.col < b.col end)
    local prices = {}
    for _, s in ipairs(list) do table.insert(prices, s.price) end
    assert(table.concat(prices, ",") == "1,1,2,2,3,3",
        "border row " .. row .. ": pairs cost 1,1 / 2,2 / 3,3 going away from the base (got " .. table.concat(prices, ",") .. ")")
    local paired = #list == 6 and list[2].col == list[1].col + 1 and list[4].col == list[3].col + 1 and list[6].col == list[5].col + 1
    assert(paired and list[3].col > list[2].col + 1 and list[5].col > list[4].col + 1, "border row " .. row .. ": slots come in spaced-out side-by-side pairs")
end
local allLocked = true
for slot in pairs(grid.slotPrices) do allLocked = allLocked and not grid.unlocked[slot] end
assert(allLocked, "border slots start locked")

-- 1b. 18 rows: outer lanes 5 rows, middle lane 6, centred on the field and the main turret
assert(grid.height == 18 and game.base.buildGrid.height == 18, "field and base are 18 rows")
local L = BattlefieldGrid.LANES
local function laneRows(l) return L[l].last - L[l].first + 1 end
assert(laneRows(1) == 5 and laneRows(2) == 6 and laneRows(3) == 5, "lanes are 5 / 6 / 5 rows")
local midTop, midBottom = grid:getLaneBounds(2)
local fieldMid = grid.y + grid.height * cs / 2
assert((midTop + midBottom) / 2 == fieldMid, "the middle lane is centred on the field")
local mt = game.base.mainLazer
local mtx, mty = mt:getCenterPosition()
assert(math.abs(mty - fieldMid) < 0.01, "the main turret is centred on the middle lane (y " .. mty .. ")")
assert(math.abs(game.base.y - fieldMid) < 0.01 and game.base.h == grid.height * cs, "the base spans the whole field")

-- 1c. The battle canvas grows to fit at the same scale; other scenes stay 720 tall
assert(math.abs(Layout.scale - 1.225) < 1e-9, "the field keeps its on-screen scale")
assert(Layout.field.y + Layout.field.h <= Layout.tray.y + 0.001 and Layout.tray.y + Layout.tray.h == Layout.H, "the field sits right above the tray, which ends at the bottom")
local sm = require("Scenes.scene_manager")
sm.scenes.stubBattle = setmetatable({}, { __index = require("Scenes.game_scene") })
sm.scenes.stubBattle.load = noop
sm.scenes.stubMenu = { load = noop }
sm.switch("stubBattle")
assert(VIRTUAL_HEIGHT == Layout.H, "the battle scene switches to the taller canvas")
sm.switch("stubMenu")
assert(VIRTUAL_HEIGHT == 720, "other scenes switch back to 720")

-- 2. Lane lookup
for lane, rows in ipairs(BattlefieldGrid.LANES) do
    local midY = grid.y + ((rows.first + rows.last) / 2 - 0.5) * cs
    assert(grid:getLaneAt(midY) == lane, "middle of lane " .. lane .. " is in lane " .. lane)
end
local border1Y = grid.y + (BattlefieldGrid.BORDER_ROWS[1] - 0.5) * cs
local lane1Top, lane1Bottom = grid:getLaneBounds(1)
assert(grid:clampToLane(1, border1Y, 10) == lane1Bottom - 10, "a y on the border is pushed back into the lane, body and all")

-- 3. Enemies can't cross a border
local function newEnemy(class, y, lane)
    local e = class:new({ game = game, x = 600, y = y, lane = lane })
    game:addObject(e)
    return e
end
local walker = newEnemy(Enemy, lane1Bottom - 15, 1)
for _ = 1, 30 do
    walker.y = walker.y + 5 -- something shoves it toward the border every frame
    walker:update(0.05)
end
local _, bottom1 = grid:getLaneBounds(1)
assert(walker.lane == 1 and walker.y + walker.h / 2 <= bottom1 + 0.001, "a pushed enemy stays in lane 1 (y " .. walker.y .. ")")
walker.destroyed = true

local unassigned = newEnemy(Enemy, grid.y + (BattlefieldGrid.LANES[3].first + 1) * cs)
unassigned:update(0.01)
assert(unassigned.lane == 3, "an enemy without a lane takes the one it appears in")
unassigned.destroyed = true

-- Spawned children stay in the parent's lane even if they start across the border
local _, lane2Bottom = grid:getLaneBounds(2)
local child = newEnemy(Enemy, lane2Bottom + 20, 2)
child:update(0.01)
assert(child.lane == 2 and child.y < lane2Bottom, "a child handed lane 2 is pulled back into lane 2")
child.destroyed = true

-- Splits spread only inside the lane
local splitter = newEnemy(Enemy, lane2Bottom - 12, 2)
splitter:startSpread(splitter.x, lane2Bottom + 40)
assert(splitter.spread.toY <= lane2Bottom, "a split can't spread across the border")
splitter.destroyed = true

-- 4. Wave spawns land in their sector's lane
for sector = 0, 2 do
    local e = game.WaveSpawner:spawnEnemy(Enemy, sector)
    local top, bottom = grid:getLaneBounds(sector + 1)
    assert(e.lane == sector + 1 and e.y >= top and e.y <= bottom, "sector " .. sector .. " spawns in lane " .. (sector + 1))
    e.destroyed = true
end

-- 5. A Phantom's blink can take it across a border
local phantom = newEnemy(Phantom, grid.y + 2 * cs, 1)
local lane3Top, lane3Bottom = grid:getLaneBounds(3)
phantom:startBlink((lane3Top + lane3Bottom) / 2)
assert(phantom.lane == 3, "a Phantom blinking into lane 3 now belongs to lane 3")
phantom:update(0.01)
assert(phantom.y >= lane3Top and phantom.y <= lane3Bottom, "and it stays there")
phantom.destroyed = true
game:takeOutTheTrash()

-- 5b. A Phantom's blink always takes it to one of the other two lanes, any
-- distance away, at a random height inside that lane
local Phantom2 = require("Enemies.Phantom")
for fromLane = 1, 3 do
    local landed, wrongLane, outside = {}, 0, 0
    local laneMin, laneMax = {}, {}
    for _ = 1, 300 do
        local ftop, fbottom = grid:getLaneBounds(fromLane)
        local p = Phantom2:new({ game = game, x = 600, y = (ftop + fbottom) / 2, lane = fromLane })
        p.blinkCooldown = 0
        p:tryBlink()
        -- run the wipe and the blink through to the end
        p:updateBlink(Phantom2.VANISH_TIME + 0.01)
        if p.lane == fromLane then wrongLane = wrongLane + 1 end
        local top, bottom = grid:getLaneBounds(p.lane)
        if p.y - p.h / 2 < top - 0.001 or p.y + p.h / 2 > bottom + 0.001 then outside = outside + 1 end
        landed[p.lane] = (landed[p.lane] or 0) + 1
        laneMin[p.lane] = math.min(laneMin[p.lane] or math.huge, p.y)
        laneMax[p.lane] = math.max(laneMax[p.lane] or -math.huge, p.y)
    end
    local others = {}
    for lane = 1, 3 do if lane ~= fromLane then table.insert(others, lane) end end
    assert(wrongLane == 0, "from lane " .. fromLane .. ": a blink never stays in the same lane")
    assert((landed[others[1]] or 0) > 50 and (landed[others[2]] or 0) > 50,
        "from lane " .. fromLane .. ": it reaches both other lanes, near and far ("
        .. others[1] .. ": " .. (landed[others[1]] or 0) .. ", " .. others[2] .. ": " .. (landed[others[2]] or 0) .. ")")
    assert(outside == 0, "from lane " .. fromLane .. ": it always lands fully inside its new lane")
    local o = others[1]
    local top, bottom = grid:getLaneBounds(o)
    assert(laneMax[o] - laneMin[o] > (bottom - top) * 0.6,
        "from lane " .. fromLane .. ": the height it lands at varies across the lane")
end

-- 6. Placing turrets and buildings on border slots
local ih = game.inputHandler
local function cellCentre(slot)
    local sx, sy = grid:getSlotPosition(slot)
    return sx + cs / 2, sy + cs / 2
end
local function hoverAndClick(slot)
    local wx, wy = cellCentre(slot)
    local mx, my = Layout.worldToScreen(wx, wy)
    love.mouse.getPosition = function() return mx, my end
    ih:update(0)
    ih:mousepressed(mx, my, 1)
end
local function placeBlueprint(bp, slot, tokens)
    game.tokens = tokens
    game.activeCard = nil
    game.inputMode = "placing"
    game.blueprint = bp
    hoverAndClick(slot)
    local placed = game.inputMode ~= "placing"
    game.inputMode = "idle"
    game.blueprint = nil
    return placed
end
local function newTurret()
    local cfg = {}
    for k, v in pairs(TurretIndex.common[1]) do cfg[k] = v end
    cfg.game = game
    return require("Buildings.Turrets.Turret"):new(cfg)
end
local function newPassive(id)
    for _, list in pairs(PassiveIndex) do
        if type(list) == "table" then
            for _, e in ipairs(list) do
                if e.id == id then
                    local cfg = {}
                    for k, v in pairs(e) do cfg[k] = v end
                    cfg.game = game
                    return e.building:new(cfg)
                end
            end
        end
    end
end

local row1 = BattlefieldGrid.BORDER_ROWS[1]
local row2 = BattlefieldGrid.BORDER_ROWS[2]
local pairs_ = BattlefieldGrid.BORDER_SLOT_PAIRS
local near = slotAt(pairs_[1].cols[1], row1)
local mid = slotAt(pairs_[2].cols[2], row2)
local far = slotAt(pairs_[3].cols[1], row1)

-- Not enough tokens for the unlock: refused
local turret = newTurret()
assert(not placeBlueprint(turret, far, 2), "a 3-token slot can't be bought with 2 tokens")
assert(not grid.unlocked[far] and game.tokens == 2, "and nothing is spent")

-- Turret on the nearest (1-token) slot
assert(placeBlueprint(turret, near, 1), "a turret can be placed on a locked 1-token border slot")
assert(grid.unlocked[near] and game.tokens == 0, "placing unlocks the slot for 1 token")
assert(turret.buildGrid == grid and turret.slot == near, "the turret sits on the battlefield border slot")
local tx, ty = cellCentre(near)
assert(math.abs(turret.x - tx) < 0.01 and math.abs(turret.y - ty) < 0.01, "the turret is centred on its slot")

-- That slot is now taken
assert(not placeBlueprint(newTurret(), near, 5), "a second turret can't go on the same slot")

-- Turret on a far (3-token) slot
local farTurret = newTurret()
assert(placeBlueprint(farTurret, far, 3) and game.tokens == 0, "a turret can be placed on a 3-token slot for 3 tokens")

-- Passive building on a middle (2-token) slot of the other border
local vault = newPassive("vault")
assert(vault, "found The Vault passive")
assert(placeBlueprint(vault, mid, 2) and game.tokens == 0, "a passive building can be placed on a 2-token slot for 2 tokens")
assert(vault.buildGrid == grid and vault.slot == mid, "the passive sits on the battlefield border slot")

-- Turrets can't go anywhere else on the battlefield
local laneCell = slotAt(15, BattlefieldGrid.LANES[2].first + 1)
assert(not placeBlueprint(newTurret(), laneCell, 10), "a turret can't be placed inside a lane")
local borderGap = slotAt(15, row1)
assert(not placeBlueprint(newTurret(), borderGap, 10), "a turret can't be placed on the border between slot pairs")

-- 7. Clicking a locked slot outside placement unlocks it for its price
local mid2 = slotAt(pairs_[2].cols[1], row1)
game.tokens = 1
game.inputMode = "idle"
hoverAndClick(mid2)
assert(not grid.unlocked[mid2] and game.tokens == 1, "clicking a 2-token slot with 1 token does nothing")
game.tokens = 5
hoverAndClick(mid2)
assert(grid.unlocked[mid2] and game.tokens == 3, "clicking it with 5 tokens unlocks it for 2")
local unlockedTurret = newTurret()
assert(placeBlueprint(unlockedTurret, mid2, 0), "an already-unlocked slot costs nothing more to build on")

-- 8. Lane slots follow the same rules as base slots
local SlotVisuals = require("Game.GUI.SlotVisuals")
assert(grid:isSlotTaken(near) and grid.buildings[near] == turret, "placed buildings are looked up by slot, as on the base")

-- An adjacency buff on a lane slot buffs the turret beside it, as it would on the base
local buffedSlot = slotAt(pairs_[1].cols[1], row2)
local cacheSlot = slotAt(pairs_[1].cols[2], row2)
local buffed = newTurret()
assert(placeBlueprint(buffed, buffedSlot, 1), "a turret goes on the second border's nearest pair")
local before = buffed:getStat("damage")
local cache = newPassive("ammoCache")
assert(placeBlueprint(cache, cacheSlot, 1), "an Ammo Cache goes on the slot beside it")
game:recalculateAllBuffs()
assert(buffed:getStat("damage") > before, "the Ammo Cache buffs its lane-slot neighbour ("
    .. before .. " -> " .. buffed:getStat("damage") .. ")")

-- An Outpost unlocks its surrounding slots: on a lane border that's only its pair partner
local outpostSlot = slotAt(pairs_[3].cols[2], row2)
local partner = slotAt(pairs_[3].cols[1], row2)
assert(not grid.unlocked[partner], "the far pair's partner slot starts locked")
local outpost = newPassive("outpost")
local okPlace, placed = pcall(placeBlueprint, outpost, outpostSlot, 3)
assert(okPlace and placed, "an Outpost can be placed on a lane slot")
assert(grid.unlocked[partner], "it unlocks its pair partner for free, as it does neighbours on the base")
local strayUnlocks = 0
for s, open in pairs(grid.unlocked) do
    if open and not grid:isBuildSlot(s) then strayUnlocks = strayUnlocks + 1 end
end
assert(strayUnlocks == 0, "and doesn't mark cells that aren't slots as unlocked")

-- The same affordability rule and slot drawing on both grids
game.activeCard = { getCost = function() return 1 end }
game.tokens = 2
game.inputMode = "placing"
assert(game.base:canAffordUnlock(1) and not game.base:canAffordUnlock(2), "base: unlock + card while placing")
assert(SlotVisuals.canAffordUnlock(game, 1) and not SlotVisuals.canAffordUnlock(game, 2), "lane slots use the same rule")
game.blueprint = newTurret()
assert(pcall(grid.drawGrid, grid) and pcall(game.base.draw, game.base), "both grids draw their slots while placing")
game.inputMode = "idle"
game.blueprint = nil
game.activeCard = nil
assert(pcall(grid.drawGrid, grid) and pcall(game.base.draw, game.base), "and outside placement")

log("--- Lane Border Tests Completed with " .. failures .. " failures ---")
os.exit(failures == 0 and 0 or 1)
