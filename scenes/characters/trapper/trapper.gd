class_name Trapper
extends Node2D

## Trapper cursor — non-physical entity that moves freely and places abilities.

var player_index: int = 0
var team: Enums.Team = Enums.Team.NONE
var role: Enums.Role = Enums.Role.TRAPPER
var player_color: Color = Color.WHITE
var input_locked: bool = true
var trapper_character: Enums.TrapperCharacter = Enums.TrapperCharacter.NONE
var bot_ai_enabled: bool = false

var _abilities: Array[TrapperAbility] = []  # 3 abilities: [A, RB, X]
var _map_bounds: Rect2 = Rect2()
var _spent_ability_indices: Dictionary = {}
var _set_reload_timer: float = 0.0
var _floating_text: String = ""
var _floating_text_timer: float = 0.0
var _floating_text_color: Color = Color.WHITE
var _animal_mark_alpha: float = 0.78
var _last_mark_position: Vector2 = Vector2.ZERO

# Bot AI state
var _bot_target: Vector2 = Vector2.ZERO
var _bot_move_timer: float = 0.0
var _bot_ability_timer: float = 2.0  # Delay before first ability use

# Button mappings for the 3 abilities
const ABILITY_BUTTONS: Array[StringName] = [&"dash", &"ability", &"interact"]  # A, RB, X


func setup(map_size: Vector2) -> void:
	_map_bounds = Rect2(Vector2.ZERO, map_size)
	bot_ai_enabled = GameManager.settings_overrides.get(&"bot_ai", false) as bool
	_spent_ability_indices.clear()
	_set_reload_timer = 0.0
	_floating_text = ""
	_floating_text_timer = 0.0
	_animal_mark_alpha = 0.78
	_last_mark_position = position
	_setup_abilities()


func _setup_abilities() -> void:
	_abilities.clear()
	var ability_classes := _get_ability_classes()
	for i in range(ability_classes.size()):
		var ability_class: GDScript = ability_classes[i]
		var ability: TrapperAbility = ability_class.new() as TrapperAbility
		ability.setup(self)
		ability.reset_round_uses()
		ability.escape_charge_used.connect(_on_ability_escape_charge_used.bind(i))
		_abilities.append(ability)


func _get_ability_classes() -> Array[GDScript]:
	match trapper_character:
		Enums.TrapperCharacter.ARANA:
			return [
				preload("res://scenes/characters/trapper/abilities/arana/expansive_web.gd"),
				preload("res://scenes/characters/trapper/abilities/arana/elastic_web.gd"),
				preload("res://scenes/characters/trapper/abilities/arana/persistent_venom.gd"),
			]
		Enums.TrapperCharacter.HONGO:
			return [
				preload("res://scenes/characters/trapper/abilities/hongo/confusing_mushroom.gd"),
				preload("res://scenes/characters/trapper/abilities/hongo/toxic_spore_zone.gd"),
				preload("res://scenes/characters/trapper/abilities/hongo/fungal_teleport.gd"),
			]
		Enums.TrapperCharacter.ESCORPION:
			return [
				preload("res://scenes/characters/trapper/abilities/escorpion/buried_stinger.gd"),
				preload("res://scenes/characters/trapper/abilities/escorpion/quicksand.gd"),
				preload("res://scenes/characters/trapper/abilities/escorpion/crushing_pincers.gd"),
			]
		Enums.TrapperCharacter.PULPO:
			return [
				preload("res://scenes/characters/trapper/abilities/pulpo/ink_stain.gd"),
				preload("res://scenes/characters/trapper/abilities/pulpo/binding_tentacle.gd"),
				preload("res://scenes/characters/trapper/abilities/pulpo/water_current.gd"),
			]
	return []


func get_role() -> Enums.Role:
	return Enums.Role.TRAPPER


func get_team() -> Enums.Team:
	return team


func freeze_character() -> void:
	input_locked = true


func unfreeze_character() -> void:
	input_locked = false


