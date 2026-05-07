class_name EscapistSelect
extends Control

const SkillTestViewScene := preload("res://scenes/ui/skill_test_view.gd")

signal escapists_ready(selections: Dictionary)
signal back_requested

var _player_indices: Array[int] = []
var _team_assignments: Dictionary = {}
var _escapist_team: Enums.Team = Enums.Team.NONE
var _player_cursor: Dictionary = {}
var _player_confirmed: Dictionary = {}
var _viewer_cursor: Dictionary = {}
var _nav_axis_locks: Dictionary = {}
var _animals: Array[Dictionary] = []
var _allow_back: bool = true
var _survival_mode: bool = false
var input_blocked: bool = false
var _preview_timers: Dictionary = {}         # {card_index: remaining_time}
var _demo_active: bool = false
var _demo_player_index: int = -1
var _demo_card_index: int = -1
var _demo_pos: Vector2 = Vector2(0.35, 0.62)
var _demo_effects: Array[Dictionary] = []
var _demo_entities: Dictionary = {}
var _skill_test_views: Dictionary = {}       # {pi: SkillTestView}
var _skill_test_cards: Dictionary = {}       # {pi: card_index}
var _escapist_sprite_cache: Dictionary = {}
var _blocked_start_message_timer: float = 0.0

const NAV_AXIS_THRESHOLD: float = 0.84
const NAV_AXIS_RELEASE: float = 0.42
const PREVIEW_DURATION: float = 0.8
const DEMO_EFFECT_DURATION: float = 0.75
const BLOCKED_START_MESSAGE_DURATION: float = 3.0
const GRID_COLUMNS: int = 2
const SLOT_COUNT: int = 4
const CARD_GAP: float = 22.0
const CARD_MARGIN: float = 16.0
const CARD_TOP_PAD: float = 14.0
const ABILITY_Y: float = 222.0
const CARDS_Y: float = 154.0


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR


func setup(player_indices: Array[int], team_assignments: Dictionary,
		escapist_team: Enums.Team, allow_back: bool = true, survival_mode: bool = false) -> void:
	_player_indices = player_indices.duplicate()
	_team_assignments = team_assignments.duplicate()
	_escapist_team = escapist_team
	_allow_back = allow_back
	_survival_mode = survival_mode
	_animals = EscapistAnimals.get_survival_all() if _survival_mode else EscapistAnimals.get_all()

	_player_cursor.clear()
	_player_confirmed.clear()
	_viewer_cursor.clear()
	_nav_axis_locks.clear()
	_preview_timers.clear()
	_demo_active = false
	_demo_player_index = -1
	_demo_card_index = -1
	_demo_pos = Vector2(0.35, 0.62)
	_demo_effects.clear()
	_demo_entities.clear()
	_blocked_start_message_timer = 0.0
	_clear_skill_tests()

	var cursor_idx := 0
	for pi: int in _player_indices:
		if _is_escapist_player(pi):
			_player_cursor[pi] = cursor_idx % _animals.size()
			_player_confirmed[pi] = false
			var device_id := InputManager.get_device_id(pi)
			var axis_active := false
			if device_id >= 0:
				axis_active = absf(Input.get_joy_axis(device_id, JOY_AXIS_LEFT_X)) > NAV_AXIS_RELEASE
			_nav_axis_locks[pi] = axis_active
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


func _get_human_selecting_players() -> Array[int]:
	var players: Array[int] = []
	for pi: int in _player_cursor:
		if _is_human(pi):
			players.append(pi)
	players.sort()
	return players


func _get_slot_player(slot_index: int) -> int:
	var players := _get_human_selecting_players()
	if slot_index < 0 or slot_index >= players.size():
		return -1
	return players[slot_index]


func _get_slot_index_for_player(player_index: int) -> int:
	return _get_human_selecting_players().find(player_index)


func _get_confirmed_animal_owner(animal_index: int, ignored_player: int = -1) -> int:
	for pi: int in _player_confirmed:
		if pi == ignored_player:
			continue
		if _player_confirmed.get(pi, false) and (_player_cursor[pi] as int) == animal_index:
			return pi
	return -1


func _handle_back_for_player(pi: int) -> bool:
	if _allow_back and (not _player_cursor.has(pi) or not _any_human_confirmed()):
		_clear_skill_tests()
		back_requested.emit()
		return true
	return false


func _handle_deselect_for_player(pi: int) -> bool:
	if _player_confirmed.get(pi, false):
		_player_confirmed[pi] = false
		return true
	return false


func _confirm_for_player(pi: int) -> bool:
	if not _player_cursor.has(pi) or _player_confirmed.get(pi, false):
		return false
	var idx: int = _player_cursor[pi] as int
	if _is_animal_taken(idx, pi):
		return false
	_player_confirmed[pi] = true
	if _all_humans_confirmed():
		_auto_assign_bots()
	return true


func _has_screen_cursor(pi: int) -> bool:
	return _player_cursor.has(pi) or _viewer_cursor.has(pi)


func _get_screen_cursor(pi: int) -> int:
	if _player_cursor.has(pi):
		return _player_cursor[pi] as int
	return _viewer_cursor.get(pi, 0) as int


