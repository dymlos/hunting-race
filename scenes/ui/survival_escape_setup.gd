class_name SurvivalEscapeSetup
extends Control

signal back_requested
signal settings_requested
signal survival_ready(role_assignments: Dictionary)

var input_blocked: bool = false
var auto_fill_bots: bool = false

var _player_joined: Dictionary = {}
var _player_roles: Dictionary = {}
var _role_cursor: Dictionary = {}
var _nav_axis_locks: Dictionary = {}
var _assigned_roles: Dictionary = {}
var _showing_placeholder: bool = false
var _message_timer: float = 0.0
var _message_text: String = ""

const MAX_PLAYERS: int = 4
const BOT_START_INDEX: int = 100
const NAV_AXIS_THRESHOLD: float = 0.84
const NAV_AXIS_RELEASE: float = 0.42


func setup() -> void:
	_player_joined.clear()
	_player_roles.clear()
	_role_cursor.clear()
	_nav_axis_locks.clear()
	_assigned_roles.clear()
	_showing_placeholder = false
	_message_timer = 0.0
	_message_text = ""
	show()
	queue_redraw()


func reopen_placeholder() -> void:
	_showing_placeholder = true
	_message_timer = 0.0
	_message_text = ""
	show()
	queue_redraw()


func _process(delta: float) -> void:
	if not visible or input_blocked:
		queue_redraw()
		return

	_message_timer = maxf(0.0, _message_timer - delta)
	if _showing_placeholder:
		_process_placeholder_input()
		queue_redraw()
		return

	_prune_disconnected_devices()
	var connected_pads := Input.get_connected_joypads()
	for device_id: int in connected_pads:
		if not _role_cursor.has(device_id):
			_role_cursor[device_id] = _pick_default_role()
		if not _nav_axis_locks.has(device_id):
			_nav_axis_locks[device_id] = absf(Input.get_joy_axis(device_id, JOY_AXIS_LEFT_X)) > NAV_AXIS_RELEASE

		if InputManager.is_menu_back_just_pressed(device_id):
			back_requested.emit()
			return

		if InputManager.is_button_just_pressed_on_device(device_id, JOY_BUTTON_Y):
			settings_requested.emit()
			return

		if InputManager.is_menu_confirm_just_pressed(device_id):
			if _get_joined_devices().is_empty():
				_show_message("Hace falta al menos 1 jugador para revisar el modo.")
			else:
				_enter_placeholder()
			return

		var move_x := Input.get_joy_axis(device_id, JOY_AXIS_LEFT_X)
		if _nav_axis_locks.get(device_id, false):
			if absf(move_x) <= NAV_AXIS_RELEASE:
				_nav_axis_locks[device_id] = false
		else:
			if move_x < -NAV_AXIS_THRESHOLD:
				_set_role_cursor(device_id, Enums.Role.ESCAPIST)
				_nav_axis_locks[device_id] = true
			elif move_x > NAV_AXIS_THRESHOLD:
				_set_role_cursor(device_id, Enums.Role.TRAPPER)
				_nav_axis_locks[device_id] = true

		if _player_joined.get(device_id, false):
			if InputManager.is_button_just_pressed_on_device(device_id, JOY_BUTTON_B):
				_player_joined.erase(device_id)
				_player_roles.erase(device_id)
				continue
			if InputManager.is_button_just_pressed_on_device(device_id, JOY_BUTTON_A):
				_player_roles[device_id] = _role_cursor[device_id]
		elif InputManager.is_button_just_pressed_on_device(device_id, JOY_BUTTON_A):
			if _get_joined_devices().size() >= MAX_PLAYERS:
				_show_message("Survival Escape permite hasta %d usuarios por ahora." % MAX_PLAYERS)
				continue
			_player_joined[device_id] = true
			_player_roles[device_id] = _role_cursor[device_id]

	queue_redraw()


func _process_placeholder_input() -> void:
	for device_id: int in Input.get_connected_joypads():
		if InputManager.is_menu_back_just_pressed(device_id):
			_showing_placeholder = false
			_assigned_roles.clear()
			return
		if InputManager.is_menu_confirm_just_pressed(device_id):
			if _get_assigned_role_count(Enums.Role.ESCAPIST) <= 0:
				_show_message("Hace falta al menos 1 escapista para probar el mapa.")
				return
			survival_ready.emit(_assigned_roles.duplicate())
			return


