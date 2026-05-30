-- Cursor.lua: custom in-game cursors. The OS cursor is hidden during gameplay,
-- so we draw our own: a red aim dot over the battlefield and a normal arrow
-- pointer everywhere else (HUD, menus, pause panel).

local Cursor = {}

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
