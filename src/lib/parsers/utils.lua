return function(result, target)
    for k, v in pairs(result) do
        target[k] = v
    end
end
