local errors = require("lib.errors")

local function is_valid_name(name)
    return string.match(name, "^%u+") or string.match(name, "^%u[%u_]-%u$") and true or false
end

local function err_name(name, given)
    return errors.bad_value_msg("Constant " .. name_type, "string containing uppercase letters and underscores and cannot start or end with an underscore", given)
end

return function(result)
    if type(result) ~= "table" then
        return false, errors.bad_value_msg("Constant definition", "table", type(result))
    end

    for k, v in pairs(result) do
        if type(k) ~= "string" then
            return false, errors.bad_value_msg("Constant group names", "string", type(k)), tostring(k)
        end

        if not is_valid_name(k) then
            return false, err_name("group names", k), k
        end

        local value_index = {}
        for kk, vv in pairs(v) do
            if type(kk) ~= "string" then
                return false, errors.bad_value_msg("Constant names", "string", type(kk)), k .. "." .. tostring(kk)
            end

            if not is_valid_name(kk) then
                return false, err_name("group names", kk), k .. "." .. kk
            end

            if value_index[v] then
                return false, "Each value within a constant group must be unique", k .. "." .. "kk"
            end

            value_index[v] = true
        end
    end

    return true
end
