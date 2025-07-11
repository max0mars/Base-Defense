Turret = {}
Turret.__index = Turret

function Turret:new(config, game)
    local t = {
        -- Position relative to world
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
        target = nil,  -- Target to auto aim at
        game = game,
    }
    setmetatable(t, self)
    return t
end

function Turret:aimAt(x, y)
    local dx = x - self.x
    local dy = y - self.y
    self.rotation = math.atan2(dy, dx)
end

function Turret:addHitEffect(effectFunc)
    table.insert(self.hitEffects, effectFunc)
end

function Turret:fire()
    local b = self.bulletType:new(self.x, self.y, self.rotation, game.enemies)
    b.damage = self.damage

    -- Add upgrades to bullet
    b.hitEffects = {}
    for _, effect in ipairs(self.hitEffects) do
        table.insert(b.hitEffects, effect)
    end

    table.insert(game.bullets, b)
end

function Turret:update(dt)
    self.cooldown = math.max(0, self.cooldown - dt)

    if self.mode == "auto" then
        self:getTarget() -- Automatically find the closest target
        if self.target then
            self:aimAt(self.target.x, self.target.y)
        end
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

function Turret:getTarget()
    local dist = 1000000000
    self.target = nil -- Reset target for each update
    for _, enemy in ipairs(game.enemies) do
        if enemy.x and enemy.y then
            local newdist = (enemy.x - self.x)^2 + (enemy.y - self.y)^2 -- Calculate squared distance to avoid sqrt for performance
            if(newdist < dist) then
                dist = newdist -- Calculate distance to the enemy
                self.target = enemy
            end
        end
    end
end