local hh2rt = require 'hh2rt'

return function()
    -- Initialize the game
    local main = require 'hh2main'
    main.initgame()

    -- Set the background image for the game
    local config = require 'hh2config'

    local background = hh2rt.readPixelSource(config.background_image)
    local image = hh2rt.createImage(background)

    hh2rt.createCanvas(background:width(), background:height())
    image:stamp(0, 0)

    -- Return the tick function
    return function()
        local now, _ = hh2rt.now()

        for timer in pairs(hh2rt.timers) do
            timer['#tick'](now)
        end
    end
end