func _set_screen_cursor(pi: int, value: int) -> void:
	if _player_cursor.has(pi):
		_player_cursor[pi] = value
	elif _viewer_cursor.has(pi):
		_viewer_cursor[pi] = value


func _move_cursor_on_grid(current_index: int, dx: int, _dy: int) -> int:
	var item_count := _animals.size()
	if item_count <= 1 or dx == 0:
		return current_index
	return (current_index + dx + item_count) % item_count


func _handle_grid_navigation(pi: int, device_id: int) -> void:
	var x := Input.get_joy_axis(device_id, JOY_AXIS_LEFT_X)
	if _nav_axis_locks.get(pi, false):
		if absf(x) <= NAV_AXIS_RELEASE:
			_nav_axis_locks[pi] = false
		return
	if absf(x) < NAV_AXIS_THRESHOLD:
		return
	var dx := 1 if x > 0.0 else -1
	var current_index := _get_screen_cursor(pi)
	var next_index := _move_cursor_on_grid(current_index, dx, 0)
	if next_index != current_index:
		_set_screen_cursor(pi, next_index)
	_nav_axis_locks[pi] = true


func _process(delta: float) -> void:
	if not visible or input_blocked:
		queue_redraw()
		return

	_prune_skill_tests()
	_update_preview_timers(delta)
	_update_skill_test_layout()
	_blocked_start_message_timer = maxf(_blocked_start_message_timer - delta, 0.0)

	var confirmed_this_frame := false
	for pi: int in _player_indices:
		if not _is_human(pi):
			continue
		if not _has_screen_cursor(pi):
			continue

		var device_id := InputManager.get_device_id(pi)
		if device_id < 0:
			continue

		if _skill_test_views.has(pi):
			if InputManager.is_menu_back_just_pressed(device_id) \
					or InputManager.is_button_just_pressed_on_device(device_id, JOY_BUTTON_B):
				_exit_skill_test(pi)
				queue_redraw()
				return
			continue

		if InputManager.is_button_just_pressed_on_device(device_id, JOY_BUTTON_Y):
			_enter_demo(pi)
			return

		if InputManager.is_button_just_pressed_on_device(device_id, JOY_BUTTON_B):
			if _handle_deselect_for_player(pi):
				queue_redraw()
				return

		if InputManager.is_menu_back_just_pressed(device_id):
			if _handle_back_for_player(pi):
				queue_redraw()
				return

		if not _player_cursor.has(pi):
			_handle_grid_navigation(pi, device_id)
			continue

		if _player_confirmed.get(pi, false):
			pass
		else:
			_handle_grid_navigation(pi, device_id)

			if InputManager.is_button_just_pressed_on_device(device_id, JOY_BUTTON_A):
				if _confirm_for_player(pi):
					confirmed_this_frame = true

	if not confirmed_this_frame and _any_human_start_pressed():
		if _selection_complete() and _all_humans_confirmed():
				_clear_skill_tests()
				escapists_ready.emit(_build_selections())
				return
		_show_start_blocked_message()
		return

	queue_redraw()


func _any_human_start_pressed() -> bool:
	for device_id: int in _get_human_device_ids():
		if InputManager.is_menu_confirm_just_pressed(device_id):
			return true
	return false


func _show_start_blocked_message() -> void:
	_blocked_start_message_timer = BLOCKED_START_MESSAGE_DURATION
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
	if not _has_screen_cursor(player_index):
		return
	var card_index := _get_screen_cursor(player_index)
	_preview_timers[card_index] = PREVIEW_DURATION
	InputManager.vibrate_player(player_index, 0.08, 0.18, 0.08)
	queue_redraw()


func _enter_demo(player_index: int) -> void:
	if not _has_screen_cursor(player_index):
		return
	_exit_skill_test(player_index)
	var card_index := _get_screen_cursor(player_index)
	var animal_data: Dictionary = _animals[card_index]
	var view := SkillTestViewScene.new()
	add_child(view)
	if _survival_mode:
		view.call("setup_escapist_survival", player_index, animal_data["id"] as Enums.EscapistAnimal)
	else:
		view.call("setup_escapist", player_index, animal_data["id"] as Enums.EscapistAnimal)
	_skill_test_views[player_index] = view
	_skill_test_cards[player_index] = card_index
	_update_skill_test_layout()
	InputManager.vibrate_player(player_index, 0.06, 0.14, 0.08)
	queue_redraw()


func _exit_demo() -> void:
	if _demo_player_index >= 0:
		_exit_skill_test(_demo_player_index)


func _exit_skill_test(player_index: int) -> void:
	var view := _get_valid_skill_test_view(player_index)
	if view != null and is_instance_valid(view):
		view.queue_free()
	_skill_test_views.erase(player_index)
	_skill_test_cards.erase(player_index)
	InputManager.suppress_edge_detection(2)
	queue_redraw()


func _clear_skill_tests() -> void:
	for pi: int in _skill_test_views:
		var view := _get_valid_skill_test_view(pi)
		if view != null and is_instance_valid(view):
			view.queue_free()
	_skill_test_views.clear()
	_skill_test_cards.clear()


