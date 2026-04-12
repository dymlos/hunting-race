class_name TeamSetup
extends Control

## Team assignment screen. Players press A to join, stick to pick teams, START to advance.
## Roles (Escapist/Trapper) are assigned per-round by GameManager, not here.

signal teams_ready(team_assignments: Dictionary)

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
	for device_id: int in pads:
		if _player_joined.get(device_id, false):
			if InputManager.is_button_just_pressed_on_device(device_id, JOY_BUTTON_B):
				_player_joined[device_id] = false
				_player_teams.erase(device_id)
			elif _nav_cooldowns.get(device_id, 0.0) <= 0.0:
				var x := Input.get_joy_axis(device_id, JOY_AXIS_LEFT_X)
				if x < -0.5:
					_player_teams[device_id] = Enums.Team.TEAM_1
					_nav_cooldowns[device_id] = NAV_COOLDOWN
				elif x > 0.5:
					_player_teams[device_id] = Enums.Team.TEAM_2
					_nav_cooldowns[device_id] = NAV_COOLDOWN
		else:
			if Input.is_joy_button_pressed(device_id, JOY_BUTTON_A):
				_player_joined[device_id] = true
				_player_teams[device_id] = Enums.Team.TEAM_1
				_nav_cooldowns[device_id] = NAV_COOLDOWN

	if _has_valid_teams():
		for device_id: int in pads:
			if _player_joined.get(device_id, false):
				if Input.is_joy_button_pressed(device_id, JOY_BUTTON_START):
					_advance()
					return

	queue_redraw()


func _has_valid_teams() -> bool:
	for device_id: int in _player_joined:
		if _player_joined[device_id]:
			return true
	return false


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

		var bot_id := 100
		while t1 < 3:
			t_assignments[bot_id] = Enums.Team.TEAM_1
			bot_id += 1
			t1 += 1
		while t2 < 3:
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

	draw_line(Vector2(cx, 120), Vector2(cx, screen.y - 60), Color(0.4, 0.4, 0.4), 2.0)

	var t1c := Enums.team_color(Enums.Team.TEAM_1)
	var t2c := Enums.team_color(Enums.Team.TEAM_2)
	draw_string(font, Vector2(cx * 0.5 - 40, 150), "TEAM 1",
		HORIZONTAL_ALIGNMENT_CENTER, -1, 24, t1c)
	draw_string(font, Vector2(cx * 1.5 - 40, 150), "TEAM 2",
		HORIZONTAL_ALIGNMENT_CENTER, -1, 24, t2c)

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
		draw_string(font, Vector2(cx - 90, screen.y - 40), "Press START to begin",
			HORIZONTAL_ALIGNMENT_CENTER, -1, 18, Color.YELLOW)
	else:
		draw_string(font, Vector2(cx - 100, screen.y - 40), "Need at least 1 player",
			HORIZONTAL_ALIGNMENT_CENTER, -1, 14, Color(0.5, 0.5, 0.5))
