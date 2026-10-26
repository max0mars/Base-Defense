-- MaterialRegistry.lua - Upgrade materials and which turrets use them.
--
-- To add a material for a new turret family, add one entry to MaterialRegistry.list.
-- A turret's material is resolved in this order:
--   1. an explicit `upgradeMaterial = "<id>"` on the turret's config
--   2. the first entry (in list order) whose `match` rule fits the turret's types / damageType
--   3. the entry marked `default = true`
-- Upgrade costs, battle rewards and the material counts in the UI all read from this list.

local MaterialRegistry = {}

-- Rare wildcard that covers any shortfall of a typed material when upgrading
MaterialRegistry.UNIVERSAL = "universal_essence"

-- A new run starts with this many of the main turret's material
MaterialRegistry.STARTING_AMOUNT = 2

MaterialRegistry.list = {
    {
        id = "energy_cells",
        name = "Energy Cells",
        shortName = "Cells",
        color = {0.3, 0.85, 1, 1},
        match = { types = {"energy"}, damageTypes = {"energy"} }
    },
    {
        id = "blast_powder",
        name = "Blast Powder",
        shortName = "Powder",
        color = {1, 0.55, 0.2, 1},
        match = { types = {"explosive"} }
    },
    {
        id = "elemental_essence",
        name = "Elemental Essence",
        shortName = "Essence",
        color = {0.5, 1, 0.4, 1},
        match = { damageTypes = {"poison", "water", "fire"} }
    },
    {
        id = "scrap",
        name = "Scrap Metal",
        shortName = "Scrap",
        color = {0.75, 0.75, 0.8, 1},
        default = true -- Normal guns
    },
    {
        id = MaterialRegistry.UNIVERSAL,
        name = "Universal Essence",
        shortName = "Universal",
        color = {1, 0.85, 1, 1},
        universal = true
    },
}

local byId = {}
for _, mat in ipairs(MaterialRegistry.list) do
    byId[mat.id] = mat
end

function MaterialRegistry.get(id)
    return byId[id]
end

function MaterialRegistry.isMaterial(id)
    return byId[id] ~= nil
end

function MaterialRegistry.getName(id)
    local mat = byId[id]
    return mat and mat.name or tostring(id)
end

--- Compact label for tight UI rows (falls back to the full name).
function MaterialRegistry.getShortName(id)
    local mat = byId[id]
    return mat and (mat.shortName or mat.name) or tostring(id)
end

--- Typed (non-universal) materials, in list order.
function MaterialRegistry.getTyped()
    local typed = {}
    for _, mat in ipairs(MaterialRegistry.list) do
        if not mat.universal then table.insert(typed, mat) end
    end
    return typed
end

-- `types` may be an array ({"turret", "energy"}) or a set ({energy = true})
local function hasType(types, name)
    if type(types) ~= "table" then return false end
    if types[name] == true then return true end
    for _, t in ipairs(types) do
        if t == name then return true end
    end
    return false
end

local function matches(rule, config)
    for _, t in ipairs(rule.types or {}) do
        if hasType(config.types, t) then return true end
    end
    for _, dt in ipairs(rule.damageTypes or {}) do
        if config.damageType == dt then return true end
    end
    return false
end

--- Material id a turret upgrades with.
-- @param config table: turret config / template (types, damageType, upgradeMaterial)
function MaterialRegistry.resolve(config)
    config = config or {}
    if config.upgradeMaterial and byId[config.upgradeMaterial] then
        return config.upgradeMaterial
    end
    local default
    for _, mat in ipairs(MaterialRegistry.list) do
        if mat.match and matches(mat.match, config) then
            return mat.id
        end
        if mat.default then default = mat.id end
    end
    return default
end

return MaterialRegistry
