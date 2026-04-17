class_name CharacterSelect
extends Control

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

const NAV_COOLDOWN: float = 0.2
const CARD_GAP: float = 18.0
const CARD_MARGIN: float = 12.0
const ABILITY_LINE_HEIGHT: float = 11.0
const ABILITY_BLOCK_HEIGHT: float = 46.0


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


func _process(delta: float) -> void:
	if not visible or input_blocked:
		queue_redraw()
		return

	# Tick nav cooldowns
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
			# Already confirmed — B to un-confirm
			if not _allow_back and InputManager.is_button_just_pressed_on_device(device_id, JOY_BUTTON_B):
				_player_confirmed[pi] = false
		else:
			# Navigate
			if _nav_cooldowns.get(pi, 0.0) <= 0.0:
				var x := Input.get_joy_axis(device_id, JOY_AXIS_LEFT_X)
				if x > 0.5:
					_player_cursor[pi] = (_player_cursor[pi] + 1) % _characters.size()
					_nav_cooldowns[pi] = NAV_COOLDOWN
				elif x < -0.5:
					_player_cursor[pi] = (_player_cursor[pi] - 1 + _characters.size()) % _characters.size()
					_nav_cooldowns[pi] = NAV_COOLDOWN

			# A to confirm (if not taken)
			if InputManager.is_button_just_pressed_on_device(device_id, JOY_BUTTON_A):
				var idx: int = _player_cursor[pi] as int
				if not _is_character_taken(idx, pi):
					_player_confirmed[pi] = true
					confirmed_this_frame = true
					if _all_humans_confirmed():
						_auto_assign_bots()

	if _selection_complete() and not confirmed_this_frame:
		for device_id: int in _get_human_device_ids():
			if InputManager.is_button_just_pressed_on_device(device_id, JOY_BUTTON_START):
				characters_ready.emit(_build_selections())
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
	draw_rect(Rect2(Vector2.ZERO, screen), Color.BLACK)

	# Title
	var title := "CHOOSE YOUR TRAPPER"
	var title_width := font.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, 28).x
	draw_string(font, Vector2(cx - title_width / 2.0, 50),
		title, HORIZONTAL_ALIGNMENT_LEFT, -1, 28, Color.WHITE)

	# Trapping team label
	var team_name := Enums.team_name(_trapping_team)
	var team_col := Enums.team_color(_trapping_team)
	var sub := "%s picks trappers" % team_name
	var sub_width := font.get_string_size(sub, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x
	draw_string(font, Vector2(cx - sub_width / 2.0, 75),
		sub, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, team_col)

	# Character cards — 4 cards in a row
	var card_count := _characters.size()
	var card_gap := CARD_GAP
	var available_w := maxf(760.0, screen.x - 260.0)
	var card_w := clampf((available_w - (card_count - 1) * card_gap) / card_count, 180.0, 230.0)
	var card_h := 240.0
	var total_w := card_count * card_w + (card_count - 1) * card_gap
	var cards_x := cx - total_w / 2.0
	var cards_y := 100.0

	for i in card_count:
		var card_x := cards_x + i * (card_w + card_gap)
		var card_rect := Rect2(Vector2(card_x, cards_y), Vector2(card_w, card_h))
		var char_data: Dictionary = _characters[i]
		var char_color: Color = char_data["color"] as Color
		var char_name: String = char_data["name"] as String
		var char_sub: String = char_data["subtitle"] as String
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
		var bg_color := Color(0.15, 0.15, 0.15)
		if confirmed_pi >= 0:
			bg_color = Color(char_color, 0.2)
		draw_rect(card_rect, bg_color)

		# Card border
		var border_color := Color(0.3, 0.3, 0.3)
		if confirmed_pi >= 0:
			border_color = char_color
		elif not hovering_pis.is_empty():
			border_color = Color(0.7, 0.7, 0.7)
		draw_rect(card_rect, border_color, false, 2.0)

		# Character name
		var name_width := font.get_string_size(char_name, HORIZONTAL_ALIGNMENT_LEFT, -1, 20).x
		draw_string(font, Vector2(card_x + card_w / 2.0 - name_width / 2.0, cards_y + 30),
			char_name, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, char_color)

		# Subtitle
		var sub_y := cards_y + 48
		var sub_max_w := card_w - CARD_MARGIN * 2.0
		var subtitle_width := font.get_string_size(char_sub, HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x
		if subtitle_width <= sub_max_w:
			draw_string(font, Vector2(card_x + card_w / 2.0 - subtitle_width / 2.0, sub_y),
				char_sub, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.6, 0.6, 0.6))
		else:
			_draw_wrapped_text(font, char_sub, Vector2(card_x + CARD_MARGIN, sub_y),
				sub_max_w, 11, Color(0.6, 0.6, 0.6), 12.0, 2)

		# Abilities list
		for a_i in abilities.size():
			var ability: Dictionary = abilities[a_i] as Dictionary
			var a_name: String = ability["name"] as String
			var a_btn: String = ability["button"] as String
			var a_text := "[%s] %s" % [a_btn, a_name]
			var text_x := card_x + CARD_MARGIN
			var text_w := card_w - CARD_MARGIN * 2.0
			var block_y := cards_y + 82 + a_i * ABILITY_BLOCK_HEIGHT
			draw_string(font, Vector2(text_x, block_y),
				a_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.82, 0.82, 0.82))
			var a_desc: String = ability["desc"] as String
			_draw_wrapped_text(font, a_desc, Vector2(text_x, block_y + 14),
				text_w, 9, Color(0.55, 0.55, 0.55), ABILITY_LINE_HEIGHT, 2)

		# TAKEN label
		if is_taken:
			var taken_label := "P%d" % (confirmed_pi + 1) if confirmed_pi < 100 else "BOT"
			var taken_text := "%s ✓" % taken_label
			var tw := font.get_string_size(taken_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x
			draw_string(font, Vector2(card_x + card_w / 2.0 - tw / 2.0, cards_y + card_h - 15),
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
			draw_string(font, Vector2(card_x + card_w / 2.0 - hw / 2.0, cards_y + card_h - 15),
				hover_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.8, 0.8, 0.8))

	# Escapist team players
	var escapist_pis: Array[int] = []
	for pi: int in _player_indices:
		if not _is_trapper_player(pi):
			escapist_pis.append(pi)

	if not escapist_pis.is_empty():
		var esc_y := cards_y + card_h + 30
		var esc_labels: Array[String] = []
		for pi: int in escapist_pis:
			var label := "P%d" % (pi + 1) if pi < 100 else "BOT"
			esc_labels.append(label)
		var esc_text := "Escapists: %s" % ", ".join(esc_labels)
		var ew := font.get_string_size(esc_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x
		var esc_team: Enums.Team = Enums.Team.TEAM_1 if _trapping_team == Enums.Team.TEAM_2 else Enums.Team.TEAM_2
		draw_string(font, Vector2(cx - ew / 2.0, esc_y),
			esc_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Enums.team_color(esc_team))

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
	var hint := "A confirm | B cancel"
	if _allow_back:
		hint = "A confirm | B back"
	if _selection_complete():
		hint = "START to begin | B back" if _allow_back else "START to begin | B to change"
	var hint_width := font.get_string_size(hint, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x
	draw_string(font, Vector2(cx - hint_width / 2.0, screen.y - 30),
		hint, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color.YELLOW)
