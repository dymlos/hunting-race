class_name SettingsMenu
extends Control

## Settings menu opened with SELECT from team setup. UP/DOWN to navigate,
## LEFT/RIGHT to change values, B or SELECT to close.

signal closed
signal setting_changed(key: String, value: Variant)

var input_blocked: bool = false

var _selected_index: int = 0
var _prev_stick_x: float = 0.0
var _prev_stick_y: float = 0.0

# Each setting: {key, label, type, options/min/max/step, default, value}
# type: "options" (cycle through list), "int" (min/max), "number" (multiplier ±%)
var _settings: Array[Dictionary] = []

const NAV_COOLDOWN: float = 0.2
var _nav_cooldown: float = 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_settings = [
		{
			"key": "bot_fill", "label": "Bot Auto-Fill",
			"type": "options", "options": ["On", "Off"],
			"value": 0,
		},
		{
			"key": "bot_ai", "label": "Bot Trapper AI",
			"type": "options", "options": ["Off", "On"],
			"value": 0,
		},
		{
			"key": "hunt_duration", "label": "Round Time",
			"type": "int", "min": 15, "max": 180, "step": 15,
			"value": int(Constants.HUNT_DURATION),
		},
		{
			"key": "hunt_countdown_enabled", "label": "Strategy Hunt",
			"type": "options", "options": ["On", "Off"],
			"value": 0,
		},
		{
			"key": "observation_duration", "label": "Observation Time",
			"type": "int", "min": 1, "max": 20, "step": 1,
			"value": int(Constants.OBSERVATION_DURATION),
		},
		{
			"key": "hunt_countdown_duration", "label": "Strategy Hunt Time",
			"type": "int", "min": 1, "max": 10, "step": 1,
			"value": int(Constants.HUNT_COUNTDOWN_DURATION),
		},
		{
			"key": "score_to_win", "label": "Rounds to Play",
			"type": "int", "min": 1, "max": 30, "step": 1,
			"value": Constants.SCORE_TO_WIN,
		},
		{
			"key": "team_size", "label": "Team Size",
			"type": "int", "min": 1, "max": 4, "step": 1,
			"value": 4,
		},
		{
			"key": "escapist_speed", "label": "Escapist Speed",
			"type": "number", "default": Constants.SPEED_ESCAPIST,
			"value": 1.0, "min_mult": 0.5, "max_mult": 1.5, "step": 0.1,
		},
		{
			"key": "trapper_speed", "label": "Cursor Speed",
			"type": "number", "default": Constants.TRAPPER_CURSOR_SPEED,
			"value": 1.0, "min_mult": 0.5, "max_mult": 1.5, "step": 0.1,
		},
		{
			"key": "music_volume", "label": "Music Volume",
			"type": "volume", "value": 100, "min": 0, "max": 100, "step": 5,
		},
		{
			"key": "effects_volume", "label": "SFX Volume",
			"type": "volume", "value": 100, "min": 0, "max": 100, "step": 5,
		},
		{
			"key": "poison_duration", "label": "Poison Time",
			"type": "int", "min": 2, "max": 15, "step": 1,
			"value": int(Constants.POISON_DURATION),
		},
	]


func open() -> void:
	_selected_index = 0
	_prev_stick_x = 0.0
	_prev_stick_y = 0.0
	_nav_cooldown = 0.0
	show()
	queue_redraw()


func _process(delta: float) -> void:
	if not visible or input_blocked:
		return

	_nav_cooldown = maxf(0.0, _nav_cooldown - delta)

	var pads := Input.get_connected_joypads()
	for device_id: int in pads:
		var stick_x := Input.get_joy_axis(device_id, JOY_AXIS_LEFT_X)
		var stick_y := Input.get_joy_axis(device_id, JOY_AXIS_LEFT_Y)

		# UP/DOWN navigation
		if _nav_cooldown <= 0.0:
			if stick_y > 0.5:
				_selected_index = (_selected_index + 1) % _settings.size()
				_nav_cooldown = NAV_COOLDOWN
			elif stick_y < -0.5:
				_selected_index = (_selected_index - 1 + _settings.size()) % _settings.size()
				_nav_cooldown = NAV_COOLDOWN

		# LEFT/RIGHT value change (edge detection)
		if stick_x > 0.5 and _prev_stick_x <= 0.5:
			_change_value(1)
		elif stick_x < -0.5 and _prev_stick_x >= -0.5:
			_change_value(-1)

		_prev_stick_x = stick_x
		_prev_stick_y = stick_y

		# B or SELECT to close
		if InputManager.is_button_just_pressed_on_device(device_id, JOY_BUTTON_B) \
				or InputManager.is_button_just_pressed_on_device(device_id, JOY_BUTTON_BACK):
			closed.emit()
			return

	queue_redraw()


