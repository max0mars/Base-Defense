hitbox = {}
hitbox.__index = hitbox

local collision = require("Scripts.collision")

function hitbox:new(entity, type)
    if not entity then
        error("Entity must be provided for hitbox creation")
    end
    if type ~= "circle" and type ~= "square" then
        error("Invalid hitbox type. Must be 'circle' or 'square'")
    end

    local obj = setmetatable({}, self)
    obj.entity = entity -- Reference to the entity this hitbox belongs to
    obj.type = type
    return obj
end

function hitbox:getX()
    return self.entity.x
end

function hitbox:getY()
    return self.entity.y
end

function hitbox:getXY()
    return self.entity.x, self.entity.y
end

function hitbox:getSize()
    return self.entity.size
end

-- probably won't be used, but just in case
function hitbox:checkCollision(other)
    return collision:checkCollision(self, other)
end