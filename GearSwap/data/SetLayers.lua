--[[
Fully qualified layer structure:
layers = {
	layer_name = {
		state = {
			set_name = {
				ALL = {
					... equipment list
				},
				JOB = {
					... equipment list
				}
			}
		}
	}
}

The "layer name" is defines the layer that is used when adding to the stack
The "state name" is the player state and should be one of: Idle, Precast, Midcast, Resting, Engaged
The "set name" should be "default", unless in Midcast/Precast, where it should be the ability name instead
In each set, you may use "ALL" or the three letter job name to specify job-specific sets.

Shorthand may be used when defining the layers:
	Equipment at the root of a set is added first, followed by "ALL", followed by the current active JOB.
	Equipment at the root of a state is added to the "default" set
	Equipment at the root of a layer is added to the "Idle" state
]]

DEFAULT_LAYER = "base"  -- base layer to auto set during load and reset
DEFAULT_STATE = "Idle"  -- base set name while idle
DEFAULT_SET = "default" -- mainly for used internal, but may be specified explicitly
STATE_PRECAST = "Precast"
STATE_MIDCAST = "Midcast"
STATE_RESTING = "Resting"
STATE_ENGAGED = "Engaged"
CHANNEL_GENERAL = 207   -- channel for general messages
reserved_sets = {'ALL', 'WAR', 'MNK', 'WHM', 'BLM', 'RDM', 'THF', 'PLD', 'DRK', 'BST', 'BRD', 'RNG', 'SAM', 'NIN', 'DRG', 'SMN', 'BLU', 'COR', 'PUP', 'DNC', 'SCH', 'GEO', 'RUN'}
warping = false

---[ Initialization ]------------------------------------------------------

-- GearSwap entrypoint
function get_sets()
	-- Initialize Globals
	Debug_mode = 0 -- Toggle for debug mode display
	stack = {}     -- active layer slots
	cache = {}     -- flattened layer cache
	layers = {}    -- layer definition
	stances = {}   -- stance definition
	macros = {}    -- macro palette swap definition
	style = {}     -- style lock swap definition

	-- Get layer data and then build the cache
    if job_setup then
        job_setup()
    end
	reset_stack()

	-- Handle game events
	windower.register_event('zone change', handler_zone_change)
	windower.raw_register_event('incoming chunk', handler_incoming_chunk)
	windower.raw_register_event('outgoing chunk', handler_outgoing_chunk)

	-- Once loaded, do initial equip, style locks, and set macro book 
	init_complete:schedule(3)
end

function init_complete()
	idle()
	set_style()
	set_macro_book()
end

---[ Utils ]------------------------------------------------------

function get_keys(t)
    local keys={}
    for key,_ in pairs(t) do
        table.insert(keys, key)
    end
    return keys
end

function deepcopy(orig)
    if type(orig) == 'table' then
        local clone = {}
        for orig_key, orig_value in next, orig, nil do
            clone[deepcopy(orig_key)] = deepcopy(orig_value)
        end
        setmetatable(clone, deepcopy(getmetatable(orig)))
        return clone
    else
        return orig
    end
end

function deepmerge(t1, t2)
    -- A special consideration must be made to preserve the ref of the "empty" object, as GS logic compares by ref
    if type(t2) ~= "table" or t2 == empty then return t2 end
    if type(t1) ~= "table" or t1 == empty then return deepcopy(t2) end
    local clone = {}
    for k, v in pairs(t1) do
        if t2[k] ~= nil then
            clone[k] = deepmerge(t1[k], t2[k])
        elseif type(v) == "table" and v ~= empty then
            clone[k] = deepcopy(v)
        else
            clone[k] = v
        end
    end
    for k, v in pairs(t2) do
        if clone[k] == nil then
            if type(clone[k]) == "table" and v ~= empty then
                clone[k] = deepcopy(v);
            else
                clone[k] = v
            end
        end
    end
    return clone
end

function set_macro_book()
	if (macros[player.sub_job]) then
		send_command('input /macro book '..macros[player.sub_job].book)
		send_command('input /macro set '..macros[player.sub_job].set)
	elseif (macros["DEFAULT"]) then
		send_command('input /macro book '..macros["DEFAULT"].book)
		send_command('input /macro set '..macros["DEFAULT"].set)
	end
end

function set_style()
	if (style[player.sub_job]) then
		send_command('@wait 1;input /lockstyleset '..style[player.sub_job])
	elseif (style["DEFAULT"]) then
		send_command('@wait 1;input /lockstyleset '..style["DEFAULT"])
	end
end

---[ Stack Management ]------------------------------------------------------

-- Creates a flattened gear cache based on the current stack and player sub job
function build_cache()
    local built = {}
    local slots = get_keys(stack)
    table.sort(slots)

    for k,v in ipairs(slots) do
        local src = stack[v] or {}
        if type(src.layer) == "table" then
			-- flatten layer then merge
            built = deepmerge(built, flatten_layer(src.layer))
        end
    end
    cache = built
end

-- Assign a layer to a slot and rebuild
function set_slot(slot, name)
    slot = tonumber(slot)
    if slot == nil then
        return false
    end

    local layer = layers[name]
    if type(layer) == "table" then
        stack[slot] = {
            name = name,
            layer = layer
        }
        build_cache()
        return true
    end
    return false
end

-- Assign a layer to a slot and rebuild
function toggle_slot(slot, name)
    slot = tonumber(slot)
    if slot == nil then
        return nil
    end

	local current = stack[slot]
	if not current or current.name ~= name then
		if set_slot(slot, name) then
			return true
	    else
			return nil
		end
	else
		if reset_slot(slot) then
			return false
		else
			return nil
		end
	end
end

-- Clear a slot and rebuild
function reset_slot(slot)
    slot = tonumber(slot)
    if slot == nil then
        return false
    end

    if stack[slot] ~= nil then
        stack[slot] = nil
        build_cache()
        return true
    end
    return false
end

-- Reset all layers to default and rebuild
function reset_stack()
    stack = {}
    set_slot(0, DEFAULT_LAYER)
end

-- Copies all equipment to the destination.
function extract_equipment(source, parent, key)
    if type(source) == "table" then
        for _,name in pairs(gearswap.default_slot_map) do
            if source[name] then
                if parent[key] == nil then
                    parent[key] = {}
                end
                parent[key][name] = source[name]
            end
        end
    end
end

-- Determines if a key in a set is a reserved name. Reserved set may not be used as sub sets.
function isreservedname(name)
    return table.contains(reserved_sets, name) or table.contains(gearswap.default_slot_map, name)
end

-- Extract equipment from a block and flatten it down based on hierarchy and current sub job
function extract_sets(source, parent, key)
    if not key then
        key = DEFAULT_SET
    end
    -- Apply equipment at the root
    extract_equipment(source, parent, key)
    -- Apply equipment from all jobs
    if source.ALL then
        extract_sets(source.ALL, parent, key)
    end
    -- Apply equipment from sub job sets
    if source[player.sub_job] then
        extract_sets(source[player.sub_job], parent, key)
    end
    -- Apply named sets
    for name, set in pairs(source) do
        if (type(set) == "table") and not isreservedname(name) then
            extract_sets(set, parent, name)
        end
    end
