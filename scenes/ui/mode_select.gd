class_name ModeSelect
extends Control

signal official_requested
signal practice_requested
signal survival_requested
signal rules_requested
signal back_requested

var input_blocked: bool = false

var _selected_index: int = 0
var _nav_axis_locked: bool = false
var _prev_keyboard_confirm: bool = false

const NAV_AXIS_THRESHOLD: float = 0.84
const NAV_AXIS_RELEASE: float = 0.42
const OPTIONS: Array[String] = ["Survival Escape", "Partida oficial", "Modo práctica", "Cómo jugar"]


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func open() -> void:
	_selected_index = 0
	_nav_axis_locked = _is_any_navigation_axis_active()
	_prev_keyboard_confirm = Input.is_key_pressed(KEY_ENTER) or Input.is_key_pressed(KEY_SPACE)
	show()
	queue_redraw()


func _is_any_navigation_axis_active() -> bool:
	for device_id: int in Input.get_connected_joypads():
		if absf(Input.get_joy_axis(device_id, JOY_AXIS_LEFT_X)) > NAV_AXIS_RELEASE \
				or absf(Input.get_joy_axis(device_id, JOY_AXIS_LEFT_Y)) > NAV_AXIS_RELEASE:
			return true
	return false


func _process(_delta: float) -> void:
	if not visible or input_blocked:
		return

	var axis_direction := 0
	var axis_neutral := true
	for device_id: int in Input.get_connected_joypads():
		var move_x := Input.get_joy_axis(device_id, JOY_AXIS_LEFT_X)
		var move_y := Input.get_joy_axis(device_id, JOY_AXIS_LEFT_Y)
		var abs_x := absf(move_x)
		var abs_y := absf(move_y)
		if abs_x > NAV_AXIS_RELEASE or abs_y > NAV_AXIS_RELEASE:
			axis_neutral = false
		if not _nav_axis_locked and axis_direction == 0:
			if abs_x >= abs_y:
				if move_x > NAV_AXIS_THRESHOLD:
					axis_direction = 1
				elif move_x < -NAV_AXIS_THRESHOLD:
					axis_direction = -1
			else:
				if move_y > NAV_AXIS_THRESHOLD:
					axis_direction = 1
				elif move_y < -NAV_AXIS_THRESHOLD:
					axis_direction = -1

		if InputManager.is_menu_confirm_just_pressed(device_id):
			_confirm_selection()
			return
		if InputManager.is_menu_back_just_pressed(device_id):
			back_requested.emit()
			return

	if _nav_axis_locked and axis_neutral:
		_nav_axis_locked = false
	if not _nav_axis_locked and axis_direction != 0:
		_selected_index = (_selected_index + axis_direction + OPTIONS.size()) % OPTIONS.size()
		_nav_axis_locked = true

	var keyboard_confirm := Input.is_key_pressed(KEY_ENTER) or Input.is_key_pressed(KEY_SPACE)
	if keyboard_confirm and not _prev_keyboard_confirm:
		_confirm_selection()
		return
	_prev_keyboard_confirm = keyboard_confirm

	queue_redraw()


func _confirm_selection() -> void:
	match _selected_index:
		0:
			survival_requested.emit()
		1:
			official_requested.emit()
		2:
			practice_requested.emit()
		_:
			rules_requested.emit()


func _draw() -> void:
	var screen := get_viewport_rect().size
	var font := ThemeDB.fallback_font
	var cx := screen.x / 2.0
	var cy := screen.y / 2.0

	draw_rect(Rect2(Vector2.ZERO, screen), Color.BLACK)

	var title := "ELEGIR MODO"
	var title_size := 34
	var title_width := font.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, title_size).x
	draw_string(font, Vector2(cx - title_width / 2.0, cy - 150.0),
		title, HORIZONTAL_ALIGNMENT_LEFT, -1, title_size, Color.WHITE)

	var sub := "Prueba survival, juega una partida oficial, entrena libremente o revisa las reglas."
	var sub_width := font.get_string_size(sub, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x
	draw_string(font, Vector2(cx - sub_width / 2.0, cy - 112.0),
		sub, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(0.65, 0.65, 0.65))

	var option_w := 220.0
	var option_h := 92.0
	var gap := 22.0
	var total_w := OPTIONS.size() * option_w + (OPTIONS.size() - 1) * gap
	var start_x := cx - total_w / 2.0
	for i in OPTIONS.size():
		var rect := Rect2(Vector2(start_x + float(i) * (option_w + gap), cy - 40.0),
			Vector2(option_w, option_h))
		var selected := i == _selected_index
		var is_help := i == 3
		var is_survival := i == 0
		var border_color := Color.YELLOW if selected else Color(0.45, 0.45, 0.45)
		var bg_color := Color(0.16, 0.16, 0.16) if selected else Color(0.1, 0.1, 0.1)
		if is_help and not selected:
			border_color = Color(0.38, 0.38, 0.42)
			bg_color = Color(0.08, 0.08, 0.085)
		elif is_survival and not selected:
			border_color = Color(0.24, 0.68, 0.42)
			bg_color = Color(0.055, 0.095, 0.07)
		draw_rect(rect, bg_color)
		draw_rect(rect, border_color, false, 2.0)

		var text := OPTIONS[i]
		var text_size := 22
		if is_help:
			text_size = 19
		elif is_survival:
			text_size = 18
		var text_width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, text_size).x
		var text_y := rect.position.y + 40.0
		if is_help:
			text_y = rect.position.y + 38.0
		draw_string(font, Vector2(rect.position.x + rect.size.x / 2.0 - text_width / 2.0,
				text_y),
			text, HORIZONTAL_ALIGNMENT_LEFT, -1, text_size, border_color)

		var detail := "Equipos, puntaje, rondas"
		if i == 1:
			detail = "Equipos, puntaje, rondas"
		elif i == 2:
			detail = "Sala libre, sin puntaje"
		elif i == 0:
			detail = "Roles fijos y oleadas"
		elif i == 3:
			detail = "Reglas, puntaje, habilidades"
		var detail_width := font.get_string_size(detail, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x
		draw_string(font, Vector2(rect.position.x + rect.size.x / 2.0 - detail_width / 2.0,
				rect.position.y + 66.0),
			detail, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0.62, 0.62, 0.62))
		if is_help:
			_draw_centered_text_in_rect(font, "AYUDA", Rect2(rect.position.x, rect.position.y + 12.0, rect.size.x, 14.0), 11, Color(0.9, 0.8, 0.45))
		elif is_survival:
			_draw_centered_text_in_rect(font, "NUEVO", Rect2(rect.position.x, rect.position.y + 12.0, rect.size.x, 14.0), 11, Color(0.55, 1.0, 0.72))

	var hint := "Izq./Der. elegir | Start confirmar | Select volver"
	var hint_width := font.get_string_size(hint, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x
	draw_string(font, Vector2(cx - hint_width / 2.0, cy + 110.0),
		hint, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color.YELLOW)


func _draw_centered_text_in_rect(font: Font, text: String, rect: Rect2, font_size: int, color: Color) -> void:
	var text_size := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
	var line_height := font.get_height(font_size)
	var baseline_y := rect.position.y + (rect.size.y - line_height) * 0.5 + font.get_ascent(font_size)
	var pos := Vector2(rect.position.x + (rect.size.x - text_size.x) * 0.5, baseline_y)
	var shadow := Color(0.0, 0.0, 0.0, 0.72 * color.a)
	draw_string(font, pos + Vector2(2.0, 2.0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, shadow)
	draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)
