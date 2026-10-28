local living_object = require("Classes.living_object")
local DamageTypes = require("Classes.DamageTypes")
local Navigators = require("Physics.Navigators")
local Chill = require("Game.Effects.StatusEffects.Chill")
local Zombie = require("Enemies.Zombie")
local Enemy = setmetatable({}, {__index = living_object})
Enemy.__index = Enemy

local Stats = {
    name = "Basic",
    reward = 25,
    size = 20, -- Default size for basic enemies
    shape = "rectangle", -- Default shape for basic enemies
    color = {1, 0, 0, 1}, -- Default color for basic enemies
    hitbox = true, -- Enemies have hitboxes by default
    types = { enemy = true }, -- Using Multi-Type system
    effectManager = true, -- Enemies have a effectManager by default
    splitOnDeathChance = 0,
}   

local function getBaseStats(config)
    local isTesting = config.game and config.game.testingMode
    local index = isTesting and require("Game.Spawning.TestingEnemyIndex") or require("Game.Spawning.EnemyIndex")
    local name = config.name or Stats.name or "Basic"
    local normalizedName = name:lower():gsub("%s+", "")
    for _, entry in ipairs(index) do
        local entryId = entry.id:lower():gsub("%s+", "")
        local entryType = entry.type:lower():gsub("%s+", "")
        if entryId == normalizedName or entryType == normalizedName then
            return entry
        end
    end
    -- Fallback to Basic
    for _, entry in ipairs(index) do
        if entry.id == "Basic" then
            return entry
        end
    end
    return nil
end

function Enemy:new(config)
    config = config or {}
    local customTypes = config.types
    config.types = {}
    if customTypes then
        for k, v in pairs(customTypes) do
            config.types[k] = v
        end
    end
    
    local base = getBaseStats(config)
    if base then
        config.name = config.name or base.id
        config.maxHp = config.maxHp or base.maxHp
        config.damage = config.damage or base.damage
        config.speed = config.speed or base.speed
        config.color = config.color or base.color
        config.shape = config.shape or base.shape
        config.size = config.size or base.size
        config.isFlying = (config.isFlying == nil and base.isFlying) or config.isFlying
        config.tier = config.tier or base.tier -- tier 5 = boss (e.g. harder to freeze)
        if base.affinities and not config.affinities then
            config.affinities = {}
            for k, v in pairs(base.affinities) do
                config.affinities[k] = v
            end
        end
        if base.types then
            for k, v in pairs(base.types) do
                config.types[k] = config.types[k] or v
            end
        end
    end

    for key, value in pairs(Stats) do
        if key ~= "types" then
            config[key] = config[key] or value -- Use default values if not provided
        end
    end
    
    for key in pairs(Stats.types) do
        config.types[key] = true
    end
    
    config.w = config.w or config.size
    config.h = config.h or config.size
    local obj = living_object:new(config)
    -- Override default parent to point to enemy manager
    if obj.effectManager and obj.game.enemyEffectManager then
        obj.effectManager.parent = obj.game.enemyEffectManager
    end
    if obj.effectManager then
        obj.effectManager:recalculateStats()
    end
    setmetatable(obj, { __index = self })
    obj:getTargetPos()
    
    local navType = config.navigator or (Navigators.USE_PATHFINDING and "GridNavigator" or "DirectNavigator")
    obj.navigator = Navigators[navType]:new(obj, obj.game)
    
    obj.enemyId = config.enemyId or (base and base.id) or config.name
    obj.shield = 0
    obj.maxShield = 50 -- Default reference for shield visuals
    
    return obj
end

function Enemy:_createGlowCanvas()
    local padding = 12
    local cw = self.w + padding * 2
    local ch = self.h + padding * 2
    
    -- Create canvas and render the glowing outline
    self.canvas = love.graphics.newCanvas(cw, ch)
    love.graphics.setCanvas(self.canvas)
    love.graphics.clear(0, 0, 0, 0)
    
    local r, g, b, a = unpack(self.color or {1, 0, 0, 1})
    
    -- Draw glow layers (static)
    for i = 6, 1, -1 do
        local alpha = 0.05 * (1 - i/7)
        love.graphics.setColor(r, g, b, alpha)
        love.graphics.setLineWidth(i * 3)
        love.graphics.rectangle("line", padding, padding, self.w, self.h)
    end
    
    -- Main crisp outline
    love.graphics.setColor(r, g, b, 1)
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", padding, padding, self.w, self.h)
    
    love.graphics.setCanvas()
    self.canvasPadding = padding
