-- DamageNumber.lua
-- Floating text for damage feedback

local DamageTypes = require("Classes.DamageTypes")

local DamageNumber = {}
DamageNumber.__index = DamageNumber

-- Non-damage feedback colours; damage colours come from DamageTypes.
local typeColors = {
    heal = {0.2, 1.0, 0.2, 1},     -- Bright green for healing
    crit = {1, 0.8, 0.2, 1},
}

function DamageNumber:new(text, x, y, damageType, customColor, delay, effectiveness, damageTags)
    local obj = setmetatable({}, self)

    obj.text = tostring(text)
    obj.x = x + love.math.random(-15, 15)
    obj.y = y + love.math.random(-15, 15)
    obj.velY = -60
    obj.velX = love.math.random(-20, 20)
    obj.color = customColor or typeColors[damageType] or DamageTypes.colorFor(damageType, damageTags)
        or DamageTypes.colors.ballistic
    obj.lifetime = 1.0
    obj.maxLifetime = 1.0
    obj.delay = delay or 0
    obj.scale = 1
    obj.destroyed = false

    -- Effectiveness feedback: super-effective hits pop bigger/gold with a "!",
    -- resisted hits shrink and cool to a dim grey-blue. Only applied when no
    -- explicit color was requested (i.e. real combat damage, not UI text).
    if not customColor then
        if effectiveness == "weak" then
            obj.scale = 1.4
            obj.color = {1, 0.9, 0.3, 1}
            obj.text = obj.text .. "!"
        elseif effectiveness == "resist" then
            obj.scale = 0.8
            obj.color = {0.6, 0.65, 0.78, 1}
        end
    end

    return obj
end

function DamageNumber:update(dt)
    if self.delay > 0 then
        self.delay = self.delay - dt
        return
    end

    self.lifetime = self.lifetime - dt
    if self.lifetime <= 0 then
        self.destroyed = true
        return
    end
    
    -- Drift up and slow down
    self.x = self.x + self.velX * dt
    self.y = self.y + self.velY * dt
    self.velY = self.velY * 0.95
    self.velX = self.velX * 0.95
end

function DamageNumber:draw()
    if self.delay > 0 then return end
    
    local alpha = math.min(1, self.lifetime / (self.maxLifetime * 0.5))
    local r, g, b = self.color[1], self.color[2], self.color[3]
    local s = self.scale or 1

    love.graphics.setColor(0, 0, 0, alpha) -- shadow/outline
    love.graphics.print(self.text, self.x + 1, self.y + 1, 0, s, s)

    love.graphics.setColor(r, g, b, alpha)
    love.graphics.print(self.text, self.x, self.y, 0, s, s)

    love.graphics.setColor(1, 1, 1, 1)
end

return DamageNumber
