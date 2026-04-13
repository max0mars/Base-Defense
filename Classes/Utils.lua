local Utils = {}

function Utils.deepCopy(orig, seen)
    seen = seen or {}
    if seen[orig] then return seen[orig] end
    
    local orig_type = type(orig)
    local copy
    if orig_type == 'table' then
        copy = {}
        seen[orig] = copy
        for orig_key, orig_value in next, orig, nil do
            copy[Utils.deepCopy(orig_key, seen)] = Utils.deepCopy(orig_value, seen)
        end
        setmetatable(copy, Utils.deepCopy(getmetatable(orig), seen))
    else -- number, string, boolean, etc
        copy = orig
    end
    return copy
end

function Utils.defaults(obj)
    
end

return Utils
