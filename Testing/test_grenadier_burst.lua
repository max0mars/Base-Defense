-- Testing/test_grenadier_burst.lua
-- A Grenadier whose target dies mid-burst used to fire the rest of the burst
-- with no landing point, so those grenades dropped (and exploded) at the
-- turret. The burst now finishes at the last spot it aimed at, and a lobbed
-- shell with no landing point flies its turret's range instead.

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

local TurretIndex = require("Buildings.TurretIndex")
local GrenadeBullet = require("Bullets.GrenadeBullet")
local LobberBullet = require("Bullets.LobberBullet")
local game = require("Game.Core.GameManager")

_G.PersistentState = {
    selectedMainTurret = "MainLazer",
    battlesCompleted = 0,
    globalDifficulty = 1,
    discoveredEnemies = { Grunt = true },
    startingTokens = 3,
}
game:load(nil, false)

local entry
for _, list in pairs(TurretIndex) do
    for _, e in ipairs(list) do if e.id == "grenadier" then entry = e end end
end
local cfg = {}
for k, v in pairs(entry) do cfg[k] = v end
cfg.game, cfg.x, cfg.y = game, 100, 300
local turret = entry.building:new(cfg)

local function grenades()
    local list = {}
    for _, obj in ipairs(game.objects) do
        if getmetatable(obj) == GrenadeBullet and not obj.destroyed then table.insert(list, obj) end
    end
    return list
end
--- Flies every grenade until it lands; returns the closest landing distance from the turret.
local function closestLanding()
    local closest = math.huge
    for _, g in ipairs(grenades()) do
        for _ = 1, 400 do
            if g.landed or g.destroyed then break end
            g:update(1 / 60)
        end
        closest = math.min(closest, math.sqrt((g.x - turret.x) ^ 2 + (g.y - turret.y) ^ 2))
    end
    return closest
end

-- 1. Its target dies after the first grenade: the rest of the burst still flies out
local tx, ty = turret.x + 300, turret.y
turret.rotation = 0
turret:fire({ targetX = tx, targetY = ty })
turret.target = nil -- killed
turret.burstsRemaining, turret.burstTimer = 2, 0
for _ = 1, 30 do turret:update(0.02) end
assert(#grenades() == 3, "All 3 grenades of the burst were fired (" .. #grenades() .. ")")
local closest = closestLanding()
assert(closest > 200, string.format("None of them land at the turret (closest %.0f px away)", closest))

-- 2. A lobbed shell with no landing point flies out along its heading to the turret's range
for _, g in ipairs(grenades()) do g.destroyed = true end
local shell = LobberBullet:new({
    name = "Shell", x = turret.x, y = turret.y, angle = 0, bulletSpeed = 250, damage = 1, pierce = 1, lifespan = 3,
    game = game, source = turret, types = { bullet = true },
})
local landedAt
for _ = 1, 400 do
    shell:update(1 / 60)
    if shell.destroyed then landedAt = shell.x break end
end
assert(landedAt and math.abs((landedAt - turret.x) - turret:getStat("range")) < 15,
    "A shell with no target lands at the turret's range, not at its feet")

print(string.format("\n%d failure(s)", failures))
if failures > 0 then os.exit(1) end
