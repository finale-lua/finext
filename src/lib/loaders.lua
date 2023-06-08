local helper = require("lib.helper")
local errors = require("lib.errors")
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

local function is_valid_extension_key(key)
    if helper.is_xfx_class_name(key) or (helper.is_xfc_class_name(key) and finale[helper.xfc_to_fc_class_name(key)]) then
        return true
    end

    return false
end
    
function loaders.create_extension_loader(paths, default_getter, parser, validator, exclude_external_files)
    return setmetatable({}, {
        __index = function(t, k)
            if not is_valid_extension_key(k) then
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

            if result == nil and helper.is_xfc_class_name(k) then
                result = {}
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
