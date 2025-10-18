local Turret = require("Buildings.Turrets.Turret")
local Mortar = setmetatable({}, Turret)
Mortar.__index = Mortar


local default = {
    damage = 50,
    bulletType = require("Bullets.Mortar_Bullet"),
    fireRate = 4, -- seconds between shots
    cooldown = 0, -- cooldown timer
    mode = "auto",
    type = "turret",
}

function Mortar:new(config)
    config = config or {}
    for key, value in pairs(default) do
        config[key] = config[key] or value
    end
    local t = setmetatable(Turret:new(config), { __index = self })
    return t
end

-- function Mortar:mousepressed(x, y, button)
--     if button == 1 then -- Left mouse button
--         self:fire(self.x, self.y, x, y)
--     end
-- end

-- function Mortar:fire(x, y, targetX, targetY)
--     if self.cooldown <= 0 then
--         local newBullet = self.bullet:new(x, y, targetX, targetY)
--         table.insert(self.bullets, newBullet)
--         self.cooldown = self.fireRate -- Reset cooldown after firing
--     end
-- end

-- function Mortar:update(dt, enemies, effects)
--     self.cooldown = self.cooldown - dt
--     if self.mode == 1 and self.cooldown <= 0 then
--         local targetX, targetY = love.mouse.getPosition() -- Get mouse position for targeting
--         self:fire(self.x, self.y, targetX, targetY)
--     end
-- end

-- function Mortar:UpdateBullets()
--     for i = #self.bullets, 1, -1 do
--         local bullet = self.bullets[i]
--         bullet:update(dt, enemies, effects)
--         if bullet.destroyed == 1 then
--             table.remove(self.bullets, i) -- Remove bullet if it goes out of bounds
--         end
--     end
-- end

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
    -- Draw the mortar itself
    love.graphics.setColor(1, 1, 0) -- Yellow color for the mortar
    love.graphics.circle("fill", self.x, self.y, 10) -- Draw the mortar as a circle
    
    -- Draw reload bar
    self:drawReloadBar()
    
    -- Reset color
    love.graphics.setColor(1, 1, 1, 1)
end

-- function Mortar:getTarget(enemies)
--     local dist = 1000000000
--     self.target = nil -- Reset target for each update
--     for _, enemy in ipairs(enemies) do
--         if enemy.x and enemy.y then
--             local newdist = (enemy.x - self.x)^2 + (enemy.y - self.y)^2 -- Calculate squared distance to avoid sqrt for performance
--             if(newdist < dist) then
--                 dist = newdist -- Calculate distance to the enemy
--                 self.target = enemy
--             end
--         end
--     end
-- end

return Mortar