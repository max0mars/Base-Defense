local Turret = require("Buildings.Turrets.Turret")
local Utils = require("Classes.Utils")

local ShotgunTurret = setmetatable({}, { __index = Turret })
ShotgunTurret.__index = ShotgunTurret

ShotgunTurret.template = {
    name = "Shotgun Turret",
    rotation = 0,
    turnSpeed = 6,
    fireRate = 0.7, -- 1 shot every ~1.5 seconds
    range = 200,     -- Lethal close-range spread weapon
    barrel = 16,
    color = {1, 0.4, 0, 1}, -- Bright fiery neon orange
    baseShape = "square",
    barrelShape = "flared",
    types = { turret = true },
    shapePattern = {{0,0}},
    firingArc = {
        direction = 0,
        minRange = 0,
        angle = math.rad(100)
    },
    sfx = "gunshot_03",
    spread = math.rad(20), -- Base full spread cone angle in radians
    
    -- Bullet Properties
    bulletName = "Shotgun Pellet",
    bulletSpeed = 480,
    damage = 8,      -- High total burst damage (10 * 8 = 80), low individual pellet damage
    damageType = "normal",
    pierce = 1,
    lifespan = 2,  -- Short-range drop-off
    bulletW = 3,
    bulletH = 3,
    bulletShape = "rectangle",
    hitEffects = {}
}

function ShotgunTurret:new(config)
    local baseConfig = Utils.deepCopy(ShotgunTurret.template)
    if config then
        for k, v in pairs(config) do
            baseConfig[k] = v
        end
    end
    
    local t = Turret:new(baseConfig)
    setmetatable(t, { __index = self })
    
    -- Define cluster firing mechanics
    t.pelletCount = 10
    t.spread = baseConfig.spread or math.rad(60)
    
    return t
end

function ShotgunTurret:fire(args)
    -- Trigger central burst sound effect once per salvo
    if AUDIO then
        AUDIO:playSFX(self.sfx or "gunshot_03")
    end
    
    local targetX = args and args.targetX
    local targetY = args and args.targetY
    
    -- Dynamically query active stats allowing external upgrade scaling
    local currentSpread = self:getStat("spread") or self.spread or math.rad(60)
    local currentDamage = self:getStat("damage") or 8
    local baseBulletSpeed = self:getStat("bulletSpeed") or 480
    
    -- Temporarily detach global AUDIO to suppress individual per-pellet gunshot sound triggers
    local oldAudio = AUDIO
    AUDIO = nil
    
    -- Launch entire cluster instantly with varied trajectories and randomized projectile velocities
    for i = 1, self.pelletCount do
        local angleOffset = (math.random() - 0.5) * currentSpread
        -- Vary individual pellet speed by ±20% for chaotic downrange cluster spread
        local speedFactor = 0.9 + math.random() * 0.2
        local pelletSpeed = baseBulletSpeed * speedFactor
        
        Turret.fire(self, {
            angle = self.rotation + angleOffset,
            damage = currentDamage,
            bulletSpeed = pelletSpeed,
            targetX = targetX,
            targetY = targetY
        })
    end
    
    AUDIO = oldAudio
end

function ShotgunTurret:draw(drawx, drawy)
    local cx, cy = drawx or self.x, drawy or self.y
    if not drawx and not drawy then
        cx, cy = self:getCenterPosition()
    end

    if self.showArc then
        self:drawFiringArc(cx, cy, 0.4)
    end
    
    local r, g, b, a = unpack(self.color or {1, 0.4, 0, 1})
    
    -- 1. Render Heavy Sturdy Square Base
    local bw, bh = 10, 10
    local basePoints = {
        cx - bw, cy - bh,
        cx + bw, cy - bh,
        cx + bw, cy + bh,
        cx - bw, cy + bh
    }
    
    love.graphics.setColor(r, g, b, 0.12)
    love.graphics.polygon("fill", basePoints)
    
    local function drawBaseLine()
        love.graphics.polygon("line", basePoints)
    end
    
    for i = 2, 1, -1 do
        love.graphics.setColor(r, g, b, 0.15 * (3 - i))
        love.graphics.setLineWidth(i * 2.5)
        drawBaseLine()
    end
    love.graphics.setColor(r, g, b, 1)
    love.graphics.setLineWidth(1.5)
    drawBaseLine()
    
    -- 2. Render Flared Shotgun/Blunderbuss Barrel
    love.graphics.push()
    love.graphics.translate(cx, cy)
    love.graphics.rotate(self.rotation)
    
    local bl = self.barrel or 16
    local barrelPoints = {
        0, -3,
        bl, -6.5, -- Flare outward
        bl, 6.5,
        0, 3
    }
    
    love.graphics.setColor(r, g, b, 0.15)
    love.graphics.polygon("fill", barrelPoints)
    
    local function drawBarrelLine()
        love.graphics.polygon("line", barrelPoints)
    end
    
    for i = 2, 1, -1 do
        love.graphics.setColor(r, g, b, 0.15 * (3 - i))
        love.graphics.setLineWidth(i * 2.5)
        drawBarrelLine()
    end
    love.graphics.setColor(r, g, b, 1)
    love.graphics.setLineWidth(2)
    drawBarrelLine()
    
    -- 3. High-Intensity Central Core/Breach Glow
    love.graphics.setColor(r, g, b, 0.5)
    love.graphics.circle("fill", 0, 0, 4)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.circle("fill", 0, 0, 2)
    
    love.graphics.pop()
    
    love.graphics.setLineWidth(1)
    love.graphics.setColor(1, 1, 1, 1)
end

return ShotgunTurret
