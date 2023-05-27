_addon.name = 'OpenSesame'
_addon.author = 'Arcon; Extensions by Aurum'
_addon.version = '1.0.0.0'
_addon.language = 'english'
_addon.commands = {'opensesame', 'os'}

require('luau')
packets = require('packets')

defaults = {}
defaults.Auto = false
defaults.Range = 10
settings = config.load(defaults)
cached_range = settings.Range^2

last = {}
doors = S{}

instance_requesting = false
instance_menu = nil
instance_option = nil
instance_npc = nil

CHANNEL_TICKETING = 141

local function get_mob_by_name(name)
    local mobs = windower.ffxi.get_mob_array()
    for i, mob in pairs(mobs) do
        if (mob.name == name) and (math.sqrt(mob.distance) < 6) then
            return mob
        end
    end
end
local function general_release()
    windower.packets.inject_incoming(0x052, string.char(0,0,0,0,0,0,0,0))
    windower.packets.inject_incoming(0x052, string.char(0,0,0,0,1,0,0,0))
end

update_doors = function()
	if settings.Auto then
		local mobs = windower.ffxi.get_mob_array()
		doors:clear()
		for index, mob in pairs(mobs) do
			if mob.spawn_type == 34 and mob.distance < 2500 then
				doors:add(index)
			end
		end
	end
end

update_doors()

exceptions = S{
    17097337, -- unknown. provided by original addon
	17772690, -- Rulude, ducal audience chamber (annoyance)
	17797169, -- Mhaura, door directly below ambu npc (annoyance)
	17797168, -- Mhaura, goldsmith door near ambu npc (annoyance)
	17072329, -- Nyzul isle runic seal. this will require special handling, so it is being ignore to prevent hosing the client
}
override_distance = T{
	[17072312] = 1, -- nyzul staging south door
	[17072311] = 1, -- nyzul staging north door
}

allowed_prompt_doors = L{'Gilded Doors'}
allowed_self_portals = L{72}

check_door = function(door)
    return door
        and door.spawn_type == 34 -- must be a door
		and door.status == 9      -- door must be closed
        and door.distance < (override_distance[door.id] or cached_range)
        and (not last[door.index] or os.time() - last[door.index] > 7)
        and door.name:byte() ~= 95
        and door.name ~= 'Furniture'
        and not exceptions:contains(door.id)
end

frame_count = 0
windower.register_event('prerender', function()
    if not windower.ffxi.get_info().logged_in then
        frame_count = 0
        return
    end

    frame_count = frame_count + 1
    if frame_count == 30 then
        update_doors()
        frame_count = 0
    end

	-- if there is an active instance request inflight then poke no more doors
	if not instance_requesting then
		local open = T{}
		if settings.Auto then
			for index in doors:it() do
				local door = windower.ffxi.get_mob_by_index(index)
				if check_door(door) then
					open[door.index] = door.id
				end
			end
		end

		for id, index in open:it() do
			packets.inject(packets.new('outgoing', 0x01A, {
				['Target'] = id,
				['Target Index'] = index
			}))
			last[index] = os.time()
		end
	end
end)

windower.register_event('logout', 'zone change', function()
    last = {}
    doors:clear()
end)

windower.register_event('addon command', function(command, ...)
    command = command and command:lower()
    local args = {...}

    if command == 'auto' then
        if args[1] == 'on' then
            settings.Auto = true
        elseif args[1] == 'off' then
            settings.Auto = false
        else
            settings.Auto = not settings.Auto
        end

        update_doors()

        log('Automatic door opening %s.':format(settings.Auto and 'enabled' or 'disabled'))
        config.save(settings)
    elseif command == 'range' then
		local newrange = tonumber(args[1])
		if newrange ~= nil then
			settings.Range = newrange
			cached_range = newrange^2
			log('Door range set to %s.':format(settings.Range))
			config.save(settings)
		else
			print('range must be a number')
		end
    else
        print(_addon.name .. ' v' .. _addon.version .. ':')
        print('  auto [on|off] - Sets automatic door opening to on/off or toggles it')
    end
end)

local function dowarp(zone, menuid, npc, destination)
	packets.inject(packets.new('outgoing', 0x5b, {
		['Target'] = npc.id,
		['Target Index'] = npc.index,
		['Option Index'] = 0,
		['_unknown1'] = 0,
		['_unknown2'] = 0,
		['Automated Message'] = true,
		['Menu ID'] = menuid,
		['Zone'] = zone,
	}))
	packets.inject(packets.new('outgoing', 0x05C, {
		['Target ID'] = npc.id,
		['Target Index'] = npc.index,
		['Zone'] = zone,
		['Menu ID'] = menuid,
		["X"] = destination.x,
		["Y"] = destination.y,
		["Z"] = destination.z,
		["_unknown1"] = destination.unknown1,
		["_unknown2"] = destination.unknown2 or 0,
		["Rotation"] = destination.h,
	}))
	coroutine.sleep(0.5) -- allow time for the warp to complete
	packets.inject(packets.new('outgoing', 0x5b, {
		['Target'] = npc.id,
		['Target Index'] = npc.index,
		['Option Index'] = destination.menu_option or 0,
		['_unknown1'] = 0,
		['_unknown2'] = 0,
		['Automated Message'] = false,
		['Menu ID'] = menuid,
		['Zone'] = zone,
	}))
end

local function CheckWarp(zone, menuid, npc)
	if WarpDoors[zone] then
		local destination = WarpDoors[zone][menuid]
		if destination then
			dowarp:schedule(0.5, zone, menuid, npc, destination)
			last[npc.index] = os.time()
			return true
		end
	end
	return false
end

