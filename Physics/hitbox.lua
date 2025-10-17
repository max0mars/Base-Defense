hitbox = {}
hitbox.__index = hitbox

local collision = require("Physics.collisionSystem_brute")

function hitbox:new(object)
    if not object then
        error("object must be provided for hitbox creation")
    end

    local obj = setmetatable({}, self)
    obj.object = object -- Reference to the object this hitbox belongs to
    return obj
end

function hitbox:getX()
    return self.object.x
end

function hitbox:getY()
    return self.object.y
end

function hitbox:getXY()
    return self.object.x, self.object.y
end

function hitbox:getSize()
    error("getSize is deprecated, use getWidth and getHeight instead")
    return self.object.size
end

function hitbox:getWidth()
    return self.object.w
end

function hitbox:getHeight()
    return self.object.h
end

-- probably won't be used, but just in case
function hitbox:checkCollision(other)
    return collision:checkCollision(self, other)
end

return hitbox