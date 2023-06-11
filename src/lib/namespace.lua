local utils = require("lib.utils")
local helper = require("lib.helper")
local policy = require("lib.policy")
local errors = require("lib.errors")

local reserved_instance = policy.get_reserved_instance()
local reserved_static = policy.get_reserved_static()

return function(classes, constants)
    -- Public methods and extension constructors, stored separately to keep the finext namespace read-only.
    local public = {}

    -- Fully resolved class definitions, for optimised run-time lookups
    local lookups = setmetatable({}, {
        __index = function(t, k)
            local lookup = classes[k].Parent and utils.copy_table_no_meta(t[classes[k].Parent]) or {Disabled = {}, Methods = {}, Properties = {}, xFCInits = {}}

            for _, attr in ipairs({"Disabled", "Methods", "Properties"}) do
                if classes[k][attr] then
                    utils.copy_into(classes[k][attr], lookup[attr])
                end
            end

            if classes[k].Disabled then
                utils.remove_keys(lookup.Methods, classes[k].Disabled)
                utils.remove_keys(lookup.Properties, classes[k].Disabled)
            end

            if helper.is_xfx_class_name(k) then
                lookup.xFCInits = nil
            elseif classes[k].Init then
                table.insert(lookup.xFCInits, classes[k].Init)
            end

            t[k] = lookup
            return lookup
        end,
    })

    -- Extension class metatables
    local metatables

    -- Extensions and the objects they're connected to
    local extension_objects = setmetatable({}, {__mode = "k"})
    local object_extensions = setmetatable({}, {
        __mode = "kv",
        __index = function(t, object)
            local class_name = helper.fc_to_xfc_class_name(helper.get_class_name(object))
            local extension = setmetatable({}, metatables[class_name])
            rawset(t, object, extension)
            extension_objects[extension] = object
            for _, v in ipairs(lookups[class_name].xFCInits) do
                v(extension)
            end
            return extension
        end,
    })

    -- Handles the fluid interface
    local function fluid_proxy(t, ...)
        -- If no return values, then apply the fluid interface
        if select("#", ...) == 0 then
            return t
        end
        return ...
    end

    -- Wraps all passed Finale objects in extensions
    local function wrap_proxy(...)
        local t
        for i = 1, #t do
            if helper.is_finale_object(t[i]) then
                t = t or table.pack(...)
                t[i] = object_extensions(t[i])
            end
        end
        return t and table.unpack(t) or ...
    end

    local function error_rewriter_fc(msg, level)
        if not errors.is_bad_argument_msg(msg) then
            return msg
        end

        msg = string.gsub(msg, "FC", "xFC")
        if string.match(msg, " userdata ") then
            local info = debug.getinfo(level, "u")
            local num = errors.get_bad_argument_number(msg)
            if info.nparams < num then
                num = num - info.nparams
                num = num * -1
            end
            local value = debug.getlocal(level, num)
            if helper.is_finale_object(value) then
                string.gsub(msg, " userdata ", helper.fc_to_xfc_class_name(helper.get_class_name(value)))
            end
        end
        return msg
    end

    local handle_fluid_proxy = errors.create_handler({
        rethrow = true,
        rename = true,
        argnum = true,
    })

    local handle_fc_fluid_proxy = errors.create_handler({
        rethrow = true,
        rename = true,
        argnum = true,
        rewriters = error_rewriter_fc,
    })

    -- Unwraps all passed extensions
    local function unwrap_proxy(...)
        local t
        for i = 1, #t do
            if extension_objects[t[i]] then
                t = t or table.pack(...)
                t[i] = extension_objects[t[i]]
            end
        end
        return t and table.unpack(t) or ...
    end

    -- Returns a function that handles the fluid interface and error re-throwing
    local function create_fluid_proxy(func)
        return function(t, ...)
            return fluid_proxy(t, handle_fluid_proxy(func, t, ...))
        end
    end

    local function create_fluid_fc_proxy(func)
        return function(t, ...)
            return fluid_proxy(t, wrap_proxy(handle_fc_fluid_proxy(func, unwrap_proxy(t, ...))))
        end
    end

    metatables = setmetatable({}, {
        __index = function(mts, class_name)
            if not classes[class_name] then
                return nil
            end

            local metatable = {}
            metatable.__index = function(t, k)
                -- Special property for accessing the underlying object
                if k == "__" then
                    return extension_objects[t]
                -- Methods
                elseif lookups[class_name].Methods[k] then
                    return create_fluid_proxy(lookups[class_name].Methods[k])
                -- Properties
                elseif lookups[class_name].Properties[k] then
                    return lookups[class_name].Properties.Get(t)
                -- Reserved properties
                elseif reserved_instance[k] then
                    return reserved_instance[k](classes[class_name])
                -- All extension and PDK keys are strings
                elseif type(k) ~= "string" then
                    return nil
                end

                -- Original object
                local prop = extension_objects[t][k]
                if type(prop) == "function" then
                    prop = create_fluid_fc_proxy(prop)
                end
                return prop
            end

            metatable.__newindex = function(t, k, v)
                -- If it's disabled or reserved, throw an error
                if lookups[class_name].Disabled[k] or (type(k) == " string" and not helper.is_valid_property_name[k]) then
                    error("No writable member '" .. tostring(k) .. "'", 2)
                end

                -- If a property descriptor exists, use the setter if it has one
                -- Otherwise, use the original property (this prevents a read-only property from being overwritten by a custom property)
                if lookups[class_name].Properties[k] then
                    if lookups[class_name].Properties[k].Set then
                        return lookups[class_name].Properties[k].Set(t, v)
                    else
                        -- @TODO test this, find some other way of capturing the error
                        return errors.rethrow(function(tt, kk, vv) extension_objects[tt][kk] = vv end, t, k, v)
                    end
                end

                -- If it's not a string key, it has to be a custom property
                if type(k) ~= "string" then
                    rawset(t, k, v)
                    return
                end

                local type_v_original = type(extension_objects[t][k])
                local type_v = type(v)
                local is_ext_method = lookups[class_name].Methods[k] and true or false

                -- If it's a method or property that doesn't exist on the original object, store it
                if type_v_original == "nil" then

                    if is_ext_method and not (type_v == "function" or type_v == "nil") then
                        error("An extension method cannot be overridden with a property.", 2)
                    end

                    rawset(t, k, v)
                    return

                -- If it's a method, we can override it but only with another method
                elseif type_v_original == "function" then
                    if not (type_v == "function" or type_v == "nil") then
                        error("A Finale PDK Framework method cannot be overridden with a property.", 2)
                    end

                    rawset(t, k, v)
                    return
                end

                -- Otherwise, try and store it on the original property. If it's read-only, it will fail and we show the error
                -- @TODO test this, find some other way of capturing the error
                return errors.rethrow(function(tt, kk, vv) extension_objects[tt][kk] = vv end, t, k, v)
            end

            -- Collect any defined metamethods
            local parent = class_name
            while parent do
                if classes[parent].MetaMethods then
                    for k, v in pairs(classes[parent].MetaMethods) do
                        if not metatable[k] then
                            metatable[k] = v
                        end
                    end
                end
                parent = classes[parent].Parent
            end

            rawset(mts, class_name, metatable)
            return metatable
        end,
    })

    local function subclass(extension, class_name, func_name)
        func_name = func_name or "subclass"

        if not extension_objects[extension] then
            error("bad argument #1 to '" .. func_name .. "' (__xFCBase expected, " .. type(extension) .. " given)", 2)
        end

        if not helper.is_xfx_class_name(class_name) then
            error("bad argument #2 to '".. func_name .. "' (xFX class name expected, " .. tostring(class_name) .. " given)", 2)
        end

        if extension.ExtClassName == class_name then
            return extension
        end

        if not classes[class_name] then
            error("Extension class '" .. class_name .. "' not found.", 2)
        end

        local parents = {}
        local current = class_name
        while true do
            table.insert(parents, 1, current)
            current = classes[current].Parent
            if current == extension.ExtClassName then
                break
            elseif helper.is_xfc_class_name(current) then
                error("Extension class '" .. class_name .. "' is not a subclass of '" .. extension.ExtClassName .. "'", 2)
            end
        end

        for _, parent in ipairs(parents) do
            -- Change class metatable
            setmetatable(extension, metatables[parent])

            -- Remove any newly disabled methods or properties
            if classes[parent].Disabled then
                for k, _ in pairs(classes[parent].Disabled) do
                    rawset(extension, k, nil)
                end
            end

            -- Run initialiser, if there is one
            if classes[parent].Init then
                errors.rethrow(classes[parent].Init, extension)
            end
        end

        return extension
    end

    local method_name
    local function error_rewriter_bridge(msg, level)
        if method_name then
            msg = string.gsub(msg, errors.function_name_placeholder(), method_name)
        end
        return msg
    end

    local handle_bridge_function = errors.create_handler({
        rethrow = true,
    })

    local handle_bridge_method = errors.create_handler({
        rethrow = true,
        rewriters = {error_rewriter_bridge, error_rewriter_fc},
    })

