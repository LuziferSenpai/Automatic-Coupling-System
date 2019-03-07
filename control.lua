require "config"

local SESI = Senpais.Signals
local rdi = defines.rail_direction
local abs = math.abs
local wire = defines.wire_type

local function CS( s, si )
	local r = s.get_circuit_network( wire.red )
	local g = s.get_circuit_network( wire.green )
	if r then
		r = r.get_signal( si )
		if r ~= nil then
			return r
		end
	end
	if g then
		g = g.get_signal( si )
		if g ~= nil then
			return g
		end
	end
	return 0
end

local function GS( e, s )
	local r = e.get_circuit_network( wire.red )
	local g = e.get_circuit_network( wire.green )
	local v = 0
	if r then
		v = r.get_signal( s )
	end
	if g then
		v = v + g.get_signal( s )
	end
	if v == 0 then
		return nil
	else
		return v
	end
end

local function OM( o1, o2 )
	return abs( o1 - o2 ) < 0.25 or abs( o1 - o2 ) > 0.75
end

local function GO( e, t )
	local x = t.position.x - e.position.x
	local y = t.position.y - e.position.y
	return ( math.atan2( y, x ) / 2 / math.pi + 0.25 ) % 1
end

local function GD( pa, pb )
	return abs( pa.x - pb.x ) + abs( pa.y - pb.y )
end

local function GRF( t, s )
	if GD( t.front_stock.position, s.position ) < GD( t.back_stock.position, s.position ) then
		return t.front_stock
	else
		return t.back_stock
	end
end

local function GRB( t, s )
	if GD( t.front_stock.position, s.position ) < GD( t.back_stock.position, s.position ) then
		return t.back_stock
	else
		return t.front_stock
	end
end
local function SRD( r )
	if r == rdi.front then
		return rdi.back
	else
		return rdi.front
	end
end

local function AU( f, c )
	local t = f.train
	local cr = t.carriages
	local fr = t.front_stock
	local br = t.back_stock
	if c and abs( c ) < #cr then
		local d = rdi.front
		if f ~= fr then
			c = c * -1
		end
		local ta = c
		if c < 0 then
			c = #cr + c
			ta = c + 1
		else
			c = c + 1
		end
		local w = cr[c]
		if not OM( GO( w, cr[ta] ), w.orientation ) then
			d = SRD( d )
		end
		if w.disconnect_rolling_stock( d ) then
			local fl = 0
			local bl = 0
			fr = fr.train
			br = br.train
			local ws = fr.carriages
			for _, ce in pairs( ws ) do
				if ce.type == "locomotive" then
					fl = fl + 1
				end
			end
			ws = br.carriages
			for _, ce in pairs( ws ) do
				if ce.type == "locomotive" then
					bl = bl + 1
				end
			end
			if fl > 0 then fr.manual_mode = false end
			if bl > 0 then br.manual_mode = false end
			return w
		end
	end
end


local function AC( t, c, s )
	if c then
		local d = rdi.front
		if c < 0 then
			d = defines.rail_direction.back
		end
		local f = GRF( t, s )
		if not OM( f.orientation, s.orientation ) then
			d = SRD( d )
		end
		if f.connect_rolling_stock( d ) then
			return f
		end
	end
end

local function CC( t )
	local s = t.station
	if ( CS( s, SESI["Signal_Couple"] ) > 0 or CS( s, SESI["Signal_Uncouple"] ) > 0 ) then
		global.TrainsID[t.id] = s
	end
end

local function CP( t )
	local s = global.TrainsID[t.id]
	global.TrainsID[t.id] = nil
	if not s then return end
	if not s.valid then return end
	local c = false
	local f = GRF( t, s )
	local b = GRB( t, s )
	local se = t.schedule
	local ch = false
	if AC( t, GS( s, SESI["Signal_Couple"] ), s ) then
		ch = true
		c = true
		t = f.train
		if f == t.front_stock or b == t.back_stock then
			f = t.front_stock
			b = t.back_stock
		else
			f = t.back_stock
			b = t.front_stock
		end
	end
	f = AU( f, GS( s, SESI["Signal_Uncouple"] ) )
	if f then
		ch = true
	else
		f = b
	end
	if ch then
		f = f.train
		b = b.train
		f.schedule = se
		b.schedule = se
		if #f.locomotives > 0 or c then f.manual_mode = false end
		if #b.locomotives > 0 or c then b.manual_mode = false end
	end
end

local function globals()
	global.TrainsID = global.TrainsID or {}
	global.Couple = global.Couple or true
end

script.on_init( globals )
script.on_configuration_changed( globals )

script.on_event( defines.events.on_train_changed_state, function( ee )
	if global.Couple then
		local t = ee.train
		local d = defines.train_state.wait_station
		if t.state == d then
			CC( t )
		elseif ee.old_state == d and global.TrainsID[t.id] then
			CP( t )
		end
	end
end )

remote.add_interface
(
	"Couple",
	{
		Check = function( t )
			CC( t )
		end,
		Couple = function( t )
			CP( t )
		end
	}
)