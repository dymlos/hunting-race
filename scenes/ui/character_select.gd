class_name CharacterSelect
extends Control

const SkillTestViewScene := preload("res://scenes/ui/skill_test_view.gd")

## Character selection screen. Each trapping-team player picks a unique trapper character.
## Escapist-team players wait. No duplicates allowed per team.

signal characters_ready(selections: Dictionary)  # {player_index: TrapperCharacter}
signal back_requested

var _player_indices: Array[int] = []
var _team_assignments: Dictionary = {}       # {pi: Team}
var _trapping_team: Enums.Team = Enums.Team.NONE

# Per-player selection state (trapper players only)
var _player_cursor: Dictionary = {}          # {pi: int} — index into _characters array
var _player_confirmed: Dictionary = {}       # {pi: bool}
var _nav_cooldowns: Dictionary = {}          # {pi: float}

var _characters: Array[Dictionary] = []      # TrapperCharacters.get_all()
var _allow_back: bool = true                 # false between rounds
var input_blocked: bool = false
var _preview_timers: Dictionary = {}         # {"card:button": remaining_time}
var _demo_active: bool = false
var _demo_player_index: int = -1
var _demo_card_index: int = -1
var _demo_pos: Vector2 = Vector2(0.5, 0.55)
var _demo_effects: Array[Dictionary] = []
var _demo_entities: Dictionary = {}
var _skill_test_views: Dictionary = {}       # {pi: SkillTestView}
var _skill_test_cards: Dictionary = {}       # {pi: card_index}

const NAV_COOLDOWN: float = 0.2
const PREVIEW_DURATION: float = 0.8
const DEMO_EFFECT_DURATION: float = 0.75
const GRID_COLUMNS: int = 2
const CARD_GAP: float = 22.0
const CARD_MARGIN: float = 16.0
const ABILITY_LINE_HEIGHT: float = 16.0
const ABILITY_BLOCK_HEIGHT: float = 58.0
const CARD_TOP_PAD: float = 16.0
const ABILITY_START_Y: float = 220.0


func setup(player_indices: Array[int], team_assignments: Dictionary,
		trapping_team: Enums.Team, allow_back: bool = true) -> void:
	_player_indices = player_indices.duplicate()
	_team_assignments = team_assignments.duplicate()
	_trapping_team = trapping_team
	_allow_back = allow_back
	_characters = TrapperCharacters.get_all()

	_player_cursor.clear()
	_player_confirmed.clear()
	_nav_cooldowns.clear()
	_preview_timers.clear()
	_demo_active = false
	_demo_player_index = -1
	_demo_card_index = -1
	_demo_pos = Vector2(0.5, 0.55)
	_demo_effects.clear()
	_demo_entities.clear()
	_clear_skill_tests()

	# Initialize cursors for trapper-team players
	var cursor_idx := 0
	for pi: int in _player_indices:
		if _is_trapper_player(pi):
			_player_cursor[pi] = cursor_idx % _characters.size()
			_player_confirmed[pi] = false
			_nav_cooldowns[pi] = 0.0
			cursor_idx += 1

	show()
	queue_redraw()

	# If no human trappers, assign bots and wait for START to begin.
	if _all_humans_confirmed():
		_auto_assign_bots()


func _is_trapper_player(pi: int) -> bool:
	var t: Enums.Team = _team_assignments.get(pi, Enums.Team.NONE) as Enums.Team
	return t == _trapping_team


func _is_human(pi: int) -> bool:
	return pi < 100


func _get_taken_characters() -> Array[Enums.TrapperCharacter]:
	## Returns characters already confirmed by teammates.
	var taken: Array[Enums.TrapperCharacter] = []
	for pi: int in _player_confirmed:
		if _player_confirmed.get(pi, false):
			var idx: int = _player_cursor[pi] as int
			var tc: Enums.TrapperCharacter = _characters[idx]["id"] as Enums.TrapperCharacter
			if tc not in taken:
				taken.append(tc)
	return taken


func _is_character_taken(char_index: int, by_pi: int) -> bool:
	## Is this character confirmed by someone other than by_pi?
	for pi: int in _player_confirmed:
		if pi == by_pi:
			continue
		if _player_confirmed.get(pi, false) and (_player_cursor[pi] as int) == char_index:
			return true
	return false


func _auto_assign_bots() -> void:
	for pi: int in _player_cursor:
		if pi >= 100 and not _player_confirmed.get(pi, false):
			# Pick a random available character
			var available: Array[int] = []
			for i in _characters.size():
				if not _is_character_taken(i, pi):
					available.append(i)
			if not available.is_empty():
				available.shuffle()
				_player_cursor[pi] = available[0]
				_player_confirmed[pi] = true


func _all_confirmed() -> bool:
	for pi: int in _player_confirmed:
		if not _player_confirmed.get(pi, false):
			return false
	return not _player_confirmed.is_empty()


func _selection_complete() -> bool:
	return _player_confirmed.is_empty() or _all_confirmed()


func _has_bot_trappers() -> bool:
	for pi: int in _player_cursor:
		if not _is_human(pi):
			return true
	return false


func _all_humans_confirmed() -> bool:
	for pi: int in _player_cursor:
		if _is_human(pi) and not _player_confirmed.get(pi, false):
			return false
	return true


func _any_human_confirmed() -> bool:
	for pi: int in _player_confirmed:
		if _is_human(pi) and _player_confirmed.get(pi, false):
			return true
	return false


func _build_selections() -> Dictionary:
	var selections: Dictionary = {}
	for pi: int in _player_confirmed:
		var idx: int = _player_cursor[pi] as int
		selections[pi] = _characters[idx]["id"]
	return selections


func _get_human_device_ids() -> Array[int]:
	var device_ids: Array[int] = []
	for pi: int in _player_indices:
		if not _is_human(pi):
			continue
		var device_id := InputManager.get_device_id(pi)
		if device_id >= 0 and device_id not in device_ids:
			device_ids.append(device_id)
	return device_ids