end

-- Flatten a layer down to only active equipment.
function flatten_layer(collection)
    local compacted = {}
    if (type(collection) == "table") then
        -- Handle equipment sitting at the layer root. These are moved into the default state
        local set = {}
        extract_equipment(collection, set, DEFAULT_SET)
        if collection.ALL then
            extract_sets(collection.ALL, set)
        end
        if collection[player.sub_job] then
            extract_sets(collection[player.sub_job], set)
        end
        if next(set) ~= nil then
            compacted[DEFAULT_STATE] = set
        end

        -- Handle equipment inside each state
        for state, stateset in pairs(collection) do
            if type(stateset) == "table" and not isreservedname(state)  then
                compacted[state] = {}
                extract_sets(stateset, compacted[state])
            end
        end
    end
    return compacted
end

---[ Set Management ]------------------------------------------------------

-- Buids an equipment list using sets based on the ability, skill, or spell being used.
function get_skill_set(collection, spell)
	local set = set_get(collection, "Default" .. spell.action_type)
	local base_norm = normalize(get_ability_basename(spell.english))
	local name_norm = normalize(spell.english)
	
	-- Write skill info out if debug is enabled
	if (Debug_mode == 1) then
		windower.add_to_chat(1, '------------------------- skill info -----------------------')
		windower.add_to_chat("Action: " .. "Default" .. spell.action_type)
		windower.add_to_chat("Type: " .. spell.type)
		if (spell.skill) then
			windower.add_to_chat("Skill: " .. normalize(spell.skill))
		end
		if spell.action_type == 'Magic' then
			if spell.type == "BlueMagic" then
				local info = BlueMagicExtendedInfo[spell.id]
				if info then
					windower.add_to_chat("Blue Type: Blue" .. info.blue_type)
					windower.add_to_chat("Blue Spell Type: Blue" .. info.spell_type)
					windower.add_to_chat("Blue Combination: Blue" .. info.blue_type .. info.spell_type)
					if info.blue_type == "Physical" then
						if info.wsc_secondary then
							windower.add_to_chat("Blue Secondary Stat: Blue" .. info.wsc_secondary)
						end
						if info.wsc_primary then
							windower.add_to_chat("Blue Primary Stat: Blue" .. info.wsc_primary)
						end
					elseif spell.element then
						windower.add_to_chat("Element: " .. spell.element .. 'Magic')
					end
				end
			else
				windower.add_to_chat("Element: " .. spell.element .. 'Magic')
			end
		end
		windower.add_to_chat("Base: " .. base_norm .. "Base")
		windower.add_to_chat("Name: " .. spell.english .. " OR " .. name_norm)
	end

	-- Layer: Spell type: WeaponSkill, JobAbility, etc
	set = set_build(set, collection, spell.type)
	
	-- Layer: Normalized skill type: EnfeeblingMagic, HealingMagic, etc
    if spell.skill then
		set = set_build(set, collection, normalize(spell.skill))
	end
	
	-- Layer: Magic-specific; Elemental: FireMagic, EarthMagic; Blue Magic: BluePhysical, BlueElemental
	if spell.action_type == 'Magic' then
		if spell.type == "BlueMagic" then
			local info = BlueMagicExtendedInfo[spell.id]
			if info then
				set = set_build(set, collection, 'Blue' .. info.blue_type)
				set = set_build(set, collection, 'Blue' .. info.spell_type)
				set = set_build(set, collection, 'Blue' .. info.blue_type .. info.spell_type)
				if info.blue_type == "Physical" then
					if info.wsc_secondary then
						set = set_build(set, collection, 'Blue' .. info.wsc_secondary)
					end
					if info.wsc_primary then
						set = set_build(set, collection, 'Blue' .. info.wsc_primary)
					end
				elseif spell.element then
					set = set_build(set, collection, spell.element .. 'Magic')
				end
			end
		else
			set = set_build(set, collection, spell.element .. 'Magic')
		end
	end

	-- Layer: Normalized skill Base: CureDefault, BarDefault, UtsusemiDefault, etc
	-- No variations such as "II" "III" "IV" etc.
	set = set_build(set, collection, base_norm .. "Base")
	
	-- Layer: Specific Skill by nane: Cure II, Utsusemi: Ni
	if set_has(collection, spell.english) then
		--EXACT match: "Cure II", "Utsusemi: Ni", "King's Justice"
		set = set_build(set, collection, spell.english)
	elseif set_has(collection, name_norm) then
		--NORMALIZED: "CureII", "UtsusemiNi", "KingsJustice"
		set = set_build(set, collection, name_norm)
    end	
	return set
end

-- Builds the base set, from which all other name based layering is done
function get_base_set()
	-- Create base set with maximum haste applied over top
	local set = set_get(cache[DEFAULT_STATE])
	
	-- Status-based swaps
	local status = player.status
    if status == 'Resting' then
		set = set_build(set, cache[STATE_RESTING])
	elseif status == 'Engaged' then
		set = set_build(set, cache[STATE_ENGAGED])
	end
	return set
end

-- Normalizes spell name by removing special characters and spaces
function normalize(name)
	return string.gsub(name, "[ ':%.%-]", "")
end

-- Determines which "group" a spell belongs to
function get_ability_basename(name)
	-- Search for the base
	if SpellBases[name] then
		return SpellBases[name]
	end
	
	-- Special considerations
	name = string.gsub(name, "^Bar(%a+)$", "Bar")
	
	-- Suffix removal
	suffixes = {" II$", " III$", " IV$", " V$", ": Ichi$", ": Ni$", "-%a+$"}
	for _, suffix in ipairs(suffixes) do
		name = string.gsub(name, suffix, "")
	end
	return name
end

-- Checks if a set is available
function set_has(collection, setname)
	if collection then
		if setname then
			if (collection[setname]) then
				return true
			end
		else
			if (collection[DEFAULT_SET]) then
				return true
			end
		end
	end
	return false
end

-- Returns a set if available
function set_get(collection, setname)
	local set = {}
	if collection then
		if setname then
			if (collection[setname]) then
				set = collection[setname]
			end
		else
			if (collection[DEFAULT_SET]) then
				set = collection[DEFAULT_SET]
			end
		end
	end
	return set
end

-- Combine a set with the specified set, if available
function set_build(build, collection, setname)
	return set_combine(build, set_get(collection, setname))
end

-- Combine a set with the specified skill sets, if available
function set_build_skill(build, collection, setname)
	return set_combine(build, get_skill_set(collection, setname))
end

---[ Stance Management ]------------------------------------------------------

function stance_forward(slot)
    slot = tonumber(slot)
    if slot == nil then
        windower.add_to_chat(CHANNEL_GENERAL, "Slot must be a number")
        return false
    end

    local stance = stances[slot]
    local cnt = #stance
    if stance and (type(stance) == "table") and (cnt > 0) then
        local current = stack[slot]
        local found = false

        if not current then
            found = true
        end

        for k, v in ipairs(stance) do
            if found then
                if layers[v] then
                    if set_slot(slot, v) then
                        windower.add_to_chat(CHANNEL_GENERAL, "Slot " .. slot .. ": " .. v)
                        return true
                    end
                end
            elseif v == current.name then
                found = true
            end
        end
        windower.add_to_chat(CHANNEL_GENERAL, "Slot " .. slot .. " unset")
        reset_slot(slot)
		return true
    else
        windower.add_to_chat(CHANNEL_GENERAL, "A stance list has not been defined for the specified slot.")
    end
	return false
