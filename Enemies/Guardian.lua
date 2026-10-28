local Enemy = require("Enemies.Enemy")
local Guardian = setmetatable({}, {__index = Enemy})
Guardian.__index = Guardian

Guardian.SHIELD_RINGS = 3 -- rings sent out when it shields its allies
Guardian.SHIELD_RING_GAP = 0.15 -- seconds between them
Guardian.SHIELD_COOLDOWN = 12 -- seconds between shield grants
Guardian.FIRST_SHIELD_DELAY = 1.5 -- seconds after spawning before the first grant, so
                                  -- the allies it spawned with are still in range
Guardian.SHIELD_AMOUNT = 100 -- shield given to each ally
Guardian.SHIELD_RADIUS = 90 -- reach of the shield grant (the aura mutation keeps auraRadius)
Guardian.MAX_SHIELD_TARGETS = 5 -- allies shielded per grant: unshielded first, then closest

local Stats = {
    name = "Guardian",
    reward = 50,
    armour = 0,
    hitbox = true,
    effectManager = true,
}

function Guardian:new(config)
    config = config or {}
    for key, value in pairs(Stats) do
        config[key] = config[key] or value
    end
    
    local obj = Enemy:new(config)
    setmetatable(obj, { __index = self })
    
    obj.auraRadius = config.auraRadius or 75
    if config.grantsShield ~= nil then
        obj.grantsShield = config.grantsShield
    else
        obj.grantsShield = true
    end
    if config.hasAura ~= nil then
        obj.hasAura = config.hasAura
    else
        obj.hasAura = false
    end
    obj.shieldAmount = config.shieldAmount or Guardian.SHIELD_AMOUNT
    obj.shieldRadius = config.shieldRadius or Guardian.SHIELD_RADIUS
    obj.shieldCooldown = config.shieldCooldown or Guardian.SHIELD_COOLDOWN
    obj.maxShieldTargets = config.maxShieldTargets or Guardian.MAX_SHIELD_TARGETS
    obj.firstShieldDelay = config.firstShieldDelay or Guardian.FIRST_SHIELD_DELAY
    -- Start most of the way through the cooldown: the first grant comes early
    obj.shieldTimer = math.max(0, obj.shieldCooldown - obj.firstShieldDelay)
    obj.auraMult = config.auraMult or -0.25
    
    return obj
end

function Guardian:update(dt)
    if self.destroyed then return end
    
    -- Call parent update (Enemy.lua handles navigation, base collision, etc.)
    Enemy.update(self, dt)
    
    if self:getStat("stunned", 0) > 0 then return end
    
    -- 1. Aura Logic (Upgrade): Buff nearby allies using the effect system
    if self.hasAura then
        local radiusSq = self.auraRadius * self.auraRadius
        local auraEffectTemplate = {
            name = "GuardianAura",
            duration = 0.5, -- Refreshable short duration
            maxStacks = 1,
            statModifiers = {
                damageReductionMultiplier = { mult = self.auraMult }
            },
            globalStacks = 1
        }

        for _, obj in ipairs(self.game.objects) do
            if obj.isType and obj:isType("enemy") and obj ~= self and not obj.destroyed then
                local dx = obj.x - self.x
                local dy = obj.y - self.y
                if dx*dx + dy*dy <= radiusSq then
                    local existing = obj.effectManager:getEffect("GuardianAura")
                    if existing then
                        existing.duration = 0.2 -- Refresh duration
                    else
                        obj.effectManager:applyEffect(auraEffectTemplate)
                    end
                end
            end
        end
    end
    
    -- 2. Shield Logic (Innate)
    if self.grantsShield then
        self.shieldTimer = self.shieldTimer + dt
        if self.shieldTimer >= self.shieldCooldown then
            self.shieldTimer = 0
            self:grantShieldsToNearby()
            -- Shield pulse: a few blue rings rolling out one after another
            for i = 0, Guardian.SHIELD_RINGS - 1 do
                self.game:spawnExpandingCircle(self.x, self.y, self.w * 0.5, self.shieldRadius, Enemy.SHIELD_COLOR, 0.7,
                    i * Guardian.SHIELD_RING_GAP)
            end
        end
    end
