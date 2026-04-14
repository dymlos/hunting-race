class_name PracticeSetup
extends Control

signal practice_ready(team_assignments: Dictionary, role_assignments: Dictionary)
signal back_requested

var input_blocked: bool = false

var _player_joined: Dictionary = {}
var _player_roles: Dictionary = {}
var _nav_cooldowns: Dictionary = {}

const NAV_COOLDOWN: float = 0.2


func setup() -> void:
	_player_joined.clear()
	_player_roles.clear()
	_nav_cooldowns.clear()
	show()
	queue_redraw()


func _process(delta: float) -> void:
	if not visible or input_blocked:
		queue_redraw()
		return

	var connected_pads := Input.get_connected_joypads()
	var stale_devices: Array[int] = []
	for device_id: int in _player_joined:
		if device_id not in connected_pads:
			stale_devices.append(device_id)
	for device_id: int in stale_devices:
		_player_joined.erase(device_id)
		_player_roles.erase(device_id)
		_nav_cooldowns.erase(device_id)

	for device_id: int in _nav_cooldowns:
		_nav_cooldowns[device_id] = maxf(0.0, _nav_cooldowns[device_id] - delta)

	for device_id: int in connected_pads:
		if _player_joined.get(device_id, false):
			if InputManager.is_button_just_pressed_on_device(device_id, JOY_BUTTON_B):
				_player_joined.erase(device_id)
				_player_roles.erase(device_id)
				_nav_cooldowns.erase(device_id)
				continue

			if _nav_cooldowns.get(device_id, 0.0) <= 0.0:
				var move_x := Input.get_joy_axis(device_id, JOY_AXIS_LEFT_X)
				if absf(move_x) > 0.5:
					_toggle_role(device_id)
					_nav_cooldowns[device_id] = NAV_COOLDOWN
		else:
			if InputManager.is_button_just_pressed_on_device(device_id, JOY_BUTTON_A):
				_player_joined[device_id] = true
				_player_roles[device_id] = Enums.Role.ESCAPIST
				_nav_cooldowns[device_id] = NAV_COOLDOWN

	if _get_joined_devices().is_empty():
		for device_id: int in connected_pads:
			if InputManager.is_button_just_pressed_on_device(device_id, JOY_BUTTON_B):
				back_requested.emit()
				return

	if not _get_joined_devices().is_empty():
		for device_id: int in _get_joined_devices():
			if InputManager.is_button_just_pressed_on_device(device_id, JOY_BUTTON_START):
				_advance()
				return

	queue_redraw()


func _toggle_role(device_id: int) -> void:
	var current_role: Enums.Role = _player_roles.get(device_id, Enums.Role.ESCAPIST) as Enums.Role
	if current_role == Enums.Role.ESCAPIST:
		_player_roles[device_id] = Enums.Role.TRAPPER
	else:
		_player_roles[device_id] = Enums.Role.ESCAPIST


func _get_joined_devices() -> Array[int]:
	var devices: Array[int] = []
	for device_id: int in _player_joined:
		if _player_joined.get(device_id, false):
			devices.append(device_id)
	devices.sort()
	return devices


func _advance() -> void:
	var devices := _get_joined_devices()
	var team_assignments: Dictionary = {}
	var role_assignments: Dictionary = {}
	var player_index := 0
	for device_id: int in devices:
		var role: Enums.Role = _player_roles.get(device_id, Enums.Role.ESCAPIST) as Enums.Role
		InputManager.assign_device(player_index, device_id)
		role_assignments[player_index] = role
		team_assignments[player_index] = Enums.Team.TEAM_1 if role == Enums.Role.ESCAPIST else Enums.Team.TEAM_2
		player_index += 1
	practice_ready.emit(team_assignments, role_assignments)


func _draw() -> void:
	var screen := get_viewport_rect().size
	var font := ThemeDB.fallback_font
	var cx := screen.x / 2.0

	draw_rect(Rect2(Vector2.ZERO, screen), Color.BLACK)

	var title := "PRACTICE MODE"
	var title_size := 34
	var title_width := font.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, title_size).x
	draw_string(font, Vector2(cx - title_width / 2.0, 72.0),
		title, HORIZONTAL_ALIGNMENT_LEFT, -1, title_size, Color.WHITE)

	var sub := "Join freely. Pick Escapist or Trapper. No bots, no hazards."
	var sub_width := font.get_string_size(sub, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x
	draw_string(font, Vector2(cx - sub_width / 2.0, 104.0),
		sub, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(0.65, 0.65, 0.65))

	var joined := _get_joined_devices()
	var panel := Rect2(Vector2(cx - 330.0, 145.0), Vector2(660.0, 330.0))
	draw_rect(panel, Color(0.09, 0.09, 0.09, 0.92))
	draw_rect(panel, Color(0.55, 0.55, 0.55, 0.75), false, 2.0)

	if joined.is_empty():
		var empty_text := "Press A to join Practice Mode"
		var empty_width := font.get_string_size(empty_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 22).x
		draw_string(font, Vector2(cx - empty_width / 2.0, panel.position.y + 150.0),
			empty_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color.YELLOW)
	else:
		for i in joined.size():
			var device_id: int = joined[i]
			var role: Enums.Role = _player_roles.get(device_id, Enums.Role.ESCAPIST) as Enums.Role
			var row_y := panel.position.y + 58.0 + float(i) * 42.0
			var player_label := "P%d" % (i + 1)
			var role_label := "Escapist" if role == Enums.Role.ESCAPIST else "Trapper"
			var role_color := Enums.role_color(role)
			draw_string(font, Vector2(panel.position.x + 52.0, row_y),
				player_label, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color.WHITE)
			draw_string(font, Vector2(panel.position.x + 150.0, row_y),
				"< %s >" % role_label, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, role_color)
			draw_string(font, Vector2(panel.position.x + 390.0, row_y),
				"LEFT/RIGHT change | B leave", HORIZONTAL_ALIGNMENT_LEFT, -1, 13,
				Color(0.55, 0.55, 0.55))

	var unjoined_y := panel.position.y + panel.size.y + 36.0
	for device_id: int in Input.get_connected_joypads():
		if _player_joined.get(device_id, false):
			continue
		var text := "Controller %d - Press A to join" % device_id
		var text_width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x
		draw_string(font, Vector2(cx - text_width / 2.0, unjoined_y),
			text, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(0.5, 0.5, 0.5))
		unjoined_y += 24.0

	var hint := "START continue | B back"
	if joined.is_empty():
		hint = "A join | B back"
	var hint_width := font.get_string_size(hint, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x
	draw_string(font, Vector2(cx - hint_width / 2.0, screen.y - 34.0),
		hint, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color.YELLOW)
