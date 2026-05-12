local Turret = require("Buildings.Turrets.Turret")
local EnergyBullet = require("Bullets.EnergyBullet")
local EnergyBlaster = setmetatable({}, { __index = Turret })
EnergyBlaster.__index = EnergyBlaster

function EnergyBlaster:new(config)
    config = config or {}
    
    -- Configure Energy Blaster Stats
    config.name = "Energy Blaster"
    config.color = {0, 1, 1, 1} -- Bright Cyan
    config.rotation = config.rotation or 0
    config.turnSpeed = 4
    config.fireRate = 1.2
    config.damage = 35
    config.bulletSpeed = 450
    config.range = 400
    config.barrel = 18
    config.bulletW = 12
    config.bulletH = 4
    config.bulletShape = "pill"
    config.damageType = "energy"
    config.bulletName = "Energy Bolt"
    config.lifespan = 1.5
    config.pierce = 1
    config.types = { turret = true, energy = true, building = true }
    config.sfx = "laser_02"
    
    config.firingArc = config.firingArc or {
        direction = config.rotation,
        minRange = 0,
        angle = math.pi/8
    }
    
    config.shapePattern = {
        {0, 0}
    }
    
    local instance = Turret:new(config)
    setmetatable(instance, EnergyBlaster)
    
    instance.bulletType = EnergyBullet
    return instance
end

function EnergyBlaster:draw(drawx, drawy)
    local cx, cy = drawx or self.x, drawy or self.y
    if not drawx and not drawy then
        cx, cy = self:getCenterPosition()
    end
    
    -- Draw firing arc if showArc flag is set
    if self.showArc then
        self:drawFiringArc(cx, cy, 0.4)
    end
    
    local r, g, b, a = unpack(self.color)
    
    -- 1. Draw Mount Base (Hexagon)
    love.graphics.setColor(r, g, b, 0.2)
    local function drawHex(x, y, s)
        local pts = {}
        for i = 0, 5 do
            local ang = i * (math.pi/3)
            table.insert(pts, x + math.cos(ang) * s)
            table.insert(pts, y + math.sin(ang) * s)
        end
        love.graphics.polygon("fill", pts)
        love.graphics.setColor(r, g, b, 1)
        love.graphics.setLineWidth(2)
        love.graphics.polygon("line", pts)
    end
    drawHex(cx, cy, 10)
    
    -- 2. Draw Rotating Turret Head (Diamond shape)
    love.graphics.push()
    love.graphics.translate(cx, cy)
    love.graphics.rotate(self.rotation)
    
    -- Head Glow
    love.graphics.setColor(r, g, b, 0.15)
    love.graphics.polygon("fill", 12, 0, 0, 8, -6, 0, 0, -8)
    
    -- Main Head
    love.graphics.setColor(r, g, b, 1)
    love.graphics.setLineWidth(2)
    love.graphics.polygon("line", 12, 0, 0, 8, -6, 0, 0, -8)
    
    -- Barrel (Dual parallel lines for energy feel)
    love.graphics.setLineWidth(3)
    love.graphics.line(8, -3, self.barrel, -3)
    love.graphics.line(8, 3, self.barrel, 3)
    
    -- Energy core (Bright center)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.circle("fill", 0, 0, 3)
    
    love.graphics.pop()
end

return EnergyBlaster
