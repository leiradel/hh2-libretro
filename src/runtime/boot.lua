local hh2 = require 'hh2'

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

local function setupGame()
    local settings = require 'main'
    dump(settings)
    print(hh2.VERSION)
end

return function()
    -- Make the addition operator concatenate string
    -- Note: if both strings are convertible to numbers, the metamethod won't be called and a number addition will be performed
    getmetatable('').__add = function(str1, str2)
        return str1 .. str2
    end

    return setupGame()
end
