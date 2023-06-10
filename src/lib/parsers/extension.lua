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

    -- Copy everything over
    for _, attr in ipairs({"Init", "Methods", "StaticMethods", "MetaMethods", "Properties"}) do
        class[attr] = utils.copy_table_no_meta(result[attr])
    end

    -- Add disabled
    if result.Disabled then
        class.Disabled = utils.create_lookup(result.Disabled)
    end

    return class
end
