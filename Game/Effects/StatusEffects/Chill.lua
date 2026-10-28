-- Chill.lua - Core status of the ice synergy.
--
-- Chill builds up in (possibly fractional) stacks and drains at a fixed rate,
-- pausing briefly after each application.
-- Each stack slows the enemy, compounding with other stacks and other slows.
-- When the stacks reach the freeze threshold they reset to 0 and the enemy is
-- frozen (same effect as a stun), then thaws: slowed and immune to chill until
-- the thaw ends. Bosses (tier 5) need more stacks and freeze for less time.
--
-- Usage from a turret: hitEffects = { Chill.onHit({ amount = 1, chance = 0.3 }) }
-- Usage from code:     Chill.apply(enemy, amount, { source = turret })

local Chill = {
    SLOW_PER_STACK       = 0.10, -- each stack: speed x0.9 (partial stacks scale smoothly)
    DECAY_PER_SECOND     = 1 / 1.5, -- one stack every 1.5s
    DECAY_DELAY          = 0.3, -- each application pauses decay for this long
    FREEZE_STACKS        = 5,
    BOSS_FREEZE_STACKS   = 10,
    FREEZE_DURATION      = 2,
    BOSS_FREEZE_DURATION = 0.75,
    THAW_DURATION        = 1.5,
    THAW_SLOW            = 0.5,
    BOSS_TIER            = 5,

    -- "hidden_" keeps these out of the generic status-dot row; Chill.draw
    -- renders them instead.
    CHILL_NAME  = "hidden_chill",
    FREEZE_NAME = "hidden_freeze",
}

local ICE_COLOR = { 0.55, 0.85, 1 }

-- -----------------------------------------------------------------------------
-- Chill state: one per enemy, holds the stack count and its slow
-- -----------------------------------------------------------------------------
local ChillState = {}
ChillState.__index = ChillState

function ChillState:new()
    return setmetatable({
        name = Chill.CHILL_NAME,
        displayName = "Chill",
        isDebuff = true,
        stacks = 0,
        decayDelay = 0, -- seconds left before decay resumes
        duration = math.huge, -- set to 0 once drained so the manager removes it
        statModifiers = { speed = { compoundMult = 1 } },
    }, ChillState)
end

function ChillState:refreshSlow()
    self.statModifiers.speed.compoundMult = (1 - Chill.SLOW_PER_STACK) ^ self.stacks
end

function ChillState:onUpdate(dt, target)
    -- Burn off the decay delay first; only the leftover time drains stacks
    local paused = math.min(dt, self.decayDelay)
    self.decayDelay = self.decayDelay - paused
    dt = dt - paused
    if dt <= 0 then return end
    self.stacks = math.max(0, self.stacks - Chill.DECAY_PER_SECOND * dt)
    if self.stacks <= 0 then
        self.duration = 0
    end
    self:refreshSlow()
    target.effectManager:markDirty()
end

-- -----------------------------------------------------------------------------
-- Freeze state: frozen (stunned), then thawing (slowed, immune to chill)
-- -----------------------------------------------------------------------------
local FreezeState = {}
FreezeState.__index = FreezeState

function FreezeState:new(freezeDuration, frozenBy)
    return setmetatable({
        frozenBy = frozenBy, -- whatever applied the freezing chill (credited for thaw damage)
        name = Chill.FREEZE_NAME,
        displayName = "Frozen",
        isDebuff = true,
        phase = "frozen",
        elapsed = 0,
        freezeDuration = freezeDuration,
        duration = freezeDuration + Chill.THAW_DURATION,
        statModifiers = { stunned = { add = 1 } },
    }, FreezeState)
end

function FreezeState:onUpdate(dt, target)
    self.elapsed = self.elapsed + dt
    if self.phase == "frozen" and self.elapsed >= self.freezeDuration then
        self.phase = "thawing"
        self.displayName = "Thawing"
        self.statModifiers = { speed = { compoundMult = 1 - Chill.THAW_SLOW } }
        target.effectManager:markDirty()
        -- Artifacts can react to the thaw (Heart of the Tundra). A kill during
        -- the transition still counts as a frozen kill.
        if target.game and target.game.artifacts then
            self.thawTransition = true
            target.game.artifacts:trigger("onEnemyThaw", target)
            self.thawTransition = false
        end
    end
end

-- Enemies fire onDeath on their effects as they die; tell the game about
-- frozen kills (Ice Market pays out on them).
function FreezeState:onDeath(target)
    local frozenKill = self.phase == "frozen" or self.thawTransition
    if frozenKill and target.game and target.game.onFrozenEnemyDied then
        target.game:onFrozenEnemyDied(target)
    end
end

-- -----------------------------------------------------------------------------
-- Queries
-- -----------------------------------------------------------------------------
function Chill.isBoss(target)
    return (target.tier or 0) >= Chill.BOSS_TIER
end

function Chill.getFreezeThreshold(target)
    return Chill.isBoss(target) and Chill.BOSS_FREEZE_STACKS or Chill.FREEZE_STACKS
end

