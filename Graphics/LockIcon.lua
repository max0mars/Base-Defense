-- LockIcon.lua - the padlock drawn on locked build slots (base and battlefield).

local LockIcon = {}

--- A small padlock centred on (cx, cy), in the current colour.
function LockIcon.draw(cx, cy)
    love.graphics.setLineWidth(2)
    love.graphics.arc("line", "open", cx, cy - 2, 4, math.pi, 2 * math.pi)
    love.graphics.line(cx - 4, cy - 2, cx - 4, cy)
    love.graphics.line(cx + 4, cy - 2, cx + 4, cy)
    love.graphics.setLineWidth(1)
    love.graphics.rectangle("fill", cx - 6, cy, 12, 8, 1, 1)
end

return LockIcon
