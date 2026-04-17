class_name StageSelect
extends Control

## Stage selection screen. Left/right to cycle, A to confirm, B to go back.

signal stage_selected(stage_index: int)
signal back_requested

var _stages: Array[Dictionary] = []
var _selected_index: int = 0
var _nav_cooldown: float = 0.0
var input_blocked: bool = false

const NAV_COOLDOWN: float = 0.2
const LOCKED_STAGE_NAMES: Array[String] = ["Toxic Garden", "Clockwork Burrow"]
const LOCKED_STAGE_COLORS: Array[Color] = [
	Color(0.24, 0.78, 0.34),
	Color(0.84, 0.52, 0.16),
]


func setup() -> void:
	_stages = MapData.get_all()
	_selected_index = 0
	_nav_cooldown = 0.0
	show()
	queue_redraw()


func _process(delta: float) -> void:
	if not visible or input_blocked:
		queue_redraw()
		return

	_nav_cooldown = maxf(0.0, _nav_cooldown - delta)

	var pads := Input.get_connected_joypads()
	for device_id: int in pads:
		if not InputManager.is_assigned_device(device_id):
			continue

		if _nav_cooldown <= 0.0:
			var x := Input.get_joy_axis(device_id, JOY_AXIS_LEFT_X)
			if x > 0.5:
				_selected_index = (_selected_index + 1) % _stages.size()
				_nav_cooldown = NAV_COOLDOWN
			elif x < -0.5:
				_selected_index = (_selected_index - 1 + _stages.size()) % _stages.size()
				_nav_cooldown = NAV_COOLDOWN

		if InputManager.is_button_just_pressed_on_device(device_id, JOY_BUTTON_A):
			stage_selected.emit(_selected_index)
			return

		if InputManager.is_button_just_pressed_on_device(device_id, JOY_BUTTON_B):
			back_requested.emit()
			return

	queue_redraw()


func _draw() -> void:
	var screen := get_viewport_rect().size
	var cx := screen.x / 2.0
	var font := ThemeDB.fallback_font

	# Background
	draw_rect(Rect2(Vector2.ZERO, screen), Color(0.02, 0.02, 0.02, 1.0))
	draw_rect(Rect2(Vector2.ZERO, Vector2(screen.x, screen.y * 0.56)), Color(0.05, 0.04, 0.03, 0.12))

	# Title
	_draw_centered_text_in_rect(font, "SELECT STAGE", Rect2(cx - 220.0, 26.0, 440.0, 42.0), 34, Color.WHITE)

	if _stages.is_empty():
		return

	var stage: Dictionary = _stages[_selected_index]
	var stage_name: String = stage.get("name", "Unknown") as String
	var stage_desc: String = stage.get("description", "") as String

	var preview_rect := Rect2(cx - 300.0, 96.0, 600.0, 310.0)
	var preview_accent := Color(0.95, 0.84, 0.18)
	_draw_panel(preview_rect, Color(0.05, 0.05, 0.06, 0.94), Color(preview_accent.r, preview_accent.g, preview_accent.b, 0.75), 2.0)
	draw_rect(Rect2(preview_rect.position, Vector2(preview_rect.size.x, 5.0)), preview_accent)
	_draw_stage_preview(stage, Rect2(preview_rect.position.x + 18.0, preview_rect.position.y + 18.0, preview_rect.size.x - 36.0, preview_rect.size.y - 36.0))
	if _stages.size() > 1:
		_draw_arrow(font, Vector2(preview_rect.position.x - 34.0, preview_rect.position.y + preview_rect.size.y * 0.5), "<")
		_draw_arrow(font, Vector2(preview_rect.end.x + 18.0, preview_rect.position.y + preview_rect.size.y * 0.5), ">")

	_draw_centered_text_in_rect(font, stage_name, Rect2(cx - 340.0, 416.0, 680.0, 40.0), 38, Color(1.0, 0.93, 0.22))

	if not stage_desc.is_empty():
		_draw_centered_text_in_rect(font, stage_desc, Rect2(cx - 420.0, 454.0, 840.0, 28.0), 16, Color(0.74, 0.74, 0.74))

	# Counter
	var total_stage_slots := _stages.size() + LOCKED_STAGE_NAMES.size()
	var counter := "%d AVAILABLE / %d TOTAL" % [_stages.size(), total_stage_slots]
	_draw_centered_text_in_rect(font, counter, Rect2(cx - 180.0, 486.0, 360.0, 18.0), 14, Color(0.48, 0.48, 0.48))
	_draw_centered_text_in_rect(font, "Score rewards escapes, speed, clean runs and fewer respawns.",
		Rect2(cx - 420.0, 510.0, 840.0, 20.0), 14, Color(0.62, 0.62, 0.64))

	_draw_locked_stage_slots(font, screen)

	# Hints
	var hint := "A confirm  |  B back"
	_draw_centered_text_in_rect(font, hint, Rect2(cx - 180.0, screen.y - 54.0, 360.0, 20.0), 16, Color(0.98, 0.92, 0.25))


