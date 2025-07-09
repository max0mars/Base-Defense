local Mortar = {
    
}

function Mortar:new(x, y)
    local obj = {
        x = x, 
        y = y, 
        damage = 50,
        bullet = require("Mortar_Bullet"), -- Assuming you have a Mortar_Bullet module
        bullets = {},
        fireRate = 2, -- seconds between shots
        cooldown = 0, -- cooldown timer
        mode = 0
    }
    setmetatable(obj, {__index = self})
    return obj
end

function Mortar:mousepressed(x, y, button)
    if button == 1 then -- Left mouse button
        self:fire(self.x, self.y, x, y)
    end
end

function Mortar:fire(x, y, targetX, targetY)
    if self.cooldown <= 0 then
        local newBullet = self.bullet:new(x, y, targetX, targetY)
        table.insert(self.bullets, newBullet)
        self.cooldown = self.fireRate -- Reset cooldown after firing
    end
end

function Mortar:update(dt, enemies, effects)
    self.cooldown = self.cooldown - dt
    if self.mode == 1 and self.cooldown <= 0 then
        local targetX, targetY = love.mouse.getPosition() -- Get mouse position for targeting
        self:fire(self.x, self.y, targetX, targetY)
    end
    for i = #self.bullets, 1, -1 do
        local bullet = self.bullets[i]
        bullet:update(dt, enemies, effects)
        if bullet.destroyed == 1 then
            table.remove(self.bullets, i) -- Remove bullet if it goes out of bounds
        end
    end
end

function Mortar:drawReloadBar()
    -- Only show reload bar if reloading
    if self.cooldown > 0 then
        local barWidth = 30
        local barHeight = 4
        local barX = self.x - barWidth/2
        local barY = self.y - 20  -- Position above the mortar
        
        
        local reloadProgress = 1 - (self.cooldown / self.fireRate)
        
        -- Draw background (dark grey)
        love.graphics.setColor(0.3, 0.3, 0.3, 0.8)
        love.graphics.rectangle("fill", barX, barY, barWidth, barHeight)
        
        -- Draw reload progress (grey)
        love.graphics.setColor(0.6, 0.6, 0.6, 0.9)
        love.graphics.rectangle("fill", barX, barY, barWidth * reloadProgress, barHeight)
        
        -- Draw border
        love.graphics.setColor(0, 0, 0, 1)
        love.graphics.rectangle("line", barX, barY, barWidth, barHeight)
    end
end

function Mortar:draw()
    for _, b in ipairs(self.bullets) do
        b:draw()
    end
    -- Draw the mortar itself
    love.graphics.setColor(1, 1, 0) -- Yellow color for the mortar
    love.graphics.circle("fill", self.x, self.y, 10) -- Draw the mortar as a circle
    
    -- Draw reload bar
    self:drawReloadBar()
    
    -- Reset color
    love.graphics.setColor(1, 1, 1, 1)
end

return Mortar