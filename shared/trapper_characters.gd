class_name TrapperCharacters

## Static data for the 4 trapper characters and their abilities.


static func get_all() -> Array[Dictionary]:
	return [
		{
			"id": Enums.TrapperCharacter.ARANA,
			"name": "ARAÑA",
			"subtitle": "Control de movimiento",
			"color": Enums.trapper_character_color(Enums.TrapperCharacter.ARANA),
			"abilities": [
				{"name": "Telaraña expansiva", "desc": "Red entre 3 puntos — zona lenta", "button": "A"},
				{"name": "Telaraña elástica", "desc": "Red entre 2 puntos — rebote", "button": "RB"},
				{"name": "Veneno persistente", "desc": "Charco venenoso — aliado cura o muere", "button": "X"},
			],
		},
		{
			"id": Enums.TrapperCharacter.HONGO,
			"name": "HONGO",
			"subtitle": "Alteración de estados",
			"color": Enums.trapper_character_color(Enums.TrapperCharacter.HONGO),
			"abilities": [
				{"name": "Hongo confusor", "desc": "Invierte controles al tocarlo", "button": "A"},
				{"name": "Esporas tóxicas", "desc": "Zona lenta + veneno al salir", "button": "RB"},
				{"name": "Teletransporte fúngico", "desc": "Par de portales enlazados", "button": "X"},
			],
		},
		{
			"id": Enums.TrapperCharacter.ESCORPION,
			"name": "ESCORPIÓN",
			"subtitle": "Control letal",
			"color": Enums.trapper_character_color(Enums.TrapperCharacter.ESCORPION),
			"abilities": [
				{"name": "Aguijón enterrado", "desc": "Trampa oculta — veneno variable según tu velocidad", "button": "A"},
				{"name": "Arena movediza", "desc": "Atrae al centro — muerte o escapar girando", "button": "RB"},
				{"name": "Tenaza trituradora", "desc": "Dos paredes que aplastan", "button": "X"},
			],
		},
		{
			"id": Enums.TrapperCharacter.PULPO,
			"name": "PULPO",
			"subtitle": "Desorientación y manipulación",
			"color": Enums.trapper_character_color(Enums.TrapperCharacter.PULPO),
			"abilities": [
				{"name": "Mancha de tinta", "desc": "Zona de visibilidad nula", "button": "A"},
				{"name": "Tentáculo enlazador", "desc": "Captura y une a dos conejos", "button": "RB"},
				{"name": "Corriente de agua", "desc": "Flujo direccional entre puntos", "button": "X"},
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
