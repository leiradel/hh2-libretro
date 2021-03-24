uses 'graphics'
uses 'stdctrls'

return {
    new = function new()
        local self = {
            --popupmenu = M.tform(),
            font = tfont(),
            horzscrollbar = tscrollbar(),
            vertscrollbar = tscrollbar(),

            show = function()
            end,

            onactivate = function()
            end,

            onclose = function()
            end,

            oncreate = function()
            end,

            onkeydown = function()
            end,

            onkeyup = function()
            end,

            tcloseaction = {
                new = function()
                    return {}
                end
            }

            cafree = 0,
            bsnone = 0,
            ponone = 0,
            poscreencenter = 1,
            vk_up = -1,
            vk_down = -2,
            vk_left = -3,
            vk_right = -4,
            vk_control = -5,
            vk_menu = -6,
            vk_shift = -7,
            vk_insert = -8
        }
    end
}
