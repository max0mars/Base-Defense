-- CardIcons.lua - the synergy icons in the bottom left of a card's description box.
-- A card shows its firing types first (projectile, hitscan, shotgun, lobber, beam),
-- then its damage types, then any resources it earns (token, mana, money).
-- Cards that can only target the Main Turret lead with a `mainTurret` icon.
-- Turrets work theirs out from their stats; any card can
-- set an explicit `icons` list instead (spells, passives and instants do).

local DamageTypes = require("Classes.DamageTypes")

local CardIcons = {}

CardIcons.FIRING_TYPES = { "projectile", "hitscan", "shotgun", "lobber", "beam" }
CardIcons.SIZE = 22
CardIcons.SPACING = 4

local FIRING_COLOR = {0.85, 0.85, 0.85, 1}
local MAIN_TURRET_COLOR = {1, 0.35, 0.35, 1}

-- Resources a card earns, coloured like the HUD's token coin and mana orb
local RESOURCE_COLORS = {
    token = {1.0, 0.8, 0.3, 1},
    mana = {0.2, 0.75, 1.0, 1},
    money = {0.3, 0.9, 0.4, 1},
}

-- Hover text: a name and what the icon means
CardIcons.INFO = {
    projectile = { "Projectile", "Fires bullets that fly to their target." },
    hitscan = { "Hitscan", "Hits its target instantly." },
    shotgun = { "Shotgun", "Fires a spread of pellets at once." },
    lobber = { "Lobber", "Lobs shells in an arc that land on the target." },
    beam = { "Beam", "Locks a continuous beam onto its target." },
    physical = { "Physical", "Physical damage." },
    energy = { "Energy", "Energy damage. Effective against armor." },
    explosive = { "Explosive", "Explosive damage, usually in an area." },
    fire = { "Fire", "Fire damage, including burn." },
    poison = { "Poison", "Poison damage, including poison and toxic over time." },
    ice = { "Ice", "Ice damage and chill. Chilled enemies slow down and can freeze." },
    trueDamage = { "True Damage", "Ignores enemy resistances and weaknesses." },
    token = { "Tokens", "Earns Tokens, used to play cards and unlock slots." },
    mana = { "Mana", "Earns Mana, used to cast spells." },
    money = { "Money", "Earns money to spend between battles." },
    mainTurret = { "Main Turret", "Only affects your Main Turret." },
}

local isFiringType = {}
for i, name in ipairs(CardIcons.FIRING_TYPES) do isFiringType[name] = i end

-- types is a list in the card indexes and a set once a building is built
local function hasType(config, name)
    local types = config.types
    if type(types) ~= "table" then return false end
    if types[name] then return true end
    for _, t in ipairs(types) do
        if t == name then return true end
    end
    return false
end

--- mainTurret first, then firing types (in FIRING_TYPES order), then the rest in the order given.
function CardIcons.order(icons)
    local firing, other, seen = {}, {}, {}
    for _, name in ipairs(icons) do
        if not seen[name] then
            seen[name] = true
            table.insert(isFiringType[name] and firing or other, name)
        end
    end
    table.sort(firing, function(a, b) return isFiringType[a] < isFiringType[b] end)
    if seen.mainTurret then
        for i, name in ipairs(other) do
            if name == "mainTurret" then table.remove(other, i) break end
        end
        table.insert(firing, 1, "mainTurret")
    end
    for _, name in ipairs(other) do table.insert(firing, name) end
    return firing
end

--- Whether a card can only be played on the Main Turret (main turret upgrades,
-- and targeted cards that require the mainturret type).
function CardIcons.targetsMainTurretOnly(data)
    return data ~= nil and (data.type == "main_upgrade" or data.requiredType == "mainturret")
end

local function deriveTurretIcons(config)
    local icons = {}
    local bullet = config.bulletId and require("Bullets.BulletIndex")[config.bulletId]
    local isHitscan = bullet and bullet.class == require("Bullets.HitscanBullet")
    local isLobber = hasType(config, "lobber")

    if isHitscan then
        table.insert(icons, "hitscan")
    elseif bullet and not isLobber then
        table.insert(icons, "projectile")
    end
    if hasType(config, "shotgun") or (config.pelletCount or 1) > 1 then
        table.insert(icons, "shotgun")
    end
    if isLobber then
        table.insert(icons, "lobber")
    end
    if DamageTypes.types[config.damageType] then
        table.insert(icons, config.damageType)
    end
    return icons
