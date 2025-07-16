local game = {}
game.__index = game

function game:load(saveData)
    if saveData then
        self.objects = saveData.objects or {} -- Load existing game objects
        self.score = saveData.score or 0 -- Load score from save data
        self.xp = saveData.xp or 0 -- Load XP from save data
    else 
        self.objects = {} -- Table to hold game objects
        self.score = 0 -- Initialize score
    end
end

function game:addXP(amount)
    self.xp = (self.xp or 0) + amount
end

return game