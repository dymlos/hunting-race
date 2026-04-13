class_name Enums

enum GameState {
	TEAM_SETUP,
	OBSERVATION,
	HUNT,
	ESCAPE,
	ROUND_END,
	MATCH_END,
	PAUSED,
}

enum Team {
	NONE,
	TEAM_1,
	TEAM_2,
}

enum Role {
	NONE,
	ESCAPIST,
	TRAPPER,
}

enum CCType {
	NONE,
	STUN,
	ROOT,
	SLOW,
}

enum TrapperCharacter {
	NONE,
	ARANA,
	HONGO,
	ESCORPION,
	PULPO,
}

enum EscapistAnimal {
	NONE,
	RABBIT,
	RAT,
	SQUIRREL,
	FLY,
}


static func team_color(team: Team) -> Color:
	if team == Team.TEAM_1:
		return Color(0.2, 0.6, 1.0)  # Blue
	elif team == Team.TEAM_2:
		return Color(1.0, 0.3, 0.2)  # Red
	return Color.WHITE


static func role_color(role: Role) -> Color:
	match role:
		Role.ESCAPIST:
			return Color(0.2, 1.0, 0.5)   # Green
		Role.TRAPPER:
			return Color(0.7, 0.3, 1.0)   # Purple
	return Color.WHITE


static func role_name(role: Role) -> String:
	match role:
		Role.ESCAPIST: return "Escapist"
		Role.TRAPPER:  return "Trapper"
	return "None"


static func trapper_character_name(tc: TrapperCharacter) -> String:
	match tc:
		TrapperCharacter.ARANA: return "ARAÑA"
		TrapperCharacter.HONGO: return "HONGO"
		TrapperCharacter.ESCORPION: return "ESCORPIÓN"
		TrapperCharacter.PULPO: return "PULPO"
	return "None"


static func trapper_character_color(tc: TrapperCharacter) -> Color:
	match tc:
		TrapperCharacter.ARANA: return Color(0.6, 0.2, 0.8)
		TrapperCharacter.HONGO: return Color(0.2, 0.8, 0.3)
		TrapperCharacter.ESCORPION: return Color(0.95, 0.12, 0.08)
		TrapperCharacter.PULPO: return Color(0.2, 0.5, 0.9)
	return Color.WHITE


static func escapist_animal_name(animal: EscapistAnimal) -> String:
	match animal:
		EscapistAnimal.RABBIT: return "RABBIT"
		EscapistAnimal.RAT: return "RAT"
		EscapistAnimal.SQUIRREL: return "SQUIRREL"
		EscapistAnimal.FLY: return "FLY"
	return "None"


static func escapist_animal_color(animal: EscapistAnimal) -> Color:
	match animal:
		EscapistAnimal.RABBIT: return Color(0.45, 0.82, 1.0)
		EscapistAnimal.RAT: return Color(0.58, 0.34, 0.18)
		EscapistAnimal.SQUIRREL: return Color(0.95, 0.72, 0.16)
		EscapistAnimal.FLY: return Color(0.18, 0.95, 0.68)
	return Color.WHITE