func _handle_back_for_player(pi: int) -> bool:
	if _player_confirmed.get(pi, false):
		_player_confirmed[pi] = false
		return true
	if _allow_back and not _any_human_confirmed():
		_clear_skill_tests()
		back_requested.emit()
		return true
	return false


func _move_cursor_on_grid(current_index: int, dx: int, dy: int) -> int:
	var item_count := _characters.size()
	if item_count <= 1:
		return current_index
	var columns := mini(GRID_COLUMNS, item_count)
	var rows := int(ceili(float(item_count) / float(columns)))
	var col := current_index % columns
	var row := int(floor(float(current_index) / float(columns)))
	var target := current_index
	if dx != 0:
		col = (col + dx + columns) % columns
		target = row * columns + col
	elif dy != 0:
		for _attempt in rows:
			row = (row + dy + rows) % rows
			target = row * columns + col
			if target < item_count:
				break
	if target >= item_count:
		return current_index
	return target


func _handle_grid_navigation(pi: int, device_id: int) -> void:
	if _nav_cooldowns.get(pi, 0.0) > 0.0:
		return
	var x := Input.get_joy_axis(device_id, JOY_AXIS_LEFT_X)
	var y := Input.get_joy_axis(device_id, JOY_AXIS_LEFT_Y)
	if absf(x) < 0.5 and absf(y) < 0.5:
		return
	var dx := 0
	var dy := 0
	if absf(x) >= absf(y):
		dx = 1 if x > 0.0 else -1
	else:
		dy = 1 if y > 0.0 else -1
	var current_index: int = _player_cursor[pi] as int
	var next_index := _move_cursor_on_grid(current_index, dx, dy)
	if next_index != current_index:
		_player_cursor[pi] = next_index
	_nav_cooldowns[pi] = NAV_COOLDOWN


func _process(delta: float) -> void:
	if not visible or input_blocked:
		queue_redraw()
		return

	_update_preview_timers(delta)
	_update_skill_test_layout()

	# Tick nav cooldowns
	for pi: int in _nav_cooldowns:
		_nav_cooldowns[pi] = maxf(0.0, _nav_cooldowns[pi] - delta)

	var confirmed_this_frame := false
	for pi: int in _player_cursor:
		if not _is_human(pi):
			continue

		var device_id := InputManager.get_device_id(pi)
		if device_id < 0:
			continue

		if _skill_test_views.has(pi):
			if InputManager.is_menu_back_just_pressed(device_id):
				_exit_skill_test(pi)
				queue_redraw()
				return
			continue

		if InputManager.is_button_just_pressed_on_device(device_id, JOY_BUTTON_A):
			_enter_demo(pi)
			return

		if InputManager.is_menu_back_just_pressed(device_id):
			if _handle_back_for_player(pi):
				queue_redraw()
				return

		if _player_confirmed.get(pi, false):
			continue

		# Navigate
		_handle_grid_navigation(pi, device_id)

		if InputManager.is_menu_confirm_just_pressed(device_id):
			var idx: int = _player_cursor[pi] as int
			if not _is_character_taken(idx, pi):
				_player_confirmed[pi] = true
				confirmed_this_frame = true
				if _all_humans_confirmed():
					_auto_assign_bots()

	if _selection_complete() and not confirmed_this_frame:
		for device_id: int in _get_human_device_ids():
			if InputManager.is_menu_confirm_just_pressed(device_id):
				_clear_skill_tests()
				characters_ready.emit(_build_selections())
				return

	queue_redraw()


func _update_preview_timers(delta: float) -> void:
	var expired: Array[String] = []
	for key: String in _preview_timers:
		_preview_timers[key] = maxf((_preview_timers[key] as float) - delta, 0.0)
		if (_preview_timers[key] as float) <= 0.0:
			expired.append(key)
	for key in expired:
		_preview_timers.erase(key)


func _trigger_ability_preview(player_index: int, button: String) -> void:
	if not _player_cursor.has(player_index):
		return
	var card_index: int = _player_cursor[player_index] as int
	var char_data: Dictionary = _characters[card_index]
	var abilities: Array = char_data["abilities"] as Array
	for ability: Dictionary in abilities:
		if (ability["button"] as String) == button:
			_preview_timers["%d:%s" % [card_index, button]] = PREVIEW_DURATION
			InputManager.vibrate_player(player_index, 0.08, 0.18, 0.08)
			queue_redraw()
			return


func _enter_demo(player_index: int) -> void:
	if not _player_cursor.has(player_index):
		return
	_exit_skill_test(player_index)
	var card_index: int = _player_cursor[player_index] as int
	var char_data: Dictionary = _characters[card_index]
	var view := SkillTestViewScene.new()
	add_child(view)
	view.call("setup_trapper", player_index, char_data["id"] as Enums.TrapperCharacter)
	_skill_test_views[player_index] = view
	_skill_test_cards[player_index] = card_index
	_update_skill_test_layout()
	InputManager.vibrate_player(player_index, 0.06, 0.14, 0.08)
	queue_redraw()


func _exit_demo() -> void:
	if _demo_player_index >= 0:
		_exit_skill_test(_demo_player_index)


func _exit_skill_test(player_index: int) -> void:
	var view := _skill_test_views.get(player_index, null) as Node
	if view != null and is_instance_valid(view):
		view.queue_free()
	_skill_test_views.erase(player_index)
	_skill_test_cards.erase(player_index)
	InputManager.suppress_edge_detection(2)
	queue_redraw()


func _clear_skill_tests() -> void:
	for pi: int in _skill_test_views:
		var view := _skill_test_views[pi] as Node
		if view != null and is_instance_valid(view):
			view.queue_free()
	_skill_test_views.clear()
	_skill_test_cards.clear()


