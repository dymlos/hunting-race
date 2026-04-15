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
				"desc": "Hold A to charge; release to leap over walls and hazards.",
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
				"desc": "Fire or retract a long hook. Pull allies through walls and movement traps; poison remains.",
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
				"desc": "Throw a bouncing acorn. It breaks the first trap hit and sticks to sticky walls.",
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
				"desc": "Prime a counter. If hit by a trap or hazard, gain speed and effect immunity.",
				"button": "A",
			},
		},
	]


static func get_by_id(animal: Enums.EscapistAnimal) -> Dictionary:
	for data: Dictionary in get_all():
		if (data["id"] as Enums.EscapistAnimal) == animal:
			return data
	return {}
