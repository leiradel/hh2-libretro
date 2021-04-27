-- Requires
do
    local cwd = arg[0]:match('(.*)/.-')

    if cwd then
        local template_separator, substitution = package.config:match('.-\n(.-)\n(.-)\n.*')
        package.path = package.path .. template_separator .. cwd .. '/' .. substitution .. '.lua'
        package.cpath = package.cpath .. template_separator .. cwd .. '/' .. substitution .. '.so'
    end
end

local inifile = require 'inifile'
local bsenc = require 'bsenc'
local riff = require 'riff'

-- Supporting functions
local function dump(tab, indent)
    indent = indent or 0
    local spaces = string.rep('    ', indent)

    for key, value in pairs(tab) do
        io.write(string.format('%s[%q] = ', spaces, key))

        local tp = type(value)

        if tp == 'number' then
            io.write(string.format('%s,\n', tostring(value)))
        elseif tp == 'string' then
            io.write(string.format('%q,\n', value))
        else
            io.write(string.format('{\n'))
            dump(value, indent + 1)
            io.write(string.format('%s},\n', spaces))
        end
    end
end

local function parseIniFile(game, path)
    local function parse(path, skindir, skinprefix)
        local profiles = {
            dpadaction = {buttonup = true, buttondown = true, buttonleft = true, buttonright = true, buttonaction = true}
        }

        local ini = assert(io.open(path))
        local settings = {skindir = skinprefix, controls = {}, buttons = {count = 0}, assets = {}}

        for section, key, value, line in inifile.iterate(ini) do
            local Value = value
            section, key, value = section:lower(), key:lower(), value:lower()

            if section == 'hh2' then
                if key == 'controllerprofile' then
                    if settings.controls.profile then
                        error('controller profile already set: ' .. value)
                    end

                    if not profiles[value] then
                        error('unknown controller profile: ' .. value)
                    end

                    settings.controls.profile = value
                elseif key == 'backgroundimage' then
                    if settings[key] then
                        error('background image already set: ' .. value)
                    end

                    settings[key] = Value
                elseif key == 'gamearea' then
                    if settings.gamearea then
                        error('game area already set: ' .. value)
                    end

                    local x0, y0, x1, y1 = value:match('(%d+)%s*,%s*(%d+)%s*,%s*(%d+)%s*,%s*(%d+)')

                    if not x0 then
                        error('invalid gamearea: ' .. value)
                    end

                    settings.gamearea = {
                        x0 = tonumber(x0),
                        y0 = tonumber(y0),
                        x1 = tonumber(x1),
                        y1 = tonumber(y1)
                    }
                else
                    local index, property = key:match('button(%d+)(.*)')

                    if index then
                        index = tonumber(index)

                        if index < 1 then
                            error('invalid button index: ' .. index)
                        end

                        properties = settings.buttons[index] or {}
                        settings.buttons[index] = properties
                        settings.buttons.count = math.max(settings.buttons.count, index)
                        property = property:lower()

                        if property == 'label' or property == 'name' then
                            if properties[property] then
                                error('button property ' .. property .. ' for index ' .. index .. ' already set: ' .. value)
                            end

                            properties[property] = Value
                        else
                            error('unknown button property for index ' .. index .. ': ' .. property .. ' (' .. key .. ')')
                        end
                    elseif settings.controls.profile and profiles[settings.controls.profile][key] then
                        local button = key:match('button(.*)')

                        if settings.controls[button] then
                            error('button ' .. button .. ' already set: ' .. value)
                        end

                        settings.controls[button] = value
                    else
                        error('unknown setting: ' .. key)
                    end
                end
            elseif section:match('image%d+') then
                if key == 'filename' then
                    local path = string.format('%s/%s', skindir, Value):gsub('\\', '/')
                    local file = io.open(path)

                    if file then
                        file:close()

                        settings.assets[#settings.assets + 1] = {
                            path = path,
                            entry = string.format('%s/%s', skinprefix, Value):gsub('\\', '/')
                        }
                    end
                end
            end
        end

        ini:close()

        if not settings.controls.profile then
            error('controller profile not set')
        end

        if not settings.backgroundimage then
            error('background image not set')
        end

        for button in pairs(profiles[settings.controls.profile]) do
            if not settings.controls[button:match('button(.*)')] then
                error('missing button: ' .. button)
            end
        end

        for i = 1, settings.buttons.count do
            if not settings.buttons[i] then
                error('missing button properties for index: ' .. i)
            else
                if not settings.buttons[i].name then
                    error('missing button property "name" for index: ' .. i)
                elseif not settings.buttons[i].label then
                    error('missing button property "label" for index: ' .. i)
                end
            end
        end

        return settings
    end

    local inipath = (game .. '/' .. path):gsub('\\', '/')
    local ini = assert(io.open(inipath))

    for section, key, value, line in inifile.iterate(ini) do
        local Value = value
        section, key, value = section:lower(), key:lower(), value:lower()

        if section == 'hh2' then
            if key == 'skin' then
                -- Game has more than one skin, use the one selected for HH2
                ini:close()
                local inipath = string.format('%s/%s/Config.ini', game, Value):gsub('\\', '/')
                local skindir = string.format('%s/%s', game, Value):gsub('\\', '/')
                return parse(inipath, skindir, Value)
            end
        elseif section == 'common' then
            if key == 'skindir' then
                -- Found the skin directory, parse the INI file
                ini:close()
                local skindir = string.format('%s/%s', game, Value):gsub('\\', '/')
                return parse(inipath, skindir, Value)
            end
        end
    end

    error('could not find the correct Config.ini')
end

-- Args
local game = assert(arg[1], 'pass the game folder name as the first parameter')

-- Parse the INI file
local settings = parseIniFile(game, 'Config.ini')

-- Create main.lua
local main = {}

do
    local out = function(format, ...)
        local str = string.format(format, ...)
        main[#main + 1] = str
        io.write(str)
    end

    out('local unit1 = require \'unit1\'\n\n')
    out('unit1.form1.oncreate()\n\n')

    out('return {\n')
    out('    core_version = "0.0.1",\n')
    out('    unmapped_buttons = {\n')

    for i = 1, settings.buttons.count do
        local button = settings.buttons[i]
        out('        {%q, %s},\n', button.label, button.name)
    end

    out('    },\n')

    out('    mapping_profile = %q,\n', settings.controls.profile)
    out('    mapped_buttons = {\n')

    for control, name in pairs(settings.controls) do
        if control ~= 'profile' then
            out('        [%q] = %s,\n', control, name)
        end
    end

    out('    },\n')

    if settings.gamearea then
        local ga = settings.gamearea
        out('    zoom = {%d, %d, %d, %d},\n', ga.x0, ga.y0, ga.x1, ga.y1)
    end

    out('    background_image = %q\n', (settings.skindir .. '/'):gsub('\\', '/'):gsub('//', '/') .. settings.backgroundimage)
    out('}\n')

    local file = assert(io.open('main.bs', 'wb'))
    file:write(bsenc(table.concat(main, '')))
    file:close()
end

-- Create the RIFF file
do
    settings.assets[#settings.assets + 1] = {entry = 'main.bs', path = 'main.bs'}
    riff(string.format('%s.hh2', game), settings.assets)
end
