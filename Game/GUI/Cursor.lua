-- Cursor.lua: in-game cursor policy. We use the real OS system cursors (the same
-- crisp hand/arrow the main menu uses) over the HUD and menus, and hide the OS
-- cursor to draw custom ones in battle: an aim reticle over the battlefield
-- during a wave, and icons for what the player is doing (see Cursor.ICONS).

local Cursor = {}

-- Set true (via Cursor.hover) when the mouse is over a clickable element this
-- frame; the cursor then renders as a hand. Reset at the start of each frame.
Cursor.wantHand = false
-- Set (via Cursor.setIcon) by HUD elements whose hover gets its own icon this frame
Cursor.icon = nil
function Cursor.reset() Cursor.wantHand = false; Cursor.icon = nil end

--- Asks for one of the icons in Cursor.ICONS this frame (over Cursor.wantHand).
function Cursor.setIcon(name) Cursor.icon = name end

-- Lazily-created OS system cursors, shared across every scene so the in-game
-- pointer matches the main menu exactly.
local handCursor, arrowCursor
function Cursor.hand()
    if not handCursor then handCursor = love.mouse.getSystemCursor("hand") end
    return handCursor
end
function Cursor.arrow()
    if not arrowCursor then arrowCursor = love.mouse.getSystemCursor("arrow") end
    return arrowCursor
end

-- Apply the appropriate OS cursor for clickable/idle UI (hand if hovering a
-- clickable this frame, arrow otherwise) and make sure it is visible.
function Cursor.applyOS()
    love.mouse.setVisible(true)
    love.mouse.setCursor(Cursor.wantHand and Cursor.hand() or Cursor.arrow())
end

-- Flags a hand cursor if the current mouse position is inside the given rect.
function Cursor.hover(x, y, w, h)
    local mx, my = love.mouse.getPosition()
    if mx >= x and mx < x + w and my >= y and my < y + h then
        Cursor.wantHand = true
        return true
    end
    return false
end

-- Pointing-hand cursor (fingertip at x, y).
function Cursor.drawHand(x, y)
    local parts = {
        { x + 1, y,      5, 14, 2 }, -- index finger
        { x - 1, y + 8, 13, 13, 4 }, -- palm
        { x - 4, y + 11, 5,  7, 2 }, -- thumb
    }
    love.graphics.push("all")
    love.graphics.setColor(0, 0, 0, 0.65)
    for _, p in ipairs(parts) do love.graphics.rectangle("fill", p[1] + 1, p[2] + 1, p[3], p[4], p[5]) end
    love.graphics.setColor(1, 1, 1, 1)
    for _, p in ipairs(parts) do love.graphics.rectangle("fill", p[1], p[2], p[3], p[4], p[5]) end
    love.graphics.pop()
end

-- Standard arrow pointer with its tip at (x, y).
function Cursor.drawArrow(x, y)
    local pts = {
        x,        y,
        x,        y + 16,
        x + 4,    y + 12,
        x + 7,    y + 18,
        x + 9.5,  y + 17,
        x + 6.5,  y + 11,
        x + 11,   y + 11,
    }
    love.graphics.push("all")
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.polygon("fill", pts)
    love.graphics.setColor(0, 0, 0, 0.9)
    love.graphics.setLineWidth(1.5)
    love.graphics.polygon("line", pts)
    love.graphics.pop()
end

local AIM_READY = { 1, 0.2, 0.2 }
local AIM_RELOADING = { 0.55, 0.57, 0.62 }
local AIM_RADIUS = 8

-- Aim reticle (battlefield), centered on (x, y): a ring with four ticks and a
-- centre dot. `charge` (0-1, nil = ready) is the main turret's reload: while
-- reloading the reticle is grey and a red arc fills the ring clockwise from
-- the top; once full it turns red again.
function Cursor.drawAim(x, y, charge)
    local ready = charge == nil or charge >= 1
    local c = ready and AIM_READY or AIM_RELOADING
    local r = AIM_RADIUS
    love.graphics.push("all")
    -- Dark outline first so the reticle reads over bright effects
    for pass = 1, 2 do
        if pass == 1 then
            love.graphics.setColor(0, 0, 0, 0.6)
            love.graphics.setLineWidth(3.5)
        else
            love.graphics.setColor(c[1], c[2], c[3], 1)
            love.graphics.setLineWidth(1.5)
        end
        love.graphics.circle("line", x, y, r)
        love.graphics.line(x, y - r - 4, x, y - r + 3)
        love.graphics.line(x, y + r - 3, x, y + r + 4)
        love.graphics.line(x - r - 4, y, x - r + 3, y)
        love.graphics.line(x + r - 3, y, x + r + 4, y)
        love.graphics.circle("fill", x, y, pass == 1 and 2 or 1.25)
    end
    -- Reload progress: screen y points down, so increasing angles run clockwise
    if not ready and charge > 0 then
        local a = AIM_READY
        love.graphics.setColor(a[1], a[2], a[3], 1)
        love.graphics.setLineWidth(2)
        local start = -math.pi / 2
        love.graphics.arc("line", "open", x, y, r, start, start + charge * 2 * math.pi, 24)
    end
    love.graphics.pop()
