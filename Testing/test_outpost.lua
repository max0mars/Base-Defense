-- Testing/test_outpost.lua
-- The Outpost passive unlocks the 8 base slots around it when placed, and
-- placed buildings can no longer be destroyed with a right-click.

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

local PassiveIndex = require("Buildings.PassiveIndex")
local TurretIndex = require("Buildings.TurretIndex")
local Layout = require("Game.GUI.Layout")
local game = require("Game.Core.GameManager")

_G.PersistentState = {
    selectedMainTurret = "MainLazer",
    battlesCompleted = 0,
    globalDifficulty = 1,
    discoveredEnemies = { Grunt = true },
    startingTokens = 3,
}
game:load(nil, false)
local base, grid = game.base, game.base.buildGrid

local function entryFor(index, id)
    for _, list in pairs(index) do
        for _, e in ipairs(list) do if e.id == id then return e end end
    end
end
local function build(entry)
    local cfg = {}
    for k, v in pairs(entry) do cfg[k] = v end
    cfg.game = game
    return entry.building:new(cfg)
end
local function cell(slot) return (slot - 1) % grid.width, math.floor((slot - 1) / grid.width) end

-- 1. Registered as a passive card
local entry = entryFor(PassiveIndex, "outpost")
assert(entry and entry.rarity == "uncommon" and entry.cost == 2, "The Outpost is an uncommon passive costing 2")
assert(entry and #entry.affectedSlots == 8, "Its card shows all 8 surrounding slots")

-- 2. Placed next to the unlocked area, it unlocks the 8 slots around it
local spot
for s = 1, grid.width * grid.height do
    local x, y = cell(s)
    local inside = x > 0 and y > 0 and x < grid.width - 1 and y < grid.height - 1
    if inside and not grid.unlocked[s] and not grid.buildings[s] and base:isSlotVisible(s) then
        -- Needs locked neighbours, or there's nothing to show
        local lockedAround = 0
        for dy = -1, 1 do for dx = -1, 1 do
            local n = (y + dy) * grid.width + (x + dx) + 1
            if not grid.unlocked[n] then lockedAround = lockedAround + 1 end
        end end
        if lockedAround >= 4 then spot = s; break end
    end
end
assert(spot ~= nil, "Found a visible, locked slot at the edge of the unlocked area")

local outpost = build(entry)
game:newBuilding(outpost, spot)
local x, y = cell(spot)
local allOpen, opened = true, 0
for dy = -1, 1 do
    for dx = -1, 1 do
        local n = (y + dy) * grid.width + (x + dx) + 1
        allOpen = allOpen and grid.unlocked[n] == true
    end
end
assert(allOpen, "All 8 surrounding slots (and its own) are unlocked")
assert(outpost.slotsUnlocked >= 4, "It reports how many slots it opened (" .. tostring(outpost.slotsUnlocked) .. ")")

-- 3. Turrets around it get +10% range (and nothing else)
local turret = build(entryFor(TurretIndex, "sentry"))
local neighbour = (y) * grid.width + (x + 1) + 1
local diagonal = (y + 1) * grid.width + (x + 1) + 1
local diagTurret = build(entryFor(TurretIndex, "blaster"))
game:newBuilding(turret, neighbour)
if not grid.buildings[diagonal] then game:newBuilding(diagTurret, diagonal) end
local far = build(entryFor(TurretIndex, "autoCannon"))
for s = 1, grid.width * grid.height do
    local fx, fy = cell(s)
    if (math.abs(fx - x) > 1 or math.abs(fy - y) > 1) and not grid.buildings[s] and grid.unlocked[s] then
        game:newBuilding(far, s); break
    end
end
game:recalculateAllBuffs()
assert(math.abs(turret:getStat("range") - turret.range * 1.1) < 1e-6, "A turret beside it gets +10% range")
assert(not diagTurret.slot or math.abs(diagTurret:getStat("range") - diagTurret.range * 1.1) < 1e-6,
    "So does a turret diagonal to it")
assert(turret:getStat("damage") == turret.damage, "Its other stats are unchanged")
assert(not far.slot or far:getStat("range") == far.range, "A turret further away isn't affected")

-- 4. At the grid's corner it only unlocks the slots that exist
grid.unlocked[1] = true
local corner = build(entry)
if not grid.buildings[1] then
    game:newBuilding(corner, 1)
    assert(#corner:getAffectedSlotsFromAnchor(1) == 3 and corner.slotsUnlocked <= 3,
        "In the corner it only has 3 neighbours to unlock")
end

-- 5. Right-clicking a placed building doesn't offer to destroy it any more
local ih = game.inputHandler
local sx, sy = Layout.worldToScreen(turret.x, turret.y)
rawset(love, "mouse", setmetatable({ getPosition = function() return sx, sy end }, { __index = function() return noop end }))
game.inputMode = "idle"
ih:update(0)
ih:mousepressed(sx, sy, 2)
game.gui:update(0)
assert(not game.gui.confirmation.active, "Right-click on a building opens no destroy confirmation")
assert(not turret.destroyed and grid.buildings[neighbour] == turret, "and the building stays where it is")

print(string.format("\n%d failure(s)", failures))
if failures > 0 then os.exit(1) end