func _prune_disconnected_devices() -> void:
	var connected_pads := Input.get_connected_joypads()
	var stale_devices: Array[int] = []
	for device_id: int in _player_joined:
		if device_id not in connected_pads:
			stale_devices.append(device_id)
	for device_id: int in stale_devices:
		_player_joined.erase(device_id)
		_player_roles.erase(device_id)
		_role_cursor.erase(device_id)
		_nav_axis_locks.erase(device_id)


func _set_role_cursor(device_id: int, role: Enums.Role) -> void:
	_role_cursor[device_id] = role
	if _player_joined.get(device_id, false):
		_player_roles[device_id] = role


func _pick_default_role() -> Enums.Role:
	var escapists := _get_role_devices(Enums.Role.ESCAPIST).size()
	var trappers := _get_role_devices(Enums.Role.TRAPPER).size()
	return Enums.Role.ESCAPIST if escapists <= trappers else Enums.Role.TRAPPER


func _get_joined_devices() -> Array[int]:
	var devices: Array[int] = []
	for device_id: int in _player_joined:
		if _player_joined.get(device_id, false):
			devices.append(device_id)
	devices.sort()
	return devices


func _get_role_devices(role: Enums.Role) -> Array[int]:
	var devices: Array[int] = []
	for device_id: int in _player_roles:
		if _player_joined.get(device_id, false) and (_player_roles[device_id] as Enums.Role) == role:
			devices.append(device_id)
	devices.sort()
	return devices


func _get_survival_target_size() -> int:
	var configured: int = GameManager.settings_overrides.get(&"team_size", MAX_PLAYERS) as int
	var escapists := _get_role_devices(Enums.Role.ESCAPIST).size()
	var trappers := _get_role_devices(Enums.Role.TRAPPER).size()
	var target := maxi(configured, escapists)
	target = maxi(target, trappers)
	target = maxi(target, 1)
	return clampi(target, 1, MAX_PLAYERS)


func _get_bot_counts_for_display() -> Dictionary:
	var counts := {
		Enums.Role.ESCAPIST: 0,
		Enums.Role.TRAPPER: 0,
	}
	if not auto_fill_bots:
		return counts
	var target_size := _get_survival_target_size()
	var escapists := _get_role_devices(Enums.Role.ESCAPIST).size()
	var trappers := _get_role_devices(Enums.Role.TRAPPER).size()
	counts[Enums.Role.ESCAPIST] = maxi(0, target_size - escapists)
	counts[Enums.Role.TRAPPER] = maxi(0, target_size - trappers)
	return counts


func _get_total_role_count(role: Enums.Role) -> int:
	var bots := _get_bot_counts_for_display()
	return _get_role_devices(role).size() + (bots.get(role, 0) as int)


func _get_player_number_for_device(device_id: int) -> int:
	return _get_joined_devices().find(device_id) + 1


func _enter_placeholder() -> void:
	_assigned_roles.clear()
	var devices := _get_joined_devices()
	for player_index in range(8):
		InputManager.unassign_device(player_index)
	for i in devices.size():
		var device_id: int = devices[i]
		InputManager.assign_device(i, device_id)
		_assigned_roles[i] = _player_roles.get(device_id, Enums.Role.ESCAPIST)
	_add_survival_bots_to_assignments()
	_showing_placeholder = true


func _add_survival_bots_to_assignments() -> void:
	if not auto_fill_bots:
		return
	var bot_counts := _get_bot_counts_for_display()
	var bot_id := BOT_START_INDEX
	var escapist_bots: int = bot_counts.get(Enums.Role.ESCAPIST, 0) as int
	for _i in range(escapist_bots):
		_assigned_roles[bot_id] = Enums.Role.ESCAPIST
		bot_id += 1
	var trapper_bots: int = bot_counts.get(Enums.Role.TRAPPER, 0) as int
	for _i in range(trapper_bots):
		_assigned_roles[bot_id] = Enums.Role.TRAPPER
		bot_id += 1


