return function(hh2rt)
    -- Augment hh2rt.log and replace print
    do
        local log = hh2rt.log
        hh2rt.log = nil

        hh2rt.debug = function(format, ...)
            log('d', string.format(format, ...))
        end

        hh2rt.info = function(format, ...)
            log('i', string.format(format, ...))
        end

        hh2rt.warn = function(format, ...)
            log('w', string.format(format, ...))
        end

        hh2rt.error = function(format, ...)
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
    hh2rt.info('registering the custom module searcher')
    local searchers = package.searchers

    searchers[2] = function(modname)
        -- See if it's the hh2rt module
        if modname == 'hh2rt' then
            return function()
                return hh2rt
            end
        end

        -- Try the native searcher
        local module = hh2rt.nativeSearcher(modname)

        if type(module) == 'function' then
            hh2rt.debug('found module %s using the native searcher', modname)
            return module
        end

        -- Try to load content from the hh2rt file
        local ok, encoded = pcall(hh2rt.contentLoader, modname .. '.bs')

        if not ok then
            return encoded
        end

        local ok, decoded = pcall(hh2rt.bsDecoder, encoded)

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
    hh2rt.info('removing the other searchers')
    searchers[3] = nil
    searchers[4] = nil

    -- Augment the module for the Pascal runtime
    do
        local runtime = require 'runtime'
        runtime(hh2rt)
    end

    -- Run boot.lua
    hh2rt.info('running boot.lua')
    local boot = require 'boot'
    return boot()
end
