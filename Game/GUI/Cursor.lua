-- Cursor.lua: in-game cursor policy. We use the real OS system cursors (the same
-- crisp hand/arrow the main menu uses) over the HUD and menus, and hide the OS
-- cursor to draw a custom red aim dot only over the live battlefield.

local Cursor = {}

-- Set true (via Cursor.hover) when the mouse is over a clickable element this
-- frame; the cursor then renders as a hand. Reset at the start of each frame.
Cursor.wantHand = false
function Cursor.reset() Cursor.wantHand = false end

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

-- Red aim dot (battlefield), centered on (x, y).
function Cursor.drawAim(x, y)
    love.graphics.push("all")
    love.graphics.setColor(1, 0, 0, 1)
    love.graphics.circle("fill", x, y, 3)
    love.graphics.pop()
end

return Cursor