end

local function findInRewardIndex(id)
    local ok, rewardIndex = pcall(require, "Game.Rewards.RewardIndex")
    if not ok then return nil end
    for _, category in pairs(rewardIndex) do
        if type(category) == "table" then
            for _, reward in ipairs(category) do
                if reward.id == id then return reward end
            end
        end
    end
    return nil
end

--- Icons for a card definition (a turret config, an index entry, or card draw data),
-- falling back to the index entry with this id when the definition has no icons.
-- @return table: ordered list of icon names, empty when the card has none
function CardIcons.resolve(config, id)
    if config and config.icons then return CardIcons.order(config.icons) end
    if config and config.damageType and config.bulletId then
        return CardIcons.order(deriveTurretIcons(config))
    end
    local entry = id and findInRewardIndex(id)
    if entry and entry ~= config then return CardIcons.resolve(entry) end
    return {}
end

-- Glyphs: each draws centred on (cx, cy) inside a box of half-width r, in the current colour
-- (also passed in as `color`)

-- Fills a (possibly concave) polygon.
local function fillPolygon(vertices)
    local ok, tris = pcall(love.math.triangulate, vertices)
    if not ok or type(tris) ~= "table" then return end
    for _, tri in ipairs(tris) do love.graphics.polygon("fill", tri) end
end

local glyphs = {}

function glyphs.projectile(cx, cy, r)
    -- A bullet flying right with two speed lines behind it
    love.graphics.polygon("fill",
        cx - r * 0.2, cy - r * 0.3, cx + r * 0.45, cy - r * 0.3, cx + r * 0.85, cy,
        cx + r * 0.45, cy + r * 0.3, cx - r * 0.2, cy + r * 0.3)
    love.graphics.setLineWidth(1.5)
    love.graphics.line(cx - r * 0.9, cy - r * 0.3, cx - r * 0.4, cy - r * 0.3)
    love.graphics.line(cx - r * 0.9, cy + r * 0.3, cx - r * 0.4, cy + r * 0.3)
end

function glyphs.hitscan(cx, cy, r)
    -- An instant line ending on a crosshair
    love.graphics.setLineWidth(1.5)
    love.graphics.line(cx - r * 0.9, cy, cx + r * 0.25, cy)
    love.graphics.circle("line", cx + r * 0.45, cy, r * 0.4)
    love.graphics.line(cx + r * 0.45, cy - r * 0.75, cx + r * 0.45, cy + r * 0.75)
end

function glyphs.shotgun(cx, cy, r)
    -- Pellets spreading out from a muzzle
    local ox = cx - r * 0.8
    love.graphics.setLineWidth(1.5)
    for _, dy in ipairs({ -0.65, 0, 0.65 }) do
        love.graphics.line(ox, cy, cx + r * 0.45, cy + r * dy)
        love.graphics.circle("fill", cx + r * 0.7, cy + r * dy * 1.15, r * 0.18)
    end
end

function glyphs.lobber(cx, cy, r)
    -- A shell arcing over to land on the right
    local points = {}
    for i = 0, 8 do
        local angle = math.pi + (i / 8) * math.pi * 0.75
        table.insert(points, cx + math.cos(angle) * r * 0.8)
        table.insert(points, cy + r * 0.5 + math.sin(angle) * r * 0.8)
    end
    love.graphics.setLineWidth(1.5)
    love.graphics.line(points)
    love.graphics.circle("fill", cx + r * 0.6, cy - r * 0.05, r * 0.25)
    love.graphics.line(cx - r * 0.9, cy + r * 0.8, cx + r * 0.9, cy + r * 0.8)
end

function glyphs.beam(cx, cy, r, color)
    -- A solid band with a bright core
    love.graphics.setColor(color[1], color[2], color[3], 0.4)
    love.graphics.rectangle("fill", cx - r * 0.9, cy - r * 0.4, r * 1.8, r * 0.8)
    love.graphics.setColor(color)
    love.graphics.setLineWidth(2)
    love.graphics.line(cx - r * 0.9, cy, cx + r * 0.9, cy)
    love.graphics.circle("fill", cx - r * 0.75, cy, r * 0.3)
end

