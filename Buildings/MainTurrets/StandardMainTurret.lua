local MainTurret = require("Buildings.MainTurrets.MainTurret")
local HitscanBullet = require("Bullets.HitscanBullet")
local Utils = require("Classes.Utils")

local StandardMainTurret = setmetatable({}, { __index = MainTurret })
StandardMainTurret.__index = StandardMainTurret

StandardMainTurret.template = {
    id = "standard_main",
    name = "Standard Blaster",
    size = 20,
    rotation = 0,
    turnSpeed = math.huge,
    fireRate = 0.5,
    range = 2000,
    barrel = 20,
    color = {0.3, 0.3, 0.3, 1},
    types = { turret = true, mainTurret = true, tesla = true },
    shapePattern = {
        {0, 0}, {1, 0},
        {0, 1}, {1, 1}
    },
    firingArc = { 
        direction = 0, 
        minRange = 0, 
        angle = math.pi * 2 
    },
    
    -- Bullet Properties (Hitscan Laser)
    bulletName = "Heavy Laser",
    bulletColor = {0, 0, 1},
    bulletSpeed = 400,
    damage = 45,
    pierce = 1,
    lifespan = 1,
    displayLifespan = 0.5,
    bulletW = 4, 
    bulletH = 4,
    damageType = "energy",
    bulletShape = "ray",
    hitEffects = {}
}

function StandardMainTurret:new(config)
    local baseConfig = Utils.deepCopy(StandardMainTurret.template)
    
    if config then
        for k, v in pairs(config) do
            baseConfig[k] = v
        end
    end
    
    baseConfig.bulletType = HitscanBullet
    
    local t = MainTurret:new(baseConfig)
    setmetatable(t, { __index = self })
    return t
end

function StandardMainTurret:draw()
    local cx, cy = self:getCenterPosition()
    local r, g, b = unpack(self.color or {0.3, 0.3, 0.3, 1})
    
    -- 1. Draw Sleek Base (Single Octagon)
    local function drawBase(radius)
        local pts = {}
        for i = 0, 7 do
            local angle = i * (math.pi * 2 / 8) + math.pi / 8
            table.insert(pts, cx + math.cos(angle) * radius)
            table.insert(pts, cy + math.sin(angle) * radius)
        end
        love.graphics.polygon("line", pts)
    end

    -- Base Glow
    love.graphics.setColor(r, g, b, 0.4)
    love.graphics.setLineWidth(4)
    drawBase(self.size * 1.1)
    love.graphics.setColor(r, g, b, 1)
    love.graphics.setLineWidth(2)
    drawBase(self.size * 1.1)

    -- 2. Draw Aiming Head (Rotating Tesla Coil)
    local mx, my = love.mouse.getPosition()
    local angle = math.atan2(my - cy, mx - cx)
    
    love.graphics.push()
    love.graphics.translate(cx, cy)
    love.graphics.rotate(angle)
    
    local function drawTeslaCoil()
        local currentFireRate = self:getStat("fireRate")
        local reloadProgress = 1 - math.max(0, self.cooldown / (1 / currentFireRate))
        
        -- Central rod
        love.graphics.setColor(0.3, 0.3, 0.3, 1)
        love.graphics.line(0, 0, 20, 0)
        
        -- Tesla rings
        for i = 1, 3 do
            local x = i * 5
            local threshold = i * 0.25
            if reloadProgress >= threshold then
                love.graphics.setColor(0.4, 0.7, 1, 1)
            else
                love.graphics.setColor(0.3, 0.3, 0.3, 1)
            end
            love.graphics.ellipse("line", x, 0, 1.5, 4)
        end
        
        -- Tip sphere
        if reloadProgress >= 1 then
            love.graphics.setColor(0.4, 0.7, 1, 1)
        else
            love.graphics.setColor(0.3, 0.3, 0.3, 1)
        end
        love.graphics.circle("line", 20, 0, 3.5)
    end
    
    -- Head Glow
    local currentFireRate = self:getStat("fireRate")
    local reloadProgress = 1 - math.max(0, self.cooldown / (1 / currentFireRate))
    
    if reloadProgress > 0.25 then
        love.graphics.setColor(0, 0.5, 1, 0.3 * reloadProgress)
        love.graphics.setLineWidth(5)
        drawTeslaCoil()
    end
    
    love.graphics.setLineWidth(2)
    drawTeslaCoil()
    
    -- Core Glow at tip and base
    if reloadProgress >= 1 then
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.circle("fill", 20, 0, 1.5)
    end
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.circle("fill", 0, 0, 3)
    
    love.graphics.pop()
    
    love.graphics.setLineWidth(1)
    love.graphics.setColor(1, 1, 1, 1)
end

function StandardMainTurret:getFirePoint()
    local cx, cy = self:getCenterPosition()
    local mx, my = love.mouse.getPosition()
    local angle = math.atan2(my - cy, mx - cx)
    return cx + math.cos(angle) * 20, cy + math.sin(angle) * 20
end

return StandardMainTurret
