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

        -- Pascal units can recursively require each other, implement a delayed load :/
        local chunk, err = load(decoded, modname, 't')

        if not chunk then
            return err
        end

        return function()
            local function delayedLoad(module)
                local contents = chunk()

                for k, v in pairs(contents) do
                    rawset(module, k, v)
                end
            end

            return setmetatable({}, {
                __index = function(self, key)
                    delayedLoad(self)
                    setmetatable(self, nil)
                    return rawget(self, key)
                end,

                __newindex = function(self, key, value)
                    delayedLoad(self)
                    setmetatable(self, nil)
                    rawset(self, key, value)
                end
            })
        end
    end

    -- Remove the other searchers
    searchers[3] = nil
    searchers[4] = nil

    -- Run boot.lua
    local boot = require 'boot'
    return boot.main()
end
