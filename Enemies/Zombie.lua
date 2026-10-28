-- Zombie.lua - Turns a freshly made enemy into a zombie (raised by a Reanimator):
-- the same enemy with the same stats and abilities, but it comes back at half
-- health and nothing can heal it, so it never gets above that. It keeps its own
-- colour but its outline glows the Reanimator's green (Enemy:drawNeonOutline).

local Zombie = {}

Zombie.HP_FRACTION = 0.5 -- of its max health
Zombie.REWARD_FRACTION = 0.5 -- XP for killing it again
Zombie.COLOR = { 0.65, 1, 0.15 } -- the Reanimator's green

local function noHeal() return 0 end

function Zombie.apply(enemy)
    enemy.isZombie = true
    enemy.hp = enemy:getStat("maxHp") * Zombie.HP_FRACTION
    enemy.heal = noHeal
    enemy.reward = math.floor((enemy.reward or 0) * Zombie.REWARD_FRACTION)
    return enemy
end

return Zombie