func _get_assigned_role_count(role: Enums.Role) -> int:
	var count := 0
	for player_index: int in _assigned_roles:
		if (_assigned_roles[player_index] as Enums.Role) == role:
			count += 1
	return count


func _show_message(text: String) -> void:
	_message_text = text
	_message_timer = 2.4


func _draw() -> void:
	var screen := get_viewport_rect().size
	var font := ThemeDB.fallback_font
	if _showing_placeholder:
		_draw_placeholder(screen, font)
	else:
		_draw_role_setup(screen, font)


func _draw_role_setup(screen: Vector2, font: Font) -> void:
	var cx := screen.x / 2.0
	draw_rect(Rect2(Vector2.ZERO, screen), Color(0.015, 0.018, 0.018, 1.0))
	draw_rect(Rect2(Vector2.ZERO, Vector2(screen.x, screen.y)), Color(0.04, 0.10, 0.07, 0.22))

	_draw_centered_text_in_rect(font, "SURVIVAL ESCAPE",
		Rect2(cx - 260.0, 28.0, 520.0, 46.0), 38, Color.WHITE)
	_draw_centered_text_in_rect(font, "Elige un rol fijo para toda la partida.",
		Rect2(cx - 360.0, 78.0, 720.0, 22.0), 16, Color(0.66, 0.70, 0.68))
	_draw_centered_text_in_rect(font, "Usa ajustes para activar bots y definir formatos 2v2, 3v3 o 4v4.",
		Rect2(cx - 420.0, 102.0, 840.0, 20.0), 13, Color(0.48, 0.52, 0.50))

	var joined := _get_joined_devices()
	var escapists := _get_role_devices(Enums.Role.ESCAPIST)
	var trappers := _get_role_devices(Enums.Role.TRAPPER)
	var bot_counts := _get_bot_counts_for_display()
	var escapist_bots: int = bot_counts.get(Enums.Role.ESCAPIST, 0) as int
	var trapper_bots: int = bot_counts.get(Enums.Role.TRAPPER, 0) as int
	var target_size := _get_survival_target_size()
	var summary_rect := Rect2(cx - 430.0, 138.0, 860.0, 62.0)
	_draw_panel(summary_rect, Color(0.04, 0.045, 0.045, 0.94), Color(0.28, 0.38, 0.32, 0.86), 2.0)
	draw_rect(Rect2(summary_rect.position, Vector2(summary_rect.size.x, 5.0)), Color(0.22, 0.85, 0.48, 0.9))
	var summary_col_w := summary_rect.size.x / 4.0
	var mode_text := "Libre"
	if auto_fill_bots:
		mode_text = "%dv%d" % [target_size, target_size]
	_draw_summary_block(font, Rect2(summary_rect.position.x, summary_rect.position.y, summary_col_w, summary_rect.size.y),
		"Usuarios", "%d/%d" % [joined.size(), MAX_PLAYERS], Color(0.90, 0.90, 0.90))
	_draw_summary_block(font, Rect2(summary_rect.position.x + summary_col_w, summary_rect.position.y, summary_col_w, summary_rect.size.y),
		"Modo", mode_text, Color(0.98, 0.86, 0.32))
	_draw_summary_block(font, Rect2(summary_rect.position.x + summary_col_w * 2.0, summary_rect.position.y, summary_col_w, summary_rect.size.y),
		"Escapistas", "%d +%d" % [escapists.size(), escapist_bots], Enums.role_color(Enums.Role.ESCAPIST))
	_draw_summary_block(font, Rect2(summary_rect.position.x + summary_col_w * 3.0, summary_rect.position.y, summary_col_w, summary_rect.size.y),
		"Cazadores", "%d +%d" % [trappers.size(), trapper_bots], Enums.role_color(Enums.Role.TRAPPER))

	var side_margin := 70.0
	var gap := 36.0
	var panel_top := 224.0
	var footer_reserved := 154.0
	var panel_h := maxf(300.0, screen.y - panel_top - footer_reserved)
	var panel_w := (screen.x - side_margin * 2.0 - gap) / 2.0
	var left_rect := Rect2(side_margin, panel_top, panel_w, panel_h)
	var right_rect := Rect2(side_margin + panel_w + gap, panel_top, panel_w, panel_h)
	_draw_role_panel(font, left_rect, Enums.Role.ESCAPIST, escapists,
		escapist_bots, "Deben llegar juntos a la salida.", Color(0.18, 0.95, 0.54))
	_draw_role_panel(font, right_rect, Enums.Role.TRAPPER, trappers,
		trapper_bots, "Presionan con cuerpo y control del mapa.", Color(0.70, 0.34, 1.0))

	_draw_unjoined_controls(font, screen, joined)
	_draw_footer(font, screen, joined)
	_draw_message(font, screen)


