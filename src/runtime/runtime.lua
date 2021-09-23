local meta = {}

return function(hh2rt, graphics, extctrls)
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
