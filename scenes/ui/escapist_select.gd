class_name EscapistSelect
extends Control

signal escapists_ready(selections: Dictionary)
signal back_requested

var _player_indices: Array[int] = []
var _team_assignments: Dictionary = {}
var _escapist_team: Enums.Team = Enums.Team.NONE
var _player_cursor: Dictionary = {}
var _player_confirmed: Dictionary = {}
var _nav_cooldowns: Dictionary = {}
var _animals: Array[Dictionary] = []
var _allow_back: bool = true
var input_blocked: bool = false

const NAV_COOLDOWN: float = 0.2
const CARD_GAP: float = 18.0
const CARD_MARGIN: float = 12.0


func setup(player_indices: Array[int], team_assignments: Dictionary,
		escapist_team: Enums.Team, allow_back: bool = true) -> void:
	_player_indices = player_indices.duplicate()
	_team_assignments = team_assignments.duplicate()
	_escapist_team = escapist_team
	_allow_back = allow_back
	_animals = EscapistAnimals.get_all()

	_player_cursor.clear()
	_player_confirmed.clear()
	_nav_cooldowns.clear()

	var cursor_idx := 0
	for pi: int in _player_indices:
		if _is_escapist_player(pi):
			_player_cursor[pi] = cursor_idx % _animals.size()
			_player_confirmed[pi] = false
			_nav_cooldowns[pi] = 0.0
			cursor_idx += 1

	show()
	queue_redraw()

	if _all_humans_confirmed():
		_auto_assign_bots()


func _is_escapist_player(pi: int) -> bool:
	var team: Enums.Team = _team_assignments.get(pi, Enums.Team.NONE) as Enums.Team
	return team == _escapist_team


func _is_human(pi: int) -> bool:
	return pi < 100


func _is_animal_taken(animal_index: int, by_pi: int) -> bool:
	for pi: int in _player_confirmed:
		if pi == by_pi:
			continue
		if _player_confirmed.get(pi, false) and (_player_cursor[pi] as int) == animal_index:
			return true
	return false


func _auto_assign_bots() -> void:
	for pi: int in _player_cursor:
		if pi >= 100 and not _player_confirmed.get(pi, false):
			var available: Array[int] = []
			for i in _animals.size():
				if not _is_animal_taken(i, pi):
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
		selections[pi] = _animals[idx]["id"]
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


