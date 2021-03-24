uses 'fmodtypes'

return {
    fsound_sample_free = function()
    end,

    fsound_close = function()
    end,

    fsound_playsound = function(channel, pfs)
        system.playsound(pfs, channel)
    end,

    fsound_stopsound = function(channel)
    end,

    fsound_setsfxmastervolume = function(vol)
    end
}
