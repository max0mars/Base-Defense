local Mortar = {
    x, y, 
    damage = 50,
    bullet = require("Mortar_Bullet"), -- Assuming you have a Mortar_Bullet module
    bullets = {},
    fireRate = 1, -- seconds between shots
    cooldown = 0 -- cooldown timer
}

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
    for i = #self.bullets, 1, -1 do
        local bullet = self.bullets[i]
        bullet:update(dt, enemies, effects)
        if bullet.destroyed == 1 then
            table.remove(self.bullets, i) -- Remove bullet if it goes out of bounds
        end
    end
end

-- function Mortar:fire(targetX, targetY)
--     table.insert(self.bullets, self.bullet:new(self.x, self.y, targetX, targetY))
-- end

function Mortar:draw()
    for _, b in ipairs(self.bullets) do
        b:draw()
    end
    -- Optionally, draw the mortar itself
    love.graphics.setColor(1, 1, 0) -- Yellow color for the mortar
    love.graphics.circle("fill", self.x, self.y, 10) -- Draw the mortar as a circle
end

return Mortar