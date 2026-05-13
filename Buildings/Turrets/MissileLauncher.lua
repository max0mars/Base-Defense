local Turret = require("Buildings.Turrets.Turret")
local Utils = require("Classes.Utils")
local MissileBullet = require("Bullets.MissileBullet")

local MissileLauncher = setmetatable({}, { __index = Turret })
MissileLauncher.__index = MissileLauncher

MissileLauncher.template = {
    name = "Missile Launcher",
    rotation = 0,
    turnSpeed = 4,
    fireRate = 0.3,  -- Extremely heavy and deliberate: 1 shot every 5 seconds
    range = 700,     -- Exceptional standoff capability
    barrel = 15,
    color = {0.7, 0.2, 0.9, 1}, -- Vibrant neon purple theme
    baseShape = "square",
    barrelShape = "single",
    types = { turret = true },
    shapePattern = {{0,0}},
    firingArc = {
        direction = 0,
        minRange = 0,
        angle = math.pi
    },
    sfx = "missile_01",
    
    -- Splash & Projectile Scaling Properties
    bulletName = "Missile",
    bulletSpeed = 350,
    damage = 10,
    explosionDamage = 20,
    radius = 60,
    damageType = "explosive",
    pierce = 1,
    lifespan = 5,
    bulletW = 6,
    bulletH = 4,
    bulletShape = "rectangle",
    hitEffects = {}
}

function MissileLauncher:new(config)
    local baseConfig = Utils.deepCopy(MissileLauncher.template)
    if config then
        for k, v in pairs(config) do
            baseConfig[k] = v
        end
    end
    
    baseConfig.bulletType = MissileBullet
    local t = Turret:new(baseConfig)
    setmetatable(t, { __index = self })
    
    -- Ensure custom splash variables are initialized onto instance for stat lookups
    t.explosionDamage = baseConfig.explosionDamage
    t.radius = baseConfig.radius
    t.sfx = baseConfig.sfx or "missile_01"
    
    return t
end

function MissileLauncher:fire(args)
    if AUDIO then
        AUDIO:playSFX(self.sfx or "missile_01")
    end
    
    local x, y = self:getFirePoint()
    if args and args.fireX and args.fireY then
        x, y = args.fireX, args.fireY
    end
    
    local currentHitEffects = {}
    if self.hitEffects then
        for _, e in ipairs(self.hitEffects) do
            table.insert(currentHitEffects, e)
        end
    end
    
    local config = {
        name = self:getStat("bulletName") or "Missile",
        x = x,
        y = y,
        angle = self.rotation,
        bulletSpeed = self:getStat("bulletSpeed") or 350,
        damage = self:getStat("damage") or 100,
        explosionDamage = self:getStat("explosionDamage") or self:getStat("damage") or 100,
        radius = self:getStat("radius") or 120,
        pierce = 1,
        lifespan = self:getStat("lifespan") or 4,
        damageType = self:getStat("damageType") or "explosive",
        w = self.bulletW or 11,
        h = self.bulletH or 6,
        shape = self.bulletShape or "rectangle",
        hitbox = true,
        hitEffects = currentHitEffects,
        game = self.game,
        source = self,
        color = self.color or {0.7, 0.2, 0.9, 1},
        tags = {"bullet"},
        types = { bullet = true },
        targetX = args and args.targetX or nil,
        targetY = args and args.targetY or nil
    }
    
    if args then
        for k, v in pairs(args) do
            config[k] = v
        end
    end
    
    self.game:addObject(self.bulletType:new(config))
end

function MissileLauncher:draw(drawx, drawy)
    local cx, cy = drawx or self.x, drawy or self.y
    if not drawx and not drawy then
        cx, cy = self:getCenterPosition()
    end
    
    if self.showArc then
        self:drawFiringArc(cx, cy, 0.4)
    end
    
    local r, g, bColor, a = unpack(self.color or {1, 0.2, 0.1, 1})
    
    -- 1. Render Sturdy Geometric Gantry/Platform Base
    local bw, bh = 12, 12
    local basePoints = {
        cx - bw, cy - bh,
        cx + bw, cy - bh,
        cx + bw, cy + bh,
        cx - bw, cy + bh
    }
    
    -- Semi-transparent premium glass inner fill
    love.graphics.setColor(r, g, bColor, 0.12)
    love.graphics.polygon("fill", basePoints)
    
    local function drawBaseLine()
        love.graphics.polygon("line", basePoints)
    end
    
    -- Layered out-sweeping neon base outer frame glows
    for layers = 2, 1, -1 do
        love.graphics.setColor(r, g, bColor, 0.15 * (3 - layers))
        love.graphics.setLineWidth(layers * 2.5)
        drawBaseLine()
    end
    love.graphics.setColor(r, g, bColor, 1)
    love.graphics.setLineWidth(1.5)
    drawBaseLine()
    
    -- 2. Rotating Turret Rail Track Assembly & Mounted Payload
    love.graphics.push()
    love.graphics.translate(cx, cy)
    love.graphics.rotate(self.rotation)
    
    -- Render bare structural guide track below payload
    love.graphics.setColor(0.4, 0.4, 0.4, 0.7)
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", -10, -2, 20, 4)
    love.graphics.line(-6, -5, -6, 5)
    love.graphics.line(6, -5, 6, 5)
    
    -- Check reload progress state mapping: self.cooldown steps down to 0
    local currentFR = self:getStat("fireRate") or 0.2
    local maxCooldown = 0
    if currentFR > 0 then maxCooldown = 1 / currentFR end
    local isReloaded = (self.cooldown or 0) <= (maxCooldown * 0.3)
    
    -- If placed as blueprint preview or fully unspooled past 50%, show loaded ordnance
    if self.isPreview or not self.game or isReloaded then
        love.graphics.push()
        love.graphics.translate(0, 0) -- Slide loaded payload slightly forward along the guide track
        
        local bw = self:getStat("bulletW") or self.bulletW or 11
        local bh = self:getStat("bulletH") or self.bulletH or 6
        if self.bulletType and self.bulletType.drawStationary then
            self.bulletType.drawStationary(self.color, bw, bh)
        elseif MissileBullet and MissileBullet.drawStationary then
            MissileBullet.drawStationary(self.color, bw, bh)
        end
        
        love.graphics.pop()
    end
    
    love.graphics.pop()
    
    love.graphics.setLineWidth(1)
    love.graphics.setColor(1, 1, 1, 1)
end

return MissileLauncher
