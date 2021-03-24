local hh2 = require 'hh2'

return {
    treginifile = {
        create = function()
            return {
                treginifile readinteger = function(arg1, key, value)
                    return hh2.loadvalue(key:lower()) or value
                end

                treginifile writeinteger = function(arg1, key, value)
                    hh2.savevalue( key:lower(), value )
                end
            }
        end
    }
}
