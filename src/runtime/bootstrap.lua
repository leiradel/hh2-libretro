return function(hh2)
    -- Register the native searcher for native modules and Lua modules embedded in C code
    local searchers = package.searchers

    for i = #searchers, 2, -1 do
        searchers[i + 2] = searchers[i]
    end

    searchers[2] = hh2.nativeSearcher

    -- Register a searcher that loads BS data from the HH2 file
    local contentLoader = hh2.contentLoader
    local bsDecoder = hh2.bsDecoder

    searchers[3] = function(modname)
        local content, err = pcall(contentLoader, modname .. '.bs')

        if not content then
            return err
        end

        local code = bsDecoder(content)
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
