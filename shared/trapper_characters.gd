class_name TrapperCharacters

## Static data for the 4 trapper characters and their abilities.


static func get_all() -> Array[Dictionary]:
	return [
		{
			"id": Enums.TrapperCharacter.ARANA,
			"name": "SPIDER",
			"subtitle": "Movement control",
			"color": Enums.trapper_character_color(Enums.TrapperCharacter.ARANA),
			"abilities": [
				{"name": "Expansive Web", "desc": "Place 3 points to form a web zone that slows enemies inside.", "button": "A"},
				{"name": "Elastic Web", "desc": "Place 2 points to stretch a line that bounces enemies away.", "button": "RB"},
				{"name": "Persistent Venom", "desc": "Place a poison puddle. Allies can cure poisoned targets before death.", "button": "X"},
			],
		},
		{
			"id": Enums.TrapperCharacter.HONGO,
			"name": "MUSHROOM",
			"subtitle": "Status disruption",
			"color": Enums.trapper_character_color(Enums.TrapperCharacter.HONGO),
			"abilities": [
				{"name": "Confusing Mushroom", "desc": "Single-use trap that inverts enemy movement on contact.", "button": "A"},
				{"name": "Toxic Spores", "desc": "Slow enemies inside the cloud; poison them when they leave.", "button": "RB"},
				{"name": "Fungal Teleport", "desc": "Place 2 linked portals. Enter one to exit from the other.", "button": "X"},
			],
		},
		{
			"id": Enums.TrapperCharacter.ESCORPION,
			"name": "SCORPION",
			"subtitle": "Lethal control",
			"color": Enums.trapper_character_color(Enums.TrapperCharacter.ESCORPION),
			"abilities": [
				{"name": "Buried Stinger", "desc": "Place a faint hidden trap that poisons; fast movement drains faster.", "button": "A"},
				{"name": "Quicksand", "desc": "Pulls enemies to a tiny lethal center; changing direction helps escape.", "button": "RB"},
				{"name": "Crushing Pincers", "desc": "Place 2 toothed walls. Wider gaps snap shut faster and can crush.", "button": "X"},
			],
		},
		{
			"id": Enums.TrapperCharacter.PULPO,
			"name": "OCTOPUS",
			"subtitle": "Vision and movement manipulation",
			"color": Enums.trapper_character_color(Enums.TrapperCharacter.PULPO),
			"abilities": [
				{"name": "Ink Stain", "desc": "Create dark ink that blocks almost all vision inside.", "button": "A"},
				{"name": "Binding Tentacle", "desc": "Roots one enemy for 5s; linking another extends the effect.", "button": "RB"},
				{"name": "Water Current", "desc": "Place 2 points to push enemies strongly from start to end.", "button": "X"},
			],
		},
	]


static func get_by_id(tc: Enums.TrapperCharacter) -> Dictionary:
	for data: Dictionary in get_all():
		if (data["id"] as Enums.TrapperCharacter) == tc:
			return data
	return {}


static func get_ids() -> Array[Enums.TrapperCharacter]:
	return [
		Enums.TrapperCharacter.ARANA,
		Enums.TrapperCharacter.HONGO,
		Enums.TrapperCharacter.ESCORPION,
		Enums.TrapperCharacter.PULPO,
	]
