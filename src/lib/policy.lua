local utils = require("lib.utils")
local helper = require("lib.helper")
local policy = {}

local extension_metamethods = utils.create_lookup({
    "__tostring",
})

local reserved_instance = {
    ExtClassName = function(class)
        return class.ClassName
    end,
    ExtParent = function(class)
        return class.Parent
    end,
    ExtBase = function(class)
        return classes.Base
    end,
}

local reserved_static = {
    __parent = function(class)
        return class.Parent
    end,
    __base = function(class)
        return class.Base
    end,
    __init = function(class)
        return class.Init
    end,
    __class = function(class)
        return helper.create_reflection(class, "Methods")
    end,
    __static = function(class)
        return helper.create_reflection(class, "StaticMethods")
    end,
    __propget = function(class)
        return helper.create_property_reflection(class, "Get")
    end,
    __propset = function(class)
        return helper.create_property_reflection(class, "Set")
    end,
    __disabled = function(class)
        return helper.create_reflection(class, "Disabled")
    end,
    __metamethods = function(class)
        return create_reflection(class, "MetaMethods")
    end,
}

---Returns a list of reserved instance properties for extensions.
---@return {[string]: function} Each getter function accepts one argument, the extensions class.
function policy.get_reserved_instance()
    return utils.copy_table(reserved_instance)
end


---Returns a list of reserved static properties for extensions.
---@return {[string]: function} Each getter function accepts one argument, the extensions class.
function policy.get_reserved_static()
    return utils.copy_table(reserved_static)
end

---Determines if a property name is valid.
---@param name string
---@return boolean
---@return string? If not valid, this will contain an error message.
function policy.is_valid_property_name(name)
    if type(name) ~= "string" then
        return false, "Extension method and property names must be strings"
    elseif name:match("^Ext%u") then
        return false, "Extension methods and properties cannot begin with 'Ext'"
    elseif name == "__" or reserved_instance[name] or reserved_static[name] then
        return false, "'" .. name .. "' is a reserved name and cannot be used for properties or methods"
    end

    return true
end

---Checks if a metamethod is allowed in extensions
---@param method_name string
---@return boolean
function policy.is_allowed_metamethod(method_name)
    return extension_metamethods[method_name] and true or false
end

return policy
