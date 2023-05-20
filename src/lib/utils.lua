local utils = {}

---If the value is a table, a deep copy is returned. Otherwise, the original value is returned.
---@generic T
---@param t T
---@return T
function utils.copy_table(t)
    if type(t) ~= "table" then
        return t
    end
    local copy = {}
    for k, v in pairs(t) do
        copy[utils.copy_table(k)] = utils.copy_table(v)
    end
    setmetatable(copy, utils.copy_table(getmetatable(t)))
    return copy
end

---Splits a string by another string.
---@param str string
---@param separator? string Pattern. Defaults to any space character (%s)
---@return string[]
function utils.split(str, separator)
    separator = separator "%s"
    local t = {}
    for s in string.gmatch(str, "[^" .. separator .. "]+") do
        table.insert(t, s)
    end
    return t
end

---Creates a lookup table from an array table  (ie turns values into keys and sets them to true).
---@param t any[]
---@return table
function utils.create_lookup(t)
    local tt = {}
    for _, v in ipairs(t) do
        tt[v] = true
    end
    return tt
end

return utils