func _draw_placeholder(screen: Vector2, font: Font) -> void:
	var cx := screen.x / 2.0
	draw_rect(Rect2(Vector2.ZERO, screen), Color(0.012, 0.014, 0.014, 1.0))
	draw_rect(Rect2(Vector2.ZERO, screen), Color(0.06, 0.12, 0.08, 0.20))

	_draw_centered_text_in_rect(font, "SURVIVAL ESCAPE",
		Rect2(cx - 260.0, 48.0, 520.0, 48.0), 38, Color.WHITE)
	_draw_centered_text_in_rect(font, "Vista previa del modo",
		Rect2(cx - 250.0, 98.0, 500.0, 24.0), 16, Color(0.58, 0.72, 0.62))

	var panel_rect := Rect2(cx - 480.0, 160.0, 960.0, 470.0)
	_draw_panel(panel_rect, Color(0.055, 0.058, 0.06, 0.96), Color(0.24, 0.82, 0.48, 0.9), 2.0)
	draw_rect(Rect2(panel_rect.position, Vector2(panel_rect.size.x, 6.0)), Color(0.24, 0.82, 0.48, 1.0))
	_draw_centered_text_in_rect(font, "ROLES FIJOS CONFIRMADOS",
		Rect2(panel_rect.position.x, panel_rect.position.y + 18.0, panel_rect.size.x, 30.0), 24, Color.WHITE)
	_draw_centered_text_in_rect(font, "Revisa roles, bots y avanza al mapa survival.",
		Rect2(panel_rect.position.x, panel_rect.position.y + 52.0, panel_rect.size.x, 24.0), 14, Color(0.68, 0.72, 0.70))

	var left_rect := Rect2(panel_rect.position.x + 34.0, panel_rect.position.y + 104.0, 420.0, 270.0)
	var right_rect := Rect2(panel_rect.end.x - 454.0, panel_rect.position.y + 104.0, 420.0, 270.0)
	_draw_assigned_role_list(font, left_rect, Enums.Role.ESCAPIST)
	_draw_assigned_role_list(font, right_rect, Enums.Role.TRAPPER)

	_draw_centered_text_in_rect(font, "Start carga el mapa de prueba. Select vuelve a editar roles.",
		Rect2(panel_rect.position.x, panel_rect.end.y - 64.0, panel_rect.size.x, 22.0), 14, Color(0.58, 0.62, 0.60))
	_draw_centered_text_in_rect(font, "Start cargar mapa | Select volver a roles",
		Rect2(cx - 320.0, screen.y - 64.0, 640.0, 32.0), 18, Color.YELLOW)
	_draw_message(font, screen)


