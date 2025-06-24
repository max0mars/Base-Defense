local Enemy = {
    x, y, r,
    hp, maxhp,
    speed,
    target = nil, -- Target to follow
    damage = 10,
    destroyed = false, -- Flag to mark if the enemy is destroyed
}

function Enemy:new(x, y, r, hp, speed, damage, target)
    local obj = setmetatable({}, { __index = self })
    obj.x = x
    obj.y = y
    obj.r = r
    obj.hp = hp or 100
    obj.maxhp = hp or 100 -- Store the maximum health
    obj.speed = speed or 5
    obj.damage = damage or 10
    obj.target = target
    obj.color = {1, 1, 1}
    obj.shape = "circle" -- Default shape is circle
    obj.destroyed = false -- Initialize destroyed flag
    return obj
end

function Enemy:newAdvanced(x, y, r, shape, hp, speed, damage, target, color)
    local obj = setmetatable({}, { __index = self })
    obj.x = x
    obj.y = y
    obj.r = r
    if shape == "rectangle" then
        obj.shape = "rectangle"
    else
        obj.shape = "circle"
    end
    obj.hp = hp or 100
    obj.speed = speed or 50
    obj.damage = damage or 10
    obj.target = target
    if(color == 1) then
        color = {1, 0, 0} -- Default color red if color is 1
    elseif(color == 2) then
        color = {0, 1, 0} -- Default color green if color is 2
    elseif(color == 3) then
        color = {0, 0, 1} -- Default color blue if color is 3
    elseif(color == 4) then
        color = {1, 1, 0} -- Default color yellow if color is 4
    else
        color = {1, 1, 1} -- Default color white if no valid color is provided
    end
    obj.color = color -- Store the color in the object
    return obj
end

function Enemy:update(dt)
    if self.target then
        if(self.target:getX() >= (self.x - self.r - dt * self.speed)) then
            self.target:takeDamage(self.damage) -- Deal damage to the target
            self.destroyed = true -- Mark the enemy as destroyed
        end
        self.x = self.x - (self.speed * dt)
    end
end


function Enemy:draw()
    love.graphics.setColor(self.color) -- Set the color for drawing
    if self.shape == "circle" then
        love.graphics.circle("fill", self.x, self.y, self.r)
    elseif self.shape == "rectangle" then
        love.graphics.rectangle("fill", self.x - self.r, self.y - self.r, self.r * 2, self.r * 2)
    end
    if self.hp < self.maxhp then
        drawHealthBar(self.x, self.y, self.hp, self.maxhp)
    end
end

function drawHealthBar(x, y, currentHealth, maxHealth, width, height)
    width = width or 40
    height = height or 4
    
    -- Position the health bar above the enemy
    local barX = x - width/2
    local barY = y - 20  -- Adjust this offset as needed
    
    -- Calculate health percentage
    local healthPercent = currentHealth / maxHealth
    
    -- Draw background (red)
    love.graphics.setColor(0.8, 0.2, 0.2, 0.8)
    love.graphics.rectangle("fill", barX, barY, width, height)
    
    -- Draw health (green)
    love.graphics.setColor(0.2, 0.8, 0.2, 0.8)
    love.graphics.rectangle("fill", barX, barY, width * healthPercent, height)
    
    -- Draw border
    love.graphics.setColor(0, 0, 0, 0.8)
    love.graphics.rectangle("line", barX, barY, width, height)
    
    -- Reset color
    love.graphics.setColor(1, 1, 1, 1)
end

function Enemy:takeDamage(damage)
    self.hp = self.hp - damage
    if self.hp <= 0 then
        self.destroyed = true -- Mark the enemy as destroyed if HP is zero or less
    end
end
return Enemy