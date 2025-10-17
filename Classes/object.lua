local hitbox = require("Physics.hitbox") -- Import the hitbox module

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
    obj.tag = config.tag or nil -- Tag for collision detection
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