--[[
% __

Bridging function between extensions and raw finale objects.

@ func (function) A function to call.
@ ... (any) Arguments to the function. Any extensions will be replaced with their underlying objects.
[any] Returned values from the function. Any returned Finale objects will be wrapped in extensions.
]]

--[[
% __

Bridging function between extensions and raw finale objects.

@ object (__FCBase | __xFCBase) Either a Finale object or an extension (which will be unwrapped for the method call).
@ method (string) The name of the method. It must be a method of the passed Finale object or the passed extension's underlying Finale object.
@ ... (any) Arguments to the function. Any extensions will be replaced with their underlying objects.
[any] Returned values from the method. Any returned Finale objects will be wrapped in extensions.
]]
    function public.__(a, b, ...)
        if extension_objects[a] then
            a = extension_objects[a]
        end
        local handler = handle_bridge_function

        if library.is_finale_object(a) then
            if type(a[b]) ~= "function" then
                error("'" .. tostring(b) .. "' is not a method of argument #1.", 2)
            end
            method_name = b
            b = a[b]
            b, a = a, b
            handler = handle_bridge_method
        end

        if type(a) ~= "function" then
            error("bad argument #1 to '__' (function or __xFCBase or __FCBase expected, " .. type(a) .. " given)", 2)
        end

        return wrap_proxy(handler(a, unwrap_proxy(b, ...)))
    end

