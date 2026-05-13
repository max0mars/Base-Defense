local Blocker = require("Buildings.Blockers.Blocker")
local SlowEffect = require("Game.Effects.StatusEffects.Slow")

local SlowBlocker = setmetatable({}, Blocker)
SlowBlocker.__index = SlowBlocker

local default = {
    name = "Frost Trap",
    slowAmount = 0.2,
    range = 100,
    shapePattern = { {0, 0} },
    color = {0.4, 0.6, 0.9, 1}, -- Nice cool bluish tone for the base blocker
}

function SlowBlocker:new(config)
    config = config or {}
    for key, value in pairs(default) do
        if config[key] == nil then
            config[key] = value
        end
    end
    
    local obj = setmetatable(Blocker.new(self, config), { __index = self })
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

function SlowBlocker:update(dt)
    if self.isPreview then return end
    
    if not self.game or not self.game.objects then return end
    
    local cx, cy = self:getCenterPosition()
    local rSq = self.range * self.range
    
    for _, obj in ipairs(self.game.objects) do
        if obj:isType("enemy") and not obj.destroyed then
            local distSq = (obj.x - cx)^2 + (obj.y - cy)^2
            if distSq <= rSq then
                if obj.effectManager then
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
end

function SlowBlocker:draw(x, y)
    -- Call parent Blocker draw logic
    Blocker.draw(self, x, y)
    
    local cx, cy
    if x and y then
        cx, cy = x, y
    else
        cx, cy = self:getCenterPosition()
    end
    
    -- Add a small distinct icon (small icy circle inside the cell)
    love.graphics.setColor(0.6, 0.8, 1, 1)
    love.graphics.circle("fill", cx, cy, 5)
    love.graphics.setColor(1, 1, 1, 1)
    
    -- Draw radius arc only when showArc or isPreview is true
    if self.showArc or self.isPreview then
        love.graphics.setColor(0.6, 0.8, 1, 0.2)
        love.graphics.circle("fill", cx, cy, self.range)
        love.graphics.setColor(1, 1, 1, 1)
    end
end

return SlowBlocker
