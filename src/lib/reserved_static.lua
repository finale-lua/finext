local utils = require("lib.utils")
local helper = require("lib.helper")
local reserved_static = {}

function reserved_static.__parent(class)
    return class.Parent
end

function reserved_static.__base(class)
    return class.Base
end

function reserved_static.__init(class)
    return class.Init
end

function reserved_static.__class(class)
    return class.Methods and utils.copy_table(class.Methods) or {}
end

function reserved_static.__static(class)
    return class.StaticMethods and utils.copy_table(class.StaticMethods) or {}
end
  
function reserved_static.__propget(class)
    return helper.create_getter_reflection(class)
end

function reserved_static.__propset(class)
    return helper.create_setter_reflection(class)
end

function reserved_static.__disabled(class)
    return class.Disabled and utils.copy_table(class.Disabled) or {}
end

function reserved_static.__metamethods(class)
    return class.MetaMethods and utils.copy_table(class.MetaMethods) or {}
end

return reserved_static
