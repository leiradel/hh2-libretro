local hh2rt = require 'hh2rt'

return function()
    -- Initialize the game
    local main = require 'hh2main'
    main.initgame()

    -- Set the background image for the game
    local config = require 'hh2config'

    local background = hh2rt.readPixelSource(config.backgroundImage)
    local image = hh2rt.createImage(background)

    hh2rt.createCanvas(background:width(), background:height())
    image:stamp(0, 0)

    if config.mappingProfile == 'leftright' then
        config.mappedButtons.a = config.mappedButtons.right
    end

    local unit1 = require 'unit1'
    local input, previous = {}, {}

    -- Return the tick function
    return function()
        local now, _ = hh2rt.now()

        for timer in pairs(hh2rt.timers) do
            timer['#tick'](now)
        end

        input = hh2rt.getInput()

        if input.left and not previous.left then
            unit1.form1.btn_left_top.onmousedown()
        elseif not input.left and previous.left then
            unit1.form1.btn_left_top.onmouseup()
        end

        if input.start and not previous.start then
            unit1.form1.btn_game_a_top.onmousedown()
        elseif not input.start and previous.start then
            unit1.form1.btn_game_a_top.onmouseup()
        end

        input, previous = previous, input
    end
end
