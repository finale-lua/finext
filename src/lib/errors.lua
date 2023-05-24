local utils = require("lib.utils")

local errors = {}
local handlers = {}
local function_name_placeholder = "tryfunczzz" -- If changing this value, do a search and replace for ALL instances in this file, including function parameters

---Creates the level info that is inserted before an erroressage.
---@package
---@param info table Info from debug.getinfo which must include the flags "lS"
---@return string
local function create_level_info_string(info)
    return (info.short_src == "[C]" and info.short_src or info.short_src .. ":" .. info.currentline) .. ":"
end

---Catches any errors thrown at the level of the function call.
---@package
---@param tryfunczzz function Function to call.
---@param ... any Arguments to the function.
---@return nil Prevents tail call optimisation.
---@return any ... Any return values from the function.
local function catch_error(tryfunczzz, ...)
    return nil, tryfunczzz(...)
end

---Handles an error message.
---@package
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

    -- Get error handling options
    local opt = handlers[debug.getinfo(catch_level + 2, "f").func]

    -- Split stack trace
    do
        local istart, iend = string.find(msg, "\nstack traceback:\n", 1, true)
        if istart then
            msg_traceback = string.sub(msg, iend + 1)
            msg = string.sub(msg, istart - 1)
        elseif finenv.DebugEnabled then
            -- Remove title and first line (ie this function) from stack trace
            msg_traceback = string.gsub(debug.traceback(), "[^\n]+\n", "", 2)
        end

        -- Remove catch_error and xpcall from stack
        if msg_traceback then
            for i = catch_level, catch_level + 1 do
                local info = debug.getinfo(i, "lS")
                msg_traceback = string.gsub(msg_traceback, "\n	" .. create_level_info_string(info) .. " in " .. (info.what == "main" and "main chunk" or "function '" .. info.name .. "'"), "", 1)
            end
        end
    end

    -- Call custom rewriters
    if opt.custom then
        for _, v in ipairs(opt.custom) do
            msg = v(msg, level + 1)
            if msg == nil then
                return
            end
        end
    end

    -- Replace function name placeholder
    if opt.rename then
        if level == catch_level then
            msg = string.gsub(msg, function_name_placeholder, debug.getinfo(level + 3).name)
        end
    end

    -- Move argument numbers down by one for bad argument errors if method call
    if opt.argnum then
        if level == catch_level and errors.is_bad_argument_error(msg) then
            local argnum = tonumber(string.match(msg, "#(%d+)")) - 1
            msg = string.gsub(msg, "#%d+", "#" .. argnum, 1)
        end
    end

    -- Reassemble message
    if msg_traceback then
        msg = msg .. "\nstack traceback:\n" .. msg_traceback
    end

    -- Rethrow with new level if thrown at catch level
    return level == catch_level and {msg, opt.rethrow and 3 or 2} or {msg_level .. " " .. msg, 0}
end

---Rethrows error from xpcall if necessary or returns the results if no error.
---@param success boolean
---@param error_msg string?
---@param ... xpcall return values
---@return any ...
local function result_handler(success, error_msg, ...)
    if not success and error_msg then
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

---Creates an error handler.
---@param opt table
---@return function
-- backtrace is always added
-- rethrow (boolean)
-- argnum (boolean)
-- rename (boolean)
-- custom (function[])
function errors.create_handler(opt)
    local func = function(tryfunczzz, ...)
        return result_handler(xpcall(catch_error, message_handler, tryfunczzz, ...))
    end
    if type(opt.custom) == "function" then
        opt.custom = {opt.custom}
    end
    handlers[func] = opt
    return func
end

return errors
