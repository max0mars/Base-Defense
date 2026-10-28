-- Game/GUI/EnemyDemo.lua
-- The little looping animation in an enemy's entry: the enemy walks right to
-- left across a strip at its in-game speed (with any active mutations), scaled
-- up, while a short script shows off its ability. Enemies that affect others use
-- Grunts as stand-ins, and a small turret or the base wall act as props.
--
-- The actors are real enemy objects (so they look exactly like they do in a
-- battle) that live in a stand-in game; the scripts move them and play out
-- their abilities, rather than running the full battle logic.

local EnemyIndex = require("Game.Spawning.EnemyIndex")
local EnemyRegistry = require("Game.Spawning.EnemyRegistry")
local Chill = require("Game.Effects.StatusEffects.Chill")
local Zombie = require("Enemies.Zombie")
local Layout = require("Game.GUI.Layout")

local EnemyDemo = {}
EnemyDemo.__index = EnemyDemo

EnemyDemo.SCALE = 2         -- world px -> screen px in the strip
local RESTART_PAUSE = 0.8   -- seconds of empty strip between loops
local TURRET_X = 10         -- the turret prop sits at the strip's left edge
local WALL_X = 6            -- the base wall prop

local function entryFor(id)
    for _, e in ipairs(EnemyIndex) do
        if e.id == id then return e end
    end
end

-- -----------------------------------------------------------------------------
-- Construction
-- -----------------------------------------------------------------------------

--- `rect` is the strip on screen {x, y, w, h}.
function EnemyDemo.new(enemyId, rect)
    local demo = setmetatable({ enemyId = enemyId, rect = rect }, EnemyDemo)
    demo.W, demo.H = rect.w / EnemyDemo.SCALE, rect.h / EnemyDemo.SCALE
    demo:restart()
    return demo
end

function EnemyDemo:restart()
    self.t = 0
    self.actors = {}
    self.bullets = {}
    self.rings = {}
    self.texts = {}
    self.turret = nil
    self.wall = nil
    self.wait = nil
    -- Stand-in game: just what enemy objects need to exist and draw
    self.game = {
        objects = self.actors, debugMode = false,
        base = { x = -10000, y = 0, w = 0, h = 0 },
    }
    local script = EnemyDemo.scripts[self.enemyId] or EnemyDemo.scripts.default
    self.script = script
    script.setup(self)
end

--- Adds a real enemy of type `id` at (x, y), with active mutations applied.
function EnemyDemo:spawn(id, x, y, config)
    local entry = entryFor(id)
    if not entry then return nil end
    local cfg = { game = self.game, x = x, y = y, name = id }
    for k, v in pairs(config or {}) do cfg[k] = v end
    local e = entry.class:new(cfg)
    EnemyRegistry:applyActiveMutations(e)
    e.demoSpeedMult = 1
    table.insert(self.actors, e)
    return e
end

--- The star of the demo, entering from the right edge.
function EnemyDemo:spawnStar(y, config)
    local entry = entryFor(self.enemyId)
    local size = entry and entry.size or 20
    self.star = self:spawn(self.enemyId, self.W + size, y or self.H / 2, config)
    return self.star
end

-- -----------------------------------------------------------------------------
-- Props and effects
-- -----------------------------------------------------------------------------

--- A small turret at the left edge, firing at `pick()` every `interval` seconds.
function EnemyDemo:addTurret(opts)
    self.turret = {
        x = TURRET_X, y = self.H / 2, angle = 0, cooldown = opts.firstShot or 0.5,
        interval = opts.interval or 0.8, pick = opts.pick, onHit = opts.onHit,
        color = opts.color or { 1, 0.85, 0.3 }, flash = 0, slowed = 0,
    }
    return self.turret
end

function EnemyDemo:addWall()
    self.wall = { x = WALL_X, flash = 0 }
end

-- delay: seconds before the ring appears (for staggered rings)
function EnemyDemo:ring(x, y, radius, color, duration, delay)
    table.insert(self.rings, { x = x, y = y, r = radius, color = color, t = -(delay or 0), dur = duration or 0.6 })
