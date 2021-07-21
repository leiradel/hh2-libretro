return function(hh2)
    -- Augment hh2.log and replace print
    do
        local log = hh2.log
        hh2.log = nil

        hh2.debug = function(format, ...)
            log('d', string.format(format, ...))
        end

        hh2.info = function(format, ...)
            log('i', string.format(format, ...))
        end

        hh2.warn = function(format, ...)
            log('w', string.format(format, ...))
        end

        hh2.error = function(format, ...)
            log('e', string.format(format, ...))
        end

        print = function(...)
            local args = {...}

            for i = 1, #args do
                args[i] = tostring(args[i])
            end

            log('d', table.concat(args, '\t'))
        end
    end

    -- Register our searcher after the cache searcher
    hh2.info('registering the custom module searcher')
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
            hh2.debug('found module %s using the native searcher', modname)
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

        -- Pascal units can recursively require each other, implement a delayed load :/
        local chunk, err = load(decoded, modname, 't')

        if not chunk then
            return err
        end

        return chunk
    end

    -- Remove the other searchers
    hh2.info('removing the other searchers')
    searchers[3] = nil
    searchers[4] = nil

    -- Run boot.lua
    hh2.info('running boot.lua')
    local boot = require 'boot'
    return boot()
end
