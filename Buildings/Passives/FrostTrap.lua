local Buff = require("Buildings.Passives.Buff")
local SlowEffect = require("Game.Effects.StatusEffects.Slow")

local FrostTrap = setmetatable({}, Buff)
FrostTrap.__index = FrostTrap

local default = {
    name = "Frost Trap",
    types = { passive = true, slow = true, control = true },
    color = {0.4, 0.6, 0.9, 1}, -- Cool bluish tone
    shapePattern = {{0, 0}},
    affectedSlots = {},
    slowAmount = 0.2,
    range = 200,
}

function FrostTrap:new(config)
    config = config or {}
    for key, value in pairs(default) do
        if config[key] == nil then
            config[key] = value
        end
    end

    local obj = Buff:new(config)
    setmetatable(obj, self)
    obj.slowAmount = config.slowAmount
    obj.range = config.range

    -- Pre-create the template to avoid table allocations each frame
    obj.slowEffectTemplate = SlowEffect:new({
        name = "slow_aura",
        amount = obj.slowAmount,
        duration = 0.2,
        hidden = true,
        maxStacks = 1
    })

    return obj
end

function FrostTrap:applyBuffs()
    -- Frost Trap slows enemies in range instead of buffing neighbours
end

function FrostTrap:update(dt)
    if self.isPreview then return end
    if not self.game or not self.game.objects or not self.slot then return end

    local cx, cy = self:getCenterPosition()
    local rSq = self.range * self.range

    for _, obj in ipairs(self.game.objects) do
        if obj:isType("enemy") and not obj.destroyed then
            local distSq = (obj.x - cx)^2 + (obj.y - cy)^2
            if distSq <= rSq and obj.effectManager then
                local existing = obj.effectManager:getEffect("slow_aura")
                if existing then
                    existing.duration = 0.2
                else
                    obj.effectManager:applyEffect(self.slowEffectTemplate, self)
                end
            end
        end
    end
end

function FrostTrap:draw(x, y)
    Buff.draw(self, x, y)

    -- Draw radius arc only when showArc or isPreview is true
    if self.showArc or self.isPreview then
        local cx, cy
        if x and y then
            cx, cy = x, y
        else
            cx, cy = self:getCenterPosition()
        end
        love.graphics.setColor(0.6, 0.8, 1, 0.2)
        love.graphics.circle("fill", cx, cy, self.range)
        love.graphics.setColor(1, 1, 1, 1)
    end
end

return FrostTrap
