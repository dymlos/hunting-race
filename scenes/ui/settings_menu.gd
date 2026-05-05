class_name SettingsMenu
extends Control

## Settings menu opened with Y from team setup. UP/DOWN to navigate,
## LEFT/RIGHT to change values, SELECT to close.

signal closed
signal setting_changed(key: String, value: Variant)

var input_blocked: bool = false

var _selected_index: int = 0
var _survival_context: bool = false
var _nav_axis_locked: bool = false
var _value_axis_locked: bool = false

# Each setting: {key, label, type, options/min/max/step, default, value}
# type: "options" (cycle through list), "int" (min/max), "number" (multiplier ±%)
var _all_settings: Array[Dictionary] = []
var _settings: Array[Dictionary] = []

const VALUE_AXIS_THRESHOLD: float = 0.86
const VALUE_AXIS_RELEASE: float = 0.42
const NAV_AXIS_THRESHOLD: float = 0.84
const NAV_AXIS_RELEASE: float = 0.42


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_all_settings = [
		{
			"key": "bot_fill", "label": "Rellenar con bots",
			"type": "options", "options": ["Sí", "No"],
			"value": 1,
		},
		{
			"key": "survival_static_bots", "label": "Bots estáticos",
			"type": "options", "options": ["Sí", "No"],
			"value": 0,
			"contexts": ["survival"],
		},
		{
			"key": "bot_ai", "label": "IA de cazadores",
			"type": "options", "options": ["No", "Sí"],
			"value": 0,
			"hide_in_survival": true,
		},
		{
			"key": "hunt_duration", "label": "Tiempo de ronda",
			"type": "int", "min": 15, "max": 180, "step": 15,
			"value": int(Constants.HUNT_DURATION),
			"hide_in_survival": true,
		},
		{
			"key": "survival_escape_duration", "label": "Tiempo survival",
			"type": "int", "min": 60, "max": 600, "step": 15,
			"value": int(Constants.SURVIVAL_ESCAPE_DURATION),
			"contexts": ["survival"],
		},
		{
			"key": "hunt_countdown_enabled", "label": "Cazería planificada",
			"type": "options", "options": ["Sí", "No"],
			"value": 0,
			"hide_in_survival": true,
		},
		{
			"key": "observation_duration", "label": "Tiempo de vista previa",
			"type": "int", "min": 1, "max": 20, "step": 1,
			"value": int(Constants.OBSERVATION_DURATION),
			"hide_in_survival": true,
		},
		{
			"key": "hunt_countdown_duration", "label": "Tiempo de cazería",
			"type": "int", "min": 1, "max": 60, "step": 1,
			"value": int(Constants.HUNT_COUNTDOWN_DURATION),
			"hide_in_survival": true,
		},
		{
			"key": "score_to_win", "label": "Rondas a jugar",
			"type": "int", "min": 1, "max": 30, "step": 1,
			"value": Constants.SCORE_TO_WIN,
			"hide_in_survival": true,
		},
		{
			"key": "team_size", "label": "Tamaño de equipo",
			"type": "int", "min": 1, "max": 4, "step": 1,
			"value": 4,
		},
		{
			"key": "escapist_speed", "label": "Velocidad escapista",
			"type": "number", "default": Constants.SPEED_ESCAPIST,
			"value": 1.0, "min_mult": 0.5, "max_mult": 1.5, "step": 0.1,
		},
		{
			"key": "trapper_speed", "label": "Velocidad del cursor",
			"type": "number", "default": Constants.TRAPPER_CURSOR_SPEED,
			"value": 1.0, "min_mult": 0.5, "max_mult": 1.5, "step": 0.1,
		},
		{
			"key": "music_volume", "label": "Volumen de música",
			"type": "volume", "value": 100, "min": 0, "max": 100, "step": 5,
		},
		{
			"key": "effects_volume", "label": "Volumen de efectos",
			"type": "volume", "value": 100, "min": 0, "max": 100, "step": 5,
		},
		{
			"key": "poison_duration", "label": "Tiempo de veneno",
			"type": "int", "min": 2, "max": 15, "step": 1,
			"value": int(Constants.POISON_DURATION),
		},
	]
	_refresh_visible_settings()


func open() -> void:
	_refresh_visible_settings()
	_selected_index = 0
	_nav_axis_locked = _is_any_axis_active(JOY_AXIS_LEFT_Y, NAV_AXIS_RELEASE)
	_value_axis_locked = _is_any_axis_active(JOY_AXIS_LEFT_X, VALUE_AXIS_RELEASE)
	show()
	queue_redraw()


