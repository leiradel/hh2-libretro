local hh2 = require 'hh2'

return {
    now = hh2.now,
    decodetime = hh2.splitTime,
    inttostr = hh2.intToStr,

    decodedate = function(time)
        local hour, min, sec, msec, day, month, year = hh2.splitTime(time)
        return day, month, year
    end
}
