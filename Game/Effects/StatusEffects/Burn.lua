-- Burn.lua - Core status of the fire synergy.
--
-- Burn builds up in (possibly fractional) stacks. Its damage per second comes
-- from the stage the stack count is in (STAGES); separately, stacks decay
-- faster the more there are (getDecayRate), so a little burn is easy to keep
-- up and a lot of it needs many sources feeding it at once.
--
-- Stacks from every source share one pool per enemy. Each source's share of
-- the pool is tracked so DamageStats credits burn damage to the turrets in
-- proportion to the stacks they added.
--
-- Usage from a turret: hitEffects = { Burn.onHit({ amount = 3 }) }
-- Usage from code:     Burn.apply(enemy, amount, { source = turret })

local Burn = {
    -- A stage applies from `stacks` up to the next stage's threshold
    STAGES = {
        { stacks = 0,  dps = 10 },
        { stacks = 10, dps = 20 },
        { stacks = 20, dps = 30 },
    },

    -- Stacks lost per second = DECAY_BASE + DECAY_SCALE * stacks ^ DECAY_POWER.
    -- With the defaults: ~2/s at 6 stacks (one Flare Gun keeps that up),
    -- 4.5/s at 10 and 16.5/s at 20.
    DECAY_BASE  = 0.5,
    DECAY_SCALE = 0.04,
    DECAY_POWER = 2,

    TICK = 0.2, -- seconds between damage ticks

    -- Visuals: stage 3's progress bar is full at this many stacks, and particle
    -- size / count / colour stop growing there too
    VISUAL_MAX_STACKS = 30,

    -- "hidden_" keeps these out of the generic status-dot row; Burn.draw
    -- renders them instead.
    STATE_NAME = "hidden_burn",
    OIL_NAME   = "hidden_oil", -- see Oil.lua (looked up by name to avoid a require loop)
}

-- -----------------------------------------------------------------------------
-- Tuning queries
-- -----------------------------------------------------------------------------

--- Stacks lost per second at this many stacks (before multipliers).
function Burn.getDecayRate(stacks)
    if stacks <= 0 then return 0 end
    return Burn.DECAY_BASE + Burn.DECAY_SCALE * stacks ^ Burn.DECAY_POWER
end