end

function stance_reverse(slot)
    slot = tonumber(slot)
    if slot == nil then
        windower.add_to_chat(CHANNEL_GENERAL, "Slot must be a number")
        return false
    end

    local stance = stances[slot]
    local cnt = #stance
    if stance and (type(stance) == "table") and (cnt > 0) then
        local current = stack[slot]
        local found = false

        if not current then
            found = true
        end

        for k = cnt, 1, -1 do
            local v = stance[k]
            if found then
                if layers[v] then
                    if set_slot(slot, v) then
                        windower.add_to_chat(CHANNEL_GENERAL, "Slot " .. slot .. ": " .. v)
                        return true
                    end
                end
            elseif v == current.name then
                found = true
            end
        end
        windower.add_to_chat(CHANNEL_GENERAL, "Slot " .. slot .. " unset")
        reset_slot(slot)
		return true
    else
        windower.add_to_chat(CHANNEL_GENERAL, "A stance list has not been defined for the specified slot.")
    end
	return false
end

---[ GearSwap Events ]------------------------------------------------------
function idle()
	local set = get_base_set()
	equip(set)
end

function precast(spell)
	-- Dont swap on trust or items
	if (spell.type == "Trust" or spell.type == "Item") then
		return
	end

	-- Base: Idle + Combat (if active)
	local set = get_base_set()
	
	-- ADD: Magic specific gear
	if spell.action_type == 'Magic' then
		-- Add interrupt down equipment
		set = set_build(set, cache.InterruptRate)
	end

	-- If default set is defined
	set = set_build(set, cache[STATE_PRECAST], DEFAULT_SET)	

	-- ADD: Spell/Skill specific gear
	set = set_build_skill(set, cache[STATE_PRECAST], spell)
	equip(set)
end

function midcast(spell)
	-- Dont swap on trust or items
	if (spell.type == "Trust" or spell.type == "Item") then
		return
	end

	-- Base: Idle + Combat (if active)
	local set = get_base_set()
	
	-- ADD: Magic specific gear
	if spell.action_type == 'Magic' then
		-- Add recast reduction pieces
		set = set_build(set, cache.MaxRecast)
	
		-- Add interrupt down equipment
		set = set_build(set, cache.InterruptRate)
	end

	-- If default set is defined
	set = set_build(set, cache[STATE_MIDCAST], DEFAULT_SET)	

	-- ADD: Spell/Skill specific gear
	set = set_build_skill(set, cache[STATE_MIDCAST], spell)
	equip(set)
	
	-- Cancel certain buffs prior to refreshing. REQUIRES THE CANCEL ADDON
	-- Warning: these cancels will still run if the spell gets interrupted
	--[[
	if spell.target.name == player.name then
		if spell.english == 'Sneak' then
			send_command('@wait 1.8;cancel 71;')
		elseif spell.english == 'Stoneskin' then
			send_command('@wait 4.8;cancel 37;')
		elseif spell.english == 'Blink' then
			send_command('@wait 4.5;cancel 36;')
		elseif spell.english == 'Utsusemi: Ichi' then
			send_command('@wait 3;cancel 66;')
		end	
	end
	--]]
end

function aftercast(spell)
	-- Dont swap on trust summonings
	if (spell.type == "Trust") then
		return
	end

    idle()
    if not spell.interrupted then
        if spell.english == 'Sleep' or spell.english == 'Sleepga' then
            send_command('@wait 55;input /echo ------- '..spell.english..' is wearing off in 5 seconds -------')
        elseif spell.english == 'Sleep II' or spell.english == 'Sleepga II' then
            send_command('@wait 85;input /echo ------- '..spell.english..' is wearing off in 5 seconds -------')
        elseif spell.english == 'Break' or spell.english == 'Breakga' then
            send_command('@wait 25;input /echo ------- '..spell.english..' is wearing off in 5 seconds -------')
        end
    end
end

function status_change(new,old)
	idle()
end

function sub_job_change(new, old)
	build_cache()
	idle()
	set_macro_book()
	set_style()
end

function self_command(command)
	local command = command
	if type(command) == 'string' then
		command = command:split(' ')
	end

	local action = command[1]
	local args = #command
	
	if action == "update" then
		idle()
		windower.add_to_chat(CHANNEL_GENERAL, "Gear has been reapplied")
	elseif action == "unset" then
		if args > 1 then
			-- clear specific layer
			local slot = tonumber(command[2])
			if slot == nil then
				windower.add_to_chat(CHANNEL_GENERAL, "Slot must be a number")
				return
			end
			
			if reset_slot(slot) then
				windower.add_to_chat(CHANNEL_GENERAL, "Slot " .. slot .. " has been unset")
				idle()
			else
				windower.add_to_chat(CHANNEL_GENERAL, "Slot " .. slot .. " is already empty")
			end
		else
			-- clear all layers
			reset_stack()
			idle()
			windower.add_to_chat(CHANNEL_GENERAL, "All applied layers have been unset")
		end
	elseif action == "set" then
		if args == 3 then
			local slot = tonumber(command[2])
			if slot == nil then
				windower.add_to_chat(CHANNEL_GENERAL, "Slot must be a number")
				return
			end
			local layer = command[3]
			if set_slot(slot, layer) then
				windower.add_to_chat(CHANNEL_GENERAL, "Slot " .. slot .. " set to " .. layer)
				idle()
			else
				windower.add_to_chat(CHANNEL_GENERAL, "'" .. layer .. "' can not be found. Names are case-sensitive.")
				windower.add_to_chat(CHANNEL_GENERAL, "Use 'gs c list layers' to show all available layers.")
			end
		else
			windower.add_to_chat(CHANNEL_GENERAL, "Both a slot and a layer must be specified")
		end
	elseif action == "toggle" then
		if args == 3 then
			local slot = tonumber(command[2])
			if slot == nil then
				windower.add_to_chat(CHANNEL_GENERAL, "Slot must be a number")
				return
			end
			local layer = command[3]
			local result = toggle_slot(slot, layer)
			if result ~= nil then
				if result then
					windower.add_to_chat(CHANNEL_GENERAL, "Slot " .. slot .. " set to " .. layer)
				else
					windower.add_to_chat(CHANNEL_GENERAL, "Slot " .. slot .. " unset")
				end
				idle()
			else
				windower.add_to_chat(CHANNEL_GENERAL, "'" .. layer .. "' can not be found. Names are case-sensitive.")
				windower.add_to_chat(CHANNEL_GENERAL, "Use 'gs c list layers' to show all available layers.")
			end
		else
			windower.add_to_chat(CHANNEL_GENERAL, "Both a slot and a layer must be specified")
		end
	elseif action == "list" then
		if args == 2 then
			local listtype = command[2]
			
			if listtype == "stack" then
				local slots = get_keys(stack)
				table.sort(slots)
				
				windower.add_to_chat(CHANNEL_GENERAL, "Applied Layers:")
				for k,v in ipairs(slots) do
					local src = stack[v] or {}
					if src.name then
						windower.add_to_chat(CHANNEL_GENERAL, v .. ": " .. src.name)
					end
				end
			elseif listtype == "layers" then
				windower.add_to_chat(CHANNEL_GENERAL, "Available Layers:")
				for k,_ in pairs(layers) do
					windower.add_to_chat(CHANNEL_GENERAL, k)
				end
			else
				windower.add_to_chat(CHANNEL_GENERAL, "Invalid type. Available: stack, layers")
			end
		else
			windower.add_to_chat(CHANNEL_GENERAL, "Must specify type. Available: stack, layers")
		end
	elseif action == "next" or action == "n" then
		if args == 2 then
			if stance_forward(command[2]) then
				idle()
			end
		else
			windower.add_to_chat(CHANNEL_GENERAL, "A stance must be specified")
		end
	elseif action == "prev" or action == "previous" or action == "p" then
		if args == 2 then
			if stance_reverse(command[2]) then
				idle()
			end
		else
			windower.add_to_chat(CHANNEL_GENERAL, "A stance must be specified")
		end		
	elseif action == "debug" then
		if Debug_mode == 1 then
			Debug_mode = 0
			windower.add_to_chat('Debug mode: OFF')
		else
			Debug_mode = 1
			windower.add_to_chat('Debug mode: ON')
		end
	else
		windower.add_to_chat("Unknown Command. Available: unset, set, toggle, list, update, debug")
	end
