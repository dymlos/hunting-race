class_name Enums

enum GameState {
	TEAM_SETUP,
	OBSERVATION,
	DEPLOYMENT,
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
	PREDATOR,
	TRAPPER,
}

enum CCType {
	NONE,
	STUN,
	ROOT,
	SLOW,
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
		Role.PREDATOR:
			return Color(1.0, 0.4, 0.1)   # Orange
		Role.TRAPPER:
			return Color(0.7, 0.3, 1.0)   # Purple
	return Color.WHITE


static func role_name(role: Role) -> String:
	match role:
		Role.ESCAPIST: return "Escapist"
		Role.PREDATOR: return "Predator"
		Role.TRAPPER:  return "Trapper"
	return "None"
