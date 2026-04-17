class_name TeamSetup
extends Control

## Team assignment screen. Players press A to join or continue, stick to pick teams, B to go back.
## Roles (Escapist/Trapper) are assigned per-round by GameManager, not here.

signal teams_ready(team_assignments: Dictionary)
signal settings_requested
signal back_requested

var _player_joined: Dictionary = {}    # {device_id: bool}
var _player_teams: Dictionary = {}     # {device_id: Enums.Team}
var _nav_cooldowns: Dictionary = {}    # {device_id: float}
var _awaiting_start_confirmation: bool = false
var input_blocked: bool = false
var auto_fill_bots: bool = false

const NAV_COOLDOWN: float = 0.2
const TITLE_FONT_SIZE: int = 42
const SUMMARY_LABEL_FONT_SIZE: int = 13
const SUMMARY_VALUE_FONT_SIZE: int = 22
const MATCH_LABEL_FONT_SIZE: int = 12
const MATCH_VALUE_FONT_SIZE: int = 18
const TEAM_HEADER_FONT_SIZE: int = 28
const TEAM_SUBHEADER_FONT_SIZE: int = 14
const SLOT_TITLE_FONT_SIZE: int = 15
const SLOT_DETAIL_FONT_SIZE: int = 13
const FOOTER_FONT_SIZE: int = 14
const FOOTER_SMALL_FONT_SIZE: int = 12


func setup() -> void:
	_player_joined.clear()
	_player_teams.clear()
	_nav_cooldowns.clear()
	_awaiting_start_confirmation = false
	show()
	queue_redraw()


func _process(delta: float) -> void:
	if not visible or input_blocked:
		queue_redraw()
		return

	# Prune disconnected devices
	var connected_pads := Input.get_connected_joypads()
	var stale_devices: Array[int] = []
	for device_id: int in _player_joined:
		if _player_joined[device_id] and device_id not in connected_pads:
			stale_devices.append(device_id)
	for device_id: int in stale_devices:
		_player_joined.erase(device_id)
		_player_teams.erase(device_id)
		_nav_cooldowns.erase(device_id)
		_awaiting_start_confirmation = false

	# Tick nav cooldowns
	for device_id: int in _nav_cooldowns:
		_nav_cooldowns[device_id] = maxf(0.0, _nav_cooldowns[device_id] - delta)

	var pads := connected_pads
	var joined_this_frame := false
	for device_id: int in pads:
		if _player_joined.get(device_id, false):
			if _awaiting_start_confirmation:
				if InputManager.is_button_just_pressed_on_device(device_id, JOY_BUTTON_A):
					_advance()
					return
				elif InputManager.is_button_just_pressed_on_device(device_id, JOY_BUTTON_B):
					_awaiting_start_confirmation = false
					return
				continue
			if InputManager.is_button_just_pressed_on_device(device_id, JOY_BUTTON_B):
				_awaiting_start_confirmation = false
				back_requested.emit()
				return
			elif _nav_cooldowns.get(device_id, 0.0) <= 0.0:
				var x := Input.get_joy_axis(device_id, JOY_AXIS_LEFT_X)
				if x < -0.5:
					_set_player_team_if_available(device_id, Enums.Team.TEAM_1)
					_nav_cooldowns[device_id] = NAV_COOLDOWN
				elif x > 0.5:
					_set_player_team_if_available(device_id, Enums.Team.TEAM_2)
					_nav_cooldowns[device_id] = NAV_COOLDOWN
		else:
			if InputManager.is_button_just_pressed_on_device(device_id, JOY_BUTTON_A):
				_player_joined[device_id] = true
				_player_teams[device_id] = _pick_join_team()
				_nav_cooldowns[device_id] = NAV_COOLDOWN
				_awaiting_start_confirmation = false
				joined_this_frame = true
			elif InputManager.is_button_just_pressed_on_device(device_id, JOY_BUTTON_B):
				_awaiting_start_confirmation = false
				back_requested.emit()
				return

	# SELECT to open settings
	for device_id: int in pads:
		if InputManager.is_button_just_pressed_on_device(device_id, JOY_BUTTON_BACK):
			_awaiting_start_confirmation = false
			settings_requested.emit()
			return

	if _has_valid_teams() and not joined_this_frame:
		for device_id: int in pads:
			if _player_joined.get(device_id, false):
				if InputManager.is_button_just_pressed_on_device(device_id, JOY_BUTTON_A):
					_awaiting_start_confirmation = true
					queue_redraw()
					return

	queue_redraw()


