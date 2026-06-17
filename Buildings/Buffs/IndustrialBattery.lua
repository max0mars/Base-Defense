local Buff = require("Buildings.Buffs.Buff")

local IndustrialBattery = setmetatable({}, Buff)
IndustrialBattery.__index = IndustrialBattery

local default = {
    name = "Industrial Battery",
    size = 20,
    color = {0.1, 0.8, 1, 1}, -- Neon cyan theme for energy
    types = { building = true, passive = true },
    shapePattern = {{0,0}},
    affectedSlots = {{-1, 0}, {0, 1}, {0, -1}, {1, 0}}, -- We will apply buffs dynamically in applyBuffs
    isGlobal = true, -- Applies to all buildings globally
    effect = {
        name = "Industrial Battery Power",
        statModifiers = { damage = { mult = 0.20 } }, -- +50% damage
        targetTypes = { energy = true }, -- increases all "Energy" damage
        duration = math.huge
    }
}

function IndustrialBattery:new(config)
    config = config or {}
    for key, value in pairs(default) do
        config[key] = config[key] or value
    end
    
    local b = Buff:new(config)
    setmetatable(b, self)
    
    return b
end

function IndustrialBattery:isAdjacentToMainTurret()
    if not self.slot then return false end
    local adjacent = self:getAdjacent()
    for _, adj in ipairs(adjacent) do
        if adj and adj:isType("mainturret") and not adj.destroyed then
            return true
        end
    end
    return false
end

function IndustrialBattery:applyBuffs()
    if not self.slot or self.destroyed then return end
    
    if not self:isAdjacentToMainTurret() then
        return
    end
    
    -- If adjacent, call the base Buff class applyBuffs, which applies it globally
    Buff.applyBuffs(self)
end

function IndustrialBattery:getTooltipStrings()
    local strings = {}
    if self:isAdjacentToMainTurret() then
        table.insert(strings, "ACTIVE: +50% Energy Damage")
    else
        table.insert(strings, "INACTIVE: Place adjacent to Main Turret")
    end
    return strings
end

-- Override draw to dim/disable glow when inactive
function IndustrialBattery:draw(drawx, drawy)
    local originalColor = self.color
    local originalDisableGlow = self.disableGlow
    
    -- For preview/placement (when self.slot is nil), show it active or check if adjacent to target slot
    local isActive = false
    if self.slot then
        isActive = self:isAdjacentToMainTurret()
    else
        -- Preview mode
        isActive = true -- Highlight active during preview so user sees color
    end
    
    if isActive then
        self.color = {0.1, 0.8, 1, 1}
        self.disableGlow = false
    else
        self.color = {0.4, 0.4, 0.4, 1}
        self.disableGlow = true
    end
    
    Buff.draw(self, drawx, drawy)
    
    self.color = originalColor
    self.disableGlow = originalDisableGlow
end

return IndustrialBattery
