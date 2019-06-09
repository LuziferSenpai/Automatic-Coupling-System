local m = "__Automatic_Coupling_System__"

local cp = util.table.deepcopy( data.raw["virtual-signal"]["signal-1"] )
cp.name = "signal-couple"
cp.icon = m .. "/signal-couple.png"
cp.subgroup = "coupling-signals"
cp.order = "a"

local dp = util.table.deepcopy( data.raw["virtual-signal"]["signal-1"] )
dp.name = "signal-decouple"
dp.icon = m .. "/signal-decouple.png"
dp.subgroup = "coupling-signals"
dp.order = "b"

data:extend{ { type = "item-subgroup", name = "coupling-signals", group = "signals", order = "gg" }, cp, dp }