local Utils = {}

function Utils.deepCopy(orig)
    local orig_type = type(orig)
    local copy
    if orig_type == 'table' then
        copy = {}
        for orig_key, orig_value in next, orig, nil do
            copy[Utils.deepCopy(orig_key)] = Utils.deepCopy(orig_value)
        end
        setmetatable(copy, Utils.deepCopy(getmetatable(orig)))
    else -- number, string, boolean, etc
        copy = orig
    end
    return copy
end

return Utils
