local hitbox = require("Physics.hitbox") -- Import the hitbox module

local object = {
    id_count = 0, -- Unique identifier for the object
}
object.__index = object

function object:new(config)
    local obj = {
        destroyed = false, -- Flag to indicate if the object is destroyed
        id = newID(),
        x = config.x or 0,
        y = config.y or 0,
        size = config.size or nil, -- Default size is nil
        w = config.w or nil, -- Width for rectangle
        h = config.h or nil, -- Height for rectangle
        shape = config.shape or nil, -- shape if needed
        color = config.color or {1, 1, 1, 1}, -- Default color is white
        game = config.game or nil, -- Reference to the game object if needed
        tag = config.tag or nil, -- Tag for collision detection
        big = config.big or false, -- Flag to indicate if the object is big
    }
    if config.hitbox then
        if obj.shape ~= "circle" and obj.shape ~= "rectangle" then
                -- If the shape is not a circle or rectangle, use a custom hitbox
                error("Unsupported shape for hitbox: " .. tostring(obj.shape))
            end
        local hitboxConfig = {
            object = obj, -- Reference to the object this hitbox belongs to
            type = config.hitbox.shape or obj.shape, -- Default to circle if not specified
        }
        obj.hitbox = hitbox:new(hitboxConfig) -- Create a hitbox if specified
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

function object:getSize()
    return self.size
end

function object:setHitbox(hitbox)
    self.hitbox = hitbox -- Set the hitbox for the object
end

function object:draw()
    love.graphics.setColor(self.color) -- Set the color for drawing
    if self.shape == "circle" then
        love.graphics.circle("fill", self.x, self.y, self.size)
    elseif self.shape == "rectangle" then
        love.graphics.rectangle("fill", self.x - self.w / 2, self.y - self.h / 2, self.w, self.h)
    end
end

return object