end

function EnemyDemo:text(str, x, y, color)
    table.insert(self.texts, { str = tostring(str), x = x, y = y, color = color, t = 0 })
end

--- Damage to an actor: shields soak it first; an actor at 0 HP dies (`onDeath`).
function EnemyDemo:damage(e, amount, color)
    if not e or e.demoDead then return end
    local shieldHit = math.min(e.shield or 0, amount)
    if shieldHit > 0 then e.shieldHit = 0 end -- shield brackets pulse
    e.shield = (e.shield or 0) - shieldHit
    e.hp = e.hp - (amount - shieldHit)
    self:text(math.floor(amount + 0.5), e.x, e.y - e.h / 2, shieldHit > 0 and { 0.5, 0.75, 1 } or color)
    if e.hp <= 0 then
        e.hp = 0
        e.demoDead = true
        self:ring(e.x, e.y, e.w, { 1, 1, 1 }, 0.3)
        if self.script.onDeath then self.script.onDeath(self, e) end
    end
end

function EnemyDemo:heal(e, amount)
    if not e or e.demoDead then return end
    local healed = e:heal(amount)
    if healed >= 0.5 then self:text("+" .. math.floor(healed + 0.5), e.x, e.y - e.h / 2, { 0.3, 1, 0.45 }) end
end

function EnemyDemo:alive()
    local list = {}
    for _, e in ipairs(self.actors) do
        if not e.demoDead then table.insert(list, e) end
    end
    return list
end