func _is_card_testing(card_index: int) -> bool:
	for pi: int in _skill_test_cards:
		if (_skill_test_cards[pi] as int) == card_index:
			return true
	return false


func _update_skill_test_layout() -> void:
	if _skill_test_views.is_empty() or _characters.is_empty():
		return
	var screen := get_viewport_rect().size
	var cx := screen.x / 2.0
	var card_count := _characters.size()
	var columns := 2
	var rows := int(ceili(float(card_count) / float(columns)))
	var row_gap := 22.0
	var available_w := maxf(760.0, screen.x - 260.0)
	var card_w := clampf((available_w - float(columns - 1) * CARD_GAP) / float(columns), 360.0, 700.0)
	var card_h := clampf((screen.y - 248.0 - float(rows - 1) * row_gap) / float(rows), 256.0, 410.0)
	var total_w := float(columns) * card_w + float(columns - 1) * CARD_GAP
	var cards_x := cx - total_w / 2.0
	var cards_y := 128.0
	for pi: int in _skill_test_views:
		var view := _skill_test_views[pi] as Node
		if view == null or not is_instance_valid(view):
			continue
		var card_index := _skill_test_cards.get(pi, -1) as int
		if card_index < 0:
			continue
		var col := card_index % columns
		var row := int(floor(float(card_index) / float(columns)))
		var card_x := cards_x + float(col) * (card_w + CARD_GAP)
		var card_y := cards_y + float(row) * (card_h + row_gap)
		var art_h := clampf(card_h * 0.48, 130.0, 205.0)
		var art_rect := Rect2(card_x + CARD_MARGIN, card_y + 62.0, card_w - CARD_MARGIN * 2.0, art_h)
		view.call("set_view_rect", art_rect)


func _process_demo(delta: float) -> void:
	var device_id := InputManager.get_device_id(_demo_player_index)
	if device_id < 0:
		_exit_demo()
		return
	if InputManager.is_menu_back_just_pressed(device_id):
		_exit_demo()
		return
	var move_vec := InputManager.get_move_vector(_demo_player_index)
	_demo_pos += move_vec * delta * 0.62
	_demo_pos.x = clampf(_demo_pos.x, 0.10, 0.90)
	_demo_pos.y = clampf(_demo_pos.y, 0.18, 0.86)
	for button in ["A", "X", "Y"]:
		var joy_button := JOY_BUTTON_A if button == "A" else (JOY_BUTTON_X if button == "X" else JOY_BUTTON_Y)
		if InputManager.is_button_just_pressed_on_device(device_id, joy_button):
			_trigger_demo_ability(button)
	_update_demo_effects(delta)
	_update_trapper_demo_entities(delta)


func _trigger_demo_ability(button: String) -> void:
	if _demo_card_index < 0 or _demo_card_index >= _characters.size():
		return
	var char_data: Dictionary = _characters[_demo_card_index] as Dictionary
	var abilities: Array = char_data["abilities"] as Array
	for ability: Dictionary in abilities:
		if (ability["button"] as String) == button:
			_demo_effects.append({
				"button": button,
				"time": 0.0,
				"duration": DEMO_EFFECT_DURATION,
				"origin": _demo_pos,
			})
			_apply_trapper_demo_ability(char_data["id"] as Enums.TrapperCharacter, button)
			InputManager.vibrate_player(_demo_player_index, 0.08, 0.22, 0.1)
			return


func _update_demo_effects(delta: float) -> void:
	var keep: Array[Dictionary] = []
	for effect: Dictionary in _demo_effects:
		effect["time"] = (effect["time"] as float) + delta
		if (effect["time"] as float) < (effect["duration"] as float):
			keep.append(effect)
	_demo_effects = keep


func _reset_trapper_demo_state(_char_id: Enums.TrapperCharacter) -> void:
	_demo_entities = {
		"opponent": Vector2(0.78, 0.64),
		"opponent_velocity": Vector2(-0.18, 0.0),
		"status": "",
		"status_timer": 0.0,
		"root_timer": 0.0,
		"placed_a": Vector2(-1.0, -1.0),
		"placed_x": Vector2(-1.0, -1.0),
		"placed_y": Vector2(-1.0, -1.0),
	}


func _update_trapper_demo_entities(delta: float) -> void:
	if _demo_entities.is_empty():
		return
	var root_timer := maxf((_demo_entities.get("root_timer", 0.0) as float) - delta, 0.0)
	_demo_entities["root_timer"] = root_timer
	var status_timer := maxf((_demo_entities.get("status_timer", 0.0) as float) - delta, 0.0)
	_demo_entities["status_timer"] = status_timer
	if status_timer <= 0.0:
		_demo_entities["status"] = ""
	var opponent := _demo_entities["opponent"] as Vector2
	var velocity := _demo_entities["opponent_velocity"] as Vector2
	if root_timer <= 0.0:
		var speed_scale := 0.35 if status_timer > 0.0 else 1.0
		opponent += velocity * delta * speed_scale
		if opponent.x < 0.18 or opponent.x > 0.86:
			velocity.x *= -1.0
			opponent.x = clampf(opponent.x, 0.18, 0.86)
	_demo_entities["opponent"] = opponent
	_demo_entities["opponent_velocity"] = velocity