func set_survival_context(enabled: bool) -> void:
	_survival_context = enabled
	_refresh_visible_settings()
	queue_redraw()


func set_setting_value(key: String, value: Variant) -> void:
	for setting: Dictionary in _all_settings:
		if (setting["key"] as String) != key:
			continue
		var type: String = setting["type"] as String
		match type:
			"options":
				var options: Array = setting["options"] as Array
				setting["value"] = clampi(int(value), 0, options.size() - 1)
			"int":
				setting["value"] = clampi(int(value), setting["min"] as int, setting["max"] as int)
			"number":
				setting["value"] = clampf(float(value),
					setting["min_mult"] as float, setting["max_mult"] as float)
			"volume":
				setting["value"] = clampi(int(value), setting["min"] as int, setting["max"] as int)
		_refresh_visible_settings()
		queue_redraw()
		return


func _is_any_axis_active(axis: int, release_threshold: float) -> bool:
	for device_id: int in Input.get_connected_joypads():
		if absf(Input.get_joy_axis(device_id, axis as JoyAxis)) > release_threshold:
			return true
	return false


func _refresh_visible_settings() -> void:
	_settings.clear()
	for setting: Dictionary in _all_settings:
		if _is_setting_visible(setting):
			_settings.append(setting)
	if _settings.is_empty():
		_selected_index = 0
	else:
		_selected_index = clampi(_selected_index, 0, _settings.size() - 1)


func _is_setting_visible(setting: Dictionary) -> bool:
	if _survival_context and (setting.get("hide_in_survival", false) as bool):
		return false
	var contexts: Array = setting.get("contexts", []) as Array
	if contexts.is_empty():
		return true
	return ("survival" in contexts) == _survival_context


func _process(_delta: float) -> void:
	if not visible or input_blocked:
		return
	if _settings.is_empty():
		return

	var pads := Input.get_connected_joypads()
	var nav_direction := 0
	var value_direction := 0
	var nav_neutral := true
	var value_neutral := true
	for device_id: int in pads:
		var stick_x := Input.get_joy_axis(device_id, JOY_AXIS_LEFT_X)
		var stick_y := Input.get_joy_axis(device_id, JOY_AXIS_LEFT_Y)
		var abs_x := absf(stick_x)
		var abs_y := absf(stick_y)
		var horizontal_is_dominant := abs_x >= abs_y
		var vertical_is_dominant := abs_y > abs_x

		if abs_y > NAV_AXIS_RELEASE:
			nav_neutral = false
		if abs_x > VALUE_AXIS_RELEASE:
			value_neutral = false

		if not _nav_axis_locked and nav_direction == 0 and vertical_is_dominant:
			if stick_y > NAV_AXIS_THRESHOLD:
				nav_direction = 1
			elif stick_y < -NAV_AXIS_THRESHOLD:
				nav_direction = -1

		if not _value_axis_locked and value_direction == 0 and horizontal_is_dominant:
			if stick_x > VALUE_AXIS_THRESHOLD:
				value_direction = 1
			elif stick_x < -VALUE_AXIS_THRESHOLD:
				value_direction = -1

		if InputManager.is_menu_back_just_pressed(device_id):
			closed.emit()
			return

	if _nav_axis_locked and nav_neutral:
		_nav_axis_locked = false
	if _value_axis_locked and value_neutral:
		_value_axis_locked = false

	if not _nav_axis_locked and nav_direction != 0:
		_selected_index = (_selected_index + nav_direction + _settings.size()) % _settings.size()
		_nav_axis_locked = true
	elif not _value_axis_locked and value_direction != 0:
		_change_value(value_direction)
		_value_axis_locked = true

	queue_redraw()


func _change_value(direction: int) -> void:
	if _settings.is_empty():
		return
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
	for s: Dictionary in _all_settings:
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
	var title := "AJUSTES"
	var title_w := font.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, 28).x
	draw_string(font, Vector2(cx - title_w / 2.0, margin + 40),
		title, HORIZONTAL_ALIGNMENT_LEFT, -1, 28, Color.WHITE)

	# Settings list
	if _settings.is_empty():
		return
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
	var hint := "Izq./Der. cambiar | Arriba/Abajo navegar | Select cerrar"
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
