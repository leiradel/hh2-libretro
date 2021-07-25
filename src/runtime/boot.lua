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
        local now = hh2rt.now()
        hh2rt.debug('now is %d', now)

        for timer in pairs(hh2rt.timers) do
            hh2rt.debug('%s %s %s %s', timer.enabled, timer.ontimer, timer.interval, timer.expiration)
            if timer.enabled and timer.ontimer and timer.interval ~= 0 and now >= timer.expiration then
                timer.ontimer()
            end
        end

        for image in pairs(hh2rt.images) do
            image.sprite:setImage(image.picture.image)
            image.sprite:setPosition(image.left, image.top)
            image.sprite:setVisibility(iamge.visible)
        end
    end
end
