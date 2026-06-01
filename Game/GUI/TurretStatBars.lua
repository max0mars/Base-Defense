-- TurretStatBars.lua: shared logic + rendering for relative DMG/RNG/SPD tier
-- bars. Used by the turret hover tooltip and the reward cards so both compare
-- turrets against the same pool-wide min/max.

local TurretStatBars = {}

local RARITIES = { "common", "uncommon", "rare", "epic", "legendary" }
local STAT_BOUNDS = nil

--- Lazily computes (and caches) the min/max of each stat across every turret in
--- the reward pool. Requires a live game reference to instantiate turrets.
function TurretStatBars.getBounds(game)
    if STAT_BOUNDS then return STAT_BOUNDS end
    local Normal = require("Game.Rewards.NormalRewardIndex")
    local b = {
        damage   = { min = math.huge, max = 0 },
        range    = { min = math.huge, max = 0 },
        fireRate = { min = math.huge, max = 0 },
    }
    local function tally(key, val)
        if type(val) ~= "number" or val <= 0 then return end
        if val < b[key].min then b[key].min = val end
        if val > b[key].max then b[key].max = val end
    end
    for _, rarity in ipairs(RARITIES) do
        for _, item in ipairs(Normal[rarity] or {}) do
            if item.type == "building" and item.building and item.iconCategory == "turret" then
                local ok, inst = pcall(function() return item.building:new({ game = game }) end)
                if ok and inst then
                    tally("damage", (inst.damage or 0) * (inst.pelletCount or 1))
                    tally("range", inst.range)
                    tally("fireRate", inst.fireRate)
                end
            end
        end
    end
    for _, key in ipairs({ "damage", "range", "fireRate" }) do
        if b[key].min == math.huge then b[key].min = 0 end
        if b[key].max <= b[key].min then b[key].max = b[key].min + 1 end
    end
    STAT_BOUNDS = b
    return b
end

--- Maps a value to a 1..maxTiers tier on a log scale (so a single high outlier
--- doesn't flatten everything else to the lowest tier).
function TurretStatBars.tier(value, bound, maxTiers)
    maxTiers = maxTiers or 5
    if not bound or value <= 0 then return 1 end
    local lo = math.log(math.max(bound.min, 1e-6))
    local hi = math.log(math.max(bound.max, bound.min + 1e-6))
    local n = (math.log(value) - lo) / (hi - lo)
    if n < 0 then n = 0 elseif n > 1 then n = 1 end
    return 1 + math.floor(n * (maxTiers - 1) + 0.5)
end

local function readStat(t, key, default)
    if t.getStat then return t:getStat(key, default) end
    return t[key] or default
end

--- Returns the three {label, tier, color} rows for a turret instance.
function TurretStatBars.rows(turret, game, maxTiers)
    local bounds = TurretStatBars.getBounds(game)
    local volley = readStat(turret, "damage", 0) * (turret.pelletCount or 1)
    return {
        { label = "DMG", tier = TurretStatBars.tier(volley, bounds.damage, maxTiers),                  color = {1.0, 0.5, 0.3, 1} },
        { label = "RNG", tier = TurretStatBars.tier(readStat(turret, "range", 0), bounds.range, maxTiers),    color = {0.4, 0.7, 1.0, 1} },
        { label = "SPD", tier = TurretStatBars.tier(readStat(turret, "fireRate", 0), bounds.fireRate, maxTiers), color = {0.45, 0.9, 0.5, 1} },
    }
end

--- Draws the three labeled tier bars top-left-anchored at (x, y).
--- opts: tiers, labelW, segW, segH, gap, rowH, labelScale. Returns height used.
function TurretStatBars.drawBars(turret, game, x, y, opts)
    opts = opts or {}
    local tiers      = opts.tiers or 5
    local labelW     = opts.labelW or 28
    local segW       = opts.segW or 8
    local segH       = opts.segH or 6
    local gap        = opts.gap or 2
    local rowH       = opts.rowH or 11
    local labelScale = opts.labelScale or 0.85

    local rows = TurretStatBars.rows(turret, game, tiers)
    for i, row in ipairs(rows) do
        local ry = y + (i - 1) * rowH
        love.graphics.setColor(0.8, 0.85, 0.9, 1)
        love.graphics.print(row.label, x, ry, 0, labelScale, labelScale)
        local pipsX = x + labelW
        for s = 1, tiers do
            if s <= row.tier then
                love.graphics.setColor(row.color)
            else
                love.graphics.setColor(0.25, 0.27, 0.32, 1)
            end
            love.graphics.rectangle("fill", pipsX + (s - 1) * (segW + gap), ry + 1, segW, segH, 1)
        end
    end
    love.graphics.setColor(1, 1, 1, 1)
    return #rows * rowH
end

--- Convenience: the bar block's pixel width for a given options set (for centering).
function TurretStatBars.barsWidth(opts)
    opts = opts or {}
    local tiers  = opts.tiers or 5
    local labelW = opts.labelW or 28
    local segW   = opts.segW or 8
    local gap    = opts.gap or 2
    return labelW + tiers * (segW + gap)
end

return TurretStatBars