func _has_valid_teams() -> bool:
	return not _get_joined_devices().is_empty()


func _get_joined_devices() -> Array[int]:
	var devices: Array[int] = []
	for device_id: int in _player_joined:
		if _player_joined.get(device_id, false):
			devices.append(device_id)
	devices.sort()
	return devices


func _get_team_size_limit() -> int:
	return GameManager.settings_overrides.get(&"team_size", 4) as int


func _get_team_counts() -> Dictionary:
	var counts := {
		Enums.Team.TEAM_1: 0,
		Enums.Team.TEAM_2: 0,
	}
	for device_id: int in _player_teams:
		if not _player_joined.get(device_id, false):
			continue
		var team: Enums.Team = _player_teams[device_id] as Enums.Team
		counts[team] = (counts.get(team, 0) as int) + 1
	return counts


func _get_bot_counts_for_display() -> Dictionary:
	var counts := _get_team_counts()
	var t1 := counts.get(Enums.Team.TEAM_1, 0) as int
	var t2 := counts.get(Enums.Team.TEAM_2, 0) as int
	var bot_counts := {
		Enums.Team.TEAM_1: 0,
		Enums.Team.TEAM_2: 0,
	}
	if auto_fill_bots:
		var target_count := maxi(t1, t2)
		bot_counts[Enums.Team.TEAM_1] = maxi(0, target_count - t1)
		bot_counts[Enums.Team.TEAM_2] = maxi(0, target_count - t2)
	return bot_counts


func _get_human_player_count() -> int:
	return _get_joined_devices().size()


func _team_can_accept(team: Enums.Team) -> bool:
	var counts := _get_team_counts()
	var limit := _get_team_size_limit()
	return (counts.get(team, 0) as int) < limit


func _pick_join_team() -> Enums.Team:
	var counts := _get_team_counts()
	var limit := _get_team_size_limit()
	var t1 := counts.get(Enums.Team.TEAM_1, 0) as int
	var t2 := counts.get(Enums.Team.TEAM_2, 0) as int
	if t1 < limit and (t1 <= t2 or t2 >= limit):
		return Enums.Team.TEAM_1
	if t2 < limit:
		return Enums.Team.TEAM_2
	return Enums.Team.TEAM_1


func _set_player_team_if_available(device_id: int, team: Enums.Team) -> void:
	var current_team: Enums.Team = _player_teams.get(device_id, Enums.Team.TEAM_1) as Enums.Team
	if current_team == team:
		return
	if not _team_can_accept(team):
		return
	_player_teams[device_id] = team
	_awaiting_start_confirmation = false


func _advance() -> void:
	_awaiting_start_confirmation = false
	var t_assignments: Dictionary = {}
	var pi := 0

	var devices: Array = []
	for device_id: int in _player_teams:
		if _player_joined.get(device_id, false):
			devices.append(device_id)
	devices.sort()

	for device_id: int in devices:
		InputManager.assign_device(pi, device_id)
		t_assignments[pi] = _player_teams[device_id]
		pi += 1

	if auto_fill_bots:
		var t1 := 0
		var t2 := 0
		for p: int in t_assignments:
			if t_assignments[p] == Enums.Team.TEAM_1:
				t1 += 1
			else:
				t2 += 1

		var target_count := maxi(t1, t2)
		var bot_id := 100
		while t1 < target_count:
			t_assignments[bot_id] = Enums.Team.TEAM_1
			bot_id += 1
			t1 += 1
		while t2 < target_count:
			t_assignments[bot_id] = Enums.Team.TEAM_2
			bot_id += 1
			t2 += 1

	teams_ready.emit(t_assignments)


