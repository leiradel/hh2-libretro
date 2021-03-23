return function(options)
    local searchers = package.searchers

    for i = #searchers, 2, -1 do
        searchers[i + 2] = searchers[i]
    end

    searchers[2] = options.nativeSeacher

    searchers[3] = function(modname)
    end
end
