local utils = require("lib.utils")

return function(result, dest, mod_name)
    for k, v in pairs(result) do
        if dest[k] ~= nil then
            error("Utils key '" .. tostring(k) .. "' already exists and cannot be overwritten (" .. mod_name .. "." .. tostring(k) .. ")", 0)
        end
        dest[utils.copy_table(k)] = utils.copy_table(v)
    end
end