func _draw() -> void:
	var screen := get_viewport_rect().size
	var cx := screen.x / 2.0
	var font := ThemeDB.fallback_font

	draw_rect(Rect2(Vector2.ZERO, screen), Color(0.02, 0.02, 0.025, 1.0))
	draw_rect(Rect2(Vector2.ZERO, Vector2(cx, screen.y)), Color(0.05, 0.09, 0.14, 0.12))
	draw_rect(Rect2(Vector2(cx, 0.0), Vector2(cx, screen.y)), Color(0.14, 0.05, 0.05, 0.12))

	var title_color := Color(1.0, 1.0, 1.0)
	_draw_centered_text_in_rect(font, "TEAM SETUP", Rect2(cx - 170.0, 12.0, 340.0, 58.0), TITLE_FONT_SIZE, title_color)

	var team_limit := _get_team_size_limit()
	if team_limit < 1:
		team_limit = 1
	var counts := _get_team_counts()
	var bot_counts := _get_bot_counts_for_display()
	var human_count := _get_human_player_count()
	var total_capacity := team_limit * 2
	var total_bots := (bot_counts.get(Enums.Team.TEAM_1, 0) as int) \
		+ (bot_counts.get(Enums.Team.TEAM_2, 0) as int)
	var format_text := "%s %d | %s %d" % [
		"%s:" % Enums.team_name(Enums.Team.TEAM_1),
		(counts.get(Enums.Team.TEAM_1, 0) as int) + (bot_counts.get(Enums.Team.TEAM_1, 0) as int),
		"%s:" % Enums.team_name(Enums.Team.TEAM_2),
		(counts.get(Enums.Team.TEAM_2, 0) as int) + (bot_counts.get(Enums.Team.TEAM_2, 0) as int),
	]
	var bot_state := "Off"
	if auto_fill_bots:
		bot_state = "On (+%d)" % total_bots
	var summary_rect := Rect2(cx - 330.0, 90.0, 660.0, 78.0)
	_draw_panel(summary_rect, Color(0.05, 0.05, 0.06, 0.94), Color(0.32, 0.32, 0.34, 0.92), 2.0)
	draw_rect(Rect2(summary_rect.position, Vector2(summary_rect.size.x, 5.0)), Color(0.12, 0.12, 0.14, 1.0))
	var summary_col_w := summary_rect.size.x / 3.0
	var players_text := "%d/%d" % [human_count, total_capacity]
	var team_size_text := "%d" % team_limit
	var bots_text := bot_state
	_draw_summary_block(font, Rect2(summary_rect.position.x, summary_rect.position.y, summary_col_w, summary_rect.size.y),
		"Players", players_text, Color(0.96, 0.96, 0.96), Color(0.9, 0.9, 0.9))
	_draw_summary_block(font, Rect2(summary_rect.position.x + summary_col_w, summary_rect.position.y, summary_col_w, summary_rect.size.y),
		"Team Size", team_size_text, Color(0.82, 0.95, 0.82), Color(0.82, 0.95, 0.82))
	_draw_summary_block(font, Rect2(summary_rect.position.x + summary_col_w * 2.0, summary_rect.position.y, summary_col_w, summary_rect.size.y),
		"Bots", bots_text, Color(0.98, 0.86, 0.32), Color(0.98, 0.86, 0.32))
	draw_line(Vector2(summary_rect.position.x + summary_col_w, summary_rect.position.y + 11.0),
		Vector2(summary_rect.position.x + summary_col_w, summary_rect.end.y - 11.0),
		Color(0.22, 0.22, 0.24, 0.88), 1.0)
	draw_line(Vector2(summary_rect.position.x + summary_col_w * 2.0, summary_rect.position.y + 11.0),
		Vector2(summary_rect.position.x + summary_col_w * 2.0, summary_rect.end.y - 11.0),
		Color(0.22, 0.22, 0.24, 0.88), 1.0)

	var match_rect := Rect2(cx - 240.0, 178.0, 480.0, 52.0)
	_draw_panel(match_rect, Color(0.03, 0.04, 0.03, 0.88), Color(0.20, 0.34, 0.20, 0.82), 1.5)
	draw_rect(Rect2(match_rect.position, Vector2(match_rect.size.x, 4.0)), Color(0.35, 0.58, 0.35, 1.0))
	_draw_centered_text_in_rect(font, "CURRENT MATCH", Rect2(match_rect.position.x, match_rect.position.y + 9.0, match_rect.size.x, 16.0), MATCH_LABEL_FONT_SIZE, Color(0.72, 0.8, 0.72))
	_draw_centered_text_in_rect(font, format_text, Rect2(match_rect.position.x, match_rect.position.y + 25.0, match_rect.size.x, 22.0), MATCH_VALUE_FONT_SIZE, Color(0.68, 0.92, 0.68))

	var top_y := 252.0
	var side_margin := 48.0
	var panel_gap := 34.0
	var panel_w := (screen.x - side_margin * 2.0 - panel_gap) * 0.5
	var panel_h := screen.y - top_y - 124.0
	var left_rect := Rect2(side_margin, top_y, panel_w, panel_h)
	var right_rect := Rect2(side_margin + panel_w + panel_gap, top_y, panel_w, panel_h)

	var t1c := Enums.team_color(Enums.Team.TEAM_1)
	var t2c := Enums.team_color(Enums.Team.TEAM_2)

	# Player slots
	var t1_devices: Array[int] = []
	var t2_devices: Array[int] = []
	for device_id: int in _player_teams:
		if _player_joined.get(device_id, false):
			if _player_teams[device_id] == Enums.Team.TEAM_1:
				t1_devices.append(device_id)
			else:
				t2_devices.append(device_id)
	t1_devices.sort()
	t2_devices.sort()
	_draw_team_panel(font, left_rect, Enums.Team.TEAM_1, t1_devices, team_limit, t1c)
	_draw_team_panel(font, right_rect, Enums.Team.TEAM_2, t2_devices, team_limit, t2c)

	var unjoined_devices: Array[int] = []
	for device_id: int in Input.get_connected_joypads():
		if not _player_joined.get(device_id, false):
			unjoined_devices.append(device_id)
	unjoined_devices.sort()

	var join_column_count := 1
	if unjoined_devices.size() > 4:
		join_column_count = 2
	var join_row_count := maxi(1, int(ceil(float(unjoined_devices.size()) / float(join_column_count))))
	var join_row_h := 24.0
	var join_box_h := 58.0 + float(join_row_count) * join_row_h
	var desired_join_w := 520.0
	if join_column_count > 1:
		desired_join_w = 680.0
	var join_box_w := minf(desired_join_w, screen.x - 120.0)
	var join_box_rect := Rect2(cx - join_box_w * 0.5, screen.y - 154.0 - join_box_h, join_box_w, join_box_h)
	if not unjoined_devices.is_empty():
		_draw_panel(join_box_rect, Color(0.04, 0.04, 0.05, 0.94), Color(0.26, 0.26, 0.28, 0.9), 2.0)
		draw_rect(Rect2(join_box_rect.position, Vector2(join_box_rect.size.x, 5.0)), Color(0.55, 0.55, 0.58, 1.0))
		_draw_centered_text_in_rect(font, "AVAILABLE CONTROLLERS", Rect2(join_box_rect.position.x, join_box_rect.position.y + 8.0, join_box_rect.size.x, 20.0), FOOTER_FONT_SIZE, Color(0.78, 0.78, 0.8))
		var list_y := join_box_rect.position.y + 36.0
		var join_col_w := join_box_rect.size.x / float(join_column_count)
		for i in unjoined_devices.size():
			var device_id := unjoined_devices[i] as int
			var col := int(floor(float(i) / float(join_row_count)))
			var row := i % join_row_count
			var cell_rect := Rect2(join_box_rect.position.x + float(col) * join_col_w, list_y + float(row) * join_row_h, join_col_w, join_row_h)
			var text := "Controller %d  -  Press A to join" % device_id
			_draw_centered_text_in_rect(font, text, cell_rect, SLOT_DETAIL_FONT_SIZE, Color(0.62, 0.62, 0.64))
	else:
		_draw_centered_text_in_rect(font, "ALL CONTROLLERS ASSIGNED", Rect2(cx - 220.0, screen.y - 160.0, 440.0, 22.0), FOOTER_FONT_SIZE, Color(0.68, 0.8, 0.68))

	var footer_rect := Rect2(cx - 350.0, screen.y - 72.0, 700.0, 42.0)
	_draw_panel(footer_rect, Color(0.03, 0.03, 0.035, 0.94), Color(0.24, 0.24, 0.26, 0.88), 1.5)
	if _has_valid_teams():
		var continue_text := "PRESS A TO CONTINUE"
		if auto_fill_bots:
			continue_text = "PRESS A TO CONTINUE WITH BOTS"
		if _awaiting_start_confirmation:
			continue_text = "A: START MATCH   |   B: CANCEL"
		_draw_centered_text_in_rect(font, continue_text, Rect2(footer_rect.position.x, footer_rect.position.y + 1.0, footer_rect.size.x, 18.0), FOOTER_FONT_SIZE, Color(0.98, 0.92, 0.48))
	else:
		_draw_centered_text_in_rect(font, "NEED AT LEAST 1 PLAYER", Rect2(footer_rect.position.x, footer_rect.position.y + 1.0, footer_rect.size.x, 18.0), FOOTER_FONT_SIZE, Color(0.82, 0.52, 0.52))
	_draw_centered_text_in_rect(font, "B: BACK   |   SELECT: SETTINGS", Rect2(footer_rect.position.x, footer_rect.position.y + 18.0, footer_rect.size.x, 18.0), FOOTER_SMALL_FONT_SIZE, Color(0.52, 0.52, 0.55))

	if _awaiting_start_confirmation:
		var panel_size := Vector2(540.0, 206.0)
		var panel_pos := Vector2(cx - panel_size.x * 0.5, screen.y * 0.5 - panel_size.y * 0.5)
		var panel_rect := Rect2(panel_pos, panel_size)
		_draw_panel(panel_rect, Color(0.06, 0.06, 0.07, 0.98), Color(0.82, 0.82, 0.85, 0.95), 2.0)
		draw_rect(Rect2(panel_rect.position, Vector2(panel_rect.size.x, 6.0)), Color(0.95, 0.82, 0.22, 1.0))
		_draw_centered_text_in_rect(font, "START THIS MATCH?", Rect2(panel_pos.x, panel_pos.y + 8.0, panel_size.x, 34.0), 28, Color.WHITE)
		_draw_centered_text_in_rect(font, "%s: %d   |   %s: %d" % [
			Enums.team_name(Enums.Team.TEAM_1),
			counts.get(Enums.Team.TEAM_1, 0),
			Enums.team_name(Enums.Team.TEAM_2),
			counts.get(Enums.Team.TEAM_2, 0),
		], Rect2(panel_pos.x, panel_pos.y + 48.0, panel_size.x, 28.0), 18, Color(0.9, 0.9, 0.9))
		var bot_chip_rect := Rect2(cx - 88.0, panel_pos.y + 92.0, 176.0, 28.0)
		var bot_fill := Color(0.14, 0.13, 0.06, 0.96)
		var bot_outline := Color(0.95, 0.82, 0.22, 0.9)
		if not auto_fill_bots:
			bot_fill = Color(0.08, 0.08, 0.09, 0.96)
			bot_outline = Color(0.45, 0.45, 0.48, 0.9)
		_draw_panel(bot_chip_rect, bot_fill, bot_outline, 1.5)
		var confirm_bot_text := "BOTS: OFF"
		if auto_fill_bots:
			confirm_bot_text = "BOTS: ON (+%d)" % total_bots
		_draw_centered_text_in_rect(font, confirm_bot_text, Rect2(panel_pos.x, panel_pos.y + 88.0, panel_size.x, 28.0), 14, Color(0.98, 0.9, 0.42))
		_draw_centered_text_in_rect(font, "A: CONFIRM   |   B: CANCEL", Rect2(panel_pos.x, panel_pos.y + 132.0, panel_size.x, 24.0), 16, Color(0.95, 0.95, 0.72))