func _draw_locked_stage_slots(font: Font, screen: Vector2) -> void:
	if LOCKED_STAGE_NAMES.is_empty():
		return

	var cx := screen.x / 2.0
	var slot_w := 240.0
	var slot_h := 88.0
	var gap := 18.0
	var total_w := LOCKED_STAGE_NAMES.size() * slot_w + (LOCKED_STAGE_NAMES.size() - 1) * gap
	var x := cx - total_w / 2.0
	var y := screen.y * 0.68

	for i in LOCKED_STAGE_NAMES.size():
		var rect := Rect2(Vector2(x + i * (slot_w + gap), y), Vector2(slot_w, slot_h))
		var locked_name := LOCKED_STAGE_NAMES[i]
		var accent := LOCKED_STAGE_COLORS[i % LOCKED_STAGE_COLORS.size()]
		_draw_panel(rect, Color(accent.r, accent.g, accent.b, 0.10), Color(accent.r, accent.g, accent.b, 0.85), 2.0)
		draw_rect(Rect2(rect.position, Vector2(rect.size.x, 5.0)), accent)
		_draw_centered_text_in_rect(font, locked_name, Rect2(rect.position.x, rect.position.y + 14.0, rect.size.x, 22.0), 16, Color(0.92, 0.92, 0.92))

		var soon := "COMING SOON"
		_draw_centered_text_in_rect(font, soon, Rect2(rect.position.x, rect.position.y + 42.0, rect.size.x, 18.0), 12, accent.lightened(0.12))


func _draw_panel(rect: Rect2, fill: Color, outline: Color, outline_width: float = 2.0) -> void:
	draw_rect(rect, fill)
	draw_rect(rect, outline, false, outline_width)


func _draw_centered_text_in_rect(font: Font, text: String, rect: Rect2, font_size: int, color: Color) -> void:
	var text_size := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
	var line_height := font.get_height(font_size)
	var baseline_y := rect.position.y + (rect.size.y - line_height) * 0.5 + font.get_ascent(font_size)
	var pos := Vector2(
		rect.position.x + (rect.size.x - text_size.x) * 0.5,
		baseline_y
	)
	var shadow := Color(0.0, 0.0, 0.0, 0.72 * color.a)
	draw_string(font, pos + Vector2(2.0, 2.0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, shadow)
	draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)


func _draw_arrow(font: Font, pos: Vector2, arrow: String) -> void:
	draw_string(font, pos + Vector2(-4.0, -18.0), arrow, HORIZONTAL_ALIGNMENT_LEFT, -1, 36, Color(0.5, 0.5, 0.5))