end

-- -----------------------------------------------------------------------------
-- Action icons
-- -----------------------------------------------------------------------------

local CYAN = { 0.0, 0.85, 1.0 }
local AMBER = { 1.0, 0.7, 0.15 }

-- Draws `shape()` twice: a dark outline, then in colour `c`.
local function outlined(c, width, shape)
    love.graphics.setColor(0, 0, 0, 0.7)
    love.graphics.setLineWidth(width + 2)
    shape("line")
    love.graphics.setColor(c[1], c[2], c[3], 1)
    love.graphics.setLineWidth(width)
    shape("line")
end

-- A small playing card, top-left at (x, y).
local function cardBadge(x, y)
    love.graphics.push()
    love.graphics.translate(x + 5, y + 7)
    love.graphics.rotate(math.rad(12))
    love.graphics.setColor(0.08, 0.12, 0.18, 1)
    love.graphics.rectangle("fill", -5, -7, 10, 14, 2, 2)
    outlined(CYAN, 1.5, function(mode) love.graphics.rectangle(mode, -5, -7, 10, 14, 2, 2) end)
    love.graphics.circle("fill", 0, -3, 1.5)
    love.graphics.pop()
end

-- An eye, centred on (cx, cy).
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
    love.graphics.setColor(0.08, 0.12, 0.18, 1)
    love.graphics.polygon("fill", pts)
    outlined(CYAN, 1.5, function(mode) love.graphics.polygon(mode, pts) end)
    love.graphics.circle("fill", cx, cy, 2.2)
end

--- Selecting a card: the pointer with a card beside it.
local function drawSelectCard(x, y)
    Cursor.drawArrow(x, y)
    cardBadge(x + 10, y + 12)
end

--- Checking a pile: the pointer with an eye beside it.
local function drawViewPile(x, y)
    Cursor.drawArrow(x, y)
    eyeBadge(x + 17, y + 20)
end

--- Targeting a card: corner brackets closing in on the point.
local function drawTargetCard(x, y)
    local pulse = (math.sin(love.timer.getTime() * 6) + 1) / 2
    local r, len = 9 + pulse * 2, 5
    outlined(CYAN, 2, function()
        for _, s in ipairs({ { -1, -1 }, { 1, -1 }, { 1, 1 }, { -1, 1 } }) do
            local cx, cy = x + s[1] * r, y + s[2] * r
            love.graphics.line(cx - s[1] * len, cy, cx, cy, cx, cy - s[2] * len)
        end
    end)
    love.graphics.circle("fill", x, y, 1.75)
end

--- Aiming a turret: a dot with a clockwise rotate arrow around it.
local function drawAimTurret(x, y)
    local r = 10
    local a1, a2 = -math.pi * 0.9, math.pi * 0.35 -- clockwise sweep (screen y points down)
    local hx, hy = x + math.cos(a2) * r, y + math.sin(a2) * r
    local tx, ty = -math.sin(a2), math.cos(a2) -- direction of travel at the head
    local nx, ny = math.cos(a2), math.sin(a2)
    local head = { hx + tx * 5, hy + ty * 5, hx + nx * 4, hy + ny * 4, hx - nx * 4, hy - ny * 4 }
    outlined(AMBER, 2, function()
        love.graphics.arc("line", "open", x, y, r, a1, a2, 20)
        love.graphics.polygon("line", head)
    end)
    love.graphics.polygon("fill", head)
    love.graphics.circle("fill", x, y, 2.25)
end

Cursor.ICONS = {
    selectCard = drawSelectCard, -- hovering a card in the hand
    viewPile = drawViewPile,     -- hovering a draw / discard pile button
    targetCard = drawTargetCard, -- a played card is waiting for its target
    aimTurret = drawAimTurret,   -- the mouse is setting a turret's aim
}

--- Draws the named icon at the mouse, hiding the OS cursor.
function Cursor.drawIcon(name, x, y)
    love.mouse.setVisible(false)
    love.graphics.push("all")
    Cursor.ICONS[name](x, y)
    love.graphics.pop()
end

return Cursor