end

-- -----------------------------------------------------------------------------
-- Motion effects: trails, hovering, and ability animations (portal, spread,
-- pulse, glint). Visual only, except that portal and spread hold the enemy in
-- place while they play (see isHalted). The battle and the codex demo both
-- advance them with updateMotionFx and draw through drawAnimated.
-- -----------------------------------------------------------------------------

Enemy.TRAIL_TIME = 1.2 -- seconds a trail point lasts (a stopped enemy's trail fades over this)
Enemy.TRAIL_LENGTH = 2 -- trail length behind the body, in body sizes
Enemy.TRAIL_SAMPLE = 0.03 -- seconds between trail points
Enemy.HOVER_HEIGHT = 1.5 -- px floating enemies bob up and down
Enemy.HOVER_SPEED = 2.4 -- radians per second
Enemy.PORTAL_TIME = 0.22 -- seconds to shrink away, and again to grow back
Enemy.SPREAD_TIME = 0.3 -- seconds split-off children take to spread apart
Enemy.PULSE_TIME = 0.2 -- seconds of one pulse
Enemy.GLINT_TIME = 0.5 -- seconds of a shine after being cleansed
Enemy.RISE_TIME = 0.45 -- seconds a raised zombie takes to grow back to full size
Enemy.SHIELD_COLOR = { 0.25, 0.55, 1.0 } -- shield brackets (matches the Guardian that grants it)
Enemy.SHIELD_HIT_TIME = 0.25 -- seconds the shield brackets pulse after a hit

local GROUND_SHAPES = { rectangle = true, soldier = true, tank = true }

--- While `untargetable` (a blinking Phantom) it doesn't count as an enemy, so
--- turrets, bullets, area damage and other enemies' abilities all pass it by.
--- Code that must still see it (wave completion, clearing the field) checks the
--- flag itself.
function Enemy:isType(typeName)
    if typeName == "enemy" and self.untargetable then return false end
    return self.types ~= nil and self.types[typeName] == true
end

--- Square-bodied enemies walk on the ground; every other shape floats.
function Enemy:isGrounded()
    return GROUND_SHAPES[self.shape or "rectangle"] == true
end

--- True while an animation holds the enemy in place.
function Enemy:isHalted()
    return self.portal ~= nil or self.spread ~= nil or self.rise ~= nil
end

--- Vertical bob of a floating enemy (0 for grounded ones).
function Enemy:getHoverOffset()
    if self:isGrounded() then return 0 end
    self.hoverPhase = self.hoverPhase or math.random() * math.pi * 2
    return math.sin((self.fxTime or 0) * Enemy.HOVER_SPEED + self.hoverPhase) * Enemy.HOVER_HEIGHT
end

--- Advances trails and ability animations.
function Enemy:updateMotionFx(dt)
    self.fxTime = (self.fxTime or 0) + dt
    local now = self.fxTime

    -- Trail: sample the position, drop points that have aged out
    self.trail = self.trail or {}
    self.trailClock = (self.trailClock or 0) + dt
    if self.trailClock >= Enemy.TRAIL_SAMPLE then
        self.trailClock = 0
        table.insert(self.trail, 1, { x = self.x, y = self.y, t = now })
    end
    while #self.trail > 0 and now - self.trail[#self.trail].t > Enemy.TRAIL_TIME do
        table.remove(self.trail)
    end

    -- Portal: shrink away, jump, grow back
    local portal = self.portal
    if portal then
        portal.t = portal.t + dt
        if not portal.jumped and portal.t >= Enemy.PORTAL_TIME then
            portal.jumped = true
            self.x, self.y = portal.x, portal.y
            self.trail = {}
            if self.recalculatePath then self:recalculatePath() end
        end
        if portal.t >= Enemy.PORTAL_TIME * 2 then self.portal = nil end
    end

    -- Spread: ease out from where it split to its own spot
    local spread = self.spread
    if spread then
        spread.t = math.min(Enemy.SPREAD_TIME, spread.t + dt)
        local p = spread.t / Enemy.SPREAD_TIME
        local ease = 1 - (1 - p) * (1 - p)
        self.x = spread.fromX + (spread.toX - spread.fromX) * ease
        self.y = spread.fromY + (spread.toY - spread.fromY) * ease
        if p >= 1 then
            self.spread = nil
            if self.recalculatePath then self:recalculatePath() end
        end
    end

    if self.pulse then
        self.pulse = self.pulse + dt
        if self.pulse >= Enemy.PULSE_TIME then self.pulse = nil end
    end
    if self.rise then
        self.rise = self.rise + dt
        if self.rise >= Enemy.RISE_TIME then self.rise = nil end
    end
    if self.glint then
        self.glint = self.glint + dt
        if self.glint >= Enemy.GLINT_TIME then self.glint = nil end
    end
    if self.shieldHit then
        self.shieldHit = self.shieldHit + dt
        if self.shieldHit >= Enemy.SHIELD_HIT_TIME then self.shieldHit = nil end
    end
end

--- Shrinks away, reappears at (x, y) and grows back.
function Enemy:startPortal(x, y)
    self.portal = { t = 0, x = x, y = y }
end

--- Slides from where it is to (x, y), popping up to full size on the way.
function Enemy:startSpread(x, y)
    self.spread = { t = 0, fromX = self.x, fromY = self.y, toX = x, toY = y }
end

function Enemy:startPulse() self.pulse = 0 end
function Enemy:startGlint() self.glint = 0 end
--- Grows up from nothing where it stands (a zombie being raised), holding still meanwhile.
function Enemy:startRise() self.rise = 0 end

--- Draw scale from the running animations (1 when none).
function Enemy:getFxScale()
    local scale = 1
    if self.portal then
        local p = math.min(1, self.portal.t / Enemy.PORTAL_TIME)
        local s = self.portal.jumped and (self.portal.t / Enemy.PORTAL_TIME - 1) or (1 - p)
        scale = scale * math.max(0, math.min(1, s)) ^ 0.7
    end
    if self.spread then
        scale = scale * (0.7 + 0.3 * (self.spread.t / Enemy.SPREAD_TIME))
    end
    if self.rise then
        local p = math.min(1, self.rise / Enemy.RISE_TIME)
        scale = scale * (1 - (1 - p) * (1 - p))
    end
    if self.pulse then
        scale = scale * (1 + 0.22 * math.sin(math.pi * self.pulse / Enemy.PULSE_TIME))
    end
    return scale
end

--- Fading ribbon behind the enemy: along the bottom of grounded enemies, through
--- the middle of floating ones.
function Enemy:drawTrail(hover)
    local trail = self.trail
    if not trail or #trail < 2 or self.portal then return end
    local r, g, b = unpack(self.color or { 1, 0, 0, 1 })
    local size = self.w or self:getStat("size") or 20
    local grounded = self:isGrounded()
    local offsetY = grounded and (self.h or size) * 0.32 or hover
    local baseWidth = grounded and (self.h or size) * 0.35 or size * 0.55
    local now = self.fxTime or 0
    -- Measured along the path: starts at the back edge, tapers out over TRAIL_LENGTH bodies
    local startAt = size * 0.45
    local length = size * Enemy.TRAIL_LENGTH

    love.graphics.push("all")
    love.graphics.setLineStyle("smooth")
    local prevX, prevY = self.x, self.y + offsetY
    local along = 0
    for i = 1, #trail do
        local p = trail[i]
        local x, y = p.x, p.y + offsetY
        local seg = math.sqrt((x - prevX) ^ 2 + (y - prevY) ^ 2)
        local segEnd = along + seg
        if segEnd > startAt and seg > 0 then
            -- Skip the part of this segment still under the body
            local from = math.max(0, (startAt - along) / seg)
            local x1, y1 = prevX + (x - prevX) * from, prevY + (y - prevY) * from
            local k = (1 - math.min(1, (segEnd - startAt) / length)) * (1 - math.min(1, (now - p.t) / Enemy.TRAIL_TIME))
            if k <= 0 then break end
            love.graphics.setColor(r, g, b, (grounded and 0.4 or 0.35) * k)
            love.graphics.setLineWidth(math.max(1, baseWidth * (0.4 + 0.6 * k)))
            love.graphics.line(x1, y1, x, y)
        end
        along = segEnd
        prevX, prevY = x, y
    end
    love.graphics.pop()
end

-- A four-pointed star of `size` at (x, y).
local function drawSparkle(x, y, size, alpha)
    local thin = size * 0.18
    love.graphics.setColor(1, 1, 1, alpha)
    love.graphics.polygon("fill", x, y - size, x + thin, y, x, y + size, x - thin, y)
    love.graphics.polygon("fill", x - size, y, x, y - thin, x + size, y, x, y + thin)
    love.graphics.circle("fill", x, y, thin * 1.2)
end

--- Shine after a cleanse: a bright sweep across the body and two sparkles.
function Enemy:drawGlint(y)
    if not self.glint then return end
    local p = self.glint / Enemy.GLINT_TIME
    local size = self.w or 20
    love.graphics.push("all")
    -- Diagonal glare band sweeping top-left to bottom-right
    local sweep = -size + p * size * 2
    love.graphics.setColor(1, 1, 1, 0.55 * math.sin(math.pi * p))
    love.graphics.setLineWidth(size * 0.22)
    love.graphics.line(self.x + sweep - size * 0.4, y - size * 0.5, self.x + sweep + size * 0.1, y + size * 0.5)
    -- Sparkles: a big one top-right, a later small one bottom-left
    drawSparkle(self.x + size * 0.45, y - size * 0.45, size * 0.75 * math.sin(math.pi * p), 1)
    local p2 = math.max(0, (p - 0.3) / 0.7)
    if p2 > 0 then
        drawSparkle(self.x - size * 0.4, y + size * 0.35, size * 0.4 * math.sin(math.pi * p2), 0.9)
    end
    love.graphics.pop()
end

--- Shield: a blue "( )" pair either side of the body. Dims as the shield
--- drains and pulses (swells and brightens) when it takes a hit.
function Enemy:drawShield(y)
    local shield = self.shield or 0
    if shield <= 0 then return end
    local ratio = math.min(1, shield / math.max(1, self.maxShield or shield))
    local pulse = self.shieldHit and math.sin(math.pi * self.shieldHit / Enemy.SHIELD_HIT_TIME) or 0
    local size = self.w or 20
    local radius = size * 0.82 * (1 + 0.12 * pulse)
    local span = 0.75 -- half-angle of each bracket, radians
    local alpha = 0.25 + 0.75 * ratio
    local width = 2 + 1.5 * pulse
    local c = Enemy.SHIELD_COLOR
    local core = math.min(1, 0.15 * ratio + 0.55 * pulse) -- hotter core when fresh, white when just hit

    love.graphics.push("all")
    love.graphics.setLineStyle("smooth")
    for _, side in ipairs({ 0, math.pi }) do
        love.graphics.setColor(c[1], c[2], c[3], alpha)
        love.graphics.setLineWidth(width)
        love.graphics.arc("line", "open", self.x, y, radius, side - span, side + span)
        love.graphics.setColor(c[1] + (1 - c[1]) * core, c[2] + (1 - c[2]) * core, 1, alpha * 0.9)
        love.graphics.setLineWidth(math.max(1, width * 0.4))
        love.graphics.arc("line", "open", self.x, y, radius, side - span, side + span)
    end
    love.graphics.pop()
end

--- Draws the enemy with its trail, hover, animation scale and glint.
function Enemy:drawAnimated()
    local hover = self:getHoverOffset()
    self:drawTrail(hover)

    -- Hover by moving the body itself, so HP-fill clipping moves with it
    local baseY = self.y
    self.y = baseY + hover
    local scale = self:getFxScale()
    if scale ~= 1 then
        love.graphics.push()
        love.graphics.translate(self.x, self.y)
        love.graphics.scale(scale, scale)
        love.graphics.translate(-self.x, -self.y)
    end
    if scale > 0.01 then
        self:draw()
        self:drawShield(self.y)
    end
    if scale ~= 1 then love.graphics.pop() end
    self:drawGlint(self.y)
    self.y = baseY
end

function Enemy:update(dt)
    if self.destroyed then return end

    self.effectManager:update(dt) -- Update status effects
    self:updateMotionFx(dt)

    if self:getStat("stunned", 0) > 0 then
        return
    end

    self.w = self:getStat("size")
    self.h = self:getStat("size")
    self:getTargetPos()
    if self:isHalted() then return end

    if self.navigator then
        self.navigator:update(dt)
    end
    
    if self.x < self.target then
        self.game.base:takeDamage(self:getStat("damage"), "ballistic", self.x, self.y, self) -- Damage the base if the enemy reaches it
        self.reachedBase = true -- Not a kill (artifacts' onEnemyKilled skips it)
        self:died() -- Destroy the enemy if it reaches the base
    end
end

-- @param source: optional bullet/turret/effect source; credits the turret behind it in DamageStats
function Enemy:takeDamage(amount, damageType, hitX, hitY, damageTags, source)
    if not amount or type(amount) ~= "number" or amount ~= amount or amount <= 0 then
        return 0
    end
    DamageTypes.validate(damageType, damageTags)

    local damageMult = DamageTypes.affinityMultiplier(self.affinities, damageType, damageTags)
    amount = amount * damageMult

    -- Effectiveness vs this enemy's affinities (damage-type matchup), for feedback.
    local effectiveness = nil
    if damageMult < 1 then
        effectiveness = "resist"
    elseif damageMult > 1 then
        effectiveness = "weak"
    end

    -- Apply Damage Reduction (from Guardian Aura or other effects)
    local reduction = self:getStat("damageReductionMultiplier", 1)
    amount = amount * reduction

    if self.game.artifacts then
        amount = self.game.artifacts:modify("modifyEnemyDamage", amount, self, damageType, damageTags, source)
    end

    if amount > 1 then
        self.game:spawnDamageNumber(amount, hitX or self.x, hitY or self.y, damageType, effectiveness, damageTags)
    end

    -- 1. Check if shield exists
    if self.shield > 0 then
        self.shieldHit = 0 -- brackets pulse
        local oldShield = self.shield
        self.shield = self.shield - amount
        if self.shield <= 0 then
            self.shield = 0
            if oldShield > 0 then
                self.game:spawnArmorBreak(self.x, self.y)
            end
        end
        self:creditDamage(source, math.min(amount, oldShield), false)
        -- Explicitly return to nullify remaining damage from this attack
        return amount
    end

    -- 2. Apply damage to HP if no shield
    local hpBefore = self.hp
    if amount >= self.hp then
        self.hp = 0
    else
        self.hp = self.hp - amount
    end
    self:creditDamage(source, math.max(0, math.min(amount, hpBefore)), hpBefore > 0 and self.hp <= 0)
    if hpBefore > 0 and self.hp <= 0 then
        self.killingBlow = { source = source, damageType = damageType, damageTags = damageTags }
    end

    if self.hp <= 0 then
        self:died()
    end

    return amount
end

--- Records effective damage dealt by `source` in the battle's DamageStats,
--- and adds it (from any source, spells included) to the run's total.
function Enemy:creditDamage(source, dealt, killed)
    local ps = _G.PersistentState
    if ps and dealt and dealt > 0 then
        ps.totalDamageDealt = (ps.totalDamageDealt or 0) + dealt
    end
    if source and self.game and self.game.damageStats then
        self.game.damageStats:record(source, dealt, killed)
    end
end

function Enemy:getFuturePosition(time)
    local speed = self:getStat("speed")
    local distToTravel = speed * time
    if distToTravel <= 0 then return self.x, self.y end

    local nav = self.navigator
    -- If it's a DirectNavigator or no path
    if not nav or not nav.path or #nav.path == 0 then
        -- Direct horizontal movement towards target
        local dx = self.target - self.x
        local d = math.abs(dx)
        if d > 0 then
            local dir = dx / d
            if distToTravel >= d then
                return self.target, self.y
            else
                return self.x + dir * distToTravel, self.y
            end
        else
            return self.x, self.y
        end
    end

    local currentX, currentY = self.x, self.y
    local remainingDist = distToTravel

    -- Current target (already has offset applied in Navigator:calculateNodeTarget)
    local tx, ty = nav.tx, nav.ty
    if tx and ty then
        local dx = tx - currentX
        local dy = ty - currentY
        local d = math.sqrt(dx*dx + dy*dy)
        if d > 0 then
            if remainingDist <= d then
                return currentX + (dx/d) * remainingDist, currentY + (dy/d) * remainingDist
            end
            remainingDist = remainingDist - d
            currentX, currentY = tx, ty
        end
    end

    -- Future nodes
    for i = (nav.currentNodeIndex or 1) + 1, #nav.path do
        local prevNode = nav.path[i-1]
        local currNode = nav.path[i]
        
        -- World position of node center
        local bx = self.game.battlefieldGrid.x + (currNode.x - 1) * self.game.battlefieldGrid.cellSize + self.game.battlefieldGrid.cellSize / 2
        local by = self.game.battlefieldGrid.y + (currNode.y - 1) * self.game.battlefieldGrid.cellSize + self.game.battlefieldGrid.cellSize / 2
        
        -- Apply perpendicular offset (replicates GridNavigator:calculateNodeTarget logic)
        if nav.perpendicularOffset then
             local pdx = currNode.x - prevNode.x
             local pdy = currNode.y - prevNode.y
             local mag = math.sqrt(pdx*pdx + pdy*pdy)
             if mag > 0 then
                 local px = -pdy / mag
                 local py = pdx / mag
                 bx = bx + px * nav.perpendicularOffset
                 by = by + py * nav.perpendicularOffset
             end
        end
        
        local dx = bx - currentX
        local dy = by - currentY
        local d = math.sqrt(dx*dx + dy*dy)
        
        if d > 0 then
            if remainingDist <= d then
                return currentX + (dx/d) * remainingDist, currentY + (dy/d) * remainingDist
            end
            remainingDist = remainingDist - d
            currentX, currentY = bx, by
        end
    end

    -- Return the final path node position (reaches the base)
    return currentX, currentY
end

function Enemy:recalculatePath()
    if self.navigator and self.navigator.recalculate then
        self.navigator:recalculate()
    end
end

function Enemy:getVelocity()
    local currentSpeed = self:getStat("speed")
    return -currentSpeed, 0 -- Enemies move left by default
end

function Enemy:died()
    if self.isDead then return end
    self.isDead = true
    
    if self.effectManager then
        self.effectManager:triggerEvent("onDeath", self)
    end
    
    if AUDIO then AUDIO:playSFX("explosion_01") end
    
    if self.splitOnDeathChance and self.splitOnDeathChance > 0 and math.random() <= self.splitOnDeathChance then
        local EnemyRegistry = require("Game.Spawning.EnemyRegistry")
        local offsets = {
            {x = -12, y = -12},
            {x = 12, y = 12}
        }
        for i = 1, 2 do
            local spawnConfig = {
                game = self.game,
                x = self.x + offsets[i].x,
                y = self.y + offsets[i].y,
                name = self.name
            }
            local basicClass = require("Enemies.Enemy")
            local childInstance = basicClass:new(spawnConfig)
            EnemyRegistry:applyActiveMutations(childInstance)
            self.game:addObject(childInstance)
        end
    end
    
    self.game:EnemyDied(self) -- tell game manager I dead
    self:destroy() -- Call the destroy method from the base living_object
end

function Enemy:getTargetPos()
    local factor = 0.5
    if self.shape == "dart" then
        factor = 7 / 15
    elseif self.shape == "octagon" then
        factor = 0.6
    elseif self.shape == "arrow" then
        factor = 0.8
    end
    self.target = self.game.base.x + self.game.base.w / 2 + (self.w * factor)
end

function Enemy:checkBaseCollision()
    if self.x <= self.target then
        return true
    end
    return false
end

function Enemy:drawHealthBar()
    -- Health is now drawn as a fill effect inside the enemy sprite
end

function Enemy:drawStatusEffects()
    living_object.drawStatusEffects(self)
    Chill.draw(self)
end

-- Neon look: a dim body whose fill level shows HP, under a bright neon tube
-- outline; the frame-wide glow pass (Graphics/Glow.lua) adds the halo.
Enemy.EMPTY_ALPHA = 0.08 -- missing HP
Enemy.HP_ALPHA = 0.32 -- remaining HP, dim enough not to glow

--- Draws an outline as a neon tube: drawShape() is called twice, first in the
--- colour at `width`, then as a thinner near-white core. Zombies get the
--- Reanimator's green outline instead.
function Enemy:drawNeonOutline(color, width, drawShape)
    if self.isZombie then color = Zombie.COLOR end
    local r, g, b = color[1], color[2], color[3]
    love.graphics.setColor(r, g, b, 1)
    love.graphics.setLineWidth(width)
    drawShape()
    love.graphics.setColor(r + (1 - r) * 0.65, g + (1 - g) * 0.65, b + (1 - b) * 0.65, 0.9)
    love.graphics.setLineWidth(math.max(1, width * 0.4))
    drawShape()
end

function Enemy:drawCustomShape(mode, cx, cy)
    if self.shape == "dart" then
        local scale = self:getStat("size", 15) / 15
        love.graphics.push()
        love.graphics.translate(cx, cy)
        love.graphics.scale(scale, scale)
        love.graphics.polygon(mode, -7, 0, 7, -4, 4, 0, 7, 4)
        love.graphics.pop()
    elseif self.shape == "tank" then
        local scale = self:getStat("size", 22) / 22
        love.graphics.push()
        love.graphics.translate(cx, cy)
        love.graphics.scale(scale, scale)
        local pts = {
            -11, -10, 11, -10, 11, -7, 9, -7, 9, 7, 11, 7,
            11, 10, -11, 10, -11, 7, -9, 7, -9, -7, -11, -7
        }
        love.graphics.polygon(mode, pts)
        love.graphics.pop()
    elseif self.shape == "octagon" then
        local size = self:getStat("size", 20)
        local function getOctagonPoints(x, y, s)
            local pts = {}
            for i = 0, 7 do
                local angle = i * (math.pi / 4) + (math.pi / 8)
                table.insert(pts, x + math.cos(angle) * s)
                table.insert(pts, y + math.sin(angle) * s)
            end
            return pts
        end
        local points = getOctagonPoints(cx, cy, size * 0.6)
        love.graphics.polygon(mode, points)
    elseif self.shape == "cross" then
        local thickness = self.w * 0.35
        -- Vertical Bar
        love.graphics.rectangle(mode, cx - thickness/2, cy - self.h/2, thickness, self.h)
        -- Horizontal Bar
        love.graphics.rectangle(mode, cx - self.w/2, cy - thickness/2, self.w, thickness)
    elseif self.shape == "diamond" then
        local size = self.w / 2
        local pts = {
            cx, cy - size,           -- Top
            cx + size, cy,           -- Right
            cx, cy + size,           -- Bottom
            cx - size, cy            -- Left
        }
        love.graphics.polygon(mode, pts)
    elseif self.shape == "soldier" then
        love.graphics.rectangle(mode, cx - self.w/2, cy - self.h/2, self.w, self.h)
        local r, g, b, a = love.graphics.getColor()
        -- Use a grey color with the same alpha as the current rendering layer
        love.graphics.setColor(0.6, 0.6, 0.6, a)
        local padW = self.w * 0.2
        local padH = self.h * 0.6
        love.graphics.rectangle(mode, cx - self.w/2 - padW, cy - padH/2, padW, padH)
        love.graphics.rectangle(mode, cx + self.w/2, cy - padH/2, padW, padH)
        love.graphics.setColor(r, g, b, a)
    else
        love.graphics.rectangle(mode, cx - self.w/2, cy - self.h/2, self.w, self.h)
    end
end

function Enemy:draw()
    if self.shape == "arrow" then
        local r, g, b, a = unpack(self.color or {1, 0.5, 0, 1})
        local drawX = self.x
        local drawY = self.y
        local size = self:getStat("size")
        
        -- Calculate rotation (pointing towards target)
        local angle = 0
        if self.navigator and (self.navigator.tx or self.tx) then
            local targetX = self.navigator.tx or self.tx
            local targetY = self.navigator.ty or self.ty
            angle = math.atan2(targetY - self.y, targetX - self.x)
        else
            angle = math.pi -- Default facing left
        end

        local function getArrowPoints(cx, cy, s, ang)
            local points = {
                {cx + math.cos(ang) * s, cy + math.sin(ang) * s}, -- Tip
                {cx + math.cos(ang + 2.5) * s, cy + math.sin(ang + 2.5) * s}, -- Back-right
                {cx + math.cos(ang + math.pi) * (s * 0.4), cy + math.sin(ang + math.pi) * (s * 0.4)}, -- Indented back
                {cx + math.cos(ang - 2.5) * s, cy + math.sin(ang - 2.5) * s} -- Back-left
            }
            local flat = {}
            for _, p in ipairs(points) do
                table.insert(flat, p[1])
                table.insert(flat, p[2])
            end
            return flat
        end

        local arrowPoints = getArrowPoints(drawX, drawY, size * 0.8, angle)

        -- 1. Draw "Empty" Base State (Dim fill)
        love.graphics.setColor(r, g, b, Enemy.EMPTY_ALPHA)
        love.graphics.polygon("fill", arrowPoints)
        
        -- 2. Calculate Scissor Box for Health Fill (Draining effect)
        local maxHp = self:getStat("maxHp")
        local fillRatio = self.hp / maxHp
        
        local minY, maxY = arrowPoints[2], arrowPoints[2]
        for i = 4, #arrowPoints, 2 do
            local y = arrowPoints[i]
            if y < minY then minY = y end
            if y > maxY then maxY = y end
        end
        local actualH = maxY - minY
        
        local scissorY = minY + actualH * (1 - fillRatio)
        local scissorH = actualH * fillRatio
        
        -- 3. Draw "Health" Fill (Bright fill restricted by scissor)
        SetGameScissor(self.x - size, scissorY, size * 2, scissorH)
        love.graphics.setColor(r, g, b, Enemy.HP_ALPHA)
        love.graphics.polygon("fill", arrowPoints)
        
        if fillRatio > 0 and fillRatio < 1 then
            SetGameScissor(self.x - size, scissorY, size * 2, 2)
            love.graphics.setColor(r, g, b, 1)
            love.graphics.polygon("fill", arrowPoints)
            SetGameScissor()
        end
        
        SetGameScissor()
        
-- 4. Neon border
        self:drawNeonOutline({ r, g, b }, 2.5, function() love.graphics.polygon("line", arrowPoints) end)
        
        -- Draw debug path if debugMode
        if self.game.debugMode and self.navigator and self.navigator.path then
            love.graphics.setColor(0, 1, 0, 0.5)
            love.graphics.setLineWidth(2)
            local path = self.navigator.path
            local prevX, prevY = self.x, self.y
            for i = self.navigator.currentNodeIndex, #path do
                local node = path[i]
                local wx = self.game.battlefieldGrid.x + (node.x - 1) * self.game.battlefieldGrid.cellSize + self.game.battlefieldGrid.cellSize / 2
                local wy = self.game.battlefieldGrid.y + (node.y - 1) * self.game.battlefieldGrid.cellSize + self.game.battlefieldGrid.cellSize / 2
                love.graphics.line(prevX, prevY, wx, wy)
                prevX, prevY = wx, wy
            end
            love.graphics.setColor(1, 1, 1, 1)
            love.graphics.setLineWidth(1)
        end
        return
    end

    local r, g, b, a = unpack(self.color or {1, 0, 0, 1})
    local drawX = self.x - self.w/2
    local drawY = self.y - self.h/2
    local cx, cy = self.x, self.y
    
    -- 1. Layer 1 (Empty Base): Dim fill
    love.graphics.setColor(r, g, b, Enemy.EMPTY_ALPHA)
    self:drawCustomShape("fill", cx, cy)
    
    -- 2. Layer 2 (Normal HP Fill): Bright glow fill with bottom-up scissor
    local maxHp = self:getStat("maxHp")
    local fillRatio = self.hp / maxHp
    
    -- Calculate scissor
    local scissorY = drawY + self.h * (1 - fillRatio)
    local scissorH = self.h * fillRatio
    
    SetGameScissor(drawX, scissorY, self.w, scissorH)
    love.graphics.setColor(r, g, b, Enemy.HP_ALPHA)
    self:drawCustomShape("fill", cx, cy)
    
    -- Add a bright horizontal line at the health level "cap"
    if fillRatio > 0 and fillRatio < 1 then
        SetGameScissor(drawX, scissorY, self.w, 2)
        love.graphics.setColor(r, g, b, 1)
        self:drawCustomShape("fill", cx, cy)
        SetGameScissor()
    end
    
    SetGameScissor()
    
    -- 3. Neon border: bright tube outline (shields are drawn as brackets by drawAnimated)
    self:drawNeonOutline({ r, g, b }, 2.5, function() self:drawCustomShape("line", cx, cy) end)
    
    if self.game.debugMode and self.navigator and self.navigator.path then
        love.graphics.setColor(0, 1, 0, 0.5) -- Green transparent line for path
        love.graphics.setLineWidth(2)
        local path = self.navigator.path
        local startIdx = math.max(1, self.navigator.currentNodeIndex - 1)
        
        if startIdx <= #path then
            local prevX, prevY = self.x, self.y
            for i = self.navigator.currentNodeIndex, #path do
                local node = path[i]
                -- World position of node center
                local wx = self.game.battlefieldGrid.x + (node.x - 1) * self.game.battlefieldGrid.cellSize + self.game.battlefieldGrid.cellSize / 2
                local wy = self.game.battlefieldGrid.y + (node.y - 1) * self.game.battlefieldGrid.cellSize + self.game.battlefieldGrid.cellSize / 2
                
                love.graphics.line(prevX, prevY, wx, wy)
                prevX, prevY = wx, wy
            end
        end
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.setLineWidth(1)
    end
end

return Enemy
