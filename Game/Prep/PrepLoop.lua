-- Game/Prep/PrepLoop.lua
-- Which screen the preparation phase shows. Battles run in loops of five, and
-- the screen depends on which battle of the loop was just finished:
--   1 a quote, 2 the merchant, 3 the alchemist, 4 the merchant, 5 major upgrades

local PrepLoop = {}

PrepLoop.LENGTH = 5
PrepLoop.SCREENS = { "quote", "merchant", "alchemist", "merchant", "upgrades" }

--- The screen shown after `battlesCompleted` battles.
function PrepLoop.screenAfter(battlesCompleted)
    if (battlesCompleted or 0) < 1 then return "quote" end
    return PrepLoop.SCREENS[(battlesCompleted - 1) % PrepLoop.LENGTH + 1]
end

--- State for the current preparation phase (merchant stock, alchemist offers,
--- the quote...). Kept until the next battle, so leaving and coming back
--- doesn't reroll anything.
function PrepLoop.getVisit()
    local ps = _G.PersistentState
    local battle = ps.battlesCompleted or 0
    if not ps.prepVisit or ps.prepVisit.battle ~= battle then
        ps.prepVisit = { battle = battle, screen = PrepLoop.screenAfter(battle) }
    end
    return ps.prepVisit
end

return PrepLoop
