return function(result, target)
    for k, v in pairs(result) do
        for kk, vv in pairs(v) do
            target[k .. "_" .. kk] = vv
        end
    end
end
