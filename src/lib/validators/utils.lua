local function err_type(name, expected, given)
    return name .. " must be a " .. expected .. ", " .. given .. " given"
end

return function(result)
    if type(result) ~= "table" then
        return false, err_type("Utils definition", "table", type(result))
    end

    for k, v in pairs(result) do
        if type(k) ~= "string" then
            return false, err_type("Utils keys", "string", type(k)), tostring(k)
        end

        if type(v) ~= "function" then
            return false, err_type("Utils functions", "function", type(v)), k
        end
    end

    return true
end
