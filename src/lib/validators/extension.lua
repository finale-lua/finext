local utils = require("lib.utils")
local errors = require("lib.errors")
local helper = require("lib.helper")

local function find_collision(class, check, skip, props)
    for _, v in ipairs(check) do
        if not skip[k] then
            for kk, _ in ipairs(props) do
                if class[v] and class[v][kk] then
                    return v, kk
                end
            end
        end
    end
end

local find_finale_name_clash
find_finale_name_clash = function(class_name, attrs, props)
    local clash_attr, clash_name = find_collision(finale[class_name], {"__class", "__static", "__propget", "__propset"}, attrs, props)
    if clash_attr then
        return class_name, clash_attr, clash_name
    end

    local parent = helper.get_parent_class(class_name)
    if parent then
        return find_finale_name_clash(parent, attrs, props)
    end
end

return function(result, class_name, classes)
    if type(result) ~= "table" then
        return false, errors.bad_value_msg("Extension classes", "table", type(result))
    end

    -- Check top level types
    for attr, attr_type in pairs({
        Init = "function",
        Parent = "string",
        Methods = "table",
        StaticMethods = "table",
        Properties = "table",
        MetaMethods = "table",
        Disabled = "table",
    }) do
        if result[attr] ~= nil and type(result[attr]) ~= attr_type then
            return false, errors.bad_value_msg("Extension class attribute '" .. attr .. "'", attr_type, type(class[attr])), attr
        end
    end

    local dummy = {class_name}

    -- Check parent if xFX
    if helper.is_xfx_class_name(class_name) then
        if not result.Parent then
            return false, "xFX* extensions must declare their parent class", "Parent"
        end

        if not helper.is_xfc_class_name(result.Parent) and not helper.is_xfx_class_name(result.Parent) then
            return false, "Extension parent must be an xFC or xFX class name, '" .. result.Parent .. "' given", "Parent"
        end

        if not classes[result.Parent] then
            return false, "Unable to load extension '" .. class.Parent .. "' as parent of '" .. class_name .. "'", "Parent"
        end

        dummy.Parent = result.Parent
        dummy.Base = classes[dummy.Parent].Base or dummy.Parent
    else
        dummy.Parent = helper.get_parent_class(helper.xfc_to_fc_class_name(class_name))

        if dummy.Parent then
            dummy.Parent = helper.fc_to_xfc_class_name(dummy.Parent)
        end
    end

    -- Check disabled and build lookup table
    dummy.Disabled = {}
    if result.Disabled then
        for _, v in ipairs(result.Disabled) do
            local is_valid, err = policy.is_valid_property_name(v)
            if not is_valid then
                return false, err, "Disabled." .. tostring(v)
            end
            dummy.Disabled[v] = true
        end
    end

    -- Check valid property names and values
    dummy.Methods = result.Methods
    dummy.StaticMethods = result.StaticMethods
    dummy.Properties = result.Properties

    local finale_class = helper.fc_to_xfc_class_name(dummy.Base or class_name)
    for attr, finale_attr in pairs({
        Methods = utils.create_lookup({"__class"}),
        StaticMethods = utils.create_lookup({"__static"}),
        Properties = utils.create_lookup({"__propget", "__propset"}),
    }) do
        if result[attr] then
            for k, _ in pairs(result[attr]) do
                local is_valid, err = policy.is_valid_property_name(k)
                if not is_valid then
                    return false, err, attr .. "." .. tostring(k)
                end
            end

            local cl = dummy
            while cl do
                for k, _ in pairs(result[attr]) do
                    if cl.Disabled[k] then
                        return false, "'" .. k .. "' is a disabled name and cannot be used for properties or methods", attr .. "." .. k
                    end
                end
                local clash_class, clash_attr, clash_name = find_clash(cl, {"Methods", "StaticMethods", "Properties"}, {[attr] = true}, result[attr])
                if clash_class then
                    return false, "Extension method/property name clash (" .. table.concat({class_name, attr, clash_name}, ".") .. " & " .. table.concat({clash_class, clash_attr, clash_name}, ".") .. ")"
                end
                cl = classes[cl.Parent]
            end

            local clash_class, clash_attr, clash_name = find_finale_name_clash(finale_class, finale_attr, result[attr])
            if clash_class then
                return false, "Extension method/property name clash with Finale class (" .. table.concat({class_name, attr, clash_name}, ".") .. " & " .. table.concat({clash_class, clash_attr, clash_name}, ".") .. ")"
            end
        end
    end

    if result.MetaMethods then
        for k, _ in pairs(result.MetaMethods) do
            if not policy.is_allowed_metamethod(k) then
                return false, "Forbidden extension MetaMethod '" .. tostring(k) .. "'", "MetaMethods." .. tostring(k)
            end
        end
    end

    -- Check attribute values
    for attr, value_type in pairs({
        Methods = "function",
        StaticMethods = "function",
        MetaMethods = "function",
        Properties = "table",
    }) do
        if result[attr] then
            for k, v in pairs(result[attr]) do
                if type(v) ~= value_type then
                    return false, errors.bad_value_msg("Extension " .. attr, value_type, type(v)), attr .. "." .. tostring(k)
                end
            end
        end
    end

    -- Check property descriptors
    if result.Properties then
        for k, v in pairs(result.Properties) do
            if not v.Get and not v.Set then
                return false, "Extension property descriptors must at least one 'Set' or 'Get' method", "Properties." .. k
            end

            for kk, vv in pairs(v) do
                if kk ~= "Set" and kk ~= "Get" then
                    return false, "Extension property descriptors can only contain 'Get' or 'Set' attributes", "Properties." .. k .. "." .. tostring(kk)
                end
                if type(vv) ~= "function" then
                    return false, errors.bad_value_msg("Extension property descriptor attribute '" .. kk .. "'", "function", type(vv)), "Properties." .. k .. "." .. kk
                end
            end
        end
    end

    return true
end
