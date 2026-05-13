-- Reward.lua - Template class for individual rewards
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
    
    -- Rarity colors for visual representation
    reward.rarityColors = {
        common = {0.7, 0.7, 0.7}, -- Gray
        uncommon = {0.0, 1.0, 0.0}, -- Green
        rare = {0.0, 0.5, 1.0}, -- Blue
        epic = {0.6, 0.0, 1.0}, -- Purple
        legendary = {1.0, 0.8, 0.0} -- Gold
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

function Reward:draw(x, y, width, height, isSelected)
    -- Draw the reward card
    local color = self:getRarityColor()
    
    -- Draw background with rarity color border
    love.graphics.setColor(0.1, 0.1, 0.1, 1.0) -- Opaque
    love.graphics.rectangle("fill", x, y, width, height)
    
    -- Draw rarity border
    love.graphics.setColor(color[1], color[2], color[3], 1.0)
    --love.graphics.setLineWidth(isSelected and 4 or 2)
    love.graphics.rectangle("line", x, y, width, height)
    
    local topPadding = math.floor(height * 0.15)
    
    -- Draw name
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.printf(self.name, x + 5, y + topPadding, width - 10, "center")
    
    -- Draw rarity
    love.graphics.setColor(color[1], color[2], color[3], 1.0)
    love.graphics.printf(string.upper(self.rarity), x + 5, y + topPadding + (height > 120 and 20 or 40), width - 10, "center")
    
    -- Draw description
    if height > 120 then
        love.graphics.setColor(0.8, 0.8, 0.8, 1.0)
        love.graphics.printf(self.description, x + 5, y + topPadding + 45, width - 10, "left")
    end
    
    -- Draw Category Icon at the bottom center
    local iconCat = self.iconCategory
    if not iconCat then
        if self.type == "main_upgrade" or self.type == "effect" or self.type == "upgrade" then
            iconCat = "upgrade"
        elseif self.type == "building" then
            if self.id and (self.id:find("buff") or self.id:find("Buff") or self.id:find("Cache") or self.id == "bank" or self.id:find("Coating") or self.id:find("Rounds") or self.id:find("rounds")) then
                iconCat = "buff"
            elseif self.id and (self.id:find("box") or self.id:find("fence") or self.id:find("Blocker")) then
                iconCat = "blocker"
            else
                iconCat = "turret"
            end
        else
            iconCat = "upgrade"
        end
    end
    
    if iconCat then
        love.graphics.push("all")
        local cx = math.floor(x + width / 2)
        local cy = math.floor(y + height - 20)
        
        if iconCat == "buff" then
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
                local cellSize = 5
                local startX = cx - (gridW * cellSize) / 2
                local startY = cy - (gridH * cellSize) / 2
                
                for r = minY, maxY do
                    for c = minX, maxX do
                        local px = startX + (c - minX) * cellSize
                        local py = startY + (r - minY) * cellSize
                        local key = c .. "," .. r
                        if shapeMap[key] then
                            love.graphics.setColor(0.6, 0.6, 0.6, 1)
                            love.graphics.rectangle("fill", px, py, cellSize-1, cellSize-1)
                        elseif buffMap[key] then
                            love.graphics.setColor(0.2, 0.8, 0.2, 1)
                            love.graphics.rectangle("fill", px, py, cellSize-1, cellSize-1)
                        end
                    end
                end
            else
                -- Fallback 3x3 grid
                local startX = cx - 7
                local startY = cy - 7
                for r = 1, 3 do
                    for c = 1, 3 do
                        if r == 2 and c == 2 then
                            love.graphics.setColor(0.6, 0.6, 0.6, 1)
                        else
                            love.graphics.setColor(0.2, 0.8, 0.2, 1)
                        end
                        love.graphics.rectangle("fill", startX + (c - 1) * 5, startY + (r - 1) * 5, 4, 4)
                    end
                end
            end
        elseif iconCat == "turret" then
            -- Simple circle with barrel
            love.graphics.setColor(0.7, 0.7, 0.7, 1)
            love.graphics.circle("fill", cx, cy, 5)
            love.graphics.setColor(1, 1, 1, 1)
            love.graphics.setLineWidth(1)
            love.graphics.circle("line", cx, cy, 5)
            love.graphics.setColor(0.9, 0.9, 0.9, 1)
            love.graphics.rectangle("fill", cx - 1.5, cy - 9, 3, 5)
        elseif iconCat == "blocker" then
            -- Small fence: 3 vertical posts, 2 horizontal rails
            love.graphics.setColor(0.7, 0.5, 0.3, 1)
            love.graphics.rectangle("fill", cx - 7, cy - 6, 2, 12)
            love.graphics.rectangle("fill", cx - 1, cy - 6, 2, 12)
            love.graphics.rectangle("fill", cx + 5, cy - 6, 2, 12)
            love.graphics.rectangle("fill", cx - 8, cy - 3, 16, 2)
            love.graphics.rectangle("fill", cx - 8, cy + 3, 16, 2)
        elseif iconCat == "upgrade" then
            -- Plus sign (+)
            love.graphics.setColor(1, 0.8, 0.2, 1)
            love.graphics.rectangle("fill", cx - 6, cy - 1.5, 12, 3)
            love.graphics.rectangle("fill", cx - 1.5, cy - 6, 3, 12)
        end
        love.graphics.pop()
    end
end

return Reward