func _apply_trapper_demo_ability(char_id: Enums.TrapperCharacter, button: String) -> void:
	if _demo_entities.is_empty():
		return
	_demo_entities["placed_%s" % button.to_lower()] = _demo_pos
	var opponent := _demo_entities["opponent"] as Vector2
	var distance := opponent.distance_to(_demo_pos)
	match char_id:
		Enums.TrapperCharacter.ARANA:
			if button == "A" and distance < 0.34:
				_set_trapper_demo_status("POISON", 1.8)
			elif button == "X":
				_demo_entities["opponent"] = opponent.move_toward(Vector2(0.20, opponent.y), 0.22)
				_set_trapper_demo_status("BOUNCE", 0.9)
			elif button == "Y" and distance < 0.42:
				_set_trapper_demo_status("SLOWED", 1.6)
		Enums.TrapperCharacter.HONGO:
			if button == "A" and distance < 0.35:
				var velocity := _demo_entities["opponent_velocity"] as Vector2
				_demo_entities["opponent_velocity"] = -velocity
				_set_trapper_demo_status("CONFUSED", 1.5)
			elif button == "X" and distance < 0.42:
				_set_trapper_demo_status("SPORES", 1.7)
			elif button == "Y":
				_demo_entities["opponent"] = Vector2(0.22, 0.34)
				_set_trapper_demo_status("PORTAL", 0.9)
		Enums.TrapperCharacter.ESCORPION:
			if button == "A" and distance < 0.26:
				_set_trapper_demo_status("STUNG", 1.4)
			elif button == "X":
				_demo_entities["opponent"] = opponent.move_toward(_demo_pos, 0.20)
				_set_trapper_demo_status("PULLED", 1.2)
			elif button == "Y":
				_demo_entities["root_timer"] = 0.8
				_set_trapper_demo_status("CRUSH", 0.9)
		Enums.TrapperCharacter.PULPO:
			if button == "A" and distance < 0.38:
				_set_trapper_demo_status("BLINDED", 1.6)
			elif button == "X" and distance < 0.38:
				_demo_entities["root_timer"] = 1.5
				_set_trapper_demo_status("ROOTED", 1.5)
			elif button == "Y":
				_demo_entities["opponent"] = opponent.move_toward(Vector2(0.88, opponent.y), 0.24)
				_set_trapper_demo_status("PUSHED", 1.1)


func _set_trapper_demo_status(text: String, duration: float) -> void:
	_demo_entities["status"] = text
	_demo_entities["status_timer"] = duration

