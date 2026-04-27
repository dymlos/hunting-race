class_name EscapistAnimals


static func get_all() -> Array[Dictionary]:
	return [
		{
			"id": Enums.EscapistAnimal.RABBIT,
			"name": "CONEJO",
			"subtitle": "Movilidad explosiva",
			"color": Enums.escapist_animal_color(Enums.EscapistAnimal.RABBIT),
			"ability": {
				"name": "Salto cargado",
				"desc": "Mantén A y suelta para saltar lejos por encima de paredes, trampas y peligros.",
				"button": "A",
			},
		},
		{
			"id": Enums.EscapistAnimal.RAT,
			"name": "RATA",
			"subtitle": "Rescate táctico",
			"color": Enums.escapist_animal_color(Enums.EscapistAnimal.RAT),
			"ability": {
				"name": "Cola de rescate",
				"desc": "Lanza un gancho para atrapar a un aliado y arrastrarlo hacia ti, incluso a través de paredes o trampas de movimiento.",
				"button": "A",
			},
		},
		{
			"id": Enums.EscapistAnimal.SQUIRREL,
			"name": "ARDILLA",
			"subtitle": "Sabotaje activo",
			"color": Enums.escapist_animal_color(Enums.EscapistAnimal.SQUIRREL),
			"ability": {
				"name": "Bellota rebotadora",
				"desc": "Lanza una bellota que rebota, destruye la primera trampa que toca y puede pegarse a paredes adhesivas.",
				"button": "A",
			},
		},
		{
			"id": Enums.EscapistAnimal.FLY,
			"name": "MOSCA",
			"subtitle": "Contraataque agresivo",
			"color": Enums.escapist_animal_color(Enums.EscapistAnimal.FLY),
			"ability": {
				"name": "Reflejo de adrenalina",
				"desc": "Prepara un contraataque. Si una trampa o peligro te golpea, obtienes velocidad e inmunidad temporal.",
				"button": "A",
			},
		},
	]


static func get_by_id(animal: Enums.EscapistAnimal) -> Dictionary:
	for data: Dictionary in get_all():
		if (data["id"] as Enums.EscapistAnimal) == animal:
			return data
	return {}
