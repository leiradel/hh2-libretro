return function(hh2rt)
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
            setVisibility = function(self, visibility)
                for i = 1, #self do
                    self[i]:setVisibility(visibility)
                end
            end
        }

        for i = 1, #text do
            local char = text:sub(i, i)

            if char ~= ' ' then
                local image = (boxybold[char] or boxybold['?'])
                local sprite = hh2rt.createSprite()

                sprite:setVisibility(true)
                sprite:setLayer(2050)
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

    local white75 = hh2rt.createImage(hh2rt.getPixelSource('white75'))
    local joypad = hh2rt.createImage(hh2rt.getPixelSource('joypad'))

    local joypadPoints = {
        up     = {ox =  84, oy =  59, anchor = 'center-center'},
        down   = {ox =  84, oy = 114, anchor = 'center-center'},
        left   = {ox =  55, oy =  87, anchor = 'center-right'},
        right  = {ox = 112, oy =  87, anchor = 'center-left'},
        a      = {ox = 345, oy =  88, anchor = 'center-left'},
        b      = {ox = 314, oy = 117, anchor = 'center-center'},
        x      = {ox = 314, oy =  59, anchor = 'center-center'},
        y      = {ox = 284, oy =  88, anchor = 'center-right'},
        l1     = {ox =  84, oy =  11, anchor = 'center-left'},
        r1     = {ox = 316, oy =  11, anchor = 'center-left'},
        select = {ox = 170, oy =  56, anchor = 'center-right'},
        start  = {ox = 230, oy =  56, anchor = 'center-left'}
    }

    local joypadFunctions = {
        leftright = {
            left = 'Left',
            right = 'Right',
            a = 'Right'
        }
    }

    hh2rt.joypadHelp = function(width, height)
        local config = require 'hh2config'

        local sprites = {
            setVisibility = function(self, visibility)
                for i = 1, #self do
                    self[i]:setVisibility(visibility)
                end
            end
        }

        for y = 0, height, white75:height() do
            for x = 0, width, white75:width() do
                local sprite = hh2rt.createSprite()
                sprite:setPosition(x, y)
                sprite:setLayer(2048)
                sprite:setImage(white75)
                sprite:setVisibility(true)

                sprites[#sprites + 1] = sprite
            end
        end

        local x0, y0 = (width - joypad:width()) // 2, (height - joypad:height()) // 2
        local sprite = hh2rt.createSprite()
        sprite:setPosition(x0, y0)
        sprite:setLayer(2049)
        sprite:setImage(joypad)
        sprite:setVisibility(true)
        sprites[#sprites + 1] = sprite

        for id, _ in pairs(config.mappedButtons) do
            local functions = joypadFunctions[config.mappingProfile]
            local point = joypadPoints[id]
            local sprite = hh2rt.text(x0 + point.ox, y0 + point.oy, point.anchor, functions[id])
            sprites[#sprites + 1] = sprite
        end

        return sprites
    end
end