func _process(delta: float) -> void:
	# Update abilities even when locked (for cooldown ticking)
	for ability: TrapperAbility in _abilities:
		ability.update(delta)
	_update_set_reload(delta)
	_update_floating_text(delta)

	if input_locked:
		_update_animal_mark_alpha(delta)
		queue_redraw()
		return

	if player_index >= 100:
		if bot_ai_enabled:
			_process_bot(delta)
		_update_animal_mark_alpha(delta)
		queue_redraw()
		return

	# Move cursor with left stick
	var speed_mult: float = GameManager.settings_overrides.get(&"trapper_speed", 1.0) as float
	var move_vec := InputManager.get_move_vector(player_index)
	position += move_vec * Constants.TRAPPER_CURSOR_SPEED * speed_mult * delta
	# Clamp to map bounds
	position.x = clampf(position.x, _map_bounds.position.x, _map_bounds.end.x)
	position.y = clampf(position.y, _map_bounds.position.y, _map_bounds.end.y)

	# Handle ability input
	for i in _abilities.size():
		if i >= ABILITY_BUTTONS.size():
			break
		var action: StringName = ABILITY_BUTTONS[i]
		if InputManager.is_action_just_pressed(player_index, action):
			_abilities[i].activate()

	# B to cancel multi-point placement
	if InputManager.is_action_just_pressed(player_index, &"cancel"):
		for ability: TrapperAbility in _abilities:
			if ability.is_placing:
				ability.cancel_placement()

	_update_animal_mark_alpha(delta)
	queue_redraw()


func _process_bot(delta: float) -> void:
	# Move toward random target
	_bot_move_timer -= delta
	if _bot_move_timer <= 0.0:
		_bot_target = Vector2(
			randf_range(_map_bounds.position.x + 30, _map_bounds.end.x - 30),
			randf_range(_map_bounds.position.y + 30, _map_bounds.end.y - 30)
		)
		_bot_move_timer = randf_range(1.5, 4.0)

	var dir := (_bot_target - position).normalized()
	var dist := position.distance_to(_bot_target)
	if dist > 10.0:
		position += dir * Constants.TRAPPER_CURSOR_SPEED * delta
	position.x = clampf(position.x, _map_bounds.position.x, _map_bounds.end.x)
	position.y = clampf(position.y, _map_bounds.position.y, _map_bounds.end.y)

	# Use abilities periodically
	_bot_ability_timer -= delta
	if _bot_ability_timer <= 0.0:
		# Pick a random ability that can activate
		var available: Array[int] = []
		for i in _abilities.size():
			if _abilities[i].can_activate():
				available.append(i)
		if not available.is_empty():
			var idx: int = available[randi() % available.size()]
			_abilities[idx].activate()
			# For multi-point abilities, immediately place remaining points nearby
			if _abilities[idx].is_placing:
				for _j in _abilities[idx].points_required:
					_abilities[idx].activate()
		_bot_ability_timer = randf_range(3.0, 8.0)


func _on_ability_escape_charge_used(_ability: TrapperAbility, ability_index: int) -> void:
	if GameManager.current_state != Enums.GameState.ESCAPE:
		return
	_spent_ability_indices[ability_index] = true
	if _spent_ability_indices.size() >= _abilities.size() and _set_reload_timer <= 0.0:
		_set_reload_timer = Constants.TRAPPER_SET_RELOAD_DELAY


func _update_set_reload(delta: float) -> void:
	if _set_reload_timer <= 0.0:
		return
	if GameManager.current_state != Enums.GameState.ESCAPE:
		_set_reload_timer = 0.0
		_spent_ability_indices.clear()
		return
	_set_reload_timer -= delta
	if _set_reload_timer > 0.0:
		return
	for ability: TrapperAbility in _abilities:
		ability.refill_charges()
	_spent_ability_indices.clear()
	_show_floating_text("Reloaded !!", Color.WHITE)


func _show_floating_text(text: String, text_color: Color) -> void:
	_floating_text = text
	_floating_text_color = text_color
	_floating_text_timer = Constants.FLOATING_TEXT_DURATION
	queue_redraw()


func _update_floating_text(delta: float) -> void:
	if _floating_text_timer <= 0.0:
		return
	_floating_text_timer = maxf(_floating_text_timer - delta, 0.0)
	if _floating_text_timer <= 0.0:
		_floating_text = ""
	queue_redraw()


