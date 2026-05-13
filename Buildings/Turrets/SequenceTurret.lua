local Turret = require("Buildings.Turrets.Turret")
local Utils = require("Classes.Utils")

local SequenceTurret = setmetatable({}, { __index = Turret })
SequenceTurret.__index = SequenceTurret

SequenceTurret.template = {
    name = "CSR-8 Sequence",
    rotation = 0,
    turnSpeed = 5,
    fireRate = 0.5, -- Slow starting RPM mapped to native Shots Per Second metric
    range = 450,        -- Long-range design profile
    barrel = 15,
    color = {0.2, 0.4, 0.8, 1}, -- Dim Blue base state
    baseShape = "octagon",
    barrelShape = "single",
    types = { turret = true },
    shapePattern = {{0,0}},
    firingArc = {
        direction = 0,
        minRange = 0,
        angle = math.pi/8
    },
    sfx = "gunshot_01",
    
    coolDownRate = 0.5,   -- Charges down extremely quickly (fully depleted in 0.5s idle)
    fireRateMultiplier = 12,
    rampUpDuration = 8,
    spread = math.rad(7), -- Initial wide cone spread
    
    -- Bullet Properties
    bulletName = "Sequence Bolt",
    bulletSpeed = 600,  -- High velocity projectile
    damage = 12,
    damageType = "normal",
    pierce = 1,
    lifespan = 1.5,
    bulletW = 6,
    bulletH = 6,
    bulletShape = "rectangle",
    hitEffects = {}
}

function SequenceTurret:new(config)
    local baseConfig = Utils.deepCopy(SequenceTurret.template)
    if config then
        for k, v in pairs(config) do
            baseConfig[k] = v
        end
    end
    
    local t = Turret:new(baseConfig)
    
    -- Ramp-up configuration properties
    t.currentCharge = 0.0
    -- Preserve untainted base initial fire rate to avoid recursive scaling loops
    t.baseFireRate = baseConfig.fireRate or 0.6
    
    setmetatable(t, { __index = self })
    
    t.fireRate = t.baseFireRate
    t.spread = baseConfig.spread or math.rad(20)
    t.currentColor = baseConfig.color
    
    return t
end

function SequenceTurret:update(dt)
    -- Explicitly verify if our current target has died or drifted out of operational boundaries
    if self.target then
        if self.target.destroyed or not self:isInFiringArc(self.target) then
            -- Pre-emptively clear reference locally to register the impending target shift
            self.target = nil
        end
    end

    -- Pre-evaluate target acquisition via parent class implementation to map current tick target
    self:getTargetArc()
    
    -- Detect target switching or target loss to penalize charge state BEFORE base class shoots
    if self.target and self.lastTarget and self.target ~= self.lastTarget then
        -- Lose 50% of accumulated charge instantly when snapping to a new target
        self.currentCharge = math.max(0.0, self.currentCharge - 0.7)
        self.cooldown = 0.5
    end
    self.lastTarget = self.target
    
    -- Ramp-up state management logic loop
    if self.target then
        self.currentCharge = math.min(1.0, self.currentCharge + (dt / self.rampUpDuration))
    else
        self.currentCharge = math.max(0.0, self.currentCharge - (dt / self.coolDownRate))
    end
    
    -- Evaluate the true, upgraded base fire rate decoupled from self-mutations
    local defaultFR = self.baseFireRate or 0.6
    local currentBaseFR = self.effectManager and self.effectManager:getStat("fireRate", defaultFR) or defaultFR
    
    -- Apply exponential upward Lerp formula: spooling curve accelerates intensely towards peak RPM
    local maxFR = currentBaseFR * (self.fireRateMultiplier or 8)
    local targetFR = currentBaseFR + ((maxFR - currentBaseFR) * (self.currentCharge ^ 2))
    self.fireRate = math.max(0.01, targetFR)
    
    -- Calculate neon color shift interpolation from Dim Blue to Bright Red
    local c = self.currentCharge
    local baseColor = {0.2, 0.4, 0.8, 1}
    local maxColor  = {1.0, 0.1, 0.1, 1} -- Shift to pure intense Red at max RPM
    self.currentColor = {
        baseColor[1] + (maxColor[1] - baseColor[1]) * c,
        baseColor[2] + (maxColor[2] - baseColor[2]) * c,
        baseColor[3] + (maxColor[3] - baseColor[3]) * c,
        1
    }
    
    -- Delegate core aiming rotation, cooldown step timers, and instantiated firing to parent logic
    Turret.update(self, dt)
