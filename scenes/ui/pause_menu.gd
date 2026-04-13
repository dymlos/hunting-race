class_name PauseMenu
extends Control

signal resume_requested
signal settings_requested
signal reset_requested

var input_blocked: bool = false

var _selected_index: int = 0
var _nav_cooldown: float = 0.0

const NAV_COOLDOWN: float = 0.2
const OPTIONS: Array[String] = ["Resume", "Settings", "Return to Setup"]


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func open() -> void:
	_selected_index = 0
	_nav_cooldown = 0.0
	show()
	queue_redraw()


func _process(delta: float) -> void:
	if not visible or input_blocked:
		return

	_nav_cooldown = maxf(0.0, _nav_cooldown - delta)

	for device_id: int in Input.get_connected_joypads():
		if not InputManager.is_assigned_device(device_id):
			continue

		var stick_y := Input.get_joy_axis(device_id, JOY_AXIS_LEFT_Y)
		if _nav_cooldown <= 0.0:
			if stick_y > 0.5:
				_selected_index = (_selected_index + 1) % OPTIONS.size()
				_nav_cooldown = NAV_COOLDOWN
			elif stick_y < -0.5:
				_selected_index = (_selected_index - 1 + OPTIONS.size()) % OPTIONS.size()
				_nav_cooldown = NAV_COOLDOWN

		if InputManager.is_button_just_pressed_on_device(device_id, JOY_BUTTON_BACK):
			reset_requested.emit()
			return

		if InputManager.is_button_just_pressed_on_device(device_id, JOY_BUTTON_B):
			resume_requested.emit()
			return

		if InputManager.is_button_just_pressed_on_device(device_id, JOY_BUTTON_A) \
				or InputManager.is_button_just_pressed_on_device(device_id, JOY_BUTTON_START):
			if _selected_index == 0:
				resume_requested.emit()
			elif _selected_index == 1:
				settings_requested.emit()
			else:
				reset_requested.emit()
			return

	queue_redraw()


func _draw() -> void:
	var screen := get_viewport_rect().size
	var font := ThemeDB.fallback_font
	var cx := screen.x / 2.0
	var cy := screen.y / 2.0

	draw_rect(Rect2(Vector2.ZERO, screen), Color(0, 0, 0, 0.72))

	var panel_size := Vector2(460, 260)
	var panel_pos := Vector2(cx - panel_size.x / 2.0, cy - panel_size.y / 2.0)
	var panel_rect := Rect2(panel_pos, panel_size)
	draw_rect(panel_rect, Color(0.08, 0.08, 0.08, 0.95))
	draw_rect(panel_rect, Color(0.7, 0.7, 0.7, 0.75), false, 2.0)

	var title := "PAUSED"
	var title_size := 34
	var title_w := font.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, title_size).x
	draw_string(font, Vector2(cx - title_w / 2.0, panel_pos.y + 58),
		title, HORIZONTAL_ALIGNMENT_LEFT, -1, title_size, Color.WHITE)

	for i in OPTIONS.size():
		var text := OPTIONS[i]
		var color := Color.YELLOW if i == _selected_index else Color(0.78, 0.78, 0.78)
		var prefix := "> " if i == _selected_index else "  "
		var display := "%s%s" % [prefix, text]
		var size := 24
		var width := font.get_string_size(display, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
		draw_string(font, Vector2(cx - width / 2.0, panel_pos.y + 125 + i * 42),
			display, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)

	var hint := "UP/DOWN select | A or START confirm | B resume | SELECT setup"
	var hint_size := 13
	var hint_w := font.get_string_size(hint, HORIZONTAL_ALIGNMENT_LEFT, -1, hint_size).x
	draw_string(font, Vector2(cx - hint_w / 2.0, panel_pos.y + panel_size.y - 24),
		hint, HORIZONTAL_ALIGNMENT_LEFT, -1, hint_size, Color(0.55, 0.55, 0.55))
