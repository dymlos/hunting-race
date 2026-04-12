class_name MapData

## Data-driven map definitions.
## Maps are one-directional courses: spawns on one side, goal on the other.
## No symmetry needed — escapists always spawn at "spawns" and run to "goal".


static func get_test_map() -> Dictionary:
	## Simple serpentine corridor — no hazards.
	var w := 1600.0
	var h := 900.0
	var t := 20.0

	return {
		"name": "Pasaje Técnico",
		"description": "Simple serpentine corridors. No hazards.",
		"size": Vector2(w, h),
		"walls": [
			# Outer boundary
			{"pos": Vector2(0, 0), "size": Vector2(w, t)},
			{"pos": Vector2(0, h - t), "size": Vector2(w, t)},
			{"pos": Vector2(0, 0), "size": Vector2(t, h)},
			{"pos": Vector2(w - t, 0), "size": Vector2(t, h)},
			# Serpentine walls
			{"pos": Vector2(380, 0), "size": Vector2(t, 620)},
			{"pos": Vector2(760, 280), "size": Vector2(t, 620)},
			{"pos": Vector2(1140, 0), "size": Vector2(t, 620)},
		],
		"hazards": [],
		"spawns": [Vector2(100, 300), Vector2(100, 450), Vector2(100, 600)],
		"goal": Rect2(w - t - 60, t, 60, h - 2 * t),
	}


static func get_gauntlet_map() -> Dictionary:
	## "The Gauntlet" — large asymmetric course with all hazard types.
	## Left to right: Spawn → Narrow Corridors → Moving Walls → Ice Bridge → One-Way Commit → Final Stretch → Goal
	var w := 2400.0
	var h := 1200.0
	var t := 20.0

	var walls: Array[Dictionary] = [
		# Outer boundary
		{"pos": Vector2(0, 0), "size": Vector2(w, t)},
		{"pos": Vector2(0, h - t), "size": Vector2(w, t)},
		{"pos": Vector2(0, 0), "size": Vector2(t, h)},
		{"pos": Vector2(w - t, 0), "size": Vector2(t, h)},

		# === SECTION 1: Spawn area — open room with exit chokepoints ===
		# Right wall of spawn room with two narrow exits (top and bottom)
		{"pos": Vector2(300, t), "size": Vector2(t, 400)},          # top block
		{"pos": Vector2(300, 500), "size": Vector2(t, 200)},        # middle block
		{"pos": Vector2(300, 800), "size": Vector2(t, h - 800 - t)},  # bottom block
		# Gaps at y=420-500 and y=700-800

		# === SECTION 2: Winding corridors (300-800) ===
		# Top corridor walls
		{"pos": Vector2(500, t), "size": Vector2(t, 500)},
		{"pos": Vector2(500, 700), "size": Vector2(t, h - 700 - t)},
		# Creates vertical passage at y=500-700

		# Horizontal divider creating upper and lower paths
		{"pos": Vector2(300, 600), "size": Vector2(200, t)},

		# === SECTION 3: Moving walls chamber (800-1300) ===
		# Entry walls
		{"pos": Vector2(800, t), "size": Vector2(t, 350)},
		{"pos": Vector2(800, h - 350 - t), "size": Vector2(t, 350)},
		# Exit walls
		{"pos": Vector2(1300, t), "size": Vector2(t, 350)},
		{"pos": Vector2(1300, h - 350 - t), "size": Vector2(t, 350)},
		# Internal pillars for moving walls to create interesting patterns
		{"pos": Vector2(1000, 450), "size": Vector2(40, 40)},
		{"pos": Vector2(1100, 650), "size": Vector2(40, 40)},

		# === SECTION 4: Ice bridge (1300-1800) ===
		# Narrow bridge with drops on sides (walls creating a constrained path)
		{"pos": Vector2(1400, t), "size": Vector2(t, 400)},
		{"pos": Vector2(1400, h - 400 - t), "size": Vector2(t, 400)},
		{"pos": Vector2(1700, t), "size": Vector2(t, 400)},
		{"pos": Vector2(1700, h - 400 - t), "size": Vector2(t, 400)},
		# Central platform narrows the ice path
		{"pos": Vector2(1500, 500), "size": Vector2(100, t)},
		{"pos": Vector2(1500, 680), "size": Vector2(100, t)},

		# === SECTION 5: One-way commit + final stretch (1800-2400) ===
		# Wall after one-way gate — funnels into final approach
		{"pos": Vector2(1900, t), "size": Vector2(t, 300)},
		{"pos": Vector2(1900, h - 300 - t), "size": Vector2(t, 300)},
		# Final corridor obstacles — staggered blocks
		{"pos": Vector2(2050, 350), "size": Vector2(60, 200)},
		{"pos": Vector2(2050, 700), "size": Vector2(60, 200)},
		{"pos": Vector2(2200, 500), "size": Vector2(60, 200)},
	]

	var hazards: Array[Dictionary] = [
		# === MOVING WALLS in chamber (section 3) ===
		# Horizontal wall sliding up and down
		{
			"type": "moving_wall",
			"pos": Vector2(850, 370),
			"size": Vector2(200, t),
			"end_pos": Vector2(850, 800),
			"period": 3.5,
		},
		# Another moving wall, offset timing
		{
			"type": "moving_wall",
			"pos": Vector2(1050, 800),
			"size": Vector2(200, t),
			"end_pos": Vector2(1050, 370),
			"period": 4.0,
		},
		# Vertical moving wall
		{
			"type": "moving_wall",
			"pos": Vector2(950, 400),
			"size": Vector2(t, 150),
			"end_pos": Vector2(1150, 400),
			"period": 3.0,
		},

		# === ICE BRIDGE (section 4) ===
		# Large slippery zone covering the bridge
		{
			"type": "slippery_zone",
			"pos": Vector2(1320, 400),
			"size": Vector2(400, 400),
		},

		# === ONE-WAY GATE (section 5 entrance) ===
		# No going back once you commit to the final stretch
		{
			"type": "one_way_gate",
			"pos": Vector2(1820, 300),
			"size": Vector2(40, 600),
			"direction": Vector2(1, 0),
		},

		# === STICKY WALLS in the final stretch (section 5) ===
		# Escapists must navigate carefully around these
		{
			"type": "sticky_wall",
			"pos": Vector2(1950, 380),
			"size": Vector2(15, 180),
		},
		{
			"type": "sticky_wall",
			"pos": Vector2(1950, 650),
			"size": Vector2(15, 180),
		},
		{
			"type": "sticky_wall",
			"pos": Vector2(2120, 500),
			"size": Vector2(15, 200),
		},
		# Sticky walls lining a narrow corridor near goal
		{
			"type": "sticky_wall",
			"pos": Vector2(2280, 350),
			"size": Vector2(10, 120),
		},
		{
			"type": "sticky_wall",
			"pos": Vector2(2280, 550),
			"size": Vector2(10, 120),
		},
	]

	return {
		"name": "The Gauntlet",
		"description": "Chokepoints, moving walls, ice, one-way gates, sticky walls.",
		"size": Vector2(w, h),
		"walls": walls,
		"hazards": hazards,
		"spawns": [
			Vector2(100, 400), Vector2(100, 520),
			Vector2(100, 640), Vector2(100, 760),
			Vector2(180, 460), Vector2(180, 580),
		],
		"goal": Rect2(w - t - 100, t, 100, h - 2 * t),
	}


static func get_all() -> Array[Dictionary]:
	return [get_test_map(), get_gauntlet_map()]
