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
var _preview_timers: Dictionary = {}         # {card_index: remaining_time}
var _demo_active: bool = false
var _demo_player_index: int = -1
var _demo_card_index: int = -1
var _demo_pos: Vector2 = Vector2(0.35, 0.62)
var _demo_effects: Array[Dictionary] = []

const NAV_COOLDOWN: float = 0.2
const PREVIEW_DURATION: float = 0.8
const DEMO_EFFECT_DURATION: float = 0.75
const CARD_GAP: float = 22.0
const CARD_MARGIN: float = 16.0
const CARD_TOP_PAD: float = 16.0
const ABILITY_Y: float = 222.0


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
	_preview_timers.clear()
	_demo_active = false
	_demo_player_index = -1
	_demo_card_index = -1
	_demo_pos = Vector2(0.35, 0.62)
	_demo_effects.clear()

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


func _handle_back_for_player(pi: int) -> bool:
	if _player_confirmed.get(pi, false):
		_player_confirmed[pi] = false
		return true
	if _allow_back and not _any_human_confirmed():
		back_requested.emit()
		return true
	return false


func _process(delta: float) -> void:
	if not visible or input_blocked:
		queue_redraw()
		return

	_update_preview_timers(delta)
	if _demo_active:
		_process_demo(delta)
		queue_redraw()
		return

	for pi: int in _nav_cooldowns:
		_nav_cooldowns[pi] = maxf(0.0, _nav_cooldowns[pi] - delta)

	var confirmed_this_frame := false
	for pi: int in _player_cursor:
		if not _is_human(pi):
			continue

		var device_id := InputManager.get_device_id(pi)
		if device_id < 0:
			continue

		if InputManager.is_button_just_pressed_on_device(device_id, JOY_BUTTON_A):
			_enter_demo(pi)
			return

		if InputManager.is_menu_back_just_pressed(device_id):
			if _handle_back_for_player(pi):
				queue_redraw()
				return

		if _player_confirmed.get(pi, false):
			pass
		else:
			if _nav_cooldowns.get(pi, 0.0) <= 0.0:
				var x := Input.get_joy_axis(device_id, JOY_AXIS_LEFT_X)
				if x > 0.5:
					_player_cursor[pi] = (_player_cursor[pi] + 1) % _animals.size()
					_nav_cooldowns[pi] = NAV_COOLDOWN
				elif x < -0.5:
					_player_cursor[pi] = (_player_cursor[pi] - 1 + _animals.size()) % _animals.size()
					_nav_cooldowns[pi] = NAV_COOLDOWN

			if InputManager.is_menu_confirm_just_pressed(device_id):
				var idx: int = _player_cursor[pi] as int
				if not _is_animal_taken(idx, pi):
					_player_confirmed[pi] = true
					confirmed_this_frame = true
					if _all_humans_confirmed():
						_auto_assign_bots()

	if _selection_complete() and not confirmed_this_frame:
		for device_id: int in _get_human_device_ids():
			if InputManager.is_menu_confirm_just_pressed(device_id):
				escapists_ready.emit(_build_selections())
				return

	queue_redraw()


func _update_preview_timers(delta: float) -> void:
	var expired: Array[int] = []
	for card_index: int in _preview_timers:
		_preview_timers[card_index] = maxf((_preview_timers[card_index] as float) - delta, 0.0)
		if (_preview_timers[card_index] as float) <= 0.0:
			expired.append(card_index)
	for card_index in expired:
		_preview_timers.erase(card_index)


func _trigger_ability_preview(player_index: int) -> void:
	if not _player_cursor.has(player_index):
		return
	var card_index: int = _player_cursor[player_index] as int
	_preview_timers[card_index] = PREVIEW_DURATION
	InputManager.vibrate_player(player_index, 0.08, 0.18, 0.08)
	queue_redraw()


func _enter_demo(player_index: int) -> void:
	if not _player_cursor.has(player_index):
		return
	_demo_active = true
	_demo_player_index = player_index
	_demo_card_index = _player_cursor[player_index] as int
	_demo_pos = Vector2(0.35, 0.62)
	_demo_effects.clear()
	InputManager.vibrate_player(player_index, 0.06, 0.14, 0.08)
	queue_redraw()


