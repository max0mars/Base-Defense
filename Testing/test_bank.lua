-- Testing/test_bank.lua
-- Bank: +1 token cap per wave only when its top, bottom and right neighbours are
-- filled, +2 when they are all turrets, nothing otherwise (incl. off-grid edges).

package.path = package.path .. ";./?.lua"

-- Mock love2d (every love.* function is a no-op; GameManager pulls in the whole game)
local noop = function() end
_G.love = setmetatable({
    math = setmetatable({ random = math.random }, { __index = function() return noop end }),
    timer = { getTime = function() return 0 end },
}, { __index = function() return setmetatable({}, { __index = function() return noop end }) end })
_G.VIRTUAL_WIDTH = 1280
_G.VIRTUAL_HEIGHT = 720

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
local GameManager = require("Game.Core.GameManager")

local bankEntry
for _, rarity in pairs(PassiveIndex) do
    for _, e in ipairs(rarity) do
        if e.id == "bank" then bankEntry = e end
    end
end

local WIDTH, HEIGHT = 4, 16
local buildGrid = { x = 0, y = 0, width = WIDTH, height = HEIGHT, cellSize = 32, buildings = {} }
local game = { objects = {}, maxTokens = 3, base = { buildGrid = buildGrid } }

local function slotAt(x, y) return y * WIDTH + x + 1 end -- 0-based grid coords

local function makeBank(x, y)
    local config = {}
    for k, v in pairs(bankEntry) do config[k] = v end
    config.game = game
    config.buildGrid = buildGrid
    local bank = bankEntry.building:new(config)
    bank.game = game
    bank.buildGrid = buildGrid
    bank.slot = slotAt(x, y)
    buildGrid.buildings[bank.slot] = bank
    table.insert(game.objects, bank)
    return bank
end

local turretStub = { isType = function(_, t) return t == "turret" end }
local passiveStub = { isType = function(_, t) return t == "passive" end }

local function place(x, y, b) buildGrid.buildings[slotAt(x, y)] = b end
local function clear() buildGrid.buildings = {}; game.objects = {} end

local function maxTokens() return GameManager.getMaxTokens(game) end

-- Bank at (1, 5): top = (1,4), bottom = (1,6), right = (2,5), left = (0,5)
clear()
local bank = makeBank(1, 5)
assert(bank:getTokenBonus() == 0, "Empty neighbours: no bonus")
assert(maxTokens() == 3, "Inactive Bank does not raise the token cap")

place(1, 4, passiveStub); place(1, 6, passiveStub)
assert(bank:getTokenBonus() == 0, "Top + bottom only: still inactive")

place(0, 5, passiveStub)
assert(bank:getTokenBonus() == 0, "Left neighbour does not count toward activation")

place(2, 5, passiveStub)
assert(bank:getTokenBonus() == 1, "Top, bottom and right filled: +1")
assert(maxTokens() == 4, "Active Bank raises the token cap by 1")

place(1, 4, turretStub); place(1, 6, turretStub)
assert(bank:getTokenBonus() == 1, "Mixed turret/passive neighbours: still +1")

place(2, 5, turretStub)
assert(bank:getTokenBonus() == 2, "All three required neighbours are turrets: +2")
assert(maxTokens() == 5, "Turret-surrounded Bank raises the token cap by 2")

place(0, 5, nil)
assert(bank:getTokenBonus() == 2, "Empty left slot doesn't matter")

buildGrid.buildings[slotAt(2, 5)] = { destroyed = true, isType = turretStub.isType }
assert(bank:getTokenBonus() == 0, "Destroyed neighbour deactivates the Bank")

-- Edges: a required neighbour off the grid can never be filled
clear()
local edgeBank = makeBank(WIDTH - 1, 5) -- rightmost column: no right neighbour
place(WIDTH - 1, 4, turretStub); place(WIDTH - 1, 6, turretStub)
assert(edgeBank:getTokenBonus() == 0, "Rightmost-column Bank can never activate")

clear()
local topBank = makeBank(1, 0) -- top row: no top neighbour
place(1, 1, turretStub); place(2, 0, turretStub)
assert(topBank:getTokenBonus() == 0, "Top-row Bank can never activate")

-- Two active Banks stack
clear()
local b1 = makeBank(1, 3)
local b2 = makeBank(1, 9)
for _, y in ipairs({ 2, 4, 8, 10 }) do place(1, y, passiveStub) end
place(2, 3, passiveStub); place(2, 9, turretStub)
assert(b1:getTokenBonus() == 1 and b2:getTokenBonus() == 1, "Two covered Banks are both active")
assert(maxTokens() == 5, "Two active Banks raise the token cap by 2")

-- Card text and tooltip agree with the behaviour
assert(bankEntry.description:find("Token") and not bankEntry.description:find("Energy"), "Card description talks about Tokens")
for _, s in ipairs(b1:getTooltipStrings()) do
    assert(not s:find("Energy"), "Tooltip no longer says Energy: " .. s)
end

if failures > 0 then
    print(failures .. " test(s) failed")
    os.exit(1)
end
print("All bank tests passed")
