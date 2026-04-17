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
const CARD_TOP_PAD: float = 16.0
const ABILITY_Y: float = 178.0


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

	draw_rect(Rect2(Vector2.ZERO, screen), Color(0.015, 0.015, 0.018, 1.0))
	draw_rect(Rect2(Vector2.ZERO, Vector2(screen.x, 410.0)), Color(0.04, 0.05, 0.04, 0.18))

	var title := "CHOOSE YOUR ESCAPIST"
	_draw_centered_text_in_rect(font, title, Rect2(cx - 260.0, 34.0, 520.0, 38.0), 30, Color.WHITE)

	var team_name := Enums.team_name(_escapist_team)
	var team_col := Enums.team_color(_escapist_team)
	var sub := "%s picks escapists" % team_name
	_draw_centered_text_in_rect(font, sub, Rect2(cx - 260.0, 72.0, 520.0, 24.0), 16, team_col)

	var card_count := _animals.size()
	var available_w := maxf(760.0, screen.x - 260.0)
	var card_w := clampf((available_w - (card_count - 1) * CARD_GAP) / card_count, 180.0, 230.0)
	var card_h := 320.0
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

		var art_rect := Rect2(card_x + CARD_MARGIN, cards_y + 54.0, card_w - CARD_MARGIN * 2.0, 100.0)
		draw_rect(art_rect, Color(animal_color, 0.10))
		draw_rect(art_rect, Color(animal_color, 0.25), false, 1.0)
		_draw_escapist_silhouette(animal_id, art_rect.position + art_rect.size * 0.5 + Vector2(0.0, 4.0),
			3.1, Color(animal_color, 1.0))

		_draw_centered_text_in_rect(font, animal_name, Rect2(card_x, cards_y + CARD_TOP_PAD, card_w, 24.0), 20, animal_color)

		_draw_centered_text_in_rect(font, animal_sub, Rect2(card_x, cards_y + 39.0, card_w, 16.0), 11, Color(0.64, 0.64, 0.66))

		var ability_button: String = ability["button"] as String
		var ability_title: String = ability["name"] as String
		var ability_name := "[%s] %s" % [ability_button, ability_title]
		var text_x := card_x + CARD_MARGIN
		var text_w := card_w - CARD_MARGIN * 2.0
		draw_string(font, Vector2(text_x, cards_y + ABILITY_Y),
			ability_name, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.85, 0.85, 0.85))
		_draw_wrapped_text(font, ability["desc"] as String, Vector2(text_x, cards_y + ABILITY_Y + 20.0),
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

	var hint := "Left stick move | A confirm | B cancel"
	if _allow_back:
		hint = "Left stick move | A confirm | B back"
	if _selection_complete():
		hint = "A continue | B back" if _allow_back else "A continue | B to change"
	var hint_width := font.get_string_size(hint, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x
	draw_string(font, Vector2(cx - hint_width / 2.0, screen.y - 30),
		hint, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color.YELLOW)


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
