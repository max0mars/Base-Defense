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
    
    self.effectManager:update(dt) -- Update status effects
    
    if self:getStat("stunned", 0) > 0 then return end
    
    if self.master and not self.master.destroyed and not self.enraged then
        local distToMasterX = self.x - self.master.x
        
        if distToMasterX > self.formationRadius then
            -- Too far away, just sprint straight forward (left) to catch up
            self.x = self.x - self:getStat("speed") * dt
        else
            -- Close enough, compute and lock into the dynamic arc formation
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
            
            -- Arc curvature: beasts further from center are pushed further right (backwards)
            local arcCurve = 0.6
            local arcX = math.abs(dynamicOffsetY) * arcCurve
            
            local targetX = self.master.x + self.formationOffsetX + arcX
            local targetY = self.master.y + dynamicOffsetY
            
            local dx = targetX - self.x
            local dy = targetY - self.y
            local dist = math.sqrt(dx*dx + dy*dy)
            
            if dist > 5 then
                -- Slowly adjust into formation while matching master's base speed
                local masterSpeed = self.master:getStat("speed")
                self.x = self.x - masterSpeed * dt
                
                local adjustSpeed = 40
                local moveDist = adjustSpeed * dt
                
                if moveDist >= dist then
                    self.x = targetX
                    self.y = targetY
                else
                    self.x = self.x + (dx / dist) * moveDist
                    self.y = self.y + (dy / dist) * moveDist
                end
            else
                -- Matched formation, move at master's speed
                local masterSpeed = self.master:getStat("speed")
                self.x = self.x - masterSpeed * dt
                self.y = targetY -- snap Y to maintain formation vertically
            end
        end
        
        -- Check if it reached the base
        self:getTargetPos() -- Ensure target is updated
        if self.x < self.target then
            self.game.base:takeDamage(self:getStat("damage"), "normal", self.x, self.y, self)
            self:died()
        end
    else
        -- Enraged or masterless: Standard base-charging behavior
        local currentSpeed = self:getStat("speed")
        self:getTargetPos()
        if self.x > self.target then
            self.x = self.x - currentSpeed * dt
        else
            self.game.base:takeDamage(self:getStat("damage"), "normal", self.x, self.y, self)
            self:died()
        end
    end
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
    
    love.graphics.setScissor(math.floor(drawX - size/2), math.floor(scissorY), math.ceil(size), math.ceil(scissorH))
    love.graphics.setColor(r, g, b, 0.8)
    love.graphics.rectangle("fill", drawX - size/2, drawY - size/2, size, size)
    
    -- Bright horizontal line at health cap
    if fillRatio > 0 and fillRatio < 1 then
        love.graphics.setScissor(math.floor(drawX - size/2), math.floor(scissorY), math.ceil(size), 2)
        love.graphics.setColor(r, g, b, 1)
        love.graphics.rectangle("fill", drawX - size/2, drawY - size/2, size, size)
    end
    love.graphics.setScissor()
    
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