local function startinstance(menuid, option1, option2, npc)
	windower.add_to_chat(CHANNEL_TICKETING, "Requesting instance")
	instance_requesting = true
	instance_npc = npc
	instance_menu = menuid
	instance_option = option2
	packets.inject(packets.new('outgoing', 0x5b, {
		['Target'] = npc.id,
		['Target Index'] = npc.index,
		['Option Index'] = 0,
		['_unknown1'] = option1,
		['_unknown2'] = 0,
		['Automated Message'] = true,
		['Menu ID'] = menuid,
		['Zone'] = windower.ffxi.get_info()['zone'],
	}))
	last[npc.index] = os.time()
end

windower.register_event('incoming chunk', function(id, data)
	-- npc dialog 2
	if id == 0x34 then
		if settings.Auto and not instance_requesting then
			local p = packets.parse('incoming', data)
			local npc = windower.ffxi.get_mob_by_id(p['NPC'])
			
			if npc and not exceptions:contains(npc.id) then
				if npc.name == "Runic Seal" then
					startinstance(p['Menu ID'], 4, 4, npc)
					return true
				end
				if npc.name == "Gilded Gateway" then
					startinstance(p['Menu ID'], 12, 4, npc)
					return true
				end
			end
		end
	end
	
	-- npc dialog 1
	if id == 0x32 then
		if settings.Auto then
			local p = packets.parse('incoming', data)
			local npc = windower.ffxi.get_mob_by_id(p['NPC'])
			local menuid = p['Menu ID']
			local zone = windower.ffxi.get_info()['zone']

			if npc and not exceptions:contains(npc.id) then
				if npc.spawn_type == 34 then
					-- menu came from a door

					-- Check if the door is fake and will warp the user (e.g. staging points)
					if CheckWarp(zone, menuid, npc) then
						return true
					end

					-- Only activate prompt doors on the whitelist
					if allowed_prompt_doors:contains(npc.name) then
						packets.inject(packets.new('outgoing', 0x5b, {
							['Target'] = npc.id,
							['Target Index'] = npc.index,
							['Option Index'] = 0,
							['_unknown1'] = 0,
							['_unknown2'] = 0,
							['Automated Message'] = true,
							['Menu ID'] = menuid,
							['Zone'] = zone,
						}))
						packets.inject(packets.new('outgoing', 0x5b, {
							['Target'] = npc.id,
							['Target Index'] = npc.index,
							['Option Index'] = 1,
							['_unknown1'] = 0,
							['_unknown2'] = 0,
							['Automated Message'] = false,
							['Menu ID'] = menuid,
							['Zone'] = zone,
						}))
						last[npc.index] = os.time()
						return true	
					end
				else
					local player = windower.ffxi.get_player()
					if player and player.id == npc.id then
						-- This is possibly a portal auto-prompt
						if CheckWarp(zone, menuid, npc) then
							return true
						end
					end
				end
			end
		end
	end

	-- Instance reservation confirmation
	if id == 0x0bf then
		local payload = data:sub(5)
		local u1, state, u3, u4, targetidx = payload:unpack("HHHHH")
		if instance_npc and instance_npc.index == targetidx then
			if state == 4 then
				windower.add_to_chat(CHANNEL_TICKETING, "Instance reserved; entering.")
				last[targetidx] = os.time()
			elseif state == 3 then
				windower.add_to_chat(CHANNEL_TICKETING, "Instance reservation failed because another player is entering.")
				last[targetidx] = 0
			else
				windower.add_to_chat(CHANNEL_TICKETING, "Instance reservation failed becuase request timed out.")
				last[targetidx] = 0
			end
			-- complete the menu selection
			packets.inject(packets.new('outgoing', 0x5b, {
				['Target'] = instance_npc.id,
				['Target Index'] = targetidx,
				['Option Index'] = state,
				['_unknown1'] = 0,
				['_unknown2'] = 0,
				['Automated Message'] = false,
				['Menu ID'] = instance_menu,
				['Zone'] = windower.ffxi.get_info()['zone'],
			}))
			general_release()
			instance_npc = nil
		end
		instance_requesting = false
	end
end)

-- These doors result in a warp instead of an open
WarpDoors = {
	[72] = {
		[106] = { x = 180.00001525879, z = 0, y = 77.612007141113, h = 63, unknown1 = 0},     -- nyzul staging north entrance
		[107] = { x = 180.00001525879, z = 0, y = 83.590003967285, h = 191, unknown1 = 0},    -- nyzul staging north exit
		[114] = { x = 180.00001525879, z = 0, y = -37.631000518799, h = 191, unknown1 = 0},   -- nyzul staging south entrance
		[115] = { x = 180.00001525879, z = 0, y = -43.581001281738, h = 63, unknown1 = 0},    -- nyzul staging south exit
		[215] = { x = -100.00000762939, z = -8.4990005493164, y = 20, h = 63, unknown1 = 1},  -- nyzul portal A to E
		[220] = { x = 620, z = -0.4990000128746, y = -303, h = 191, unknown1 = 1},            -- nyzul portal to A (Bhaflau Remnent)
	},
	[75] = {
		[200] = { x = 340.00003051758, z = -0.4990000128746, y = 140, h = 191, unknown1 = 1, unknown2 = 1, menu_option = 1}, -- BRII F1 to F2
		[203] = { x = -260, z = -0.5, y = -340.00003051758, h = 0, unknown1 = 1, unknown2 = 1, menu_option = 1}, -- BRII F2 NE to F3
		[205] = { x = -460.00003051758, z = -0.4990000128746, y = -20, h = 0, unknown1 = 1, unknown2 = 1, menu_option = 1}, -- BRII F3 WEST to F3
		[207] = { x = -340.00003051758, z = -0.5, y = 340.00003051758, h = 191, unknown1 = 1, unknown2 = 1, menu_option = 1}, -- BRII F4 to F5
	},
}