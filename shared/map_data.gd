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
		"description": "Pasillos serpenteantes simples. Sin peligros.",
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
		{"pos": Vector2(300, t), "size": Vector2(t, 210)},
		{"pos": Vector2(300, 400), "size": Vector2(t, 100)},
		{"pos": Vector2(300, 700), "size": Vector2(t, 150)},         # y=700–850
		{"pos": Vector2(300, 1160), "size": Vector2(t, h - 1160 - t)},

		# ============================================================
		# SECTION 2: THREE ROUTES (x: 300–900)
		# ============================================================

		# --- TOP PATH floor (separates top from middle) ---
		# y=350 wall from x=300 to x=900
		{"pos": Vector2(300, 380), "size": Vector2(600, t)},
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
		{"pos": Vector2(320, 990), "size": Vector2(560, t)},
		# BOTTOM PATH: passable strip y=850–940 (90px tall), x=320–880
		# Below the inner ceiling is open negative space, not a second blocked corridor.

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
		{"pos": Vector2(900, 830), "size": Vector2(100, t)},
		# Gap at x=1050-1150 (100px) — bottom path enters here
		# Right segment x=1150-1300
		{"pos": Vector2(1180, 830), "size": Vector2(120, t)},

		# Bottom path opens into the merge instead of suggesting a sealed side corridor.

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

	var top_sticky_left_bounds := Rect2(Vector2(360, 35), Vector2(240, 270))
	var top_sticky_mid_bounds := Rect2(Vector2(510, 98), Vector2(255, 250))
	var top_sticky_right_bounds := Rect2(Vector2(670, 45), Vector2(230, 280))
	var top_sticky_low_left_bounds := Rect2(Vector2(340, 322), Vector2(350, 50))
	var top_sticky_low_right_bounds := Rect2(Vector2(550, 322), Vector2(340, 50))
	var moving_entry_sweeper_bounds := Rect2(Vector2(320, 400), Vector2(280, 410))
	var moving_sweeper_bounds := Rect2(Vector2(300, 370), Vector2(620, 460))
	var moving_blocker_bounds := Rect2(Vector2(320, 370), Vector2(600, 460))
	var middle_sticky_bounds := Rect2(Vector2(360, 420), Vector2(500, 330))
	var middle_low_sticky_bounds := Rect2(Vector2(620, 720), Vector2(240, 110))
	var bottom_sticky_left_upper_bounds := Rect2(Vector2(380, 850), Vector2(95, 118))
	var bottom_sticky_mid_lower_bounds := Rect2(Vector2(500, 878), Vector2(105, 100))
	var bottom_sticky_mid_upper_bounds := Rect2(Vector2(620, 850), Vector2(110, 118))
	var bottom_sticky_right_lower_bounds := Rect2(Vector2(760, 878), Vector2(110, 100))
	var bottom_sticky_upper_lane_bounds := Rect2(Vector2(405, 1004), Vector2(330, 82))
	var bottom_sticky_middle_gap_bounds := Rect2(Vector2(455, 1062), Vector2(280, 60))
	var bottom_sticky_lower_lane_bounds := Rect2(Vector2(500, 1068), Vector2(260, 92))
	var bottom_sticky_lower_left_bounds := Rect2(Vector2(365, 1064), Vector2(155, 96))
	var bottom_sticky_lower_right_bounds := Rect2(Vector2(710, 1064), Vector2(145, 96))
	var bottom_slippery_bounds := Rect2(Vector2(790, 860), Vector2(390, 180))
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
	var sticky_maze_left_top_bounds := Rect2(Vector2(1865, 270), Vector2(180, 260))
	var sticky_maze_left_bottom_bounds := Rect2(Vector2(1865, 635), Vector2(190, 315))
	var sticky_maze_mid_top_bounds := Rect2(Vector2(2005, 155), Vector2(220, 330))
	var sticky_maze_mid_bottom_bounds := Rect2(Vector2(2005, 520), Vector2(230, 305))
	var sticky_maze_right_top_bounds := Rect2(Vector2(2145, 250), Vector2(220, 330))
	var sticky_maze_right_bottom_bounds := Rect2(Vector2(2145, 645), Vector2(220, 310))
	var sticky_maze_goal_top_bounds := Rect2(Vector2(2230, 220), Vector2(140, 330))
	var sticky_maze_goal_bottom_bounds := Rect2(Vector2(2230, 620), Vector2(140, 340))
	var sticky_maze_slippery_top_bounds := Rect2(Vector2(1835, 120), Vector2(290, 180))
	var sticky_maze_slippery_bottom_bounds := Rect2(Vector2(1950, 875), Vector2(310, 170))
	var sticky_maze_slippery_goal_bounds := Rect2(Vector2(2155, 470), Vector2(225, 190))
	var sticky_maze_lift_left_bounds := Rect2(Vector2(1810, 440), Vector2(150, 260))
	var sticky_maze_lift_upper_bounds := Rect2(Vector2(1885, 340), Vector2(110, 300))
	var sticky_maze_lift_mid_bounds := Rect2(Vector2(2085, 450), Vector2(110, 260))
	var sticky_maze_lift_bottom_bounds := Rect2(Vector2(2010, 890), Vector2(360, 80))
	var goal_top_guard_bounds := Rect2(Vector2(2185, 390), Vector2(185, 48))
	var goal_bottom_guard_bounds := Rect2(Vector2(2185, 772), Vector2(185, 48))
	var top_entrance_sticky_bounds := Rect2(Vector2(1840, 120), Vector2(190, 330))
	var bottom_entrance_sticky_bounds := Rect2(Vector2(1840, 720), Vector2(190, 330))
	var goal_top_blob_bounds := Rect2(Vector2(1815, 105), Vector2(470, 255))
	var goal_bottom_blob_bounds := Rect2(Vector2(1840, 840), Vector2(510, 260))

	var hazards: Array[Dictionary] = [
		# === TOP PATH: STICKY WALLS inside corridor (y=20-350, x=300-900) ===
		{
			"type": "sticky_wall",
			"pos": Vector2(420, 55),
			"size": Vector2(12, 175),
			"end_pos": Vector2(555, 55),
			"period": 2.45,
			"jitter": Vector2(28, 34),
			"bounds": top_sticky_left_bounds,
		},
		{
			"type": "sticky_wall",
			"pos": Vector2(580, 145),
			"size": Vector2(12, 145),
			"end_pos": Vector2(735, 145),
			"period": 2.6,
			"jitter": Vector2(28, 34),
			"bounds": top_sticky_mid_bounds,
		},
		{
			"type": "sticky_wall",
			"pos": Vector2(740, 70),
			"size": Vector2(12, 170),
			"end_pos": Vector2(875, 70),
			"period": 2.5,
			"jitter": Vector2(28, 34),
			"bounds": top_sticky_right_bounds,
		},
		{
			"type": "sticky_wall",
			"pos": Vector2(370, 344),
			"size": Vector2(96, 16),
			"end_pos": Vector2(570, 344),
			"period": 2.35,
			"jitter": Vector2(24, 10),
			"bounds": top_sticky_low_left_bounds,
		},
		{
			"type": "sticky_wall",
			"pos": Vector2(585, 344),
			"size": Vector2(96, 16),
			"end_pos": Vector2(785, 344),
			"period": 2.4,
			"jitter": Vector2(24, 10),
			"bounds": top_sticky_low_right_bounds,
		},

		# === MIDDLE PATH: MOVING WALLS (y=370-830, x=300-900) ===
		{
			"type": "moving_wall",
			"pos": Vector2(340, 430),
			"size": Vector2(140, t),
			"end_pos": Vector2(340, 785),
			"period": 3.35,
			"jitter": Vector2(35, 35),
			"bounds": moving_entry_sweeper_bounds,
		},
		{
			"type": "moving_wall",
			"pos": Vector2(400, 390),
			"size": Vector2(180, t),
			"end_pos": Vector2(400, 805),
			"period": 3.5,
			"jitter": Vector2(220, 80),
			"bounds": moving_sweeper_bounds,
		},
		{
			"type": "moving_wall",
			"pos": Vector2(620, 805),
			"size": Vector2(180, t),
			"end_pos": Vector2(620, 390),
			"period": 3.8,
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
			"pos": Vector2(728, 754),
			"size": Vector2(18, 72),
			"jitter": Vector2(65, 6),
			"bounds": middle_low_sticky_bounds,
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
			"pos": Vector2(410, 865),
			"size": Vector2(10, 10),
			"jitter": Vector2(45, 22),
			"bounds": bottom_sticky_left_upper_bounds,
		},
		{
			"type": "sticky_wall",
			"pos": Vector2(455, 930),
			"size": Vector2(10, 10),
			"jitter": Vector2(35, 28),
			"bounds": bottom_sticky_left_upper_bounds,
		},
		{
			"type": "sticky_wall",
			"pos": Vector2(535, 915),
			"size": Vector2(10, 10),
			"jitter": Vector2(48, 34),
			"bounds": bottom_sticky_mid_lower_bounds,
		},
		{
			"type": "sticky_wall",
			"pos": Vector2(580, 958),
			"size": Vector2(10, 10),
			"jitter": Vector2(38, 22),
			"bounds": bottom_sticky_mid_lower_bounds,
		},
		{
			"type": "sticky_wall",
			"pos": Vector2(655, 866),
			"size": Vector2(10, 10),
			"jitter": Vector2(48, 22),
			"bounds": bottom_sticky_mid_upper_bounds,
		},
		{
			"type": "sticky_wall",
			"pos": Vector2(704, 932),
			"size": Vector2(10, 10),
			"jitter": Vector2(38, 28),
			"bounds": bottom_sticky_mid_upper_bounds,
		},
		{
			"type": "sticky_wall",
			"pos": Vector2(805, 918),
			"size": Vector2(10, 10),
			"jitter": Vector2(48, 34),
			"bounds": bottom_sticky_right_lower_bounds,
		},
		{
			"type": "sticky_wall",
			"pos": Vector2(840, 956),
			"size": Vector2(10, 10),
			"jitter": Vector2(24, 22),
			"bounds": bottom_sticky_right_lower_bounds,
		},
		{
			"type": "slippery_zone",
			"pos": Vector2(860, 866),
			"size": Vector2(190, 108),
			"jitter": Vector2(110, 50),
			"bounds": bottom_slippery_bounds,
		},
		{
			"type": "sticky_wall",
			"pos": Vector2(470, 1024),
			"size": Vector2(10, 10),
			"jitter": Vector2(74, 18),
			"bounds": bottom_sticky_upper_lane_bounds,
		},
		{
			"type": "sticky_wall",
			"pos": Vector2(555, 1074),
			"size": Vector2(10, 10),
			"jitter": Vector2(70, 20),
			"bounds": bottom_sticky_upper_lane_bounds,
		},
		{
			"type": "sticky_wall",
			"pos": Vector2(585, 1084),
			"size": Vector2(10, 10),
			"jitter": Vector2(80, 16),
			"bounds": bottom_sticky_middle_gap_bounds,
		},
		{
			"type": "sticky_wall",
			"pos": Vector2(620, 1090),
			"size": Vector2(10, 10),
			"jitter": Vector2(82, 24),
			"bounds": bottom_sticky_lower_lane_bounds,
		},
		{
			"type": "sticky_wall",
			"pos": Vector2(690, 1142),
			"size": Vector2(10, 10),
			"jitter": Vector2(72, 18),
			"bounds": bottom_sticky_lower_lane_bounds,
		},
		{
			"type": "sticky_wall",
			"pos": Vector2(404, 1098),
			"size": Vector2(10, 10),
			"jitter": Vector2(46, 22),
			"bounds": bottom_sticky_lower_left_bounds,
		},
		{
			"type": "sticky_wall",
			"pos": Vector2(448, 1138),
			"size": Vector2(10, 10),
			"jitter": Vector2(42, 18),
			"bounds": bottom_sticky_lower_left_bounds,
		},
		{
			"type": "sticky_wall",
			"pos": Vector2(776, 1098),
			"size": Vector2(10, 10),
			"jitter": Vector2(54, 22),
			"bounds": bottom_sticky_lower_right_bounds,
		},
		{
			"type": "sticky_wall",
			"pos": Vector2(812, 1140),
			"size": Vector2(10, 10),
			"jitter": Vector2(44, 18),
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
			"end_pos": Vector2(1998, 390),
			"period": 2.45,
			"jitter": Vector2(20, 32),
			"bounds": sticky_maze_left_top_bounds,
		},
		{
			"type": "sticky_wall",
			"pos": Vector2(1925, 735),
			"size": Vector2(28, 130),
			"end_pos": Vector2(1995, 815),
			"period": 2.35,
			"jitter": Vector2(22, 42),
			"bounds": sticky_maze_left_bottom_bounds,
		},
		{
			"type": "sticky_wall",
			"pos": Vector2(2050, 195),
			"size": Vector2(28, 115),
			"end_pos": Vector2(2180, 320),
			"period": 2.5,
			"jitter": Vector2(22, 40),
			"bounds": sticky_maze_mid_top_bounds,
		},
		{
			"type": "sticky_wall",
			"pos": Vector2(2050, 580),
			"size": Vector2(28, 115),
			"end_pos": Vector2(2190, 700),
			"period": 2.4,
			"jitter": Vector2(26, 40),
			"bounds": sticky_maze_mid_bottom_bounds,
		},
		{
			"type": "sticky_wall",
			"pos": Vector2(2175, 360),
			"size": Vector2(28, 125),
			"end_pos": Vector2(2305, 450),
			"period": 2.4,
			"jitter": Vector2(24, 42),
			"bounds": sticky_maze_right_top_bounds,
		},
		{
			"type": "sticky_wall",
			"pos": Vector2(2175, 770),
			"size": Vector2(28, 125),
			"end_pos": Vector2(2300, 700),
			"period": 2.45,
			"jitter": Vector2(24, 42),
			"bounds": sticky_maze_right_bottom_bounds,
		},
		{
			"type": "sticky_wall",
			"pos": Vector2(2285, 245),
			"size": Vector2(28, 90),
			"end_pos": Vector2(2285, 485),
			"period": 2.35,
			"jitter": Vector2(18, 28),
			"bounds": sticky_maze_goal_top_bounds,
		},
		{
			"type": "sticky_wall",
			"pos": Vector2(2285, 850),
			"size": Vector2(28, 90),
			"end_pos": Vector2(2285, 640),
			"period": 2.35,
			"jitter": Vector2(18, 28),
			"bounds": sticky_maze_goal_bottom_bounds,
		},
		{
			"type": "slippery_zone",
			"pos": Vector2(1860, 145),
			"size": Vector2(165, 85),
			"end_pos": Vector2(1950, 200),
			"period": 3.45,
			"fixed": true,
			"bounds": sticky_maze_slippery_top_bounds,
		},
		{
			"type": "sticky_wall",
			"pos": Vector2(1848, 170),
			"size": Vector2(10, 10),
			"period": 1.15,
			"patrol_offset": Vector2(92, 34),
			"bounds": goal_top_blob_bounds,
		},
		{
			"type": "sticky_wall",
			"pos": Vector2(1935, 280),
			"size": Vector2(10, 10),
			"period": 1.25,
			"patrol_offset": Vector2(-78, 42),
			"bounds": goal_top_blob_bounds,
		},
		{
			"type": "sticky_wall",
			"pos": Vector2(2035, 145),
			"size": Vector2(10, 10),
			"period": 1.2,
			"patrol_offset": Vector2(72, 58),
			"bounds": goal_top_blob_bounds,
		},
		{
			"type": "sticky_wall",
			"pos": Vector2(2155, 255),
			"size": Vector2(10, 10),
			"period": 1.3,
			"patrol_offset": Vector2(-84, -42),
			"bounds": goal_top_blob_bounds,
		},
		{
			"type": "sticky_wall",
			"pos": Vector2(2235, 180),
			"size": Vector2(10, 10),
			"period": 1.18,
			"patrol_offset": Vector2(42, 78),
			"bounds": goal_top_blob_bounds,
		},
		{
			"type": "sticky_wall",
			"pos": Vector2(1888, 325),
			"size": Vector2(10, 10),
			"period": 1.24,
			"patrol_offset": Vector2(68, -56),
			"bounds": goal_top_blob_bounds,
		},
		{
			"type": "sticky_wall",
			"pos": Vector2(1998, 115),
			"size": Vector2(10, 10),
			"period": 1.19,
			"patrol_offset": Vector2(-82, 48),
			"bounds": goal_top_blob_bounds,
		},
		{
			"type": "sticky_wall",
			"pos": Vector2(2095, 320),
			"size": Vector2(10, 10),
			"period": 1.31,
			"patrol_offset": Vector2(76, -62),
			"bounds": goal_top_blob_bounds,
		},
		{
			"type": "sticky_wall",
			"pos": Vector2(2190, 125),
			"size": Vector2(10, 10),
			"period": 1.21,
			"patrol_offset": Vector2(-66, 74),
			"bounds": goal_top_blob_bounds,
		},
		{
			"type": "sticky_wall",
			"pos": Vector2(2270, 310),
			"size": Vector2(10, 10),
			"period": 1.27,
			"patrol_offset": Vector2(-74, -52),
			"bounds": goal_top_blob_bounds,
		},
		{
			"type": "slippery_zone",
			"pos": Vector2(1970, 900),
			"size": Vector2(170, 85),
			"end_pos": Vector2(2075, 960),
			"period": 3.65,
			"fixed": true,
			"bounds": sticky_maze_slippery_bottom_bounds,
		},
		{
			"type": "sticky_wall",
			"pos": Vector2(1875, 935),
			"size": Vector2(10, 10),
			"period": 1.22,
			"patrol_offset": Vector2(86, -46),
			"bounds": goal_bottom_blob_bounds,
		},
		{
			"type": "sticky_wall",
			"pos": Vector2(1975, 1030),
			"size": Vector2(10, 10),
			"period": 1.28,
			"patrol_offset": Vector2(-70, -64),
			"bounds": goal_bottom_blob_bounds,
		},
		{
			"type": "sticky_wall",
			"pos": Vector2(2070, 875),
			"size": Vector2(10, 10),
			"period": 1.16,
			"patrol_offset": Vector2(94, 38),
			"bounds": goal_bottom_blob_bounds,
		},
		{
			"type": "sticky_wall",
			"pos": Vector2(2180, 1010),
			"size": Vector2(10, 10),
			"period": 1.26,
			"patrol_offset": Vector2(-88, -36),
			"bounds": goal_bottom_blob_bounds,
		},
		{
			"type": "sticky_wall",
			"pos": Vector2(2280, 930),
			"size": Vector2(10, 10),
			"period": 1.18,
			"patrol_offset": Vector2(54, 68),
			"bounds": goal_bottom_blob_bounds,
		},
		{
			"type": "sticky_wall",
			"pos": Vector2(1905, 1080),
			"size": Vector2(10, 10),
			"period": 1.2,
			"patrol_offset": Vector2(78, -58),
			"bounds": goal_bottom_blob_bounds,
		},
		{
			"type": "sticky_wall",
			"pos": Vector2(2015, 860),
			"size": Vector2(10, 10),
			"period": 1.24,
			"patrol_offset": Vector2(-82, 54),
			"bounds": goal_bottom_blob_bounds,
		},
		{
			"type": "sticky_wall",
			"pos": Vector2(2110, 1070),
			"size": Vector2(10, 10),
			"period": 1.32,
			"patrol_offset": Vector2(92, -42),
			"bounds": goal_bottom_blob_bounds,
		},
		{
			"type": "sticky_wall",
			"pos": Vector2(2210, 875),
			"size": Vector2(10, 10),
			"period": 1.17,
			"patrol_offset": Vector2(-70, 70),
			"bounds": goal_bottom_blob_bounds,
		},
		{
			"type": "sticky_wall",
			"pos": Vector2(2330, 1060),
			"size": Vector2(10, 10),
			"period": 1.29,
			"patrol_offset": Vector2(-96, -48),
			"bounds": goal_bottom_blob_bounds,
		},
		{
			"type": "slippery_zone",
			"pos": Vector2(2215, 500),
			"size": Vector2(125, 95),
			"end_pos": Vector2(2165, 575),
			"period": 3.25,
			"fixed": true,
			"bounds": sticky_maze_slippery_goal_bounds,
		},
		{
			"type": "moving_wall",
			"pos": Vector2(1825, 650),
			"size": Vector2(120, 12),
			"end_pos": Vector2(1825, 470),
			"period": 1.9,
			"fixed": true,
			"bounds": sticky_maze_lift_left_bounds,
		},
		{
			"type": "moving_wall",
			"pos": Vector2(1915, 600),
			"size": Vector2(12, 120),
			"end_pos": Vector2(1915, 380),
			"period": 2.0,
			"fixed": true,
			"bounds": sticky_maze_lift_upper_bounds,
		},
		{
			"type": "moving_wall",
			"pos": Vector2(2135, 500),
			"size": Vector2(12, 130),
			"end_pos": Vector2(2135, 640),
			"period": 1.85,
			"fixed": true,
			"bounds": sticky_maze_lift_mid_bounds,
		},
		{
			"type": "moving_wall",
			"pos": Vector2(2250, 930),
			"size": Vector2(120, 12),
			"end_pos": Vector2(2025, 930),
			"period": 2.1,
			"fixed": true,
			"bounds": sticky_maze_lift_bottom_bounds,
		},
		{
			"type": "moving_wall",
			"pos": Vector2(2195, 405),
			"size": Vector2(125, 12),
			"end_pos": Vector2(2245, 405),
			"period": 0.95,
			"fixed": true,
			"bounds": goal_top_guard_bounds,
		},
		{
			"type": "moving_wall",
			"pos": Vector2(2195, 790),
			"size": Vector2(125, 12),
			"end_pos": Vector2(2245, 790),
			"period": 0.95,
			"fixed": true,
			"bounds": goal_bottom_guard_bounds,
		},
		# Thin sticky strips on corridor entrance walls
		{
			"type": "sticky_wall",
			"pos": Vector2(1852, 250),
			"size": Vector2(12, 100),
			"end_pos": Vector2(1975, 250),
			"period": 2.35,
			"jitter": Vector2(0, 95),
			"bounds": top_entrance_sticky_bounds,
		},
		{
			"type": "sticky_wall",
			"pos": Vector2(1852, h - 350),
			"size": Vector2(12, 100),
			"end_pos": Vector2(1975, h - 350),
			"period": 2.35,
			"jitter": Vector2(0, 95),
			"bounds": bottom_entrance_sticky_bounds,
		},
	]

	return {
		"name": "El deslizadero pegajoso",
		"description": "3 rutas: corredor adhesivo, muros móviles o túnel seguro. Todas llegan a un laberinto adhesivo.",
		"size": Vector2(w, h),
		"walls": walls,
		"hazards": hazards,
		"spawns": [
			Vector2(120, 450), Vector2(120, 560),
			Vector2(120, 670), Vector2(120, 780),
			Vector2(200, 500), Vector2(200, 620),
		],
		"safety_checkpoint": {
			"zone": Rect2(1710, 300, 120, 600),
			"respawn_zone": Rect2(1765, 340, 90, 520),
		},
		"goal": Rect2(w - t - 70, 430, 70, 340),
	}