func _draw_wrapped_text(font: Font, text: String, position: Vector2,
		max_width: float, font_size: int, color: Color, line_height: float,
		max_lines: int) -> float:
	var words := text.split(" ", false)
	var lines: Array[String] = []
	var current := ""

	for word: String in words:
		var candidate := word if current.is_empty() else "%s %s" % [current, word]
		var candidate_width := font.get_string_size(candidate,
			HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
		if candidate_width <= max_width or current.is_empty():
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
			var trimmed_width := font.get_string_size(trimmed,
				HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
			if trimmed_width <= max_width:
				lines[max_lines - 1] = trimmed
				break
			last_line = last_line.substr(0, last_line.length() - 1).strip_edges()

	for i in lines.size():
		draw_string(font, position + Vector2(0, i * line_height),
			lines[i], HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)

	return lines.size() * line_height


func _draw() -> void:
	var screen := get_viewport_rect().size
	var cx := screen.x / 2.0
	var font := ThemeDB.fallback_font

	# Background
	draw_rect(Rect2(Vector2.ZERO, screen), Color(0.015, 0.015, 0.018, 1.0))
	draw_rect(Rect2(Vector2.ZERO, Vector2(screen.x, 430.0)), Color(0.06, 0.035, 0.045, 0.18))

	# Title
	var title := "CHOOSE YOUR TRAPPER"
	_draw_centered_text_in_rect(font, title, Rect2(cx - 260.0, 34.0, 520.0, 38.0), 30, Color.WHITE)

	# Trapping team label
	var team_name := Enums.team_name(_trapping_team)
	var team_col := Enums.team_color(_trapping_team)
	var sub := "%s picks trappers" % team_name
	_draw_centered_text_in_rect(font, sub, Rect2(cx - 260.0, 72.0, 520.0, 24.0), 16, team_col)
	_draw_centered_text_in_rect(font, "Trappers use A, X and Y in-match. START confirms menus and SELECT cancels or goes back.",
		Rect2(cx - 520.0, 96.0, 1040.0, 18.0), 13, Color(0.62, 0.64, 0.66))

	# Character cards — 4 cards in a row
	var card_count := _characters.size()
	var columns := 2
	var rows := int(ceili(float(card_count) / float(columns)))
	var card_gap := CARD_GAP
	var row_gap := 22.0
	var available_w := maxf(760.0, screen.x - 260.0)
	var card_w := clampf((available_w - float(columns - 1) * card_gap) / float(columns), 360.0, 700.0)
	var card_h := clampf((screen.y - 248.0 - float(rows - 1) * row_gap) / float(rows), 256.0, 410.0)
	var total_w := float(columns) * card_w + float(columns - 1) * card_gap
	var cards_x := cx - total_w / 2.0
	var cards_y := 128.0

	for i in card_count:
		var col := i % columns
		var row := int(floor(float(i) / float(columns)))
		var card_x := cards_x + float(col) * (card_w + card_gap)
		var card_y := cards_y + float(row) * (card_h + row_gap)
		var card_rect := Rect2(Vector2(card_x, card_y), Vector2(card_w, card_h))
		var char_data: Dictionary = _characters[i]
		var char_color: Color = char_data["color"] as Color
		var char_name: String = char_data["name"] as String
		var char_sub: String = char_data["subtitle"] as String
		var char_id: Enums.TrapperCharacter = char_data["id"] as Enums.TrapperCharacter
		var abilities: Array = char_data["abilities"] as Array

		# Check if anyone is hovering or confirmed on this card
		var is_taken := false
		var hovering_pis: Array[int] = []
		var confirmed_pi: int = -1
		for pi: int in _player_cursor:
			if (_player_cursor[pi] as int) == i:
				if _player_confirmed.get(pi, false):
					confirmed_pi = pi
					is_taken = true
				else:
					hovering_pis.append(pi)

		# Card background
		var bg_color := Color(0.11, 0.11, 0.12)
		if confirmed_pi >= 0:
			bg_color = Color(char_color, 0.18)

		# Card border
		var border_color := Color(0.3, 0.3, 0.3)
		if confirmed_pi >= 0:
			border_color = char_color
		elif not hovering_pis.is_empty():
			border_color = Color(char_color, 0.82)
		_draw_panel(card_rect, bg_color, border_color, 2.0)
		draw_rect(Rect2(card_rect.position, Vector2(card_rect.size.x, 5.0)), Color(char_color, 0.95))

		var art_h := clampf(card_h * 0.48, 130.0, 205.0)
		var art_rect := Rect2(card_x + CARD_MARGIN, card_y + 62.0, card_w - CARD_MARGIN * 2.0, art_h)
		draw_rect(art_rect, Color(char_color, 0.10))
		draw_rect(art_rect, Color(char_color, 0.25), false, 1.0)
		var demo_running := _is_card_testing(i)
		if demo_running:
			_draw_centered_text_in_rect(font, "REAL SKILL TEST",
				art_rect, 12, Color(char_color, 0.9))
		else:
			var silhouette_scale := 3.0
			var silhouette_offset := Vector2(0.0, -2.0)
			if char_id == Enums.TrapperCharacter.ESCORPION:
				silhouette_scale = 2.15
				silhouette_offset = Vector2(0.0, 6.0)
			_draw_trapper_silhouette(char_id, art_rect.position + art_rect.size * 0.5 + silhouette_offset,
				silhouette_scale, Color(char_color, 1.0))

		# Character name
		_draw_centered_text_in_rect(font, char_name, Rect2(card_x, card_y + CARD_TOP_PAD, card_w, 28.0), 24, char_color)

		# Subtitle
		var sub_y := card_y + 44.0
		var sub_max_w := card_w - CARD_MARGIN * 2.0
		var subtitle_width := font.get_string_size(char_sub, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x
		if subtitle_width <= sub_max_w:
			_draw_centered_text_in_rect(font, char_sub, Rect2(card_x, sub_y, card_w, 18.0), 13, Color(0.64, 0.64, 0.66))
		else:
			_draw_wrapped_text(font, char_sub, Vector2(card_x + CARD_MARGIN, sub_y + 10.0),
				sub_max_w, 13, Color(0.6, 0.6, 0.6), 15.0, 2)

		# Abilities list
		var ability_y := art_rect.end.y + 30.0
		var ability_gap := 12.0
		var ability_col_w := (card_w - CARD_MARGIN * 2.0 - ability_gap * 2.0) / 3.0
		for a_i in abilities.size():
			var ability: Dictionary = abilities[a_i] as Dictionary
			var a_name: String = ability["name"] as String
			var a_btn: String = ability["button"] as String
			var a_text := "[%s] %s" % [a_btn, a_name]
			var text_x := card_x + CARD_MARGIN + float(a_i) * (ability_col_w + ability_gap)
			var text_w := ability_col_w
			var block_y := ability_y
			draw_string(font, Vector2(text_x, block_y),
				a_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0.86, 0.86, 0.86))
			var a_desc: String = ability["desc"] as String
			_draw_wrapped_text(font, a_desc, Vector2(text_x, block_y + 20),
				text_w, 11, Color(0.62, 0.62, 0.62), 14.0, 3)

		# TAKEN label
		if is_taken:
			var taken_label := "P%d" % (confirmed_pi + 1) if confirmed_pi < 100 else "BOT"
			var taken_text := "%s ✓" % taken_label
			var tw := font.get_string_size(taken_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x
			draw_string(font, Vector2(card_x + card_w / 2.0 - tw / 2.0, card_y + card_h - 15),
				taken_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, char_color)

		# Hovering player indicators
		if not hovering_pis.is_empty() and not is_taken:
			var hover_text := ""
			for h_i in hovering_pis.size():
				if h_i > 0:
					hover_text += " "
				var pi: int = hovering_pis[h_i]
				hover_text += "P%d" % (pi + 1) if pi < 100 else "BOT"
			var hw := font.get_string_size(hover_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x
			draw_string(font, Vector2(card_x + card_w / 2.0 - hw / 2.0, card_y + card_h - 15),
				hover_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.8, 0.8, 0.8))

	# Escapist team players
	var escapist_pis: Array[int] = []
	for pi: int in _player_indices:
		if not _is_trapper_player(pi):
			escapist_pis.append(pi)

	if not escapist_pis.is_empty():
		var grid_bottom := cards_y + float(rows) * card_h + float(rows - 1) * row_gap
		var esc_y := minf(grid_bottom + 24.0, screen.y - 84.0)
		var esc_labels: Array[String] = []
		for pi: int in escapist_pis:
			var label := "P%d" % (pi + 1) if pi < 100 else "BOT"
			esc_labels.append(label)
		var esc_text := "Escapists: %s" % ", ".join(esc_labels)
		var esc_team: Enums.Team = Enums.Team.TEAM_1 if _trapping_team == Enums.Team.TEAM_2 else Enums.Team.TEAM_2
		var wait_rect := Rect2(cx - 230.0, esc_y - 18.0, 460.0, 30.0)
		_draw_panel(wait_rect, Color(0.04, 0.04, 0.045, 0.9), Color(Enums.team_color(esc_team), 0.45), 1.5)
		_draw_centered_text_in_rect(font, esc_text, wait_rect, 14, Enums.team_color(esc_team))

	# Status line
	var status_y := screen.y - 70
	for pi: int in _player_cursor:
		if not _is_human(pi):
			continue
		var idx: int = _player_cursor[pi] as int
		var char_data2: Dictionary = _characters[idx]
		var cname: String = char_data2["name"] as String
		var confirmed: bool = _player_confirmed.get(pi, false)
		var label := "P%d: %s %s" % [pi + 1, cname, "✓" if confirmed else "..."]
		var lw := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x
		draw_string(font, Vector2(cx - lw / 2.0, status_y),
			label, HORIZONTAL_ALIGNMENT_LEFT, -1, 14,
			Color.YELLOW if confirmed else Color(0.6, 0.6, 0.6))
		status_y += 20

	# Hints
	var hint := "A demo | Left stick move | START confirm | SELECT cancel"
	if _allow_back:
		hint = "A demo | Left stick move | START confirm | SELECT back or cancel"
	if _selection_complete():
		hint = "START to begin | SELECT back or change" if _allow_back else "START to begin | SELECT to change"
	var hint_width := font.get_string_size(hint, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x
	draw_string(font, Vector2(cx - hint_width / 2.0, screen.y - 30),
		hint, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color.YELLOW)


func _draw_panel(rect: Rect2, fill: Color, outline: Color, outline_width: float = 2.0) -> void:
	draw_rect(rect, fill)
	draw_rect(rect, outline, false, outline_width)


func _draw_trapper_demo(font: Font, rect: Rect2,
		char_id: Enums.TrapperCharacter, color: Color) -> void:
	draw_rect(rect, Color(0.02, 0.025, 0.03, 0.96))
	draw_rect(rect, Color(color, 0.55), false, 1.5)
	var obstacle := Rect2(rect.position + Vector2(rect.size.x * 0.62, rect.size.y * 0.34),
		Vector2(rect.size.x * 0.18, rect.size.y * 0.20))
	draw_rect(obstacle, Color(0.62, 0.62, 0.62, 0.85))
	draw_rect(obstacle, Color(0.86, 0.86, 0.86, 0.55), false, 1.0)
	var opponent_norm := _demo_entities.get("opponent", Vector2(0.78, 0.64)) as Vector2
	var target := rect.position + Vector2(opponent_norm.x * rect.size.x, opponent_norm.y * rect.size.y)
	draw_circle(target, 8.0, Color(1.0, 0.25, 0.18, 0.82))
	draw_string(font, target + Vector2(-10.0, -12.0), "RUN", HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(1.0, 0.60, 0.50))
	var player := rect.position + Vector2(_demo_pos.x * rect.size.x, _demo_pos.y * rect.size.y)
	for effect: Dictionary in _demo_effects:
		var button := effect["button"] as String
		var t := clampf((effect["time"] as float) / (effect["duration"] as float), 0.0, 1.0)
		_draw_trapper_demo_effect(rect, player, target, char_id, button, color, t)
	for button in ["A", "X", "Y"]:
		var key := "placed_%s" % (button as String).to_lower()
		var placed := _demo_entities.get(key, Vector2(-1.0, -1.0)) as Vector2
		if placed.x >= 0.0:
			var p := rect.position + Vector2(placed.x * rect.size.x, placed.y * rect.size.y)
			draw_arc(p, 8.0, 0.0, TAU, 16, Color(color, 0.54), 1.4)
			draw_string(font, p + Vector2(-4.0, 3.0), button, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color.WHITE)
	draw_circle(player, 10.0, Color(color, 0.95))
	draw_line(player + Vector2(-13.0, 0.0), player + Vector2(13.0, 0.0), Color.WHITE, 1.6)
	draw_line(player + Vector2(0.0, -13.0), player + Vector2(0.0, 13.0), Color.WHITE, 1.6)
	var status := _demo_entities.get("status", "") as String
	if not status.is_empty():
		_draw_centered_text_in_rect(font, status,
			Rect2(rect.position.x, rect.position.y + 8.0, rect.size.x, 18.0), 11, Color.YELLOW)
	draw_string(font, rect.position + Vector2(9.0, rect.size.y - 9.0),
		"SELECT exit | A/X/Y test", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(color, 0.9))


func _draw_trapper_demo_effect(rect: Rect2, player: Vector2, target: Vector2,
		char_id: Enums.TrapperCharacter, button: String, color: Color, t: float) -> void:
	var fade := 1.0 - t
	match char_id:
		Enums.TrapperCharacter.ARANA:
			if button == "A":
				draw_circle(player, 12.0 + 28.0 * t, Color(0.16, 0.9, 0.34, 0.28 * fade))
			elif button == "X":
				draw_line(player, target, Color(color, 0.85 * fade), 3.0)
				draw_circle(target, 7.0 + 9.0 * t, Color(color, 0.45 * fade))
			else:
				for offset in [-18.0, 0.0, 18.0]:
					draw_line(Vector2(rect.position.x + 14.0, player.y + offset),
						Vector2(rect.end.x - 14.0, player.y - offset), Color(color, 0.58 * fade), 2.0)
		Enums.TrapperCharacter.HONGO:
			if button == "A":
				draw_circle(player, 16.0, Color(color, 0.8))
				draw_arc(player, 24.0 + 20.0 * t, 0.0, TAU, 24, Color(color, 0.55 * fade), 3.0)
			elif button == "X":
				draw_circle(target, 18.0 + 26.0 * t, Color(color, 0.25 * fade))
			else:
				draw_circle(player, 10.0, Color(color, 0.8))
				draw_circle(target, 10.0, Color(color, 0.8))
				draw_line(player, target, Color(color, 0.42 * fade), 2.0)
		Enums.TrapperCharacter.ESCORPION:
			if button == "A":
				var tip := player + Vector2(0.0, lerpf(20.0, -20.0, t))
				draw_colored_polygon(PackedVector2Array([tip, tip + Vector2(-9.0, 22.0), tip + Vector2(9.0, 22.0)]),
					Color(color, 0.85 * fade))
			elif button == "X":
				draw_circle(target, 18.0 + 18.0 * t, Color(0.9, 0.72, 0.22, 0.35 * fade))
				draw_arc(target, 26.0, 0.0, TAU, 24, Color(0.9, 0.72, 0.22, 0.8 * fade), 3.0)
			else:
				var left := player.x - lerpf(48.0, 12.0, t)
				var right := player.x + lerpf(48.0, 12.0, t)
				draw_line(Vector2(left, rect.position.y + 12.0), Vector2(left, rect.end.y - 12.0), Color(color, 0.9), 5.0)
				draw_line(Vector2(right, rect.position.y + 12.0), Vector2(right, rect.end.y - 12.0), Color(color, 0.9), 5.0)
		Enums.TrapperCharacter.PULPO:
			if button == "A":
				draw_circle(player, 18.0 + 22.0 * t, Color(0.04, 0.04, 0.06, 0.55 * fade))
			elif button == "X":
				draw_line(player, target, Color(color, 0.8 * fade), 4.0)
				draw_circle(target, 10.0, Color(color, 0.45 * fade))
			else:
				var wave_y := player.y + sin(t * TAU) * 12.0
				draw_line(Vector2(rect.position.x + 12.0, wave_y), Vector2(rect.end.x - 12.0, wave_y),
					Color(color, 0.75 * fade), 4.0)


func _draw_active_trapper_preview(font: Font, rect: Rect2, card_index: int,
		char_id: Enums.TrapperCharacter, color: Color) -> void:
	var active_button := ""
	var remaining := 0.0
	for button in ["A", "X", "Y"]:
		var key := "%d:%s" % [card_index, button]
		if _preview_timers.has(key) and (_preview_timers[key] as float) > remaining:
			active_button = button
			remaining = _preview_timers[key] as float
	if active_button.is_empty():
		return

	var t := 1.0 - clampf(remaining / PREVIEW_DURATION, 0.0, 1.0)
	var center := rect.position + rect.size * 0.5
	draw_rect(rect, Color(color, 0.14))
	match char_id:
		Enums.TrapperCharacter.ARANA:
			_draw_spider_preview(center, rect, active_button, color, t)
		Enums.TrapperCharacter.HONGO:
			_draw_mushroom_preview(center, rect, active_button, color, t)
		Enums.TrapperCharacter.ESCORPION:
			_draw_scorpion_preview(center, rect, active_button, color, t)
		Enums.TrapperCharacter.PULPO:
			_draw_octopus_preview(center, rect, active_button, color, t)
	draw_string(font, rect.position + Vector2(10.0, rect.size.y - 10.0),
		"Preview [%s]" % active_button, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(color, 0.92))


func _draw_spider_preview(center: Vector2, rect: Rect2, button: String, color: Color, t: float) -> void:
	if button == "A":
		draw_circle(center, 16.0 + 34.0 * t, Color(0.15, 0.95, 0.35, 0.22 * (1.0 - t)))
	elif button == "X":
		var y := lerpf(rect.position.y + 20.0, rect.end.y - 20.0, t)
		for offset in [-12.0, 0.0, 12.0]:
			draw_line(Vector2(rect.position.x + 18.0, y + offset), Vector2(rect.end.x - 18.0, y - offset),
				Color(color, 0.72), 2.0)
	else:
		draw_arc(center, 26.0 + 26.0 * t, 0.0, TAU, 28, Color(color, 0.9 * (1.0 - t)), 3.0)


func _draw_mushroom_preview(center: Vector2, rect: Rect2, button: String, color: Color, t: float) -> void:
	if button == "A":
		draw_circle(center + Vector2(0.0, 8.0), 10.0 + 24.0 * t, Color(color, 0.3 * (1.0 - t)))
		draw_circle(center + Vector2(0.0, -8.0), 18.0, Color(color, 0.8))
	elif button == "X":
		for i in 5:
			var angle := TAU * float(i) / 5.0 + t * PI
			draw_circle(center + Vector2(cos(angle), sin(angle)) * (18.0 + 22.0 * t),
				7.0, Color(color, 0.42 * (1.0 - t)))
	else:
		draw_arc(center, 38.0, 0.0, TAU * t, 24, Color(color, 0.85), 3.0)
		draw_line(center + Vector2(-42.0, 0.0), center + Vector2(42.0, 0.0), Color(color, 0.42), 2.0)


func _draw_scorpion_preview(center: Vector2, rect: Rect2, button: String, color: Color, t: float) -> void:
	if button == "A":
		var tip := center + Vector2(0.0, lerpf(28.0, -28.0, t))
		draw_colored_polygon(PackedVector2Array([
			tip,
			tip + Vector2(-10.0, 28.0),
			tip + Vector2(10.0, 28.0),
		]), Color(color, 0.84))
	elif button == "X":
		draw_arc(center, 12.0 + 34.0 * t, 0.0, TAU, 28, Color(0.9, 0.72, 0.22, 0.5 * (1.0 - t)), 4.0)
	else:
		var left := rect.position.x + lerpf(20.0, rect.size.x * 0.42, t)
		var right := rect.end.x - lerpf(20.0, rect.size.x * 0.42, t)
		draw_line(Vector2(left, rect.position.y + 18.0), Vector2(left, rect.end.y - 18.0), Color(color, 0.9), 5.0)
		draw_line(Vector2(right, rect.position.y + 18.0), Vector2(right, rect.end.y - 18.0), Color(color, 0.9), 5.0)


func _draw_octopus_preview(center: Vector2, rect: Rect2, button: String, color: Color, t: float) -> void:
	if button == "A":
		for i in 6:
			var angle := TAU * float(i) / 6.0
			draw_circle(center + Vector2(cos(angle), sin(angle)) * (10.0 + 34.0 * t),
				8.0, Color(color, 0.34 * (1.0 - t)))
	elif button == "X":
		var wave_y := center.y + sin(t * TAU) * 16.0
		draw_line(Vector2(rect.position.x + 20.0, wave_y), Vector2(rect.end.x - 20.0, center.y),
			Color(color, 0.82), 4.0)
	else:
		draw_circle(center + Vector2(lerpf(-34.0, 34.0, t), 0.0), 12.0, Color(color, 0.8))
		draw_circle(center + Vector2(lerpf(34.0, -34.0, t), 0.0), 12.0, Color(1.0, 1.0, 1.0, 0.55))


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


func _scaled_points(center: Vector2, scale: float, points: Array) -> PackedVector2Array:
	var result := PackedVector2Array()
	for point in points:
		result.append(center + (point as Vector2) * scale)
	return result


func _draw_filled_ellipse(center: Vector2, radii: Vector2, fill_color: Color, point_count: int = 24) -> void:
	var points := PackedVector2Array()
	for i in range(point_count):
		var angle := TAU * float(i) / float(point_count)
		points.append(center + Vector2(cos(angle) * radii.x, sin(angle) * radii.y))
	draw_colored_polygon(points, fill_color)


func _draw_trapper_silhouette(character: Enums.TrapperCharacter, center: Vector2, scale: float, color: Color) -> void:
	match character:
		Enums.TrapperCharacter.ARANA:
			_draw_spider_silhouette(center, scale, color)
		Enums.TrapperCharacter.HONGO:
			_draw_mushroom_silhouette(center, scale, color)
		Enums.TrapperCharacter.ESCORPION:
			_draw_scorpion_silhouette(center, scale, color)
		Enums.TrapperCharacter.PULPO:
			_draw_octopus_silhouette(center, scale, color)


func _draw_spider_silhouette(center: Vector2, scale: float, color: Color) -> void:
	_draw_filled_ellipse(center + Vector2(0.0, 2.0) * scale, Vector2(7.2, 8.6) * scale, color)
	_draw_filled_ellipse(center + Vector2(0.0, -7.0) * scale, Vector2(4.6, 4.2) * scale, color)
	for side in [-1.0, 1.0]:
		draw_polyline(_scaled_points(center, scale, [
			Vector2(side * 3.0, -2.0),
			Vector2(side * 9.5, 4.0),
			Vector2(side * 15.0, 1.0),
		]), color, 2.2 * scale)
		draw_polyline(_scaled_points(center, scale, [
			Vector2(side * 2.0, 2.5),
			Vector2(side * 8.0, 10.0),
			Vector2(side * 13.0, 9.0),
		]), color, 2.2 * scale)
		draw_polyline(_scaled_points(center, scale, [
			Vector2(side * 4.0, -5.0),
			Vector2(side * 10.0, -10.0),
			Vector2(side * 14.0, -6.0),
		]), color, 2.2 * scale)


func _draw_mushroom_silhouette(center: Vector2, scale: float, color: Color) -> void:
	draw_colored_polygon(_scaled_points(center, scale, [
		Vector2(-15.0, -3.0),
		Vector2(-12.0, -10.0),
		Vector2(-5.0, -14.0),
		Vector2(5.0, -14.0),
		Vector2(12.0, -10.0),
		Vector2(15.0, -3.0),
		Vector2(8.0, 1.5),
		Vector2(-8.0, 1.5),
	]), color)
	_draw_filled_ellipse(center + Vector2(0.0, 8.0) * scale, Vector2(6.0, 8.0) * scale, color)
	draw_circle(center + Vector2(-5.5, -7.0) * scale, 1.7 * scale, Color(1.0, 1.0, 1.0, 0.36))
	draw_circle(center + Vector2(4.5, -9.0) * scale, 1.5 * scale, Color(1.0, 1.0, 1.0, 0.36))


func _draw_scorpion_silhouette(center: Vector2, scale: float, color: Color) -> void:
	_draw_filled_ellipse(center + Vector2(0.0, 2.0) * scale, Vector2(9.0, 6.0) * scale, color)
	_draw_filled_ellipse(center + Vector2(-8.0, 2.0) * scale, Vector2(6.0, 4.8) * scale, color)
	_draw_filled_ellipse(center + Vector2(8.0, 2.0) * scale, Vector2(6.0, 4.8) * scale, color)

	for side in [-1.0, 1.0]:
		draw_polyline(_scaled_points(center, scale, [
			Vector2(side * 5.0, 2.0),
			Vector2(side * 15.0, 8.0),
			Vector2(side * 20.0, 4.0),
		]), color, 2.4 * scale)
		draw_polyline(_scaled_points(center, scale, [
			Vector2(side * 4.0, 6.0),
			Vector2(side * 13.0, 14.0),
			Vector2(side * 19.0, 12.0),
		]), color, 2.0 * scale)
		draw_polyline(_scaled_points(center, scale, [
			Vector2(side * 11.0, -1.0),
			Vector2(side * 22.0, -8.0),
		]), color, 2.8 * scale)
		draw_colored_polygon(_scaled_points(center, scale, [
			Vector2(side * 22.0, -8.0),
			Vector2(side * 28.0, -13.0),
			Vector2(side * 27.0, -5.0),
			Vector2(side * 20.0, -3.0),
		]), color)

	draw_polyline(_scaled_points(center, scale, [
		Vector2(8.0, -3.0),
		Vector2(12.0, -12.0),
		Vector2(4.0, -19.0),
		Vector2(-5.0, -17.0),
	]), color, 3.2 * scale)
	draw_colored_polygon(_scaled_points(center, scale, [
		Vector2(-5.0, -17.0),
		Vector2(-11.0, -23.0),
		Vector2(-2.0, -24.0),
	]), color)


func _draw_octopus_silhouette(center: Vector2, scale: float, color: Color) -> void:
	_draw_filled_ellipse(center + Vector2(0.0, -3.0) * scale, Vector2(10.0, 9.0) * scale, color)
	for x in [-9.0, -4.0, 4.0, 9.0]:
		var side := -1.0 if x < 0.0 else 1.0
		draw_polyline(_scaled_points(center, scale, [
			Vector2(x * 0.45, 4.0),
			Vector2(x, 12.0),
			Vector2(x + side * 3.0, 16.0),
		]), color, 2.0 * scale)
	draw_circle(center + Vector2(-3.5, -5.0) * scale, 1.1 * scale, Color(0.01, 0.01, 0.01, color.a))
	draw_circle(center + Vector2(3.5, -5.0) * scale, 1.1 * scale, Color(0.01, 0.01, 0.01, color.a))