func _is_card_testing(card_index: int) -> bool:
	for pi: int in _skill_test_cards:
		if _skill_test_views.has(pi) and (_skill_test_cards[pi] as int) == card_index:
			return true
	return false


func _is_viewer_testing(pi: int) -> bool:
	return _skill_test_views.has(pi) and _skill_test_cards.has(pi)


func _prune_skill_tests() -> void:
	var stale: Array[int] = []
	for pi: int in _skill_test_cards:
		if not _skill_test_views.has(pi):
			stale.append(pi)
			continue
		var view := _get_valid_skill_test_view(pi)
		if view == null or not is_instance_valid(view) or not view.is_inside_tree():
			stale.append(pi)
	for pi in stale:
		_skill_test_views.erase(pi)
		_skill_test_cards.erase(pi)


func _update_skill_test_layout() -> void:
	if _skill_test_views.is_empty() or _animals.is_empty():
		return
	var screen := get_viewport_rect().size
	var cx := screen.x / 2.0
	var columns := 2
	var rows := int(ceili(float(SLOT_COUNT) / float(columns)))
	var row_gap := 22.0
	var available_w := maxf(760.0, screen.x - 260.0)
	var card_w := clampf((available_w - float(columns - 1) * CARD_GAP) / float(columns), 360.0, 700.0)
	var card_h := clampf((screen.y - 274.0 - float(rows - 1) * row_gap) / float(rows), 256.0, 410.0)
	var total_w := float(columns) * card_w + float(columns - 1) * CARD_GAP
	var cards_x := cx - total_w / 2.0
	var cards_y := CARDS_Y
	for pi: int in _skill_test_views:
		var view := _get_valid_skill_test_view(pi)
		if view == null or not is_instance_valid(view):
			continue
		var slot_index := _get_slot_index_for_player(pi)
		if slot_index < 0:
			continue
		var col := slot_index % columns
		var row := int(floor(float(slot_index) / float(columns)))
		var card_x := cards_x + float(col) * (card_w + CARD_GAP)
		var card_y := cards_y + float(row) * (card_h + row_gap)
		var art_h := clampf(card_h * 0.54, 145.0, 225.0)
		var art_rect := Rect2(card_x + CARD_MARGIN, card_y + 62.0, card_w - CARD_MARGIN * 2.0, art_h)
		view.call("set_view_rect", art_rect)


func _get_valid_skill_test_view(player_index: int) -> Node:
	var view: Variant = _skill_test_views.get(player_index, null)
	if view is Object and is_instance_valid(view) and view is Node:
		return view as Node
	return null


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
	_update_escapist_demo_entities(delta)


func _trigger_demo_ability() -> void:
	if _demo_card_index < 0 or _demo_card_index >= _animals.size():
		return
	var animal_data: Dictionary = _animals[_demo_card_index]
	var animal_id := animal_data["id"] as Enums.EscapistAnimal
	_demo_effects.append({
		"time": 0.0,
		"duration": DEMO_EFFECT_DURATION,
		"origin": _demo_pos,
		"animal": animal_id,
	})
	_apply_escapist_demo_ability(animal_id)
	InputManager.vibrate_player(_demo_player_index, 0.08, 0.22, 0.1)


func _update_demo_effects(delta: float) -> void:
	var keep: Array[Dictionary] = []
	for effect: Dictionary in _demo_effects:
		effect["time"] = (effect["time"] as float) + delta
		if (effect["time"] as float) < (effect["duration"] as float):
			keep.append(effect)
	_demo_effects = keep


func _reset_escapist_demo_state(_animal_id: Enums.EscapistAnimal) -> void:
	_demo_entities = {
		"ally": Vector2(0.78, 0.30),
		"opponent": Vector2(0.80, 0.58),
		"opponent_velocity": Vector2(-0.16, 0.0),
		"trap": Vector2(0.76, 0.72),
		"trap_alive": true,
		"status": "",
		"status_timer": 0.0,
		"counter_timer": 0.0,
		"boost_timer": 0.0,
	}


func _update_escapist_demo_entities(delta: float) -> void:
	if _demo_entities.is_empty():
		return
	var status_timer := maxf((_demo_entities.get("status_timer", 0.0) as float) - delta, 0.0)
	_demo_entities["status_timer"] = status_timer
	if status_timer <= 0.0:
		_demo_entities["status"] = ""

	var opponent := _demo_entities["opponent"] as Vector2
	var velocity := _demo_entities["opponent_velocity"] as Vector2
	opponent += velocity * delta
	if opponent.x < 0.58 or opponent.x > 0.88:
		velocity.x *= -1.0
		opponent.x = clampf(opponent.x, 0.58, 0.88)
	_demo_entities["opponent"] = opponent
	_demo_entities["opponent_velocity"] = velocity

	var boost_timer := maxf((_demo_entities.get("boost_timer", 0.0) as float) - delta, 0.0)
	_demo_entities["boost_timer"] = boost_timer
	if boost_timer > 0.0:
		_demo_pos.x = clampf(_demo_pos.x + delta * 0.34, 0.10, 0.90)

	var counter_timer := maxf((_demo_entities.get("counter_timer", 0.0) as float) - delta, 0.0)
	_demo_entities["counter_timer"] = counter_timer
	if counter_timer > 0.0 and _fly_counter_can_trigger():
		_demo_entities["counter_timer"] = 0.0
		_demo_entities["boost_timer"] = 0.55
		_demo_pos.x = clampf(_demo_pos.x + 0.20, 0.10, 0.90)
		_set_escapist_demo_status("IMPULSO ACTIVADO", 0.9)


