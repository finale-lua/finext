local errors = require("lib.errors")

return function(result)
    if type(result) ~= "table" then
        return false, errors.bad_value_msg("Utils definition", "table", type(result))
    end

    for k, v in pairs(result) do
        if type(k) ~= "string" then
            return false, errors.bad_value_msg("Utils keys", "string", type(k)), tostring(k)
        end

        if type(v) ~= "function" then
            return false, errors.bad_value_msg("Utils functions", "function", type(v)), k
        end
    end

    return true
end
