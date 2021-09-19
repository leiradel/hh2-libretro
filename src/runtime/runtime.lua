local meta = {}

local function augmentHh2(hh2rt)

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
                        k = k + 1
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

local function augmentUnits(hh2rt, graphics, extctrls)
    local tpictureMt = {
        __index = function(self, key)
            local props = meta[self]

            if props[key] ~= nil then
                return props[key]
            end

            error(string.format('tpicture does not have property %s', key))
        end,

        __newindex = function(self, key, value)
            local props = meta[self]
            props[key] = value
        end
    }

    graphics.tpicture = {
        create = function()
            local instance = {}
            local props = {}
            meta[instance] = props

            props.loadfromfile = function(path)
                local pixelsrc = hh2rt.readPixelSource(path:gsub('\\', '/'):gsub('/+', '/'))
                props['#image'] = hh2rt.createImage(pixelsrc)

                if props['#onload'] then
                    props['#onload']()
                end
            end

            return setmetatable(instance, tpictureMt)
        end
    }

    local timageMt = {
        __index = function(self, key)
            local props = meta[self]

            if props[key] ~= nil then
                return props[key]
            end

            error(string.format('timage does not have property %s', key))
        end,

        __newindex = function(self, key, value)
            local props = meta[self]
            props[key] = value

            if key == 'left' or key == 'top' then
                props['#sprite']:setPosition(props.left, props.top)
            elseif key == 'visible' then
                props['#sprite']:setVisibility(props.visible)
            elseif key == 'picture' then
                props['#sprite']:setImage(props.picture and props.picture['#image'])
            end
        end
    }

    local spriteLayer = 1023

    extctrls.timage = {
        create = function()
            local instance = {}
            local sprite = hh2rt.createSprite()
            sprite:setVisibility(true)
            sprite:setLayer(spriteLayer)
            spriteLayer = spriteLayer - 1

            local props = {
                left = 0,
                top = 0,
                visible = true,
                picture = graphics.tpicture.create(),

                width = 0,
                height = 0,
                transparent = true,
                center = true,
                anchors = 0,

                ['#sprite'] = sprite
            }

            meta[instance] = props

            props.picture['#onload'] = function()
                -- force the refresh of the sprite image
                instance.picture = instance.picture
            end

            return setmetatable(instance, timageMt)
        end
    }

    local ttimerMt = {
        __index = function(self, key)
            local props = meta[self]

            if props[key] ~= nil then
                return props[key]
            end

            error(string.format('ttimer does not have property %s', key))
        end,

        __newindex = function(self, key, value)
            local props = meta[self]
            props[key] = value

            if key == 'interval' then
                props['#expiration'] = hh2rt.now() + value * 1000
            elseif key == 'enabled' then
                props['#expiration'] = hh2rt.now() + props.interval * 1000
            end
        end
    }

    extctrls.ttimer = {
        create = function()
            local instance = {}

            local props = {
                interval = 0,
                enabled = false,
                ontimer = function() end,

                ['#expiration'] = 0
            }

            meta[instance] = props

            props['#tick'] = function(now)
                if props.enabled and props.ontimer and props.interval ~= 0 and now >= props['#expiration'] then
                    props['#expiration'] = now + props.interval * 1000
                    props.ontimer()
                end
            end

            hh2rt.timers[instance] = true
            return setmetatable(instance, ttimerMt)
        end
    }
end

return {
    augmentHh2 = augmentHh2,
    augmentUnits = augmentUnits
}