--- Current chill stacks (fractional), 0 when not chilled.
function Chill.getStacks(target)
    local em = target and target.effectManager
    local state = em and em:getEffect(Chill.CHILL_NAME)
    return state and state.stacks or 0
end

function Chill.isFrozen(target)
    local em = target and target.effectManager
    local state = em and em:getEffect(Chill.FREEZE_NAME)
    return state ~= nil and state.phase == "frozen"
end

--- True while frozen or thawing, i.e. while chill can't be applied.
function Chill.isImmune(target)
    local em = target and target.effectManager
    return em ~= nil and em:getEffect(Chill.FREEZE_NAME) ~= nil
end

--- Ice turrets are the ones that deal ice damage.
function Chill.isIceTurret(obj)
    return obj ~= nil and obj.isType ~= nil and obj:isType("turret") and obj.damageType == "ice"
end

function Chill.isThawing(target)
    local em = target and target.effectManager
    local state = em and em:getEffect(Chill.FREEZE_NAME)
    return state ~= nil and state.phase == "thawing"
end

--- Extra damage fraction against a target from one chill-damage bonus
--- { chilledMax = x, frozen = y }: scales 0..x with progress toward freezing
--- (so bosses, which need more stacks, scale the same way); frozen targets get y.
function Chill.getDamageBonus(target, bonus)
    if Chill.isFrozen(target) then
        return bonus.frozen
    end
    return bonus.chilledMax * math.min(1, Chill.getStacks(target) / Chill.getFreezeThreshold(target))
end

--- Damage multiplier against a target from a list of chill-damage bonuses
--- (they add together, like other damage buffs). nil or empty list -> 1.
function Chill.getDamageMultiplier(target, bonuses)
    local total = 0
    for _, bonus in ipairs(bonuses or {}) do
        total = total + Chill.getDamageBonus(target, bonus)
    end
    return 1 + total
end

-- -----------------------------------------------------------------------------
-- Applying chill
-- -----------------------------------------------------------------------------

--- Multiplier on all chill applied, from game-wide effects (Overchill spell).
--- Overlapping sources don't stack: the strongest one wins.
function Chill.getApplyMultiplier(game)
    local mult = 1
    local em = game and game.enemyEffectManager
    for _, effect in ipairs(em and em.activeEffects or {}) do
        if effect.chillMultiplier and effect.chillMultiplier > mult then
            mult = effect.chillMultiplier
        end
    end
    return mult
end

--- Freezes a target outright, clearing its chill. Ignored while frozen or thawing.
-- @param source any|nil: what froze it (a turret or its bullet), credited for thaw damage
-- @return boolean true if the target was frozen
function Chill.freeze(target, source)
    local em = target and target.effectManager
    if not em or target.destroyed or em:getEffect(Chill.FREEZE_NAME) then return false end
    local state = em:getEffect(Chill.CHILL_NAME)
    if state then em:removeEffect(state) end
    local duration = Chill.isBoss(target) and Chill.BOSS_FREEZE_DURATION or Chill.FREEZE_DURATION
    em:applyEffect(FreezeState:new(duration, source))
    return true
end

--- What froze the target (a turret or its bullet), or nil if it isn't frozen /
--- thawing or nothing was credited (e.g. a spell).
function Chill.getFreezer(target)
    local state = target and target.effectManager and target.effectManager:getEffect(Chill.FREEZE_NAME)
    return state and state.frozenBy
end

--- Adds chill stacks to a target. Ignored while frozen or thawing.
-- @param opts table|nil: cap = this application never raises chill above `cap` stacks;
--                       source = the turret (or its bullet) applying it, credited if it freezes
-- @return boolean true if this application froze the target
function Chill.apply(target, amount, opts)
    local em = target and target.effectManager
    if not em or target.destroyed or not amount or amount <= 0 then return false end
    if em:getEffect(Chill.FREEZE_NAME) then return false end

    amount = amount * Chill.getApplyMultiplier(target.game)
    local state = em:getEffect(Chill.CHILL_NAME)
    if opts and opts.cap then
        amount = math.min(amount, opts.cap - (state and state.stacks or 0))
        if amount <= 0 then return false end
    end

    if not state then
        em:applyEffect(ChillState:new())
        state = em:getEffect(Chill.CHILL_NAME)
    end

    state.stacks = state.stacks + amount
    state.decayDelay = Chill.DECAY_DELAY
    if state.stacks >= Chill.getFreezeThreshold(target) then
        return Chill.freeze(target, opts and opts.source)
    end

    state:refreshSlow()
    em:recalculateStats()
    return false
end

-- -----------------------------------------------------------------------------
-- Hit effect for turrets / bullets
-- -----------------------------------------------------------------------------
local ChillOnHit = {}
ChillOnHit.__index = ChillOnHit