end

function SequenceTurret:fire(args)
    args = args or {}
    -- Bind the interpolated dynamic ramp-up color to outgoing projectiles
    args.color = self.currentColor or self.color
    
    -- Inverted Spread Formula: spread scales up directly with charge state for erratic high RPM bursts
    local baseSpread = self:getStat("spread")
    local currentSpreadCone = baseSpread * (self.currentCharge or 0)
    local angleOffset = (math.random() - 0.5) * currentSpreadCone
    
    -- Override outgoing target angle with our calculated spread deviation
    args.angle = (self.rotation or 0) + angleOffset
    
    -- Delegate instantiation to base logic to spawn Bullets/Bullet.lua with active trails and modifiers
    Turret.fire(self, args)
end

function SequenceTurret:draw(drawx, drawy)
    local cx, cy = drawx or self.x, drawy or self.y
    if not drawx and not drawy then
        cx, cy = self:getCenterPosition()
    end
    
    if self.showArc then
        self:drawFiringArc(cx, cy, 0.4)
    end
    
    -- Separate static base color from the dynamically glowing barrel color
    local baseCol = self.color or {0.2, 0.4, 0.8, 1}
    local barrelCol = self.currentColor or baseCol
    local chargeGlowBoost = (self.currentCharge or 0) * 0.35
    local chargeWidthBoost = (self.currentCharge or 0) * 2.5
    
    -- 1. Base Rendering: Stationary geometric base (Octagon) stays cool and static
    local function drawBaseShape()
        local radius = 10
        local points = {}
        for i = 0, 7 do
            local ang = i * (math.pi * 2 / 8) + math.pi / 8
            table.insert(points, cx + math.cos(ang) * radius)
            table.insert(points, cy + math.sin(ang) * radius)
        end
        love.graphics.polygon("line", points)
    end
    
    -- Inner glassmorphic dim fill (Static)
    love.graphics.setColor(baseCol[1], baseCol[2], baseCol[3], 0.12)
    local fillPoints = {}
    for i = 0, 7 do
        local ang = i * (math.pi * 2 / 8) + math.pi / 8
        table.insert(fillPoints, cx + math.cos(ang) * 10)
        table.insert(fillPoints, cy + math.sin(ang) * 10)
    end
    love.graphics.polygon("fill", fillPoints)
    
    -- Neon wireframe glow layers (Static)
    for i = 2, 1, -1 do
        love.graphics.setColor(baseCol[1], baseCol[2], baseCol[3], 0.15 * (3 - i))
        love.graphics.setLineWidth(i * 2.5)
        drawBaseShape()
    end
    love.graphics.setColor(baseCol[1], baseCol[2], baseCol[3], 1)
    love.graphics.setLineWidth(1.5)
    drawBaseShape()
    
    -- 2. Stationary Glowing Barrel (Dynamically shifts color and flares heat)
    love.graphics.push()
    love.graphics.translate(cx, cy)
    love.graphics.rotate(self.rotation or self.angle or 0)
    
    local barrelLength = self.barrel or 15
    local barrelWidth = 4
    
    -- Render static barrel pointing along local X-axis
    local function drawBarrelShape()
        love.graphics.rectangle("line", 0, -barrelWidth/2, barrelLength, barrelWidth, 1, 1)
    end
    
    love.graphics.setColor(barrelCol[1], barrelCol[2], barrelCol[3], 0.15 + chargeGlowBoost * 0.4)
    love.graphics.rectangle("fill", 0, -barrelWidth/2, barrelLength, barrelWidth, 1, 1)
    
    for i = 2, 1, -1 do
        love.graphics.setColor(barrelCol[1], barrelCol[2], barrelCol[3], 0.15 * (3 - i) + chargeGlowBoost)
        love.graphics.setLineWidth(i * 2.5 + chargeWidthBoost)
        drawBarrelShape()
    end
    love.graphics.setColor(barrelCol[1], barrelCol[2], barrelCol[3], 1)
    love.graphics.setLineWidth(2)
    drawBarrelShape()
    
    -- Shining breach core glow flaring with charge
    love.graphics.setColor(barrelCol[1], barrelCol[2], barrelCol[3], 0.5 + chargeGlowBoost)
    love.graphics.circle("fill", 0, 0, 3 + chargeWidthBoost * 0.5)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.circle("fill", 0, 0, 1.5)
    
    love.graphics.pop()
    
    love.graphics.setLineWidth(1)
    love.graphics.setColor(1, 1, 1, 1)
end

return SequenceTurret
