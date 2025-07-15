object = {
    id_count = 0, -- Unique identifier for the object
}
object.__index = object

function object:new()
    local obj = {
        destroyed = false, -- Flag to indicate if the object is destroyed
        id = newID(),
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