func _draw_panel(rect: Rect2, fill: Color, outline: Color, outline_width: float = 2.0) -> void:
	draw_rect(rect, fill)
	draw_rect(rect, outline, false, outline_width)


func _draw_centered_text(font: Font, text: String, center_x: float, top_y: float, font_size: int, color: Color) -> void:
	var text_size := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
	var pos := Vector2(center_x - text_size.x * 0.5, top_y)
	var shadow := Color(0.0, 0.0, 0.0, 0.72 * color.a)
	draw_string(font, pos + Vector2(2.0, 2.0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, shadow)
	draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)


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


func _draw_summary_block(font: Font, rect: Rect2, label: String, value: String, label_color: Color, value_color: Color) -> void:
	_draw_centered_text_in_rect(font, label, Rect2(rect.position.x, rect.position.y + 14.0, rect.size.x, 18.0), SUMMARY_LABEL_FONT_SIZE, label_color)
	_draw_centered_text_in_rect(font, value, Rect2(rect.position.x, rect.position.y + 30.0, rect.size.x, 30.0), SUMMARY_VALUE_FONT_SIZE, value_color)


func _draw_team_panel(font: Font, rect: Rect2, team: Enums.Team, devices: Array, team_limit: int, accent: Color) -> void:
	var fill := Color(accent.r, accent.g, accent.b, 0.10)
	var outline := Color(accent.r, accent.g, accent.b, 0.78)
	_draw_panel(rect, fill, outline, 2.0)
	draw_rect(Rect2(rect.position, Vector2(rect.size.x, 6.0)), accent)
	_draw_centered_text_in_rect(font, Enums.team_name(team), Rect2(rect.position.x, rect.position.y + 2.0, rect.size.x, 44.0), TEAM_HEADER_FONT_SIZE, accent)
	_draw_centered_text_in_rect(font, "%d/%d players" % [devices.size(), team_limit], Rect2(rect.position.x, rect.position.y + 46.0, rect.size.x, 22.0), TEAM_SUBHEADER_FONT_SIZE, Color(0.84, 0.84, 0.86))
	draw_line(Vector2(rect.position.x + 20.0, rect.position.y + 76.0), Vector2(rect.end.x - 20.0, rect.position.y + 76.0),
		Color(accent.r, accent.g, accent.b, 0.35), 1.0)

	var slot_y := rect.position.y + 92.0
	if devices.is_empty():
		_draw_centered_text_in_rect(font, "Waiting for players", Rect2(rect.position.x, slot_y + 6.0, rect.size.x, 18.0), SLOT_TITLE_FONT_SIZE, Color(0.58, 0.58, 0.6))
		_draw_centered_text_in_rect(font, "Press A on a controller to join", Rect2(rect.position.x, slot_y + 28.0, rect.size.x, 18.0), SLOT_DETAIL_FONT_SIZE, Color(0.42, 0.42, 0.45))
		return

	for i in devices.size():
		var device_id := devices[i] as int
		var card_rect := Rect2(rect.position.x + 20.0, slot_y + float(i) * 54.0, rect.size.x - 40.0, 46.0)
		_draw_panel(card_rect, Color(0.04, 0.04, 0.05, 0.92), Color(accent.r, accent.g, accent.b, 0.42), 1.5)
		draw_rect(Rect2(card_rect.position, Vector2(6.0, card_rect.size.y)), accent)
		var player_label := "P%d" % (device_id + 1)
		draw_string(font, Vector2(card_rect.position.x + 18.0, card_rect.position.y + 30.0),
			player_label, HORIZONTAL_ALIGNMENT_LEFT, -1, SLOT_TITLE_FONT_SIZE, accent)
		draw_string(font, Vector2(card_rect.position.x + 74.0, card_rect.position.y + 30.0),
			"Controller %d" % device_id, HORIZONTAL_ALIGNMENT_LEFT, -1, SLOT_TITLE_FONT_SIZE, Color(0.9, 0.9, 0.92))
		draw_string(font, Vector2(card_rect.position.x + 74.0, card_rect.position.y + 42.0),
			"Ready", HORIZONTAL_ALIGNMENT_LEFT, -1, SLOT_DETAIL_FONT_SIZE, Color(0.68, 0.72, 0.68))
