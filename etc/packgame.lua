local inifile = require 'inifile'
local ddlt = require 'ddlt'

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

local function findIniFile(game, path)
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
                return inipath, skindir, Value
            end
        elseif section == 'common' then
            if key == 'skindir' then
                -- Found the skin directory
                ini:close()
                local skindir = string.format('%s/%s', game, Value):gsub('\\', '/')
                return inipath, skindir, Value
            end
        end
    end

    error('could not find the correct Config.ini')
end

local function parseIniFile(path, skindir, skinprefix)
    local profiles = {
        dpadaction = {buttonup = true, buttondown = true, buttonleft = true, buttonright = true, buttonaction = true},
        leftright = {buttonleft = true, buttonright = true}
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

-- Create main.lua
local function genMain(settings)
    local out = function(format, ...)
        local str = string.format(format, ...)
        io.write(str)
    end

    out('local unit1 = require \'unit1\'\n')
    out('local dfm = require \'dfm\'\n\n')
    out('unit1.form1.oncreate()\n')
    out('dfm.inittform1(unit1.form1)\n')

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
end

local function genMakefile(gamepath, soundpath, skinpath)
    local out = function(format, ...)
        local str = string.format(format, ...)
        io.write(str)
    end

    local outlist = function(path, predicate)
        local list = {}

        for _, file in ipairs(ddlt.scandir(path)) do
            local name = predicate(file)

            if name then
                list[#list + 1] = name
            end
        end

        if #list ~= 0 then
            for i = 1, #list - 1 do
                out('\t%s \\\n', list[i])
            end

            out('\t%s\n\n', list[#list])
        end
    end

    out('%%.lua: %%.pas\n\t$(LUA) ../etc/pas2lua.lua -I../src/runtime/units -DHH2 "$<" > "$@"\n\n')
    out('%%.bs: %%.lua\n\t$(LUA) ../etc/bsenc.lua "$<" "$@"\n\n')

    out('LUA ?= \\\n')
    out('\tLUA_PATH="/home/leiradel/Develop/luamods/access/src/?.lua;/home/leiradel/Develop/luamods/inifile/src/?.lua;../etc/?.lua" \\\n')
    out('\tLUA_CPATH="/home/leiradel/Develop/luamods/proxyud/src/?.so;/home/leiradel/Develop/luamods/ddlt/?.so" \\\n')
    out('\tlua\n\n')

    out('RIFF = $(LUA) ../../etc/riff.lua\n\n')

    out('BS_FILES = \\\n')
    out('\t%s/main.bs \\\n\t%s/dfm.bs \\\n\t%s/unit1.bs\n\n', gamepath, gamepath, gamepath)
    --[[outlist(gamepath, function(name)
        if name:match('.*%.pas$') then
            return name:gsub('%.pas', '.bs')
        end
    end)]]

    out('WAV_FILES = \\\n')
    outlist(soundpath, function(name)
        if name:match('.*%.wav$') then
            return name
        end
    end)

    out('IMG_FILES = \\\n')
    outlist(skinpath, function(name)
        if name:match('.*%.png$') or name:match('.*%.jpg$') then
            return name
        end
    end)

    --[[out('DFM_FILES = \\\n')
    outlist(gamepath, function(name)
        if name:match('.*%.pas$') then
            local dfm = name:gsub('%.pas$', '.txt')

            if ddlt.stat(dfm) then
                return dfm
            end
        end
    end)]]

    out('INI_FILE = \\\n\t%s/Config.ini\n\n', skinpath)
    out('HH2_FILES = $(BS_FILES) $(WAV_FILES) $(IMG_FILES) $(INI_FILE)\n\n')
    out('all: %s.hh2\n\n', gamepath)
    out('%s.hh2: $(HH2_FILES)\n\tcd %s && $(RIFF) "../$@" $(subst %s/,,$+)\n\n', gamepath, gamepath, gamepath)
    out('clean:\n\trm -f %s.hh2 $(BS_FILES)\n', gamepath)
end

if #arg ~= 2 then
    print(string.format('Usage: lua %s (--main | --makefile) <game folder>', arg[0]))
    exit(1)
end

-- Find the INI file
local inipath, skinpath, skinprefix = findIniFile(arg[2], 'Config.ini')

-- Parse the INI file
local settings = parseIniFile(inipath, skinpath, skinprefix)

if arg[1] == '--main' then
    -- Generate main.lua
    genMain(settings)
elseif arg[1] == '--makefile' then
    genMakefile(arg[2], arg[2] .. '/Sound', skinpath)
else
    io.stderr:write(string.format('Error: unknown option %s', arg[1]))
    os.exit(1)
end
