local EffectManager = require("Game.Effects.EffectManager")
local em = EffectManager:new(nil, nil)

local buff = {
    name = "inst_range_1",
    displayName = "Range Finder",
    statModifiers = { range = { add = 100 } }
}
em:applyEffect(buff)
local strings = em:getTooltipStrings()
for _, s in ipairs(strings) do
    print(s)
end
