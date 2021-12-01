local hh2rt = require 'hh2rt'
local controls = require 'controls'

return function()
    -- Initialize the game
    local main = require 'hh2main'
    main.initgame()

    -- Set the background image for the game
    local config = require 'hh2config'

    local background = hh2rt.createImage(hh2rt.readPixelSource(config.backgroundImage))
    hh2rt.createCanvas(background:width(), background:height())
    background:stamp(0, 0)

    -- Configure the buttons depending on the profile
    if config.mappingProfile == 'dpadaction' then
        config.mappedButtons.b = config.mappedButtons.action
    elseif config.mappingProfile == 'dpadtwoactions' then
        config.mappedButtons.b = config.mappedButtons.action1
        config.mappedButtons.a = config.mappedButtons.action2
    elseif config.mappingProfile == 'leftright' then
        config.mappedButtons.a = config.mappedButtons.right
    elseif config.mappingProfile == 'leftrightaction' then
        config.mappedButtons.a = config.mappedButtons.right
        config.mappedButtons.b = config.mappedButtons.action
    elseif config.mappingProfile == 'updownaction' then
        config.mappedButtons.b = config.mappedButtons.action
    elseif config.mappingProfile == 'fourdiagonals' then
        config.mappedButtons.up = config.mappedButtons.nw
        config.mappedButtons.down = config.mappedButtons.sw
        config.mappedButtons.x = config.mappedButtons.ne
        config.mappedButtons.b = config.mappedButtons.se
    elseif config.mappingProfile == 'threehorizontal' then
        -- unsure
    elseif config.mappingProfile == 'updownleftright' then
        config.mappedButtons.y = config.mappedButtons.left
        config.mappedButtons.a = config.mappedButtons.right
        config.mappedButtons.left = nil
        config.mappedButtons.right = nil
    elseif config.mappingProfile == 'leftrightaction2p' then
        config.mappedButtons.b = config.mappedButtons.actionp1
        config.mappedButtons['b/2'] = config.mappedButtons.actionp2
    elseif config.mappingProfile == 'leftrighttwoactions' then
        config.mappedButtons.y = config.mappedButtons.actionleft
        config.mappedButtons.a = config.mappedButtons.actionright
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

        hh2rt.getInput(input)

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