--- The living actor nearest the left edge (the turret's target), or nil.
function EnemyDemo:frontmost(filter)
    local best
    for _, e in ipairs(self:alive()) do
        if e.x < self.W and (not filter or filter(e)) and (not best or e.x < best.x) then best = e end
    end
    return best
end

-- -----------------------------------------------------------------------------
-- Update
-- -----------------------------------------------------------------------------

function EnemyDemo:update(dt)
    if self.wait then
        self.wait = self.wait - dt
        if self.wait <= 0 then self:restart() end
        return
    end
    self.t = self.t + dt

    for _, e in ipairs(self.actors) do
        if not e.demoDead then
            if e.effectManager then e.effectManager:update(dt) end
            if e.updateMotionFx then e:updateMotionFx(dt) end
            local speed = e:getStat("speed") * (e.demoSpeedMult or 1)
            if (e:getStat("stunned", 0) or 0) > 0 or (e.isHalted and e:isHalted()) then speed = 0 end
            e.x = e.x - speed * dt
        end
    end

    if self.script.update then self.script.update(self, dt) end
    self:updateTurret(dt)
    self:updateEffects(dt)

    -- Loop once the star has walked off (or the script says it's done)
    local star = self.star
    local gone = not star or star.demoDead or star.x < -star.w
    if self.script.isDone then gone = self.script.isDone(self) end
    if gone then self.wait = RESTART_PAUSE end
end

function EnemyDemo:updateTurret(dt)
    local tr = self.turret
    if not tr then return end
    tr.flash = math.max(0, tr.flash - dt)
    local target = tr.pick and tr.pick(self)
    if target then tr.angle = math.atan2(target.y - tr.y, target.x - tr.x) end
    tr.cooldown = tr.cooldown - dt
    if target and tr.cooldown <= 0 then
        tr.cooldown = tr.interval * (1 + 0.35 * tr.slowed)
        table.insert(self.bullets, {
            x = tr.x + math.cos(tr.angle) * 6, y = tr.y + math.sin(tr.angle) * 6,
            target = target, speed = 260, color = tr.color, onHit = tr.onHit,
        })
    end
end

function EnemyDemo:updateEffects(dt)
    for i = #self.bullets, 1, -1 do
        local b = self.bullets[i]
        local tx, ty = b.target.x, b.target.y
        local dx, dy = tx - b.x, ty - b.y
        local d = math.sqrt(dx * dx + dy * dy)
        local step = b.speed * dt
        if b.target.demoDead or b.target.untargetable or (b.toTurret and not self.turret) then
            table.remove(self.bullets, i)
        elseif d <= step then
            table.remove(self.bullets, i)
            if b.onHit then b.onHit(self, b.target, b) end
        else
            b.x, b.y = b.x + dx / d * step, b.y + dy / d * step
        end
    end
    for i = #self.rings, 1, -1 do
        local r = self.rings[i]
        r.t = r.t + dt
        if r.t >= r.dur then table.remove(self.rings, i) end
    end
    for i = #self.texts, 1, -1 do
        local tx = self.texts[i]
        tx.t = tx.t + dt
        tx.y = tx.y - 18 * dt
        if tx.t >= 0.9 then table.remove(self.texts, i) end
    end
    if self.wall then self.wall.flash = math.max(0, self.wall.flash - dt) end
end

-- -----------------------------------------------------------------------------
-- Draw
-- -----------------------------------------------------------------------------

function EnemyDemo:draw()
    local r = self.rect
    love.graphics.push("all")
    love.graphics.setColor(0.03, 0.04, 0.06, 1)
    love.graphics.rectangle("fill", r.x, r.y, r.w, r.h, 6)
    -- Faint ground grid, like the battlefield
    love.graphics.setColor(0.25, 0.3, 0.4, 0.12)
    local cell = 25 * EnemyDemo.SCALE
    for gx = r.x + cell, r.x + r.w, cell do love.graphics.line(gx, r.y, gx, r.y + r.h) end

    SetGameScissor(r.x, r.y, r.w, r.h)
    Layout.pushView({ x = r.x, y = r.y, scale = EnemyDemo.SCALE, clip = r })

    if self.wall then
        local flash = self.wall.flash
        love.graphics.setColor(0.2 + 0.8 * flash, 1 - 0.8 * flash, 0.2, 0.9)
        love.graphics.setLineWidth(2)
        love.graphics.line(self.wall.x, 0, self.wall.x, self.H)
    end

    for _, ring in ipairs(self.rings) do
        local p = math.max(0, ring.t) / ring.dur
        love.graphics.setColor(ring.color[1], ring.color[2], ring.color[3], ring.t < 0 and 0 or 0.7 * (1 - p))
        love.graphics.setLineWidth(1.5)
        love.graphics.circle("line", ring.x, ring.y, ring.r * (0.3 + 0.7 * p))
    end

    if self.script.drawUnder then self.script.drawUnder(self) end
    for _, e in ipairs(self.actors) do
        if not e.demoDead then
            if e.drawAnimated then e:drawAnimated() else e:draw() end
            if e.drawStatusEffects then e:drawStatusEffects() end
        end
    end
    if self.script.drawOver then self.script.drawOver(self) end

    for _, b in ipairs(self.bullets) do
        love.graphics.setColor(b.color)
        love.graphics.circle("fill", b.x, b.y, b.radius or 1.5)
    end

    local tr = self.turret
    if tr then
        love.graphics.setColor(0.35 + 0.65 * tr.flash, 0.4, 0.5, 1)
        love.graphics.rectangle("fill", tr.x - 5, tr.y - 5, 10, 10, 2)
        love.graphics.setColor(0.85, 0.85, 0.9, 1)
        love.graphics.setLineWidth(2)
        love.graphics.line(tr.x, tr.y, tr.x + math.cos(tr.angle) * 8, tr.y + math.sin(tr.angle) * 8)
    end

    Layout.popView()
    SetGameScissor()

    -- Floating numbers in screen space, so they stay crisp
    for _, tx in ipairs(self.texts) do
        local sx, sy = r.x + tx.x * EnemyDemo.SCALE, r.y + tx.y * EnemyDemo.SCALE
        local c = tx.color or { 1, 1, 1 }
        local font = love.graphics.getFont()
        love.graphics.setColor(c[1], c[2], c[3], 1 - tx.t / 0.9)
        love.graphics.print(tx.str, sx - font:getWidth(tx.str) / 2, sy - font:getHeight())
    end
    if tr and tr.slowed > 0 then
        love.graphics.setColor(1, 0.4, 0.4, 0.9)
        love.graphics.print(string.rep("v", math.min(tr.slowed, 5)), r.x + tr.x * EnemyDemo.SCALE - 8, r.y + (tr.y + 8) * EnemyDemo.SCALE)
    end
    love.graphics.setColor(0.3, 0.45, 0.6, 0.7)
    love.graphics.setLineWidth(1)
    love.graphics.rectangle("line", r.x, r.y, r.w, r.h, 6)
    love.graphics.pop()
end

-- -----------------------------------------------------------------------------
-- Scripts: one per enemy. setup(demo) places the actors; update(demo, dt) plays
-- the ability; onDeath(demo, e) and isDone(demo) are optional.
-- -----------------------------------------------------------------------------

local scripts = {}
EnemyDemo.scripts = scripts

local function every(state, key, interval, dt, first)
    state[key] = (state[key] or (first or interval)) - dt
    if state[key] <= 0 then
        state[key] = state[key] + interval
        return true
    end
    return false
end

local function bulletHit(damage, color)
    return function(demo, target) demo:damage(target, damage, color) end
end

scripts.default = { setup = function(demo) demo:spawnStar() end }
scripts.Grunt = scripts.default

-- Scout: races past a Grunt walking alongside for comparison
scripts.Scout = {
    setup = function(demo)
        demo:spawnStar(demo.H * 0.35)
        demo:spawn("Grunt", demo.W + 10, demo.H * 0.7)
    end,
}

-- Critter: a little pack of them
scripts.Critter = {
    setup = function(demo)
        demo:spawnStar(demo.H / 2)
        demo:spawn("Critter", demo.W + 22, demo.H / 2 - 14)
        demo:spawn("Critter", demo.W + 16, demo.H / 2 + 14)
    end,
}

-- Drone: fires disabling shots at the turret, which shoots slower with each
scripts.Drone = {
    setup = function(demo)
        demo:spawnStar()
        demo.state = {}
        demo:addTurret({
            interval = 0.6,
            pick = function(d) return d.star and not d.star.demoDead and d.star.x < d.W - 10 and d.star or nil end,
            onHit = bulletHit(6, { 1, 0.9, 0.4 }),
        })
    end,
    update = function(demo, dt)
        local star = demo.star
        if star.demoDead or star.x > demo.W - 10 then return end
        if every(demo.state, "shot", star:getStat("debuffFrequency") or 4, dt, 1.2) then
            table.insert(demo.bullets, {
                x = star.x, y = star.y, target = demo.turret, toTurret = true, speed = 120,
                color = { 0.3, 1, 1 }, radius = 2.5,
                onHit = function(d)
                    d.turret.slowed = d.turret.slowed + 1
                    d.turret.flash = 1
                    d:ring(d.turret.x, d.turret.y, 10, { 0.3, 1, 1 }, 0.4)
                end,
            })
        end
    end,
}

-- Soldier: bullets (yellow) are blunted by its armour; energy shots (cyan) aren't
scripts.Soldier = {
    setup = function(demo)
        demo:spawnStar()
        local ballistic = true
        local tr = demo:addTurret({
            interval = 0.7,
            pick = function(d) return d.star.x < d.W - 10 and d.star or nil end,
        })
        tr.onHit = function(d, target)
            local mult = ballistic and ((target.affinities and target.affinities.ballistic) or 1) or 1
            d:damage(target, 10 * mult, ballistic and { 0.65, 0.65, 0.7 } or { 0.4, 0.9, 1 })
            ballistic = not ballistic
            tr.color = ballistic and { 1, 0.85, 0.3 } or { 0.4, 0.9, 1 }
        end
    end,
}

-- Sapper: dashes into the base wall, which flashes from the impact
scripts.Sapper = {
    setup = function(demo)
        demo:addWall()
        demo:spawnStar()
    end,
    update = function(demo)
        local star = demo.star
        if not star.demoDead and star.x - star.w / 2 <= demo.wall.x then
            star.demoDead = true
            demo.wall.flash = 1
            demo:ring(demo.wall.x, star.y, 30, { 1, 0.5, 0.2 }, 0.5)
            demo:ring(demo.wall.x, star.y, 18, { 1, 0.9, 0.4 }, 0.35)
        end
    end,
    isDone = function(demo) return demo.star.demoDead and #demo.rings == 0 and demo.wall.flash <= 0 end,
}

-- Broodmother: stops, and pulses as each Critter hatches side by side in front of it
scripts.Broodmother = {
    setup = function(demo)
        demo:spawnStar()
        demo.state = {}
    end,
    update = function(demo, dt)
        local bm = demo.star
        if bm.x > demo.W then return end
        if every(demo.state, "hatch", bm:getStat("spawnFrequency") or 6, dt, 1) then
            demo.state.count = bm:getStat("spawnAmount") or 3
            demo.state.slot = 0
            bm.spawnQueue = demo.state.count -- holds it still (Spawner:isHalted)
            demo.state.stagger = 0
        end
        if (bm.spawnQueue or 0) > 0 then
            demo.state.stagger = demo.state.stagger - dt
            if demo.state.stagger <= 0 then
                demo.state.stagger = bm.staggerDelay or 0.2
                demo.state.slot = demo.state.slot + 1
                bm.spawnQueue = bm.spawnQueue - 1
                bm:startPulse()
                local count = demo.state.count
                local lane = (demo.state.slot - (count + 1) / 2) * 14
                local c = demo:spawn(bm:getStat("spawnReference") or "Critter", bm.x - bm.w / 2 - 8, bm.y + lane)
                if c then demo:ring(c.x, c.y, 8, { 0.3, 1, 0.3 }, 0.3) end
            end
        end
    end,
    isDone = function(demo)
        for _, e in ipairs(demo:alive()) do
            if e.x > -e.w then return false end
        end
        return true
    end,
}

-- Guardian: regularly shields the Grunts around it; the turret's shots hit the
-- shields first
scripts.Guardian = {
    setup = function(demo)
        local g = demo:spawnStar()
        demo.grunts = {
            demo:spawn("Grunt", g.x - 26, g.y - 18),
            demo:spawn("Grunt", g.x - 26, g.y + 18),
        }
        for _, gr in ipairs(demo.grunts) do gr.demoSpeedMult = g:getStat("speed") / gr:getStat("speed") end
        demo.state = {}
        demo:addTurret({
            interval = 0.5,
            pick = function(d) return d:frontmost(function(e) return e ~= d.star end) end,
            onHit = bulletHit(8),
        })
    end,
    update = function(demo, dt)
        local g = demo.star
        if g.demoDead or g.x > demo.W then return end
        if every(demo.state, "shield", g.shieldCooldown, dt, 1) then
            for i = 0, g.SHIELD_RINGS - 1 do
                demo:ring(g.x, g.y, g.shieldRadius, g.SHIELD_COLOR, 0.7, i * g.SHIELD_RING_GAP)
            end
            for _, gr in ipairs(demo.grunts) do
                if not gr.demoDead then
                    gr.shield = g.shieldAmount
                    gr.maxShield = math.max(gr.maxShield or 0, gr.shield)
                end
            end
        end
    end,
}

-- Captain: the turret's ice shots chill the Grunts; the Captain shakes it off them
scripts.Captain = {
    setup = function(demo)
        local c = demo:spawnStar()
        demo.grunts = {
            demo:spawn("Grunt", c.x - 26, c.y - 18),
            demo:spawn("Grunt", c.x - 26, c.y + 18),
        }
        demo.state = {}
        demo:addTurret({
            interval = 0.45, color = { 0.55, 0.85, 1 },
            pick = function(d) return d:frontmost(function(e) return e ~= d.star end) end,
            onHit = function(_, target) Chill.apply(target, 1.2) end,
        })
    end,
    update = function(demo, dt)
        local c = demo.star
        if c.x > demo.W then return end
        if every(demo.state, "rally", c.clearCooldown or 3, dt, 2.5) then
            local cleared = false
            for _, gr in ipairs(demo.grunts) do
                if not gr.demoDead and gr.effectManager:clearDebuffs() then
                    cleared = true
                    gr:startGlint()
                end
            end
            if cleared then demo:ring(c.x, c.y, c.range or 120, { 0.1, 0.4, 0.9 }, 0.6) end
        end
    end,
}

-- Portal Master: opens portals that pull the Grunts beside it forward
scripts.PortalMaster = {
    setup = function(demo)
        local p = demo:spawnStar()
        demo.grunts = {
            demo:spawn("Grunt", p.x + 6, p.y - 22),
            demo:spawn("Grunt", p.x + 6, p.y + 22),
        }
        demo.state = {}
    end,
    update = function(demo, dt)
        local p = demo.star
        if p.x > demo.W then return end
        if every(demo.state, "portal", p.teleportCooldown or 5, dt, 1.5) then
            demo:ring(p.x, p.y, 30, { 0.7, 0.3, 1 }, 0.6)
            for _, gr in ipairs(demo.grunts) do
                if not gr.demoDead then
                    local toX = gr.x - (p.teleportDistance or 25)
                    demo:ring(gr.x, gr.y, 10, { 0.7, 0.3, 1 }, 0.4)
                    demo:ring(toX, gr.y, 10, { 0.85, 0.5, 1 }, 0.5)
                    gr:startPortal(toX, gr.y)
                end
            end
        end
    end,
    isDone = function(demo)
        for _, e in ipairs(demo:alive()) do
            if e.x > -e.w then return false end
        end
        return true
    end,
}

-- Medic: latches onto the most wounded Grunt and heals it up, then the next
scripts.Medic = {
    setup = function(demo)
        local m = demo:spawnStar()
        local a = demo:spawn("Grunt", m.x - 30, m.y - 16)
        local b = demo:spawn("Grunt", m.x - 30, m.y + 16)
        a.hp, b.hp = a.hp * 0.3, b.hp * 0.6
        demo.grunts = { a, b }
        for _, gr in ipairs(demo.grunts) do gr.demoSpeedMult = m:getStat("speed") / gr:getStat("speed") end
        demo.state = {}
    end,
    update = function(demo, dt)
        local m = demo.star
        if m.x > demo.W then return end
        local current = m.attachedTargets[1]
        if current and (current.demoDead or current.hp >= current:getStat("maxHp")) then
            m.attachedTargets = {}
            current = nil
        end
        if not current then
            local worst
            for _, gr in ipairs(demo.grunts) do
                if not gr.demoDead and gr.hp < gr:getStat("maxHp") and (not worst or gr.hp < worst.hp) then worst = gr end
            end
            if worst then m.attachedTargets = { worst } end
        end
        if m.attachedTargets[1] and every(demo.state, "heal", 0.5, dt) then
            demo:heal(m.attachedTargets[1], (m.regenAmount or 15) * 0.5)
        end
    end,
}

-- Slime: the turret pops it, and it splits into smaller slimes (which split again)
scripts.Slime = {
    setup = function(demo)
        demo:spawnStar()
        demo:addTurret({
            interval = 0.35,
            pick = function(d) return d:frontmost() end,
            onHit = bulletHit(12),
        })
    end,
    onDeath = function(demo, e)
        local generation = e.generation or 0
        if generation >= 2 then return end
        demo:ring(e.x, e.y, e.w * 1.4, e.color, 0.25)
        local size = math.max(8, e.w * 0.75)
        local spread = (size + (e.SPLIT_GAP or 4)) / 2
        for _, dir in ipairs({ -1, 1 }) do
            local maxHp = math.max(1, math.floor(e:getStat("maxHp") / 2))
            local child = demo:spawn("Slime", e.x, e.y, {
                generation = generation + 1, maxHp = maxHp, hp = maxHp,
                speed = e:getStat("speed"), size = size,
            })
            if child then child:startSpread(e.x, e.y + dir * spread) end
        end
    end,
    isDone = function(demo) return #demo:alive() == 0 and #demo.texts == 0 end,
}

-- Reanimator: the turret drops the Grunts walking ahead of it, then it channels,
-- slams the ground and raises them as half-health zombies (which the turret then
-- ignores, to keep it short)
scripts.Reanimator = {
    setup = function(demo)
        local r = demo:spawnStar()
        for i, dy in ipairs({ -18, 0, 18 }) do
            local gr = demo:spawn("Grunt", r.x - 30 - (i == 2 and 10 or 0), r.y + dy)
            gr.demoSpeedMult = r:getStat("speed") / gr:getStat("speed")
        end
        demo.corpses = {}
        demo.state = {}
        demo:addTurret({
            interval = 0.25,
            pick = function(d) return d:frontmost(function(e) return e ~= d.star and not e.isZombie end) end,
            onHit = bulletHit(25),
        })
    end,
    onDeath = function(demo, e)
        if e ~= demo.star and not e.isZombie then table.insert(demo.corpses, { x = e.x, y = e.y }) end
    end,
    update = function(demo, dt)
        local r = demo.star
        if r.phase then
            if not r:advanceCast(dt) then return end
            demo:ring(r.x, r.y, 60, Zombie.COLOR, 0.6)
        else
            if #demo.corpses >= 3 and not demo.state.raised then
                demo.state.raised = true
                r:startChannel()
            end
            return
        end
        for _, c in ipairs(demo.corpses) do
            local z = demo:spawn("Grunt", c.x, c.y)
            Zombie.apply(z)
            z:startRise()
            z.demoSpeedMult = r:getStat("speed") / z:getStat("speed")
            demo:ring(c.x, c.y, 12, Zombie.COLOR, 0.4)
        end
        demo.corpses = {}
    end,
    isDone = function(demo)
        for _, e in ipairs(demo:alive()) do
            if e.x > -e.w then return false end
        end
        return true
    end,
}

-- Phantom: each time the turret hits it, it's wiped away left to right (still
-- hittable), then it's gone and reappears higher or lower; the turret can't
-- target it while it's gone or make it blink again until its cooldown is up
-- (it holds still throughout)
scripts.Phantom = {
    setup = function(demo)
        demo:spawnStar()
        demo:addTurret({
            interval = 0.35,
            pick = function(d)
                local p = d.star
                return (p.x < d.W - 10 and not p.untargetable and not p.demoDead) and p or nil
            end,
            onHit = function(d, target)
                d:damage(target, 12)
                if target.demoDead or not target:canBlink() then return end
                local margin = target.h / 2 + 4
                local toY = target.pickBlinkY(target.y, margin, d.H - margin, d.H)
                if toY then target:startVanish(toY) end
            end,
        })
    end,
    update = function(demo, dt)
        local p = demo.star
        local wasVanishing, wasGone = p.vanishTime ~= nil, p.blinkTime ~= nil
        local fromY = p.y
        p:updateBlink(dt)
        if wasVanishing and p.blinkTime then demo:ring(p.x + p.w * 0.5, fromY, p.w * 0.6, p.color, 0.2) end
        if wasGone and not p.blinkTime then demo:ring(p.x, p.y, p.w, p.color, 0.25) end
    end,
}

-- Tank: barely dented by the turret, and a Medic's healing lands extra hard on it
scripts.Tank = {
    setup = function(demo)
        local t = demo:spawnStar()
        local m = demo:spawn("Medic", t.x + t.w / 2 + 14, t.y + 18)
        m.demoSpeedMult = t:getStat("speed") / m:getStat("speed")
        m.attachedTargets = { t }
        demo.medic = m
        demo.state = {}
        demo:addTurret({
            interval = 0.3,
            pick = function(d) return d.star.x < d.W - 10 and d.star or nil end,
            onHit = bulletHit(20),
        })
    end,
    update = function(demo, dt)
        if demo.star.x > demo.W then return end
        if every(demo.state, "heal", 0.5, dt) then
            demo:heal(demo.star, (demo.medic.regenAmount or 15) * 0.5)
        end
    end,
    isDone = function(demo)
        for _, e in ipairs(demo:alive()) do
            if e.x > -e.w then return false end
        end
        return true
    end,
}

return EnemyDemo
