return function(hh2)
    -- Register our searcher after the cache searcher
    local searchers = package.searchers

    searchers[2] = function(modname)
        -- See if it's the hh2 module
        if modname == 'hh2' then
            return function()
                return hh2
            end
        end

        -- Try the native searcher
        local module = hh2.nativeSearcher(modname)

        if type(module) == 'function' then
            return module
        end

        -- Try to load content from the hh2 file
        local content, err = pcall(hh2.contentLoader, modname .. '.bs')

        if not content then
            return err
        end

        local code = hh2.bsDecoder(content)
        local chunk, err = load(code, modname, 't')
        return chunk or err
    end

    -- Creates the global 'uses' function
    uses = function(unitname)
        local unit = require(unitname)

        -- Register the unit contents in the globals table
        for key, value in pairs(unit) do
            _G[key] = value
        end
    end
end