func _update_animal_mark_alpha(delta: float) -> void:
	var speed := 0.0
	if delta > 0.0:
		speed = position.distance_to(_last_mark_position) / delta
	_last_mark_position = position
	var move_ratio := clampf(speed / maxf(Constants.TRAPPER_CURSOR_SPEED, 1.0), 0.0, 1.0)
	_animal_mark_alpha = lerpf(0.78, 0.34, move_ratio)


func _draw_filled_ellipse(center: Vector2, radii: Vector2, fill_color: Color, point_count: int = 18) -> void:
	var points := PackedVector2Array()
	for i in range(point_count):
		var angle := TAU * float(i) / float(point_count)
		points.append(center + Vector2(cos(angle) * radii.x, sin(angle) * radii.y))
	draw_colored_polygon(points, fill_color)


func _draw_trapper_character_mark(size: float, base_color: Color) -> void:
	var mark_color := Color(base_color, _animal_mark_alpha)
	match trapper_character:
		Enums.TrapperCharacter.ARANA:
			_draw_spider_mark(size, mark_color)
		Enums.TrapperCharacter.HONGO:
			_draw_mushroom_mark(size, mark_color)
		Enums.TrapperCharacter.ESCORPION:
			_draw_scorpion_mark(size, mark_color)
		Enums.TrapperCharacter.PULPO:
			_draw_octopus_mark(size, mark_color)


func _draw_spider_mark(size: float, mark_color: Color) -> void:
	for side in [-1.0, 1.0]:
		draw_polyline(PackedVector2Array([
			Vector2(side * 3.0, size * 0.45),
			Vector2(side * 8.5, size + 4.0),
			Vector2(side * 14.0, size + 2.0),
		]), mark_color, 1.8)
		draw_polyline(PackedVector2Array([
			Vector2(side * 1.8, size * 0.7),
			Vector2(side * 5.5, size + 8.0),
			Vector2(side * 10.5, size + 10.0),
		]), mark_color, 1.8)
		draw_polyline(PackedVector2Array([
			Vector2(side * 5.0, size * 0.2),
			Vector2(side * 11.0, size + 1.0),
			Vector2(side * 14.5, size - 3.5),
		]), mark_color, 1.8)


func _draw_mushroom_mark(size: float, mark_color: Color) -> void:
	var cap := PackedVector2Array([
		Vector2(-15.0, -size - 2.0),
		Vector2(-12.0, -size - 9.0),
		Vector2(-5.0, -size - 13.0),
		Vector2(5.0, -size - 13.0),
		Vector2(12.0, -size - 9.0),
		Vector2(15.0, -size - 2.0),
		Vector2(8.0, -size + 2.5),
		Vector2(-8.0, -size + 2.5),
	])
	draw_colored_polygon(cap, mark_color)
	draw_arc(Vector2.ZERO, size * 0.52, PI * 0.2, PI * 0.8, 8, mark_color, 2.0)
	draw_circle(Vector2(-5.5, -size - 6.0), 1.7, Color(1.0, 1.0, 1.0, 0.35))
	draw_circle(Vector2(4.5, -size - 8.0), 1.5, Color(1.0, 1.0, 1.0, 0.35))


func _draw_scorpion_mark(size: float, mark_color: Color) -> void:
	draw_arc(Vector2(size + 2.0, -1.0), 8.5, -PI * 0.2, PI * 1.15, 16, mark_color, 2.5)
	draw_colored_polygon(PackedVector2Array([
		Vector2(size + 9.0, -11.0),
		Vector2(size + 16.5, -13.0),
		Vector2(size + 12.5, -6.0),
	]), mark_color)
	draw_polyline(PackedVector2Array([
		Vector2(-size * 0.45, size * 0.3),
		Vector2(-size - 4.5, size * 0.7),
		Vector2(-size - 7.0, size * 0.25),
	]), mark_color, 2.0)
	draw_polyline(PackedVector2Array([
		Vector2(size * 0.45, size * 0.3),
		Vector2(size + 4.5, size * 0.7),
		Vector2(size + 7.0, size * 0.25),
	]), mark_color, 2.0)


