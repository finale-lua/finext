local utils = require("lib.utils")
local errors = require("lib.errors")
local helper = require("lib.helper")

local function find_collision(class, attrs, props)
    for _, v in ipairs(attrs) do
        for _, vv in ipairs(props) do
            if class[v] and class[v][vv] then
                return v, vv
            end
        end
    end
end

local find_finale_name_clash
find_finale_name_clash = function(class_name, attrs, props)
    local clash_attr, clash_name = find_collision(finale[class_name], attrs, props)
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

    local parent

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

        parent = result.Parent
    else
        parent = helper.get_parent_class(helper.xfc_to_fc_class_name(class_name))

        if parent then
            parent = helper.fc_to_xfc_class_name(parent)
        end
    end

    -- Check disabled and build lookup table
    local disabled = {}
    if result.Disabled then
        for _, v in ipairs(result.Disabled) do
            local is_valid, err = policy.is_valid_property_name(v)
            if not is_valid then
                return false, err, "Disabled." .. tostring(v)
            end
            disabled[v] = true
        end
    end

    -- Check valid property names and values
    for _, attr in pairs({"Methods", "StaticMethods", "Properties"}) do
        if result[attr] then
            for k, _ in pairs(result[attr]) do
                local is_valid = true
                local err
                is_valid, err = policy.is_valid_property_name(k)
                if is_valid then
                    if disabled[k] or (parent and classes[parent].Lookup.Disabled[k]) then
                        is_valid = false
                        err = "'" .. k .. "' is a disabled name and cannot be used for properties or methods"
                    end
                end
                if not is_valid then
                    return false, err, attr .. "." .. tostring(k)
                end
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

    -- Check method/property name collisions throughout class heirarchy
    local find_extension_name_clash
    find_extension_name_clash = function(class, class_name, parent, prop_types, prop)
        local prop_clash = find_collision(class, prop_types, prop)
        if prop_clash then
            return class_name, prop_clash
        end

        if parent then
            return find_extension_name_clash(classes[parent], parent, classes[parent].Parent, prop_types, prop)
        end
    end

    local ext_attr = utils.create_lookup({"Methods", "StaticMethods", "Properties"})
    local fin_attr = utils.create_lookup({"__class", "__static", "__propget", "__propset"})
    local fin_class = helper.is_xfc_class_name(class_name) and class_name or (classes[parent].Base or parent)
    fin_class = helper.xfc_to_fc_class_name(fin_class)

    for k, v in pairs({
        Methods = {"__class"},
        StaticMethods = {"__static"},
        Properties = {"__propget", "__propset"},
    }) do
        if result[k] then
            local ext_attr_test = utils.copy_table_no_meta(ext_attr)
            local fin_attr_test = utils.copy_table_no_meta(fin_attr)

            ext_attr_test[k] = nil
            for _, vv in ipairs(v) do
                fin_attr_test[vv] = nil
            end

            ext_attr_test = utils.table_keys(ext_attr_test)
            fin_attr_test = utils.table_keys(fin_attr_test)
            local test_props = utils.table_keys(result[k])

            local clash_class, clash_attr, clash_name = find_extension_name_clash(result, class_name, parent, ext_attr_test, test_props)
            if not clash_class then
                clash_class, clash_attr, clash_name = find_finale_name_clash(fin_class, fin_attr_test, test_props)
            end
            if clash_class then
                return false, "Extension method/property name clash (" .. table.concat({class_name, k, clash_name}, ".") .. "&" .. table.concat({clash_class, clash_attr, clash_name}, ".") .. ")"
            end
        end
    end

    return true
end
