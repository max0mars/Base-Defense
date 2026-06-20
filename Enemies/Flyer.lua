--[[
local Enemy = require("Enemies.Enemy")
local Flyer = setmetatable({}, {__index = Enemy})
Flyer.__index = Flyer

-- Flyer subclass is now redundant as its properties (color, shape, size, speed, HP, damage, types)
-- are fully consolidated into EnemyIndex/TestingEnemyIndex and handled by the base Enemy class.
--]]
