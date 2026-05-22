local Turret = require("Buildings.Turrets.Turret")
local Utils = require("Classes.Utils")

local Blaster = setmetatable({}, { __index = Turret })
Blaster.__index = Blaster

-- Source of Truth: All stats in a single flat table
Blaster.template = {
    name = "Blaster",
    size = 15,
    rotation = 0,
    turnSpeed = math.huge,
    fireRate = 0.7,
    range = 450,
    barrel = 10,
    color = {0.2, 0.8, 1, 1},
    types = { turret = true, blaster = true },
    shapePattern = {{0,0}},
    firingArc = {
        direction = 0,
        minRange = 0,
        angle = math.pi/6
    },
    spread = math.rad(2),
    
    -- Bullet properties (now flat)
    bulletName = "Energy Bolt",
    bulletSpeed = 400,
    damageType = "energy",
    damage = 8, 
    pierce = 1,
    lifespan = 2,
    bulletW = 4,
    bulletH = 4,
    bulletShape = "rectangle",
    hitEffects = {}
}

function Blaster:new(config)
    local baseConfig = Utils.deepCopy(Blaster.template)
    
    if config then
        for k, v in pairs(config) do
            baseConfig[k] = v
        end
    end
    
    local t = Turret:new(baseConfig)
    setmetatable(t, { __index = self })
    
    t.burstAmount = 3
    t.burstCount = 0
    t.burstDelay = 0.1
    t.burstTimer = 0
    t.isBursting = false
    
    return t
end

function Blaster:update(dt)
    if self.destroyed then return end

    if self.burstCount > 0 then
        self.burstTimer = self.burstTimer - dt
        if self.burstTimer <= 0 then
            self.burstTimer = self.burstDelay
            self.burstCount = self.burstCount - 1
            
            self.isBursting = true
            if self.target and not self.target.destroyed then
                local x, y = self:getTargetLeadPosition()
                self:lookAt(x, y, dt)
                self:fire({targetX = x, targetY = y})
            else
                self:fire(self.lastArgs)
            end
            self.isBursting = false
        end
    end

    Turret.update(self, dt)
end

function Blaster:fire(args)
    if self.isBursting then
        Turret.fire(self, args)
    else
        self.burstCount = self.burstAmount - 1
        self.burstTimer = self.burstDelay
        self.lastArgs = args
        
        self.isBursting = true
        Turret.fire(self, args)
        self.isBursting = false
    end
end

return Blaster
