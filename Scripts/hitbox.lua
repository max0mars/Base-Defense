hitbox = {}
hitbox.__index = hitbox

require("Scripts.collision")

function hitbox:new(entity, type, tag)
    if not entity then
        error("Entity must be provided for hitbox creation")
    end
    if type ~= "circle" and type ~= "square" and type ~= "triangle" then
        error("Invalid hitbox type. Must be 'circle', 'square', or 'triangle'")
    end
    if tag and type(tag) ~= "string" then
        error("Tag must be a string")
    end

    local obj = setmetatable({}, self)
    obj.entity = entity -- Reference to the entity this hitbox belongs to
    obj.type = type
    obj.tag = tag or ''
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

function hitbox:checkCollision(other)
    return collision:checkCollision(self, other)
end