func _draw_stage_preview(stage: Dictionary, rect: Rect2) -> void:
	var preview_fill := Color(0.03, 0.03, 0.035, 0.96)
	draw_rect(rect, preview_fill)
	draw_rect(rect, Color(0.35, 0.35, 0.35, 0.75), false, 1.5)

	var map_size: Vector2 = stage.get("size", Vector2.ZERO) as Vector2
	if map_size.x <= 0.0 or map_size.y <= 0.0:
		return

	var inner := Rect2(rect.position.x + 8.0, rect.position.y + 8.0, rect.size.x - 16.0, rect.size.y - 16.0)
	var scale := minf(inner.size.x / map_size.x, inner.size.y / map_size.y)
	var draw_size := map_size * scale
	var offset := inner.position + (inner.size - draw_size) * 0.5
	var map_rect := Rect2(offset, draw_size)

	# Boundary
	draw_rect(map_rect, Color(0.06, 0.06, 0.07, 1.0), false, 1.0)

	var walls: Array = stage.get("walls", [])
	for wall_def in walls:
		if not (wall_def is Dictionary):
			continue
		var wall_pos: Vector2 = wall_def.get("pos", Vector2.ZERO) as Vector2
		var wall_size: Vector2 = wall_def.get("size", Vector2.ZERO) as Vector2
		if wall_size.x <= 0.0 or wall_size.y <= 0.0:
			continue
		var wall_rect := Rect2(offset + wall_pos * scale, wall_size * scale)
		draw_rect(wall_rect, Color(0.68, 0.68, 0.68, 0.92))

	var goal_rect: Rect2 = stage.get("goal", Rect2()) as Rect2
	if goal_rect.size.x > 0.0 and goal_rect.size.y > 0.0:
		var goal_draw := Rect2(offset + goal_rect.position * scale, goal_rect.size * scale)
		draw_rect(goal_draw, Color(0.18, 0.95, 0.48, 0.25))
		draw_rect(goal_draw, Color(0.18, 0.95, 0.48, 0.95), false, 2.0)

	var hazards: Array = stage.get("hazards", [])
	for hazard_def in hazards:
		if not (hazard_def is Dictionary):
			continue
		var hazard_pos: Vector2 = hazard_def.get("pos", Vector2.ZERO) as Vector2
		var hazard_size: Vector2 = hazard_def.get("size", Vector2.ZERO) as Vector2
		if hazard_size.x <= 0.0 or hazard_size.y <= 0.0:
			continue
		var hazard_type := str(hazard_def.get("type", ""))
		var hazard_rect := Rect2(offset + hazard_pos * scale, hazard_size * scale)
		match hazard_type:
			"sticky_wall":
				_draw_scaled_hazard_rect(hazard_rect, Constants.STICKY_WALL_COLOR, Color(Constants.STICKY_WALL_COLOR, 0.35))
			"moving_wall":
				_draw_scaled_hazard_rect(hazard_rect, Constants.MOVING_WALL_COLOR, Color(Constants.MOVING_WALL_COLOR, 0.38))
			"slippery_zone":
				_draw_scaled_hazard_rect(hazard_rect, Constants.SLIPPERY_ZONE_COLOR, Color(0.25, 0.85, 1.0, 0.55))
			"one_way_gate":
				_draw_scaled_hazard_rect(hazard_rect, Constants.ONE_WAY_COLOR, Color(0.2, 1.0, 0.4, 0.75))
			"ice_box":
				_draw_scaled_hazard_rect(hazard_rect, Color(0.62, 0.62, 0.62, 1.0), Color(0.86, 0.86, 0.86, 0.7))
			"frost_vent":
				_draw_scaled_hazard_rect(hazard_rect, Constants.FROST_VENT_COLOR, Color(0.75, 1.0, 1.0, 0.8))
			_:
				_draw_scaled_hazard_rect(hazard_rect, Color(0.55, 0.55, 0.58, 0.9), Color(0.75, 0.75, 0.78, 0.55))

	var spawns: Array = stage.get("spawns", [])
	for spawn in spawns:
		if not (spawn is Vector2):
			continue
		var spawn_pos := offset + (spawn as Vector2) * scale
		draw_line(spawn_pos + Vector2(-4.0, 0.0), spawn_pos + Vector2(4.0, 0.0), Color(1.0, 1.0, 1.0, 0.95), 2.0)
		draw_line(spawn_pos + Vector2(0.0, -4.0), spawn_pos + Vector2(0.0, 4.0), Color(1.0, 1.0, 1.0, 0.95), 2.0)


func _draw_scaled_hazard_rect(rect: Rect2, fill: Color, outline: Color) -> void:
	draw_rect(rect, fill)
	draw_rect(rect, outline, false, 1.0)
