class_name StageSelect
extends Control

## Stage selection screen. Left/right to cycle, START to confirm, SELECT to go back.

signal stage_selected(stage_index: int)
signal back_requested

var _stages: Array[Dictionary] = []
var _selected_index: int = 0
var _nav_cooldown: float = 0.0
var input_blocked: bool = false

const NAV_COOLDOWN: float = 0.2


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

		if InputManager.is_button_just_pressed_on_device(device_id, JOY_BUTTON_START):
			stage_selected.emit(_selected_index)
			return

		if InputManager.is_button_just_pressed_on_device(device_id, JOY_BUTTON_BACK):
			back_requested.emit()
			return

	queue_redraw()


func _draw() -> void:
	var screen := get_viewport_rect().size
	var cx := screen.x / 2.0
	var cy := screen.y / 2.0
	var font := ThemeDB.fallback_font

	# Background
	draw_rect(Rect2(Vector2.ZERO, screen), Color.BLACK)

	# Title
	draw_string(font, Vector2(cx - 90, 80), "SELECT STAGE",
		HORIZONTAL_ALIGNMENT_CENTER, -1, 32, Color.WHITE)

	if _stages.is_empty():
		return

	var stage: Dictionary = _stages[_selected_index]
	var stage_name: String = stage.get("name", "Unknown") as String
	var stage_desc: String = stage.get("description", "") as String

	# Stage name
	var name_width := font.get_string_size(stage_name, HORIZONTAL_ALIGNMENT_LEFT, -1, 36).x
	draw_string(font, Vector2(cx - name_width / 2.0, cy - 40),
		stage_name, HORIZONTAL_ALIGNMENT_LEFT, -1, 36, Color.YELLOW)

	# Description
	if not stage_desc.is_empty():
		var desc_width := font.get_string_size(stage_desc, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x
		draw_string(font, Vector2(cx - desc_width / 2.0, cy + 10),
			stage_desc, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(0.7, 0.7, 0.7))

	# Map size info
	var map_size: Vector2 = stage.get("size", Vector2.ZERO) as Vector2
	var hazard_count: int = (stage.get("hazards", []) as Array).size()
	var info := "%dx%d | %d hazards" % [int(map_size.x), int(map_size.y), hazard_count]
	var info_width := font.get_string_size(info, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x
	draw_string(font, Vector2(cx - info_width / 2.0, cy + 40),
		info, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(0.5, 0.5, 0.5))

	# Navigation arrows
	if _stages.size() > 1:
		draw_string(font, Vector2(cx - 180, cy - 40), "<",
			HORIZONTAL_ALIGNMENT_CENTER, -1, 36, Color(0.5, 0.5, 0.5))
		draw_string(font, Vector2(cx + 170, cy - 40), ">",
			HORIZONTAL_ALIGNMENT_CENTER, -1, 36, Color(0.5, 0.5, 0.5))

	# Counter
	var counter := "%d / %d" % [_selected_index + 1, _stages.size()]
	var counter_width := font.get_string_size(counter, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x
	draw_string(font, Vector2(cx - counter_width / 2.0, cy + 70),
		counter, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(0.4, 0.4, 0.4))

	# Hints
	var hint := "START to confirm  |  SELECT to go back"
	var hint_width := font.get_string_size(hint, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x
	draw_string(font, Vector2(cx - hint_width / 2.0, screen.y - 40),
		hint, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color.YELLOW)
