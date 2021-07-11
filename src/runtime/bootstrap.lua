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
        local ok, encoded = pcall(hh2.contentLoader, modname .. '.bs')

        if not ok then
            return encoded
        end

        local ok, decoded = pcall(hh2.bsDecoder, encoded)

        if not ok then
            return decoded
        end

        local chunk, err = load(decoded, modname, 't')
        return chunk or err
    end

    -- Remove the other searchers
    searchers[3] = nil
    searchers[4] = nil

    -- Run boot.lua
    local boot = require 'boot'
    return boot()
end
