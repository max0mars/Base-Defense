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

--- Called once placed (on the base or a lane border): unlocks the surrounding
--- slots of its own grid that are still locked. Cells off the edge of the grid,
--- or that can't be built on (between the lane border slots), aren't slots.
function Outpost:onPlaced()
    local grid = self.buildGrid
    local unlocked = 0
    for _, slot in ipairs(self:getAffectedSlotsFromAnchor(self.slot)) do
        local isSlot = not grid.isBuildSlot or grid:isBuildSlot(slot)
        if isSlot and not grid.unlocked[slot] then
            grid.unlocked[slot] = true
            unlocked = unlocked + 1
        end
    end
    self.slotsUnlocked = unlocked

    local game = self.game
    if unlocked > 0 and game then
        if game.spawnExpandingCircle then
            game:spawnExpandingCircle(self.x, self.y, grid.cellSize * 0.5, grid.cellSize * 1.6,
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

-- Sprite: a flag planted on a mound, with corner brackets for the slots it opens
function Outpost:drawShape(cx, cy, s)
    local poleX = cx - s * 0.4
    local wave = math.sin(love.timer.getTime() * 3) * s * 0.12
    love.graphics.line(poleX, cy + s * 0.74, poleX, cy - s)
    love.graphics.polygon("line", poleX, cy - s, cx + s * 0.85, cy - s * 0.65 + wave, poleX, cy - s * 0.25)
    love.graphics.arc("line", "open", cx, cy + s * 1.6, s * 0.95, math.pi * 1.2, math.pi * 1.8)
end

function Outpost:drawDetail(cx, cy, s)
    local k = s * 0.3
    for _, sx in ipairs({ -1, 1 }) do
        for _, sy in ipairs({ -1, 1 }) do
            local x, y = cx + sx * s, cy + sy * s
            love.graphics.line(x - sx * k, y, x, y, x, y - sy * k)
        end
    end
end

return Outpost