--[[
% UI

Returns an extension-wrapped UI object from `finenv.UI`

: (xFCUI)
]]
    function public.UI()
        return object_extensions[finenv.UI()]
    end

    local namespace = {}
    namespace.namespace = setmetatable({}, {
        __newindex = function(t, k, v) end,
        __index = function(t, k)
            if not public[k] then
                if not classes[k] then
                    return nil
                end
                local metatable = {
                    __newindex = function(tt, kk, vv) end,
                    __index = function(tt, kk)
                        return (lookups[k].Methods[kk] and create_fluid_proxy(lookups[k].Methods[kk]))
                        or classes[k].StaticMethods[kk]
                        or (lookups[k].Properties[kk] and utils.copy_table(lookups[k].Properties[kk]))
                        or (reserved_static[kk] and reserved_static[kk](classes[k])) -- reserved_props handles calls to copy_table itself if needed
                        or nil
                    end,
                }
                -- @TODO Check that FC is callable...
                if helper.is_xfc_class_name(class_name) then
                    metatable.__call = function(tt, ...)
                        return object_extensions(errors.rethrow(finale[helper.xfc_to_fc_class_name(k)], ...))
                    end
                else
                    metatable.__call = function(tt, ...)
                        local extension = errors.rethrow(t[classes[k].Base], ...)
                        if not extension then return nil end
                        return subclass(extension, k)
                    end
                end
                public[k] = setmetatable({}, metatable)
            end
            return public[k]
        end,
        __call = function(t, object, class_name)
            if helper.is_finale_object(object) then
                if rawget(object_extensions, object) then
                    error("Object has already been extended.", 2)
                end
                local extension = object_extensions[object]
                if class_name then
                    return subclass(extension, class_name, 'finext')
                else
                    return extension
                end
            elseif extension_objects[object] then
                return subclass(object, class_name, 'finext')
            end
            error("bad argument #1 to 'finext' (__FCBase or __xFCBase expected, " .. type(object) .. " given)", 2)
        end,
    })

    function namespace.is_extension(value)
        return extension_objects[value] and true or false
    end

    return namespace
end
