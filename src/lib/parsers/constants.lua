
return function(result, dest, mod_name)
    local function assert_valid_name(name, err_name, err_path)
        if not string.match(name, "^%u+") and not string.match(name, "^%u[%u_]-%u$") then
            error("Constant " .. err_name .. " can only contain uppercase letters and underscores and cannot start or end with an underscore, '" .. tostring(name) .. "' given (" .. mod_name .. (err_path or "")  .. ")", 0)
        end
    end

    for k, v in pairs(result) do
        assert_valid_name(k, "group names")
        for kk, vv in pairs(v) do
            assert_valid_name(kk, "names", "." .. k)
            local const = k .. "_" .. kk
            if dest[const] ~= nil then
                error("A constant named '" .. const .. "' already exists and cannot be overridden (" .. mod_name .. "." .. k .. "." .. kk .. ")" , 0)
            end
            dest[const] = vv
        end
    end
end
