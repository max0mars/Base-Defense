local ShotgunTurret = require("Buildings.Turrets.ShotgunTurret")
local Turret = require("Buildings.Turrets.Turret")
local Utils = require("Classes.Utils")

local PlasmaScattershot = setmetatable({}, { __index = ShotgunTurret })
PlasmaScattershot.__index = PlasmaScattershot

PlasmaScattershot.template = {
    name = "Plasma Scattershot",
    rotation = 0,
    turnSpeed = 6,
    fireRate = 2,  -- High-tech variant firing significantly faster (2.5 vs 0.7)
    range = 200,     -- Slightly higher range than base shotgun
    barrel = 10,
    color = {0.2, 0.6, 1, 1}, -- Neon blue core aesthetic
    baseShape = "square",
    barrelShape = "flared",
    types = { turret = true, legendary = true, energy = true },
    shapePattern = {{0,0}},
    firingArc = {
        direction = 0,
        minRange = 0,
        angle = math.rad(80)
    },
    sfx = "laser_02",  -- Appropriate energy weapon sound
    spread = math.rad(15), -- Focused energy scatter cone
    
    -- Bullet Properties (High-velocity plasma bolts)
    bulletName = "Plasma Bolt",
    bulletSpeed = 600,
    damage = 10,
    damageType = "energy",
    pierce = 1,
    lifespan = 1,
    bulletW = 4,
    bulletH = 4,
    bulletShape = "rectangle",
    hitEffects = {}
}

function PlasmaScattershot:new(config)
    local baseConfig = Utils.deepCopy(PlasmaScattershot.template)
    if config then
        for k, v in pairs(config) do
            baseConfig[k] = v
        end
    end
    
    -- Inherit from ShotgunTurret
    local t = ShotgunTurret:new(baseConfig)
    setmetatable(t, { __index = self })
    
    -- Custom Ammo System Parameters
    t.maxAmmo = 6
    t.currentAmmo = 6
    t.pelletCount = 6
    t.isReloading = false
    t.reloadCooldown = nil
    
    return t
end

function PlasmaScattershot:update(dt)
    -- Acquire target and check if an enemy is within range
    self:getTargetArc()
    
    local currentFireRate = self:getStat("fireRate") or 2.5
    local reloadTimePerAmmo = 3 / currentFireRate -- 50% of the normal fire rate
    
    -- Ammo reloading state transition logic
    if self.currentAmmo == 0 then
        self.isReloading = true
    elseif self.target == nil and self.currentAmmo < self.maxAmmo then
        self.isReloading = true
    elseif self.target ~= nil and self.currentAmmo > 0 then
        -- Immediately interrupt reload if an enemy enters range and we have ammo
        self.isReloading = false
        self.reloadCooldown = nil
    end
    
    -- Reload timer tick
    if self.isReloading then
        if not self.reloadCooldown then
            self.reloadCooldown = reloadTimePerAmmo
        end
        
        self.reloadCooldown = self.reloadCooldown - dt
        if self.reloadCooldown <= 0 then
            self.currentAmmo = self.currentAmmo + 1
            if self.currentAmmo >= self.maxAmmo then
                self.currentAmmo = self.maxAmmo
                self.isReloading = false
                self.reloadCooldown = nil
            else
                -- Start reloading next shell
                self.reloadCooldown = reloadTimePerAmmo
            end
        end
    end
    
    -- targeting and rotation logic
    -- We temporarily override the cooldown to be very large if currentAmmo is 0
    -- so that the base update doesn't trigger firing (while still allowing aiming/rotation)
    local originalCooldown = self.cooldown
    if self.currentAmmo == 0 then
        self.cooldown = 9999 -- block firing entirely
    end
    
    -- Execute targeting, leading, rotation and potential firing inside base Turret update
    Turret.update(self, dt)
    
    -- Restore original cooldown if we forced a blockade, and manually decay it
    if self.currentAmmo == 0 then
        self.cooldown = originalCooldown - dt
    end
end

function PlasmaScattershot:fire(args)
    if self.currentAmmo > 0 then
        self.currentAmmo = self.currentAmmo - 1
        ShotgunTurret.fire(self, args)
    end
end

function PlasmaScattershot:draw(drawx, drawy)
    local cx, cy = drawx or self.x, drawy or self.y
    if not drawx and not drawy then
        cx, cy = self:getCenterPosition()
    end

    if self.showArc then
        self:drawFiringArc(cx, cy, 0.4)
    end
    
    local r, g, b, a = unpack(self.color or {0.2, 0.6, 1, 1})
    
    -- 1. Render Heavy Sturdy Square Base
    local bw, bh = 8, 8
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

    -- 2. Draw custom horizontal ammo indicator near the bottom of the base (behind the barrel)
    local maxAmmo = self.maxAmmo or 6
    local currentAmmo = self.currentAmmo or 0
    local sqSize = 2
    local spacing = 1
    local totalWidth = maxAmmo * sqSize + (maxAmmo - 1) * spacing
    local startX = cx - totalWidth / 2
    
    -- Place ammo grid just inside the bottom edge of the base chassis (positive Y direction in Love2D)
    local sqY = cy + 7.5
    
    for idx = 1, maxAmmo do
        -- Interpolate color from Red (left, idx=1) to Neon Blue (right, idx=6)
        local t = (idx - 1) / (maxAmmo - 1)
        local ar = (1 - t) * 1.0 + t * 0.2
        local ag = (1 - t) * 0.1 + t * 0.6
        local ab = (1 - t) * 0.1 + t * 1.0
        
        local sqX = startX + (idx - 1) * (sqSize + spacing) + sqSize / 2
        
        -- Black border/background box
        love.graphics.setColor(0, 0, 0, 0.8)
        love.graphics.rectangle("fill", sqX - sqSize / 2 - 0.5, sqY - sqSize / 2 - 0.5, sqSize + 1, sqSize + 1)
        
        -- Lit/Unlit square
        if idx <= currentAmmo then
            love.graphics.setColor(ar, ag, ab, 1)
        else
            love.graphics.setColor(0.3, 0.3, 0.3, 1) -- Flat unlit grey
        end
        love.graphics.rectangle("fill", sqX - sqSize / 2, sqY - sqSize / 2, sqSize, sqSize)
    end
    
    -- 3. Render Flared Shotgun/Blunderbuss Barrel (drawn on top of base and ammo indicators)
    love.graphics.push()
    love.graphics.translate(cx, cy)
    love.graphics.rotate(self.rotation)
    
    local bl = self.barrel or 10
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
    
    -- 4. High-Intensity Central Core/Breach Glow
    love.graphics.setColor(r, g, b, 0.5)
    love.graphics.circle("fill", 0, 0, 4)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.circle("fill", 0, 0, 2)
    
    love.graphics.pop()
    
    -- Reset default paint parameters
    love.graphics.setLineWidth(1)
    love.graphics.setColor(1, 1, 1, 1)
end

return PlasmaScattershot
