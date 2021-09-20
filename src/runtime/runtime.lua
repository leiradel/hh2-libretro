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

    local boxybold = {}

    do
        local font = hh2rt.getPixelSource('boxybold')

        boxybold['!'] = font:sub(2, 0, 8, 16)
        boxybold['"'] = font:sub(12, 0, 14, 10)
        boxybold['#'] = font:sub(28, 0, 18, 16)
        boxybold['$'] = font:sub(48, 0, 14, 16)
        boxybold['%'] = font:sub(64, 0, 20, 16)
        boxybold['&'] = font:sub(86, 0, 18, 16)
        boxybold['\''] = font:sub(106, 0, 8, 10)
        boxybold['('] = font:sub(116, 0, 10, 16)
        boxybold[')'] = font:sub(128, 0, 10, 16)
        boxybold['*'] = font:sub(140, 0, 12, 14)
        boxybold['+'] = font:sub(154, 0, 16, 16)
        boxybold[','] = font:sub(172, 0, 10, 16)
        boxybold['-'] = font:sub(184, 0, 12, 12)
        boxybold['.'] = font:sub(198, 0, 8, 16)
        boxybold['/'] = font:sub(208, 0, 12, 16)

        boxybold['0'] = font:sub(2, 18, 14, 16)
        boxybold['1'] = font:sub(18, 18, 8, 16)
        boxybold['2'] = font:sub(28, 18, 14, 16)
        boxybold['3'] = font:sub(44, 18, 14, 16)
        boxybold['4'] = font:sub(60, 18, 14, 16)
        boxybold['5'] = font:sub(76, 18, 14, 16)
        boxybold['6'] = font:sub(92, 18, 14, 16)
        boxybold['7'] = font:sub(108, 18, 14, 16)
        boxybold['8'] = font:sub(124, 18, 14, 16)
        boxybold['9'] = font:sub(140, 18, 14, 16)

        boxybold[':'] = font:sub(2, 36, 8, 16)
        boxybold[';'] = font:sub(12, 36, 8, 16)
        boxybold['<'] = font:sub(22, 36, 12, 16)
        boxybold['='] = font:sub(36, 36, 12, 14)
        boxybold['>'] = font:sub(50, 36, 12, 16)
        boxybold['?'] = font:sub(64, 36, 16, 16)
        boxybold['@'] = font:sub(82, 36, 16, 16)

        boxybold['A'] = font:sub(2, 54, 14, 16)
        boxybold['B'] = font:sub(18, 54, 14, 16)
        boxybold['C'] = font:sub(34, 54, 14, 16)
        boxybold['D'] = font:sub(50, 54, 14, 16)
        boxybold['E'] = font:sub(66, 54, 14, 16)
        boxybold['F'] = font:sub(82, 54, 14, 16)
        boxybold['G'] = font:sub(98, 54, 14, 16)
        boxybold['H'] = font:sub(114, 54, 14, 16)
        boxybold['I'] = font:sub(130, 54, 8, 16)
        boxybold['J'] = font:sub(140, 54, 14, 16)
        boxybold['K'] = font:sub(156, 54, 14, 16)
        boxybold['L'] = font:sub(172, 54, 14, 16)
        boxybold['M'] = font:sub(188, 54, 18, 16)

        boxybold['N'] = font:sub(2, 72, 16, 16)
        boxybold['O'] = font:sub(20, 72, 14, 16)
        boxybold['P'] = font:sub(36, 72, 14, 16)
        boxybold['Q'] = font:sub(52, 72, 16, 16)
        boxybold['R'] = font:sub(70, 72, 14, 16)
        boxybold['S'] = font:sub(86, 72, 14, 16)
        boxybold['T'] = font:sub(102, 72, 16, 16)
        boxybold['U'] = font:sub(120, 72, 14, 16)
        boxybold['V'] = font:sub(136, 72, 14, 16)
        boxybold['W'] = font:sub(152, 72, 18, 16)
        boxybold['X'] = font:sub(172, 72, 14, 16)
        boxybold['Y'] = font:sub(188, 72, 16, 16)
        boxybold['Z'] = font:sub(206, 72, 14, 16)

        boxybold['['] = font:sub(2, 90, 10, 16)
        boxybold['\\'] = font:sub(14, 90, 12, 16)
        boxybold[']'] = font:sub(28, 90, 10, 16)
        boxybold['^'] = font:sub(40, 90, 16, 12)
        boxybold['_'] = font:sub(58, 90, 12, 16)
        boxybold['`'] = font:sub(72, 90, 10, 12)
        boxybold['{'] = font:sub(84, 90, 10, 16)
        boxybold['|'] = font:sub(96, 90, 8, 16)
        boxybold['}'] = font:sub(106, 90, 10, 16)
        boxybold['~'] = font:sub(118, 90, 18, 10)

        boxybold['a'] = font:sub(2, 112, 14, 16)
        boxybold['b'] = font:sub(18, 112, 14, 16)
        boxybold['c'] = font:sub(34, 112, 12, 16)
        boxybold['d'] = font:sub(48, 112, 14, 16)
        boxybold['e'] = font:sub(64, 112, 14, 16)
        boxybold['f'] = font:sub(80, 112, 12, 16)
        boxybold['g'] = font:sub(94, 112, 14, 18)
        boxybold['h'] = font:sub(110, 112, 14, 16)
        boxybold['i'] = font:sub(126, 112, 10, 16)
        boxybold['j'] = font:sub(138, 112, 12, 18)
        boxybold['k'] = font:sub(152, 112, 14, 16)
        boxybold['l'] = font:sub(168, 112, 10, 16)
        boxybold['m'] = font:sub(180, 112, 18, 16)
        boxybold['n'] = font:sub(200, 112, 14, 16)

        boxybold['o'] = font:sub(2, 130, 14, 16)
        boxybold['p'] = font:sub(18, 130, 14, 18)
        boxybold['q'] = font:sub(34, 130, 14, 18)
        boxybold['r'] = font:sub(50, 130, 14, 16)
        boxybold['s'] = font:sub(66, 130, 14, 16)
        boxybold['t'] = font:sub(82, 130, 12, 16)
        boxybold['u'] = font:sub(96, 130, 14, 16)
        boxybold['v'] = font:sub(112, 130, 14, 16)
        boxybold['w'] = font:sub(128, 130, 18, 16)
        boxybold['x'] = font:sub(148, 130, 14, 16)
        boxybold['y'] = font:sub(164, 130, 14, 18)
        boxybold['z'] = font:sub(180, 130, 14, 16)

        for char, pixelsrc in pairs(boxybold) do
            boxybold[char] = hh2rt.createImage(pixelsrc)
        end
    end

    hh2rt.text = function(x, y, anchor, format, ...)
        local text = string.format(format, ...)
        local width = 0

        for i = 1, #text do
            local char = text:sub(i, i)

            if char ~= ' ' then
                local image = (boxybold[char] or boxybold['?'])
                width = width + image:width()
            else
                width = width + 5
            end
        end

        if anchor:find('left', 1, true) then
            -- nothing
        elseif anchor:find('right', 1, true) then
            x = x - width
        else -- center
            x = x - width // 2
        end

        if anchor:find('top', 1, true) then
            -- nothing
        elseif anchor:find('bottom', 1, true) then
            y = y - 18
        else -- center
            y = y - 9
        end

        local sprites = {
            hide = function(self)
                for i = 1, #self do
                    self[i]:setVisibility(false)
                end
            end
        }

        for i = 1, #text do
            local char = text:sub(i, i)

            if char ~= ' ' then
                local image = (boxybold[char] or boxybold['?'])
                local sprite = hh2rt.createSprite()

                sprite:setVisibility(true)
                sprite:setLayer(2048)
                sprite:setImage(image)
                sprite:setPosition(x, y)
                x = x + image:width()

                sprites[#sprites + 1] = sprite
            else
                x = x + 5
            end
        end

        return sprites
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
