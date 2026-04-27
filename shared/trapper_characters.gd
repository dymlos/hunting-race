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
				{"name": "Veneno persistente", "desc": "Deja un charco venenoso. Si sus aliados no tocan a la víctima a tiempo, reaparece.", "button": "A"},
				{"name": "Telaraña elástica", "desc": "Coloca 2 puntos para tender una línea que empuja enemigos al tocarla.", "button": "X"},
				{"name": "Telaraña expansiva", "desc": "Coloca 3 puntos para crear una zona grande que ralentiza a todos dentro.", "button": "Y"},
			],
		},
		{
			"id": Enums.TrapperCharacter.HONGO,
			"name": "HONGO",
			"subtitle": "Alteración de estado",
			"color": Enums.trapper_character_color(Enums.TrapperCharacter.HONGO),
			"abilities": [
				{"name": "Hongo confusor", "desc": "Trampa de un solo uso que invierte los controles enemigos por unos segundos.", "button": "A"},
				{"name": "Esporas tóxicas", "desc": "Crea una nube que ralentiza enemigos; al salir de la nube quedan envenenados.", "button": "X"},
				{"name": "Teletransporte fungal", "desc": "Coloca 2 portales unidos. Entra por uno para salir al instante por el otro.", "button": "Y"},
			],
		},
		{
			"id": Enums.TrapperCharacter.ESCORPION,
			"name": "ESCORPIÓN",
			"subtitle": "Control letal",
			"color": Enums.trapper_character_color(Enums.TrapperCharacter.ESCORPION),
			"abilities": [
				{"name": "Aguijón enterrado", "desc": "Esconde una pequeña mina que envenena al contacto. Correr envenenado es peligroso.", "button": "A"},
				{"name": "Arenas movedizas", "desc": "Crea una zona que arrastra enemigos a un centro letal salvo que cambien de dirección.", "button": "X"},
				{"name": "Pinzas trituradoras", "desc": "Coloca 2 muros dentados que se cierran y matan si los dientes tocan desde cualquier ángulo.", "button": "Y"},
			],
		},
		{
			"id": Enums.TrapperCharacter.PULPO,
			"name": "PULPO",
			"subtitle": "Visión y movimiento",
			"color": Enums.trapper_character_color(Enums.TrapperCharacter.PULPO),
			"abilities": [
				{"name": "Mancha de tinta", "desc": "Esparce tinta oscura que oculta casi todo dentro de la nube.", "button": "A"},
				{"name": "Tentáculo inmovilizador", "desc": "Fija a un enemigo en el lugar. Si otro objetivo se enlaza, dura más.", "button": "X"},
				{"name": "Corriente de agua", "desc": "Coloca 2 puntos para crear una corriente fuerte que empuja enemigos por su camino.", "button": "Y"},
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
