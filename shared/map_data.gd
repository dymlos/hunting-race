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
	## "The Gauntlet" — 3 branching routes with different risk/reward.
	##
	## Verified route traces (all passable):
	##   TOP:    Spawn(y=250-350) → corridor(y=20-350, x=300-900) → drops into merge(y=350+, x=900+) → open room → goal
	##   MIDDLE: Spawn(y=500-700) → chamber(y=370-830, x=300-900) → straight into merge(x=900+) → open room → goal
	##   BOTTOM: Spawn(y=850-1000) → tunnel(y=870-1000, x=300-900) → up through gap(x=900, y=830 gap) → merge → goal
	##
	var w := 2400.0
	var h := 1200.0
	var t := 20.0

	var walls: Array[Dictionary] = [
		# === OUTER BOUNDARY ===
		{"pos": Vector2(0, 0), "size": Vector2(w, t)},             # top
		{"pos": Vector2(0, h - t), "size": Vector2(w, t)},         # bottom
		{"pos": Vector2(0, 0), "size": Vector2(t, h)},             # left
		{"pos": Vector2(w - t, 0), "size": Vector2(t, h)},         # right

		# ============================================================
		# SECTION 1: SPAWN ROOM (x: 0–300)
		# 3 exits: top (y=250-350), middle (y=500-700), bottom (y=850-1000)
		# ============================================================
		{"pos": Vector2(300, t), "size": Vector2(t, 230)},           # y=20–250
		{"pos": Vector2(300, 350), "size": Vector2(t, 150)},         # y=350–500
		{"pos": Vector2(300, 700), "size": Vector2(t, 150)},         # y=700–850
		{"pos": Vector2(300, 1000), "size": Vector2(t, h - 1000 - t)}, # y=1000–1180

		# ============================================================
		# SECTION 2: THREE ROUTES (x: 300–900)
		# ============================================================

		# --- TOP PATH floor (separates top from middle) ---
		# y=350 wall from x=300 to x=900
		{"pos": Vector2(300, 350), "size": Vector2(600, t)},
		# TOP PATH: open corridor y=20–350, x=300–900
		# (sticky walls placed as hazards inside)

		# --- MIDDLE PATH floor (separates middle from bottom) ---
		# y=830 wall from x=300 to x=900
		{"pos": Vector2(300, 830), "size": Vector2(600, t)},
		# MIDDLE PATH: open chamber y=370–830, x=300–900
		# (moving walls placed as hazards)
		# Pillars in the chamber
		{"pos": Vector2(480, 500), "size": Vector2(40, 40)},
		{"pos": Vector2(640, 700), "size": Vector2(40, 40)},
		{"pos": Vector2(780, 550), "size": Vector2(40, 40)},

		# --- BOTTOM PATH: narrow tunnel y=870–1000, x=320–880 ---
		# Inner ceiling (creates narrow passage)
		{"pos": Vector2(320, 940), "size": Vector2(560, t)},
		# BOTTOM PATH: passable strip y=850–940 (90px tall), x=320–880
		# Below the inner ceiling is dead space (y=960–1180)
		# Decorative fill below tunnel
		{"pos": Vector2(320, 1060), "size": Vector2(560, t)},

		# ============================================================
		# SECTION 3: MERGE ZONE (x: 900–1300)
		# All 3 paths feed into one area.
		# Top path drops down at x=900 (floor ends, open below).
		# Middle path continues straight.
		# Bottom path comes up through gap in y=830 separator.
		# Ice zone in the middle of the merge.
		# ============================================================

		# Separator between merge zone and bottom — with gap for bottom path
		# Left segment x=900-1050
		{"pos": Vector2(900, 830), "size": Vector2(150, t)},
		# Gap at x=1050-1150 (100px) — bottom path enters here
		# Right segment x=1150-1300
		{"pos": Vector2(1150, 830), "size": Vector2(150, t)},

		# Bottom path corridor to reach the gap (x=880-1050, y=850-1000)
		{"pos": Vector2(880, 1000), "size": Vector2(280, t)},        # floor of bottom connector

		# Top narrows into merge — wall guides top path down
		{"pos": Vector2(900, t), "size": Vector2(t, 200)},           # x=900, y=20-220

		# ============================================================
		# SECTION 4: OPEN ROOM + ONE-WAY (x: 1300–1750)
		# Breathing room. All paths have merged into y=220–830.
		# ============================================================
		{"pos": Vector2(1300, t), "size": Vector2(t, 250)},          # top wall
		{"pos": Vector2(1300, h - 300 - t), "size": Vector2(t, 300)}, # bottom wall
		# Cover pillars
		{"pos": Vector2(1450, 400), "size": Vector2(50, 50)},
		{"pos": Vector2(1550, 650), "size": Vector2(50, 50)},
		# Exit narrowing (one-way gate as hazard)
		{"pos": Vector2(1730, t), "size": Vector2(t, 300)},
		{"pos": Vector2(1730, h - 300 - t), "size": Vector2(t, 300)},

		# ============================================================
		# SECTION 5: STICKY MAZE + GOAL (x: 1750–2400)
		# Weave through staggered blocks with sticky surfaces.
		# ============================================================
		{"pos": Vector2(1850, t), "size": Vector2(t, 250)},
		{"pos": Vector2(1850, h - 250 - t), "size": Vector2(t, 250)},
		# Maze blocks (sticky walls overlaid as hazards)
		{"pos": Vector2(1920, 350), "size": Vector2(60, 180)},
		{"pos": Vector2(1920, 700), "size": Vector2(60, 180)},
		{"pos": Vector2(2060, 500), "size": Vector2(60, 200)},
		{"pos": Vector2(2200, 350), "size": Vector2(60, 150)},
		{"pos": Vector2(2200, 720), "size": Vector2(60, 150)},
	]

	var top_sticky_left_bounds := Rect2(Vector2(380, 40), Vector2(110, 210))
	var top_sticky_mid_bounds := Rect2(Vector2(535, 125), Vector2(120, 185))
	var top_sticky_right_bounds := Rect2(Vector2(700, 55), Vector2(120, 210))
	var top_sticky_low_left_bounds := Rect2(Vector2(390, 315), Vector2(170, 25))
	var top_sticky_low_right_bounds := Rect2(Vector2(585, 315), Vector2(185, 25))
	var moving_sweeper_bounds := Rect2(Vector2(300, 370), Vector2(620, 460))
	var moving_blocker_bounds := Rect2(Vector2(320, 370), Vector2(600, 460))
	var middle_sticky_bounds := Rect2(Vector2(360, 420), Vector2(500, 330))
	var bottom_sticky_left_upper_bounds := Rect2(Vector2(380, 850), Vector2(95, 44))
	var bottom_sticky_mid_lower_bounds := Rect2(Vector2(500, 896), Vector2(95, 44))
	var bottom_sticky_mid_upper_bounds := Rect2(Vector2(620, 850), Vector2(95, 44))
	var bottom_sticky_right_lower_bounds := Rect2(Vector2(760, 896), Vector2(95, 44))
	var bottom_sticky_upper_lane_bounds := Rect2(Vector2(380, 972), Vector2(250, 60))
	var bottom_sticky_lower_lane_bounds := Rect2(Vector2(500, 1092), Vector2(260, 60))
	var bottom_slippery_bounds := Rect2(Vector2(760, 850), Vector2(360, 150))
	var slippery_bounds := Rect2(Vector2(760, 190), Vector2(760, 720))
	var sticky_maze_bounds := Rect2(Vector2(1780, 250), Vector2(600, 730))
	var top_entrance_sticky_bounds := Rect2(Vector2(1840, 120), Vector2(50, 330))
	var bottom_entrance_sticky_bounds := Rect2(Vector2(1840, 720), Vector2(50, 330))

	var hazards: Array[Dictionary] = [
		# === TOP PATH: STICKY WALLS inside corridor (y=20-350, x=300-900) ===
		{
			"type": "sticky_wall",
			"pos": Vector2(420, 55),
			"size": Vector2(12, 175),
			"jitter": Vector2(45, 24),
			"bounds": top_sticky_left_bounds,
		},
		{
			"type": "sticky_wall",
			"pos": Vector2(580, 145),
			"size": Vector2(12, 145),
			"jitter": Vector2(45, 24),
			"bounds": top_sticky_mid_bounds,
		},
		{
			"type": "sticky_wall",
			"pos": Vector2(740, 70),
			"size": Vector2(12, 170),
			"jitter": Vector2(45, 24),
			"bounds": top_sticky_right_bounds,
		},
		{
			"type": "sticky_wall",
			"pos": Vector2(430, 320),
			"size": Vector2(130, 18),
			"jitter": Vector2(35, 4),
			"bounds": top_sticky_low_left_bounds,
		},
		{
			"type": "sticky_wall",
			"pos": Vector2(625, 320),
			"size": Vector2(130, 18),
			"jitter": Vector2(45, 4),
			"bounds": top_sticky_low_right_bounds,
		},

		# === MIDDLE PATH: MOVING WALLS (y=370-830, x=300-900) ===
		{
			"type": "moving_wall",
			"pos": Vector2(400, 400),
			"size": Vector2(180, t),
			"end_pos": Vector2(400, 780),
			"period": 3.5,
			"jitter": Vector2(220, 80),
			"bounds": moving_sweeper_bounds,
		},
		{
			"type": "moving_wall",
			"pos": Vector2(620, 780),
			"size": Vector2(180, t),
			"end_pos": Vector2(620, 400),
			"period": 4.0,
			"jitter": Vector2(220, 80),
			"bounds": moving_sweeper_bounds,
		},
		{
			"type": "moving_wall",
			"pos": Vector2(500, 550),
			"size": Vector2(t, 140),
			"end_pos": Vector2(700, 550),
			"period": 3.0,
			"jitter": Vector2(190, 150),
			"bounds": moving_blocker_bounds,
		},
		{
			"type": "sticky_wall",
			"pos": Vector2(720, 640),
			"size": Vector2(70, 18),
			"jitter": Vector2(140, 110),
			"bounds": middle_sticky_bounds,
		},
		{
			"type": "sticky_wall",
			"pos": Vector2(555, 455),
			"size": Vector2(18, 72),
			"jitter": Vector2(150, 95),
			"bounds": middle_sticky_bounds,
		},

		# === BOTTOM PATH: TECHNICAL TUNNEL HAZARDS ===
		{
			"type": "sticky_wall",
			"pos": Vector2(410, 850),
			"size": Vector2(18, 44),
			"jitter": Vector2(45, 0),
			"bounds": bottom_sticky_left_upper_bounds,
		},
		{
			"type": "sticky_wall",
			"pos": Vector2(535, 896),
			"size": Vector2(18, 44),
			"jitter": Vector2(45, 0),
			"bounds": bottom_sticky_mid_lower_bounds,
		},
		{
			"type": "sticky_wall",
			"pos": Vector2(655, 850),
			"size": Vector2(18, 38),
			"jitter": Vector2(45, 0),
			"bounds": bottom_sticky_mid_upper_bounds,
		},
		{
			"type": "sticky_wall",
			"pos": Vector2(805, 902),
			"size": Vector2(18, 38),
			"jitter": Vector2(45, 0),
			"bounds": bottom_sticky_right_lower_bounds,
		},
		{
			"type": "slippery_zone",
			"pos": Vector2(835, 850),
			"size": Vector2(170, 90),
			"jitter": Vector2(110, 40),
			"bounds": bottom_slippery_bounds,
		},
		{
			"type": "sticky_wall",
			"pos": Vector2(470, 982),
			"size": Vector2(18, 40),
			"jitter": Vector2(85, 10),
			"bounds": bottom_sticky_upper_lane_bounds,
		},
		{
			"type": "sticky_wall",
			"pos": Vector2(620, 1102),
			"size": Vector2(18, 40),
			"jitter": Vector2(85, 10),
			"bounds": bottom_sticky_lower_lane_bounds,
		},

		# === MERGE ZONE: ICE (x=950-1250, y=300-750) ===
		{
			"type": "slippery_zone",
			"pos": Vector2(950, 300),
			"size": Vector2(300, 450),
			"jitter": Vector2(280, 210),
			"bounds": slippery_bounds,
		},

		# === OPEN ROOM: ONE-WAY GATE ===
		{
			"type": "one_way_gate",
			"pos": Vector2(1700, 300),
			"size": Vector2(30, 600),
			"direction": Vector2(1, 0),
		},

		# === STICKY MAZE: overlaid on the maze blocks ===
		{
			"type": "sticky_wall",
			"pos": Vector2(1918, 530),
			"size": Vector2(64, 170),
			"jitter": Vector2(130, 130),
			"bounds": sticky_maze_bounds,
		},
		{
			"type": "sticky_wall",
			"pos": Vector2(2058, 350),
			"size": Vector2(64, 150),
			"jitter": Vector2(130, 130),
			"bounds": sticky_maze_bounds,
		},
		{
			"type": "sticky_wall",
			"pos": Vector2(2058, 700),
			"size": Vector2(64, 150),
			"jitter": Vector2(130, 130),
			"bounds": sticky_maze_bounds,
		},
		{
			"type": "sticky_wall",
			"pos": Vector2(2198, 500),
			"size": Vector2(64, 70),
			"jitter": Vector2(130, 130),
			"bounds": sticky_maze_bounds,
		},
		{
			"type": "sticky_wall",
			"pos": Vector2(2198, 870),
			"size": Vector2(64, 50),
			"jitter": Vector2(130, 130),
			"bounds": sticky_maze_bounds,
		},
		# Thin sticky strips on corridor entrance walls
		{
			"type": "sticky_wall",
			"pos": Vector2(1852, 250),
			"size": Vector2(12, 100),
			"jitter": Vector2(0, 150),
			"bounds": top_entrance_sticky_bounds,
		},
		{
			"type": "sticky_wall",
			"pos": Vector2(1852, h - 350),
			"size": Vector2(12, 100),
			"jitter": Vector2(0, 150),
			"bounds": bottom_entrance_sticky_bounds,
		},
	]

	return {
		"name": "The Gauntlet",
		"description": "3 routes: sticky corridor, moving walls, or safe tunnel. All merge into a sticky maze.",
		"size": Vector2(w, h),
		"walls": walls,
		"hazards": hazards,
		"spawns": [
			Vector2(120, 450), Vector2(120, 560),
			Vector2(120, 670), Vector2(120, 780),
			Vector2(200, 500), Vector2(200, 620),
		],
		"goal": Rect2(w - t - 100, 250, 100, h - 500),
	}


static func get_all() -> Array[Dictionary]:
	return [get_gauntlet_map()]
