local Buff = require("Buildings.Buffs.Buff")

local Bank = setmetatable({}, Buff)
Bank.__index = Bank

local default = {
    name = "Bank",
    size = 20,
    color = {1, 0.84, 0, 1}, -- Neon Gold
    types = { building = true, economy = true, passive = true },
    shapePattern = {{0,0}},
    affectedSlots = {{-1, 0}, {0, -1}, {1, 0}, {0, 1}},
    -- Explicitly no buff effect so the base Buff class never applies damage buffs
    effect = false,
    
    -- Economy specific
    tokensPerCycle = 1,
    cycleWaves = 1
}

function Bank:new(config)
    config = config or {}
    for key, value in pairs(default) do
        config[key] = config[key] or value
    end
    
    -- Pass effect=nil to Buff:new so it never applies any stat modifier
    config.effect = nil
    
    local b = Buff:new(config)
    setmetatable(b, self)
    
    b.wavesSinceLastToken = 0
    return b
end

function Bank:isSurrounded()
    if not self.slot then return false end
    local affectedSlots = self:getAffectedSlotsFromAnchor(self.slot)
    if #affectedSlots < #self.affectedSlots then return false end
    for _, slot in ipairs(affectedSlots) do
        local b = self.game.base.buildGrid.buildings[slot]
        if not b or b.destroyed then
            return false
        end
    end
    return true
end

function Bank:applyBuffs()
    -- Bank does not apply stat buffs to neighbors — economy building only
end

function Bank:getTooltipStrings()
    local strings = {}
    if self:isSurrounded() then
        table.insert(strings, "+1 token per wave")
    end
    return strings
end

function Bank:checkPayout()
    self.wavesSinceLastToken = self.wavesSinceLastToken + 1
    
    if self.wavesSinceLastToken >= self.cycleWaves then
        self.wavesSinceLastToken = 0
        
        if self:isSurrounded() then
            return self.tokensPerCycle
        end
    end
    
    return 0
end

-- We inherit Buff:draw() but override it to change colors dynamically
function Bank:draw(drawx, drawy)
    local originalColor = self.color
    local originalDisableGlow = self.disableGlow
    
    if self:isSurrounded() then
        self.color = {1, 0.84, 0, 1} -- Neon Gold
        self.disableGlow = false
    else
        self.color = {0.4, 0.4, 0.4, 1} -- Inactive Grey
        self.disableGlow = true
    end
    
    Buff.draw(self, drawx, drawy)
    
    self.color = originalColor
    self.disableGlow = originalDisableGlow
end

return Bank
