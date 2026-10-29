-- Cursor.lua: the game's own mouse cursor, drawn in every scene (the OS cursor
-- stays hidden). Each frame, scenes and UI say what's under the mouse and
-- main.lua draws the result last, on top of everything:
--   Cursor.wantHand / Cursor.hover   a clickable: the pointing hand
--   Cursor.setIcon(name)             a hover with its own action icon (Cursor.ICONS)
--   Cursor.use(name, charge)         the battle's choice (reticle, targeting, aiming),
--                                    cleared again by Cursor.usePointer for menus
-- With none of these it is the plain pointer.

local Neon = require("Game.GUI.Neon")

local Cursor = {}

Cursor.wantHand = false
Cursor.icon = nil
Cursor.mode = nil   -- set by Cursor.use
Cursor.charge = nil -- the reticle's reload, 0-1

--- Clears the frame's cursor requests (called before each frame's draw).
function Cursor.reset()
    Cursor.wantHand = false
    Cursor.icon = nil
    Cursor.mode = nil
    Cursor.charge = nil
end

--- Asks for one of the icons in Cursor.ICONS this frame (over Cursor.wantHand).
function Cursor.setIcon(name) Cursor.icon = name end

--- Shows `name` (an icon, or "reticle" with its reload `charge`) whatever the HUD asked for.
function Cursor.use(name, charge)
    Cursor.mode = name
    Cursor.charge = charge
end

--- Drops a Cursor.use choice: back to the HUD's hand / icon, or the plain pointer.
function Cursor.usePointer()
    Cursor.mode = nil
    Cursor.charge = nil
end

-- Flags a hand cursor (or `icon`) if the current mouse position is inside the given rect.
function Cursor.hover(x, y, w, h, icon)
    local mx, my = love.mouse.getPosition()
    if mx >= x and mx < x + w and my >= y and my < y + h then
        Cursor.wantHand = true
        if icon then Cursor.icon = icon end
        return true
    end
    return false
end

--- The cursor that will be drawn this frame: a Cursor.ICONS name, "reticle",
--- "hand" or "pointer".
function Cursor.current()
    return Cursor.mode or Cursor.icon or (Cursor.wantHand and "hand") or "pointer"
end

-- -----------------------------------------------------------------------------
-- Drawing helpers
-- -----------------------------------------------------------------------------

local CYAN = Neon.CYAN
local AMBER = Neon.AMBER
local MAGENTA = Neon.MAGENTA
local GREEN = Neon.GREEN
local RED = Neon.RED
local GOLD = { 1.0, 0.82, 0.25 }
local FILL = { 0.03, 0.05, 0.09 }

-- A neon tube: dark outline, the colour, then a thin hot core.
local function tube(c, width, shape)
    love.graphics.setColor(0, 0, 0, 0.75)
    love.graphics.setLineWidth(width + 2)
    shape("line")
    love.graphics.setColor(c[1], c[2], c[3], 1)
    love.graphics.setLineWidth(width)
    shape("line")
    local hot = Neon.hot(c, 0.55)
    love.graphics.setColor(hot[1], hot[2], hot[3], 0.9)
    love.graphics.setLineWidth(math.max(0.75, width * 0.4))
    shape("line")
end

-- Fills a (possibly concave) polygon.
local function fillPolygon(pts)
    local ok, tris = pcall(love.math.triangulate, pts)
    if not ok or type(tris) ~= "table" then return end
    for _, t in ipairs(tris) do love.graphics.polygon("fill", t) end
end

-- Pointer: a plain angled triangle with its tip at (x, y).
local function pointerShape(x, y)
    return {
        x,        y,
        x + 3.5,  y + 15,
        x + 12.5, y + 9,
    }
end

-- Pointing hand with the fingertip at (x, y).
local function handShape(x, y)
    return {
        x - 2.5, y + 1.5,  x - 1.5, y,  x + 1.5, y,  x + 2.5, y + 1.5,   -- index fingertip
        x + 2.5, y + 7.5,                                               -- down to the knuckle
        x + 4, y + 6.8,  x + 5.5, y + 7.8,                               -- middle finger
        x + 7, y + 7.6,  x + 8.5, y + 8.8,                               -- ring finger
        x + 10, y + 9,  x + 11, y + 10.5,                                -- little finger
        x + 11, y + 16,  x + 8.5, y + 20,                                -- palm, right side
        x - 1.5, y + 20,  x - 4, y + 16.5,                               -- wrist
        x - 7.5, y + 11.5,  x - 7, y + 10,  x - 5.5, y + 9.8,            -- thumb
        x - 2.5, y + 12,                                                 -- thumb joint
    }