func _change_value(direction: int) -> void:
	var setting: Dictionary = _settings[_selected_index]
	var key: String = setting["key"] as String
	var type: String = setting["type"] as String

	match type:
		"options":
			var options: Array = setting["options"] as Array
			var val: int = setting["value"] as int
			val = (val + direction + options.size()) % options.size()
			setting["value"] = val
		"int":
			var val: int = setting["value"] as int
			var step: int = setting.get("step", 1) as int
			val = clampi(val + direction * step, setting["min"] as int, setting["max"] as int)
			setting["value"] = val
		"number":
			var val: float = setting["value"] as float
			var step: float = setting.get("step", 0.1) as float
			val = clampf(val + direction * step,
				setting["min_mult"] as float, setting["max_mult"] as float)
			setting["value"] = snappedi(val * 100, int(step * 100)) / 100.0
		"volume":
			var val: int = setting["value"] as int
			var step: int = setting.get("step", 5) as int
			val = clampi(val + direction * step, setting["min"] as int, setting["max"] as int)
			setting["value"] = val

	setting_changed.emit(key, setting["value"])


func get_setting(key: String) -> Variant:
	for s: Dictionary in _settings:
		if (s["key"] as String) == key:
			return s["value"]
	return null


func _draw() -> void:
	var screen := get_viewport_rect().size
	var cx := screen.x / 2.0
	var font := ThemeDB.fallback_font

	# Dark overlay
	draw_rect(Rect2(Vector2.ZERO, screen), Color(0, 0, 0, 0.85))

	# Border
	var margin := 30.0
	var border_rect := Rect2(Vector2(margin, margin), screen - Vector2(margin * 2, margin * 2))
	draw_rect(border_rect, Color(0.3, 0.3, 0.3), false, 2.0)

	# Title
	var title := "SETTINGS"
	var title_w := font.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, 28).x
	draw_string(font, Vector2(cx - title_w / 2.0, margin + 40),
		title, HORIZONTAL_ALIGNMENT_LEFT, -1, 28, Color.WHITE)

	# Settings list
	var list_y := margin + 70.0
	var available_h := screen.y - list_y - margin - 40.0
	var item_spacing := minf(36.0, available_h / _settings.size())
	var font_size := 16 if item_spacing < 28 else (20 if item_spacing < 35 else 22)

	for i in _settings.size():
		var setting: Dictionary = _settings[i]
		var is_selected := i == _selected_index
		var label: String = setting["label"] as String
		var type: String = setting["type"] as String
		var color := Color.YELLOW if is_selected else Color(0.7, 0.7, 0.7)
		var prefix := "> " if is_selected else "  "
		var y := list_y + i * item_spacing

		# Value display
		var value_text := ""
		match type:
			"options":
				var options: Array = setting["options"] as Array
				var val: int = setting["value"] as int
				value_text = options[val] as String
			"int":
				value_text = "%d" % (setting["value"] as int)
			"number":
				value_text = "%d%%" % int((setting["value"] as float) * 100.0)
			"volume":
				value_text = "%d%%" % (setting["value"] as int)

		var display := "%s%s:  < %s >" % [prefix, label, value_text]
		draw_string(font, Vector2(cx - 200, y),
			display, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)
		if type == "volume":
			_draw_slider_bar(Vector2(cx + 130.0, y - float(font_size) + 5.0),
				setting["value"] as int, color)

	# Hint
	var hint := "LEFT/RIGHT change | UP/DOWN navigate | B or SELECT close"
	var hw := font.get_string_size(hint, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x
	draw_string(font, Vector2(cx - hw / 2.0, screen.y - margin - 10),
		hint, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(0.5, 0.5, 0.5))


func _draw_slider_bar(pos: Vector2, value: int, color: Color) -> void:
	var bar_size := Vector2(150.0, 8.0)
	var ratio := clampf(float(value) / 100.0, 0.0, 1.0)
	draw_rect(Rect2(pos, bar_size), Color(0.18, 0.18, 0.18, 0.95))
	draw_rect(Rect2(pos, Vector2(bar_size.x * ratio, bar_size.y)), Color(color, 0.9))
	draw_rect(Rect2(pos, bar_size), Color(0.62, 0.62, 0.62, 0.65), false, 1.0)
	var knob_x := pos.x + bar_size.x * ratio
	draw_rect(Rect2(Vector2(knob_x - 3.0, pos.y - 4.0), Vector2(6.0, 16.0)), color)
