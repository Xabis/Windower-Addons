include('SetLayers')

--[[
COMMANDS:
gs c set <slot> <layer>    -- Assigns a layer to a specific slot
gs c unset <slot>          -- Removes any layer assigned to a slot
gs c toggle <slot> <layer> -- If the slot is using the specified layer, it is unset, otherwise it is set
gs c next <slot>           -- cycle slot stance forward
gs c prev <slot>           -- cycle slot stance backwards
gs c list stack            -- show what layers are currently applied

The <slot> is a number indicating the layer priority; higher numbers have higher priority.
Only one layer may be assiged to a slot at any given time.

Layers can be brought in at any time and assigned to any slot, regardless of stance setup.
You also have infinite stances and infinite slots. The same layer may be assigned to different slots.

For example, if you want to apply the "TH" layer you can just quickly type:
//gs c set 99 TH

MY MACROS:
/console gs c toggle 1 Ranged     -- Toggle the ranged set on/off
/console gs c next 2              -- Cycle Weapon sets
/console gs c next 3              -- Cycle TP sets
/console gs c toggle 2 ForceClub  -- Quick toggle for club specifically.
/console gs c toggle 2 ForcePole  -- Quick toggle for polearm specifically.
/console gs c unset               -- REMOVE ALL LAYERS (except base)
]]

function job_setup()
	layers = {
		base = {
			Idle = {
				ALL = {
					main="Instigator",
					sub="Utu Grip",
					range=empty,
					ammo="Ginsen",
					head="Sakpata's Helm",
					body="Sakpata's Plate",
					hands="Sakpata's Gauntlets",
					legs="Sakpata's Cuisses",
					feet="Sakpata's Leggings",
					neck="War. Beads +1",
					waist="Ioskeha Belt +1",
					left_ear="Brutal Earring",
					right_ear="Cessance Earring",
					left_ring="Defending Ring",
					right_ring="Shneddick Ring",
					back={ name="Cichol's Mantle", augments={'DEX+20','Accuracy+20 Attack+20','DEX+10','"Dbl.Atk."+10','Phys. dmg. taken-10%',}},
				},
				NIN = {
					main="Naegling",
					sub="Nibiru Tabar",
					right_ear="Suppanomimi",
				},
				DNC = {
					main="Naegling",
					sub="Nibiru Tabar",
					right_ear="Suppanomimi",
				},
				DRG = {
					main="Naegling",
					sub="Blurred Shield +1",
				},
				THF = {
					main="Naegling",
					sub="Blurred Shield +1",
				},
				WHM = {
					main="Naegling",
					sub="Blurred Shield +1",
				},
				BLU = {
					main="Naegling",
					sub="Blurred Shield +1",
				},
				BLM = {
					main="Naegling",
					sub="Blurred Shield +1",
				},
			},
			Engaged = {
				ALL = {
					left_ring="Rajas Ring",
					right_ring="Flamma Ring",
				}
			},
			Midcast = {
				ALL = {
					WeaponSkill = {
						ammo="Knobkierrie",
						head="Agoge Mask +3",
						neck="War. Beads +1",
						body="Pumm. Lorica +3",
						feet="Sulev. Leggings +2",
						left_ring="Regal Ring",
						left_ear="Thrud Earring",
						right_ear="Moonshade Earring",
						back={ name="Cichol's Mantle", augments={'STR+20','Accuracy+20 Attack+20','STR+10','Weapon skill damage +10%',}},
					},
					WarCry = {
						head="Agoge Mask +3",
					},
					Aggressor = {
						head="Pumm. Mask +1",
						body="Agoge Lorica +1",
					},
					Berserk = {
						body="Pumm. Lorica +3",
						feet="Agoge Calligae +1",
					},
				},
				SAM = {
					WeaponSkill = {
						neck="Fotia Gorget",
					},
				},
				DNC = {
					WeaponSkill = {
						neck="Fotia Gorget",
					},
				},
				NIN = {
					WeaponSkill = {
						neck="Fotia Gorget",
					},
				},
			},
		},
		Accuracy = {
			body="Pumm. Lorica +3",
			legs="Pumm. Cuisses +3",
		},
		DamageTaken = {
			head="Sakpata's Helm",
			body="Sakpata's Plate",
			hands="Sakpata's Gauntlets",
			legs="Sakpata's Cuisses",
			feet="Sakpata's Leggings",
			back={ name="Cichol's Mantle", augments={'DEX+20','Accuracy+20 Attack+20','DEX+10','"Dbl.Atk."+10','Phys. dmg. taken-10%',}},
		},
		Ranged = {
			range="Aureole",
			ammo=empty,
		},
		LowDamage = {
			ALL = {
				main="Bronze Sword",
			},
			DNC = {
				sub="Bronze Sword",
			},
			NIN = {
				sub="Bronze Sword",
			},
		},
		ForceGaxe = {
			Idle = {
				main="Instigator",
				sub="Utu Grip",
				NIN = {
					right_ear="Cessance Earring",
				},
				DNC = {
					right_ear="Cessance Earring",
				},
			},
			Midcast = {
				WeaponSkill = {
					neck="Fotia Gorget",
				}
			}
		},
		ForceSword = {
			Idle = {
				main="Naegling",
				sub="Blurred Shield +1",
			}
		},
		ForcePole = {
			Idle = {
				main="Shining One",
				sub="Utu Grip",
				NIN = {
					right_ear="Cessance Earring",
				},
				DNC = {
					right_ear="Cessance Earring",
				},
			},
			Midcast = {
				WeaponSkill = {
					neck="Fotia Gorget",
				}
			}
		},
		ForceClub = {
			main="Beryllium Mace",
		},
		ForceShield = {
			NIN = {
				sub="Blurred Shield +1",
			},
			DNC = {
				sub="Blurred Shield +1",
			},
			THF = {
				sub="Blurred Shield +1",
			},
		},
		Crafting = {
			body="Goldsmith's Smock",
			head="Shaded Specs.",
			neck="Goldsm. Torque",
			left_ring="Craftkeeper's Ring",
			right_ring="Artificer's Ring",
		},
		TH = {
			range=empty,
			ammo="Per. Lucky Egg",
			head="Wh. Rarab Cap +1",
			waist="Chaac Belt",
		},
		MovementSpeed = {
			right_ring="Shneddick Ring",
		},
		Death = {
			right_ring="Shadow Ring",
		},
		Trapper = {
			range="Soultrapper 2000",
			ammo="Blank Soulplate",
		},
	}

	stances = {
		[2] = {
			[1] = "LowDamage",
			[2] = "ForceGaxe",
			[3] = "ForceClub",
			[4] = "ForcePole",
		},
		[3] = {
			[1] = "DamageTaken",
			[2] = "Accuracy",
		},
		[99] = {
			[1] = "Crafting",
			[2] = "TH",
		},
	}

	style = {
		DEFAULT = 19,
	}
end