func _draw_octopus_mark(size: float, mark_color: Color) -> void:
	_draw_filled_ellipse(Vector2(0.0, size * 0.55), Vector2(7.5, 5.0), mark_color)
	for x in [-8.0, -3.0, 3.0, 8.0]:
		var side := -1.0 if x < 0.0 else 1.0
		draw_polyline(PackedVector2Array([
			Vector2(x * 0.45, size * 0.75),
			Vector2(x, size + 8.0),
			Vector2(x + side * 3.0, size + 11.5),
		]), mark_color, 2.0)


func _draw_escape_charge_blocks(size: float) -> void:
	var block_size := Vector2(4.0, 4.0)
	var block_gap := 2.0
	var total_width := float(_abilities.size()) * block_size.x + float(maxi(_abilities.size() - 1, 0)) * block_gap
	var start_x := -total_width / 2.0
	var y := size + 12.0
	for i in _abilities.size():
		var ability: TrapperAbility = _abilities[i]
		if ability.get_charges_remaining() <= 0:
			continue
		var rect := Rect2(Vector2(start_x + float(i) * (block_size.x + block_gap), y), block_size)
		draw_rect(rect, Color(ability.get_display_color(), 0.78))


func _draw_player_label(label: String, position: Vector2, font_size: int, label_color: Color) -> void:
	var shadow_color := Color(0.0, 0.0, 0.0, 0.85)
	for offset in [
		Vector2(-1.0, 0.0),
		Vector2(1.0, 0.0),
		Vector2(0.0, -1.0),
		Vector2(0.0, 1.0),
	]:
		draw_string(ThemeDB.fallback_font, position + offset,
			label, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size, shadow_color)
	for offset in [Vector2.ZERO, Vector2(0.55, 0.0), Vector2(-0.55, 0.0)]:
		draw_string(ThemeDB.fallback_font, position + offset,
			label, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size, label_color)


func _draw() -> void:
	var char_color := Enums.trapper_character_color(trapper_character)
	if trapper_character == Enums.TrapperCharacter.NONE:
		char_color = player_color
	var team_color := Enums.team_color(team)

	# Crosshair cursor
	var size := 12.0
	var color := Color(char_color, 0.8)
	_draw_trapper_character_mark(size, char_color)
	draw_line(Vector2(-size, 0), Vector2(size, 0), color, 2.0)
	draw_line(Vector2(0, -size), Vector2(0, size), color, 2.0)
	draw_arc(Vector2.ZERO, size * 0.7, 0, TAU, 12, color, 1.5)

	# Player label
	var label := "P%d" % (player_index + 1)
	if player_index >= 100:
		label = "BOT"
	_draw_player_label(label, Vector2(-10, -size - 4), 12, team_color)

	if _floating_text_timer > 0.0 and not _floating_text.is_empty():
		var text_alpha := clampf(_floating_text_timer / Constants.FLOATING_TEXT_DURATION, 0.0, 1.0)
		var text_size := 18
		var text_w := ThemeDB.fallback_font.get_string_size(
			_floating_text, HORIZONTAL_ALIGNMENT_LEFT, -1, text_size).x
		var text_pos := Vector2(-text_w / 2.0, -size - 40)
		draw_string(ThemeDB.fallback_font, text_pos + Vector2(2.0, 2.0),
			_floating_text, HORIZONTAL_ALIGNMENT_LEFT, -1, text_size,
			Color(0.0, 0.0, 0.0, 0.65 * text_alpha))
		draw_string(ThemeDB.fallback_font, text_pos,
			_floating_text, HORIZONTAL_ALIGNMENT_LEFT, -1, text_size,
			Color(_floating_text_color, text_alpha))

	# Ability indicators
	_draw_escape_charge_blocks(size)
	for i in _abilities.size():
		var ability: TrapperAbility = _abilities[i]
		var a_color := ability.get_display_color()

		# Cooldown arc
		var ratio := ability.get_cooldown_ratio()
		if ratio > 0.0:
			var arc_radius := size + 4.0 + i * 4.0
			draw_arc(Vector2.ZERO, arc_radius,
				-PI / 2.0, -PI / 2.0 + TAU * (1.0 - ratio),
				12, Color(a_color, 0.4), 2.0)

	# Draw ability placement previews
	for ability: TrapperAbility in _abilities:
		ability.draw_preview(self)
