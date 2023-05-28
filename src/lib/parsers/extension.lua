local utils = require("lib.utils")
local helper = require("lib.helper")

return function(result, class_name, classes)
    local class = {ClassName = class_name}

    -- xFC-specific
    if helper.is_xfc_class_name(class_name) then
        class.Parent = helper.get_parent_class(helper.xfc_to_fc_class_name(class_name))

        if class.Parent then
            class.Parent = helper.fc_to_xfc_class_name(class.Parent)
        end

    -- xFX-specific
    else
        class.Parent = result.Parent
        class.Base = helper.is_xfc_class_name(class.Parent) and class.Parent or classes[class.Parent].Base
    end

    class.Lookup = class.Parent and utils.copy_table(classes[class.Parent].Lookup) or {Methods = {}, Properties = {}, Disabled = {}, xFCInits = {}}

    -- Copy everything over
    if result.Init then
        class.Init = result.Init
        if helper.is_xfc_class_name(class_name) then
           table.insert(class.Lookup.xFCInits, class.Init)
        end
    end

    for _, attr in ipairs({"Methods", "StaticMethods", "MetaMethods", "Properties"}) do
        class[attr] = utils.copy_table_no_meta(result[attr])
    end

    -- Add to lookup
    if class.Methods then
        utils.copy_into(class.Methods, class.Lookup.Methods)
    end

    if class.Properties then
        for k, v in pairs(class.Properties) do
            if not class.Lookup.Properties[k] then
                class.Lookup.Properties[k] = {}
            end
            utils.copy_into(v, class.Lookup.Properties[k])
        end
    end

    -- Add disabled, remove disabled methods/properties
    if result.Disabled then
        class.Disabled = utils.create_lookup(result.Disabled)
        utils.copy_into(class.Disabled, class.Lookups.Disabled)
        utils.remove_keys(class.Lookup.Methods, class.Disabled)
        utils.remove_keys(class.Lookup.Properties, class.Disabled)
    end

    if helper.is_xfx_class_name(class_name) then
        class.Lookup.xFCInits = nil
    end

    return class
end
