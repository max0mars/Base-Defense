Turret = {}
Turret.__index = Turret

function Turret:new(config)
    local t = {
        -- Position relative to base
        x = config.x or 0,
        y = config.y or 0,

        -- Local rotation for aiming
        rotation = 0,

        -- Firing properties
        fireRate = config.fireRate or 1,
        bulletType = config.bulletType or Bullet,
        cooldown = 0,

        -- Upgrades: e.g. hit effects, damage bonus
        hitEffects = {},
        damage = config.damage or 10,

        -- Target (optional)
        target = nil,

        -- Parent base (optional, for absolute position)
        base = nil,
    }
    setmetatable(t, self)
    return t
end

function Turret:setBase(base)
    self.base = base
endb  

function Turret:aimAt(x, y)
    local dx = x - self.x
    local dy = y - self.y
    self.rotation = math.atan2(dy, dx)
end

function Turret:getWorldPosition()
    if self.base then
        return self.base.x + self.offsetX, self.base.y + self.offsetY
    else
        return self.offsetX, self.offsetY
    end
end

function Turret:addHitEffect(effectFunc)
    table.insert(self.hitEffects, effectFunc)
end

function Turret:fire()
    if self.cooldown <= 0 then
        local bx, by = self:getWorldPosition()
        local b = self.bulletType:new(bx, by, self.rotation, game.enemies)
        b.damage = self.damage

        -- Add upgrades to bullet
        b.hitEffects = {}
        for _, effect in ipairs(self.hitEffects) do
            table.insert(b.hitEffects, effect)
        end

        table.insert(game.bullets, b)

        self.cooldown = 1 / self.fireRate
    end
end

function Turret:update(dt)
    self.cooldown = math.max(0, self.cooldown - dt)

    -- Auto aim logic (optional)
    if self.target then
        self:aimAt(self.target.x, self.target.y)
    end
end

function Turret:draw()
    local bx, by = self:getWorldPosition()

    -- Draw turret mount
    love.graphics.setColor(0, 0, 1)
    love.graphics.circle("fill", bx, by, 8)

    -- Draw barrel
    love.graphics.setColor(1, 1, 1)
    love.graphics.line(
        bx, by,
        bx + math.cos(self.rotation) * 20,
        by + math.sin(self.rotation) * 20
    )
end
