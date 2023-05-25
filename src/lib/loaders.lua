local loaders = {}

local require_error_handler = errors.create_handler({
    custom = function(msg)
        if msg:match("module '[^']-' not found") then
            return nil
        end

        return msg
    end,
})

local function try_require(mod_name, exclude_external_files)
    if exclude_external_files and not package.preload(mod_name) then
        return nil
    end

    return require_error_handler(require, mod_name)
end

function loaders.create_lazy_loader(paths, validator, exclude_external_files)
    return setmetatable({}, {
        __index = function(t, k)
            if not validator.is_valid_key(k) then
                return nil
            end

            local result
            for _, p in ipairs(paths) do
                local full_path = p .. "." .. k
                result = try_require(require, full_path, exclude_external_files)
                if result then
                    break
                end
            end

            if result == nil then
                result = validator.get_default_value(k)
            end

            if result ~= nil then
                result = validator.validate(result, k, full_path)
                rawset(t, k, result)
            end

            return result
        end,
    })
end

function loaders.load_into(t, mod_name, paths, parser, exclude_external_files)
    for _, p in ipairs(paths) do
        local full_path = p .. "." .. mod_name
        local result = try_require(require, full_path, exclude_external_files)
        if result then
            parser(result, t, full_path)
        end
    end
    return t
end

return loaders
