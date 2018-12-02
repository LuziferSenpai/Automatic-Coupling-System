local MODNAME = "__Automatic_Coupling_System__"

local couple_signal = util.table.deepcopy( data.raw["virtual-signal"]["signal-1"] )
couple_signal.name = "signal-couple"
couple_signal.icon = MODNAME .. "/signal-couple.png"
couple_signal.subgroup = "coupling-signals"
couple_signal.order = "a"

local decouple_signal = util.table.deepcopy( data.raw["virtual-signal"]["signal-1"] )
decouple_signal.name = "signal-decouple"
decouple_signal.icon = MODNAME .. "/signal-decouple.png"
decouple_signal.subgroup = "coupling-signals"
decouple_signal.order = "b"

data:extend{ { type = "item-subgroup", name = "coupling-signals", group = "signals", order = "gg" }, couple_signal, decouple_signal }