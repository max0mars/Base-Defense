object = {
    id_count = 0, -- Unique identifier for the object
}
object.__index = object

function object:new(config)
    local obj = {
        destroyed = false, -- Flag to indicate if the object is destroyed
        id = newID(),
        hitbox = config.hitbox or nil, -- Placeholder for the hitbox, can be set later
        x = config.x or 0,
        y = config.y or 0,
        size = config.size or 10, -- Default size is 10
        shape = config.shape or "circle", -- Default shape is circle
        color = config.color or {1, 1, 1, 1}, -- Default color is white
        game = config.game or nil, -- Reference to the game object if needed
        tag = config.tag or '', -- Tag for collision detection
    }
    return setmetatable(obj, self)
end

function newID()
    object.id_count = object.id_count + 1
    return object.id_count
end

function object:destroy()
    self.destroyed = true -- Mark the object as destroyed
    if self.hitbox then
        self.hitbox:destroy()
        self.hitbox = nil
    end
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
    elseif self.shape == "square" then
        local halfSize = self.size / 2
        love.graphics.rectangle("fill", self.x - halfSize, self.y - halfSize, self.size, self.size)
    end
end

return object