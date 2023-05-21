local helper = {}

---Determines if a string is an FC* class name.
---@param class_name string
---@return boolean
function helper.is_fc_class_name(class_name)
    return type(class_name) == "string" and (class_name:match("^FC[A-Z][a-zA-Z]+$") or class_name:match("^__FC[A-Z][a-zA-Z]+$")) and true or false
end

---Determines if a string is an xFC* class name.
---@param class_name string
---@return boolean
function helper.is_xfc_class_name(class_name)
    return type(class_name) == "string" and (class_name:match("^xFC[A-Z][a-zA-Z]+$") or class_name:match("^__xFC[A-Z][a-zA-Z]+$")) and true or false
end

---Determines if a string is an xFX* class name.
---@param class_name string
---@return boolean
function helper.is_xfx_class_name(class_name)
    return type(class_name) == "string" and class_name:match("^xFX[A-Z][a-zA-Z]+$") and true or false
end

---Converts an FC* class name to an xFC* class name.
---@param class_name string
---@return string
function helper.fc_to_xfc_class_name(class_name)
    return string.gsub(class_name, "FC", "xFC", 1)
end

---Converts an xFC* class name to an FC* class name.
---@param class_name string
---@return string
function helper.xfc_to_fc_class_name(class_name)
    return string.gsub(class_name, "xFC", "FC", 1)
end

---Determines if a value is a Finale object.
---@param value any
---@retirn boolean
function helper.is_finale_object(value)
    return type(value) == "userdata" and value.GetClassID and true or false
end

---Finds the parent of an FC* class.
---@param class_name string
---@return string?
function helper.get_parent_class(class_name)
    local class = finale[class_name]
    if type(class) ~= "table" then return nil end
    if not finenv.IsRGPLua then -- old jw lua
        local classt = class.__class
        if classt and class_name ~= "__FCBase" then
            local classtp = classt.__parent -- this line crashes Finale (in jw lua 0.54) if "__parent" doesn't exist, so we excluded "__FCBase" above, the only class without a parent
            if classtp and type(classtp) == "table" then
                for k, v in pairs(finale) do
                    if type(v) == "table" then
                        if v.__class and v.__class == classtp then
                            return tostring(k)
                        end
                    end
                end
            end
        end
    else
        for k, _ in pairs(class.__parent) do
            return tostring(k)  -- in RGP Lua the v is just a dummy value, and the key is the class_name of the parent
        end
    end
    return nil
end

---Returns the real class name of a Finale object. Handles any incorrectly named classes from the PDK Framework.
---@param object userdata
---@return string
function helper.get_class_name(object)
    local class_name = object:ClassName()

    if class_name == "__FCCollection" and object.ExecuteModal then
        return object.RegisterHandleCommand and "FCCustomLuaWindow" or "FCCustomWindow"
    elseif class_name == "FCControl" then
        if object.GetCheck then
            return "FCCtrlCheckbox"
        elseif object.GetThumbPosition then
            return "FCCtrlSlider"
        elseif object.AddPage then
            return "FCCtrlSwitcher"
        else
            return "FCCtrlButton"
        end
    elseif class_name == "FCCtrlButton" and object.GetThumbPosition then
        return "FCCtrlSlider"
    end

    return class_name
end

return helper
