-- Reward.lua - Template class for individual rewards
local TurretStatBars = require("Game.GUI.TurretStatBars")
local CardDraw = require("Game.Cards.CardDraw")

local Reward = {}
Reward.__index = Reward

function Reward:new(config)
    local reward = setmetatable({}, self)
    
    -- Basic reward properties
    reward.name = config.name or "No Name"
    reward.description = config.description or "No description available"
    reward.sprite = config.sprite or nil -- Path to sprite or nil for text-only
    reward.rarity = config.rarity or "common" -- common, uncommon, rare, epic, legendary
    reward.type = config.type or "upgrade" -- upgrade, building, etc.
    reward.building = config.building or nil -- Reference to building class if type is building
    reward.id = config.id or nil -- Unique identifier
    reward.effect = config.effect or nil -- Table for Status Effects
    reward.iconCategory = config.iconCategory or nil
    reward.shapePattern = config.shapePattern or nil
    reward.color = config.color or nil
    reward.turretSlots = config.turretSlots or nil
    reward.isSlotted = config.isSlotted or false
    
    -- Rarity colors for visual representation
    reward.rarityColors = {
        common = {0.7, 0.7, 0.7}, -- Gray
        uncommon = {0.0, 1.0, 0.0}, -- Green
        rare = {0.0, 0.5, 1.0}, -- Blue
        epic = {0.6, 0.0, 1.0}, -- Purple
        legendary = {1.0, 0.8, 0.0}, -- Gold
        blocker = {0.9, 0.5, 0.1} -- Orange
    }
    -- Additional metadata
    reward.category = config.category or "general" -- weapon, defense, utility, etc.
    reward.game = config.game
    
    -- Create dummy building if it's a building type, to read properties for icons
    if reward.building and type(reward.building) == "table" and reward.building.new and reward.game then
        local success, b = pcall(reward.building.new, reward.building, {game = reward.game, types={building=true}})
        if success then
            reward.dummyBuilding = b
        else
            print("Failed to instantiate dummy building for reward: " .. tostring(reward.id))
        end
    end
    
    -- Instantiate the new scalable CardDraw UI element
    reward.rewardCard = CardDraw.new(0, 0, reward)
    
    return reward
end

function Reward:getRarityColor()
    return self.rarityColors[self.rarity] or self.rarityColors.common
end

function Reward:getRarityWeight()
    -- Weights for rarity selection (higher = more common)
    local weights = {
        common = 100,
        uncommon = 50,
        rare = 20,
        epic = 8,
        legendary = 2
    }
    return weights[self.rarity] or weights.common
end

function Reward:execute(game)
    -- Execute the reward's effect
    if self.onSelect then
        self.onSelect(game)
    end
end

--- Resolves the display category for the card's emblem.
function Reward:resolveIconCat()
    if self.iconCategory then return self.iconCategory end
    if self.type == "main_upgrade" or self.type == "effect" or self.type == "upgrade" then
        return "upgrade"
    elseif self.type == "building" then
        if self.id and (self.id:find("buff") or self.id:find("Buff") or self.id:find("Cache") or self.id == "bank" or self.id:find("Coating") or self.id:find("Rounds") or self.id:find("rounds")) then
            return "buff"
        elseif self.id and (self.id:find("box") or self.id:find("fence") or self.id:find("Blocker")) then
            return "blocker"
        else
            return "turret"
        end
    end
    return "upgrade"
end