func _apply_escapist_demo_ability(animal_id: Enums.EscapistAnimal) -> void:
	if _demo_entities.is_empty():
		return
	match animal_id:
		Enums.EscapistAnimal.RABBIT:
			_demo_pos.x = clampf(_demo_pos.x + 0.30, 0.10, 0.90)
			_demo_pos.y = clampf(_demo_pos.y - 0.04, 0.18, 0.86)
			_set_escapist_demo_status("SALTO LARGO", 0.9)
		Enums.EscapistAnimal.RAT:
			var ally := _demo_entities["ally"] as Vector2
			_demo_entities["ally"] = ally.move_toward(_demo_pos, 0.34)
			_set_escapist_demo_status("ALIADO RESCATADO", 1.0)
		Enums.EscapistAnimal.SQUIRREL:
			_demo_entities["trap_alive"] = false
			_set_escapist_demo_status("TRAMPA ROTA", 1.0)
		Enums.EscapistAnimal.FLY:
			_demo_entities["counter_timer"] = 1.25
			if _fly_counter_can_trigger():
				_demo_entities["counter_timer"] = 0.0
				_demo_entities["boost_timer"] = 0.55
				_demo_pos.x = clampf(_demo_pos.x + 0.20, 0.10, 0.90)
				_set_escapist_demo_status("IMPULSO ACTIVADO", 0.9)
			else:
				_set_escapist_demo_status("CONTRAATAQUE LISTO", 1.0)


func _fly_counter_can_trigger() -> bool:
	if _demo_entities.is_empty():
		return false
	var opponent := _demo_entities["opponent"] as Vector2
	if _demo_pos.distance_to(opponent) < 0.22:
		return true
	if _demo_entities.get("trap_alive", true) as bool:
		var trap := _demo_entities["trap"] as Vector2
		return _demo_pos.distance_to(trap) < 0.24
	return false


