local validator = {}

local function err_type(name, expected, given)
    return name .. " must be a " .. expected .. ", " .. given .. " given"
end

local function process_level(params, k, v)
    if params.type and type(v) ~= params.type then
        return false, err_type(params.name, params.type, type(v)), k
    end

    if params.functions then
        for _, func in ipairs(params.functions) do
        local success, err = func(k, v)
            if not success then
                return success, err, k
            end
        end
    end

    if params.children then
        for kk, vv in pairs(v) do
            local success, err, path = process_level(params.children, kk, vv)
            if not success then
                if path then
                    path = k .. "." .. path
                end
                return success, err, path
            end
        end
    end

    if params.named_children then
        for kk, child in pairs(params.named_children) do
            if v[kk] then
                local success, err, path = process_level(child, kk, v[kk])
                if not success then
                    if path then
                        path = k .. "." .. path
                    end
                    return success, err, path
                end
            end
        end
    end

    return true
end

function validator.create_module_validator(params)
    return function(t)
        return process_level(params, nil, t)
    end
end

return validator
