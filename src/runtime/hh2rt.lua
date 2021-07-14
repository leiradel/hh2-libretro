local meta = {}

local classMt = {
    __index = function(self, key)
        local super = meta[self].super

        if super then
            local method = super[key]

            if method then
                rawset(self, key, method)
                return method
            end
        end
    end
}

local instanceMt = {
    __index = function(self, key)
        local class = meta[self]
        local value = class[key]

        if value then
            local method = function(...)
                return value(self, ...)
            end

            rawset(self, key, method)
            return method
        end
    end
}

return {
    newClass = function(id, super, init)
        if type(super) == 'function' then error('super is a function') end
        local class = {}
        meta[class] = {id = id, super = super, init = init}
        return setmetatable(class, classMt)
    end,

    newConstructor = function(class, constructor)
        return function(...)
            local instance = {}
            meta[instance] = class
            setmetatable(instance, instanceMt)
            
            local super = class

            while super do
                local init = meta[super].init

                if init then
                    init(instance)
                end

                super = meta[super].super
            end

            constructor(instance, ...)
            return instance
        end
    end,

    callInherited = function(name, instance, ...)
        local class = meta[instance]
        local super = meta[class].super

        while super do
            local method = super[name]

            if method then
                return method(instance, ...)
            end

            super = meta[super].super
        end

        error('class do not have an inherited method %s', name)
    end,

    newEnum = function(elements)
        local enum = {}
        meta[enum] = elements
        return enum
    end,

    newSet = function(enum)
        local set = {}
        meta[set] = meta[enum]
        return set
    end,

    instantiateSet = function(elements)
        local instance = {}
        meta[instance] = elements
        return instance
    end,

    newArray = function(dimensions, default, value)
        local function init(array, dimensions, default, value, i)
            local min = dimensions[i][1]
            local max = dimensions[i][2]

            if i < #dimensions then
                if value then
                    local k = 1

                    for j = min, max do
                        array[j] = {}
                        init(array[j], dimensions, default, value[k], i + 1)
                    end
                else
                    for j = min, max do
                        array[j] = {}
                        init(array[j], dimensions, default, nil, i + 1)
                    end
                end
            else
                if value then
                    local k = 1

                    for j = min, max do
                        array[j] = value[k]
                        k = k + 1
                    end
                else
                    for j = min, max do
                        array[j] = default
                    end
                end
            end
        end

        local array = {}
        init(array, dimensions, default, value, 1)
        return array
    end,

    newRecord = function()
        return {}
    end
}
