local hh2 = require 'hh2'

return {
    tfont = {
        new = function()
            return {}
        end,
    },

    tpicture = hh2.newPicture,
    default_charset = 0,
    clwhite = 0xffffffff,
    clfuchsia = 0xffff00ff,
    clwindowtext = 0xff000000
}
