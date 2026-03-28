-- ## 1. Building Reward
-- Use this for placing new turrets, walls, or buff buildings.
reward = {
    id = "internal_id",
    name = "Display Name",
    description = "Flavor text or stats.",
    type = "building",
    building = require(...)
}

-- 2. Effect Upgrade, can be stat modifiers or onUpdate functions
reward = {
    id = "internal_id",
    name = "Upgrade Name",
    description = "text",
    type = "effect",
    targetTags = {}, --optional
    targetTypes = {}, --optional
    effect = {
        name = "name",
        statModifiers = {stat = {mult = 0.2}},
        duration = math.huge
    },
    duration = math.huge
}
-- 4. Custom Logic (Scripts)
-- Use this for complex rewards like healing the base or triggering events.
{
    id = "internal_id",
    name = "Custom Script",
    description = "Instantly heals the base for 50 HP",
    type = "onSelect",
    onSelect = function(game)
        game.base.hp = math.min(game.base.maxhp, game.base.hp + 50)
    end
}