func _set_escapist_demo_status(text: String, duration: float) -> void:
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
			if font.get_string_size(trimmed, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x <= max_width:
				lines[max_lines - 1] = trimmed
				break
			last_line = last_line.substr(0, last_line.length() - 1).strip_edges()

	for i in lines.size():
		draw_string(font, position + Vector2(0, i * line_height),
			lines[i], HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)

	return lines.size() * line_height


func _player_display_name(player_index: int) -> String:
	return "USUARIO %d" % (player_index + 1) if player_index < 100 else "BOT"


func _format_player_names(player_indices: Array[int]) -> String:
	var names: Array[String] = []
	for pi: int in player_indices:
		names.append(_player_display_name(pi))
	return ", ".join(names)


func _draw_selection_badge(font: Font, rect: Rect2, text: String, color: Color,
		is_confirmed: bool) -> void:
	var fill_alpha := 0.34 if is_confirmed else 0.18
	var border_alpha := 0.95 if is_confirmed else 0.62
	draw_rect(rect, Color(0.0, 0.0, 0.0, 0.68))
	draw_rect(rect, Color(color, fill_alpha))
	draw_rect(rect, Color(color, border_alpha), false, 1.5)
	_draw_centered_text_in_rect(font, text, rect, 14 if is_confirmed else 12,
		Color.WHITE if is_confirmed else Color(0.86, 0.86, 0.86))


func _draw_character_index(font: Font, origin: Vector2, current_index: int) -> void:
	var chip_size := Vector2(28.0, 22.0)
	var gap := 5.0
	for i in _animals.size():
		var animal_data: Dictionary = _animals[i]
		var chip_color: Color = animal_data.get("color", Color.WHITE) as Color
		var chip_name: String = animal_data.get("name", "") as String
		var chip_label := chip_name.substr(0, 1)
		var selected := i == current_index
		var rect := Rect2(origin + Vector2(float(i) * (chip_size.x + gap), 0.0), chip_size)
		draw_rect(rect, Color(0.0, 0.0, 0.0, 0.72))
		draw_rect(rect, Color(chip_color, 0.42 if selected else 0.12))
		draw_rect(rect, Color(chip_color, 0.95 if selected else 0.34), false, 1.5 if selected else 1.0)
		_draw_centered_text_in_rect(font, chip_label, rect, 12, Color.WHITE if selected else Color(0.64, 0.64, 0.66))


func _draw_side_arrows(font: Font, rect: Rect2, color: Color) -> void:
	var pulse := 0.5 + 0.5 * sin(float(Time.get_ticks_msec()) / 1000.0 * TAU * 1.35)
	var arrow_color := Color(color, 0.50 + 0.25 * pulse)
	var fill := Color(color, 0.08 + 0.07 * pulse)
	var arrow_y := rect.position.y + rect.size.y * 0.45 - 17.0
	var left_rect := Rect2(rect.position.x + 12.0, arrow_y, 30.0, 34.0)
	var right_rect := Rect2(rect.end.x - 42.0, arrow_y, 30.0, 34.0)
	draw_rect(left_rect, Color(0.0, 0.0, 0.0, 0.36))
	draw_rect(left_rect, fill)
	draw_rect(left_rect, arrow_color, false, 1.0)
	draw_rect(right_rect, Color(0.0, 0.0, 0.0, 0.36))
	draw_rect(right_rect, fill)
	draw_rect(right_rect, arrow_color, false, 1.0)
	_draw_centered_text_in_rect(font, "<", left_rect, 24, arrow_color)
	_draw_centered_text_in_rect(font, ">", right_rect, 24, arrow_color)


func _draw_testing_prompt(font: Font, rect: Rect2, color: Color) -> void:
	var pulse := 0.55 + 0.45 * absf(sin(float(Time.get_ticks_msec()) / 1000.0 * TAU * 1.18))
	var prompt_rect := Rect2(
		rect.position.x,
		rect.position.y,
		rect.size.x,
		24.0
	)
	draw_rect(prompt_rect, Color(0.0, 0.0, 0.0, 0.58 + 0.18 * pulse))
	draw_rect(prompt_rect, Color(color, 0.18 + 0.36 * pulse))
	draw_rect(prompt_rect, Color(color, 0.52 + 0.42 * pulse), false, 1.4)
	_draw_centered_text_in_rect(font, "¡¡Entrá en Modo Testing apretando Y!!",
		prompt_rect, 13, Color(1.0, 0.98, 0.18, 0.72 + 0.28 * pulse))


func _draw_start_blocked_message(font: Font, screen: Vector2, color: Color) -> void:
	if _blocked_start_message_timer <= 0.0:
		return
	var fade := clampf(_blocked_start_message_timer / BLOCKED_START_MESSAGE_DURATION, 0.0, 1.0)
	var pulse := 0.5 + 0.5 * sin(float(Time.get_ticks_msec()) / 1000.0 * TAU * 2.0)
	var panel := Rect2(Vector2(screen.x * 0.5 - 360.0, screen.y * 0.5 - 48.0), Vector2(720.0, 96.0))
	draw_rect(panel.grow(10.0), Color(color, 0.12 * fade + 0.10 * pulse * fade))
	draw_rect(panel, Color(0.0, 0.0, 0.0, 0.86 * fade))
	draw_rect(panel, Color(color, 0.92 * fade), false, 2.4)
	_draw_centered_text_in_rect(font, "Falta que todos elijan su personaje",
		Rect2(panel.position.x + 18.0, panel.position.y + 20.0, panel.size.x - 36.0, 28.0),
		23, Color(1.0, 0.96, 0.28, fade))
	_draw_centered_text_in_rect(font, "Usá A para elegir o B para cambiar la selección.",
		Rect2(panel.position.x + 18.0, panel.position.y + 54.0, panel.size.x - 36.0, 22.0),
		14, Color(0.9, 0.9, 0.9, 0.86 * fade))


func _draw() -> void:
	var screen := get_viewport_rect().size
	var cx := screen.x / 2.0
	var font := ThemeDB.fallback_font

	draw_rect(Rect2(Vector2.ZERO, screen), Color(0.015, 0.015, 0.018, 1.0))
	draw_rect(Rect2(Vector2.ZERO, Vector2(screen.x, 410.0)), Color(0.04, 0.05, 0.04, 0.18))

	var title := "ELIGE TU ESCAPISTA"
	if _survival_mode:
		title = "ELIGE TU ESCAPISTA SURVIVAL"
	_draw_centered_text_in_rect(font, title, Rect2(cx - 260.0, 34.0, 520.0, 38.0), 30, Color.WHITE)

	var team_name := Enums.team_name(_escapist_team)
	var team_col := Enums.team_color(_escapist_team)
	var sub := "%s elige escapistas" % team_name
	if _survival_mode:
		sub = "%s elige escapistas con habilidades por llave" % team_name
	_draw_centered_text_in_rect(font, sub, Rect2(cx - 260.0, 72.0, 520.0, 24.0), 16, team_col)
	var menu_hint := "Menú: A elige, B deselecciona, Y testing. En partida los escapistas usan A. Start continúa y Select vuelve."
	if _survival_mode:
		menu_hint = "Survival: habilidades dormidas hasta llave, cooldown 20s. Y abre testing con zombies y trampas survival."
	_draw_centered_text_in_rect(font, menu_hint,
		Rect2(cx - 520.0, 96.0, 1040.0, 18.0), 13, Color(0.62, 0.64, 0.66))
	_draw_testing_prompt(font, Rect2(cx - 330.0, 118.0, 660.0, 24.0), team_col)

	var card_count := _animals.size()
	var columns := 2
	var rows := int(ceili(float(card_count) / float(columns)))
	var row_gap := 22.0
	var available_w := maxf(760.0, screen.x - 260.0)
	var card_w := clampf((available_w - float(columns - 1) * CARD_GAP) / float(columns), 360.0, 700.0)
	var card_h := clampf((screen.y - 274.0 - float(rows - 1) * row_gap) / float(rows), 256.0, 410.0)
	var total_w := float(columns) * card_w + float(columns - 1) * CARD_GAP
	var cards_x := cx - total_w / 2.0
	var cards_y := CARDS_Y

	for i in SLOT_COUNT:
		var col := i % columns
		var row := int(floor(float(i) / float(columns)))
		var card_x := cards_x + float(col) * (card_w + CARD_GAP)
		var card_y := cards_y + float(row) * (card_h + row_gap)
		var card_rect := Rect2(Vector2(card_x, card_y), Vector2(card_w, card_h))
		var player_index := _get_slot_player(i)
		if player_index < 0:
			_draw_panel(card_rect, Color(0.045, 0.045, 0.052, 0.88), Color(0.18, 0.18, 0.2, 0.72), 1.5)
			draw_rect(Rect2(card_rect.position, Vector2(card_rect.size.x, 5.0)), Color(0.18, 0.18, 0.2, 0.85))
			_draw_centered_text_in_rect(font, "SLOT LIBRE",
				Rect2(card_x, card_y + card_h * 0.42, card_w, 28.0), 18, Color(0.45, 0.45, 0.48))
			_draw_centered_text_in_rect(font, "Sin usuario eligiendo",
				Rect2(card_x, card_y + card_h * 0.50, card_w, 22.0), 12, Color(0.34, 0.34, 0.38))
			continue

		var animal_index: int = _player_cursor[player_index] as int
		var animal_data: Dictionary = _animals[animal_index]
		var animal_color: Color = animal_data["color"] as Color
		var animal_name: String = animal_data["name"] as String
		var animal_sub: String = animal_data["subtitle"] as String
		var animal_id: Enums.EscapistAnimal = animal_data["id"] as Enums.EscapistAnimal
		var ability: Dictionary = animal_data["ability"] as Dictionary

		var confirmed: bool = _player_confirmed.get(player_index, false)
		var taken_by: int = _get_confirmed_animal_owner(animal_index, player_index)
		var confirmed_pi: int = player_index
		var hovering_pis: Array[int] = [player_index]
		var preview_pis: Array[int] = []
		var bg_color := Color(0.095, 0.095, 0.105)
		if confirmed:
			bg_color = Color(animal_color, 0.23)
		var border_color := animal_color if confirmed else Color(animal_color, 0.82)
		if taken_by >= 0 and not confirmed:
			border_color = Color(1.0, 0.18, 0.12, 0.92)
		_draw_panel(card_rect, bg_color, border_color, 4.0 if confirmed else 2.0)
		if confirmed:
			draw_rect(card_rect.grow(-6.0), Color(animal_color, 0.18), false, 1.5)
		draw_rect(Rect2(card_rect.position, Vector2(card_rect.size.x, 7.0 if confirmed else 5.0)),
			Color(animal_color, 1.0 if confirmed else 0.92))
		_draw_character_index(font, Vector2(card_x + CARD_MARGIN, card_y + 12.0), animal_index)
		_draw_selection_badge(font,
			Rect2(card_x + card_w - CARD_MARGIN - 170.0, card_y + 12.0, 170.0, 24.0),
			_player_display_name(player_index), animal_color, confirmed)
		_draw_side_arrows(font, card_rect, animal_color)

		var art_h := clampf(card_h * 0.54, 145.0, 225.0)
		var art_rect := Rect2(card_x + CARD_MARGIN, card_y + 62.0, card_w - CARD_MARGIN * 2.0, art_h)
		draw_rect(art_rect, Color(animal_color, 0.10))
		draw_rect(art_rect, Color(animal_color, 0.25), false, 1.0)
		var demo_running := _is_viewer_testing(player_index)
		if demo_running:
			_draw_centered_text_in_rect(font, "PRUEBA REAL",
				art_rect, 12, Color(animal_color, 0.9))
		else:
			_draw_escapist_sprite_preview(animal_id, art_rect, animal_color)

		_draw_centered_text_in_rect(font, animal_name, Rect2(card_x, card_y + CARD_TOP_PAD, card_w, 26.0), 22, animal_color)

		_draw_centered_text_in_rect(font, animal_sub, Rect2(card_x, card_y + 42.0, card_w, 18.0), 12, Color(0.62, 0.62, 0.64))

		var ability_button: String = ability["button"] as String
		var ability_title: String = ability["name"] as String
		var ability_name := "[%s] %s" % [ability_button, ability_title]
		var text_x := card_x + CARD_MARGIN
		var text_w := card_w - CARD_MARGIN * 2.0
		var ability_y := art_rect.end.y + 24.0
		draw_line(Vector2(text_x, ability_y - 13.0), Vector2(text_x + text_w, ability_y - 13.0),
			Color(animal_color, 0.24), 1.0)
		draw_string(font, Vector2(text_x, ability_y),
			ability_name, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(0.9, 0.9, 0.9))
		_draw_wrapped_text(font, ability["desc"] as String, Vector2(text_x, ability_y + 22.0),
			text_w, 12, Color(0.62, 0.62, 0.62), 16.0, 4)

		if confirmed:
			_draw_selection_badge(font,
				Rect2(card_x + CARD_MARGIN, card_y + card_h - 42.0, card_w - CARD_MARGIN * 2.0, 28.0),
				"%s ELIGIÓ" % _player_display_name(player_index), animal_color, true)
		elif taken_by >= 0:
			_draw_selection_badge(font,
				Rect2(card_x + CARD_MARGIN, card_y + card_h - 40.0, card_w - CARD_MARGIN * 2.0, 26.0),
				"YA ELEGIDO POR %s" % _player_display_name(taken_by), Color(1.0, 0.18, 0.12), false)
		else:
			_draw_selection_badge(font,
				Rect2(card_x + CARD_MARGIN, card_y + card_h - 40.0, card_w - CARD_MARGIN * 2.0, 26.0),
				"%s ELIGIENDO" % _player_display_name(player_index), animal_color, false)
		continue

		if confirmed:
			var taken_label := "%s ELIGIÓ" % _player_display_name(confirmed_pi)
			_draw_selection_badge(font,
				Rect2(card_x + CARD_MARGIN, card_y + card_h - 42.0, card_w - CARD_MARGIN * 2.0, 28.0),
				taken_label, animal_color, true)
		elif not hovering_pis.is_empty():
			var hover_text := "%s ELIGIENDO" % _format_player_names(hovering_pis)
			_draw_selection_badge(font,
				Rect2(card_x + CARD_MARGIN, card_y + card_h - 40.0, card_w - CARD_MARGIN * 2.0, 26.0),
				hover_text, animal_color, false)
		elif not preview_pis.is_empty():
			var preview_text := "%s PROBANDO" % _format_player_names(preview_pis)
			_draw_selection_badge(font,
				Rect2(card_x + CARD_MARGIN, card_y + card_h - 40.0, card_w - CARD_MARGIN * 2.0, 26.0),
				preview_text, animal_color, false)

	var trapper_pis: Array[int] = []
	for pi: int in _player_indices:
		if not _is_escapist_player(pi):
			trapper_pis.append(pi)
	if not trapper_pis.is_empty():
		var trapper_labels: Array[String] = []
		for pi: int in trapper_pis:
			trapper_labels.append(_player_display_name(pi))
		var trapper_team := Enums.Team.TEAM_2 if _escapist_team == Enums.Team.TEAM_1 else Enums.Team.TEAM_1
		var trapper_text := "Cazadores: %s" % ", ".join(trapper_labels)
		var trapper_width := font.get_string_size(trapper_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x
		var grid_bottom := cards_y + float(rows) * card_h + float(rows - 1) * row_gap
		var wait_y := minf(grid_bottom + 24.0, screen.y - 84.0)
		var wait_rect := Rect2(cx - 230.0, wait_y, 460.0, 30.0)
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
		var status_mark := "ELEGIDO" if confirmed else "ELIGIENDO"
		var label := "%s: %s %s" % [_player_display_name(pi), status_name, status_mark]
		var label_width := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x
		draw_string(font, Vector2(cx - label_width / 2.0, status_y),
			label, HORIZONTAL_ALIGNMENT_LEFT, -1, 14,
			Color.YELLOW if confirmed else Color(0.6, 0.6, 0.6))
		status_y += 20.0
	for pi: int in _viewer_cursor:
		var idx: int = _viewer_cursor[pi] as int
		var animal_data2: Dictionary = _animals[idx]
		var status_name: String = animal_data2["name"] as String
		var status_mark := "PROBANDO" if _is_viewer_testing(pi) else "MIRANDO"
		var label := "%s: %s %s" % [_player_display_name(pi), status_name, status_mark]
		var label_width := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x
		draw_string(font, Vector2(cx - label_width / 2.0, status_y),
			label, HORIZONTAL_ALIGNMENT_LEFT, -1, 14,
			Color(0.58, 0.75, 1.0) if _is_viewer_testing(pi) else Color(0.48, 0.52, 0.58))
		status_y += 20.0

	var hint := "A elegir | B deseleccionar | Y testing | Izq./Der. cambiar | Select cancelar"
	if _allow_back:
		hint = "A elegir | B deseleccionar | Y testing | Izq./Der. cambiar | Select volver"
	if _selection_complete():
		hint = "Start continuar | B cambiar selección | Y testing | Select volver" if _allow_back else "Start continuar | B cambiar selección | Y testing"
	var hint_width := font.get_string_size(hint, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x
	draw_string(font, Vector2(cx - hint_width / 2.0, screen.y - 30),
		hint, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color.YELLOW)
	_draw_start_blocked_message(font, screen, team_col)


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
	var trap_norm := _demo_entities.get("trap", Vector2(0.76, 0.72)) as Vector2
	var trap := rect.position + Vector2(trap_norm.x * rect.size.x, trap_norm.y * rect.size.y)
	var trap_alive := _demo_entities.get("trap_alive", true) as bool
	if trap_alive:
		draw_rect(Rect2(trap - Vector2(9.0, 9.0), Vector2(18.0, 18.0)), Color(1.0, 0.22, 0.18, 0.72))
		draw_rect(Rect2(trap - Vector2(11.0, 11.0), Vector2(22.0, 22.0)), Color(1.0, 0.72, 0.18, 0.55), false, 1.2)
	else:
		draw_line(trap + Vector2(-12.0, -9.0), trap + Vector2(12.0, 9.0), Color(0.8, 0.8, 0.8, 0.55), 2.0)
		draw_line(trap + Vector2(-12.0, 9.0), trap + Vector2(12.0, -9.0), Color(0.8, 0.8, 0.8, 0.55), 2.0)

	var ally_norm := _demo_entities.get("ally", Vector2(0.78, 0.30)) as Vector2
	var ally := rect.position + Vector2(ally_norm.x * rect.size.x, ally_norm.y * rect.size.y)
	if animal_id == Enums.EscapistAnimal.RAT:
		draw_circle(ally, 8.0, Color(0.25, 0.85, 1.0, 0.82))
		draw_string(font, ally + Vector2(-10.0, -12.0), "ALIADO", HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(0.65, 0.95, 1.0))

	var opponent_norm := _demo_entities.get("opponent", Vector2(0.80, 0.58)) as Vector2
	var opponent := rect.position + Vector2(opponent_norm.x * rect.size.x, opponent_norm.y * rect.size.y)
	if animal_id == Enums.EscapistAnimal.FLY:
		draw_circle(opponent, 8.5, Color(1.0, 0.18, 0.16, 0.86))
		draw_string(font, opponent + Vector2(-12.0, -12.0), "GOLPE", HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(1.0, 0.55, 0.45))

	var player := rect.position + Vector2(_demo_pos.x * rect.size.x, _demo_pos.y * rect.size.y)
	for effect: Dictionary in _demo_effects:
		var t := clampf((effect["time"] as float) / (effect["duration"] as float), 0.0, 1.0)
		_draw_escapist_demo_effect(rect, player, ally, trap, animal_id, color, t)
	draw_circle(player, 11.0, Color(color, 0.95))
	draw_arc(player, 14.0, 0.0, TAU, 18, Color.WHITE, 1.4)
	var status := _demo_entities.get("status", "") as String
	if not status.is_empty():
		_draw_centered_text_in_rect(font, status,
			Rect2(rect.position.x, rect.position.y + 8.0, rect.size.x, 18.0), 11, Color.YELLOW)
	draw_string(font, rect.position + Vector2(9.0, rect.size.y - 9.0),
		"Select salir | A habilidad", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(color, 0.9))


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


func _draw_escapist_sprite_preview(animal: Enums.EscapistAnimal, rect: Rect2, color: Color) -> void:
	var texture := _get_escapist_preview_texture(animal)
	if texture == null:
		_draw_escapist_silhouette(animal, rect.position + rect.size * 0.5 + Vector2(0.0, 4.0),
			3.65, Color(color, 1.0))
		return
	var portrait_rect := _fit_texture_in_rect(texture, rect.grow(-8.0))
	draw_texture_rect(texture, portrait_rect, false)
	draw_rect(portrait_rect, Color(color, 0.24), false, 1.0)


func _get_escapist_preview_texture(animal: Enums.EscapistAnimal) -> Texture2D:
	var key := int(animal)
	if _escapist_sprite_cache.has(key):
		return _escapist_sprite_cache[key] as Texture2D
	var asset_name := _get_escapist_asset_name(animal)
	var path := "res://assets/ui/selection_portraits/%s.png" % asset_name
	var image := Image.new()
	if image.load(path) != OK:
		_escapist_sprite_cache[key] = null
		return null
	var texture := ImageTexture.create_from_image(image)
	_escapist_sprite_cache[key] = texture
	return texture


func _fit_texture_in_rect(texture: Texture2D, rect: Rect2) -> Rect2:
	var size := texture.get_size()
	if size.x <= 0.0 or size.y <= 0.0:
		return rect
	var scale := minf(rect.size.x / size.x, rect.size.y / size.y)
	var target_size := size * scale
	var pos := rect.position + (rect.size - target_size) * 0.5
	return Rect2(pos, target_size)


func _get_escapist_asset_name(animal: Enums.EscapistAnimal) -> String:
	match animal:
		Enums.EscapistAnimal.RABBIT:
			return "rabbit"
		Enums.EscapistAnimal.RAT:
			return "rat"
		Enums.EscapistAnimal.SQUIRREL:
			return "squirrel"
		Enums.EscapistAnimal.FLY:
			return "fly"
	return "rabbit"


func _get_escapist_preview_target_size(animal: Enums.EscapistAnimal) -> Vector2:
	match animal:
		Enums.EscapistAnimal.RAT:
			return Vector2(130.0, 58.0)
		Enums.EscapistAnimal.SQUIRREL:
			return Vector2(150.0, 88.0)
		Enums.EscapistAnimal.FLY:
			return Vector2(142.0, 88.0)
	return Vector2(120.0, 86.0)


func _get_escapist_preview_offset(animal: Enums.EscapistAnimal) -> Vector2:
	match animal:
		Enums.EscapistAnimal.RAT:
			return Vector2(0.0, 7.0)
		Enums.EscapistAnimal.FLY:
			return Vector2(0.0, 4.0)
	return Vector2.ZERO


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