end

--[ Game Events ]------------------------------------------------------------

-- When a zone change occurs, force an equip update
function handler_zone_change(new_id, old_id)
	idle()
end

-- After an intra-zone warp, force a reset
-- Intended to address being left in combat sets after a bcnm-style fight concludes.
-- These types of fights block the disengage, and then warp you to the exit. Example: Walk of Echoes, HTBF, etc.
function post_warp_reset()
	-- Raw event handler seems to be out of the gearswap scope, so use the addon command instead of calling idle directly
	send_command('gs c update')
end
function handler_incoming_chunk(id, data)
	if id == 0x052 and warping then
		-- intra-zone warps typically require dialogue flow. This is a backup in case no option is sent
		warping = false
		post_warp_reset:schedule(1)
	end
end
function handler_outgoing_chunk(id, data)
	if id == 0x05C then
		-- warp request
		warping = true
	end
	if id == 0x05B and warping then
		-- intra-zone warps typically require dialogue flow, so this is assumed to be the closer
		warping = false
		post_warp_reset:schedule(1)
	end
end

--[ Lookup Tables ]------------------------------------------------------------
SpellBases = {
	['Foe Requiem'] = "Requiem",
	['Foe Requiem II'] = "Requiem",
	['Foe Requiem III'] = "Requiem",
	['Foe Requiem IV'] = "Requiem",
	['Foe Requiem V'] = "Requiem",
	['Foe Requiem VI'] = "Requiem",
	['Foe Requiem VII'] = "Requiem",
	['Horde Lullaby'] = "Lullaby",
	['Horde Lullaby II'] = "Lullaby",
	['Army\'s Paeon'] = "Paeon",
	['Army\'s Paeon II'] = "Paeon",
	['Army\'s Paeon III'] = "Paeon",
	['Army\'s Paeon IV'] = "Paeon",
	['Army\'s Paeon V'] = "Paeon",
	['Army\'s Paeon VI'] = "Paeon",
	['Mage\'s Ballad'] = "Ballad",
	['Mage\'s Ballad II'] = "Ballad",
	['Mage\'s Ballad III'] = "Ballad",
	['Knight\'s Minne'] = "Minne",
	['Knight\'s Minne II'] = "Minne",
	['Knight\'s Minne III'] = "Minne",
	['Knight\'s Minne IV'] = "Minne",
	['Knight\'s Minne V'] = "Minne",
	['Valor Minuet'] = "Minuet",
	['Valor Minuet II'] = "Minuet",
	['Valor Minuet III'] = "Minuet",
	['Valor Minuet IV'] = "Minuet",
	['Valor Minuet V'] = "Minuet",
	['Sword Madrigal'] = "Madrigal",
	['Blade Madrigal'] = "Madrigal",
	['Hunter\'s Prelude'] = "Prelude",
	['Archer\'s Prelude'] = "Prelude",
	['Sheepfoe Mambo'] = "Mambo",
	['Dragonfoe Mambo'] = "Mambo",
	['Advancing March'] = "March",
	['Victory March'] = "March",
	['Battlefield Elegy'] = "Elegy",
	['Carnage Elegy'] = "Elegy",
	['Sinewy Etude'] = "Etude",
	['Dextrous Etude'] = "Etude",
	['Vivacious Etude'] = "Etude",
	['Quick Etude'] = "Etude",
	['Learned Etude'] = "Etude",
	['Spirited Etude'] = "Etude",
	['Enchanting Etude'] = "Etude",
	['Herculean Etude'] = "Etude",
	['Uncanny Etude'] = "Etude",
	['Vital Etude'] = "Etude",
	['Swift Etude'] = "Etude",
	['Sage Etude'] = "Etude",
	['Logical Etude'] = "Etude",
	['Bewitching Etude'] = "Etude",
	['Raptor Mazurka'] = "Mazurka",
	['Chocobo Mazurka'] = "Mazurka",
	['Foe Lullaby'] = "Lullaby",
	['Foe Lullaby II'] = "Lullaby",
}

