local function extendHh2rt(hh2rt)
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

            local value = class[key]

            if value then
                local method = function(...)
                    return value(self, ...)
                end

                rawset(self, key, method)
                return method
            end

            error(string.format('instance %s do not have field %q', instanceId(self), key))
        end,

        __newindex = function(self, key, value)
            rawset(self, key, value)
        end
    }

    local function newConstructor(class, constructor)
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
                meta[super].init(instance)
            end

            constructor(instance, ...)
            return instance
        end
    end

    local classMt = {
        __index = function(self, key)
            if key == 'create' then
                local value = newConstructor(self, function(instance) end)
                rawset(self, key, value)
                return value
            end

            local super = meta[self].super

            if super then
                local value = super[key]

                if value then
                    rawset(self, key, value)
                    return value
                end
            end
            
            error(string.format('class %s do not have field %q', classId(self), key))
        end,

        __newindex = function(self, key, value)
            rawset(self, key, value)
        end
    }

    hh2rt.newClass = function(id, super, init)
        if super then
            hh2rt.debug('creating class %s with super %s', id, meta[super].id)
        else
            hh2rt.debug('creating class %s', id)
        end

        local class = {}
        meta[class] = {id = id, super = super, init = init}
        return setmetatable(class, classMt)
    end

    hh2rt.newConstructor = function(class, constructor)
        return newConstructor(class, constructor)
    end

    hh2rt.callInherited = function(name, instance, ...)
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
    end

    hh2rt.newEnum = function(elements)
        local enum = {}
        meta[enum] = elements
        return enum
    end

    hh2rt.newSet = function(enum)
        local set = {}
        meta[set] = meta[enum]
        return set
    end

    hh2rt.instantiateSet = function(elements)
        local instance = {}
        meta[instance] = elements
        return instance
    end

    hh2rt.newArray = function(dimensions, default, value)
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
    end

    hh2rt.newRecord = function()
        return {}
    end
end

local function extendExtctrls(extctrls, hh2rt)
    extctrls.timage = {
        create = function()
            local instance = {}
            local info = {}

            instance.picture = {
                loadfromfile = function(path)
                    hh2rt.debug('%q loading %q', tostring(instance), path)
                    local pixelsrc = hh2rt.readPixelSource(path)
                    local image = hh2rt.createImage(pixelsrc)
                    info.sprite:setImage(image)
                end
            }

            info.sprite = hh2rt.createSprite()
            info.top = 0
            info.left = 0

            setmetatable(instance, {
                __index = function(self, key)
                    hh2rt.debug('%q reading %q', tostring(self), key)
                    return info[key]
                end,

                __newindex = function(self, key, value)
                    hh2rt.debug('%q setting %q to %q', tostring(self), key, tostring(value))

                    info[key] = value

                    if key == 'top' or key == 'left' then
                        info.sprite:setPosition(info.left, info.top)
                    end
                end
            })

            return instance
        end
    }
end

return {
    extendHh2rt = extendHh2rt,
    extendExtctrls = extendExtctrls
}
