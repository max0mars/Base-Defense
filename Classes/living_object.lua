local object = require("Classes.object")

local living_object = setmetatable({}, object)
living_object.__index = living_object

local default = {
    types = { living_object = true },
}

function living_object:new(config)
    if not config.types then config.types = {} end
    for key, value in pairs(default.types) do
        config.types[key] = true
    end
    config.effectManager = true
    local obj = object:new(config)
    setmetatable(obj, { __index = self })
    obj.hp = config.hp
    obj.maxhp = config.maxHp or config.hp -- Store the maximum health
    obj.armour = config.armour or 0
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

function living_object:takeDamage(amount, damageType)
    if damageType == nil then
        damageType = "normal" -- Default damage type
    end
    local damageTaken = 0
    local damageMult = 1   

    if self.affinities then
        if self.affinities[damageType] then
            damageMult = self.affinities[damageType]
        end
    end

    amount = amount * damageMult
    if amount > 1 then
        self.game:spawnDamageNumber(amount, self.x, self.y, damageType)
    end

    if(amount >= self.hp) then

        damageTaken = self.hp
        self.hp = 0
    else
        damageTaken = amount
        self.hp = self.hp - amount
    end
    if self.hp <= 0 then
        self:died()
    end
    return damageTaken
end

function living_object:died()
    self:destroy() -- Call the destroy method from the base object
end

function living_object:draw()
    object.draw(self) -- Call the base object's draw method
end

function living_object:getHealthBarRect()
    local width, height, yOffset
    if self.shape == "circle" then
        width = self.size * 2
        height = self.size
        yOffset = 0
    else
        width = self.w
        height = 10
        yOffset = self.h / 2
    end
    local barX = self.x - width / 2
    local barY = self.y - 20 - yOffset
    return barX, barY, width, height
end

return living_object