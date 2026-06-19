local Turret = require("Buildings.Turrets.Turret")
local EnergyBullet = require("Bullets.EnergyBullet")
local Utils = require("Classes.Utils")

local FluxCannon = setmetatable({}, { __index = Turret })
FluxCannon.__index = FluxCannon

-- Source of Truth: All stats in a single flat table
FluxCannon.template = {
    name = "Flux Cannon",
    color = {0, 1, 1, 1}, -- Bright Cyan
    rotation = 0,

    fireRate = 1.2,
    damage = 35,
    bulletSpeed = 450,
    range = 400,
    barrel = 12,
    bulletW = 12,
    damageType = "energy",
    bulletName = "Energy Bolt",
    lifespan = 1.5,
    pierce = 1,
    types = { turret = true, energy = true },
    sfx = "laser_02",
    firingArc = {
        direction = 0,
        minRange = 0,
        angle = math.pi/8
    },
    shapePattern = {
        {0, 0}
    }
}

function FluxCannon:new(config)
    local baseConfig = Utils.deepCopy(FluxCannon.template)
    
    if config then
        for k, v in pairs(config) do
            if type(v) == "table" and baseConfig[k] then
                for k2, v2 in pairs(v) do baseConfig[k][k2] = v2 end
            else
                baseConfig[k] = v
            end
        end
    end
    
    local instance = Turret:new(baseConfig)
    setmetatable(instance, FluxCannon)
    
    instance.bulletType = EnergyBullet
    return instance
end

function FluxCannon:draw(drawx, drawy)
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
    drawHex(cx, cy, 8)
    
    -- 2. Draw Rotating Turret Head (Diamond shape)
    love.graphics.push()
    love.graphics.translate(cx, cy)
    love.graphics.rotate(self.rotation)
    
    -- Head Glow
    love.graphics.setColor(r, g, b, 0.15)
    love.graphics.polygon("fill", 10, 0, 0, 6, -5, 0, 0, -6)
    
    -- Main Head
    love.graphics.setColor(r, g, b, 1)
    love.graphics.setLineWidth(2)
    love.graphics.polygon("line", 10, 0, 0, 6, -5, 0, 0, -6)
    
    -- Barrel (Dual parallel lines for energy feel)
    love.graphics.setLineWidth(3)
    love.graphics.line(6, -2.5, self.barrel, -2.5)
    love.graphics.line(6, 2.5, self.barrel, 2.5)
    
    -- Energy core (Bright center)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.circle("fill", 0, 0, 3)
    
    love.graphics.pop()
end

return FluxCannon
