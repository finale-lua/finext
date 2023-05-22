local utils = require("lib.utils")
local errors = {}

local rewriters = {}
local function_name_placeholder = "tryfunczzz"

---Replaces the function name placeholder with the function name from the level above the call to rethrow*
---@param msg string
---@param level number
---@param catch_level number
---@return string
function rewriters.rename(msg, level, catch_level)
    if level ~= catch_level then
        return msg
    end

    return string.gsub(msg, function_name_placeholder, debug.getinfo(level + 3).name)
end

---Shifts argument number in bad argument errors down by one if it was a method call.
---@param msg string
---@param level number
---@param catch_level number
---@return string
function rewriters.argnum(msg, level, catch_level)
    if level ~= catch_level or not errors.is_bad_argument_error(msg) or debug.getinfo(level + 3, "n").namewhat ~= "method" then
        return msg
    end

    -- Shift argument number down by one for method (colon) calls
    local argnum = tonumber(string.match(msg, "#(%d+)")) - 1
    return string.gsub(msg, "#%d+", "#" .. argnum, 1)
end

---Calls any custom rewriters.
---@param msg string
---@param level number
---@param catch_level number
---@return string
function rewriters.custom(msg, level, catch_level)
    local funcs = debug.getlocal(catch_level + 2, 1)
    if not funcs then
        return
    end

    if type(funcs) == "function" then
        funcs = {funcs}
    end

    for _, v in ipairs(funcs) do
        msg = v(msg, level == 0 and level or level + 1, catch_level)
    end

    return msg
end

---Creates the level info that is inserted before an erroressage.
---@param info table Info from debug.getinfo which must include the flags "lS"
---@return string
local function create_level_info_string(info)
    return (info.short_src == "[C]" and info.short_src or info.short_src .. ":" .. info.currentline) .. ":"
end

---Catches any errors thrown at the level of the function call.
---@param tryfunczzz function Function to call.
---@param ... any Arguments to the function.
---@return nil Prevents tail call optimisation.
---@return any ... Any return values from the function.
local function catch_error(tryfunczzz, ...)
    return nil, tryfunczzz(...)
end

---Handles an error message.
---@param original_msg string
---@return {string, number} The rewritten error message and the level to throw it at.
local function message_handler(original_msg)
    local msg_level
    local msg
    local msg_traceback
    local level
    local catch_level

    -- Determine level
    local i = 2
    while not level or not catch_level do
        local info = debug.getinfo(i, "flS")
        if not info then
            msg = original_msg
            level = 0
            break
        end

        if info.func == catch_error then
            catch_level = i
        end

        local level_str = create_level_info_string(info)
    
        if string.sub(original_msg, 1, string.len(level_str)) == level_str then
            msg_level = level_str
            msg = string.sub(original_msg, string.len(level_str) + 2) -- +2 to skip space in between level info and message
            level = i
        end

        i = i + 1
    end

    -- Split stack trace
    if finenv.DebugEnabled then
        local istart, iend = string.find(msg, "\nstack traceback:\n", 1, true)
        if istart then
            msg_traceback = string.sub(msg, iend + 1)
            msg = string.sub(msg, istart - 1)
        else
            -- Remove title and first line (ie this function) from stack trace
            msg_traceback = string.gsub(debug.traceback(), "[^\n]+\n", "", 2)
        end

        -- Remove capture and xpcall from stack
        for i = catch_level, catch_level + 1 do
            local info = debug.getinfo(i, "lS")
            msg_traceback = string.gsub(msg_traceback, "\n	" .. create_level_info_string(info) .. " in " .. (info.what == "main" and "main chunk" or "function '" .. info.name .. "'"), "", 1)
        end
    end

    -- Call any rewriters
    if level == catch_level then
        local level_rewriters = utils.create_lookup(utils.split(debug.getinfo(catch_level + 2, "n").name, "_"))
        -- Call order: custom rewriters must come first.
        -- rethrow is omitted since that is handled by this function (and all errors are rethrown)
        for _, v in ipairs({"custom", "rename", "argnum"}) do
            if level_rewriters[v] then
                msg = rewriters[v](msg, level and level + 1 or level, level == catch_level)
            end
        end
    end

    -- Reassemble message
    if finenv.DebugEnabled then
        msg = msg .. "\nstack traceback:\n" .. msg_traceback
    end

    -- Rethrow with new level if thrown at catch level
    return level == catch_level and {msg, 3} or {msg_level .. " " .. msg, 0}
end

---Rethrows error from xpcall if necessary or returns the results if no error.
---@param success boolean
---@param error_msg string?
---@param ... xpcall return values
---@return any ...
local function result_handler(success, error_msg, ...)
    if not success then
        error(table.unpack(error_msg))
    end

    return ...
end

---Returns the function name placeholder for use in error messages.
---@return string
function errors.function_name_placeholder()
    return function_name_placeholder
end

---Determines if an error is bad argument error.
---@param msg string
---@return boolean
function errors.is_bad_argument_error(msg)
    return string.match(msg, "^bad argument #%d+ to '") and true or false
end

-- Using method names shifts as much processing as possible to the error message handler
---Rethrow any errors from a function at the next level.
---@param tryfunczzz function The function to call.
---@param ... any Argumenta to pass to the function.
---@return any ... Any returned values from the funxtion.
for _, v in ipairs({"rethrow", "rethrow_rename_argnum"}) do
    errors[v] = function (tryfunczzz, ...)
        return result_handler(xpcall(catch_error, message_handler, tryfunczzz, ...))
    end
end

---Rethrow any errors from a function at the next level.
---@param custom_rewriters function|function[] Custom error message rewriters.
---@param tryfunczzz function The function to call.
---@param ... any Argumenta to pass to the function.
---@return any ... Any returned values from the funxtion.
for _, v in ipairs({"rethrow_custom", "rethrow_custom_rename_argnum"}) do
    errors[v] = function(custom_rewriters, tryfunczzz, ...)
        return result_handler(xpcall(catch_error, message_handler, tryfunczzz, ...))
    end
end

return errors
