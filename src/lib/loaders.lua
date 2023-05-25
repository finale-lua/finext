local loaders = {}

local try_require = errors.create_handler({
    custom = function(msg)
        if msg:match("module '[^']-' not found") then
            return
        end
        return msg
    end,
})

function loaders.create_lazy_loader(paths, validator)
    return setmetatable({}, {
        __index = function(t, k)
            if not validator.is_valid_key(k) then
                return nil
            end
            for _, p in ipairs(paths) do
                local full_path = p .. "." .. k
                local result = try_require(require, full_path)
                if result then
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
        local result = try_require(require, full_path)
        if result then
            parser(result, t, full_path)
        end
    end
    return t
end

return loaders