function glyphs.physical(cx, cy, r)
    -- A solid block
    fillPolygon({ cx, cy - r * 0.8, cx + r * 0.7, cy, cx, cy + r * 0.8, cx - r * 0.7, cy })
end

function glyphs.energy(cx, cy, r)
    -- A lightning bolt
    fillPolygon({
        cx + r * 0.2, cy - r * 0.9,
        cx - r * 0.55, cy + r * 0.15,
        cx - r * 0.05, cy + r * 0.15,
        cx - r * 0.25, cy + r * 0.9,
        cx + r * 0.55, cy - r * 0.2,
        cx + r * 0.05, cy - r * 0.2,
    })
end

function glyphs.explosive(cx, cy, r)
    -- An 8-point blast
    local vertices = {}
    for i = 0, 15 do
        local radius = (i % 2 == 0) and r * 0.9 or r * 0.45
        local angle = i * math.pi / 8
        table.insert(vertices, cx + math.cos(angle) * radius)
        table.insert(vertices, cy + math.sin(angle) * radius)
    end
    fillPolygon(vertices)
end

function glyphs.fire(cx, cy, r)
    -- A flame with a split tip
    fillPolygon({
        cx, cy + r * 0.85,
        cx - r * 0.6, cy + r * 0.3,
        cx - r * 0.5, cy - r * 0.3,
        cx - r * 0.15, cy - r * 0.05,
        cx, cy - r * 0.9,
        cx + r * 0.25, cy - r * 0.35,
        cx + r * 0.45, cy - r * 0.6,
        cx + r * 0.6, cy + r * 0.3,
    })
end

function glyphs.poison(cx, cy, r)
    -- A droplet
    love.graphics.circle("fill", cx, cy + r * 0.3, r * 0.5)
    love.graphics.polygon("fill", cx, cy - r * 0.9, cx - r * 0.47, cy + r * 0.15, cx + r * 0.47, cy + r * 0.15)
end

function glyphs.ice(cx, cy, r)
    -- A six-spoke snowflake
    love.graphics.setLineWidth(1.5)
    for i = 0, 2 do
        local angle = i * math.pi / 3 + math.pi / 2
        local dx, dy = math.cos(angle) * r * 0.85, math.sin(angle) * r * 0.85
        love.graphics.line(cx - dx, cy - dy, cx + dx, cy + dy)
    end
end

function glyphs.trueDamage(cx, cy, r)
    -- A four-point sparkle
    fillPolygon({
        cx, cy - r * 0.9, cx + r * 0.2, cy - r * 0.2,
        cx + r * 0.9, cy, cx + r * 0.2, cy + r * 0.2,
        cx, cy + r * 0.9, cx - r * 0.2, cy + r * 0.2,
        cx - r * 0.9, cy, cx - r * 0.2, cy - r * 0.2,
    })
end

function glyphs.token(cx, cy, r)
    -- A coin stamped with a T, like the HUD's token counter
    love.graphics.setLineWidth(1.5)
    love.graphics.circle("line", cx, cy, r * 0.85)
    love.graphics.line(cx - r * 0.4, cy - r * 0.35, cx + r * 0.4, cy - r * 0.35)
    love.graphics.line(cx, cy - r * 0.35, cx, cy + r * 0.45)
end

function glyphs.mana(cx, cy, r, color)
    -- An orb with a glowing core, like the HUD's mana counter
    love.graphics.setLineWidth(1.5)
    love.graphics.circle("line", cx, cy, r * 0.85)
    love.graphics.circle("fill", cx, cy, r * 0.45)
    love.graphics.setColor(0.85, 0.97, 1.0, 1)
    love.graphics.circle("fill", cx, cy, r * 0.15)
    love.graphics.setColor(color)
end

function glyphs.money(cx, cy, r)
    -- A banknote
    love.graphics.setLineWidth(1.5)
    love.graphics.rectangle("line", cx - r * 0.9, cy - r * 0.55, r * 1.8, r * 1.1, 1)
    love.graphics.circle("fill", cx, cy, r * 0.3)
    love.graphics.circle("fill", cx - r * 0.6, cy, r * 0.1)
    love.graphics.circle("fill", cx + r * 0.6, cy, r * 0.1)
end

