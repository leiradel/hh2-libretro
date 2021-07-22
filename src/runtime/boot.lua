local hh2rt = require 'hh2rt'

return function()
    local main = require 'hh2main'
    main.initgame()

    local config = require 'hh2config'

    local background = hh2rt.readPixelSource(config.background_image)
    local image = hh2rt.createImage(background)

    hh2rt.createCanvas(background:width(), background:height())

    image:stamp(0, 0)
end
