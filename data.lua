local MODNAME = "__Automatic_Coupling_System__"

local couple = util.table.deepcopy(data.raw["virtual-signal"]["signal-1"])
couple.name = "signal-couple"
couple.icon = MODNAME .. "/signal-couple.png"
couple.icon_size = 32
couple.icon_mipmap = nil
couple.subgroup = "coupling-signals"
couple.order = "a"

local decouple = util.table.deepcopy(data.raw["virtual-signal"]["signal-1"])
decouple.name = "signal-decouple"
decouple.icon = MODNAME .. "/signal-decouple.png"
decouple.icon_size = 32
decouple.icon_mipmap = nil
decouple.subgroup = "coupling-signals"
decouple.order = "b"

data:extend{{type = "item-subgroup", name = "coupling-signals", group = "signals", order = "zz"}, couple, decouple}