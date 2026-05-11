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
    obj.maxHp = config.maxHp or config.hp or 100
    obj.hp = config.hp or obj.maxHp -- Default to maxHp if current hp is not provided
    obj.shield = config.shield or 0
    obj.maxShield = config.maxShield or math.huge
    obj.armour = config.armour or 0
    obj.affinities = config.affinities or {
        normal = 1,
        poison = 1,
        armourPiercing = 1,
        trueDamage = 1,
        fire = 1,
        explosive = 1,
        electric = 1,
        energy = 1
    }
    return obj
end

function living_object:drawHealthBar()
    if self.hp < self:getStat("maxHp") then
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
        height = math.max(self.h/4, 3) -- Fixed height for rectangle health bar
        yOffset = self.h / 2
    end

    -- Position the health bar above the enemy
    local barX = self.x - width/2
    local barY = self.y - height - 2 - yOffset -- Adjust this offset as needed

    -- Calculate health percentage
    local healthPercent = self.hp / self:getStat("maxHp")

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

local damageTypes = {
    normal = 1,
    poison = 1,
    armourPiercing = 1,
    trueDamage = 1,
    fire = 1,
    explosive = 1,
    electric = 1,
    energy = 1
}
function living_object:takeDamage(amount, damageType, hitX, hitY)
    if damageTypes[damageType] == nil then
        error("Developer Error: Invalid damage type: " .. damageType)
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
        self.game:spawnDamageNumber(amount, hitX or self.x, hitY or self.y, damageType)
    end

    local damageTaken = 0

    -- Shield Logic (Temp Health)
    if self.shield and self.shield > 0 then
        if amount >= self.shield then
            damageTaken = self.shield
            self.shield = 0
            -- Damage gating: excess damage does not carry over to normal health
            return damageTaken
        else
            self.shield = self.shield - amount
            return amount
        end
    end

    -- Normal HP Logic
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

function living_object:drawStatusEffects()
    if not self.effectManager then return end
    
    local iconSize = 4
    local spacing = 4
    local x, y, width, height = self:getHealthBarRect()
    if not (x and y and width and height) then return end

    local effectCount = 0
    for name, count in pairs(self.effectManager.effectCounts) do
        if count > 0 then
            effectCount = effectCount + 1
        end
    end
    if effectCount == 0 then return end
    
    local totalWidth = effectCount * iconSize + (effectCount-1) * spacing
    local drawX = x + (width - totalWidth) / 2
    local drawY = y - iconSize - 2

    local i = 0
    local EffectManager = require("Game.Effects.EffectManager")
    for name, count in pairs(self.effectManager.effectCounts) do
        if count > 0 then
            local color = EffectManager.colors[name] or {1,1,1,1}
            love.graphics.setColor(color)
            love.graphics.circle("fill", drawX + i*(iconSize+spacing) + iconSize/2, drawY + iconSize/2, iconSize/2)
            love.graphics.setColor(0,0,0,1)
            love.graphics.printf(tostring(count), drawX + i*(iconSize+spacing), drawY + 2, iconSize, "center")
            i = i + 1
        end
    end
    love.graphics.setColor(1,1,1,1)
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