local loaders = {}

-- Attempts to load a module
local function try_load_module(name)
    local success, result = pcall(require, name)

    -- If the reason it failed to load was anything other than module not found, display the error
    if not success and not result:match("module '[^']-' not found") then
        error(result, 0)
    end

    return success, result
end

function loaders.create_lazy_loader(paths, validator)
    return setmetatable({}, {
        __index = function(t, k)
            if not validator.is_valid_key(k) then
                return nil
            end
            for _, p in ipairs(paths) do
                local full_path = p .. "." .. k
                local success, result = try_load_module(full_path)
                if success then
                    result = validator.validate(result, k, full_path)
                    rawset(t, k, result)
                    return result
                end
            end
            return nil
        end,
    })
end

function loaders.load_into(t, mod_name, paths, parser)
    for _, p in ipairs(paths) do
        local full_path = p .. "." .. mod_name
        local success, result = try_load_module(full_path)
        if success then
            parser(result, t, full_path)
        end
    end
    return t
end

return loaders
