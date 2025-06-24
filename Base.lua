local Base = {
    x, y, w, h,
    hp,
    color = {love.math.colorFromBytes(69, 69, 69)},
    turrets = {},-- table of turrets
}

function Base:update(dt)
    for _, turret in ipairs(self.turrets) do
        if turret.update then
            turret:update(dt)
        end
    end
end

function Base:draw()
    love.graphics.setColor(self.color)
    love.graphics.rectangle("fill", self.x, self.y, self.w, self.h)
end

function Base:takeDamage(damage)
    self.hp = self.hp - damage
end

function Base:keypressed(key)
    for _, turret in ipairs(self.turrets) do
        if turret.keypressed then
            turret:keypressed(key)
        end
    end
end

function Base:mousepressed(x, y, button)
    for _, turret in ipairs(self.turrets) do
        if turret.mousepressed then
            turret:mousepressed(x, y, button)
        end
    end
end

function Base:getX()
    return self.x + self.w -- returns the right edge of the base
end

return Base