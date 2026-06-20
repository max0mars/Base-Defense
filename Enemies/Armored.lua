--[[
local Enemy = require("Enemies.Enemy")
local Armored = setmetatable({}, {__index = Enemy})
Armored.__index = Armored

-- Armored subclass is now redundant as its properties (color, shape, size, speed, HP, damage, affinities, types)
-- are fully consolidated into EnemyIndex/TestingEnemyIndex and handled by the base Enemy class.
--]]
