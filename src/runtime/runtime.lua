local hh2 = require 'hh2'
local meta, props = {}, {}

local function classId(class)
    return string.format('%s: %s', meta[class].id, tostring(class):match('table: 0x(%x+)'))
end

local function instanceId(instance)
    return string.format('%s (%s)', tostring(instance):match('table: 0x(%x+)'), classId(meta[instance]))
end

local instanceMt = {
    __index = function(self, key)
        local class = meta[self]
        hh2.debug('looking for field %q in instance %s', key, instanceId(self))

        local value = class[key]

        if value then
            hh2.debug('\tfound %s', value)

            local method = function(...)
                return value(self, ...)
            end

            rawset(self, key, method)
            return method
        end

        error(string.format('instance %s do not have field %q', instanceId(self), key))
    end,

    __newindex = function(self, key, value)
        hh2.debug('setting field %q in instance %s to %s', key, instanceId(self), value)
        rawset(self, key, value)
    end
}

local function newConstructor(class, constructor)
    hh2.info('creating constructor %s for class %s', constructor, classId(class))

    return function(...)
        local instance = {}
        meta[instance] = class
        setmetatable(instance, instanceMt)
        
        local chain = {}
        local super = class

        while super do
            chain[#chain + 1] = super
            super = meta[super].super
        end

        for i = #chain, 1, -1 do
            local super = chain[i]

            hh2.debug(
                'calling init method #%d from class %s inside constructor %s for instance %s',
                i, classId(super), constructor, instanceId(instance)
            )

            meta[super].init(instance)
        end

        hh2.info('calling constructor %s with instance %s', constructor, instanceId(instance))
        constructor(instance, ...)
        return instance
    end
end

local classMt = {
    __index = function(self, key)
        hh2.debug('looking for field %q in class %s', key, classId(self))

        if key == 'create' then
            hh2.debug('\tsynthetizing constructor for class %s', classId(self))
            local value = newConstructor(self, function(instance) end)
            rawset(self, key, value)
            return value
        end

        local super = meta[self].super

        if super then
            local value = super[key]

            if value then
                hh2.debug('\tfound %s in super class %s', value, classId(super))
                rawset(self, key, value)
                return value
            end
        end
        
        error(string.format('class %s do not have field %q', classId(self), key))
    end,

    __newindex = function(self, key, value)
        hh2.debug('setting field %q in class %s to %s', key, classId(self), value)
        rawset(self, key, value)
    end
}

return {
    newClass = function(id, super, init)
        local class = {}
        meta[class] = {id = id, super = super, init = init}

        hh2.info(
            'creating class %q as %s with super class %s and init function %s',
            id, classId(class), super and classId(super) or 'none', init
        )

        return setmetatable(class, classMt)
    end,

    newConstructor = function(class, constructor)
        return newConstructor(class,constructor)
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

        error(string.format('class do not have an inherited method %q', name))
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
    end,

    poke = hh2.poke
}
