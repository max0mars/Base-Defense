-- Testing/test_arc_overlay.lua
-- Firing arcs are colour-coded by overlap count (1..8+), each turret's arc is
-- counted once, and main turrets keep drawing their own range circle.

package.path = package.path .. ";./?.lua"

-- Mock love2d that records stencil / fill calls
local calls = {}
local function record(name) return function(...) table.insert(calls, { name, ... }) end end
_G.love = {
    math = { random = math.random },
    timer = { getTime = function() return 0 end },
    graphics = setmetatable({
        stencil = function(fn, action, value)
            table.insert(calls, { "stencil", action, value })
            fn()
        end,
        setStencilTest = record("setStencilTest"),
        setColor = record("setColor"),
        rectangle = record("rectangle"),
        polygon = record("polygon"),
    }, { __index = function() return function() end end }),
}
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

local ArcOverlay = require("Game.GUI.ArcOverlay")
local Turret = require("Buildings.Turrets.Turret")
local StandardMainTurret = require("Buildings.MainTurrets.StandardMainTurret")

-- 1. Eight distinct colours, the last one covering 8+
assert(#ArcOverlay.LEVELS == 8, "Gradient has 8 levels")
local seen = {}
for i, c in ipairs(ArcOverlay.LEVELS) do
    local key = string.format("%.2f,%.2f,%.2f", c[1], c[2], c[3])
    assert(not seen[key], "Level " .. i .. " has a unique colour")
    seen[key] = true
end

-- 2. Drawing: one stencil pass, one fill per level, 8+ uses "gequal"
local counted = 0
local arcs = {}
for _ = 1, 3 do
    table.insert(arcs, { drawFiringArcShape = function() counted = counted + 1 end })
end
calls = {}
ArcOverlay.draw(arcs, 0, 0, 800, 400)
assert(counted == 3, "Every arc is drawn into the stencil exactly once")
local tests, fills = {}, 0
for _, c in ipairs(calls) do
    if c[1] == "stencil" then assert(c[2] == "increment", "Stencil counts overlaps by incrementing") end
    if c[1] == "setStencilTest" and c[2] then table.insert(tests, { c[2], c[3] }) end
    if c[1] == "rectangle" then fills = fills + 1 end
end
assert(#tests == 8 and fills == 8, "One stencil test and one fill per level")
assert(tests[1][1] == "equal" and tests[1][2] == 1, "Level 1 colours exactly one arc")
assert(tests[7][1] == "equal" and tests[7][2] == 7, "Level 7 colours exactly seven arcs")
assert(tests[8][1] == "gequal" and tests[8][2] == 8, "Level 8 colours eight or more arcs")

calls = {}
ArcOverlay.draw({}, 0, 0, 800, 400)
assert(#calls == 0, "Nothing is drawn when no arcs are visible")

-- 3. Which objects the overlay takes over
local function turretLike(extra)
    local o = setmetatable({ showArc = true, firingArc = { direction = 0, angle = 1, minRange = 0 } }, { __index = Turret })
    for k, v in pairs(extra or {}) do o[k] = v end
    return o
end
assert(ArcOverlay.wants(turretLike()), "Turret with a visible arc is drawn by the overlay")
assert(not ArcOverlay.wants(turretLike({ showArc = false })), "Hidden arcs are skipped")
assert(not ArcOverlay.wants(turretLike({ destroyed = true })), "Destroyed turrets are skipped")
local main = setmetatable({ showArc = true, firingArc = { direction = 0, angle = math.pi, minRange = 0 } }, { __index = StandardMainTurret })
assert(not ArcOverlay.wants(main), "Main turrets keep their own range circle")
assert(not ArcOverlay.wants({ showArc = true, range = 100 }), "Buildings without firing arcs are skipped")

-- 4. A turret the overlay drew does not draw its grey arc again
local t = turretLike({ x = 0, y = 0, getStat = function() return 300 end })
calls = {}
t.arcDrawnByOverlay = true
t:drawFiringArc(0, 0, 0.4)
local polys = 0
for _, c in ipairs(calls) do if c[1] == "polygon" then polys = polys + 1 end end
assert(polys == 0, "Overlay-drawn turret skips its own grey arc")

calls = {}
t.arcDrawnByOverlay = nil
t:drawFiringArc(0, 0, 0.4)
polys = 0
for _, c in ipairs(calls) do if c[1] == "polygon" then polys = polys + 1 end end
assert(polys > 0, "Turrets not in the overlay (e.g. placement preview) still draw their grey arc")

if failures > 0 then
    print(failures .. " test(s) failed")
    os.exit(1)
end
print("All arc overlay tests passed")
