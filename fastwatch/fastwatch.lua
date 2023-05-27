_addon.name     = 'fastwatch'
_addon.author   = 'Xab'
_addon.version  = '1.0'
_addon.commands = {'fw'}

require('logger')
require('coroutine')
packets = require('packets')

local running = false
local starting = false
local fighting = false
local laststonecnt = 0
local stoneids = L{1539,1540,1541,1542,1543,1544}

local function get_mob_by_name(name)
    local mobs = windower.ffxi.get_mob_array()
    for i, mob in pairs(mobs) do
        if (mob.name == name) and (math.sqrt(mob.distance) < 6) then
            return mob
        end
    end
end

function general_release()
    windower.packets.inject_incoming(0x052, string.char(0,0,0,0,0,0,0,0))
    windower.packets.inject_incoming(0x052, string.char(0,0,0,0,1,0,0,0))
end

function isPartyFull()
	local party = windower.ffxi.get_party()
	return party.party1_count == 6
end

function getstonecount()
	local cnt = 0
	local key_items = windower.ffxi.get_key_items()
	for _, id in ipairs(key_items) do
		if stoneids:contains(id) then
			cnt = cnt + 1
		end
	end
	return cnt
end

windower.register_event('incoming chunk', function(id, data)
	-- 0x034 - NPC Interaction
	if (id == 0x34 and running) then
		local p = packets.parse('incoming', data)
		local npc = windower.ffxi.get_mob_by_id(p['NPC'])
		
		-- If the menu interacton is from the rift, then start the fight
		if npc then
			if npc.name == "Planar Rift" then
				starting = true
				fighting = true
				local outp = packets.new('outgoing', 0x5b, {
					['Target'] = npc.id,
					['Target Index'] = npc.index,
					['Option Index'] = 0x51,
					['_unknown1'] = 0,
					['_unknown2'] = 0,
					['Automated Message'] = false,
					['Menu ID'] = p['Menu ID'],
					['Zone'] = windower.ffxi.get_info()['zone'],
				})
				packets.inject(outp)
				general_release()
				return true
			end
		end
	end
	
	-- 0x052 - NPC Interaction Release
	if id == 0x052 then
		starting = false
	end
	
	-- 0x38 - Spawn/Despawn
    if (id == 0x38 and running)  then
        local p = packets.parse('incoming', data)
        local mob = windower.ffxi.get_mob_by_id(p['Mob'])
        if not mob then elseif (mob.name == 'Riftworn Pyxis') then
            if p['Type'] == 'deru' then
				fighting = false
				local cnt = getstonecount()
				if cnt ~= laststonecnt then
					log("Stones remaining: " .. cnt)
					laststonecnt = getstonecount()
				end
            end
        end
    end
end)

function watchrift()
	local warnnostone = true
	if not running then
		log("Watching for rift")
		running = true
		starting = false
		fighting = false
		laststonecnt = -1
		while running do
			if not starting and not fighting and isPartyFull() then
				local rift = get_mob_by_name('Planar Rift')
				if rift and rift.valid_target then
					local cnt = getstonecount()
					if cnt > 0 then
						-- Poke the rift to open the dialog menu
						warnnostone = true
						local p = packets.new('outgoing', 0x1a, {
							['Target'] = rift.id,
							['Target Index'] = rift.index,
						})
						packets.inject(p)
						coroutine.sleep(4)
					elseif warnnostone then
						log("No voidstones to initiate battle.")
						warnnostone = false
					end
				end
			end
			coroutine.sleep(.5)
		end
		log("Stopped")
	end
end

windower.register_event('addon command',function (...)
	local command = L{...}
	local action = command[1]

	if action == "release" then
		log("Injecting release message")
		general_release()
	elseif action == "start" then
		watchrift()
	elseif action == "stop" then
		running = false
	else
		print("Invalid Command")
	end
end)