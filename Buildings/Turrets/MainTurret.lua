local Turret = require("Buildings.Turrets.Turret")
local HitscanBullet = require("Bullets.HitscanBullet")
local Utils = require("Classes.Utils")

local MainTurret = setmetatable({}, { __index = Turret })
MainTurret.__index = MainTurret

-- Source of Truth: All stats for the Main Turret
MainTurret.template = {
    name = "Main Turret",
    size = 20,
    rotation = 0,
    turnSpeed = math.huge,
    fireRate = 0.5,
    bulletSpeed = 800,
    damage = 65,
    range = 2000, -- Replacing math.huge with a large finite number for range calculation
    barrel = 10,
    color = {0.3, 0.3, 0.3, 1},
    types = { turret = true, mainTurret = true },
    shapePattern = {
        {0, 0}, {1, 0},
        {0, 1}, {1, 1}
    },
    -- MainTurret doesn't traditionally use arcs, but the base class requires it
    firingArc = { 
        direction = 0, 
        minRange = 0, 
        angle = math.pi * 2 -- 360 degree arc
    },
    
    -- Sub-stats for its bullets
    bulletStats = {
        name = "Heavy Laser",
        speed = 0, -- Laser is hitscan
        damage = 65,
        pierce = 1,
        range = 0,
        lifespan = 0.5,
        maxLifespan = 0.5,
        w = 4, h = 4,
        shape = "rectangle",
        damageType = "energy",
        color = {0, 0, 1, 1},
        hitEffects = {}
    }
}

function MainTurret:new(config)
    local baseConfig = Utils.deepCopy(MainTurret.template)
    
    if config then
        for k, v in pairs(config) do
            baseConfig[k] = v
        end
    end
    
    -- Sync bullet stats
    baseConfig.bulletSpeed = baseConfig.bulletStats.speed
    baseConfig.damage = baseConfig.bulletStats.damage
    baseConfig.bulletType = HitscanBullet
    
    local t = Turret:new(baseConfig)
    setmetatable(t, { __index = self })
    
    t.autofire = baseConfig.autofire or false
    
    -- Sync logical position (x, y) with the center if we have a slot
    if t.slot then
        local cx, cy = t:getCenterPosition()
        t.x, t.y = cx, cy
    end
    
    return t
end

function MainTurret:getCenterPosition()
    if not self.slot then
        return self.x, self.y
    end

    local anchorSlot = self.slot
    local anchorX = ((anchorSlot - 1) % self.buildGrid.width) * self.buildGrid.cellSize + self.buildGrid.x
    local anchorY = (math.ceil(anchorSlot / self.buildGrid.width) - 1) * self.buildGrid.cellSize + self.buildGrid.y
    
    local centerX = anchorX + self.buildGrid.cellSize
    local centerY = anchorY + self.buildGrid.cellSize
    
    return centerX, centerY
end

function MainTurret:update(dt)
    self.cooldown = self.cooldown - dt
    
    if self.autofire and self.game:isState("wave") then
        local mx, my = love.mouse.getPosition()
        self:PlayerClick(mx, my)
    end
end

function MainTurret:PlayerClick(tX, tY)
    local base = self.game.base
    local bx1 = base.x - base.w / 2
    local bx2 = base.x + base.w / 2
    local by1 = base.y - base.h / 2
    local by2 = base.y + base.h / 2
    
    if tX >= bx1 and tX <= bx2 and tY >= by1 and tY <= by2 then
        return false
    end

    if self.cooldown <= 0 then
        local currentFireRate = self:getStat("fireRate")
        if currentFireRate > 0 then
            local fX, fY = self:getFirePoint()
            
            -- Prepare bullet config from our source of truth
            local bConfig = Utils.deepCopy(self.template.bulletStats)
            bConfig.x = fX
            bConfig.y = fY
            bConfig.targetX = tX
            bConfig.targetY = tY
            bConfig.game = self.game
            bConfig.source = self
            bConfig.angle = math.atan2(tY - fY, tX - fX)
            
            -- Handle fire logic
            self:fire(bConfig)
            self.cooldown = 1 / currentFireRate
            return true
        end
    end
    return false
end

function MainTurret:fire(bConfig)
     -- Note: In the base Turret, fire() creates its own config. 
     -- For MainTurret we might want to override or ensure base Turret fire() is compatible.
     -- Actually, Turret:fire(args) uses args to override its internal config.
     -- But we want a CLEAN injection.
     self.game:addObject(self.bulletType:new(bConfig))
end

function MainTurret:drawReloadBar()
    if self.cooldown > 0 then
        local centerX, centerY = self:getCenterPosition()
        local barWidth = 40
        local barHeight = 6
        local barX = centerX - barWidth/2
        local barY = centerY - 30
        
        local currentFireRate = self:getStat("fireRate")
        local reloadProgress = 1 - (self.cooldown / (1 / currentFireRate))
        
        love.graphics.setColor(0.3, 0.3, 0.3, 0.8)
        love.graphics.rectangle("fill", barX, barY, barWidth, barHeight)
        
        love.graphics.setColor(1, 0.5, 0, 0.9)
        love.graphics.rectangle("fill", barX, barY, barWidth * math.max(0, reloadProgress), barHeight)
        
        love.graphics.setColor(0, 0, 0, 1)
        love.graphics.rectangle("line", barX, barY, barWidth, barHeight)
    end
end

function MainTurret:draw()
    local centerX, centerY = self:getCenterPosition()
    love.graphics.setColor(self.color)
    
    love.graphics.rectangle("line", centerX - self.size, centerY - self.size, self.size * 2, self.size * 2)

    love.graphics.setColor(1, 1, 1)
    love.graphics.setLineWidth(2)
    
    -- Draw barrel lines
    love.graphics.line(centerX- 10, centerY+5, centerX, centerY - self.barrel)
    love.graphics.line(centerX+10, centerY+5, centerX, centerY - self.barrel)
    love.graphics.line(centerX, centerY+5, centerX, centerY - self.barrel)

    love.graphics.setColor(0, 0, 1)
    love.graphics.circle("fill", centerX, centerY - self.barrel, 4)
    love.graphics.setLineWidth(1)
    love.graphics.setColor(1, 1, 1, 1)
end

function MainTurret:getFirePoint()
    local centerX, centerY = self:getCenterPosition()
    return centerX, centerY - self.barrel
end

function MainTurret:getTargetArc() end
function MainTurret:isInFiringArc(enemy) return true end
function MainTurret:drawFiringArc(alpha) end

return MainTurret