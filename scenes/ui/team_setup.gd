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
var input_blocked: bool = false
var auto_fill_bots: bool = false

const NAV_COOLDOWN: float = 0.2


func setup() -> void:
	_player_joined.clear()
	_player_teams.clear()
	_nav_cooldowns.clear()
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

	# Tick nav cooldowns
	for device_id: int in _nav_cooldowns:
		_nav_cooldowns[device_id] = maxf(0.0, _nav_cooldowns[device_id] - delta)

	var pads := connected_pads
	var joined_this_frame := false
	for device_id: int in pads:
		if _player_joined.get(device_id, false):
			if InputManager.is_button_just_pressed_on_device(device_id, JOY_BUTTON_B):
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
				joined_this_frame = true
			elif InputManager.is_button_just_pressed_on_device(device_id, JOY_BUTTON_B):
				back_requested.emit()
				return

	# SELECT to open settings
	for device_id: int in pads:
		if InputManager.is_button_just_pressed_on_device(device_id, JOY_BUTTON_BACK):
			settings_requested.emit()
			return

	if _has_valid_teams() and not joined_this_frame:
		for device_id: int in pads:
			if _player_joined.get(device_id, false):
				if InputManager.is_button_just_pressed_on_device(device_id, JOY_BUTTON_A):
					_advance()
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


func _advance() -> void:
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

	draw_rect(Rect2(Vector2.ZERO, screen), Color.BLACK)

	draw_string(font, Vector2(cx - 80, 80), "TEAM SETUP",
		HORIZONTAL_ALIGNMENT_CENTER, -1, 32, Color.WHITE)

	var team_limit := _get_team_size_limit()
	if team_limit < 1:
		team_limit = 1
	var counts := _get_team_counts()
	var bot_counts := _get_bot_counts_for_display()
	var human_count := _get_human_player_count()
	var total_capacity := team_limit * 2
	var total_bots := (bot_counts.get(Enums.Team.TEAM_1, 0) as int) \
		+ (bot_counts.get(Enums.Team.TEAM_2, 0) as int)
	var format_text := "%dv%d" % [
		(counts.get(Enums.Team.TEAM_1, 0) as int) + (bot_counts.get(Enums.Team.TEAM_1, 0) as int),
		(counts.get(Enums.Team.TEAM_2, 0) as int) + (bot_counts.get(Enums.Team.TEAM_2, 0) as int),
	]
	var bot_state := "Off"
	if auto_fill_bots:
		bot_state = "On (+%d)" % total_bots
	var summary_color := Color(0.82, 0.82, 0.82)
	draw_string(font, Vector2(cx, 112), "Players: %d/%d | Team Size: %d | Bots: %s" % [
		human_count, total_capacity, team_limit, bot_state
	], HORIZONTAL_ALIGNMENT_CENTER, -1, 16, summary_color)
	draw_string(font, Vector2(cx, 132), "Current Match: %s" % format_text,
		HORIZONTAL_ALIGNMENT_CENTER, -1, 16, Color(0.7, 0.9, 0.7))

	draw_line(Vector2(cx, 120), Vector2(cx, screen.y - 60), Color(0.4, 0.4, 0.4), 2.0)

	var t1c := Enums.team_color(Enums.Team.TEAM_1)
	var t2c := Enums.team_color(Enums.Team.TEAM_2)

	# Player slots
	var t1_devices: Array = []
	var t2_devices: Array = []
	for device_id: int in _player_teams:
		if _player_joined.get(device_id, false):
			if _player_teams[device_id] == Enums.Team.TEAM_1:
				t1_devices.append(device_id)
			else:
				t2_devices.append(device_id)
	t1_devices.sort()
	t2_devices.sort()
	var slot_height := 40.0
	var t1_count := t1_devices.size()
	var t2_count := t2_devices.size()
	var t1_label := "TEAM 1 (%d/%d)" % [t1_count, team_limit]
	var t2_label := "TEAM 2 (%d/%d)" % [t2_count, team_limit]
	draw_string(font, Vector2(cx * 0.5 - 20, 150), t1_label,
		HORIZONTAL_ALIGNMENT_CENTER, -1, 24, t1c)
	draw_string(font, Vector2(cx * 1.5 - 20, 150), t2_label,
		HORIZONTAL_ALIGNMENT_CENTER, -1, 24, t2c)
	for i in t1_devices.size():
		var label := "P%d" % (t1_devices[i] + 1)
		draw_string(font, Vector2(cx * 0.5 - 20, 190.0 + i * slot_height), label,
			HORIZONTAL_ALIGNMENT_CENTER, -1, 16, t1c)

	for i in t2_devices.size():
		var label := "P%d" % (t2_devices[i] + 1)
		draw_string(font, Vector2(cx * 1.5 - 20, 190.0 + i * slot_height), label,
			HORIZONTAL_ALIGNMENT_CENTER, -1, 16, t2c)

	# Unjoined controllers
	var unjoin_y := 190.0 + maxf(t1_devices.size(), t2_devices.size()) * slot_height + 40.0
	for device_id: int in Input.get_connected_joypads():
		if not _player_joined.get(device_id, false):
			var text := "Controller %d - Press A to join" % device_id
			draw_string(font, Vector2(cx - 140, unjoin_y), text,
				HORIZONTAL_ALIGNMENT_CENTER, -1, 14, Color(0.5, 0.5, 0.5))
			unjoin_y += 26.0

	# Hints
	if _has_valid_teams():
		var continue_text := "Press A to continue"
		if auto_fill_bots:
			continue_text = "Press A to continue with bots"
		draw_string(font, Vector2(cx - 90, screen.y - 40), continue_text,
			HORIZONTAL_ALIGNMENT_CENTER, -1, 18, Color.YELLOW)
	else:
		draw_string(font, Vector2(cx - 100, screen.y - 40), "Need at least 1 player",
			HORIZONTAL_ALIGNMENT_CENTER, -1, 14, Color(0.5, 0.5, 0.5))

	draw_string(font, Vector2(cx - 118, screen.y - 18), "B: Back | SELECT: Settings",
		HORIZONTAL_ALIGNMENT_CENTER, -1, 12, Color(0.4, 0.4, 0.4))
