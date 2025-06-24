local Base = {
    x, y, w, h,
    hp,
    maxHp, -- Add maxHp to track maximum health
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
    
    -- Draw health bar
    self:drawHealthBar()
end

function Base:drawHealthBar()
    if not self.maxHp or self.maxHp <= 0 then return end
    
    local barWidth = self.w
    local barHeight = 8
    local barX = self.x
    local barY = self.y - barHeight - 5 -- Position above the base
    
    -- Calculate health percentage
    local healthPercent = math.max(0, self.hp / self.maxHp)
    
    -- Draw background (dark red)
    love.graphics.setColor(0.3, 0.1, 0.1, 0.8)
    love.graphics.rectangle("fill", barX, barY, barWidth, barHeight)
    
    -- Draw health bar with color based on health percentage
    local r, g, b = 0.2, 0.8, 0.2  -- Green
    if healthPercent < 0.6 then
        r, g, b = 0.8, 0.8, 0.2  -- Yellow
    end
    if healthPercent < 0.3 then
        r, g, b = 0.8, 0.2, 0.2  -- Red
    end
    
    love.graphics.setColor(r, g, b, 0.9)
    love.graphics.rectangle("fill", barX, barY, barWidth * healthPercent, barHeight)
    
    -- Draw border
    love.graphics.setColor(0, 0, 0, 1)
    love.graphics.rectangle("line", barX, barY, barWidth, barHeight)
    
    -- Draw HP text
    love.graphics.setColor(1, 1, 1, 1)
    local hpText = string.format("%d/%d", math.max(0, self.hp), self.maxHp)
    local font = love.graphics.getFont()
    local textWidth = font:getWidth(hpText)
    love.graphics.print(hpText, barX + (barWidth - textWidth)/2, barY - 2)
    
    -- Reset color
    love.graphics.setColor(1, 1, 1, 1)
end

function Base:takeDamage(damage)
    self.hp = self.hp - damage
    -- Ensure HP doesn't go below 0
    self.hp = math.max(0, self.hp)
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