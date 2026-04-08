local Blocker = require("Buildings.Blockers.Blocker")
local Utils = require("Classes.Utils")

local SlottedBlocker = setmetatable({}, { __index = Blocker })
SlottedBlocker.__index = SlottedBlocker

local default = {
    name = "Platform Blocker",
    types = { blocker = true, slotted = true },
    color = { 0.6, 0.6, 0.7, 1 },
    cost = 200,
    -- Footprint: The tiles occupied by the blocker itself (relative to anchor 0,0)
    shapePattern = {
        {0, -1}, 
        {0, 0}, 
        {0, 1},
    },
    -- turretSlots: Relative coordinates where turrets can be placed
    turretSlots = {
        {0, 0}
    },
}

function SlottedBlocker:new(config)
    config = config or {}
    local baseConfig = Utils.deepCopy(default)
    for k, v in pairs(config) do
        baseConfig[k] = v
    end
    
    local obj = Blocker:new(baseConfig)
    setmetatable(obj, { __index = self })
    
    obj.managedSlots = {} -- Absolute slot IDs being managed
    obj.turretSlots = baseConfig.turretSlots
    
    return obj
end

function SlottedBlocker:onPlaced(anchorSlot)
    local grid = self.game.battlefieldGrid
    local gridWidth = grid.width
    
    -- Convert relative turret slots to absolute IDs
    local anchorI = ((anchorSlot - 1) % gridWidth)
    local anchorJ = math.floor((anchorSlot - 1) / gridWidth)
    
    for _, rel in ipairs(self.turretSlots) do
        local absI = anchorI + rel[1]
        local absJ = anchorJ + rel[2]
        
        if absI >= 0 and absI < gridWidth and absJ >= 0 and absJ < grid.height then
            local absSlot = absJ * gridWidth + absI + 1
            table.insert(self.managedSlots, absSlot)
            grid.unlocked[absSlot] = true -- Allow turret placement
        end
    end
    
    -- Critical: Force re-calc so neighbors see the new buildable area
    self.game:recalculateAllBuffs()
end

function SlottedBlocker:onRemoved()
    local grid = self.game.battlefieldGrid
    
    -- 1. Identify and destroy any turrets on my slots
    for _, slotID in ipairs(self.managedSlots) do
        local building = grid.buildings[slotID]
        if building and building ~= self then
            building:remove() -- Standard cleanup
        end
        
        -- 2. Re-lock the slot
        grid.unlocked[slotID] = false
    end
    
    self.managedSlots = {}
    
    -- 3. Force re-calc
    self.game:recalculateAllBuffs()
end

-- Draw behind: handled if added early, or we can force it here
function SlottedBlocker:draw(x, y)
    Blocker.draw(self, x, y)
    
    -- Draw slot indicators
    if self.isPreview or self.selected then
        local drawX = x or self.x
        local drawY = y or self.y
        local w = (self.buildGrid and self.buildGrid.cellSize) or 25
        local h = (self.buildGrid and self.buildGrid.cellSize) or 25
        
        love.graphics.setColor(0, 1, 1, 0.4)
        for _, rel in ipairs(self.turretSlots) do
            local ox = rel[1] * w
            local oy = rel[2] * h
            love.graphics.rectangle("line", drawX + ox - w/2 + 2, drawY + oy - h/2 + 2, w - 4, h - 4)
        end
        love.graphics.setColor(1, 1, 1, 1)
    end
end

return SlottedBlocker