func _draw_role_panel(font: Font, rect: Rect2, role: Enums.Role, devices: Array[int],
		bot_count: int, description: String, accent: Color) -> void:
	_draw_panel(rect, Color(accent, 0.09), Color(accent, 0.72), 2.0)
	draw_rect(Rect2(rect.position, Vector2(rect.size.x, 6.0)), accent)
	_draw_centered_text_in_rect(font, Enums.role_name(role).to_upper(),
		Rect2(rect.position.x, rect.position.y + 16.0, rect.size.x, 34.0), 27, accent)
	_draw_centered_text_in_rect(font, description,
		Rect2(rect.position.x + 20.0, rect.position.y + 54.0, rect.size.x - 40.0, 22.0), 13, Color(0.72, 0.74, 0.73))
	draw_line(Vector2(rect.position.x + 22.0, rect.position.y + 88.0),
		Vector2(rect.end.x - 22.0, rect.position.y + 88.0), Color(accent, 0.36), 1.0)

	if devices.is_empty() and bot_count <= 0:
		_draw_centered_text_in_rect(font, "Sin usuarios en este rol",
			Rect2(rect.position.x, rect.position.y + 136.0, rect.size.x, 24.0), 16, Color(0.48, 0.50, 0.50))
		_draw_centered_text_in_rect(font, "Palanca izq./der. y A para elegir",
			Rect2(rect.position.x, rect.position.y + 162.0, rect.size.x, 20.0), 12, Color(0.40, 0.42, 0.42))
		return

	var slot_y := rect.position.y + 112.0
	var row_index := 0
	for i in devices.size():
		var device_id: int = devices[i]
		var card_rect := Rect2(rect.position.x + 26.0, slot_y + float(row_index) * 58.0, rect.size.x - 52.0, 46.0)
		_draw_panel(card_rect, Color(0.025, 0.028, 0.03, 0.92), Color(accent, 0.45), 1.5)
		draw_rect(Rect2(card_rect.position, Vector2(6.0, card_rect.size.y)), accent)
		var player_number := _get_player_number_for_device(device_id)
		draw_string(font, Vector2(card_rect.position.x + 18.0, card_rect.position.y + 30.0),
			"USUARIO %d" % player_number, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, accent)
		draw_string(font, Vector2(card_rect.position.x + 144.0, card_rect.position.y + 30.0),
			"Control %d" % device_id, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color(0.88, 0.88, 0.90))
		draw_string(font, Vector2(card_rect.position.x + 144.0, card_rect.position.y + 42.0),
			"Rol fijo", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.58, 0.62, 0.60))
		row_index += 1

	for i in range(bot_count):
		var card_rect := Rect2(rect.position.x + 26.0, slot_y + float(row_index) * 58.0, rect.size.x - 52.0, 46.0)
		_draw_panel(card_rect, Color(0.055, 0.050, 0.025, 0.92), Color(0.98, 0.86, 0.32, 0.46), 1.5)
		draw_rect(Rect2(card_rect.position, Vector2(6.0, card_rect.size.y)), Color(0.98, 0.86, 0.32))
		draw_string(font, Vector2(card_rect.position.x + 18.0, card_rect.position.y + 30.0),
			"BOT %d" % (i + 1), HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color(0.98, 0.86, 0.32))
		draw_string(font, Vector2(card_rect.position.x + 144.0, card_rect.position.y + 30.0),
			"Autorrelleno", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color(0.88, 0.88, 0.90))
		draw_string(font, Vector2(card_rect.position.x + 144.0, card_rect.position.y + 42.0),
			"IA survival", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.62, 0.62, 0.50))
		row_index += 1


func _draw_unjoined_controls(font: Font, screen: Vector2, joined: Array[int]) -> void:
	var cx := screen.x / 2.0
	var unjoined: Array[int] = []
	for device_id: int in Input.get_connected_joypads():
		if device_id not in joined:
			unjoined.append(device_id)
	unjoined.sort()
	if unjoined.is_empty():
		_draw_centered_text_in_rect(font, "TODOS LOS CONTROLES DISPONIBLES ESTAN ASIGNADOS",
			Rect2(cx - 300.0, screen.y - 132.0, 600.0, 22.0), 13, Color(0.52, 0.58, 0.54))
		return

	var box_w := minf(720.0, screen.x - 120.0)
	var box_h := 42.0 + float(unjoined.size()) * 22.0
	var box_rect := Rect2(cx - box_w * 0.5, screen.y - 156.0 - box_h, box_w, box_h)
	_draw_panel(box_rect, Color(0.04, 0.04, 0.045, 0.94), Color(0.26, 0.32, 0.28, 0.9), 1.5)
	draw_rect(Rect2(box_rect.position, Vector2(box_rect.size.x, 4.0)), Color(0.24, 0.82, 0.48, 0.92))
	_draw_centered_text_in_rect(font, "CONTROLES DISPONIBLES",
		Rect2(box_rect.position.x, box_rect.position.y + 6.0, box_rect.size.x, 20.0), 13, Color(0.74, 0.78, 0.76))
	for i in unjoined.size():
		var device_id: int = unjoined[i]
		var role: Enums.Role = _role_cursor.get(device_id, _pick_default_role()) as Enums.Role
		var text := "Control %d  -  %s  -  A se une" % [device_id, Enums.role_name(role)]
		_draw_centered_text_in_rect(font, text,
			Rect2(box_rect.position.x, box_rect.position.y + 30.0 + float(i) * 22.0, box_rect.size.x, 20.0),
			12, Enums.role_color(role))