end

local function drawShape(pts, color)
    love.graphics.setColor(FILL[1], FILL[2], FILL[3], 0.92)
    fillPolygon(pts)
    tube(color, 1.5, function(mode) love.graphics.polygon(mode, pts) end)
end

--- The plain pointer, tip at (x, y), in `color` (cyan by default).
function Cursor.drawArrow(x, y, color)
    love.graphics.push("all")
    love.graphics.setLineJoin("miter")
    drawShape(pointerShape(x, y), color or CYAN)
    love.graphics.pop()
end

--- The pointing hand over clickables, fingertip at (x, y).
function Cursor.drawHand(x, y, color)
    love.graphics.push("all")
    drawShape(handShape(x, y), color or CYAN)
    love.graphics.pop()
end

-- Badges: small symbols beside the pointer, centred on (cx, cy)

local function badgeDisc(cx, cy, c)
    love.graphics.setColor(FILL[1], FILL[2], FILL[3], 0.95)
    love.graphics.circle("fill", cx, cy, 7.5)
    tube(c, 1.5, function(mode) love.graphics.circle(mode, cx, cy, 7.5) end)
end

local function cardBadge(cx, cy, c)
    love.graphics.push()
    love.graphics.translate(cx, cy)
    love.graphics.rotate(math.rad(12))
    love.graphics.setColor(FILL[1], FILL[2], FILL[3], 1)
    love.graphics.rectangle("fill", -5, -7, 10, 14, 2, 2)
    tube(c or CYAN, 1.5, function(mode) love.graphics.rectangle(mode, -5, -7, 10, 14, 2, 2) end)
    love.graphics.circle("fill", 0, -3, 1.5)
    love.graphics.pop()
end

local function eyeBadge(cx, cy)
    local pts = {}
    for i = 0, 16 do
        local t = i / 16 * math.pi
        table.insert(pts, cx - 7 * math.cos(t)); table.insert(pts, cy - 4.5 * math.sin(t))
    end
    for i = 1, 15 do
        local t = i / 16 * math.pi
        table.insert(pts, cx + 7 * math.cos(t)); table.insert(pts, cy + 4.5 * math.sin(t))
    end
    love.graphics.setColor(FILL[1], FILL[2], FILL[3], 1)
    love.graphics.polygon("fill", pts)
    tube(CYAN, 1.5, function(mode) love.graphics.polygon(mode, pts) end)
    love.graphics.circle("fill", cx, cy, 2.2)
end

local function trashBadge(cx, cy)
    badgeDisc(cx, cy, RED)
    tube(RED, 1.25, function()
        love.graphics.line(cx - 3.5, cy - 2.5, cx + 3.5, cy - 2.5)         -- lid
        love.graphics.line(cx - 1.25, cy - 4, cx + 1.25, cy - 4)            -- handle
        love.graphics.polygon("line", cx - 2.75, cy - 1, cx + 2.75, cy - 1, -- can
            cx + 2, cy + 4, cx - 2, cy + 4)
    end)
end

local function coinBadge(cx, cy)
    badgeDisc(cx, cy, GOLD)
    tube(GOLD, 1.25, function()
        -- An "S" with a bar through it
        love.graphics.arc("line", "open", cx, cy - 1.5, 2.25, math.pi * 0.1, math.pi * 1.5, 10)
        love.graphics.arc("line", "open", cx, cy + 1.5, 2.25, -math.pi * 0.5, math.pi * 0.9, 10)
        love.graphics.line(cx, cy - 5, cx, cy + 5)
    end)
end

local function upgradeBadge(cx, cy)
    badgeDisc(cx, cy, GREEN)
    tube(GREEN, 1.5, function()
        love.graphics.line(cx, cy + 4, cx, cy - 3.5)
        love.graphics.line(cx - 3.5, cy, cx, cy - 4, cx + 3.5, cy)
    end)
end

-- Corner brackets around (x, y), pulsing in and out.
local function brackets(x, y, c)
    local pulse = (math.sin(love.timer.getTime() * 6) + 1) / 2
    local r, len = 9 + pulse * 2, 5
    tube(c, 2, function()
        for _, s in ipairs({ { -1, -1 }, { 1, -1 }, { 1, 1 }, { -1, 1 } }) do
            local cx, cy = x + s[1] * r, y + s[2] * r
            love.graphics.line(cx - s[1] * len, cy, cx, cy, cx, cy - s[2] * len)
        end
    end)
    love.graphics.setColor(c[1], c[2], c[3], 1)
    love.graphics.circle("fill", x, y, 1.75)
