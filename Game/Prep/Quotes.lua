-- Game/Prep/Quotes.lua
-- The quiet preparation phase after the first battle of each loop: a random
-- motivational quote, picked once per visit.

local Quotes = {}

-- Lines from classic texts on strategy, plus well-documented quotes from
-- leaders and writers. Sun Tzu is quoted from Lionel Giles's 1910 translation,
-- Musashi from the Victor Harris translation.
Quotes.list = {
    { text = "The art of war teaches us to rely not on the likelihood of the enemy's not coming, but on our own readiness to receive him.", author = "Sun Tzu, The Art of War" },
    { text = "If you know the enemy and know yourself, you need not fear the result of a hundred battles.", author = "Sun Tzu, The Art of War" },
    { text = "To secure ourselves against defeat lies in our own hands, but the opportunity of defeating the enemy is provided by the enemy himself.", author = "Sun Tzu, The Art of War" },
    { text = "The victorious strategist only seeks battle after the victory has been won, whereas he who is destined to defeat first fights and afterwards looks for victory.", author = "Sun Tzu, The Art of War" },
    { text = "He will win who knows when to fight and when not to fight.", author = "Sun Tzu, The Art of War" },
    { text = "Let your plans be dark and impenetrable as night, and when you move, fall like a thunderbolt.", author = "Sun Tzu, The Art of War" },
    { text = "Appear at points which the enemy must hasten to defend; march swiftly to places where you are not expected.", author = "Sun Tzu, The Art of War" },
    { text = "Supreme excellence consists in breaking the enemy's resistance without fighting.", author = "Sun Tzu, The Art of War" },
    { text = "In war, then, let your great object be victory, not lengthy campaigns.", author = "Sun Tzu, The Art of War" },
    { text = "All warfare is based on deception.", author = "Sun Tzu, The Art of War" },
    { text = "Do nothing which is of no use.", author = "Miyamoto Musashi, The Book of Five Rings" },
    { text = "Perceive that which cannot be seen with the eye.", author = "Miyamoto Musashi, The Book of Five Rings" },
    { text = "Everything in war is very simple, but the simplest thing is difficult.", author = "Carl von Clausewitz, On War" },
    { text = "Let him who desires peace prepare for war.", author = "Vegetius, De Re Militari" },
    { text = "Never give in, never give in, never, never, never, never.", author = "Winston Churchill, Harrow School, 1941" },
    { text = "We shall go on to the end... we shall never surrender.", author = "Winston Churchill, 1940" },
    { text = "Plans are worthless, but planning is everything.", author = "Dwight D. Eisenhower" },
    { text = "Fortune favors the bold.", author = "Terence, Phormio" },
    { text = "The impediment to action advances action. What stands in the way becomes the way.", author = "Marcus Aurelius, Meditations" },
    { text = "Waste no more time arguing about what a good man should be. Be one.", author = "Marcus Aurelius, Meditations" },
    { text = "Do what you can, with what you have, where you are.", author = "Theodore Roosevelt" },
    { text = "The credit belongs to the man who is actually in the arena.", author = "Theodore Roosevelt, 1910" },
    { text = "The harder the conflict, the more glorious the triumph.", author = "Thomas Paine, The American Crisis" },
    { text = "These are the times that try men's souls.", author = "Thomas Paine, The American Crisis" },
    { text = "Ever tried. Ever failed. No matter. Try again. Fail again. Fail better.", author = "Samuel Beckett, Worstward Ho" },
    { text = "Fall seven times, stand up eight.", author = "Japanese proverb" },
}

function Quotes.get(visit)
    visit.quote = visit.quote or math.random(#Quotes.list)
    return Quotes.list[visit.quote]
end

function Quotes.draw(scene, visit, area)
    if not scene.quoteFont then scene.quoteFont = love.graphics.newFont(26) end
    local quote = Quotes.get(visit)
    local oldFont = love.graphics.getFont()
    love.graphics.setFont(scene.quoteFont)
    local w = math.min(area.w, 800)
    local x = area.x + (area.w - w) / 2
    local text = "\"" .. quote.text .. "\""
    local _, lines = scene.quoteFont:getWrap(text, w)
    local textH = #lines * scene.quoteFont:getHeight()
    local y = area.y + (area.h - textH) / 2 - 20
    love.graphics.setColor(0.85, 0.9, 1, 0.95)
    love.graphics.printf(text, x, y, w, "center")
    love.graphics.setFont(oldFont)
    love.graphics.setColor(0.6, 0.65, 0.75, 0.95)
    love.graphics.printf("- " .. quote.author, x, y + textH + 16, w, "center")
end

function Quotes.mousepressed()
    return false
end

return Quotes
