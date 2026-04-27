class_name PauseMenu
extends Control

signal resume_requested
signal settings_requested
signal practice_requested
signal practice_character_select_requested
signal practice_obstacles_toggled(enabled: bool)
signal practice_bots_toggled(enabled: bool)
signal how_to_play_requested
signal reset_requested
signal round_reset_requested

var input_blocked: bool = false

var _selected_index: int = 0
var _nav_cooldown: float = 0.0
var _showing_ability_guide: bool = false

const NAV_COOLDOWN: float = 0.2
const OFFICIAL_OPTIONS: Array[String] = ["Resume", "Settings", "How to Play", "Ability Guide", "Cooldowns", "Restart Round", "Practice Mode", "Return to Setup"]
const PRACTICE_OPTIONS: Array[String] = ["Resume", "Settings", "How to Play", "Ability Guide", "Cooldowns", "Practice Obstacles", "Practice Bots", "Change Characters", "Restart Practice Setup"]


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func open() -> void:
	_selected_index = 0
	_nav_cooldown = 0.0
	_showing_ability_guide = false
	show()
	queue_redraw()


func _process(delta: float) -> void:
	if not visible or input_blocked:
		return

	_nav_cooldown = maxf(0.0, _nav_cooldown - delta)

	for device_id: int in Input.get_connected_joypads():
		if not InputManager.is_assigned_device(device_id):
			continue

		if _showing_ability_guide:
			if InputManager.is_button_just_pressed_on_device(device_id, JOY_BUTTON_A) \
					or InputManager.is_button_just_pressed_on_device(device_id, JOY_BUTTON_B):
				_showing_ability_guide = false
				queue_redraw()
				return
			continue

		var options := _get_options()
		var stick_y := Input.get_joy_axis(device_id, JOY_AXIS_LEFT_Y)
		if _nav_cooldown <= 0.0:
			if stick_y > 0.5:
				_selected_index = (_selected_index + 1) % options.size()
				_nav_cooldown = NAV_COOLDOWN
			elif stick_y < -0.5:
				_selected_index = (_selected_index - 1 + options.size()) % options.size()
				_nav_cooldown = NAV_COOLDOWN

		if InputManager.is_button_just_pressed_on_device(device_id, JOY_BUTTON_BACK):
			if GameManager.practice_mode:
				practice_requested.emit()
			else:
				reset_requested.emit()
			return

		if InputManager.is_button_just_pressed_on_device(device_id, JOY_BUTTON_B):
			resume_requested.emit()
			return

		if InputManager.is_button_just_pressed_on_device(device_id, JOY_BUTTON_A):
			_activate_option(options[_selected_index])
			return

	queue_redraw()


