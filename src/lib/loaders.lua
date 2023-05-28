local loaders = {}

local function error_suffix(path, sub_path)
    sub_path = sub_path and ("[" .. sub_path .. "]") or ""
    return " (" .. path .. sub_path .. ")"
end

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

function loaders.create_lazy_loader(paths, key_validator, default_getter, parser, validator, exclude_external_files)
    return setmetatable({}, {
        __index = function(t, k)
            if not key_validator(k) then
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
                result = default_getter(k)
            end

            if result ~= nil then
                if validator then
                    local is_valid, err_msg, err_path = validator(result, k, t)
                    if not is_valid then
                        error(err_msg .. error_suffix(full_path, err_path), 0)
                    end
                end

                result = parser(result, k)
                t[k] = result
            end

            return result
        end,
    })
end

function loaders.load_into(t, mod_name, paths, parser, validator, exclude_external_files)
    for _, p in ipairs(paths) do
        local full_path = p .. "." .. mod_name
        local result = try_require(require, full_path, exclude_external_files)
        if result ~= nil then
            if validator then
                local is_valid, err_msg, err_path = validator(result)
                if not is_valid then
                    error(err_msg .. error_suffix(full_path, err_path), 0)
                end
                local parsed = parser(result)
                for k, v in pairs(parsed) do
                    if t[k] ~= nil then
                        error("Duplicate entry, the key '" .. tostring(k) .. "' already exists and cannot be overwritten" .. error_suffix(path, k), 0)
                    end
                    t[k] = v
                end
            else
                utils.copy_into(parser(result), t)
            end
        end
    end

    return t
end

return loaders