function glyphs.mainTurret(cx, cy, r)
    -- A crowned turret: domed head with a barrel, on a base
    love.graphics.arc("fill", "pie", cx - r * 0.1, cy + r * 0.35, r * 0.5, math.pi, math.pi * 2)
    love.graphics.rectangle("fill", cx - r * 0.85, cy + r * 0.45, r * 1.5, r * 0.35)
    love.graphics.setLineWidth(2)
    love.graphics.line(cx + r * 0.1, cy + r * 0.05, cx + r * 0.9, cy - r * 0.35)
    -- Crown
    fillPolygon({
        cx - r * 0.55, cy - r * 0.25, cx - r * 0.6, cy - r * 0.85, cx - r * 0.3, cy - r * 0.5,
        cx - r * 0.1, cy - r * 0.9, cx + r * 0.1, cy - r * 0.5, cx + r * 0.4, cy - r * 0.85,
        cx + r * 0.35, cy - r * 0.25,
    })
end

local function iconColor(name)
    if name == "mainTurret" then return MAIN_TURRET_COLOR end
    if isFiringType[name] then return FIRING_COLOR end
    return DamageTypes.colors[name] or RESOURCE_COLORS[name] or FIRING_COLOR
end

--- Draws one icon as a small framed badge with its top-left corner at (x, y).
function CardIcons.drawIcon(name, x, y, size)
    size = size or CardIcons.SIZE
    local color = iconColor(name)
    local half = size / 2

    love.graphics.setColor(color[1], color[2], color[3], 0.12)
    love.graphics.rectangle("fill", x, y, size, size, 3)
    love.graphics.setColor(color[1], color[2], color[3], 0.6)
    love.graphics.setLineWidth(1)
    love.graphics.rectangle("line", x, y, size, size, 3)

    local glyph = glyphs[name]
    if glyph then
        love.graphics.setColor(color)
        glyph(x + half, y + half, half * 0.75, color)
    end
    love.graphics.setLineWidth(1)
end

--- Draws a row of icons left to right from (x, y).
function CardIcons.drawRow(icons, x, y, size)
    size = size or CardIcons.SIZE
    for i, name in ipairs(icons) do
        CardIcons.drawIcon(name, x + (i - 1) * (size + CardIcons.SPACING), y, size)
    end
end

--- The icon in a row drawn from (x, y) that contains (px, py), and its index.
function CardIcons.iconAt(icons, x, y, px, py, size)
    size = size or CardIcons.SIZE
    if py < y or py > y + size then return nil end
    for i, name in ipairs(icons) do
        local ix = x + (i - 1) * (size + CardIcons.SPACING)
        if px >= ix and px <= ix + size then return name, i end
    end
    return nil
end

local TOOLTIP_WIDTH = 220
local TOOLTIP_PADDING = 7

--- Draws an icon's name and meaning in a panel above (x, y), kept on screen.
function CardIcons.drawTooltip(name, x, y)
    local info = CardIcons.INFO[name]
    if not info then return end
    local font = love.graphics.getFont()
    local textW = TOOLTIP_WIDTH - TOOLTIP_PADDING * 2
    local _, lines = font:getWrap(info[2], textW)
    local lineH = font:getHeight()
    local boxW = TOOLTIP_WIDTH
    local boxH = TOOLTIP_PADDING * 2 + lineH * (1 + #lines) + 2

    local boxX = math.max(5, math.min(x - boxW / 2, VIRTUAL_WIDTH - 5 - boxW))
    local boxY = y - 8 - boxH
    if boxY < 5 then boxY = y + CardIcons.SIZE + 8 end

    love.graphics.setColor(0.03, 0.05, 0.09, 0.94)
    love.graphics.rectangle("fill", boxX, boxY, boxW, boxH, 4)
    love.graphics.setColor(0.0, 0.7, 1.0, 0.4)
    love.graphics.setLineWidth(1)
    love.graphics.rectangle("line", boxX, boxY, boxW, boxH, 4)

    love.graphics.setColor(iconColor(name))
    love.graphics.print(info[1], boxX + TOOLTIP_PADDING, boxY + TOOLTIP_PADDING)
    love.graphics.setColor(0.85, 0.88, 0.92, 1)
    love.graphics.printf(info[2], boxX + TOOLTIP_PADDING, boxY + TOOLTIP_PADDING + lineH + 2, textW, "left")
    love.graphics.setColor(1, 1, 1, 1)
end

return CardIcons
