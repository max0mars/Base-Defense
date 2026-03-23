BuffManager = {}
BuffManager.__index = BuffManager

function BuffManager:new(owner)
    local instance = setmetatable({}, BuffManager)
    instance.owner = owner
    instance.buffs = {}
    instance.debuffs = {}
    instance.buffableStats = {}
    return instance
end

function BuffManager:addBuff(sourceId, buffData)
    self.buffs[sourceId] = buffData
end

function BuffManager:removeBuff(sourceId)
    self.buffs[sourceId] = nil
end

function BuffManager:clearAllBuffs()
    self.buffs = {}
end

function BuffManager:getActiveBuff(sourceId)
    return self.buffs[sourceId]
end

function BuffManager:hasBuffFrom(sourceId)
    return self.buffs[sourceId] ~= nil
end