--- Stage index (1..#STAGES) for a stack count, 0 when not burning.
function Burn.getStage(stacks)
    if not stacks or stacks <= 0 then return 0 end
    local stage = 1
    for i, s in ipairs(Burn.STAGES) do
        if stacks >= s.stacks then stage = i end
    end
    return stage
end

--- Base damage per second for a stack count (0 when not burning).
function Burn.getStageDps(stacks)
    local stage = Burn.getStage(stacks)
    return stage > 0 and Burn.STAGES[stage].dps or 0
end

--- 0..1 progress through the current stage (stage 3 fills up to VISUAL_MAX_STACKS).
function Burn.getStageProgress(stacks)
    local stage = Burn.getStage(stacks)
    if stage == 0 then return 0 end
    local from = Burn.STAGES[stage].stacks
    local nextStage = Burn.STAGES[stage + 1]
    local to = nextStage and nextStage.stacks or Burn.VISUAL_MAX_STACKS
    return math.max(0, math.min(1, (stacks - from) / math.max(1, to - from)))
end

-- -----------------------------------------------------------------------------
-- Multipliers
-- -----------------------------------------------------------------------------

-- Product of `field` over the enemy's effects and the global enemy effects
-- (artifacts like Persistent Flames, zones like Blazing Flames).
local function effectProduct(target, field)
    local mult = 1
    local em = target and target.effectManager
    while em do
        for _, effect in ipairs(em.activeEffects) do
            if effect[field] then mult = mult * effect[field] end
        end
        em = em.parent
    end
    return mult
end

--- Multiplier on burn damage against a target: fire damage buffs on the player
--- (Cheap Accelerants) times any burn-damage effects on the enemy.
function Burn.getDamageMultiplier(target)
    local mult = effectProduct(target, "burnDamageMult")
    local pem = target and target.game and target.game.playerEffectManager
    if pem then
        mult = mult * pem:getStatMult("fire_damage")
    end
    return mult
end

--- Multiplier on burn decay against a target.
function Burn.getDecayMultiplier(target)
    return effectProduct(target, "burnDecayMult")
end

-- -----------------------------------------------------------------------------
-- Burn state: one per enemy, holds the stacks and who added them
-- -----------------------------------------------------------------------------
local BurnState = {}
BurnState.__index = BurnState

function BurnState:new()
    return setmetatable({
        name = Burn.STATE_NAME,
        displayName = "Burn",
        isDebuff = true,
        stacks = 0,
        tickTimer = 0,
        duration = math.huge, -- set to 0 once burnt out so the manager removes it
        -- Passed to takeDamage as the source: Enemy:creditDamage splits each tick
        -- between creditShares (turret -> stacks it added, scaled down with decay)
        credit = { creditShares = {}, creditTotal = 0 },
        particles = {},
        emitTimer = 0,
    }, BurnState)
end

--- Adds stacks, crediting them to `creditKey` (a turret, or nil for no one).
function BurnState:addStacks(amount, creditKey)
    self.stacks = self.stacks + amount
    if creditKey then
        local shares = self.credit.creditShares
        shares[creditKey] = (shares[creditKey] or 0) + amount
    end
    self.credit.creditTotal = self.stacks
end

-- Shrinks every share with the pool so newer sources aren't drowned out.
function BurnState:setStacks(stacks)
    local ratio = self.stacks > 0 and stacks / self.stacks or 0
    for key, share in pairs(self.credit.creditShares) do
        self.credit.creditShares[key] = share * ratio
    end
    self.stacks = stacks
    self.credit.creditTotal = stacks
end

function BurnState:onUpdate(dt, target)
    if self.stacks > 0 then
        self.tickTimer = self.tickTimer + dt
        while self.tickTimer >= Burn.TICK and not target.destroyed do
            self.tickTimer = self.tickTimer - Burn.TICK
            local damage = Burn.getStageDps(self.stacks) * Burn.getDamageMultiplier(target) * Burn.TICK
            target:takeDamage(damage, "fire", nil, nil, { "dot" }, self.credit)
        end
        local decay = Burn.getDecayRate(self.stacks) * Burn.getDecayMultiplier(target) * dt
        self:setStacks(math.max(0, self.stacks - decay))
    end
    if self.stacks <= 0 then
        self.duration = 0
    end
    self:updateParticles(dt, target)
end

-- Enemies fire onDeath on their effects as they die. Kills only: an enemy
-- reaching the base doesn't spread its flames (Combustion).
function BurnState:onDeath(target)
    if target.reachedBase or self.stacks <= 0 then return end
    if target.game and target.game.artifacts then
        target.game.artifacts:trigger("onBurningEnemyDied", target, self)
    end
end

-- -----------------------------------------------------------------------------
-- Queries
-- -----------------------------------------------------------------------------

function Burn.getState(target)
    local em = target and target.effectManager
    return em and em:getEffect(Burn.STATE_NAME)
end

--- Current burn stacks (fractional), 0 when not burning.
function Burn.getStacks(target)
    local state = Burn.getState(target)
    return state and state.stacks or 0
end

function Burn.isBurning(target)
    return Burn.getStacks(target) > 0
end

--- Fire turrets are the ones that deal fire damage.
function Burn.isFireTurret(obj)
    return obj ~= nil and obj.isType ~= nil and obj:isType("turret") and obj.damageType == "fire"
end

-- -----------------------------------------------------------------------------
-- Applying burn
-- -----------------------------------------------------------------------------

local function getOrCreateState(target)
    local em = target.effectManager
    local state = em:getEffect(Burn.STATE_NAME)
    if not state then
        em:applyEffect(BurnState:new())
        state = em:getEffect(Burn.STATE_NAME)
    end
    return state
end

--- The turret behind a source (bullet -> turret) that burn damage is credited
--- to, so shares merge per turret. nil for spells.
function Burn.creditKeyFor(source)
    local DamageStats = require("Game.Core.DamageStats")
    return DamageStats.resolveTurret(source)
end
local creditKeyFor = Burn.creditKeyFor

--- Adds stacks with no artifact or oil reactions (spreading, transfers).
-- @param creditKey any|nil: the turret credited for these stacks
function Burn.addRaw(target, amount, creditKey)
    local em = target and target.effectManager
    if not em or target.destroyed or not amount or amount <= 0 then return end
    getOrCreateState(target):addStacks(amount, creditKey)
end

--- Applies burn: one application of `amount` stacks. Fuel Tank and other
--- artifacts adjust the amount; oil on the target ignites for bonus stacks.
-- @param opts table|nil: source = the turret (or its bullet) applying it
-- @return number stacks actually added
function Burn.apply(target, amount, opts)
    local em = target and target.effectManager
    if not em or target.destroyed or not amount or amount <= 0 then return 0 end

    local source = opts and opts.source
    local game = target.game
    if game and game.artifacts then
        amount = game.artifacts:modify("modifyBurnApplied", amount, target, source)
    end

    local state = getOrCreateState(target)
    state:addStacks(amount, creditKeyFor(source))

    -- Oil ignites: its bonus stacks are credited to whoever oiled the enemy
    local oil = em:getEffect(Burn.OIL_NAME)
    if oil then
        state:addStacks(oil.bonusStacks, creditKeyFor(oil.oiledBy))
        amount = amount + oil.bonusStacks
        em:removeEffect(oil)
        if oil.onIgnite then oil:onIgnite(target) end
    end
    return amount
end

-- -----------------------------------------------------------------------------
-- Hit effect for turrets / bullets
-- -----------------------------------------------------------------------------
local BurnOnHit = {}
BurnOnHit.__index = BurnOnHit

--- Hit-effect template that applies burn to whatever the bullet hits.
-- @param config table: amount (stacks per hit, default 1), chance (0-1, default 1),
--                      name (default "burn"; turrets keep one hit effect per name)
function Burn.onHit(config)
    config = config or {}
    return setmetatable({
        name = config.name or "burn",
        isIndependent = true,
        amount = config.amount or 1,
        hitChance = config.chance or 1,
    }, BurnOnHit)
end

-- Bullets fire independent effects through trigger(target, bullet).
function BurnOnHit:trigger(target, source)
    if not target or not target.isType or not target:isType("enemy") then return end
    if self.hitChance < 1 and math.random() > self.hitChance then return end
    Burn.apply(target, self.amount, { source = source })
end

-- EffectManager:applyEffect routes independent effects through onApply.
function BurnOnHit:onApply(target, source)
    self:trigger(target, source)
end

-- -----------------------------------------------------------------------------
-- Visuals
-- -----------------------------------------------------------------------------

-- Flame colour by stack count: deep orange -> orange -> yellow-white -> blue.
local COLOR_STOPS = {
    { 0,  { 1.0, 0.30, 0.05 } },
    { 10, { 1.0, 0.60, 0.10 } },
    { 20, { 1.0, 0.90, 0.55 } },
    { 30, { 0.40, 0.70, 1.00 } },
}

function Burn.getColor(stacks)
    if stacks <= COLOR_STOPS[1][1] then return COLOR_STOPS[1][2] end
    for i = 2, #COLOR_STOPS do
        local s, c = COLOR_STOPS[i][1], COLOR_STOPS[i][2]
        if stacks <= s then
            local ps, pc = COLOR_STOPS[i - 1][1], COLOR_STOPS[i - 1][2]
            local t = (stacks - ps) / (s - ps)
            return { pc[1] + (c[1] - pc[1]) * t, pc[2] + (c[2] - pc[2]) * t, pc[3] + (c[3] - pc[3]) * t }
        end
    end
    return COLOR_STOPS[#COLOR_STOPS][2]
end

-- Particle tuning, scaled by intensity (stacks / VISUAL_MAX_STACKS)
local PARTICLES_PER_SECOND = { 6, 60 }
local PARTICLE_SIZE = { 1.5, 4 }
local PARTICLE_ALPHA = { 0.45, 1 }
local PARTICLE_LIFE = { 0.35, 0.6 }
local PARTICLE_RISE = { 25, 60 } -- px per second upward
local MAX_PARTICLES = 80

local function lerp(range, t) return range[1] + (range[2] - range[1]) * t end

function BurnState:updateParticles(dt, target)
    local list = self.particles
    for i = #list, 1, -1 do
        local p = list[i]
        p.life = p.life - dt
        if p.life <= 0 then
            table.remove(list, i)
        else
            p.x = p.x + p.vx * dt
            p.y = p.y + p.vy * dt
        end
    end
    if self.stacks <= 0 then return end

    local intensity = math.min(1, self.stacks / Burn.VISUAL_MAX_STACKS)
    self.emitTimer = self.emitTimer + dt * lerp(PARTICLES_PER_SECOND, intensity)
    local half = (target.w or target.size or 20) / 2
    local color = Burn.getColor(self.stacks)
    while self.emitTimer >= 1 and #list < MAX_PARTICLES do
        self.emitTimer = self.emitTimer - 1
        local life = lerp(PARTICLE_LIFE, math.random())
        table.insert(list, {
            x = target.x + (math.random() * 2 - 1) * half * 0.8,
            y = target.y + (math.random() * 2 - 1) * half * 0.6,
            vx = (math.random() * 2 - 1) * 10,
            vy = -lerp(PARTICLE_RISE, intensity) * (0.7 + math.random() * 0.6),
            life = life,
            maxLife = life,
            size = lerp(PARTICLE_SIZE, intensity) * (0.7 + math.random() * 0.6),
            alpha = lerp(PARTICLE_ALPHA, intensity),
            color = color,
        })
    end
    self.emitTimer = math.min(self.emitTimer, 1)
end

-- Flame centred at (cx, cy), `w` wide and `h` tall: a round base under a
-- pointed tip (two convex shapes, so filled polygons draw cleanly).
local function drawFlame(cx, cy, w, h)
    local baseY = cy + h / 2 - w / 2
    love.graphics.circle("fill", cx, baseY, w / 2)
    love.graphics.polygon("fill", cx - w / 2, baseY, cx, cy - h / 2, cx + w / 2, baseY)
end

-- Icon per stage: { width, height, outer colour, inner colour }
local ICONS = {
    { 5, 7,  { 1.0, 0.45, 0.1 }, { 1.0, 0.8, 0.3 } },  -- small fire
    { 7, 10, { 1.0, 0.55, 0.1 }, { 1.0, 0.95, 0.6 } }, -- larger fire
    { 7, 10, { 0.3, 0.6, 1.0 },  { 0.85, 0.95, 1.0 } }, -- blue fire
}

--- Stage icon (with a progress bar under it) centred at (cx, cy).
function Burn.drawIcon(stacks, cx, cy)
    local stage = Burn.getStage(stacks)
    if stage == 0 then return end
    local icon = ICONS[math.min(stage, #ICONS)]
    local w, h, outer, inner = icon[1], icon[2], icon[3], icon[4]
    local flicker = 1 + 0.08 * math.sin(love.timer.getTime() * 18 + cx)

    love.graphics.setColor(outer[1], outer[2], outer[3], 1)
    drawFlame(cx, cy, w, h * flicker)
    love.graphics.setColor(inner[1], inner[2], inner[3], 1)
    drawFlame(cx, cy + h * 0.2, w * 0.5, h * 0.5 * flicker)

    -- Progress through the stage
    local barW, barH = 10, 2
    local bx, by = cx - barW / 2, cy + h / 2 + 2
    love.graphics.setColor(0.08, 0.04, 0.02, 0.85)
    love.graphics.rectangle("fill", bx, by, barW, barH)
    love.graphics.setColor(outer[1], outer[2], outer[3], 1)
    love.graphics.rectangle("fill", bx, by, barW * Burn.getStageProgress(stacks), barH)
end

--- Flame particles rising off the enemy, and the stage icon above it.
function Burn.draw(enemy)
    local state = Burn.getState(enemy)
    if not state then return end

    love.graphics.push("all")
    love.graphics.setBlendMode("add")
    for _, p in ipairs(state.particles) do
        local t = p.life / p.maxLife -- 1 at birth, 0 at death
        local c = p.color
        love.graphics.setColor(c[1], c[2] * (0.6 + 0.4 * t), c[3] * (0.5 + 0.5 * t), p.alpha * t)
        love.graphics.circle("fill", p.x, p.y, p.size * (0.4 + 0.6 * t))
    end
    love.graphics.setBlendMode("alpha")

    if state.stacks > 0 then
        local top = enemy.y - (enemy.h or enemy.size or 20) / 2
        Burn.drawIcon(state.stacks, enemy.x, top - 14)
    end
    love.graphics.pop()
end

return Burn