func _process(delta: float) -> void:
	if not visible or input_blocked:
		queue_redraw()
		return

	for pi: int in _nav_cooldowns:
		_nav_cooldowns[pi] = maxf(0.0, _nav_cooldowns[pi] - delta)

	if _allow_back:
		for device_id: int in _get_human_device_ids():
			if InputManager.is_button_just_pressed_on_device(device_id, JOY_BUTTON_B):
				back_requested.emit()
				return

	var confirmed_this_frame := false
	for pi: int in _player_cursor:
		if not _is_human(pi):
			continue

		var device_id := InputManager.get_device_id(pi)
		if device_id < 0:
			continue

		if _player_confirmed.get(pi, false):
			if not _allow_back and InputManager.is_button_just_pressed_on_device(device_id, JOY_BUTTON_B):
				_player_confirmed[pi] = false
		else:
			if _nav_cooldowns.get(pi, 0.0) <= 0.0:
				var x := Input.get_joy_axis(device_id, JOY_AXIS_LEFT_X)
				if x > 0.5:
					_player_cursor[pi] = (_player_cursor[pi] + 1) % _animals.size()
					_nav_cooldowns[pi] = NAV_COOLDOWN
				elif x < -0.5:
					_player_cursor[pi] = (_player_cursor[pi] - 1 + _animals.size()) % _animals.size()
					_nav_cooldowns[pi] = NAV_COOLDOWN

			if InputManager.is_button_just_pressed_on_device(device_id, JOY_BUTTON_A):
				var idx: int = _player_cursor[pi] as int
				if not _is_animal_taken(idx, pi):
					_player_confirmed[pi] = true
					confirmed_this_frame = true
					if _all_humans_confirmed():
						_auto_assign_bots()

	if _selection_complete() and not confirmed_this_frame:
		for device_id: int in _get_human_device_ids():
			if InputManager.is_button_just_pressed_on_device(device_id, JOY_BUTTON_A):
				escapists_ready.emit(_build_selections())
				return

	queue_redraw()


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
			if font.get_string_size(trimmed, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x <= max_width:
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

	draw_rect(Rect2(Vector2.ZERO, screen), Color.BLACK)

	var title := "CHOOSE YOUR ESCAPIST"
	var title_width := font.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, 28).x
	draw_string(font, Vector2(cx - title_width / 2.0, 50),
		title, HORIZONTAL_ALIGNMENT_LEFT, -1, 28, Color.WHITE)

	var team_name := Enums.team_name(_escapist_team)
	var team_col := Enums.team_color(_escapist_team)
	var sub := "%s picks escapists" % team_name
	var sub_width := font.get_string_size(sub, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x
	draw_string(font, Vector2(cx - sub_width / 2.0, 75),
		sub, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, team_col)

	var card_count := _animals.size()
	var available_w := maxf(760.0, screen.x - 260.0)
	var card_w := clampf((available_w - (card_count - 1) * CARD_GAP) / card_count, 180.0, 230.0)
	var card_h := 220.0
	var total_w := card_count * card_w + (card_count - 1) * CARD_GAP
	var cards_x := cx - total_w / 2.0
	var cards_y := 110.0

	for i in card_count:
		var card_x := cards_x + i * (card_w + CARD_GAP)
		var card_rect := Rect2(Vector2(card_x, cards_y), Vector2(card_w, card_h))
		var animal_data: Dictionary = _animals[i]
		var animal_color: Color = animal_data["color"] as Color
		var animal_name: String = animal_data["name"] as String
		var animal_sub: String = animal_data["subtitle"] as String
		var ability: Dictionary = animal_data["ability"] as Dictionary

		var hovering_pis: Array[int] = []
		var confirmed_pi := -1
		for pi: int in _player_cursor:
			if (_player_cursor[pi] as int) == i:
				if _player_confirmed.get(pi, false):
					confirmed_pi = pi
				else:
					hovering_pis.append(pi)

		var bg_color := Color(0.15, 0.15, 0.15)
		if confirmed_pi >= 0:
			bg_color = Color(animal_color, 0.2)
		draw_rect(card_rect, bg_color)
		var border_color := animal_color if confirmed_pi >= 0 else Color(0.3, 0.3, 0.3)
		if confirmed_pi < 0 and not hovering_pis.is_empty():
			border_color = Color(0.7, 0.7, 0.7)
		draw_rect(card_rect, border_color, false, 2.0)

		var name_width := font.get_string_size(animal_name, HORIZONTAL_ALIGNMENT_LEFT, -1, 20).x
		draw_string(font, Vector2(card_x + card_w / 2.0 - name_width / 2.0, cards_y + 30),
			animal_name, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, animal_color)

		var sub_width_card := font.get_string_size(animal_sub, HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x
		draw_string(font, Vector2(card_x + card_w / 2.0 - sub_width_card / 2.0, cards_y + 50),
			animal_sub, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.6, 0.6, 0.6))

		var ability_button: String = ability["button"] as String
		var ability_title: String = ability["name"] as String
		var ability_name := "[%s] %s" % [ability_button, ability_title]
		var text_x := card_x + CARD_MARGIN
		var text_w := card_w - CARD_MARGIN * 2.0
		draw_string(font, Vector2(text_x, cards_y + 92),
			ability_name, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.85, 0.85, 0.85))
		_draw_wrapped_text(font, ability["desc"] as String, Vector2(text_x, cards_y + 112),
			text_w, 10, Color(0.58, 0.58, 0.58), 13.0, 4)

		if confirmed_pi >= 0:
			var taken_label := "P%d" % (confirmed_pi + 1) if confirmed_pi < 100 else "BOT"
			var taken_width := font.get_string_size(taken_label, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x
			draw_string(font, Vector2(card_x + card_w / 2.0 - taken_width / 2.0, cards_y + card_h - 15),
				taken_label, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, animal_color)
		elif not hovering_pis.is_empty():
			var hover_text := ""
			for h_i in hovering_pis.size():
				if h_i > 0:
					hover_text += " "
				var pi: int = hovering_pis[h_i]
				hover_text += "P%d" % (pi + 1) if pi < 100 else "BOT"
			var hover_width := font.get_string_size(hover_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x
			draw_string(font, Vector2(card_x + card_w / 2.0 - hover_width / 2.0, cards_y + card_h - 15),
				hover_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.8, 0.8, 0.8))

	var trapper_pis: Array[int] = []
	for pi: int in _player_indices:
		if not _is_escapist_player(pi):
			trapper_pis.append(pi)
	if not trapper_pis.is_empty():
		var trapper_labels: Array[String] = []
		for pi: int in trapper_pis:
			trapper_labels.append("P%d" % (pi + 1) if pi < 100 else "BOT")
		var trapper_team := Enums.Team.TEAM_2 if _escapist_team == Enums.Team.TEAM_1 else Enums.Team.TEAM_1
		var trapper_text := "Trappers: %s" % ", ".join(trapper_labels)
		var trapper_width := font.get_string_size(trapper_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x
		draw_string(font, Vector2(cx - trapper_width / 2.0, cards_y + card_h + 30),
			trapper_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Enums.team_color(trapper_team))

	var status_y := screen.y - 70
	for pi: int in _player_cursor:
		if not _is_human(pi):
			continue
		var idx: int = _player_cursor[pi] as int
		var animal_data2: Dictionary = _animals[idx]
		var confirmed: bool = _player_confirmed.get(pi, false)
		var status_name: String = animal_data2["name"] as String
		var status_mark := "OK" if confirmed else "..."
		var label := "P%d: %s %s" % [pi + 1, status_name, status_mark]
		var label_width := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x
		draw_string(font, Vector2(cx - label_width / 2.0, status_y),
			label, HORIZONTAL_ALIGNMENT_LEFT, -1, 14,
			Color.YELLOW if confirmed else Color(0.6, 0.6, 0.6))
		status_y += 20.0

	var hint := "A confirm | B cancel"
	if _allow_back:
		hint = "A confirm | B back"
	if _selection_complete():
		hint = "A continue | B back" if _allow_back else "A continue | B to change"
	var hint_width := font.get_string_size(hint, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x
	draw_string(font, Vector2(cx - hint_width / 2.0, screen.y - 30),
		hint, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color.YELLOW)