func _exit_demo() -> void:
	_demo_active = false
	_demo_player_index = -1
	_demo_card_index = -1
	_demo_effects.clear()
	InputManager.suppress_edge_detection(2)
	queue_redraw()


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
	if InputManager.is_button_just_pressed_on_device(device_id, JOY_BUTTON_A):
		_trigger_demo_ability()
	_update_demo_effects(delta)


func _trigger_demo_ability() -> void:
	if _demo_card_index < 0 or _demo_card_index >= _animals.size():
		return
	var animal_data: Dictionary = _animals[_demo_card_index]
	var animal_id := animal_data["id"] as Enums.EscapistAnimal
	if animal_id == Enums.EscapistAnimal.RABBIT:
		_demo_pos.x = clampf(_demo_pos.x + 0.28, 0.10, 0.90)
	_demo_effects.append({
		"time": 0.0,
		"duration": DEMO_EFFECT_DURATION,
		"origin": _demo_pos,
		"animal": animal_id,
	})
	InputManager.vibrate_player(_demo_player_index, 0.08, 0.22, 0.1)


func _update_demo_effects(delta: float) -> void:
	var keep: Array[Dictionary] = []
	for effect: Dictionary in _demo_effects:
		effect["time"] = (effect["time"] as float) + delta
		if (effect["time"] as float) < (effect["duration"] as float):
			keep.append(effect)
	_demo_effects = keep


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

	draw_rect(Rect2(Vector2.ZERO, screen), Color(0.015, 0.015, 0.018, 1.0))
	draw_rect(Rect2(Vector2.ZERO, Vector2(screen.x, 410.0)), Color(0.04, 0.05, 0.04, 0.18))

	var title := "CHOOSE YOUR ESCAPIST"
	_draw_centered_text_in_rect(font, title, Rect2(cx - 260.0, 34.0, 520.0, 38.0), 30, Color.WHITE)

	var team_name := Enums.team_name(_escapist_team)
	var team_col := Enums.team_color(_escapist_team)
	var sub := "%s picks escapists" % team_name
	_draw_centered_text_in_rect(font, sub, Rect2(cx - 260.0, 72.0, 520.0, 24.0), 16, team_col)
	_draw_centered_text_in_rect(font, "Escapists use A in-match. START confirms menus and SELECT cancels or goes back.",
		Rect2(cx - 520.0, 96.0, 1040.0, 18.0), 13, Color(0.62, 0.64, 0.66))

	var card_count := _animals.size()
	var available_w := maxf(880.0, screen.x - 220.0)
	var card_w := clampf((available_w - (card_count - 1) * CARD_GAP) / card_count, 220.0, 300.0)
	var card_h := 400.0
	var total_w := card_count * card_w + (card_count - 1) * CARD_GAP
	var cards_x := cx - total_w / 2.0
	var cards_y := 118.0

	for i in card_count:
		var card_x := cards_x + i * (card_w + CARD_GAP)
		var card_rect := Rect2(Vector2(card_x, cards_y), Vector2(card_w, card_h))
		var animal_data: Dictionary = _animals[i]
		var animal_color: Color = animal_data["color"] as Color
		var animal_name: String = animal_data["name"] as String
		var animal_sub: String = animal_data["subtitle"] as String
		var animal_id: Enums.EscapistAnimal = animal_data["id"] as Enums.EscapistAnimal
		var ability: Dictionary = animal_data["ability"] as Dictionary

		var hovering_pis: Array[int] = []
		var confirmed_pi := -1
		for pi: int in _player_cursor:
			if (_player_cursor[pi] as int) == i:
				if _player_confirmed.get(pi, false):
					confirmed_pi = pi
				else:
					hovering_pis.append(pi)

		var bg_color := Color(0.11, 0.11, 0.12)
		if confirmed_pi >= 0:
			bg_color = Color(animal_color, 0.18)
		var border_color := animal_color if confirmed_pi >= 0 else Color(0.3, 0.3, 0.3)
		if confirmed_pi < 0 and not hovering_pis.is_empty():
			border_color = Color(animal_color, 0.82)
		_draw_panel(card_rect, bg_color, border_color, 2.0)
		draw_rect(Rect2(card_rect.position, Vector2(card_rect.size.x, 5.0)), Color(animal_color, 0.95))

		var art_rect := Rect2(card_x + CARD_MARGIN, cards_y + 62.0, card_w - CARD_MARGIN * 2.0, 122.0)
		draw_rect(art_rect, Color(animal_color, 0.10))
		draw_rect(art_rect, Color(animal_color, 0.25), false, 1.0)
		var demo_running := _demo_active and _demo_card_index == i
		if demo_running:
			_draw_escapist_demo(font, art_rect, animal_id, animal_color)
		else:
			_draw_escapist_silhouette(animal_id, art_rect.position + art_rect.size * 0.5 + Vector2(0.0, 4.0),
				3.1, Color(animal_color, 1.0))

		_draw_centered_text_in_rect(font, animal_name, Rect2(card_x, cards_y + CARD_TOP_PAD, card_w, 28.0), 24, animal_color)

		_draw_centered_text_in_rect(font, animal_sub, Rect2(card_x, cards_y + 44.0, card_w, 18.0), 13, Color(0.64, 0.64, 0.66))

		var ability_button: String = ability["button"] as String
		var ability_title: String = ability["name"] as String
		var ability_name := "[%s] %s" % [ability_button, ability_title]
		var text_x := card_x + CARD_MARGIN
		var text_w := card_w - CARD_MARGIN * 2.0
		draw_string(font, Vector2(text_x, cards_y + ABILITY_Y),
			ability_name, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(0.88, 0.88, 0.88))
		_draw_wrapped_text(font, ability["desc"] as String, Vector2(text_x, cards_y + ABILITY_Y + 26.0),
			text_w, 13, Color(0.64, 0.64, 0.64), 17.0, 4)

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
		var wait_rect := Rect2(cx - 230.0, cards_y + card_h + 24.0, 460.0, 30.0)
		_draw_panel(wait_rect, Color(0.04, 0.04, 0.045, 0.9), Color(Enums.team_color(trapper_team), 0.45), 1.5)
		_draw_centered_text_in_rect(font, trapper_text, wait_rect, 14, Enums.team_color(trapper_team))

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

	var hint := "A demo | Left stick move | START confirm | SELECT cancel"
	if _allow_back:
		hint = "A demo | Left stick move | START confirm | SELECT back or cancel"
	if _selection_complete():
		hint = "START continue | SELECT back or change" if _allow_back else "START continue | SELECT to change"
	var hint_width := font.get_string_size(hint, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x
	draw_string(font, Vector2(cx - hint_width / 2.0, screen.y - 30),
		hint, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color.YELLOW)


func _draw_panel(rect: Rect2, fill: Color, outline: Color, outline_width: float = 2.0) -> void:
	draw_rect(rect, fill)
	draw_rect(rect, outline, false, outline_width)


func _draw_escapist_demo(font: Font, rect: Rect2,
		animal_id: Enums.EscapistAnimal, color: Color) -> void:
	draw_rect(rect, Color(0.02, 0.025, 0.03, 0.96))
	draw_rect(rect, Color(color, 0.55), false, 1.5)
	var obstacle := Rect2(rect.position + Vector2(rect.size.x * 0.52, rect.size.y * 0.24),
		Vector2(rect.size.x * 0.12, rect.size.y * 0.46))
	draw_rect(obstacle, Color(0.58, 0.58, 0.58, 0.86))
	draw_rect(obstacle, Color(0.86, 0.86, 0.86, 0.48), false, 1.0)
	var trap := rect.position + Vector2(rect.size.x * 0.78, rect.size.y * 0.66)
	draw_rect(Rect2(trap - Vector2(9.0, 9.0), Vector2(18.0, 18.0)), Color(1.0, 0.22, 0.18, 0.72))
	var ally := rect.position + Vector2(rect.size.x * 0.78, rect.size.y * 0.32)
	draw_circle(ally, 8.0, Color(0.25, 0.85, 1.0, 0.82))
	var player := rect.position + Vector2(_demo_pos.x * rect.size.x, _demo_pos.y * rect.size.y)
	for effect: Dictionary in _demo_effects:
		var t := clampf((effect["time"] as float) / (effect["duration"] as float), 0.0, 1.0)
		_draw_escapist_demo_effect(rect, player, ally, trap, animal_id, color, t)
	draw_circle(player, 11.0, Color(color, 0.95))
	draw_arc(player, 14.0, 0.0, TAU, 18, Color.WHITE, 1.4)
	draw_string(font, rect.position + Vector2(9.0, rect.size.y - 9.0),
		"SELECT exit | A skill", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(color, 0.9))


func _draw_escapist_demo_effect(rect: Rect2, player: Vector2, ally: Vector2, trap: Vector2,
		animal_id: Enums.EscapistAnimal, color: Color, t: float) -> void:
	var fade := 1.0 - t
	match animal_id:
		Enums.EscapistAnimal.RABBIT:
			var start := player - Vector2(44.0, 0.0)
			draw_arc(start + Vector2(30.0, 0.0), 36.0, PI, TAU, 24, Color(color, 0.35 * fade), 2.0)
			draw_circle(player, 10.0 + 12.0 * t, Color(color, 0.45 * fade))
		Enums.EscapistAnimal.RAT:
			draw_line(player, ally, Color(color, 0.9 * fade), 4.0)
			draw_circle(ally, 8.0 + 10.0 * t, Color(color, 0.45 * fade))
		Enums.EscapistAnimal.SQUIRREL:
			var acorn := player.lerp(trap, t)
			draw_circle(acorn, 8.0, Color(color, 0.9 * fade))
			draw_line(player, acorn, Color(color, 0.32 * fade), 2.0)
		Enums.EscapistAnimal.FLY:
			draw_arc(player, 18.0 + 32.0 * t, 0.0, TAU, 28,
				Color(color, 0.9 * fade), 3.0)
			draw_line(player, trap, Color(color, 0.38 * fade), 2.0)


func _draw_active_escapist_preview(font: Font, rect: Rect2, card_index: int,
		animal_id: Enums.EscapistAnimal, color: Color) -> void:
	if not _preview_timers.has(card_index):
		return
	var remaining := _preview_timers[card_index] as float
	if remaining <= 0.0:
		return
	var t := 1.0 - clampf(remaining / PREVIEW_DURATION, 0.0, 1.0)
	var center := rect.position + rect.size * 0.5
	draw_rect(rect, Color(color, 0.14))
	match animal_id:
		Enums.EscapistAnimal.RABBIT:
			var start := rect.position + Vector2(30.0, rect.size.y - 24.0)
			var end := rect.end - Vector2(30.0, 28.0)
			var mid := start.lerp(end, t) + Vector2(0.0, -38.0 * sin(t * PI))
			draw_arc(start.lerp(end, 0.5), 42.0, PI, TAU, 24, Color(color, 0.35), 2.0)
			draw_circle(mid, 11.0, Color(color, 0.86))
		Enums.EscapistAnimal.RAT:
			var end_pos := center + Vector2(lerpf(-48.0, 48.0, t), sin(t * PI) * -20.0)
			draw_line(center, end_pos, Color(color, 0.82), 4.0)
			draw_circle(end_pos, 8.0, Color(color, 0.86))
		Enums.EscapistAnimal.SQUIRREL:
			var bounce := absf(sin(t * PI * 2.0))
			var acorn_pos := center + Vector2(lerpf(-42.0, 42.0, t), -28.0 * bounce)
			draw_circle(acorn_pos, 12.0, Color(color, 0.88))
			draw_arc(acorn_pos, 16.0, 0.0, TAU, 18, Color(color, 0.5), 2.0)
		Enums.EscapistAnimal.FLY:
			draw_arc(center, 22.0 + 28.0 * t, 0.0, TAU, 28,
				Color(color, 0.92 * (1.0 - t)), 3.0)
			draw_circle(center, 14.0, Color(color, 0.72))
	draw_string(font, rect.position + Vector2(10.0, rect.size.y - 10.0),
		"Preview [A]", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(color, 0.92))


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


func _draw_escapist_silhouette(animal: Enums.EscapistAnimal, center: Vector2, scale: float, color: Color) -> void:
	match animal:
		Enums.EscapistAnimal.RABBIT:
			_draw_rabbit_silhouette(center, scale, color)
		Enums.EscapistAnimal.RAT:
			_draw_rat_silhouette(center, scale, color)
		Enums.EscapistAnimal.SQUIRREL:
			_draw_squirrel_silhouette(center, scale, color)
		Enums.EscapistAnimal.FLY:
			_draw_fly_silhouette(center, scale, color)


func _draw_rabbit_silhouette(center: Vector2, scale: float, color: Color) -> void:
	draw_colored_polygon(_scaled_points(center, scale, [
		Vector2(-5.8, -3.5),
		Vector2(-10.8, -13.0),
		Vector2(-6.0, -14.2),
		Vector2(-2.0, -4.6),
	]), color)
	draw_colored_polygon(_scaled_points(center, scale, [
		Vector2(5.8, -3.5),
		Vector2(10.8, -13.0),
		Vector2(6.0, -14.2),
		Vector2(2.0, -4.6),
	]), color)
	draw_colored_polygon(_scaled_points(center, scale, [
		Vector2(-8.0, -2.0),
		Vector2(-4.0, -7.0),
		Vector2(4.0, -7.0),
		Vector2(8.0, -2.0),
		Vector2(7.0, 5.5),
		Vector2(2.0, 10.0),
		Vector2(-2.0, 10.0),
		Vector2(-7.0, 5.5),
	]), color)


func _draw_rat_silhouette(center: Vector2, scale: float, color: Color) -> void:
	draw_polyline(_scaled_points(center, scale, [
		Vector2(-6.2, 7.6),
		Vector2(-12.8, 9.2),
		Vector2(-15.0, 6.0),
		Vector2(-9.4, 4.5),
	]), color, 2.4 * scale)
	_draw_filled_ellipse(center + Vector2(-5.0, 2.4) * scale, Vector2(8.0, 8.8) * scale, color)
	_draw_filled_ellipse(center + Vector2(1.0, -3.8) * scale, Vector2(6.4, 4.8) * scale, color)
	draw_colored_polygon(_scaled_points(center, scale, [
		Vector2(3.5, -7.4),
		Vector2(13.8, -3.0),
		Vector2(5.0, 1.4),
	]), color)
	draw_circle(center + Vector2(-1.6, -7.6) * scale, 3.5 * scale, color)
	draw_circle(center + Vector2(2.4, -7.8) * scale, 3.2 * scale, color)
	draw_circle(center + Vector2(5.5, -4.8) * scale, 1.1 * scale, Color(0.01, 0.01, 0.01, color.a))


func _draw_squirrel_silhouette(center: Vector2, scale: float, color: Color) -> void:
	_draw_filled_ellipse(center + Vector2(-6.8, -1.0) * scale, Vector2(7.2, 10.8) * scale, color)
	_draw_filled_ellipse(center + Vector2(-3.6, -7.0) * scale, Vector2(6.4, 7.4) * scale, color)
	_draw_filled_ellipse(center + Vector2(-3.0, 5.4) * scale, Vector2(5.6, 7.0) * scale, color)
	_draw_filled_ellipse(center + Vector2(3.0, 5.2) * scale, Vector2(5.8, 6.0) * scale, color)
	draw_colored_polygon(_scaled_points(center, scale, [
		Vector2(4.0, -4.0),
		Vector2(8.0, -7.5),
		Vector2(12.8, -3.0),
		Vector2(9.5, 1.8),
		Vector2(4.0, 1.0),
	]), color)
	draw_colored_polygon(_scaled_points(center, scale, [
		Vector2(5.6, -5.0),
		Vector2(6.8, -10.0),
		Vector2(9.0, -5.8),
	]), color)
	draw_circle(center + Vector2(9.2, -2.5) * scale, 0.9 * scale, Color(0.01, 0.01, 0.01, color.a))


func _draw_fly_silhouette(center: Vector2, scale: float, color: Color) -> void:
	draw_colored_polygon(_scaled_points(center, scale, [
		Vector2(-1.5, -3.0),
		Vector2(-12.5, -8.5),
		Vector2(-14.0, 0.8),
		Vector2(-5.0, 5.6),
	]), color)
	draw_colored_polygon(_scaled_points(center, scale, [
		Vector2(1.5, -3.0),
		Vector2(12.5, -8.5),
		Vector2(14.0, 0.8),
		Vector2(5.0, 5.6),
	]), color)
	draw_colored_polygon(_scaled_points(center, scale, [
		Vector2(-2.8, -8.5),
		Vector2(2.8, -8.5),
		Vector2(4.0, 6.8),
		Vector2(0.0, 11.0),
		Vector2(-4.0, 6.8),
	]), color)
