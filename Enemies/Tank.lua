--[[
local Enemy = require("Enemies.Enemy")
local tank = setmetatable({}, {__index = Enemy})
tank.__index = tank

-- Tank subclass is now redundant as its properties (color, shape, size, speed, HP, damage, types)
-- are fully consolidated into EnemyIndex/TestingEnemyIndex and handled by the base Enemy class.
--]]
