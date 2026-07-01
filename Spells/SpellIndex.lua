local SpellCardRegistry = require("Spells.SpellCardRegistry")

local SpellIndex = {
    common = {},
    uncommon = {},
    rare = {},
    epic = {},
    legendary = {}
}

for _, spell in pairs(SpellCardRegistry) do
    if type(spell) == "table" and spell.id and spell.rarity then
        local rarityKey = spell.rarity:lower()
        if SpellIndex[rarityKey] then
            table.insert(SpellIndex[rarityKey], {
                id = spell.id,
                name = spell.name,
                description = spell.description,
                type = "spell",
                types = {"spell"},
                cost = spell.cost or 1,
                rarity = rarityKey
            })
        end
    end
end

return SpellIndex
