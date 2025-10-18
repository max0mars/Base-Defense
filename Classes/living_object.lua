local object = require("Classes.object")

local living_object = setmetatable({}, object)
living_object.__index = living_object

function living_object:new(config)
    local obj = object:new(config)
    setmetatable(obj, { __index = self })
    obj.hp = config.hp or 100
    obj.maxhp = config.hp or 100 -- Store the maximum health
    return obj
end

function living_object:drawHealthBar()
    if self.hp < self.maxhp then
        self:_drawHealthBar()
    end
end

function living_object:_drawHealthBar()
    local width
    local height
    local yOffset = 0
    if self.shape == "circle" then
        width = self.size * 2
        height = self.size
    else 
        width = self.w
        height = 10 -- Fixed height for rectangle health bar
        yOffset = self.h / 2
    end

    -- Position the health bar above the enemy
    local barX = self.x - width/2
    local barY = self.y - 20 - yOffset -- Adjust this offset as needed

    -- Calculate health percentage
    local healthPercent = self.hp / self.maxhp

    -- Draw background (red)
    love.graphics.setColor(0.8, 0.2, 0.2, 0.8)
    love.graphics.rectangle("fill", barX, barY, width, height)
    
    -- Draw health (green)
    love.graphics.setColor(0.2, 0.8, 0.2, 0.8)
    love.graphics.rectangle("fill", barX, barY, width * healthPercent, height)
    
    -- Draw border
    love.graphics.setColor(0, 0, 0, 0.8)
    love.graphics.rectangle("line", barX, barY, width, height)
end

function living_object:takeDamage(amount)
    self.hp = self.hp - amount
    if self.hp <= 0 then
        self:died()
    end
end

function living_object:died()
    self:destroy() -- Call the destroy method from the base object
end

function living_object:draw()
    object.draw(self) -- Call the base object's draw method
    -- if self.hp < self.maxhp then
    --     self:drawHealthBar() -- Draw the health bar if hp is less than maxhp
    -- end
end

return living_object