include('SetLayers')

function job_setup()
	layers = {
		base = {
			Idle = {
				ALL = {
					main="Gridarvor",
					sub="Enki Strap",
					ammo="Sancus Sachet +1",
					head="Convoker's Horn +2",
					body="Nyame Mail",
					hands="Nyame Gauntlets",
					legs="Nyame Flanchard",
					feet="Convo. Pigaches +2",
					neck="Sibyl Scarf",
					waist="Regal Belt",
					left_ear="Lugalbanda Earring",
					right_ear="Evans Earring",
					left_ring="Defending Ring",
					right_ring="Shneddick Ring",
					back={ name="Campestres's Cape", augments={'Pet: Acc.+20 Pet: R.Acc.+20 Pet: Atk.+20 Pet: R.Atk.+20','Pet: "Regen"+10',}},
				},
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
					feet="Amalric Nails",            --5%
					neck="Voltsurge Torque",         --4%
					waist="Witful Belt",             --3%
					left_ear="Malignance Earring",   --4%
					right_ear="Loquac. Earring",     --2%
					left_ring="Kishar Ring",         --4%
				},                                   --34% total
			},
			Midcast = {
				BloodPactWard = {
					body="Con. Doublet +2",
				},
				BloodPactRage = {
					body="Con. Doublet +2",
					feet="Convo. Pigaches +2",
					neck="Shulmanu Collar",
					waist="Regal Belt",
					left_ear="Lugalbanda Earring",
					right_ear="Gelos Earring",
					left_ring="Varar Ring +1",
					right_ring="Varar Ring +1",
					back={ name="Campestres's Cape", augments={'Pet: Acc.+20 Pet: R.Acc.+20 Pet: Atk.+20 Pet: R.Atk.+20','Pet: "Regen"+10',}},
				},
				FlamingCrush = {
					neck="Adad Amulet",
				},
				WeaponSkill = {
					neck="Fotia Gorget",
					waist="Eschan Stone",
					left_ring="Vehemence Ring",
					right_ear="Moonshade Earring",
				},
			}
		},
		DamageTaken = {
			head="Nyame Helm",
			body="Nyame Mail",
			hands="Nyame Gauntlets",
			legs="Nyame Flanchard",
			feet="Nyame Sollerets",
			left_ring="Defending Ring",
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
		},
		ForceClub = {
			main="Daybreak",
			sub="Chanter's Shield",
		}
	}

	stances = {
		[99] = {
			[1] = "Crafting",
			[2] = "TH",
		},
	}
end
