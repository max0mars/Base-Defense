local Buff = require("Buildings.Buffs.Buff")

local Bank = setmetatable({}, Buff)
Bank.__index = Bank

local default = {
    name = "Bank",
    size = 20,
    color = {1, 0.84, 0, 1}, -- Neon Gold
    types = { building = true, economy = true, passive = true },
    shapePattern = {{0,0}},
    affectedSlots = {{-1, 0}, {0, -1}, {1, 0}, {0, 1}}, -- Bank doesn't affect other slots
    effect = nil, -- No buff effect
    
    -- Economy specific
    tokensPerCycle = 1,
    cycleWaves = 1
}

function Bank:new(config)
    config = config or {}
    for key, value in pairs(default) do
        config[key] = config[key] or value
    end
    
    local b = Buff:new(config)
    setmetatable(b, self)
    
    b.wavesSinceLastToken = 0
    return b
end

function Bank:checkPayout()
    self.wavesSinceLastToken = self.wavesSinceLastToken + 1
    
    if self.wavesSinceLastToken >= self.cycleWaves then
        self.wavesSinceLastToken = 0
        
        -- Check if all valid affected slots in the grid are occupied
        local affectedSlots = self:getAffectedSlotsFromAnchor(self.slot)
        local allOccupied = true
        if #affectedSlots == 0 then
            allOccupied = false
        else
            for _, slot in ipairs(affectedSlots) do
                if not self.game.base.buildGrid.buildings[slot] then
                    allOccupied = false
                    break
                end
            end
        end
        
        if allOccupied then
            return self.tokensPerCycle
        end
    end
    
    return 0
end

-- We inherit Buff:draw() so it looks like other support/buff buildings (Neon Gold Diamond)

return Bank
