local hh2rt = require 'hh2rt'
local controls = require 'controls'

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

    -- Configure the buttons depending on the profile
    if config.mappingProfile == 'leftright' then
        config.mappedButtons.a = config.mappedButtons.right
    elseif config.mappingProfile == 'dpadaction' then
        config.mappedButtons.b = config.mappedButtons.action
    else
        hh2rt.warn('unknown mapping profile: %s', config.mappingProfile)
    end

    -- Return the tick function
    local unit1 = require 'unit1'
    local input, previous = {}, {}

    return function()
        local now, _ = hh2rt.now()

        for timer in pairs(hh2rt.timers) do
            timer['#tick'](now)
        end

        input = hh2rt.getInput()

        for name, button in pairs(config.mappedButtons) do
            if input[name] and not previous[name] then
                button.onmousedown(nil, controls.mbleft, nil, input.mouseX, input.mouseY)
            elseif not input[name] and previous[name] then
                button.onmouseup(nil, controls.mbleft, nil, input.mouseX, input.mouseY)
            end
        end

        if input.start and not previous.start then
            unit1.form1.btn_game_a_top.onmousedown(nil, controls.mbleft, nil, input.mouseX, input.mouseY)
        elseif not input.start and previous.start then
            unit1.form1.btn_game_a_top.onmouseup(nil, controls.mbleft, nil, input.mouseX, input.mouseY)
        end

        input, previous = previous, input
    end
end