--- Draws the type emblem centered at (cx, cy). Turrets/upgrades get a ringed
--- badge; buffs/blockers render their shape footprint.
function Reward:drawEmblem(iconCat, cx, cy)
    local color = self:getRarityColor()
    love.graphics.push("all")

    if iconCat == "turret" then
        love.graphics.setColor(color[1], color[2], color[3], 0.5)
        love.graphics.setLineWidth(1)
        love.graphics.circle("line", cx, cy, 10)
        love.graphics.setColor(0.78, 0.82, 0.88, 1)
        love.graphics.circle("fill", cx, cy, 5)
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.circle("line", cx, cy, 5)
        love.graphics.setColor(0.9, 0.9, 0.95, 1)
        love.graphics.rectangle("fill", cx - 1.5, cy - 12, 3, 7) -- barrel pointing up

    elseif iconCat == "upgrade" then
        love.graphics.setColor(color[1], color[2], color[3], 0.5)
        love.graphics.setLineWidth(1)
        love.graphics.circle("line", cx, cy, 10)
        love.graphics.setColor(1, 0.8, 0.2, 1)
        love.graphics.rectangle("fill", cx - 6, cy - 1.5, 12, 3)
        love.graphics.rectangle("fill", cx - 1.5, cy - 6, 3, 12)

    elseif iconCat == "buff" then
        local cellSize = 6
        if self.dummyBuilding and self.dummyBuilding.shapePattern then
            local b = self.dummyBuilding
            local minX, maxX, minY, maxY = 0, 0, 0, 0
            local shapeMap = {}
            for _, p in ipairs(b.shapePattern) do
                shapeMap[p[1] .. "," .. p[2]] = true
                minX = math.min(minX, p[1]); maxX = math.max(maxX, p[1])
                minY = math.min(minY, p[2]); maxY = math.max(maxY, p[2])
            end
            local buffMap = {}
            if b.affectedSlots then
                for _, p in ipairs(b.affectedSlots) do
                    buffMap[p[1] .. "," .. p[2]] = true
                    minX = math.min(minX, p[1]); maxX = math.max(maxX, p[1])
                    minY = math.min(minY, p[2]); maxY = math.max(maxY, p[2])
                end
            end
            local gridW = maxX - minX + 1
            local gridH = maxY - minY + 1
            local startX = cx - (gridW * cellSize) / 2
            local startY = cy - (gridH * cellSize) / 2
            for r = minY, maxY do
                for c = minX, maxX do
                    local px = startX + (c - minX) * cellSize
                    local py = startY + (r - minY) * cellSize
                    local key = c .. "," .. r
                    if shapeMap[key] then
                        love.graphics.setColor(0.6, 0.6, 0.6, 1)
                        love.graphics.rectangle("fill", px, py, cellSize - 1, cellSize - 1)
                    elseif buffMap[key] then
                        love.graphics.setColor(0.2, 0.8, 0.2, 1)
                        love.graphics.rectangle("fill", px, py, cellSize - 1, cellSize - 1)
                    end
                end
            end
        else
            local startX = cx - cellSize * 1.5
            local startY = cy - cellSize * 1.5
            for r = 1, 3 do
                for c = 1, 3 do
                    if r == 2 and c == 2 then love.graphics.setColor(0.6, 0.6, 0.6, 1)
                    else love.graphics.setColor(0.2, 0.8, 0.2, 1) end
                    love.graphics.rectangle("fill", startX + (c - 1) * cellSize, startY + (r - 1) * cellSize, cellSize - 1, cellSize - 1)
                end
            end
        end

    elseif iconCat == "blocker" then
        if self.shapePattern then
            local minX, maxX, minY, maxY = 0, 0, 0, 0
            for _, p in ipairs(self.shapePattern) do
                minX = math.min(minX, p[1]); maxX = math.max(maxX, p[1])
                minY = math.min(minY, p[2]); maxY = math.max(maxY, p[2])
            end
            local gridW = maxX - minX + 1
            local gridH = maxY - minY + 1
            local cellSize = 7
            local startX = cx - (gridW * cellSize) / 2
            local startY = cy - (gridH * cellSize) / 2
            for _, p in ipairs(self.shapePattern) do
                local px = startX + (p[1] - minX) * cellSize
                local py = startY + (p[2] - minY) * cellSize
                local isSlot = false
                if self.isSlotted and self.turretSlots then
                    for _, ts in ipairs(self.turretSlots) do
                        if ts[1] == p[1] and ts[2] == p[2] then isSlot = true; break end
                    end
                end
                if isSlot then love.graphics.setColor(0, 0.8, 1, 1)
                else love.graphics.setColor(self.color or {0.9, 0.5, 0.1, 1}) end
                love.graphics.rectangle("fill", px, py, cellSize - 1, cellSize - 1)
            end
        end
    end

    love.graphics.pop()
end

function Reward:draw(x, y, width, height, isSelected)
    local color = self:getRarityColor()
    local iconCat = self:resolveIconCat()
    local bandH = 38

    -- Card body (dark glass).
    love.graphics.setColor(0.07, 0.08, 0.11, 1)
    love.graphics.rectangle("fill", x, y, width, height, 5)

    -- Header band tinted by rarity, capped by a rarity line.
    love.graphics.setColor(color[1], color[2], color[3], 0.10)
    love.graphics.rectangle("fill", x + 2, y + 2, width - 4, bandH)
    love.graphics.setColor(color[1], color[2], color[3], 0.55)
    love.graphics.setLineWidth(1)
    love.graphics.line(x, y + bandH, x + width, y + bandH)

    -- Type emblem, centered in the header band (consistent across all cards).
    self:drawEmblem(iconCat, math.floor(x + width / 2), math.floor(y + bandH / 2))

    -- Name.
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.printf(self.name, x + 6, y + bandH + 11, width - 12, "center")

    -- Rarity, rendered as a letter-spaced tag. Hidden on small (stored) cards.
    if height > 120 then
        local rarityTag = (string.upper(self.rarity):gsub("(.)", "%1 ")):gsub(" $", "")
        love.graphics.setColor(color[1], color[2], color[3], 1)
        love.graphics.printf(rarityTag, x + 6, y + bandH + 34, width - 12, "center")
    end

    -- Description (centered). Skipped when empty or placeholder.
    if height > 120 and self.description and self.description ~= ""
       and self.description ~= "No description available" then
        love.graphics.setColor(0.78, 0.8, 0.85, 1)
        love.graphics.printf(self.description, x + 10, y + bandH + 58, width - 20, "center")
    end

    -- Turret telemetry block: DPS headline + relative DMG/RNG/SPD tier bars.
    if iconCat == "turret" and self.dummyBuilding and self.game and height > 140 then
        local t = self.dummyBuilding
        local dmg = (t.getStat and t:getStat("damage", 0)) or t.damage or 0
        local fireRate = (t.getStat and t:getStat("fireRate", 0)) or t.fireRate or 0
        local dps = dmg * (t.pelletCount or 1) * fireRate

        local barOpts = { tiers = 5, labelW = 30, segW = 9, segH = 6, gap = 3, rowH = 12, labelScale = 0.9 }
        local barsW = TurretStatBars.barsWidth(barOpts)
        local colX = math.floor(x + (width - barsW) / 2)
        local statTop = y + height - 66

        love.graphics.setColor(color[1], color[2], color[3], 0.35)
        love.graphics.setLineWidth(1)
        love.graphics.line(x + 14, statTop, x + width - 14, statTop)

        love.graphics.setColor(1, 0.85, 0.2, 1)
        love.graphics.printf(string.format("DPS %.0f", dps), colX, statTop + 7, barsW, "center")

        TurretStatBars.drawBars(t, self.game, colX, statTop + 23, barOpts)
    end

    -- Rarity border on top (crisp), thicker when selected.
    love.graphics.setColor(color[1], color[2], color[3], 1)
    love.graphics.setLineWidth(isSelected and 3 or 1.5)
    love.graphics.rectangle("line", x, y, width, height, 5)
    love.graphics.setLineWidth(1)
end

return Reward