class_name MapData

## Data-driven map definitions. Each map is a Dictionary with walls, spawns, goals, and hazards.


static func get_test_map() -> Dictionary:
	## Simple serpentine corridor — no hazards.
	var w := 1600.0
	var h := 900.0
	var t := 20.0

	var walls: Array[Dictionary] = [
		# Outer boundary
		{"pos": Vector2(0, 0), "size": Vector2(w, t)},
		{"pos": Vector2(0, h - t), "size": Vector2(w, t)},
		{"pos": Vector2(0, 0), "size": Vector2(t, h)},
		{"pos": Vector2(w - t, 0), "size": Vector2(t, h)},
		# Internal serpentine walls
		{"pos": Vector2(380, 0), "size": Vector2(t, 620)},
		{"pos": Vector2(760, 280), "size": Vector2(t, 620)},
		{"pos": Vector2(1140, 0), "size": Vector2(t, 620)},
	]

	return {
		"name": "Pasaje Técnico",
		"description": "Simple serpentine corridors. No hazards.",
		"size": Vector2(w, h),
		"walls": walls,
		"hazards": [],
		"spawn_team1": [Vector2(100, 300), Vector2(100, 450), Vector2(100, 600)],
		"spawn_team2": [Vector2(w - 100, 300), Vector2(w - 100, 450), Vector2(w - 100, 600)],
		"goal_team1": Rect2(w - t - 60, t, 60, h - 2 * t),
		"goal_team2": Rect2(t, t, 60, h - 2 * t),
	}


static func get_gauntlet_map() -> Dictionary:
	## "The Gauntlet" — all 4 hazard types. Symmetric from both sides.
	## Layout: Spawn → Chokepoint → Moving Walls → Slippery → One-Way Gate → Goal
	var w := 1800.0
	var h := 900.0
	var t := 20.0

	var walls: Array[Dictionary] = [
		# Outer boundary
		{"pos": Vector2(0, 0), "size": Vector2(w, t)},
		{"pos": Vector2(0, h - t), "size": Vector2(w, t)},
		{"pos": Vector2(0, 0), "size": Vector2(t, h)},
		{"pos": Vector2(w - t, 0), "size": Vector2(t, h)},

		# === CHOKEPOINTS near spawns (narrow 50px gaps) ===
		# Left chokepoint — wall from top, leaves narrow gap
		{"pos": Vector2(250, t), "size": Vector2(t, 370)},
		{"pos": Vector2(250, 480), "size": Vector2(t, h - 480 - t)},
		# Right chokepoint — mirror
		{"pos": Vector2(w - 270, t), "size": Vector2(t, 370)},
		{"pos": Vector2(w - 270, 480), "size": Vector2(t, h - 480 - t)},

		# === Central corridor dividers ===
		# Create lanes in the moving wall zone
		{"pos": Vector2(500, t), "size": Vector2(t, 280)},
		{"pos": Vector2(500, h - 280 - t), "size": Vector2(t, 280)},
		{"pos": Vector2(w - 520, t), "size": Vector2(t, 280)},
		{"pos": Vector2(w - 520, h - 280 - t), "size": Vector2(t, 280)},

		# Mid walls creating the slippery zone chamber
		{"pos": Vector2(750, t), "size": Vector2(t, 300)},
		{"pos": Vector2(750, h - 300 - t), "size": Vector2(t, 300)},
		{"pos": Vector2(w - 770, t), "size": Vector2(t, 300)},
		{"pos": Vector2(w - 770, h - 300 - t), "size": Vector2(t, 300)},
	]

	var hazards: Array[Dictionary] = [
		# === MOVING WALLS in the middle corridors ===
		# Horizontal sliding walls between the lane dividers
		{
			"type": "moving_wall",
			"pos": Vector2(540, 300),
			"size": Vector2(180, t),
			"end_pos": Vector2(540, 560),
			"period": 3.0,
		},
		{
			"type": "moving_wall",
			"pos": Vector2(w - 740, 560),
			"size": Vector2(180, t),
			"end_pos": Vector2(w - 740, 300),
			"period": 3.5,
		},

		# === SLIPPERY ZONES — large ice patches in the center ===
		{
			"type": "slippery_zone",
			"pos": Vector2(770, t),
			"size": Vector2(260, h - 2 * t),
		},

		# === ONE-WAY GATES — prevent backtracking past the 3/4 mark ===
		# Left side: only allows rightward movement
		{
			"type": "one_way_gate",
			"pos": Vector2(1100, 300),
			"size": Vector2(30, 300),
			"direction": Vector2(1, 0),
		},
		# Right side: only allows leftward movement
		{
			"type": "one_way_gate",
			"pos": Vector2(670, 300),
			"size": Vector2(30, 300),
			"direction": Vector2(-1, 0),
		},
	]

	return {
		"name": "The Gauntlet",
		"description": "Chokepoints, moving walls, ice zones, one-way gates.",
		"size": Vector2(w, h),
		"walls": walls,
		"hazards": hazards,
		"spawn_team1": [Vector2(100, 350), Vector2(100, 450), Vector2(100, 550)],
		"spawn_team2": [Vector2(w - 100, 350), Vector2(w - 100, 450), Vector2(w - 100, 550)],
		"goal_team1": Rect2(w - t - 80, t, 80, h - 2 * t),
		"goal_team2": Rect2(t, t, 80, h - 2 * t),
	}


static func get_all() -> Array[Dictionary]:
	return [get_test_map(), get_gauntlet_map()]