static func get_practice_map() -> Dictionary:
	var w := 1600.0
	var h := 900.0
	var spawn := Vector2(w / 2.0, h / 2.0)
	var respawn_zone := Rect2(spawn - Vector2(120.0, 65.0), Vector2(240.0, 130.0))

	return {
		"name": "Sala de práctica",
		"description": "Una sala limpia para probar movimiento, trampas y habilidades.",
		"size": Vector2(w, h),
		"walls": [],
		"hazards": [],
		"spawns": [spawn],
		"goal": Rect2(),
		"respawn_zone": respawn_zone,
		"show_respawn_marker": true,
	}


static func get_survival_test_map(team_size: int = 1) -> Dictionary:
	var w := 1500.0
	var h := 860.0
	var t := 24.0

	var map_data: Dictionary = {
		"name": "Refugio de prueba",
		"description": "Mapa compacto para probar roles fijos, timer, salida grupal y oleadas simples.",
		"size": Vector2(w, h),
		"survival_duration": 240.0,
		"floor_color": Color(0.52, 0.49, 0.40),
		"floor_upper_haze": Color(0.70, 0.65, 0.52, 0.18),
		"floor_lower_haze": Color(0.40, 0.38, 0.32, 0.16),
		"floor_dust_color": Color(0.94, 0.88, 0.70, 0.08),
		"floor_border_color": Color(0.15, 0.13, 0.10, 0.18),
		"floor_outside_margin": 512.0,
		"goal_blocks_survival_enemies": true,
		"walls": [
			{"pos": Vector2(0, 0), "size": Vector2(w, t)},
			{"pos": Vector2(0, h - t), "size": Vector2(w, t)},
			{"pos": Vector2(0, 0), "size": Vector2(t, h)},
			{"pos": Vector2(w - t, 0), "size": Vector2(t, h)},

			{"pos": Vector2(305, 145), "size": Vector2(t, 245)},
			{"pos": Vector2(305, 510), "size": Vector2(t, 205)},
			{"pos": Vector2(520, 250), "size": Vector2(350, t)},
			{"pos": Vector2(520, 590), "size": Vector2(350, t)},
			{"pos": Vector2(735, 360), "size": Vector2(t, 140)},
			{"pos": Vector2(1030, 120), "size": Vector2(t, 255)},
			{"pos": Vector2(1030, 525), "size": Vector2(t, 225)},
			{"pos": Vector2(1195, 300), "size": Vector2(130, t)},
			{"pos": Vector2(1195, 535), "size": Vector2(130, t)},
		],
		"hazards": [],
		"spawns": [
			Vector2(118, 330),
			Vector2(118, 430),
			Vector2(118, 530),
			Vector2(118, 630),
		],
		"survival_trapper_spawns": [
			Vector2(610, 410),
			Vector2(905, 455),
			Vector2(1110, 220),
			Vector2(1110, 660),
		],
		"survival_zombie_spawns": [
			Vector2(435, 96),
			Vector2(680, 96),
			Vector2(950, 92),
			Vector2(1340, 180),
			Vector2(1345, 700),
			Vector2(940, 772),
			Vector2(640, 772),
			Vector2(430, 765),
		],
		"survival_jail": {
			"rect": Rect2(52, 692, 146, 104),
			"release_rect": Rect2(204, 714, 44, 60),
			"spawn": Vector2(125, 744),
			"release_position": Vector2(270, 744),
			"wall_thickness": 12.0,
		},
		"survival_locks": [
			{
				"id": "blue",
				"label": "AZUL",
				"color": Color(0.20, 0.58, 1.0),
				"key_rect": Rect2(1262, 674, 38, 38),
				"key_hidden": true,
				"gate_rect": Rect2(390, 90, 70, 70),
				"button_rect": Rect2(404, 104, 42, 42),
			},
			{
				"id": "red",
				"label": "ROJA",
				"color": Color(1.0, 0.22, 0.18),
				"key_rect": Rect2(1220, 168, 38, 38),
				"key_hidden": true,
				"gate_rect": Rect2(390, 695, 70, 70),
				"button_rect": Rect2(404, 709, 42, 42),
			},
			{
				"id": "yellow",
				"label": "AMARILLA",
				"color": Color(1.0, 0.84, 0.16),
				"key_rect": Rect2(190, 430, 38, 38),
				"key_hidden": true,
				"gate_rect": Rect2(880, 410, 70, 70),
				"button_rect": Rect2(894, 424, 42, 42),
			},
		],
		"goal": Rect2(w - t - 86, 292, 86, 276),
	}
	var scale := _get_survival_team_scale(team_size)
	var scaled_map := _scale_survival_map_data(map_data, scale)
	scaled_map["survival_team_size"] = clampi(team_size, 1, 4)
	scaled_map["survival_team_scale"] = scale
	return scaled_map


static func _get_survival_team_scale(team_size: int) -> float:
	match clampi(team_size, 1, 4):
		1:
			return 1.0
		2:
			return 1.12
		3:
			return 1.20
	return 1.28


static func _scale_survival_map_data(map_data: Dictionary, scale: float) -> Dictionary:
	if is_equal_approx(scale, 1.0):
		return map_data.duplicate(true)
	return _scale_survival_value(map_data, scale) as Dictionary


static func _scale_survival_value(value: Variant, scale: float) -> Variant:
	if value is Vector2:
		return (value as Vector2) * scale
	if value is Rect2:
		var rect := value as Rect2
		return Rect2(rect.position * scale, rect.size * scale)
	if value is Dictionary:
		var scaled_dict: Dictionary = {}
		for key in value:
			scaled_dict[key] = _scale_survival_value(value[key], scale)
		return scaled_dict
	if value is Array:
		var scaled_array: Array = []
		for item in value:
			scaled_array.append(_scale_survival_value(item, scale))
		return scaled_array
	return value


static func get_all() -> Array[Dictionary]:
	return [get_gauntlet_map()]
