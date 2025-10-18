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
    love.graphics.setColor(0.1, 0.1, 0.1, 0.8)
    love.graphics.rectangle("fill", x, y, width, height)
    
    -- Draw rarity border
    love.graphics.setColor(color[1], color[2], color[3], 1.0)
    --love.graphics.setLineWidth(isSelected and 4 or 2)
    love.graphics.rectangle("line", x, y, width, height)
    
    -- Draw name
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.printf(self.name, x + 5, y + 60, width - 10, "center")
    
    -- Draw rarity
    love.graphics.setColor(color[1], color[2], color[3], 1.0)
    love.graphics.printf(string.upper(self.rarity), x + 5, y + 80, width - 10, "center")
    
    -- Draw description
    love.graphics.setColor(0.8, 0.8, 0.8, 1.0)
    love.graphics.printf(self.description, x + 5, y + 100, width - 10, "left")
    --love.graphics.setLineWidth(1)
end

return Reward