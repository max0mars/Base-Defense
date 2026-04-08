local hitbox = require("Physics.hitbox") -- Import the hitbox module
local EffectManager = require("Game.Effects.EffectManager") -- Import the EffectManager module

local object = {
    id_count = 0, -- Unique identifier for the object
}
object.__index = object

function object:new(config)
    if config.shape == "circle" then
        error("Circle shape is deprecated, use rectangle with width and height instead")
    end
    local obj = {
        destroyed = false, -- Flag to indicate if the object is destroyed
        id = newID(),
    }
    for key, value in pairs(config) do
        obj[key] = value -- Copy all config properties to the new object
    end
    obj.x = config.x or 0
    obj.y = config.y or 0
    obj.size = config.size or nil -- Default size is nil
    obj.w = config.w or nil -- Width for rectangle
    obj.h = config.h or nil -- Height for rectangle
    obj.shape = config.shape or nil -- shape if needed
    obj.color = config.color or {1, 1, 1, 1} -- Default color is white
    obj.game = config.game or nil -- Reference to the game object if needed
    
    -- Initialize Multi-Type system (O(1) lookup)
    obj.types = {}
    if config.types then
        if type(config.types) == "table" then
            for _, t in ipairs(config.types) do obj.types[t] = true end
            for k, v in pairs(config.types) do if type(k) == "string" then obj.types[k] = v end end
        elseif type(config.types) == "string" then
            obj.types[config.types] = true
        end
    end

    -- Support transition from tag to types
    if config.tag then
        obj.types[config.tag] = true
    end
    -- Support transition from tag to types
    if config.tag then
        obj.types[config.tag] = true
    end
    if config.effectManager then
        obj.effectManager = EffectManager:new(obj) -- Initialize EffectManager if config provided
        if obj.game and obj.game.playerEffectManager then
            obj.effectManager.parent = obj.game.playerEffectManager
        end
    end
    if config.hitbox then
        if not obj.w or not obj.h then
            error("Width (w) and Height (h) must be provided for hitbox")
        end
        if not obj.shape then
            error("Hitbox has no shape")
        end
        obj.hitbox = hitbox:new(obj) -- Create a hitbox with reference to new object
    end
    return setmetatable(obj, self)
end

function newID()
    object.id_count = object.id_count + 1
    return object.id_count
end

function object:died()
    self:destroy() -- Call the destroy method to clean up
end

function object:destroy()
    self.destroyed = true -- Mark the object as destroyed
end

function object:getID()
    return self.id
end

function object:getHitbox()
    return self.hitbox -- Return the hitbox associated with the object
end
    
function object:isType(typeName)
    return self.types and self.types[typeName] == true
end

function object:getStat(statName)
    if self[statName] == nil then
        error("Developer Error: Object [" .. (self.name or "Unknown") .. "] is missing the '" .. statName .. "' stat. All stats accessed via getStat must be explicitly defined in the class (even if set to 0) to ensure modifiers are applied correctly.")
    end

    if self.effectManager and self.effectManager.getStat then
        return self.effectManager:getStat(statName, self[statName])
    end
    return self[statName]
end

-- function object:getSize()
--     return self.size
-- end

-- function object:setHitbox(hitbox)
--     self.hitbox = hitbox -- Set the hitbox for the object
-- end

function object:draw()
    love.graphics.setColor(self.color or {1, 1, 1, 1}) -- Set the color for drawing
    if self.shape == "circle" then
        love.graphics.circle("fill", self.x, self.y, self.size)
    elseif self.shape == "rectangle" then
        love.graphics.rectangle("fill", self.x - self.w / 2, self.y - self.h / 2, self.w, self.h)
    end
end

return object