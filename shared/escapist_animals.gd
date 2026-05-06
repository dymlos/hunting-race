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


static func get_survival_all() -> Array[Dictionary]:
	return [
		{
			"id": Enums.EscapistAnimal.RABBIT,
			"name": "CONEJO",
			"subtitle": "Salto con llave",
			"color": Enums.escapist_animal_color(Enums.EscapistAnimal.RABBIT),
			"ability": {
				"name": "Salto cargado",
				"desc": "Habilidad dormida hasta tomar una llave. Al habilitarse usa cooldown de 20s y conserva el salto cargado para cruzar peligros.",
				"button": "A",
			},
		},
		{
			"id": Enums.EscapistAnimal.RAT,
			"name": "RATA",
			"subtitle": "Rescate progresivo",
			"color": Enums.escapist_animal_color(Enums.EscapistAnimal.RAT),
			"ability": {
				"name": "Cola de rescate",
				"desc": "Se habilita con llave. La cola alcanza medio mapa, rescata aliados de zombies sin traer enemigos y gana velocidad por cada rescate real.",
				"button": "A",
			},
		},
		{
			"id": Enums.EscapistAnimal.SQUIRREL,
			"name": "ARDILLA",
			"subtitle": "Bellota anti-zombie",
			"color": Enums.escapist_animal_color(Enums.EscapistAnimal.SQUIRREL),
			"ability": {
				"name": "Bellota rebotadora",
				"desc": "Se habilita con llave. La bellota rompe trampas y elimina zombies; al tocar un zombie se destruye junto con el objetivo.",
				"button": "A",
			},
		},
		{
			"id": Enums.EscapistAnimal.FLY,
			"name": "MOSCA",
			"subtitle": "Reflejo de 1 segundo",
			"color": Enums.escapist_animal_color(Enums.EscapistAnimal.FLY),
			"ability": {
				"name": "Reflejo de adrenalina",
				"desc": "Se habilita con llave. Activa una ventana de 1s: si un zombie o trampa letal toca, evita el efecto y gana velocidad.",
				"button": "A",
			},
		},
	]


static func get_survival_by_id(animal: Enums.EscapistAnimal) -> Dictionary:
	for data: Dictionary in get_survival_all():
		if (data["id"] as Enums.EscapistAnimal) == animal:
			return data
	return {}
