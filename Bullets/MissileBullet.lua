local Bullet = require("Bullets.Bullet")
local explosionEffect = require("Game.Effects.IndependantEffects.explosion")

local MissileBullet = setmetatable({}, { __index = Bullet })
MissileBullet.__index = MissileBullet

function MissileBullet:new(config)
    config = config or {}
    config.name = config.name or "Missile"
    config.bulletSpeed = config.bulletSpeed or 300
    config.damage = config.damage or 60
    config.explosionDamage = config.explosionDamage or config.damage or 60
    config.radius = config.radius or 120
    config.pierce = 1 -- Explodes immediately on first target impact
    config.lifespan = config.lifespan or 4
    config.w = config.w or 6
    config.h = config.h or 4
    config.shape = "rectangle"
    config.color = config.color or {0.7, 0.2, 0.9, 1}
    
    local b = Bullet:new(config)
    setmetatable(b, { __index = self })
    
    b.maxTrail = 15 -- Generates a robust prominent fading exhaust plume
    
    -- Pre-cache custom explosion effect template to handle splash logic
    b.explosionInstance = explosionEffect:new({
        explosionDamage = b.explosionDamage,
        radius = b.radius,
        color = b.color
    })
    
    return b
end

function MissileBullet:onHit(target)
    if self.destroyed then return end
    
    -- Instantiate or refresh splash explosion logic payload
    local exp = self.explosionInstance
    if not exp then
        exp = explosionEffect:new({
            explosionDamage = self:getStat("explosionDamage") or self:getStat("damage") or 60,
            radius = self:getStat("radius") or 120,
            color = self.color
        })
    end
    
    -- Trigger independent splash explosion passing current impact coordinate and bullet source
    exp:trigger(target, self)
    
    -- Terminate missile instance instantaneously avoiding any downstream single-target pierce iteration
    self:died()
end

function MissileBullet:draw()
    local r, g, bColor, a = unpack(self.color or {0.7, 0.2, 0.9, 1})
    
    -- 1. Fading Prominent Thruster Exhaust Trail
    if #self.trail > 1 then
        for i = 1, #self.trail - 1 do
            local p1 = self.trail[i]
            local p2 = self.trail[i+1]
            local alpha = (1 - (i / #self.trail)) * 0.6
            
            -- Outer fiery orange/red exhaust glow
            love.graphics.setColor(1, 0.5, 0, alpha * 0.5)
            love.graphics.setLineWidth(8 - (i / #self.trail) * 5)
            love.graphics.line(p1.x, p1.y, p2.x, p2.y)
            
            -- Core high-temperature yellow/white exhaust core line
            love.graphics.setColor(1, 1, 0.5, alpha)
            love.graphics.setLineWidth(2)
            love.graphics.line(p1.x, p1.y, p2.x, p2.y)
        end
    end
    
    -- 2. Render Distinct Geometric Missile Fuselage
    love.graphics.push()
    love.graphics.translate(self.x, self.y)
    love.graphics.rotate(self.angle)
    
    local mw, mh = self.w or 6, self.h or 4
    local halfH = mh / 2
    
    -- Premium Multi-Layer Neon Aura Outlines
    for layers = 2, 1, -1 do
        love.graphics.setColor(r, g, bColor, 0.15 * (3 - layers))
        love.graphics.setLineWidth(layers * 2)
        
        -- Rectangular central core casing spanning full width
        love.graphics.rectangle("line", -mw, -halfH, mw * 2, mh)
        -- Rounded leading nose tip
        love.graphics.arc("line", "open", mw, 0, halfH, -math.pi / 2, math.pi / 2)
        -- Two flush rear stabilizing right-angled fins
        love.graphics.polygon("line", -mw, -halfH, -mw, -halfH - 2, -mw + 3, -halfH)
        love.graphics.polygon("line", -mw, halfH, -mw, halfH + 2, -mw + 3, halfH)
    end
    
    -- Solid Core Interior Fills
    love.graphics.setColor(r, g, bColor, 0.85)
    love.graphics.rectangle("fill", -mw, -halfH, mw * 2, mh)
    love.graphics.arc("fill", "pie", mw, 0, halfH, -math.pi / 2, math.pi / 2)
    love.graphics.polygon("fill", -mw, -halfH, -mw, -halfH - 2, -mw + 3, -halfH)
    love.graphics.polygon("fill", -mw, halfH, -mw, halfH + 2, -mw + 3, halfH)
    
    -- High-contrast absolute white core outer wireframe highlights
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.setLineWidth(1.5)
    love.graphics.rectangle("line", -mw, -halfH, mw * 2, mh)
    love.graphics.arc("line", "open", mw, 0, halfH, -math.pi / 2, math.pi / 2)
    love.graphics.polygon("line", -mw, -halfH, -mw, -halfH - 2, -mw + 3, -halfH)
    love.graphics.polygon("line", -mw, halfH, -mw, halfH + 2, -mw + 3, halfH)
    
    love.graphics.pop()
    
    love.graphics.setLineWidth(1)
    love.graphics.setColor(1, 1, 1, 1)
end

function MissileBullet.drawStationary(color, mw, mh)
    local r, g, bColor, a = unpack(color or {0.7, 0.2, 0.9, 1})
    mw = mw or 6
    mh = mh or 4
    local halfH = mh / 2
    
    -- Outlined layered neon missile core casing spanning full width
    for layers = 2, 1, -1 do
        love.graphics.setColor(r, g, bColor, 0.15 * (3 - layers))
        love.graphics.setLineWidth(layers * 2)
        love.graphics.rectangle("line", -mw, -halfH, mw * 2, mh)
        love.graphics.arc("line", "open", mw, 0, halfH, -math.pi / 2, math.pi / 2)
        -- Two flush rear stabilizing right-angled fins
        love.graphics.polygon("line", -mw, -halfH, -mw, -halfH - 2, -mw + 3, -halfH)
        love.graphics.polygon("line", -mw, halfH, -mw, halfH + 2, -mw + 3, halfH)
    end
    
    -- Solid neon interior core fill
    love.graphics.setColor(r, g, bColor, 0.85)
    love.graphics.rectangle("fill", -mw, -halfH, mw * 2, mh)
    love.graphics.arc("fill", "pie", mw, 0, halfH, -math.pi / 2, math.pi / 2)
    love.graphics.polygon("fill", -mw, -halfH, -mw, -halfH - 2, -mw + 3, -halfH)
    love.graphics.polygon("fill", -mw, halfH, -mw, halfH + 2, -mw + 3, halfH)
    
    -- Distinct bright core wireframe accent
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.setLineWidth(1.5)
    love.graphics.rectangle("line", -mw, -halfH, mw * 2, mh)
    love.graphics.arc("line", "open", mw, 0, halfH, -math.pi / 2, math.pi / 2)
    love.graphics.polygon("line", -mw, -halfH, -mw, -halfH - 2, -mw + 3, -halfH)
    love.graphics.polygon("line", -mw, halfH, -mw, halfH + 2, -mw + 3, halfH)
end

return MissileBullet
