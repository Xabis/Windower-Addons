include('SetLayers')

function job_setup()
	layers = {
		base = {
			Idle = {
				ALL = {
					main="Naegling",
					sub="Nusku Shield",
					range="Death Penalty",
					ammo="Living Bullet",
					head="Nyame Helm",
					body="Nyame Mail",
					hands="Nyame Gauntlets",
					legs="Nyame Flanchard",
					feet="Nyame Sollerets",
					neck="Comm. Charm +1",
					waist="Flume Belt +1",
					left_ear="Brutal Earring",
					right_ear="Cessance Earring",
					left_ring="Defending Ring",
					right_ring="Shneddick Ring",
					back={ name="Camulus's Mantle", augments={'DEX+20','Accuracy+20 Attack+20','DEX+10','"Dbl.Atk."+10','Phys. dmg. taken-10%',}},
				},
				DNC = {
					sub="Tauret",
					left_ear="Eabani Earring",
					right_ear="Suppanomimi",
				},
				NIN = {
					sub="Tauret",
					left_ear="Eabani Earring",
					right_ear="Suppanomimi",
				}
			},
			Engaged = {
				head="Malignance Chapeau",
				feet="Malignance Boots",
				waist="Sailfi Belt +1",
				left_ring="Epona's Ring",
				right_ring="Petrov Ring",
			},
			Precast = {
				Ranged = {
					head="Chass. Tricorne +1",
					feet="Meg. Jam. +2",
					hands="Lanun Gants +1",
				},
			},
			Midcast = {
				WeaponSkill = {
					head="Nyame Helm",
					body="Laksa. Frac +3",
					hands="Meg. Gloves +2",
					feet="Lanun Bottes +2",
					left_ear="Ishvara Earring",
					right_ear="Moonshade Earring",
					left_ring="Regal Ring",
					right_ring="Rufescent Ring",
					back={ name="Camulus's Mantle", augments={'STR+20','Accuracy+20 Attack+20','STR+10','Weapon skill damage +10%',}},
				},
				Ranged = {
					head="Malignance Chapeau",
					hands="Nyame Gauntlets",
					feet="Malignance Boots",
					waist="Sailfi Belt +1",
					left_ear="Volley Earring",
					right_ear="Neritic Earring",
					left_ring="Regal Ring",
					right_ring="Dingir Ring",
				},
				Requiescat = {
					neck="Fotia Gorget",
				},
				Evisceration = {
					neck="Fotia Gorget",
				},
				WildFire = {
					body="Lanun Frac +3",
					right_ring="Dingir Ring",
					back={ name="Camulus's Mantle", augments={'AGI+20','Mag. Acc+20 /Mag. Dmg.+20','AGI+10','Weapon skill damage +10%',}},
				},
				LeadenSalute = {
					head="Pixie Hairpin +1",
					body="Lanun Frac +3",
					waist="Eschan Stone",
					left_ear="Friomisi Earring",
					left_ring="Archon Ring",
					right_ring="Dingir Ring",
					back={ name="Camulus's Mantle", augments={'AGI+20','Mag. Acc+20 /Mag. Dmg.+20','AGI+10','Weapon skill damage +10%',}},
				},
				LastStand = {
					head="Lanun Tricorne +2",
					neck="Fotia Gorget",
					waist="Fotia Belt",
					right_ring="Dingir Ring",
					back={ name="Camulus's Mantle", augments={'AGI+20','Rng.Acc.+20 Rng.Atk.+20','AGI+10','Weapon skill damage +10%',}},
				},
				AeolianEdge = {
					body="Lanun Frac +3",
					waist="Eschan Stone",
					left_ear="Friomisi Earring",
					right_ring="Dingir Ring",
				},
				CorsairRoll = {
					range="Compensator",
					head="Lanun Tricorne +2",
					hands="Chasseur's Gants +2",
					neck="Regal Necklace",
					left_ring="Luzaf's Ring",
				},
				Fold = {
					hands="Lanun Gants +1",
				},
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
			range=empty,
			ammo="Per. Lucky Egg",
			head="Wh. Rarab Cap +1",
			waist="Chaac Belt",
		},
		MovementSpeed = {
			right_ring="Shneddick Ring",
		},
		LowDamage = {
			--ammo="Bronze Bullet",
			--ammo="Orichalc. Bullet",
			main="Bronze Knife",
			DNC = {
				sub="Bronze Knife",
			},
			NIN = {
				sub="Bronze Knife",
			}
		},
		ExpCape = {
			back="Aptitude Mantle +1",
		},
		ForceShield = {
			NIN = {
				sub="Nusku Shield",
			},
			DNC = {
				sub="Nusku Shield",
			},
		},
	}
	
	stances = {
		[99] = {
			[1] = "Crafting",
			[2] = "TH",
		},
	}
	
	style = {
		DEFAULT = 17,
	}
end
