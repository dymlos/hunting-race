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
		queue_redraw()
		return

	if player_index >= 100:
		if bot_ai_enabled:
			_process_bot(delta)
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


func _draw() -> void:
	var char_color := Enums.trapper_character_color(trapper_character)
	if trapper_character == Enums.TrapperCharacter.NONE:
		char_color = player_color

	# Crosshair cursor
	var size := 12.0
	var color := Color(char_color, 0.8)
	draw_line(Vector2(-size, 0), Vector2(size, 0), color, 2.0)
	draw_line(Vector2(0, -size), Vector2(0, size), color, 2.0)
	draw_arc(Vector2.ZERO, size * 0.7, 0, TAU, 12, color, 1.5)

	# Player label
	var label := "P%d" % (player_index + 1)
	if player_index >= 100:
		label = "BOT"
	draw_string(ThemeDB.fallback_font, Vector2(-10, -size - 4),
		label, HORIZONTAL_ALIGNMENT_CENTER, -1, 10, color)

	# Character name
	var char_name := Enums.trapper_character_name(trapper_character)
	if char_name != "None":
		var name_w := ThemeDB.fallback_font.get_string_size(char_name, HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x
		draw_string(ThemeDB.fallback_font, Vector2(-name_w / 2.0, -size - 14),
			char_name, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(char_color, 0.6))

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
	var indicator_y := size + 14.0
	for i in _abilities.size():
		var ability: TrapperAbility = _abilities[i]
		var a_color := ability.get_display_color()

		# Active count and remaining charge
		var use_text := "S%d C%d" % [
			ability.get_strategy_uses_remaining(),
			ability.get_charges_remaining(),
		]
		var count_text := "A%d %s" % [ability.get_active_count(), use_text]
		draw_string(ThemeDB.fallback_font, Vector2(-10, indicator_y),
			count_text, HORIZONTAL_ALIGNMENT_CENTER, -1, 7, Color(a_color, 0.7))

		# Cooldown arc
		var ratio := ability.get_cooldown_ratio()
		if ratio > 0.0:
			var arc_radius := size + 4.0 + i * 4.0
			draw_arc(Vector2.ZERO, arc_radius,
				-PI / 2.0, -PI / 2.0 + TAU * (1.0 - ratio),
				12, Color(a_color, 0.4), 2.0)

		indicator_y += 10.0

	# Draw ability placement previews
	for ability: TrapperAbility in _abilities:
		ability.draw_preview(self)