end

local function turretBadge(cx, cy)
    badgeDisc(cx, cy, CYAN)
    tube(CYAN, 1.25, function()
        love.graphics.circle("line", cx - 1, cy + 1, 2.5)
        love.graphics.line(cx + 0.5, cy - 0.5, cx + 4, cy - 4)
    end)
end

local function mainTurretBadge(cx, cy)
    badgeDisc(cx, cy, AMBER)
    local hex = {}
    for i = 0, 5 do
        local a = math.pi / 6 + i * math.pi / 3
        table.insert(hex, cx + math.cos(a) * 4); table.insert(hex, cy + math.sin(a) * 4)
    end
    tube(AMBER, 1.25, function(mode) love.graphics.polygon(mode, hex) end)
    love.graphics.circle("fill", cx, cy, 1.25)
end

-- -----------------------------------------------------------------------------
-- The battle reticle
-- -----------------------------------------------------------------------------

local AIM_READY = { 1, 0.2, 0.2 }
local AIM_RELOADING = { 0.55, 0.57, 0.62 }
local AIM_RADIUS = 8

-- The four ticks, with the share of the reload at which the clockwise sweep
-- (from the top) reaches each one; it gets back to the top tick when it's done
local AIM_TICKS = {
    { at = 1,    dx = 0,  dy = -1 },
    { at = 0.25, dx = 1,  dy = 0 },
    { at = 0.5,  dx = 0,  dy = 1 },
    { at = 0.75, dx = -1, dy = 0 },
}

-- Aim reticle (battlefield), centered on (x, y): a ring with four ticks and a
-- centre dot, all red when the main turret can fire. `charge` (0-1, nil =
-- ready) is its reload: after a shot the whole reticle goes grey, then red
-- fills it back in clockwise from the top (the ring, and each tick as the
-- sweep passes it) until it's all red again.
function Cursor.drawAim(x, y, charge)
    charge = charge or 1
    local ready = charge >= 1
    local r = AIM_RADIUS
    local function tick(t)
        love.graphics.line(x + t.dx * (r - 3), y + t.dy * (r - 3), x + t.dx * (r + 5), y + t.dy * (r + 5))
    end
    local function colour(isRed)
        local c = isRed and AIM_READY or AIM_RELOADING
        love.graphics.setColor(c[1], c[2], c[3], 1)
    end
    love.graphics.push("all")
    love.graphics.setLineStyle("smooth")
    -- Dark outline first so the reticle reads over bright effects
    love.graphics.setColor(0, 0, 0, 0.55)
    love.graphics.setLineWidth(3.5)
    love.graphics.circle("line", x, y, r)
    for _, t in ipairs(AIM_TICKS) do tick(t) end
    love.graphics.circle("fill", x, y, 2.5)

    love.graphics.setLineWidth(2)
    -- Ring: grey, with the reloaded part red (screen y points down, so
    -- increasing angles run clockwise)
    colour(ready)
    love.graphics.circle("line", x, y, r)
    if not ready and charge > 0 then
        colour(true)
        local start = -math.pi / 2
        love.graphics.arc("line", "open", x, y, r, start, start + charge * 2 * math.pi, 24)
    end
    -- Ticks turn red as the sweep reaches them; the dot when it's ready
    for _, t in ipairs(AIM_TICKS) do
        colour(charge >= t.at)
        tick(t)
    end
    colour(ready)
    love.graphics.circle("fill", x, y, 1.6)
    love.graphics.pop()
end

-- -----------------------------------------------------------------------------
-- Action icons
-- -----------------------------------------------------------------------------

-- The pointer with a badge beside it
local function withBadge(badge)
    return function(x, y)
        Cursor.drawArrow(x, y)
        badge(x + 15, y + 19)
    end
end

