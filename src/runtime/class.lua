return {
    new = function(...)
        local superClasses = {...}
        local class = {}

        -- Copy all methods from the super classes
        for i = 1, #superClasses do
            for name, method in pairs(superClasses[i]) do
                -- Do not override methods already defined
                if not class[name] then
                    class[name] = method
                end
            end
        end

        return setmetatable(class, {
            __call = function(self, ...)
                -- Create an empty instance and the method cache
                local instance = {}
                local methods = {}

                -- Create the methods in the method cache
                for name, method in pairs(class) do
                    methods[name] = function(...)
                        return method(instance, ...)
                    end
                end

                -- Set the __index metamethod to return the methods from the cache
                instance = setmetatable(instance, {
                    __index = function(self, key)
                        return methods[key]
                    end
                })

                -- Call the new method to initialize the instance
                if class.new then
                    class.new(instance, ...)
                end

                return instance
            end
        })
    end
}
