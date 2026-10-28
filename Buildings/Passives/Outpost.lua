-- Outpost.lua - Passive that unlocks all 8 base slots around it when placed,
-- for free (they'd normally cost a token each), and gives the turrets in those
-- slots +10% range.

local Buff = require("Buildings.Passives.Buff")

local Outpost = setmetatable({}, Buff)
Outpost.__index = Outpost

-- The 8 surrounding cells
Outpost.SURROUNDING = {
    {-1, -1}, {0, -1}, {1, -1},
    {-1, 0},           {1, 0},
    {-1, 1},  {0, 1},  {1, 1},
}

local default = {
    name = "Outpost",
    size = 20,
    color = {0.3, 1, 0.75, 1}, -- Mint
    types = { building = true, economy = true, passive = true },
    shapePattern = {{0,0}},
    -- Applied by Buff:applyBuffs to the turrets in the surrounding slots
    effect = {
        name = "Outpost Range",
        statModifiers = { range = { mult = 0.1 } },
        duration = math.huge,
        targetTypes = { turret = true },
    },
}

function Outpost:new(config)
    config = config or {}
    for key, value in pairs(default) do
        config[key] = config[key] or value
    end
    config.affectedSlots = config.affectedSlots or Outpost.SURROUNDING

    local b = Buff:new(config)
    setmetatable(b, self)
    b.slotsUnlocked = 0
    return b
end

--- Called by Base:addBuilding once placed: unlocks the surrounding slots that
--- are still locked (ones off the edge of the grid don't exist).
function Outpost:onPlaced(base)
    local unlocked = 0
    for _, slot in ipairs(self:getAffectedSlotsFromAnchor(self.slot)) do
        if not base.buildGrid.unlocked[slot] then
            base.buildGrid.unlocked[slot] = true
            unlocked = unlocked + 1
        end
    end
    self.slotsUnlocked = unlocked

    local game = self.game
    if unlocked > 0 and game then
        if game.spawnExpandingCircle then
            game:spawnExpandingCircle(self.x, self.y, base.buildGrid.cellSize * 0.5, base.buildGrid.cellSize * 1.6,
                self.color, 0.5)
        end
        if game.spawnFloatingText then
            game:spawnFloatingText("+" .. unlocked .. " slots", self.x, self.y - 20, self.color)
        end
    end
end

function Outpost:getTooltipStrings()
    return {
        string.format("Unlocked %d surrounding slot%s", self.slotsUnlocked, self.slotsUnlocked == 1 and "" or "s"),
        "+10% range to turrets around it",
    }
end

return Outpost