--- Aiming a turret: a dot with a clockwise rotate arrow around it.
local function drawAimTurret(x, y)
    local r = 10
    local a1, a2 = -math.pi * 0.9, math.pi * 0.35 -- clockwise sweep (screen y points down)
    local hx, hy = x + math.cos(a2) * r, y + math.sin(a2) * r
    local tx, ty = -math.sin(a2), math.cos(a2) -- direction of travel at the head
    local nx, ny = math.cos(a2), math.sin(a2)
    local head = { hx + tx * 5, hy + ty * 5, hx + nx * 4, hy + ny * 4, hx - nx * 4, hy - ny * 4 }
    tube(AMBER, 2, function()
        love.graphics.arc("line", "open", x, y, r, a1, a2, 20)
        love.graphics.polygon("line", head)
    end)
    love.graphics.setColor(AMBER[1], AMBER[2], AMBER[3], 1)
    love.graphics.polygon("fill", head)
    love.graphics.circle("fill", x, y, 2.25)
end

--- Placing a building: a block dropping onto the point.
local function drawPlaceBuilding(x, y)
    tube(GREEN, 1.75, function(mode)
        love.graphics.rectangle(mode, x - 7, y - 7, 14, 14, 2, 2)
        love.graphics.line(x - 9, y + 11, x + 9, y + 11) -- the ground it lands on
    end)
    tube(GREEN, 1.5, function()
        love.graphics.line(x, y - 4, x, y + 3)
        love.graphics.line(x - 3, y, x, y + 3.5, x + 3, y)
    end)
end

--- A card that goes anywhere (spells, global and area cards): a crosshair burst.
local function drawTargetAnywhere(x, y)
    local spin = love.timer.getTime() * 1.5
    tube(MAGENTA, 1.75, function()
        love.graphics.circle("line", x, y, 8)
        for i = 0, 3 do
            local a = spin + i * math.pi / 2
            love.graphics.line(x + math.cos(a) * 10, y + math.sin(a) * 10, x + math.cos(a) * 14, y + math.sin(a) * 14)
        end
    end)
    love.graphics.setColor(MAGENTA[1], MAGENTA[2], MAGENTA[3], 1)
    love.graphics.circle("fill", x, y, 1.75)
end

--- A card that goes on a turret or building.
local function drawTargetTurret(x, y)
    brackets(x, y, CYAN)
    turretBadge(x + 17, y + 17)
end

--- A card that goes on the main turret.
local function drawTargetMainTurret(x, y)
    brackets(x, y, AMBER)
    mainTurretBadge(x + 17, y + 17)
end

Cursor.ICONS = {
    -- In battle
    selectCard = withBadge(cardBadge),         -- hovering a card to pick (hand, rewards)
    viewPile = withBadge(eyeBadge),            -- hovering a draw / discard pile button
    placeBuilding = drawPlaceBuilding,         -- a building card waiting for its slot
    targetTurret = drawTargetTurret,           -- a card waiting for a turret / building
    targetMainTurret = drawTargetMainTurret,   -- a card waiting for the main turret
    targetAnywhere = drawTargetAnywhere,       -- a spell / global / area card
    aimTurret = drawAimTurret,                 -- the mouse is setting a turret's aim
    -- Between battles
    removeCard = withBadge(trashBadge),        -- removing a card from the deck
    buyCard = withBadge(coinBadge),            -- buying from the merchant
    upgradeCard = withBadge(upgradeBadge),     -- upgrading a card
}

--- Draws the named icon at (x, y).
function Cursor.drawIcon(name, x, y)
    love.graphics.push("all")
    Cursor.ICONS[name](x, y)
    love.graphics.pop()
end

--- Draws this frame's cursor at window pixel (rx, ry), through scalify's
--- scale and letterbox offset (main.lua calls this last each frame).
function Cursor.drawOnScreen(rx, ry)
    if not (scalify and scalify._SCALE) then return end
    local s, off = scalify._SCALE.x, scalify._OFFSET
    love.graphics.push("all")
    love.graphics.setScissor()
    -- scalify:start translates by the letterbox offset outside its push/pop, so
    -- that offset is still applied here: start again from the window's origin
    love.graphics.origin()
    love.graphics.translate(off.x, off.y)
    love.graphics.scale(s, s)
    Cursor.draw((rx - off.x) / s, (ry - off.y) / s)
    love.graphics.pop()
end

--- Draws this frame's cursor at (x, y) in virtual-canvas coordinates.
function Cursor.draw(x, y)
    local name = Cursor.current()
    if name == "reticle" then
        Cursor.drawAim(x, y, Cursor.charge)
    elseif name == "hand" then
        Cursor.drawHand(x, y)
    elseif name == "pointer" or not Cursor.ICONS[name] then
        Cursor.drawArrow(x, y)
    else
        Cursor.drawIcon(name, x, y)
    end
end

return Cursor
