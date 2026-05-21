local CardReveal = {}
CardReveal.__index = CardReveal

-- Particle systems cache
local function createParticleSystem(color, size, count, spread)
    local canvas = love.graphics.newCanvas(4, 4)
    love.graphics.setCanvas(canvas)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.circle("fill", 2, 2, 2)
    love.graphics.setCanvas()
    
    local ps = love.graphics.newParticleSystem(canvas, count or 100)
    ps:setParticleLifetime(0.5, 1.5)
    ps:setEmissionRate(0)
    ps:setSizeVariation(1)
    ps:setSizes(size, size * 0.5, 0)
    ps:setSpeed(50, 150)
    ps:setSpread(spread or (math.pi * 2))
    ps:setColors(color[1], color[2], color[3], 1, color[1], color[2], color[3], 0)
    return ps
end

function CardReveal:new(reward, x, y, width, height)
    local obj = setmetatable({}, self)
    obj.reward = reward
    obj.x = x
    obj.y = y
    obj.width = width
    obj.height = height
    
    obj.state = "hidden" -- hidden, flipping, revealed
    obj.flipTimer = 0
    obj.flipDuration = 0.5
    obj.scaleX = 1
    
    obj.rarity = reward.rarity or "common"
    obj.color = reward:getRarityColor()
    
    obj.glowAlpha = 0
    obj.shakeTimer = 0
    
    -- Effects specific properties
    if obj.rarity == "epic" then
        obj.flipDuration = 2
        obj.ps = createParticleSystem({1, 0, 1}, 1.5, 200)
        obj.ps:setSpeed(150, 300)
    elseif obj.rarity == "legendary" then
        obj.flipDuration = 4.5
        obj.ps = createParticleSystem({1, 0.8, 0}, 2, 300)
        obj.ps:setSpeed(200, 400)
        obj.laserRotation = 0
    elseif obj.rarity == "rare" then
        obj.ps = createParticleSystem({0, 0.5, 1}, 1, 50, math.pi)
        obj.ps:setSpeed(30, 80)
        obj.ps:setLinearAcceleration(0, -50, 0, -100) -- drift upwards
    end
    
    return obj
end

function CardReveal:startFlip()
    if self.state == "hidden" then
        self.state = "flipping"
        self.flipTimer = 0
        
        -- Epic and Legendary sounds have swells, so they start playing exactly when the flip begins
        if AUDIO and (self.rarity == "epic" or self.rarity == "legendary") then
            AUDIO:playSFX(self.rarity)
        end
    end
end

function CardReveal:update(dt)
    if self.ps then
        self.ps:update(dt)
    end
    
    if self.shakeTimer > 0 then
        self.shakeTimer = math.max(0, self.shakeTimer - dt)
    end
    
    if self.glowAlpha > 0 and self.state == "revealed" then
        self.glowAlpha = math.max(0, self.glowAlpha - dt * 2) -- fade out over 0.5s
    end
    
    if self.state == "revealed" or self.state == "flipping" then
        self.laserRotation = (self.laserRotation or 0) + dt * 0.5
    end
    
    if self.state == "flipping" then
        self.flipTimer = self.flipTimer + dt
        local progress = self.flipTimer / self.flipDuration
        
        -- scaleX goes from 1 to 0 (at 0.5 progress) then 0 to 1
        if progress < 0.5 then
            self.scaleX = 1 - (progress * 2)
        else
            -- Midpoint crossed, trigger reveal effects once
            if not self.effectsTriggered then
                self.effectsTriggered = true
                self:triggerRevealEffects()
            end
            self.scaleX = (progress - 0.5) * 2
        end
        
        if progress >= 1 then
            self.state = "revealed"
            self.scaleX = 1
        end
    end
end

function CardReveal:triggerRevealEffects()
    -- Common, Uncommon, and Rare sounds trigger immediately on reveal
    if AUDIO and (self.rarity ~= "epic" and self.rarity ~= "legendary") then
        AUDIO:playSFX(self.rarity)
    end
    
    if self.rarity == "uncommon" then
        self.glowAlpha = 0.5
    elseif self.rarity == "rare" then
        self.glowAlpha = 0.8
        if self.ps then self.ps:emit(30) end
    elseif self.rarity == "epic" then
        self.glowAlpha = 1.0
        self.shakeTimer = 0.2
        if self.ps then self.ps:emit(100) end
    elseif self.rarity == "legendary" then
        self.glowAlpha = 1.0
        self.shakeTimer = 0.3
        if self.ps then self.ps:emit(200) end
    end