end

--- Tops up the shields of up to maxShieldTargets allies in range that are below
--- shieldAmount: allies with no shield first, then the closest. With no allies
--- in range at all, it shields itself. Returns the enemies shielded.
function Guardian:grantShieldsToNearby()
    local radiusSq = self.shieldRadius * self.shieldRadius
    local candidates = {}
    local alliesInRange = 0
    for _, obj in ipairs(self.game.objects) do
        if obj.isType and obj:isType("enemy") and obj ~= self and not obj.destroyed then
            local dx = obj.x - self.x
            local dy = obj.y - self.y
            local distSq = dx*dx + dy*dy
            if distSq <= radiusSq then
                alliesInRange = alliesInRange + 1
                if (obj.shield or 0) < self.shieldAmount then
                    table.insert(candidates, { enemy = obj, distSq = distSq, unshielded = (obj.shield or 0) <= 0 })
                end
            end
        end
    end
    if alliesInRange == 0 and (self.shield or 0) < self.shieldAmount then
        table.insert(candidates, { enemy = self, distSq = 0, unshielded = true })
    end
    table.sort(candidates, function(a, b)
        if a.unshielded ~= b.unshielded then return a.unshielded end
        return a.distSq < b.distSq
    end)

    local shielded = {}
    for i = 1, math.min(self.maxShieldTargets, #candidates) do
        local obj = candidates[i].enemy
        obj.shield = self.shieldAmount
        if not obj.maxShield or obj.maxShield < self.shieldAmount then
            obj.maxShield = self.shieldAmount
        end
        table.insert(shielded, obj)
    end
    return shielded
end

function Guardian:drawShape(mode, x, y, w, h)
    local thickness = w * 0.35
    -- Vertical Bar
    love.graphics.rectangle(mode, x + (w - thickness)/2, y, thickness, h)
    -- Horizontal Bar
    love.graphics.rectangle(mode, x, y + (h - thickness)/2, w, thickness)
end

function Guardian:draw()
    local r, g, b, a = unpack(self.color)
    local drawX = self.x - self.w/2
    local drawY = self.y - self.h/2
    
    -- Layer 1: Empty Base (Dim)
    love.graphics.setColor(r, g, b, Enemy.EMPTY_ALPHA)
    self:drawShape("fill", drawX, drawY, self.w, self.h)
    
    -- Layer 2: HP Fill (Scissor bottom-up)
    local maxHp = self:getStat("maxHp")
    local fillRatio = self.hp / maxHp
    local scissorY = drawY + self.h * (1 - fillRatio)
    local scissorH = self.h * fillRatio
    
    SetGameScissor(drawX, scissorY, self.w, scissorH)
    love.graphics.setColor(r, g, b, Enemy.HP_ALPHA)
    self:drawShape("fill", drawX, drawY, self.w, self.h)
    
    -- Add bright cap line
    -- We do this by setting a very thin scissor and redrawing the shape fill
    if fillRatio > 0 and fillRatio < 1 then
        SetGameScissor(drawX, scissorY, self.w, 2)
        love.graphics.setColor(r, g, b, 1)
        self:drawShape("fill", drawX, drawY, self.w, self.h)
        SetGameScissor()
    end
    
    SetGameScissor()
    
    -- Layer 3: Neon Border & Glow (shields are drawn as brackets by drawAnimated)
    self:drawNeonOutline({ r, g, b }, 2.5, function() self:drawShape("line", drawX, drawY, self.w, self.h) end)
    
    -- Aura Range Visual (Faint circle) - Only if upgrade active
    if self.hasAura then
        love.graphics.setColor(r, g, b, 0.03)
        love.graphics.circle("fill", self.x, self.y, self.auraRadius)
        love.graphics.setColor(r, g, b, 0.15)
        love.graphics.setLineWidth(1)
        love.graphics.circle("line", self.x, self.y, self.auraRadius)
    end
end

-- Drawn as a cross, so it floats like other non-square enemies
function Guardian:isGrounded() return false end

return Guardian
