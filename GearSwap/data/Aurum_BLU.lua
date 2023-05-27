include('SetLayers')

function job_setup()
	layers = {
		base = {
			Idle = {
				ALL = {
					main="Naegling",
					sub="Culminus",
					range=empty,
					ammo="Ginsen",
					head="Nyame Helm",
					body="Hashishin Mintan +2",
					hands="Nyame Gauntlets",
					legs="Nyame Flanchard",
					feet="Nyame Sollerets",
					neck="Sibyl Scarf",
					waist="Sailfi Belt +1",
					left_ear="Brutal Earring",
					right_ear="Magnetic Earring",
					left_ring="Defending Ring",
					right_ring="Shneddick Ring",
					back="Cornflower Cape",
				},
				DNC = {
					sub="Mimesis",
					right_ear="Suppanomimi",
				},
				THF = {
					sub="Mimesis",
					right_ear="Suppanomimi",
				},
			},
			Engaged = {
				neck="Sanctity Necklace",
				left_ring="Rajas Ring",
				right_ring="Enlivened Ring",
			},
			Resting = {
				body="Yigit Gomlek",
				left_ear="Relaxing Earring",
				right_ear="Magnetic Earring",
				neck="Eidolon Pendant +1",
				waist="Hierarch Belt",
			},
			Precast = {
				DefaultMagic = {
					ammo="Sapience Orb",             --2%
					head="Amalric Coif",             --10%
					body="Hashishin Mintan +2",      --15%
					feet="Amalric Nails",            --5%
					neck="Voltsurge Torque",         --4%
					waist="Witful Belt",             --3%
					left_ear="Loquac. Earring",      --2%
					right_ear="Enchntr. Earring +1", --2%
					left_ring="Kishar Ring",         --4%
				},                                   --47% fast cast total
			},
			Midcast = {
				BlueMagicalAttack = {
					head="Jhakri Coronal +2",
					body="Hashishin Mintan +2",
					hands="Jhakri Cuffs +2",
					legs="Jhakri Slops +2",
					feet="Jhakri Pigaches +2",
					neck="Sibyl Scarf",
					left_ear="Regal Earring",
					right_ear="Friomisi Earring",
					left_ring="Shiva Ring",
					right_ring="Shiva Ring",
					waist="Eschan Stone",
				},
				BluePhysical = {
					neck="Fotia Gorget",
					waist="Fotia Belt",
					right_ear="Moonshade Earring"
				},
				BlueSTR = {
					left_ring="Rajas Ring",
					right_ring="Rufescent Ring",
				},
				Diffusion = {
					feet="Luhlaza Charuqs",
				},
				WeaponSkill = {
					ammo="Oshasha's Treatise",
					neck="Fotia Gorget",
					waist="Fotia Belt",
					left_ring="Vehemence Ring",
					right_ear="Moonshade Earring",
				},
			}
		},
		Ranged = {
			range="Aureole",
			ammo=empty,
			Precast = {
				DefaultMagic = {
					ammo=empty,
				}
			}
		},
		LowDamage = {
			main="Bronze Sword",
			DNC = {
				sub="Bronze Sword",
			},
			NIN = {
				sub="Bronze Sword",
			},
			THF = {
				sub="Bronze Sword",
			},
		},	
		ForceClub = {
			DNC = {
				sub="Maxentius",
			},
			NIN = {
				sub="Maxentius",
			},
			THF = {
				sub="Maxentius",
			},
		},
		ForceClubMain = {
			main="Maxentius",
			DNC = {
				sub="Nibiru Cudgel",
			},
			NIN = {
				sub="Nibiru Cudgel",
			},
			THF = {
				sub="Nibiru Cudgel",
			},
		},	
		Learning = {
			hands="Magus Bazubands",
		},
		Crafting = {
			body="Goldsmith's Smock",
			head="Shaded Specs.",
			neck="Goldsm. Torque",
			left_ring="Craftkeeper's Ring",
			right_ring="Artificer's Ring",
		},
		TH = {
			Idle = {
				head="Wh. Rarab Cap +1",
				waist="Chaac Belt",
			},
			BlueMagicalAttack = {
				head="Wh. Rarab Cap +1",
				waist="Chaac Belt",
			},
		},
	}

	stances = {
		[2] = {
			[1] = "LowDamage",
			[2] = "ForceClub",
		},
		[99] = {
			[1] = "Crafting",
			[2] = "TH",
		},
	}
end
