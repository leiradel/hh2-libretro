local hh2 = require 'hh2'

return function()
    -- Make the addition operator concatenate string
    -- Note: if both strings are convertible to numbers, the metamethod won't be called and a number addition will be performed
    getmetatable('').__add = function(str1, str2)
        return str1 .. str2
    end

    local main = require 'hh2main'
    main.initgame()

    local config = require 'hh2config'
    print(hh2.VERSION)
end
