return function(result)
    local t = {}
    for group, constants in pairs(result) do
        for constant, value in pairs(constants) do
            t[group .. "_" .. constant] = value
        end
    end
    return t
end
