--[[
local Enemy = require("Enemies.Enemy")
local speeder = setmetatable({}, {__index = Enemy})
speeder.__index = speeder

-- Speeder subclass is now redundant as its properties (color, shape, size, speed, HP, types)
-- are fully consolidated into EnemyIndex/TestingEnemyIndex and handled by the base Enemy class.
--]]
