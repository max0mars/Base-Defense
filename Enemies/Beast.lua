local Enemy = require("Enemies.Enemy")
local Beast = setmetatable({}, {__index = Enemy})
Beast.__index = Beast

local default = {
    name = "Beast",
    speed = 140,
    maxHp = 30,
    damage = 5,
    reward = 5,
    size = 12,
    color = {0.8, 0.4, 0.1, 1},
    types = { beast = true },
    formationRadius = 20
}

function Beast:new(config)
    config = config or {}
    if not config.types then config.types = {} end
    for key, value in pairs(default) do
        config[key] = config[key] or value
    end
    for key in pairs(default.types) do
        config.types[key] = true
    end
    
    local instance = Enemy:new(config)
    setmetatable(instance, Beast)
    
    instance.master = config.master
    instance.enraged = false
    instance.formationOffsetX = -25
    instance.formationRadius = config.formationRadius
    
    return instance
end

function Beast:update(dt)
    if self.destroyed then return end
    
    if self.master and not self.master.destroyed and not self.enraged then
        local masterBaseSpeed = self.master.speed or 25
        local distToMasterX = self.x - self.master.x
        
        if distToMasterX > self.formationRadius then
            self.speed = 140
        elseif distToMasterX < -self.formationRadius then
            self.speed = masterBaseSpeed * 0.5
        else
            self.speed = masterBaseSpeed
        end
        
        local closeBeasts = {}
        for _, b in ipairs(self.master.activeBeasts) do
            if not b.destroyed and (b.x - self.master.x) <= self.formationRadius then
                table.insert(closeBeasts, b)
            end
        end
        
        local myIndex = 1
        local totalBeasts = #closeBeasts
        for i, b in ipairs(closeBeasts) do
            if b == self then
                myIndex = i
                break
            end
        end
        
        local spacing = 14
        local totalHeight = (totalBeasts - 1) * spacing
        local dynamicOffsetY = -totalHeight / 2 + (myIndex - 1) * spacing
        
        if self.navigator then
            self.navigator.perpendicularOffset = dynamicOffsetY
        end
    else
        self.speed = 140
        if not self.enraged and self.masterDied then
            self:masterDied()
        end
    end
    
    Enemy.update(self, dt)
end

function Beast:masterDied()
    self.master = nil
    self.enraged = true
    -- Speed resets to 180 automatically since getStat("speed") will return default 180 (unless mutated)
end

function Beast:draw()
    local r, g, b, a = unpack(self.color)
    local drawX = self.x
    local drawY = self.y
    local size = self:getStat("size")
    
    -- Empty state (Dim fill)
    love.graphics.setColor(r, g, b, 0.2)
    love.graphics.rectangle("fill", drawX - size/2, drawY - size/2, size, size)
    
    -- Health fill
    local maxHp = self:getStat("maxHp")
    local fillRatio = self.hp / maxHp
    
    local scissorY = (drawY - size/2) + size * (1 - fillRatio)
    local scissorH = size * fillRatio
    
    SetGameScissor(math.floor(drawX - size/2), math.floor(scissorY), math.ceil(size), math.ceil(scissorH))
    love.graphics.setColor(r, g, b, 0.8)
    love.graphics.rectangle("fill", drawX - size/2, drawY - size/2, size, size)
    
    -- Bright horizontal line at health cap
    if fillRatio > 0 and fillRatio < 1 then
        SetGameScissor(math.floor(drawX - size/2), math.floor(scissorY), math.ceil(size), 2)
        love.graphics.setColor(r, g, b, 1)
        love.graphics.rectangle("fill", drawX - size/2, drawY - size/2, size, size)
    end
    SetGameScissor()
    
    -- Glowing borders
    for i = 3, 1, -1 do
        love.graphics.setColor(r, g, b, 0.1 * (4-i))
        love.graphics.setLineWidth(i * 2)
        love.graphics.rectangle("line", drawX - size/2, drawY - size/2, size, size)
    end
    
    -- Main border
    love.graphics.setColor(r, g, b, 1)
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", drawX - size/2, drawY - size/2, size, size)
    
    -- Enraged indicator (red eyes)
    -- if self.enraged then
    --     love.graphics.setColor(1, 0, 0, 1)
    --     love.graphics.circle("fill", drawX + size*0.2, drawY - size*0.2, 2)
    --     love.graphics.circle("fill", drawX + size*0.2, drawY + size*0.2, 2)
    -- end
end

return Beast
