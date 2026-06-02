local Turret = require("Buildings.Turrets.Turret")
local Utils = require("Classes.Utils")

local AutoCannon = setmetatable({}, { __index = Turret })
AutoCannon.__index = AutoCannon

AutoCannon.template = {
    name = "Auto Cannon",
    rotation = 0,
    turnSpeed = 10,
    fireRate = 5,
    range = 350,
    barrel = 15,
    color = {0.8, 0.8, 0.2, 1},
    baseShape = "octagon",
    barrelShape = "double",
    types = { turret = true },
    shapePattern = {{0,0}},
    firingArc = {
        direction = 0,
        minRange = 0,
        angle = math.pi/4
    },
    spread = math.rad(5),
    -- Bullet Properties
    bulletName = "Cannon Round",
    bulletSpeed = 500,
    damageType = "normal",
    damage = 3,
    pierce = 1,
    lifespan = .8,
    bulletW = 3, 
    bulletH = 3, 
    bulletShape = "rectangle",
    hitEffects = {}
}

function AutoCannon:new(config)
    local baseConfig = Utils.deepCopy(AutoCannon.template)
    
    if config then
        for k, v in pairs(config) do
            baseConfig[k] = v
        end
    end
    
    local t = Turret:new(baseConfig)
    setmetatable(t, { __index = self })
    t.shootSide = 0
    return t
end

function AutoCannon:fire(args)
    args = args or {}
    
    -- Alternate between top (1) and bottom (2) barrels
    self.shootSide = (self.shootSide or 0) + 1
    if self.shootSide > 2 then
        self.shootSide = 1
    end
    
    -- Local offset: top is y = -3.5, bottom is y = 3.5
    local ly = (self.shootSide == 1) and -3.5 or 3.5
    local lx = self.barrel or 15
    
    local cx, cy = self:getCenterPosition()
    local cosR = math.cos(self.rotation)
    local sinR = math.sin(self.rotation)
    
    -- Transform local coordinate to world coordinates
    args.fireX = cx + lx * cosR - ly * sinR
    args.fireY = cy + lx * sinR + ly * cosR
    
    Turret.fire(self, args)
end

function AutoCannon:drawCustomBase(cx, cy)
    -- Rectangular base for AutoCannon
    love.graphics.rectangle("line", cx - 8, cy - 6, 16, 12, 1, 1)
end

function AutoCannon:drawCustomBarrel()
    -- Twin slender barrels
    love.graphics.rectangle("line", 0, -4.5, self.barrel, 2)
    love.graphics.rectangle("line", 0, 2.5, self.barrel, 2)
end

return AutoCannon
