_addon.name     = 'buydust'
_addon.author   = 'Xab'
_addon.version  = '1.0'
_addon.commands = {'bd'}

require('logger')
require('coroutine')
packets = require('packets')
res = require('resources')
math.randomseed(os.time())

-- config
local BUYDELAY = true  -- true if you want a post-buy delay
local BUYMINTIME = 0.5 -- Minimum delay IN SECONDS. Decimals allowed.
local BUYMAXTIME = 2.0 -- Maximum delay IN SECONDS. Decimals allowed.

-- internal state
local buymode = false
local buycount = 0
local buytime = 0

local function get_mob_by_name(name)
    local mobs = windower.ffxi.get_mob_array()
    for i, mob in pairs(mobs) do
        if (mob.name == name) and (math.sqrt(mob.distance) < 6) then
            return mob
        end
    end
end

local function poke_thing(thing)
    local npc = get_mob_by_name(thing)
    if npc then
        local p = packets.new('outgoing', 0x1a, {
            ['Target'] = npc.id,
            ['Target Index'] = npc.index,
        })
        packets.inject(p)
		return true
    end
	return false
end

windower.register_event('incoming chunk', function(id, data)
	if (id == 0x34 and not buymode and buycount > 0) then
		local p = packets.parse('incoming', data)
		local npc = windower.ffxi.get_mob_by_id(p['NPC'])
		if npc and npc.name == "Voidwatch Purveyor" then
			buymode = true
			local outp = packets.new('outgoing', 0x5b, {
				['Target'] = npc.id,
				['Target Index'] = npc.index,
				['Option Index'] = 1,
				['_unknown1'] = "69",
				['_unknown2'] = 0,
				['Automated Message'] = false,
				['Menu ID'] = p['Menu ID'],
				['Zone'] = windower.ffxi.get_info()['zone'],
			})
			packets.inject(outp)
			buycount = buycount - 1
			general_release()
			return true
		end
	end
	
	if id == 0x052 then
		buymode = false
	end
end)


function general_release()
    windower.packets.inject_incoming(0x052, string.char(0,0,0,0,0,0,0,0))
    windower.packets.inject_incoming(0x052, string.char(0,0,0,0,1,0,0,0))
end

function getdelay()
	return BUYMINTIME + 0.5 + math.random() * (BUYMAXTIME - BUYMINTIME)
end

function dobuy(count)
	if count then
		buycount = tonumber(count)
		log("Buying " .. buycount .. " dust")
		while buycount > 0 do
			if not buymode then
				if BUYDELAY then
					if os.clock() > buytime then
						if poke_thing("Voidwatch Purveyor") then
							buytime = os.clock() + getdelay()
						end
					end
				else
					poke_thing("Voidwatch Purveyor")
				end
            end			
			coroutine.sleep(.5)
		end
		log("Buying stopped")
	end
end

windower.register_event('addon command',function (...)
	local command = L{...}
	local action = command[1]

	if action == "release" then
		log("Injecting release message")
		general_release()
	elseif action == "buy" then
		if command.n == 2 then
			local count = tonumber(command[2])
			if (count and count > 0) then
				dobuy(count)
			else
				print("not a valid number")
			end
		else
			print("bd buy <number>")
		end
	elseif action == "stop" then
		log("Stopping purchases")
		buycount = 0
		buymode = false
		general_release()
	else
		print("Commands:")
		print("  buy: Buy dust")
		print("  stop: Stop purchasing early")
		print("  release: Emergency escape if client is locked")
	end
end)