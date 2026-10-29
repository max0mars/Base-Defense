-- SlotVisuals.lua - how build slots look, shared by the base grid and the lane
-- border slots so both follow the same rules:
--   locked   a padlock, green if the player can afford the unlock and red if
--            not (while placing a card: the unlock plus the card); while
--            placing, a red tint where it can't go and a dim cyan pad where it
--            can; hovered outside placement, a green / red highlight
--   empty    a cyan pad while placing a card; hovered, a blue highlight

local LockIcon = require("Graphics.LockIcon")

local SlotVisuals = {}

--- Whether the player can pay `price` to unlock a slot: while placing a card
--- (whose cost is paid too) that's unlock + card, otherwise just the unlock.
function SlotVisuals.canAffordUnlock(game, price)
    if game.inputMode == "placing" then
        return game:canAffordPlacement(price)
    end
    return (game.tokens or 0) >= price
end

local function outline(r, g, b, a, sx, sy, cs)
    love.graphics.setColor(r, g, b, a)
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", sx + 1, sy + 1, cs - 2, cs - 2)
    love.graphics.setLineWidth(1)
end

-- "A card can go here" while placing, `strength` 1 for open slots, 0.5 for locked ones
local function placementPad(sx, sy, cs, strength)
    love.graphics.setColor(0, 1, 1, 0.2 * strength)
    love.graphics.rectangle("fill", sx + 2, sy + 2, cs - 4, cs - 4)
    love.graphics.setColor(0, 1, 1, 0.5 * strength)
    love.graphics.rectangle("line", sx + 2, sy + 2, cs - 4, cs - 4)
end

--- The slot's frame: grey when unlocked (`price` nil), else green / red like its padlock.
function SlotVisuals.drawFrame(game, sx, sy, cs, price)
    if not price then
        love.graphics.setColor(0.5, 0.5, 0.5, 0.5)
    elseif SlotVisuals.canAffordUnlock(game, price) then
        love.graphics.setColor(0, 0.5, 0)
    elseif game.inputMode == "placing" then
        love.graphics.setColor(1, 0.3, 0.3)
    else
        love.graphics.setColor(0.5, 0, 0)
    end
    love.graphics.rectangle("line", sx, sy, cs, cs)
end

--- A locked slot at (sx, sy), `cs` across, that costs `price` to unlock.
function SlotVisuals.drawLocked(game, sx, sy, cs, price, hovered)
    local placing = game.inputMode == "placing"
    local affordable = SlotVisuals.canAffordUnlock(game, price)
    love.graphics.setColor(0.1, 0.1, 0.1)
    love.graphics.rectangle("fill", sx, sy, cs, cs)
    if placing and not affordable then
        -- Can't place here: tint the whole slot red
        love.graphics.setColor(0.9, 0.2, 0.2, 0.28)
        love.graphics.rectangle("fill", sx, sy, cs, cs)
    elseif placing then
        placementPad(sx, sy, cs, 0.5)
    end

    if affordable then
        love.graphics.setColor(0, 0.5, 0) -- faint green
    elseif placing then
        love.graphics.setColor(1, 0.3, 0.3) -- red
    else
        love.graphics.setColor(0.5, 0, 0) -- faint red
    end
    LockIcon.draw(sx + cs / 2, sy + cs / 2)

    if hovered and not placing then
        if affordable then love.graphics.setColor(0.2, 0.9, 0.4, 0.20)
        else love.graphics.setColor(0.9, 0.3, 0.3, 0.20) end
        love.graphics.rectangle("fill", sx, sy, cs, cs)
        if affordable then outline(0.3, 1.0, 0.5, 0.95, sx, sy, cs)
        else outline(1.0, 0.4, 0.4, 0.95, sx, sy, cs) end
    end
end

--- An unlocked slot at (sx, sy) with nothing on it.
function SlotVisuals.drawEmpty(game, sx, sy, cs, hovered)
    if game.inputMode == "placing" then
        placementPad(sx, sy, cs, 1)
    end
    if hovered and game.inputMode ~= "placing" then
        love.graphics.setColor(0.4, 0.7, 1.0, 0.16)
        love.graphics.rectangle("fill", sx, sy, cs, cs)
        outline(0.5, 0.8, 1.0, 0.9, sx, sy, cs)
    end
end

return SlotVisuals