BlueMagicExtendedInfo = {
    [513] = {id=513,en="Venom Shell",blue_type="Magical",spell_type="Attack",target_type="AoE",monster_type="Aquans"},
    [515] = {id=515,en="Maelstrom",blue_type="Magical",spell_type="Attack",target_type="AoE",monster_type="Aquans"},
    [517] = {id=517,en="Metallic Body",blue_type="Magical",spell_type="Buff",target_type="Self",monster_type="Aquans"},
    [519] = {id=519,en="Screwdriver",blue_type="Physical",spell_type="Attack",target_type="Single",monster_type="Aquans",wsc_primary="STR",wsc_secondary="MND"},
    [521] = {id=521,en="MP Drainkiss",blue_type="Magical",spell_type="Attack",target_type="Single",monster_type="Amorphs"},
    [522] = {id=522,en="Death Ray",blue_type="Magical",spell_type="Attack",target_type="Single",monster_type="Amorphs"},
    [524] = {id=524,en="Sandspin",blue_type="Magical",spell_type="Attack",target_type="Single",monster_type="Amorphs"},
    [527] = {id=527,en="Smite of Rage",blue_type="Physical",spell_type="Attack",target_type="Single",monster_type="Arcana",wsc_primary="STR",wsc_secondary="DEX"},
    [529] = {id=529,en="Bludgeon",blue_type="Physical",spell_type="Attack",target_type="Single",monster_type="Arcana",wsc_primary="CHR"},
    [530] = {id=530,en="Refueling",blue_type="Magical",spell_type="Buff",target_type="Self",monster_type="Arcana"},
    [531] = {id=531,en="Ice Break",blue_type="Magical",spell_type="Attack",target_type="AoE",monster_type="Arcana"},
    [532] = {id=532,en="Blitzstrahl",blue_type="Magical",spell_type="Attack",target_type="Single",monster_type="Arcana"},
    [533] = {id=533,en="Self-Destruct",blue_type="Magical",spell_type="Attack",target_type="AoE",monster_type="Arcana"},
    [534] = {id=534,en="Mysterious Light",blue_type="Magical",spell_type="Attack",target_type="AoE",monster_type="Arcana"},
    [535] = {id=535,en="Cold Wave",blue_type="Magical",spell_type="Attack",target_type="AoE",monster_type="Arcana"},
    [536] = {id=536,en="Poison Breath",blue_type="Magical",spell_type="Breath",target_type="AoE",monster_type="Undead"},
    [537] = {id=537,en="Stinking Gas",blue_type="Magical",spell_type="Attack",target_type="AoE",monster_type="Undead"},
    [538] = {id=538,en="Memento Mori",blue_type="Magical",spell_type="Buff",target_type="Self",monster_type="Undead"},
    [539] = {id=539,en="Terror Touch",blue_type="Physical",spell_type="Attack",target_type="Single",monster_type="Undead",wsc_primary="DEX",wsc_secondary="INT"},
    [540] = {id=540,en="Spinal Cleave",blue_type="Physical",spell_type="Attack",target_type="Single",monster_type="Undead",wsc_primary="STR"},
    [541] = {id=541,en="Blood Saber",blue_type="Magical",spell_type="Attack",target_type="AoE",monster_type="Undead"},
    [542] = {id=542,en="Digest",blue_type="Magical",spell_type="Attack",target_type="Single",monster_type="Amorphs"},
    [543] = {id=543,en="Mandibular Bite",blue_type="Physical",spell_type="Attack",target_type="Single",monster_type="Vermin",wsc_primary="STR",wsc_secondary="INT"},
    [544] = {id=544,en="Cursed Sphere",blue_type="Magical",spell_type="Attack",target_type="AoE",monster_type="Vermin"},
    [545] = {id=545,en="Sickle Slash",blue_type="Physical",spell_type="Attack",target_type="Single",monster_type="Vermin",wsc_primary="DEX"},
    [547] = {id=547,en="Cocoon",blue_type="Magical",spell_type="Buff",target_type="Self",monster_type="Vermin"},
    [548] = {id=548,en="Filamented Hold",blue_type="Magical",spell_type="Attack",target_type="AoE",monster_type="Vermin"},
    [549] = {id=549,en="Pollen",blue_type="Magical",spell_type="Cure",target_type="Self",monster_type="Vermin"},
    [551] = {id=551,en="Power Attack",blue_type="Physical",spell_type="Attack",target_type="Single",monster_type="Vermin",wsc_primary="STR",wsc_secondary="VIT"},
    [554] = {id=554,en="Death Scissors",blue_type="Physical",spell_type="Attack",target_type="Single",monster_type="Vermin",wsc_primary="STR"},
    [555] = {id=555,en="Magnetite Cloud",blue_type="Magical",spell_type="Breath",target_type="Single",monster_type="Beastmen"},
    [557] = {id=557,en="Eyes On Me",blue_type="Magical",spell_type="Attack",target_type="Single",monster_type="Demons"},
    [560] = {id=560,en="Frenetic Rip",blue_type="Physical",spell_type="Attack",target_type="Single",monster_type="Demons",wsc_primary="STR",wsc_secondary="DEX"},
    [561] = {id=561,en="Frightful Roar",blue_type="Magical",spell_type="Attack",target_type="AoE",monster_type="Demons"},
    [563] = {id=563,en="Hecatomb Wave",blue_type="Magical",spell_type="Breath",target_type="AoE",monster_type="Demons"},
    [564] = {id=564,en="Body Slam",blue_type="Physical",spell_type="Attack",target_type="AoE",monster_type="Dragons",wsc_primary="VIT"},
    [565] = {id=565,en="Radiant Breath",blue_type="Magical",spell_type="Breath",target_type="Single",monster_type="Dragons"},
    [567] = {id=567,en="Helldive",blue_type="Physical",spell_type="Attack",target_type="Single",monster_type="Birds",wsc_primary="AGI"},
    [569] = {id=569,en="Jet Stream",blue_type="Physical",spell_type="Attack",target_type="Single",monster_type="Birds",wsc_primary="AGI"},
    [570] = {id=570,en="Blood Drain",blue_type="Magical",spell_type="Attack",target_type="Single",monster_type="Birds"},
    [572] = {id=572,en="Sound Blast",blue_type="Magical",spell_type="Attack",target_type="AoE",monster_type="Birds"},
    [573] = {id=573,en="Feather Tickle",blue_type="Magical",spell_type="Attack",target_type="Single",monster_type="Birds"},
    [574] = {id=574,en="Feather Barrier",blue_type="Magical",spell_type="Buff",target_type="Self",monster_type="Birds"},
    [575] = {id=575,en="Jettatura",blue_type="Magical",spell_type="Attack",target_type="AoE",monster_type="Birds"},
    [576] = {id=576,en="Yawn",blue_type="Magical",spell_type="Attack",target_type="AoE",monster_type="Birds"},
    [577] = {id=577,en="Foot Kick",blue_type="Physical",spell_type="Attack",target_type="Single",monster_type="Beasts",wsc_primary="STR",wsc_secondary="DEX"},
    [578] = {id=578,en="Wild Carrot",blue_type="Magical",spell_type="Cure",target_type="Single",monster_type="Beasts"},
    [579] = {id=579,en="Voracious Trunk",blue_type="Magical",spell_type="Attack",target_type="Single",monster_type="Beasts"},
    [581] = {id=581,en="Healing Breeze",blue_type="Magical",spell_type="Cure",target_type="Self",monster_type="Beasts"},
    [582] = {id=582,en="Chaotic Eye",blue_type="Magical",spell_type="Attack",target_type="Single",monster_type="Beasts"},
    [584] = {id=584,en="Sheep Song",blue_type="Magical",spell_type="Attack",target_type="AoE",monster_type="Beasts"},
    [585] = {id=585,en="Ram Charge",blue_type="Physical",spell_type="Attack",target_type="Single",monster_type="Beasts",wsc_primary="MND",wsc_secondary="STR"},
    [587] = {id=587,en="Claw Cyclone",blue_type="Physical",spell_type="Attack",target_type="AoE",monster_type="Beasts",wsc_primary="DEX"},
    [588] = {id=588,en="Lowing",blue_type="Magical",spell_type="Attack",target_type="AoE",monster_type="Beasts"},
    [589] = {id=589,en="Dimensional Death",blue_type="Physical",spell_type="Attack",target_type="Single",monster_type="Undead",wsc_primary="STR"},
    [591] = {id=591,en="Heat Breath",blue_type="Magical",spell_type="Breath",target_type="AoE",monster_type="Beasts"},
    [592] = {id=592,en="Blank Gaze",blue_type="Magical",spell_type="Attack",target_type="Single",monster_type="Beasts"},
    [593] = {id=593,en="Magic Fruit",blue_type="Magical",spell_type="Cure",target_type="Single",monster_type="Beasts"},
    [594] = {id=594,en="Uppercut",blue_type="Physical",spell_type="Attack",target_type="Single",monster_type="Plantoids",wsc_primary="STR"},
    [595] = {id=595,en="1000 Needles",blue_type="Magical",spell_type="Attack",target_type="AoE",monster_type="Plantoids"},
    [596] = {id=596,en="Pinecone Bomb",blue_type="Physical",spell_type="Attack",target_type="Single",monster_type="Plantoids",wsc_primary="STR",wsc_secondary="AGI"},
    [597] = {id=597,en="Sprout Smack",blue_type="Physical",spell_type="Attack",target_type="Single",monster_type="Plantoids",wsc_primary="VIT"},
    [598] = {id=598,en="Soporific",blue_type="Magical",spell_type="Attack",target_type="AoE",monster_type="Plantoids"},
    [599] = {id=599,en="Queasyshroom",blue_type="Physical",spell_type="Attack",target_type="Single",monster_type="Plantoids",wsc_primary="INT"},
    [603] = {id=603,en="Wild Oats",blue_type="Physical",spell_type="Attack",target_type="Single",monster_type="Plantoids",wsc_primary="AGI"},
    [604] = {id=604,en="Bad Breath",blue_type="Magical",spell_type="Breath",target_type="AoE",monster_type="Plantoids"},
    [605] = {id=605,en="Geist Wall",blue_type="Magical",spell_type="Attack",target_type="AoE",monster_type="Lizards"},
    [606] = {id=606,en="Awful Eye",blue_type="Magical",spell_type="Attack",target_type="AoE",monster_type="Lizards"},
    [608] = {id=608,en="Frost Breath",blue_type="Magical",spell_type="Breath",target_type="Single",monster_type="Lizards"},
    [610] = {id=610,en="Infrasonics",blue_type="Magical",spell_type="Attack",target_type="AoE",monster_type="Lizards"},
    [611] = {id=611,en="Disseverment",blue_type="Physical",spell_type="Attack",target_type="Single",monster_type="Luminians",wsc_primary="STR",wsc_secondary="DEX"},
    [612] = {id=612,en="Actinic Burst",blue_type="Magical",spell_type="Attack",target_type="AoE",monster_type="Luminians"},
    [613] = {id=613,en="Reactor Cool",blue_type="Magical",spell_type="Buff",target_type="Self",monster_type="Luminians"},
    [614] = {id=614,en="Saline Coat",blue_type="Magical",spell_type="Buff",target_type="Self",monster_type="Luminians"},
    [615] = {id=615,en="Plasma Charge",blue_type="Magical",spell_type="Buff",target_type="Self",monster_type="Luminians"},
    [616] = {id=616,en="Temporal Shift",blue_type="Magical",spell_type="Attack",target_type="AoE",monster_type="Luminians"},
    [617] = {id=617,en="Vertical Cleave",blue_type="Physical",spell_type="Attack",target_type="Single",monster_type="Luminians",wsc_primary="STR"},
    [618] = {id=618,en="Blastbomb",blue_type="Magical",spell_type="Attack",target_type="AoE",monster_type="Beastmen"},
    [620] = {id=620,en="Battle Dance",blue_type="Physical",spell_type="Attack",target_type="AoE",monster_type="Beastmen",wsc_primary="STR"},
    [621] = {id=621,en="Sandspray",blue_type="Magical",spell_type="Attack",target_type="AoE",monster_type="Beastmen"},
    [622] = {id=622,en="Grand Slam",blue_type="Physical",spell_type="Attack",target_type="AoE",monster_type="Beastmen",wsc_primary="VIT"},
    [623] = {id=623,en="Head Butt",blue_type="Physical",spell_type="Attack",target_type="Single",monster_type="Beastmen",wsc_primary="STR",wsc_secondary="INT"},
    [626] = {id=626,en="Bomb Toss",blue_type="Magical",spell_type="Attack",target_type="AoE",monster_type="Beastmen"},
    [628] = {id=628,en="Frypan",blue_type="Physical",spell_type="Attack",target_type="AoE",monster_type="Beastmen",wsc_primary="STR",wsc_secondary="MND"},
    [629] = {id=629,en="Flying Hip Press",blue_type="Magical",spell_type="Breath",target_type="AoE",monster_type="Beastmen"},
    [631] = {id=631,en="Hydro Shot",blue_type="Physical",spell_type="Attack",target_type="Single",monster_type="Beastmen",wsc_primary="AGI"},
    [632] = {id=632,en="Diamondhide",blue_type="Magical",spell_type="Buff",target_type="Self",monster_type="Beastmen"},
    [633] = {id=633,en="Enervation",blue_type="Magical",spell_type="Attack",target_type="AoE",monster_type="Beastmen"},
    [634] = {id=634,en="Light of Penance",blue_type="Magical",spell_type="Attack",target_type="Single",monster_type="Beastmen"},
    [636] = {id=636,en="Warm-Up",blue_type="Magical",spell_type="Buff",target_type="Self",monster_type="Beastmen"},
    [637] = {id=637,en="Firespit",blue_type="Magical",spell_type="Attack",target_type="Single",monster_type="Beastmen"},
    [638] = {id=638,en="Feather Storm",blue_type="Physical",spell_type="Attack",target_type="Single",monster_type="Beastmen",wsc_primary="AGI"},
    [640] = {id=640,en="Tail Slap",blue_type="Physical",spell_type="Attack",target_type="AoE",monster_type="Beastmen",wsc_primary="VIT",wsc_secondary="STR"},
    [641] = {id=641,en="Hysteric Barrage",blue_type="Physical",spell_type="Attack",target_type="Single",monster_type="Beastmen",wsc_primary="DEX"},
    [642] = {id=642,en="Amplification",blue_type="Magical",spell_type="Buff",target_type="Self",monster_type="Amorphs"},
    [643] = {id=643,en="Cannonball",blue_type="Physical",spell_type="Attack",target_type="Single",monster_type="Vermin",wsc_primary="STR",wsc_secondary="VIT"},
    [644] = {id=644,en="Mind Blast",blue_type="Magical",spell_type="Attack",target_type="Single",monster_type="Demons"},
    [645] = {id=645,en="Exuviation",blue_type="Magical",spell_type="Cure",target_type="Self",monster_type="Vermin"},
    [646] = {id=646,en="Magic Hammer",blue_type="Magical",spell_type="Attack",target_type="Single",monster_type="Beastmen"},
    [647] = {id=647,en="Zephyr Mantle",blue_type="Magical",spell_type="Buff",target_type="Self",monster_type="Dragons"},
    [648] = {id=648,en="Regurgitation",blue_type="Magical",spell_type="Attack",target_type="Single",monster_type="Lizards"},
    [650] = {id=650,en="Seedspray",blue_type="Physical",spell_type="Attack",target_type="Single",monster_type="Plantoids",wsc_primary="DEX"},
    [651] = {id=651,en="Corrosive Ooze",blue_type="Magical",spell_type="Attack",target_type="AoE",monster_type="Amorphs"},
    [652] = {id=652,en="Spiral Spin",blue_type="Physical",spell_type="Attack",target_type="Single",monster_type="Vermin",wsc_primary="AGI"},
    [653] = {id=653,en="Asuran Claws",blue_type="Physical",spell_type="Attack",target_type="Single",monster_type="Beasts",wsc_primary="STR",wsc_secondary="DEX"},
    [654] = {id=654,en="Sub-zero Smash",blue_type="Physical",spell_type="Attack",target_type="AoE",monster_type="Aquans",wsc_primary="VIT"},
    [655] = {id=655,en="Triumphant Roar",blue_type="Magical",spell_type="Buff",target_type="Self",monster_type="Demons"},
    [656] = {id=656,en="Acrid Stream",blue_type="Magical",spell_type="Attack",target_type="AoE",monster_type="Vorageans"},
    [657] = {id=657,en="Blazing Bound",blue_type="Magical",spell_type="Attack",target_type="Single",monster_type="Vorageans"},
    [658] = {id=658,en="Plenilune Embrace",blue_type="Magical",spell_type="Cure",target_type="Single",monster_type="Beasts"},
    [659] = {id=659,en="Demoralizing Roar",blue_type="Magical",spell_type="Attack",target_type="AoE",monster_type="Lizards"},
    [660] = {id=660,en="Cimicine Discharge",blue_type="Magical",spell_type="Attack",target_type="AoE",monster_type="Vermin"},
    [661] = {id=661,en="Animating Wail",blue_type="Magical",spell_type="Buff",target_type="Self",monster_type="Undead"},
    [662] = {id=662,en="Battery Charge",blue_type="Magical",spell_type="Buff",target_type="Self",monster_type="Arcana"},
    [663] = {id=663,en="Leafstorm",blue_type="Magical",spell_type="Attack",target_type="AoE",monster_type="Plantoids"},
    [664] = {id=664,en="Regeneration",blue_type="Magical",spell_type="Buff",target_type="Self",monster_type="Aquans"},
    [665] = {id=665,en="Final Sting",blue_type="Physical",spell_type="Attack",target_type="Single",monster_type="Vermin"},
    [666] = {id=666,en="Goblin Rush",blue_type="Physical",spell_type="Attack",target_type="Single",monster_type="Beastmen",wsc_primary="STR",wsc_secondary="DEX"},
    [667] = {id=667,en="Vanity Dive",blue_type="Physical",spell_type="Attack",target_type="Single",monster_type="Empty",wsc_primary="DEX"},
    [668] = {id=668,en="Magic Barrier",blue_type="Magical",spell_type="Buff",target_type="Self",monster_type="Demons"},
    [669] = {id=669,en="Whirl of Rage",blue_type="Physical",spell_type="Attack",target_type="AoE",monster_type="Arcana",wsc_primary="STR",wsc_secondary="MND"},
    [670] = {id=670,en="Benthic Typhoon",blue_type="Physical",spell_type="Attack",target_type="AoE",monster_type="Vorageans",wsc_primary="AGI"},
    [671] = {id=671,en="Auroral Drape",blue_type="Magical",spell_type="Attack",target_type="AoE",monster_type="Empty"},
    [672] = {id=672,en="Osmosis",blue_type="Magical",spell_type="Attack",target_type="Single",monster_type="Vorageans"},
    [673] = {id=673,en="Quad. Continuum",blue_type="Physical",spell_type="Attack",target_type="Single",monster_type="Empty",wsc_primary="STR",wsc_secondary="VIT"},
    [674] = {id=674,en="Fantod",blue_type="Magical",spell_type="Buff",target_type="Self",monster_type="Birds"},
    [675] = {id=675,en="Thermal Pulse",blue_type="Magical",spell_type="Attack",target_type="AoE",monster_type="Vermin"},
    [677] = {id=677,en="Empty Thrash",blue_type="Physical",spell_type="Attack",target_type="AoE",monster_type="Empty",wsc_primary="STR"},
    [678] = {id=678,en="Dream Flower",blue_type="Magical",spell_type="Attack",target_type="AoE",monster_type="Plantoids"},
    [679] = {id=679,en="Occultation",blue_type="Magical",spell_type="Buff",target_type="Self",monster_type="Empty"},
    [680] = {id=680,en="Charged Whisker",blue_type="Magical",spell_type="Attack",target_type="AoE",monster_type="Beasts"},
    [681] = {id=681,en="Winds of Promy.",blue_type="Magical",spell_type="Buff",target_type="AoE",monster_type="Empty"},
    [682] = {id=682,en="Delta Thrust",blue_type="Physical",spell_type="Attack",target_type="Single",monster_type="Lizards",wsc_primary="VIT",wsc_secondary="STR"},
    [683] = {id=683,en="Evryone. Grudge",blue_type="Magical",spell_type="Attack",target_type="Single",monster_type="Beastmen"},
    [684] = {id=684,en="Reaving Wind",blue_type="Magical",spell_type="Attack",target_type="AoE",monster_type="Birds"},
    [685] = {id=685,en="Barrier Tusk",blue_type="Magical",spell_type="Buff",target_type="Self",monster_type="Beasts"},
    [686] = {id=686,en="Mortal Ray",blue_type="Magical",spell_type="Attack",target_type="Single",monster_type="Demons"},
    [687] = {id=687,en="Water Bomb",blue_type="Magical",spell_type="Attack",target_type="AoE",monster_type="Beastmen"},
    [688] = {id=688,en="Heavy Strike",blue_type="Physical",spell_type="Attack",target_type="Single",monster_type="Arcana",wsc_primary="STR"},
    [689] = {id=689,en="Dark Orb",blue_type="Magical",spell_type="Attack",target_type="Single",monster_type="Demons"},
    [690] = {id=690,en="White Wind",blue_type="Magical",spell_type="Cure",target_type="Self",monster_type="Dragons"},
    [692] = {id=692,en="Sudden Lunge",blue_type="Physical",spell_type="Attack",target_type="Single",monster_type="Vermin",wsc_primary="AGI"},
    [693] = {id=693,en="Quadrastrike",blue_type="Physical",spell_type="Attack",target_type="Single",monster_type="Demons",wsc_primary="STR"},
    [694] = {id=694,en="Vapor Spray",blue_type="Magical",spell_type="Breath",target_type="AoE",monster_type="Luminians"},
    [695] = {id=695,en="Thunder Breath",blue_type="Magical",spell_type="Breath",target_type="AoE",monster_type="Dragons"},
    [696] = {id=696,en="O. Counterstance",blue_type="Magical",spell_type="Buff",target_type="Self",monster_type="Beastmen"},
    [697] = {id=697,en="Amorphic Spikes",blue_type="Physical",spell_type="Attack",target_type="Single",monster_type="Amorphs",wsc_primary="DEX",wsc_secondary="INT"},
    [698] = {id=698,en="Wind Breath",blue_type="Magical",spell_type="Breath",target_type="AoE",monster_type="Dragons"},
    [699] = {id=699,en="Barbed Crescent",blue_type="Physical",spell_type="Attack",target_type="Single",monster_type="Undead",wsc_primary="DEX"},
    [700] = {id=700,en="Nat. Meditation",blue_type="Magical",spell_type="Buff",target_type="Self",monster_type="Vermin"},
    [701] = {id=701,en="Tem. Upheaval",blue_type="Magical",spell_type="Attack",target_type="AoE",monster_type="Vermin"},
    [702] = {id=702,en="Rending Deluge",blue_type="Magical",spell_type="Attack",target_type="AoE",monster_type="Aquans"},
    [703] = {id=703,en="Embalming Earth",blue_type="Magical",spell_type="Attack",target_type="AoE",monster_type="Lizards"},
    [704] = {id=704,en="Paralyzing Triad",blue_type="Physical",spell_type="Attack",target_type="Single",monster_type="Elementals",wsc_primary="STR",wsc_secondary="DEX"},
    [705] = {id=705,en="Foul Waters",blue_type="Magical",spell_type="Attack",target_type="AoE",monster_type="Amorphs"},
    [706] = {id=706,en="Glutinous Dart",blue_type="Physical",spell_type="Attack",target_type="Single",monster_type="Beastmen",wsc_primary="STR",wsc_secondary="VIT"},
    [707] = {id=707,en="Retinal Glare",blue_type="Magical",spell_type="Attack",target_type="AoE",monster_type="Plantoids"},
    [708] = {id=708,en="Subduction",blue_type="Magical",spell_type="Attack",target_type="AoE",monster_type="Arcana"},
    [709] = {id=709,en="Thrashing Assault",blue_type="Physical",spell_type="Attack",target_type="Single",monster_type="Beastmen",wsc_primary="STR",wsc_secondary="DEX"},
    [710] = {id=710,en="Erratic Flutter",blue_type="Magical",spell_type="Buff",target_type="Self",monster_type="Vermin"},
    [711] = {id=711,en="Restoral",blue_type="Magical",spell_type="Cure",target_type="Self",monster_type="Archaic Machines"},
    [712] = {id=712,en="Rail Cannon",blue_type="Magical",spell_type="Attack",target_type="Single",monster_type="Archaic Machines"},
    [713] = {id=713,en="Diffusion Ray",blue_type="Magical",spell_type="Attack",target_type="AoE",monster_type="Archaic Machines"},
    [714] = {id=714,en="Sinker Drill",blue_type="Physical",spell_type="Attack",target_type="Single",monster_type="Arcana",wsc_primary="STR",wsc_secondary="VIT"},
    [715] = {id=715,en="Molting Plumage",blue_type="Magical",spell_type="Attack",target_type="AoE",monster_type="Birds"},
    [716] = {id=716,en="Nectarous Deluge",blue_type="Magical",spell_type="Attack",target_type="AoE",monster_type="Plantoids"},
    [717] = {id=717,en="Sweeping Gouge",blue_type="Physical",spell_type="Attack",target_type="Single",monster_type="Beasts",wsc_primary="VIT"},
    [718] = {id=718,en="Atra. Libations",blue_type="Magical",spell_type="Attack",target_type="AoE",monster_type="Undead"},
    [719] = {id=719,en="Searing Tempest",blue_type="Magical",spell_type="Attack",target_type="AoE",monster_type="Elementals"},
    [720] = {id=720,en="Spectral Floe",blue_type="Magical",spell_type="Attack",target_type="AoE",monster_type="Elementals"},
    [721] = {id=721,en="Anvil Lightning",blue_type="Magical",spell_type="Attack",target_type="AoE",monster_type="Elementals"},
    [722] = {id=722,en="Entomb",blue_type="Magical",spell_type="Attack",target_type="AoE",monster_type="Elementals"},
    [723] = {id=723,en="Saurian Slide",blue_type="Physical",spell_type="Attack",target_type="Single",monster_type="Beastmen"},
    [724] = {id=724,en="Palling Salvo",blue_type="Magical",spell_type="Attack",target_type="AoE",monster_type="Vermin"},
    [725] = {id=725,en="Blinding Fulgor",blue_type="Magical",spell_type="Attack",target_type="AoE",monster_type="Elementals"},
    [726] = {id=726,en="Scouring Spate",blue_type="Magical",spell_type="Attack",target_type="AoE",monster_type="Elementals"},
    [727] = {id=727,en="Silent Storm",blue_type="Magical",spell_type="Attack",target_type="AoE",monster_type="Elementals"},
    [728] = {id=728,en="Tenebral Crush",blue_type="Magical",spell_type="Attack",target_type="AoE",monster_type="Elementals"},
    [736] = {id=736,en="Thunderbolt",blue_type="Magical",spell_type="Attack",target_type="AoE",monster_type="Beasts"},
    [737] = {id=737,en="Harden Shell",blue_type="Magical",spell_type="Buff",target_type="Self",monster_type="Lizards"},
    [738] = {id=738,en="Absolute Terror",blue_type="Magical",spell_type="Attack",target_type="Single",monster_type="Dragons"},
    [739] = {id=739,en="Gates of Hades",blue_type="Magical",spell_type="Attack",target_type="AoE",monster_type="Beasts"},
    [740] = {id=740,en="Tourbillion",blue_type="Physical",spell_type="Attack",target_type="AoE",monster_type="Arcana",wsc_primary="STR",wsc_secondary="MND"},
    [741] = {id=741,en="Pyric Bulwark",blue_type="Magical",spell_type="Buff",target_type="Self",monster_type="Lizards"},
    [742] = {id=742,en="Bilgestorm",blue_type="Physical",spell_type="Attack",target_type="AoE",monster_type="Demons"},
    [743] = {id=743,en="Bloodrake",blue_type="Physical",spell_type="Attack",target_type="Single",monster_type="Undead",wsc_primary="STR",wsc_secondary="MND"},
    [744] = {id=744,en="Droning Whirlwind",blue_type="Magical",spell_type="Attack",target_type="AoE",monster_type="Vermin"},
    [745] = {id=745,en="Carcharian Verve",blue_type="Magical",spell_type="Buff",target_type="Self",monster_type="Aquans"},
    [746] = {id=746,en="Blistering Roar",blue_type="Magical",spell_type="Attack",target_type="AoE",monster_type="Lizards"},
    [747] = {id=747,en="Uproot",blue_type="Magical",spell_type="Attack",target_type="AoE",monster_type="Plantoids"},
    [748] = {id=748,en="Crashing Thunder",blue_type="Magical",spell_type="Attack",target_type="AoE",monster_type="Birds"},
    [749] = {id=749,en="Polar Roar",blue_type="Magical",spell_type="Attack",target_type="AoE",monster_type="Beasts"},
    [750] = {id=750,en="Mighty Guard",blue_type="Magical",spell_type="Buff",target_type="Self",monster_type="Dragons"},
    [751] = {id=751,en="Cruel Joke",blue_type="Magical",spell_type="Attack",target_type="AoE",monster_type="Undead"},
    [752] = {id=752,en="Cesspool",blue_type="Magical",spell_type="Attack",target_type="AoE",monster_type="Amorphs"},
    [753] = {id=753,en="Tearing Gust",blue_type="Magical",spell_type="Attack",target_type="AoE",monster_type="Elementals"},
}