class_name MapData

## Data-driven map definitions. Each map is a Dictionary with walls, spawns, and goals.


static func get_test_map() -> Dictionary:
	## Serpentine corridor map ~1600x900.
	## Team 1 spawns on the left, their goal is on the right.
	## Team 2 spawns on the right, their goal is on the left.
	var w := 1600.0
	var h := 900.0
	var t := 20.0  # wall thickness

	var walls: Array[Dictionary] = [
		# Outer boundary
		{"pos": Vector2(0, 0), "size": Vector2(w, t)},             # top
		{"pos": Vector2(0, h - t), "size": Vector2(w, t)},         # bottom
		{"pos": Vector2(0, 0), "size": Vector2(t, h)},             # left
		{"pos": Vector2(w - t, 0), "size": Vector2(t, h)},         # right

		# Internal walls creating serpentine path
		# Wall 1: extends from top, leaves gap at bottom
		{"pos": Vector2(380, 0), "size": Vector2(t, 620)},
		# Wall 2: extends from bottom, leaves gap at top
		{"pos": Vector2(760, 280), "size": Vector2(t, 620)},
		# Wall 3: extends from top, leaves gap at bottom
		{"pos": Vector2(1140, 0), "size": Vector2(t, 620)},
	]

	return {
		"name": "Pasaje Técnico",
		"size": Vector2(w, h),
		"walls": walls,
		"spawn_team1": [
			Vector2(100, 300),
			Vector2(100, 450),
			Vector2(100, 600),
		],
		"spawn_team2": [
			Vector2(w - 100, 300),
			Vector2(w - 100, 450),
			Vector2(w - 100, 600),
		],
		# Goal for team 1 is on team 2's side (right), and vice versa
		"goal_team1": Rect2(w - t - 60, t, 60, h - 2 * t),       # right side
		"goal_team2": Rect2(t, t, 60, h - 2 * t),                 # left side
	}


static func get_all() -> Array[Dictionary]:
	return [get_test_map()]
