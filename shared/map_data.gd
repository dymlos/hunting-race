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
		{"pos": Vector2(300, 1000), "size": Vector2(t, 70)},
		{"pos": Vector2(300, 1160), "size": Vector2(t, h - 1160 - t)},

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
		# Randomized ice boxes are defined as hazards.
		# Exit narrowing (one-way gate as hazard)
		{"pos": Vector2(1730, t), "size": Vector2(t, 300)},
		{"pos": Vector2(1730, h - 300 - t), "size": Vector2(t, 300)},

		# ============================================================
		# SECTION 5: STICKY MAZE + GOAL (x: 1750–2400)
		# Weave through staggered blocks with sticky surfaces.
		# ============================================================
		{"pos": Vector2(1850, t), "size": Vector2(t, 250)},
		{"pos": Vector2(1850, h - 250 - t), "size": Vector2(t, 250)},
		# Maze blocks with passable gaps between each pair.
		{"pos": Vector2(1920, 300), "size": Vector2(38, 180)},
		{"pos": Vector2(1920, 690), "size": Vector2(38, 220)},
		{"pos": Vector2(2045, 120), "size": Vector2(38, 220)},
		{"pos": Vector2(2045, 520), "size": Vector2(38, 220)},
		{"pos": Vector2(2170, 300), "size": Vector2(38, 220)},
		{"pos": Vector2(2170, 730), "size": Vector2(38, 230)},
		{"pos": Vector2(2280, 170), "size": Vector2(38, 190)},
		{"pos": Vector2(2280, 840), "size": Vector2(38, 180)},
		{"pos": Vector2(1920, 564), "size": Vector2(150, 12)},
		{"pos": Vector2(2035, 404), "size": Vector2(170, 12)},
		{"pos": Vector2(2045, 824), "size": Vector2(160, 12)},
		{"pos": Vector2(2200, 604), "size": Vector2(80, 12)},
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
	var bottom_sticky_lower_left_bounds := Rect2(Vector2(350, 1088), Vector2(150, 70))
	var bottom_sticky_lower_right_bounds := Rect2(Vector2(720, 1088), Vector2(130, 70))
	var bottom_slippery_bounds := Rect2(Vector2(760, 850), Vector2(360, 150))
	var center_ice_rect := Rect2(Vector2(900, 250), Vector2(780, 580))
	var center_ice_box_left_top_bounds := Rect2(Vector2(955, 305), Vector2(130, 170))
	var center_ice_box_left_bottom_bounds := Rect2(Vector2(1035, 565), Vector2(145, 175))
	var center_ice_box_mid_top_bounds := Rect2(Vector2(1165, 335), Vector2(145, 170))
	var center_ice_box_mid_bottom_bounds := Rect2(Vector2(1285, 610), Vector2(145, 160))
	var center_ice_box_right_top_bounds := Rect2(Vector2(1435, 330), Vector2(135, 175))
	var center_ice_box_right_bottom_bounds := Rect2(Vector2(1540, 585), Vector2(120, 170))
	var center_ice_sticky_left_bounds := Rect2(Vector2(970, 430), Vector2(210, 70))
	var center_ice_sticky_mid_bounds := Rect2(Vector2(1160, 350), Vector2(180, 180))
	var center_ice_sticky_lower_bounds := Rect2(Vector2(1280, 690), Vector2(230, 70))
	var center_ice_sticky_right_bounds := Rect2(Vector2(1490, 445), Vector2(170, 200))
	var center_entry_lift_bounds := Rect2(Vector2(740, 560), Vector2(340, 170))
	var sticky_maze_left_top_bounds := Rect2(Vector2(1890, 280), Vector2(130, 220))
	var sticky_maze_left_bottom_bounds := Rect2(Vector2(1885, 660), Vector2(150, 260))
	var sticky_maze_mid_top_bounds := Rect2(Vector2(2020, 170), Vector2(150, 260))
	var sticky_maze_mid_bottom_bounds := Rect2(Vector2(2020, 535), Vector2(170, 260))
	var sticky_maze_right_top_bounds := Rect2(Vector2(2160, 270), Vector2(150, 280))
	var sticky_maze_right_bottom_bounds := Rect2(Vector2(2160, 680), Vector2(150, 260))
	var sticky_maze_goal_top_bounds := Rect2(Vector2(2245, 250), Vector2(115, 260))
	var sticky_maze_goal_bottom_bounds := Rect2(Vector2(2245, 660), Vector2(115, 260))
	var sticky_maze_lift_left_bounds := Rect2(Vector2(1810, 440), Vector2(150, 260))
	var sticky_maze_lift_upper_bounds := Rect2(Vector2(1885, 340), Vector2(110, 300))
	var sticky_maze_lift_mid_bounds := Rect2(Vector2(2085, 450), Vector2(110, 260))
	var sticky_maze_lift_bottom_bounds := Rect2(Vector2(2010, 890), Vector2(360, 80))
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
		{
			"type": "sticky_wall",
			"pos": Vector2(400, 1110),
			"size": Vector2(18, 44),
			"jitter": Vector2(55, 12),
			"bounds": bottom_sticky_lower_left_bounds,
		},
		{
			"type": "sticky_wall",
			"pos": Vector2(770, 1108),
			"size": Vector2(18, 46),
			"jitter": Vector2(50, 12),
			"bounds": bottom_sticky_lower_right_bounds,
		},

		# === CENTER ICE FIELD ===
		{
			"type": "slippery_zone",
			"pos": center_ice_rect.position,
			"size": center_ice_rect.size,
			"fixed": true,
		},
		{
			"type": "ice_box",
			"pos": Vector2(995, 345),
			"size": Vector2(46, 46),
			"jitter": Vector2(42, 58),
			"bounds": center_ice_box_left_top_bounds,
		},
		{
			"type": "ice_box",
			"pos": Vector2(1090, 630),
			"size": Vector2(56, 46),
			"jitter": Vector2(48, 65),
			"bounds": center_ice_box_left_bottom_bounds,
		},
		{
			"type": "ice_box",
			"pos": Vector2(1220, 390),
			"size": Vector2(48, 56),
			"jitter": Vector2(52, 60),
			"bounds": center_ice_box_mid_top_bounds,
		},
		{
			"type": "ice_box",
			"pos": Vector2(1345, 665),
			"size": Vector2(58, 42),
			"jitter": Vector2(50, 58),
			"bounds": center_ice_box_mid_bottom_bounds,
		},
		{
			"type": "ice_box",
			"pos": Vector2(1485, 405),
			"size": Vector2(50, 50),
			"jitter": Vector2(45, 62),
			"bounds": center_ice_box_right_top_bounds,
		},
		{
			"type": "ice_box",
			"pos": Vector2(1580, 645),
			"size": Vector2(48, 58),
			"jitter": Vector2(42, 62),
			"bounds": center_ice_box_right_bottom_bounds,
		},
		{
			"type": "sticky_wall",
			"pos": Vector2(1020, 455),
			"size": Vector2(120, 18),
			"jitter": Vector2(55, 24),
			"bounds": center_ice_sticky_left_bounds,
		},
		{
			"type": "sticky_wall",
			"pos": Vector2(1210, 385),
			"size": Vector2(18, 110),
			"jitter": Vector2(58, 44),
			"bounds": center_ice_sticky_mid_bounds,
		},
		{
			"type": "sticky_wall",
			"pos": Vector2(1340, 715),
			"size": Vector2(130, 18),
			"jitter": Vector2(62, 22),
			"bounds": center_ice_sticky_lower_bounds,
		},
		{
			"type": "sticky_wall",
			"pos": Vector2(1535, 500),
			"size": Vector2(18, 120),
			"jitter": Vector2(54, 52),
			"bounds": center_ice_sticky_right_bounds,
		},
		{
			"type": "moving_wall",
			"pos": Vector2(780, 585),
			"size": Vector2(12, 120),
			"end_pos": Vector2(940, 585),
			"period": 2.4,
			"fixed": true,
			"bounds": center_entry_lift_bounds,
		},
		{
			"type": "frost_vent",
			"pos": Vector2(950, 170),
			"size": Vector2(84, 22),
			"fixed": true,
			"direction": Vector2.DOWN,
			"range": 520.0,
			"width": 180.0,
			"period": 0.95,
			"force": 560.0,
		},
		{
			"type": "frost_vent",
			"pos": Vector2(1375, 170),
			"size": Vector2(84, 22),
			"fixed": true,
			"direction": Vector2.DOWN,
			"range": 520.0,
			"width": 180.0,
			"period": 1.0,
			"force": 560.0,
		},
		{
			"type": "frost_vent",
			"pos": Vector2(1265, 900),
			"size": Vector2(84, 22),
			"fixed": true,
			"direction": Vector2.UP,
			"range": 440.0,
			"width": 180.0,
			"period": 0.9,
			"force": 540.0,
		},
		{
			"type": "frost_vent",
			"pos": Vector2(1525, 900),
			"size": Vector2(84, 22),
			"fixed": true,
			"direction": Vector2.UP,
			"range": 440.0,
			"width": 180.0,
			"period": 1.0,
			"force": 540.0,
		},
		{
			"type": "frost_vent",
			"pos": Vector2(1260, 850),
			"size": Vector2(22, 84),
			"fixed": true,
			"direction": Vector2.LEFT,
			"range": 340.0,
			"width": 150.0,
			"period": 0.95,
			"force": 540.0,
		},
		{
			"type": "frost_vent",
			"pos": Vector2(1260, 1045),
			"size": Vector2(22, 84),
			"fixed": true,
			"direction": Vector2.LEFT,
			"range": 340.0,
			"width": 150.0,
			"period": 1.0,
			"force": 540.0,
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
			"pos": Vector2(1925, 325),
			"size": Vector2(28, 130),
			"jitter": Vector2(28, 40),
			"bounds": sticky_maze_left_top_bounds,
		},
		{
			"type": "sticky_wall",
			"pos": Vector2(1925, 735),
			"size": Vector2(28, 130),
			"jitter": Vector2(32, 55),
			"bounds": sticky_maze_left_bottom_bounds,
		},
		{
			"type": "sticky_wall",
			"pos": Vector2(2050, 195),
			"size": Vector2(28, 115),
			"jitter": Vector2(32, 55),
			"bounds": sticky_maze_mid_top_bounds,
		},
		{
			"type": "sticky_wall",
			"pos": Vector2(2050, 580),
			"size": Vector2(28, 115),
			"jitter": Vector2(38, 55),
			"bounds": sticky_maze_mid_bottom_bounds,
		},
		{
			"type": "sticky_wall",
			"pos": Vector2(2175, 360),
			"size": Vector2(28, 125),
			"jitter": Vector2(35, 55),
			"bounds": sticky_maze_right_top_bounds,
		},
		{
			"type": "sticky_wall",
			"pos": Vector2(2175, 770),
			"size": Vector2(28, 125),
			"jitter": Vector2(35, 55),
			"bounds": sticky_maze_right_bottom_bounds,
		},
		{
			"type": "sticky_wall",
			"pos": Vector2(2285, 245),
			"size": Vector2(28, 90),
			"jitter": Vector2(24, 45),
			"bounds": sticky_maze_goal_top_bounds,
		},
		{
			"type": "sticky_wall",
			"pos": Vector2(2285, 850),
			"size": Vector2(28, 90),
			"jitter": Vector2(24, 45),
			"bounds": sticky_maze_goal_bottom_bounds,
		},
		{
			"type": "slippery_zone",
			"pos": Vector2(1875, 155),
			"size": Vector2(165, 85),
			"fixed": true,
		},
		{
			"type": "slippery_zone",
			"pos": Vector2(1985, 920),
			"size": Vector2(170, 85),
			"fixed": true,
		},
		{
			"type": "slippery_zone",
			"pos": Vector2(2215, 520),
			"size": Vector2(125, 95),
			"fixed": true,
		},
		{
			"type": "moving_wall",
			"pos": Vector2(1825, 650),
			"size": Vector2(120, 12),
			"end_pos": Vector2(1825, 470),
			"period": 2.6,
			"fixed": true,
			"bounds": sticky_maze_lift_left_bounds,
		},
		{
			"type": "moving_wall",
			"pos": Vector2(1915, 600),
			"size": Vector2(12, 120),
			"end_pos": Vector2(1915, 380),
			"period": 2.8,
			"fixed": true,
			"bounds": sticky_maze_lift_upper_bounds,
		},
		{
			"type": "moving_wall",
			"pos": Vector2(2135, 500),
			"size": Vector2(12, 130),
			"end_pos": Vector2(2135, 640),
			"period": 2.5,
			"fixed": true,
			"bounds": sticky_maze_lift_mid_bounds,
		},
		{
			"type": "moving_wall",
			"pos": Vector2(2250, 930),
			"size": Vector2(120, 12),
			"end_pos": Vector2(2025, 930),
			"period": 3.0,
			"fixed": true,
			"bounds": sticky_maze_lift_bottom_bounds,
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
		"name": "The Sticky Slide",
		"description": "3 routes: sticky corridor, moving walls, or safe tunnel. All merge into a sticky maze.",
		"size": Vector2(w, h),
		"walls": walls,
		"hazards": hazards,
		"spawns": [
			Vector2(120, 450), Vector2(120, 560),
			Vector2(120, 670), Vector2(120, 780),
			Vector2(200, 500), Vector2(200, 620),
		],
		"goal": Rect2(w - t - 70, 430, 70, 340),
	}


static func get_practice_map() -> Dictionary:
	var w := 1600.0
	var h := 900.0
	var spawn := Vector2(w / 2.0, h / 2.0)

	return {
		"name": "Practice Room",
		"description": "A clean room for testing movement, traps, and skills.",
		"size": Vector2(w, h),
		"walls": [],
		"hazards": [],
		"spawns": [spawn],
		"goal": Rect2(),
		"show_respawn_marker": true,
	}


static func get_all() -> Array[Dictionary]:
	return [get_gauntlet_map()]
