local Auto_Mortar = {
    x, y, 
    damage = 50,
    bullets = {},
    fireRate = 1, -- seconds between shots
    cooldown = 0 -- cooldown timer
}

-- function Auto_Mortar:mousepressed(x, y, button)
--     if button == 1 then -- Left mouse button
--         self:fire(self.x, self.y, x, y)
--     end
-- end

function Auto_Mortar:fire(x, y, targetX, targetY)
    if self.cooldown <= 0 then
        local newBullet = self.bullet:new(x, y, targetX, targetY, self.damage)
        table.insert(self.bullets, newBullet)
        self.cooldown = self.fireRate -- Reset cooldown after firing
    end
end

function Auto_Mortar:new(x, y, fireRate)
    local obj = setmetatable({}, {__index = self})
    obj.x = x or 0
    obj.y = y or 0
    obj.fireRate = fireRate or 1 -- Default fire rate if not provided
    obj.cooldown = 0 -- Initialize cooldown
    obj.bullets = {} -- Initialize bullets table
    obj.bullet = require("Mortar_Bullet"):newInstance() -- Assuming you have a Mortar_Bullet module
    return obj
end

function Auto_Mortar:update(dt, enemies, effects)
    local dist = 1000000000
    self.target = nil -- Reset target for each update
    for _, enemy in ipairs(enemies) do
        if enemy.x and enemy.y then
            local newdist = (enemy.x - self.x)^2 + (enemy.y - self.y)^2 -- Calculate squared distance to avoid sqrt for performance
            if(newdist < dist) then
                dist = newdist -- Calculate distance to the enemy
                self.target = enemy
            end
        end
    end
    self.cooldown = self.cooldown - dt
    if(self.cooldown < 0 and self.target) then
        self:fire(self.x, self.y, self.target.x, self.target.y) -- Ensure cooldown does not go negative
    end
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

function Auto_Mortar:draw()
    for _, b in ipairs(self.bullets) do
        b:draw()
    end
    -- Optionally, draw the mortar itself
    love.graphics.setColor(1, 1, 0) -- Yellow color for the mortar
    love.graphics.circle("fill", self.x, self.y, 10) -- Draw the mortar as a circle
end

return Auto_Mortar