--- Hit-effect template that applies chill to whatever the bullet hits.
-- @param config table: amount (stacks per hit, may be fractional, default 1),
--                      chance (0-1, default 1),
--                      perSecond (instead of amount: stacks per second for a
--                      turret firing once a second, split across its shots and
--                      pellets; uses base stats, so fire-rate and pellet buffs
--                      add hits and raise it),
--                      rateScaling (with perSecond, default 0: chill per second
--                      grows as baseFireRate ^ rateScaling, so 0 = the same for
--                      every turret and 1 = a fixed amount per shot),
--                      pelletScaling (with perSecond, default 0: pellets count
--                      as extra fire rate for rateScaling, pellets ^ pelletScaling
--                      shots each, so 0 = they don't and 1 = each is a full shot),
--                      maxPerShot (with perSecond: cap on the chill one shot's
--                      pellets add up to),
--                      name (default "chill"; turrets keep one hit effect per name)
function Chill.onHit(config)
    config = config or {}
    return setmetatable({
        name = config.name or "chill",
        isIndependent = true,
        amount = config.amount or 1,
        perSecond = config.perSecond,
        rateScaling = config.rateScaling or 0,
        pelletScaling = config.pelletScaling or 0,
        maxPerShot = config.maxPerShot or math.huge,
        hitChance = config.chance or 1,
    }, ChillOnHit)
end

-- Chill one hit applies. `source` is the bullet (its turret is source.source)
-- or, for beams, the turret itself.
function ChillOnHit:getAmount(source)
    if not self.perSecond then return self.amount end
    -- Unbuffed values: buffs then add hits of the same size
    local shooter = source and (source.source or source)
    local fireRate = shooter and shooter.fireRate or 0
    if fireRate <= 0 then return math.min(self.perSecond, self.maxPerShot) end
    local pellets = math.max(1, shooter.pelletCount or 1)
    local effectiveRate = fireRate * pellets ^ self.pelletScaling
    local perShot = self.perSecond * effectiveRate ^ self.rateScaling / fireRate
    return math.min(perShot, self.maxPerShot) / pellets
end

-- Bullets fire independent effects through trigger(target, bullet).
function ChillOnHit:trigger(target, source)
    if not target or not target.isType or not target:isType("enemy") then return end
    if self.hitChance < 1 and math.random() > self.hitChance then return end
    Chill.apply(target, self:getAmount(source), { source = source })
end

-- EffectManager:applyEffect routes independent effects through onApply.
function ChillOnHit:onApply(target, source)
    self:trigger(target, source)
end

-- -----------------------------------------------------------------------------
-- Visuals (drawn in the overlay pass, world space)
-- -----------------------------------------------------------------------------
local function drawBody(enemy, mode)
    if enemy.drawCustomShape and enemy.shape ~= "arrow" then
        enemy:drawCustomShape(mode, enemy.x, enemy.y)
    else
        local r = (enemy.getStat and enemy:getStat("size") or enemy.size or 10) * 0.8
        love.graphics.circle(mode, enemy.x, enemy.y, r)
    end
end

-- Pip row under the enemy: one pip per stack needed to freeze. `filled` is the
-- stack count shown (the last pip partially filled); `alpha` scales the fill.
local function drawPips(enemy, threshold, filled, alpha)
    local pip, gap = 3, 1
    local rowW = threshold * pip + (threshold - 1) * gap
    local px = enemy.x - rowW / 2
    local py = enemy.y + (enemy.h or enemy.size or 10) / 2 + 3
    for i = 1, threshold do
        local x = px + (i - 1) * (pip + gap)
        local fill = math.max(0, math.min(1, filled - (i - 1)))
        love.graphics.setColor(0.05, 0.1, 0.15, 0.8)
        love.graphics.rectangle("fill", x, py, pip, pip)
        if fill > 0 then
            love.graphics.setColor(ICE_COLOR[1], ICE_COLOR[2], ICE_COLOR[3], alpha)
            love.graphics.rectangle("fill", x, py, pip * fill, pip)
        end
    end
end

--- Chilled: blue tint deepening per stack + a pip row under the enemy.
--- Frozen: solid icy-white fill + pale outline. Thawing: flashing full pip row.
function Chill.draw(enemy)
    local em = enemy.effectManager
    if not em then return end
    local freeze = em:getEffect(Chill.FREEZE_NAME)
    local chill = em:getEffect(Chill.CHILL_NAME)
    if not freeze and not chill then return end

    love.graphics.push("all")
    if freeze and freeze.phase == "frozen" then
        love.graphics.setColor(0.9, 0.97, 1, 0.75)
        drawBody(enemy, "fill")
        love.graphics.setColor(0.85, 0.95, 1, 1)
        love.graphics.setLineWidth(2)
        drawBody(enemy, "line")
    elseif freeze then
        local threshold = Chill.getFreezeThreshold(enemy)
        local pulse = (math.sin(love.timer.getTime() * 8) + 1) / 2
        drawPips(enemy, threshold, threshold, 0.25 + 0.75 * pulse)
    elseif chill then
        local threshold = Chill.getFreezeThreshold(enemy)
        local ratio = math.min(1, chill.stacks / threshold)
        love.graphics.setColor(ICE_COLOR[1], ICE_COLOR[2], ICE_COLOR[3], 0.1 + 0.4 * ratio)
        drawBody(enemy, "fill")
        drawPips(enemy, threshold, chill.stacks, 1)
    end
    love.graphics.pop()
end

return Chill
