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
				{"name": "Persistent Venom", "desc": "Drop a poison puddle. If allies do not touch the victim in time, they respawn.", "button": "A"},
				{"name": "Elastic Web", "desc": "Place 2 points to stretch a web line that throws enemies away on contact.", "button": "X"},
				{"name": "Expansive Web", "desc": "Place 3 points to create a large web zone that slows everyone inside.", "button": "Y"},
			],
		},
		{
			"id": Enums.TrapperCharacter.HONGO,
			"name": "MUSHROOM",
			"subtitle": "Status disruption",
			"color": Enums.trapper_character_color(Enums.TrapperCharacter.HONGO),
			"abilities": [
				{"name": "Confusing Mushroom", "desc": "Single-use trap that flips enemy movement controls for a few seconds.", "button": "A"},
				{"name": "Toxic Spores", "desc": "Create a cloud that slows enemies inside; leaving the cloud poisons them.", "button": "X"},
				{"name": "Fungal Teleport", "desc": "Place 2 linked portals. Step into one to instantly come out of the other.", "button": "Y"},
			],
		},
		{
			"id": Enums.TrapperCharacter.ESCORPION,
			"name": "SCORPION",
			"subtitle": "Lethal control",
			"color": Enums.trapper_character_color(Enums.TrapperCharacter.ESCORPION),
			"abilities": [
				{"name": "Buried Stinger", "desc": "Hide a tiny stinger mine that poisons on contact. Running while poisoned is dangerous.", "button": "A"},
				{"name": "Quicksand", "desc": "Create a pull zone that drags enemies to a lethal center unless they keep changing direction.", "button": "X"},
				{"name": "Crushing Pincers", "desc": "Place 2 toothed walls that slam shut and kill if the teeth touch from any angle.", "button": "Y"},
			],
		},
		{
			"id": Enums.TrapperCharacter.PULPO,
			"name": "OCTOPUS",
			"subtitle": "Vision and movement manipulation",
			"color": Enums.trapper_character_color(Enums.TrapperCharacter.PULPO),
			"abilities": [
				{"name": "Ink Stain", "desc": "Spread dark ink that hides almost everything inside the cloud.", "button": "A"},
				{"name": "Binding Tentacle", "desc": "Root one enemy in place. If another target links in, the root lasts longer.", "button": "X"},
				{"name": "Water Current", "desc": "Place 2 points to build a strong stream that shoves enemies along its path.", "button": "Y"},
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