end

function CardReveal:draw(isSelected)
    local cx = self.x + self.width / 2
    local cy = self.y + self.height / 2
    
    local drawX = cx
    local drawY = cy
    if self.shakeTimer > 0 then
        drawX = drawX + (math.random() - 0.5) * 10
        drawY = drawY + (math.random() - 0.5) * 10
    end
    
    -- Draw background effects (lasers for legendary)
    if self.state == "revealed" and self.rarity == "legendary" then
        love.graphics.push("all")
        love.graphics.setBlendMode("add")
        love.graphics.setColor(1, 0.8, 0, 0.3 + math.sin(love.timer.getTime() * 5) * 0.1)
        
        for i = 1, 6 do
            local angle = self.laserRotation + (i * math.pi / 3)
            love.graphics.push()
            love.graphics.translate(drawX, drawY)
            love.graphics.rotate(angle)
            -- Draw long laser beam
            love.graphics.polygon("fill", -10, 0, 10, 0, 40, -300, -40, -300)
            love.graphics.polygon("fill", -10, 0, 10, 0, 40, 300, -40, 300)
            love.graphics.pop()
        end
        love.graphics.pop()
    end
    
    -- Draw particles behind card
    if self.ps then
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.draw(self.ps, drawX, drawY)
    end
    
    love.graphics.push()
    love.graphics.translate(drawX, drawY)
    
    -- Additional "slam" scale effect for epic/legendary while flipping past midpoint
    local effectScale = 1
    if self.state == "flipping" and self.effectsTriggered and (self.rarity == "epic" or self.rarity == "legendary") then
        local progress = self.flipTimer / self.flipDuration
        local remainder = (progress - 0.5) * 2 -- 0 to 1
        effectScale = 1 + (1 - remainder) * 0.5 -- Scale from 1.5 down to 1
    end
    
    love.graphics.scale(self.scaleX * effectScale, 1 * effectScale)
    
    if self.state == "hidden" or (self.state == "flipping" and not self.effectsTriggered) then
        -- Draw Card Back
        love.graphics.setColor(0.15, 0.15, 0.2, 1)
        love.graphics.rectangle("fill", -self.width/2, -self.height/2, self.width, self.height)
        love.graphics.setColor(0.4, 0.4, 0.5, 1)
        love.graphics.setLineWidth(4)
        love.graphics.rectangle("line", -self.width/2, -self.height/2, self.width, self.height)
        
        -- Add a simple logo or pattern on the back
        love.graphics.circle("line", 0, 0, 30)
        love.graphics.polygon("line", 0, -15, 15, 10, -15, 10)
    else
        -- Draw Actual Card
        self.reward:draw(-self.width/2, -self.height/2, self.width, self.height, isSelected)
        
        -- Draw Overlay Glows
        if self.glowAlpha > 0 then
            love.graphics.push("all")
            love.graphics.setBlendMode("add")
            love.graphics.setColor(self.color[1], self.color[2], self.color[3], self.glowAlpha)
            love.graphics.rectangle("fill", -self.width/2, -self.height/2, self.width, self.height)
            love.graphics.pop()
        end
        
        -- Continuous pulsing aura for Legendary
        if self.rarity == "legendary" and self.state == "revealed" then
            love.graphics.push("all")
            local pulse = (math.sin(love.timer.getTime() * 4) + 1) * 0.5 -- 0 to 1
            love.graphics.setColor(1, 0.8, 0, 0.2 * pulse)
            love.graphics.setBlendMode("add")
            love.graphics.setLineWidth(4 + pulse * 4)
            love.graphics.rectangle("line", -self.width/2 - 2, -self.height/2 - 2, self.width + 4, self.height + 4)
            love.graphics.pop()
        end
    end
    
    love.graphics.pop()
end

return CardReveal
