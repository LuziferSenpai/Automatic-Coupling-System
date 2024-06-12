local eventHandler = require("__core__/lualib/event_handler")
local eventsDefine = defines.events
local eventsLib = {}

eventsLib.events = {
    [eventsDefine.on_game_created_from_scenario] = function()
        local locomotives = game.surfaces[1].find_entities_filtered({
            type = "locomotive"
        })

        for i = 1, #locomotives do
            locomotives[i].train.manual_mode = false
        end
    end
}

eventHandler.add_libraries({
    require("__Automatic_Coupling_System__/scripts/events"),

    eventsLib
})