func _draw_footer(font: Font, screen: Vector2, joined: Array[int]) -> void:
	var cx := screen.x / 2.0
	var footer_rect := Rect2(cx - 390.0, screen.y - 76.0, 780.0, 44.0)
	_draw_panel(footer_rect, Color(0.025, 0.026, 0.028, 0.96), Color(0.24, 0.30, 0.26, 0.9), 1.5)
	var main_text := "Start continuar"
	var main_color := Color(0.98, 0.92, 0.48)
	if joined.is_empty():
		main_text = "A elegir rol y unirse"
		main_color = Color(0.72, 0.72, 0.54)
	_draw_centered_text_in_rect(font, main_text,
		Rect2(footer_rect.position.x, footer_rect.position.y + 2.0, footer_rect.size.x, 18.0), 14, main_color)
	_draw_centered_text_in_rect(font, "Palanca izq./der. rol | A elegir | B deseleccionar | Y ajustes | Select volver",
		Rect2(footer_rect.position.x, footer_rect.position.y + 20.0, footer_rect.size.x, 18.0), 12, Color(0.54, 0.56, 0.56))


func _draw_assigned_role_list(font: Font, rect: Rect2, role: Enums.Role) -> void:
	var accent := Enums.role_color(role)
	_draw_panel(rect, Color(accent, 0.09), Color(accent, 0.64), 1.5)
	draw_rect(Rect2(rect.position, Vector2(rect.size.x, 5.0)), accent)
	_draw_centered_text_in_rect(font, Enums.role_name(role).to_upper(),
		Rect2(rect.position.x, rect.position.y + 14.0, rect.size.x, 28.0), 22, accent)
	var players: Array[int] = []
	for player_index: int in _assigned_roles:
		if (_assigned_roles[player_index] as Enums.Role) == role:
			players.append(player_index)
	players.sort()
	if players.is_empty():
		_draw_centered_text_in_rect(font, "Sin participantes",
			Rect2(rect.position.x, rect.position.y + 122.0, rect.size.x, 22.0), 15, Color(0.48, 0.50, 0.50))
		return
	for i in players.size():
		var player_index: int = players[i]
		var row := Rect2(rect.position.x + 28.0, rect.position.y + 72.0 + float(i) * 42.0, rect.size.x - 56.0, 34.0)
		_draw_panel(row, Color(0.02, 0.022, 0.024, 0.88), Color(accent, 0.34), 1.0)
		_draw_centered_text_in_rect(font, _get_participant_label(player_index), row, 14, Color(0.9, 0.9, 0.92))


func _get_participant_label(player_index: int) -> String:
	if player_index >= BOT_START_INDEX:
		return "BOT %d" % (player_index - BOT_START_INDEX + 1)
	return "USUARIO %d" % (player_index + 1)


func _draw_summary_block(font: Font, rect: Rect2, label: String, value: String, color: Color) -> void:
	_draw_centered_text_in_rect(font, label,
		Rect2(rect.position.x, rect.position.y + 10.0, rect.size.x, 18.0), 12, Color(0.62, 0.66, 0.64))
	_draw_centered_text_in_rect(font, value,
		Rect2(rect.position.x, rect.position.y + 27.0, rect.size.x, 28.0), 22, color)


func _draw_message(font: Font, screen: Vector2) -> void:
	if _message_timer <= 0.0 or _message_text.is_empty():
		return
	var cx := screen.x / 2.0
	var alpha := clampf(_message_timer / 0.3, 0.0, 1.0)
	var rect := Rect2(cx - 330.0, 126.0, 660.0, 38.0)
	_draw_panel(rect, Color(0.12, 0.05, 0.04, 0.94 * alpha), Color(1.0, 0.25, 0.16, 0.9 * alpha), 1.5)
	_draw_centered_text_in_rect(font, _message_text, rect, 14, Color(1.0, 0.82, 0.72, alpha))


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
