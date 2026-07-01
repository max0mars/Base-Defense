local TurretIndex = require("Buildings.TurretIndex")
local PassiveIndex = require("Buildings.PassiveIndex")
local SpellIndex = require("Spells.SpellIndex")
local InstantIndex = require("Instants.InstantIndex")

local RewardIndex = {
    common = {},
    uncommon = {},
    rare = {},
    epic = {},
    legendary = {}
}

local function mergeIndex(sourceIndex)
    for rarity, items in pairs(sourceIndex) do
        if RewardIndex[rarity] then
            for _, item in ipairs(items) do
                table.insert(RewardIndex[rarity], item)
            end
        end
    end
end

-- Merge all standard pools
mergeIndex(TurretIndex)
mergeIndex(PassiveIndex)
mergeIndex(SpellIndex)
mergeIndex(InstantIndex)

-- Provide a function to inject unique cards (e.g. from Main Turret)
function RewardIndex.injectCards(cards)
    if not cards then return end
    for rarity, rarityCards in pairs(cards) do
        if RewardIndex[rarity] then
            for _, card in ipairs(rarityCards) do
                table.insert(RewardIndex[rarity], card)
            end
        end
    end
end

-- Kept for compatibility if anything still calls it directly
function RewardIndex.injectSpells(registry)
    -- Spells are already merged via SpellIndex, but if a custom registry is passed:
    if not registry then return end
    for _, spell in pairs(registry) do
        if type(spell) == "table" and spell.id and spell.rarity then
            local rarityKey = spell.rarity:lower()
            if RewardIndex[rarityKey] then
                local exists = false
                for _, existing in ipairs(RewardIndex[rarityKey]) do
                    if existing.id == spell.id then exists = true; break end
                end
                if not exists then
                    table.insert(RewardIndex[rarityKey], {
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
    end
end

function RewardIndex.injectInstants(registry)
    -- Instants are already merged via InstantIndex
    if not registry then return end
    for _, inst in pairs(registry) do
        if type(inst) == "table" and inst.id and inst.rarity then
            local rarityKey = inst.rarity:lower()
            if RewardIndex[rarityKey] then
                local exists = false
                for _, existing in ipairs(RewardIndex[rarityKey]) do
                    if existing.id == inst.id then exists = true; break end
                end
                if not exists then
                    table.insert(RewardIndex[rarityKey], {
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
    end
end

return RewardIndex
