class_name Enums

enum GameState {
	TEAM_SETUP,
	OBSERVATION,
	HUNT,
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
		TrapperCharacter.ESCORPION: return Color(0.9, 0.5, 0.1)
		TrapperCharacter.PULPO: return Color(0.2, 0.5, 0.9)
	return Color.WHITE
