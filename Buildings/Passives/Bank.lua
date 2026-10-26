local Buff = require("Buildings.Passives.Buff")

local Bank = setmetatable({}, Buff)
Bank.__index = Bank

local default = {
    name = "Bank",
    size = 20,
    color = {1, 0.84, 0, 1}, -- Neon Gold
    types = { building = true, economy = true, passive = true },
    shapePattern = {{0,0}},
    --affectedSlots = {{-1, 0}, {0, -1}, {1, 0}, {0, 1}},
    -- Explicitly no buff effect so the base Buff class never applies damage buffs
    effect = false,
    
    -- Economy specific`
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

-- Token cap bonus once the required neighbours (affectedSlots: top, bottom, right) are filled
Bank.COVERED_BONUS = 1
Bank.ALL_TURRETS_BONUS = 2

function Bank:isSurrounded()
    return self:getTokenBonus() > 0
end

--- Token cap bonus this Bank currently provides (checked when tokens refill each wave).
-- 0 unless every required neighbour is filled; more if they are all turrets.
function Bank:getTokenBonus()
    if not self.slot or not self.affectedSlots or not self.game or not self.game.base then return 0 end
    local neighbourSlots = self:getAffectedSlotsFromAnchor(self.slot)
    -- A neighbour off the edge of the grid can never be filled
    if #neighbourSlots < #self.affectedSlots then return 0 end

    local allTurrets = true
    for _, slot in ipairs(neighbourSlots) do
        local b = self.game.base.buildGrid.buildings[slot]
        if not b or b.destroyed then
            return 0
        end
        if not (b.isType and b:isType("turret")) then
            allTurrets = false
        end
    end
    return allTurrets and self.ALL_TURRETS_BONUS or self.COVERED_BONUS
end

function Bank:applyBuffs()
    -- Bank does not apply stat buffs to neighbors — economy building only
end

function Bank:getTooltipStrings()
    local bonus = self:getTokenBonus()
    if bonus == 0 then
        return { "Inactive: fill top, bottom and right" }
    end
    return { string.format("+%d Token per wave", bonus) }
end

function Bank:checkPayout()
    -- No longer used, max tokens are calculated dynamically in GameManager
    return 0
end

-- We inherit Buff:draw() but override it to change colors dynamically
function Bank:draw(drawx, drawy)
    local originalColor = self.color
    local originalDisableGlow = self.disableGlow
    
    local bonus = self:getTokenBonus()
    if bonus >= self.ALL_TURRETS_BONUS then
        self.color = {1, 0.95, 0.5, 1} -- Bright Gold: all neighbours are turrets
        self.disableGlow = false
    elseif bonus > 0 then
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
