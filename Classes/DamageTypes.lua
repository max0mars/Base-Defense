-- DamageTypes.lua
-- Core damage types and the damage-number palette.
-- Every hit has exactly one core type, plus any number of damage tags
-- (projectile, aoe, dot, ...). Affinities match the type and the tags;
-- trueDamage ignores affinities entirely.

local DamageTypes = {}

DamageTypes.types = {
    ballistic = true,
    energy = true,
    explosive = true,
    fire = true,
    poison = true,
    ice = true,
    trueDamage = true,
}

-- Keyed by damage type, or by a tag that recolours its hit (toxic is poison damage).
DamageTypes.colors = {
    ballistic = {1, 1, 1, 1},
    energy = {0.3, 0.6, 1, 1},
    explosive = {1, 0.6, 0.2, 1},
    fire = {1, 0.5, 0, 1},
    poison = {0.15, 0.6, 0.15, 1}, -- Darkened poison so it's distinct from heal
    ice = {0.55, 0.85, 1, 1},
    trueDamage = {1, 0.4, 0.7, 1},
    toxic = {0.7, 0.2, 0.9, 1},
}

--- Raises a developer error for an unknown core type or a core type used as a tag.
function DamageTypes.validate(damageType, damageTags)
    if not DamageTypes.types[damageType] then
        error("Developer Error: Invalid damage type: " .. tostring(damageType))
    end
    for _, tag in ipairs(damageTags or {}) do
        if DamageTypes.types[tag] then
            error("Developer Error: damageTags cannot contain core damage types. Only the primary damageType is allowed.")
        end
    end
end

--- Multiplier from a target's affinities for this hit.
function DamageTypes.affinityMultiplier(affinities, damageType, damageTags)
    if not affinities or damageType == "trueDamage" then return 1 end
    local mult = affinities[damageType] or 1
    for _, tag in ipairs(damageTags or {}) do
        if affinities[tag] then
            mult = mult * affinities[tag]
        end
    end
    return mult
end

--- Colour for a hit: a recolouring tag if it has one, otherwise its core type.
function DamageTypes.colorFor(damageType, damageTags)
    for _, tag in ipairs(damageTags or {}) do
        if DamageTypes.colors[tag] then return DamageTypes.colors[tag] end
    end
    return DamageTypes.colors[damageType]
end

return DamageTypes
