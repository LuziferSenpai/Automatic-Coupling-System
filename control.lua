require "defines"

local Signals = Senpais.Signals
local rail_dir = defines.rail_direction
local abs = math.abs
local wire = defines.wire_type

local function GetSignalValue( entity, signal )
	local red = entity.get_circuit_network( wire.red )
	local green = entity.get_circuit_network( wire.green )
	local value = 0

	if red then
		value = red.get_signal( signal )
	end

	if green then
		value = value + green.get_signal( signal )
	end

	if value == 0 then
		return nil
	else
		return value
	end
end

local function OrientationMatch( orient1, orient2 )
	return abs( orient1 - orient2 ) < 0.25 or abs( orient1 - orient2 ) > 0.75
end

local function GetOrientation( entity, target )
	local x = target.position.x - entity.position.x
	local y = target.position.y - entity.position.y
	return ( math.atan2( y, x ) / 2 / math.pi + 0.25 ) % 1
end

local function GetTileDistance( pos_a, pos_b )
	return abs( pos_a.x - pos_b.x ) + abs( pos_a.y - pos_b.y )
end

local function GetRealFront( train, station )
	if GetTileDistance( train.front_stock.position, station.position ) < GetTileDistance( train.back_stock.position, station.position ) then
		return train.front_stock
	else
		return train.back_stock
	end
end

local function GetRealBack( train, station )
	if GetTileDistance( train.front_stock.position, station.position ) < GetTileDistance( train.back_stock.position, station.position ) then
		return train.back_stock
	else
		return train.front_stock
	end
end
local function SwapRailDir( raildir )
	if raildir == rail_dir.front then
		return rail_dir.back
	else
		return rail_dir.front
	end
end

local function AttemptUncouple( front, count )
	local train = front.train
	local carriages = train.carriages
	local front_stock = train.front_stock
	local back_stock = train.back_stock
	
	if count and abs( count ) < #carriages then
		local direction = rail_dir.front

		if front ~= front_stock then
			count = count * -1
		end

		local target = count

		if count < 0 then
			count = #carriages + count
			target = count + 1
		else
			count = count + 1
		end

		local wagon = carriages[count]
		
		if not OrientationMatch( GetOrientation( wagon, carriages[target] ), wagon.orientation ) then
			direction = SwapRailDir( direction )
		end

		if wagon.disconnect_rolling_stock( direction ) then
			local frontLocos = 0
			local backLocos = 0

			front_stock = front_stock.train
			back_stock = back_stock.train

			local wagons = front_stock.carriages

			for _, carriage in pairs( wagons ) do
				if carriage.type == "locomotive" then
					frontLocos = 1  -- only care if there is at least one loco
					break
				end
			end

			wagons = back_stock.carriages

			for _, carriage in pairs( wagons ) do
				if carriage.type == "locomotive" then
					backLocos = 1  -- only care if there is at least one loco
					break
				end
			end

			-- Front section stays in automatic after uncoupling, force it to manual if no locomotives.
			if frontLocos > 0 then
				front_stock.manual_mode = false
			else
				front_stock.manual_mode = true
			end
			-- Do the same for back section just to be safe.
			if backLocos > 0 then
				back_stock.manual_mode = false
			else
				back_stock.manual_mode = true
			end
			
			return wagon
		end
	end
end


local function AttemptCouple( train, count, station )
	if count then
		local direction = rail_dir.front
		
		if count < 0 then
			direction =  rail_dir.back
		end
		
		local front = GetRealFront( train, station )
		
		if not OrientationMatch( front.orientation, station.orientation ) then
			direction = SwapRailDir( direction )
		end
		if front.connect_rolling_stock( direction ) then
			return front
		end
	end
end

local function CheckCouple( train )
	local station = train.station
	if station ~= nil then
		if ( GetSignalValue( station, Signals["Signal_Couple"] ) ~= nil or GetSignalValue( station, Signals["Signal_Uncouple"] ) ~= nil ) then
			global.TrainsID[train.id] = { station = station, mod = false }
			
			return true
		end
	end
end

local function Couple( train )
	local station = global.TrainsID[train.id].station
	
	global.TrainsID[train.id] = nil
	
	if not station then return end
	if not station.valid then return end
	
	local couple = false
	local front = GetRealFront( train, station )
	local back = GetRealBack( train, station )
	local schedule = train.schedule
	local changed = false
	if AttemptCouple( train, GetSignalValue( station, Signals["Signal_Couple"] ), station ) then
		changed = true
		couple = true
		train = front.train
		
		if front == train.front_stock or back == train.back_stock then
			front = train.front_stock
			back = train.back_stock
		else
			front = train.back_stock
			back = train.front_stock
		end
	end
	
	front = AttemptUncouple( front, GetSignalValue( station, Signals["Signal_Uncouple"] ) )
	
	if front then
		changed = true
	else
		front = back
	end
	
	if changed then
		front = front.train
		back = back.train
		front.schedule = schedule
		back.schedule = schedule
		
		if #front.locomotives > 0 or couple then front.manual_mode = false end
		if #back.locomotives > 0 or couple then back.manual_mode = false end
		
		return true
	end
end

local function globals()
	global.TrainsID = global.TrainsID or {}
end

script.on_init( globals )
script.on_configuration_changed( function( event )
	local changes = event.mod_changes or {}

	if next( changes ) then
		local couplechanges = changes["Automatic_Coupling_System"] or {}

		if next( couplechanges ) then
			local oldversion = couplechanges.old_version

			if oldversion and couplechanges.new_version then
				if oldversion <= "0.2.3" then

					local TrainsID = global.TrainsID

					global.TrainsID = nil

					globals()

					if next( TrainsID ) then
						for id, data in pairs( TrainsID ) do
							global.TrainsID[id] = { station = data.s, mod = data.m }
						end
					end
				end
			end
		end
	end
end )

script.on_event( defines.events.on_train_changed_state, function( event )
	local train = event.train
	local statedefines = defines.train_state.wait_station
	
	if train.state == statedefines then
		CheckCouple( train )
	elseif event.old_state == statedefines and global.TrainsID[train.id] and not global.TrainsID[train.id].mod then
		Couple( train )
	end
end )

remote.add_interface
(
	"Couple",
	{
		Check = function( train )
			local boolean = CheckCouple( train )
			if boolean then
				global.TrainsID[train.id].mod = true
				
				return boolean
			else
				return false
			end
		end,

		Couple = function( train )
			local boolean = Couple( train )
			
			if boolean then
				return boolean
			else
				return false
			end
		end
	}
)