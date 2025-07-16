hitbox = {}
hitbox.__index = hitbox

local collision = require("Scripts.collision")

function hitbox:new(config)
    if not config.object then
        error("object must be provided for hitbox creation")
    end
    if config.type ~= "circle" and config.type ~= "rectangle" then
        error("Invalid hitbox type. Must be 'circle' or 'rectangle'")
    end

    local obj = setmetatable({}, self)
    obj.object = config.object -- Reference to the object this hitbox belongs to
    obj.type = config.type
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
    return self.object.size
end

function hitbox:getW()
    return self.object.w
end

function hitbox:getH()
    return self.object.h
end

-- probably won't be used, but just in case
function hitbox:checkCollision(other)
    return collision:checkCollision(self, other)
end

return hitbox