class_name EscapistAnimals


static func get_all() -> Array[Dictionary]:
	return [
		{
			"id": Enums.EscapistAnimal.RABBIT,
			"name": "RABBIT",
			"subtitle": "Explosive mobility",
			"color": Enums.escapist_animal_color(Enums.EscapistAnimal.RABBIT),
			"ability": {
				"name": "Charged Leap",
				"desc": "Hold A, then release to jump a long distance over walls, traps and hazards.",
				"button": "A",
			},
		},
		{
			"id": Enums.EscapistAnimal.RAT,
			"name": "RAT",
			"subtitle": "Tactical rescue",
			"color": Enums.escapist_animal_color(Enums.EscapistAnimal.RAT),
			"ability": {
				"name": "Rescue Tail",
				"desc": "Throw a hook to grab an ally and drag them to you, even through walls or movement traps.",
				"button": "A",
			},
		},
		{
			"id": Enums.EscapistAnimal.SQUIRREL,
			"name": "SQUIRREL",
			"subtitle": "Active sabotage",
			"color": Enums.escapist_animal_color(Enums.EscapistAnimal.SQUIRREL),
			"ability": {
				"name": "Ricochet Acorn",
				"desc": "Throw a bouncing acorn that destroys the first trap it touches and can stick to sticky walls.",
				"button": "A",
			},
		},
		{
			"id": Enums.EscapistAnimal.FLY,
			"name": "FLY",
			"subtitle": "Aggressive counter",
			"color": Enums.escapist_animal_color(Enums.EscapistAnimal.FLY),
			"ability": {
				"name": "Adrenaline Reflex",
				"desc": "Arm a counter. If a trap or hazard hits you, you burst with speed and temporary immunity.",
				"button": "A",
			},
		},
	]


static func get_by_id(animal: Enums.EscapistAnimal) -> Dictionary:
	for data: Dictionary in get_all():
		if (data["id"] as Enums.EscapistAnimal) == animal:
			return data
	return {}