func _draw() -> void:
	var screen := get_viewport_rect().size
	var font := ThemeDB.fallback_font
	var cx := screen.x / 2.0
	var cy := screen.y / 2.0

	draw_rect(Rect2(Vector2.ZERO, screen), Color(0, 0, 0, 0.72))
	if _showing_ability_guide:
		_draw_ability_guide(font, screen)
		return

	var options := _get_options()
	var panel_size := Vector2(520, 154 + options.size() * 39 + 48)
	var panel_pos := Vector2(cx - panel_size.x / 2.0, cy - panel_size.y / 2.0)
	var panel_rect := Rect2(panel_pos, panel_size)
	draw_rect(panel_rect, Color(0.08, 0.08, 0.08, 0.95))
	draw_rect(panel_rect, Color(0.7, 0.7, 0.7, 0.75), false, 2.0)

	var title := "PAUSED"
	var title_size := 34
	var title_w := font.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, title_size).x
	draw_string(font, Vector2(cx - title_w / 2.0, panel_pos.y + 58),
		title, HORIZONTAL_ALIGNMENT_LEFT, -1, title_size, Color.WHITE)

	for i in options.size():
		var text := _get_option_label(options[i])
		var color := Color.YELLOW if i == _selected_index else Color(0.78, 0.78, 0.78)
		var prefix := "> " if i == _selected_index else "  "
		var display := "%s%s" % [prefix, text]
		var size := 24
		var width := font.get_string_size(display, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
		draw_string(font, Vector2(cx - width / 2.0, panel_pos.y + 114 + i * 39),
			display, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)

	var hint := "UP/DOWN select | A confirm | B resume | SELECT setup"
	if GameManager.practice_mode:
		hint = "UP/DOWN select | A confirm | B resume | SELECT practice setup"
	var hint_size := 13
	var hint_w := font.get_string_size(hint, HORIZONTAL_ALIGNMENT_LEFT, -1, hint_size).x
	draw_string(font, Vector2(cx - hint_w / 2.0, panel_pos.y + panel_size.y - 24),
		hint, HORIZONTAL_ALIGNMENT_LEFT, -1, hint_size, Color(0.55, 0.55, 0.55))


func _draw_ability_guide(font: Font, screen: Vector2) -> void:
	var panel_margin := 36.0
	var panel := Rect2(Vector2(panel_margin, 30.0),
		Vector2(screen.x - panel_margin * 2.0, screen.y - 60.0))
	draw_rect(panel, Color(0.06, 0.06, 0.06, 0.96))
	draw_rect(panel, Color(0.75, 0.75, 0.75, 0.75), false, 2.0)

	var title := "ABILITY GUIDE"
	draw_string(font, panel.position + Vector2(28.0, 42.0),
		title, HORIZONTAL_ALIGNMENT_LEFT, -1, 38, Color.WHITE)
	draw_string(font, panel.position + Vector2(28.0, 68.0),
		"Escapists use A. Trappers use A, X, and Y. SELECT cancels multi-point trap placement.",
		HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(0.68, 0.68, 0.68))

	var left_x := panel.position.x + 30.0
	var right_x := panel.position.x + panel.size.x * 0.48
	var top_y := panel.position.y + 124.0
	_draw_escapist_guide(font, Vector2(left_x, top_y), panel.size.x * 0.4)
	_draw_trapper_guide(font, Vector2(right_x, top_y), panel.size.x * 0.46)

	var hint := "A / B close"
	var hint_width := font.get_string_size(hint, HORIZONTAL_ALIGNMENT_LEFT, -1, 18).x
	draw_string(font, Vector2(panel.position.x + panel.size.x - hint_width - 28.0,
			panel.position.y + panel.size.y - 20.0),
		hint, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color.YELLOW)


func _get_options() -> Array[String]:
	if GameManager.practice_mode:
		return PRACTICE_OPTIONS
	return OFFICIAL_OPTIONS


func _get_option_label(option: String) -> String:
	match option:
		"Cooldowns":
			var enabled := GameManager.settings_overrides.get(&"skill_cooldowns_enabled", true) as bool
			return "Cooldowns: < %s >" % ("On" if enabled else "Off")
		"Practice Obstacles":
			var enabled := GameManager.settings_overrides.get(&"practice_obstacles_enabled", false) as bool
			return "Obstacles: < %s >" % ("On" if enabled else "Off")
		"Practice Bots":
			var enabled := GameManager.settings_overrides.get(&"practice_bots_enabled", false) as bool
			return "Bots: < %s >" % ("On" if enabled else "Off")
	return option


func _activate_option(option: String) -> void:
	match option:
		"Resume":
			resume_requested.emit()
		"Settings":
			settings_requested.emit()
		"How to Play":
			how_to_play_requested.emit()
		"Ability Guide":
			_showing_ability_guide = true
			queue_redraw()
		"Cooldowns":
			_toggle_skill_cooldowns()
		"Practice Mode":
			practice_requested.emit()
		"Restart Round":
			round_reset_requested.emit()
		"Practice Obstacles":
			_toggle_practice_obstacles()
		"Practice Bots":
			_toggle_practice_bots()
		"Change Characters":
			practice_character_select_requested.emit()
		"Restart Practice Setup":
			practice_requested.emit()
		"Return to Setup":
			reset_requested.emit()


func _toggle_skill_cooldowns() -> void:
	var enabled := GameManager.settings_overrides.get(&"skill_cooldowns_enabled", true) as bool
	GameManager.settings_overrides[&"skill_cooldowns_enabled"] = not enabled
	queue_redraw()


func _toggle_practice_obstacles() -> void:
	var enabled := GameManager.settings_overrides.get(&"practice_obstacles_enabled", false) as bool
	var next_enabled := not enabled
	GameManager.settings_overrides[&"practice_obstacles_enabled"] = next_enabled
	practice_obstacles_toggled.emit(next_enabled)
	queue_redraw()


func _toggle_practice_bots() -> void:
	var enabled := GameManager.settings_overrides.get(&"practice_bots_enabled", false) as bool
	var next_enabled := not enabled
	GameManager.settings_overrides[&"practice_bots_enabled"] = next_enabled
	practice_bots_toggled.emit(next_enabled)
	queue_redraw()


func _draw_escapist_guide(font: Font, pos: Vector2, width: float) -> void:
	draw_string(font, pos, "ESCAPISTS", HORIZONTAL_ALIGNMENT_LEFT, -1, 26,
		Enums.role_color(Enums.Role.ESCAPIST))
	var y := pos.y + 42.0
	for animal_data: Dictionary in EscapistAnimals.get_all():
		var ability: Dictionary = animal_data["ability"] as Dictionary
		var color: Color = animal_data["color"] as Color
		var header := "%s  [%s] %s" % [
			animal_data["name"] as String,
			ability["button"] as String,
			"%s  CD %ds" % [
				ability["name"] as String,
				int(_get_escapist_cooldown(animal_data["id"] as Enums.EscapistAnimal)),
			],
		]
		draw_string(font, Vector2(pos.x, y), header,
			HORIZONTAL_ALIGNMENT_LEFT, -1, 18, color)
		y += 23.0
		y += _draw_wrapped_text(font, ability["desc"] as String,
			Vector2(pos.x + 12.0, y), width - 12.0, 15,
			Color(0.74, 0.74, 0.74), 19.0, 2)
		y += 17.0


func _draw_trapper_guide(font: Font, pos: Vector2, width: float) -> void:
	draw_string(font, pos, "TRAPPERS", HORIZONTAL_ALIGNMENT_LEFT, -1, 26,
		Enums.role_color(Enums.Role.TRAPPER))
	var y := pos.y + 42.0
	for trapper_data: Dictionary in _get_trapper_guide_data():
		var color: Color = trapper_data["color"] as Color
		draw_string(font, Vector2(pos.x, y), trapper_data["name"] as String,
			HORIZONTAL_ALIGNMENT_LEFT, -1, 18, color)
		y += 23.0
		var abilities: Array = trapper_data["abilities"] as Array
		for ability: Dictionary in abilities:
			var line := "[%s] %s - %s" % [
				ability["button"] as String,
				"%s  CD %ds" % [
					ability["name"] as String,
					int(_get_trapper_cooldown(
						trapper_data["id"] as Enums.TrapperCharacter,
						ability["button"] as String
					)),
				],
				ability["desc"] as String,
			]
			y += _draw_wrapped_text(font, line, Vector2(pos.x + 12.0, y),
				width - 12.0, 14, Color(0.74, 0.74, 0.74), 17.0, 2)
		y += 14.0


func _draw_wrapped_text(font: Font, text: String, position: Vector2,
		max_width: float, font_size: int, color: Color, line_height: float,
		max_lines: int) -> float:
	var words := text.split(" ", false)
	var lines: Array[String] = []
	var current := ""

	for word: String in words:
		var candidate := word if current.is_empty() else "%s %s" % [current, word]
		if font.get_string_size(candidate, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x <= max_width \
				or current.is_empty():
			current = candidate
		else:
			lines.append(current)
			current = word

	if not current.is_empty():
		lines.append(current)

	if lines.size() > max_lines:
		lines = lines.slice(0, max_lines)
		var last_line := lines[max_lines - 1]
		while not last_line.is_empty():
			var trimmed := "%s..." % last_line
			if font.get_string_size(trimmed, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x <= max_width:
				lines[max_lines - 1] = trimmed
				break
			last_line = last_line.substr(0, last_line.length() - 1).strip_edges()

	for i in lines.size():
		draw_string(font, position + Vector2(0.0, float(i) * line_height),
			lines[i], HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)

	return float(lines.size()) * line_height


func _get_trapper_guide_data() -> Array[Dictionary]:
	return TrapperCharacters.get_all()


func _get_escapist_cooldown(animal: Enums.EscapistAnimal) -> float:
	match animal:
		Enums.EscapistAnimal.RABBIT:
			return Constants.RABBIT_ABILITY_COOLDOWN
		Enums.EscapistAnimal.RAT:
			return Constants.RAT_ABILITY_COOLDOWN
		Enums.EscapistAnimal.SQUIRREL:
			return Constants.SQUIRREL_ABILITY_COOLDOWN
		Enums.EscapistAnimal.FLY:
			return Constants.FLY_ABILITY_COOLDOWN
	return 0.0


func _get_trapper_cooldown(character: Enums.TrapperCharacter, button: String) -> float:
	match character:
		Enums.TrapperCharacter.ARANA:
			match button:
				"A":
					return Constants.ARANA_VENOM_COOLDOWN
				"X":
					return Constants.ARANA_ELASTIC_COOLDOWN
				"Y":
					return Constants.ARANA_WEB_COOLDOWN
		Enums.TrapperCharacter.HONGO:
			match button:
				"A":
					return Constants.HONGO_CONFUSE_COOLDOWN
				"X":
					return Constants.HONGO_SPORE_COOLDOWN
				"Y":
					return Constants.HONGO_TELEPORT_COOLDOWN
		Enums.TrapperCharacter.ESCORPION:
			match button:
				"A":
					return Constants.ESCORPION_STINGER_COOLDOWN
				"X":
					return Constants.ESCORPION_QUICKSAND_COOLDOWN
				"Y":
					return Constants.ESCORPION_PINCERS_COOLDOWN
		Enums.TrapperCharacter.PULPO:
			match button:
				"A":
					return Constants.PULPO_INK_COOLDOWN
				"X":
					return Constants.PULPO_TENTACLE_COOLDOWN
				"Y":
					return Constants.PULPO_CURRENT_COOLDOWN
	return 0.0
