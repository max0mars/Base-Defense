local InstantCardRegistry = require("Instants.InstantCardRegistry")

local InstantIndex = {
    common = {},
    uncommon = {},
    rare = {},
    epic = {},
    legendary = {}
}

for _, inst in pairs(InstantCardRegistry) do
    if type(inst) == "table" and inst.id and inst.rarity then
        local rarityKey = inst.rarity:lower()
        if InstantIndex[rarityKey] then
            table.insert(InstantIndex[rarityKey], {
                id = inst.id,
                name = inst.name,
                description = inst.description,
                type = "instant",
                types = {"instant"},
                cost = inst.cost or 1,
                rarity = rarityKey
            })
        end
    end
end

return InstantIndex
