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
            elseif key == 'backgroundimage' or key == 'author' then
                if settings[key] then
                    error(string.format('%s already set: %s', key, value))
                end

                settings[key] = Value
            elseif key == 'gamescreen1' or key == 'gamescreen2' then
                if settings[key] then
                    error(string.format('%s already set: %s', key, value))
                end

                local x0, y0, x1, y1 = value:match('(%d+)%s*,%s*(%d+)%s*,%s*(%d+)%s*,%s*(%d+)')

                if not x0 then
                    error(string.format('invalid %s: %s', key, value))
                end

                settings[key] = {
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
            local asset = settings.assets[section] or {}
            settings.assets[section] = asset

            if key == 'filename' then
                local path = string.format('%s/%s', skindir, Value):gsub('\\', '/')
                local file = io.open(path)

                if file then
                    file:close()

                    asset.path = path
                    asset.entry = string.format('%s/%s', skinprefix, Value):gsub('\\', '/')
                end
            else
                asset[key] = Value
            end
        end
    end

    ini:close()

    if not settings.controls.profile then
        error('controller profile not set')
    end

    if not settings.gamescreen1 then
        error('gamescreen1 not set')
    end

    if not settings.backgroundimage then
        error('background image not set')
    end

    if not settings.author then
        settings.author = ''
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

local function genSettings(settings)
    local out = function(format, ...)
        local str = string.format(format, ...)
        io.write(str)
    end

    out('local unit1 = require \'unit1\'\n\n')
    out('return {\n')
    out('    coreVersion = "0.0.1",\n')
    out('    unmappedMuttons = {\n')

    for i = 1, settings.buttons.count do
        local button = settings.buttons[i]
        out('        {%q, %s},\n', button.label, button.name)
    end

    out('    },\n')

    out('    mappingProfile = %q,\n', settings.controls.profile)
    out('    mappedButtons = {\n')

    do
        local ordered = {}

        for control, name in pairs(settings.controls) do
            if control ~= 'profile' then
                ordered[#ordered + 1] = {control = control, name = name}
            end
        end

        table.sort(ordered, function(a, b) return a.control < b.control end)

        for _, rec in ipairs(ordered) do
            out('        [%q] = %s,\n', rec.control, rec.name)
        end
    end

    out('    },\n')

    if not settings.gamescreen2 then
        local ga = settings.gamescreen1
        out('    zoom = {%d, %d, %d, %d},\n', ga.x0, ga.y0, ga.x1, ga.y1)
    end

    out('    backgroundImage = %q\n', (settings.skindir .. '/'):gsub('\\', '/'):gsub('//', '/') .. settings.backgroundimage)
    out('}\n')
end

local function genGfxInit(settings, skinpath)
    local out = function(format, ...)
        local str = string.format(format, ...)
        io.write(str)
    end

    local assets = {}

    for section, asset in pairs(settings.assets) do
        asset.index = tonumber(section:match('.-(%d+)'))
        assets[#assets + 1] = asset
    end

    table.sort(assets, function(a, b) return a.index < b.index end)

    for _, asset in ipairs(assets) do
        if asset.entry then
            out('    aImages[%d].Picture.LoadFromFile(\'%s\');\n', asset.index, asset.entry)
        end

        if asset.top then
            out('    aImages[%d].Top := %s;\n', asset.index, asset.top);
        end

        if asset.left then
            out('    aImages[%d].Left := %s;\n', asset.index, asset.left);
        end
        
        if asset.width then
            out('    aImages[%d].Width := %s;\n', asset.index, asset.width);
        end

        if asset.height then
            out('    aImages[%d].Height := %s;\n', asset.index, asset.height);
        end
    end
end

local function genMakefile(settings, gamepath, soundpath, skinpath)
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

        table.sort(list, function(a, b) return a < b end)

        if #list ~= 0 then
            for i = 1, #list - 1 do
                out('\t%s \\\n', list[i])
            end

            out('\t%s\n\n', list[#list])
        end
    end

    out('%%.lua: %%.pas\n')
    out('\t@echo "Transpiling to Lua: $@"\n')
    out('\t@$(LUA) "$(ETC)/pas2lua.lua" "-I$(UNITS)" -I. -DHH2 "$<" > "$@"\n\n')

    out('%%.bs: %%.lua.gz\n')
    out('\t@echo "Encrypting $@"\n')
    out('\t@$(ETC)/aesenc "r%%!^g3rGEeSUtJKcUo%%6rcrGTX3GoXv!" "$<" "$@"\n\n')

    out('%%.lua.gz: %%.lua\n')
    out('\t@echo "Compressing $@"\n')
    out('\t@$(LUA) -e "local s=`wc -c \'$<\' | sed \'s/ .*//\'` io.write(string.char(s&255,(s>>8)&255,(s>>16)&255,(s>>24)&255))" > "$@"\n')
    out('\t@cat "$<" | gzip -c9n >> "$@"\n\n')

    out('LUA ?= \\\n')
    out('\tLUA_PATH="$(LUAMODS)/access/src/?.lua;$(LUAMODS)/inifile/src/?.lua;$(ETC)/?.lua" \\\n')
    out('\tLUA_CPATH="$(LUAMODS)/proxyud/src/?.so;$(LUAMODS)/ddlt/?.so" \\\n')
    out('\tlua\n\n')

    out('BS_FILES = \\\n')
    out('\thh2config.bs \\\n')
    out('\thh2dfm.bs \\\n')
    out('\thh2main.bs \\\n')
    out('\tunit1.bs\n\n')

    out('WAV_FILES = \\\n')
    outlist(soundpath, function(name)
        if name:match('.*%.wav$') then
            return name:gsub(gamepath .. '/', '')
        end
    end)

    out('IMG_FILES = \\\n')
    local images = {}

    for _, asset in pairs(settings.assets) do
        images[#images + 1] = asset.path
    end

    table.sort(images, function(a, b) return a < b end)

    for i, path in ipairs(images) do
        out('\t%s', path:gsub(gamepath .. '/', ''):gsub('\\', '/'):gsub('/+', '/'))

        if i < #images then
            out(' \\\n')
        end
    end

    out('\n\n')

    out('HH2_FILES = $(BS_FILES) $(WAV_FILES) $(IMG_FILES)\n\n')

    out('all: %s.hh2\n\n', gamepath)

    out('%s.hh2: $(HH2_FILES)\n', gamepath)
    out('\t@echo "Packaging $@"\n')
    out('\t@$(LUA) "$(ETC)/riff.lua" "$@" $+\n\n')

    out('clean:\n')
    out('\t@echo "Cleaning up"\n')
    out('\t@rm -f %s.hh2 $(BS_FILES)\n', gamepath)
end

if #arg ~= 2 then
    print(string.format('Usage: lua %s (--settings | --gfxinit | --makefile) <game folder>', arg[0]))
    exit(1)
end

-- Find the INI file
local inipath, skinpath, skinprefix = findIniFile(arg[2], 'Config.ini')

-- Parse the INI file
local settings = parseIniFile(inipath, skinpath, skinprefix)

if arg[1] == '--settings' then
    genSettings(settings)
elseif arg[1] == '--gfxinit' then
    genGfxInit(settings, skinpath)
elseif arg[1] == '--makefile' then
    genMakefile(settings, arg[2], arg[2] .. '/Sound', skinpath)
else
    io.stderr:write(string.format('Error: unknown option %s', arg[1]))
    os.exit(1)
end
