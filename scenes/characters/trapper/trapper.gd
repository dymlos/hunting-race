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

var _abilities: Array[TrapperAbility] = []  # 3 abilities: [A, X, Y]
var _map_bounds: Rect2 = Rect2()
var _spent_ability_indices: Dictionary = {}
var _set_reload_timer: float = 0.0
var _floating_text: String = ""
var _floating_text_timer: float = 0.0
var _floating_text_color: Color = Color.WHITE
var _ability_ready_flash_timer: float = 0.0
var _ability_ready_flash_color: Color = Color.WHITE
var _animal_mark_alpha: float = 0.78
var _last_mark_position: Vector2 = Vector2.ZERO

# Bot AI state
var _bot_target: Vector2 = Vector2.ZERO
var _bot_move_timer: float = 0.0
var _bot_ability_timer: float = 2.0  # Delay before first ability use
var _bot_mode: StringName = &"generic"
var _bot_path_a: Vector2 = Vector2.ZERO
var _bot_path_b: Vector2 = Vector2.ZERO
var _bot_path_target: Vector2 = Vector2.ZERO
var _bot_elapsed: float = 0.0
var _bot_next_ability_index: int = 0
var _bot_ability_schedule: Array[float] = [1.2, 3.8, 6.4]
var _bot_active_placement_index: int = -1
var _bot_placement_timer: float = 0.0
var _bot_cycle_delay: float = 0.0
var _bot_placement_points: Array[Vector2] = []
var _bot_blocked_timer: float = 0.0
var _bot_cycle_count: int = 0

# Button mappings for the 3 abilities
const ABILITY_BUTTONS: Array[StringName] = [&"dash", &"interact", &"ability"]  # A, X, Y


func setup(map_size: Vector2) -> void:
	_map_bounds = Rect2(Vector2.ZERO, map_size)
	bot_ai_enabled = GameManager.settings_overrides.get(&"bot_ai", false) as bool
	_bot_mode = &"generic"
	_bot_path_a = Vector2.ZERO
	_bot_path_b = Vector2.ZERO
	_bot_path_target = Vector2.ZERO
	_bot_elapsed = 0.0
	_bot_next_ability_index = 0
	_bot_active_placement_index = -1
	_bot_placement_timer = 0.0
	_bot_cycle_delay = 0.0
	_bot_placement_points.clear()
	_bot_blocked_timer = 0.0
	_bot_cycle_count = 0
	_spent_ability_indices.clear()
	_set_reload_timer = 0.0
	_floating_text = ""
	_floating_text_timer = 0.0
	_ability_ready_flash_timer = 0.0
	_animal_mark_alpha = 0.78
	_last_mark_position = position
	_setup_abilities()


func configure_spider_bot(path_a: Vector2, path_b: Vector2) -> void:
	bot_ai_enabled = true
	_bot_mode = &"spider"
	_configure_path_bot(path_a, path_b)


func configure_scorpion_bot(path_a: Vector2, path_b: Vector2) -> void:
	bot_ai_enabled = true
	_bot_mode = &"scorpion"
	_configure_path_bot(path_a, path_b)


func configure_mushroom_bot(path_a: Vector2, path_b: Vector2) -> void:
	bot_ai_enabled = true
	_bot_mode = &"mushroom"
	_configure_path_bot(path_a, path_b)


func configure_octopus_bot(path_a: Vector2, path_b: Vector2) -> void:
	bot_ai_enabled = true
	_bot_mode = &"octopus"
	_configure_path_bot(path_a, path_b)


func _configure_path_bot(path_a: Vector2, path_b: Vector2) -> void:
	_bot_path_a = path_a
	_bot_path_b = path_b
	_bot_path_target = path_b
	_bot_elapsed = 0.0
	_bot_next_ability_index = 0
	_bot_active_placement_index = -1
	_bot_placement_timer = 0.0
	_bot_cycle_delay = 0.0
	_bot_placement_points.clear()
	_bot_blocked_timer = 0.0
	_bot_cycle_count = 0
	_bot_move_timer = 0.0
	_bot_ability_timer = 1.2
	position = path_a
	_last_mark_position = position


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
				preload("res://scenes/characters/trapper/abilities/arana/persistent_venom.gd"),
				preload("res://scenes/characters/trapper/abilities/arana/elastic_web.gd"),
				preload("res://scenes/characters/trapper/abilities/arana/expansive_web.gd"),
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
	if _ability_ready_flash_timer > 0.0:
		_ability_ready_flash_timer = maxf(_ability_ready_flash_timer - delta, 0.0)
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
			if _abilities[i].can_activate() or _abilities[i].is_placing:
				_abilities[i].activate()
			else:
				_abilities[i].notify_cooldown_denied()

	# B to cancel multi-point placement
	if InputManager.is_action_just_pressed(player_index, &"cancel"):
		for ability: TrapperAbility in _abilities:
			if ability.is_placing:
				ability.cancel_placement()

	_update_animal_mark_alpha(delta)
	queue_redraw()


func _process_bot(delta: float) -> void:
	_bot_elapsed += delta
	if _bot_mode == &"spider" \
			or _bot_mode == &"scorpion" \
			or _bot_mode == &"mushroom" \
			or _bot_mode == &"octopus":
		_process_path_trap_bot(delta)
		return

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


func _process_path_trap_bot(delta: float) -> void:
	var move_speed := Constants.TRAPPER_CURSOR_SPEED * 0.6

	if _bot_active_placement_index >= 0:
		var active_ability: TrapperAbility = _abilities[_bot_active_placement_index]
		if not _bot_placement_points.is_empty():
			var placement_target: Vector2 = _bot_placement_points[0]
			var moved := _move_bot_toward(placement_target, move_speed * 1.15 * delta)
			_bot_blocked_timer = 0.0 if moved else _bot_blocked_timer + delta
			if _bot_blocked_timer >= 0.55:
				active_ability.activate()
				_bot_placement_points.pop_front()
				_bot_blocked_timer = 0.0
				if not active_ability.is_placing:
					_finish_bot_ability_placement()
				return
			if position.distance_to(placement_target) <= 8.0:
				active_ability.activate()
				_bot_placement_points.pop_front()
				_bot_blocked_timer = 0.0
				if not active_ability.is_placing:
					_finish_bot_ability_placement()
			return

		_bot_placement_timer -= delta
		if _bot_placement_timer <= 0.0:
			active_ability.activate()
			_bot_placement_timer = 0.22
			if not active_ability.is_placing:
				_finish_bot_ability_placement()
		return

	if _move_bot_toward(_bot_path_target, move_speed * delta):
		_bot_blocked_timer = 0.0
	else:
		_bot_blocked_timer += delta
		if _bot_blocked_timer >= 0.45:
			_bot_path_target = _bot_path_a if _bot_path_target == _bot_path_b else _bot_path_b
			_bot_blocked_timer = 0.0
	if position.distance_to(_bot_path_target) <= 8.0:
		_bot_path_target = _bot_path_a if _bot_path_target == _bot_path_b else _bot_path_b

	if _bot_next_ability_index >= _abilities.size():
		_bot_cycle_delay = maxf(_bot_cycle_delay - delta, 0.0)
		if _bot_cycle_delay <= 0.0:
			_bot_next_ability_index = 0
			_bot_elapsed = 0.0
			_bot_cycle_count += 1
		return
	var schedule_time := _bot_ability_schedule[_bot_next_ability_index] if _bot_next_ability_index < _bot_ability_schedule.size() else 9999.0
	if _bot_elapsed < schedule_time:
		return
	var ability := _abilities[_bot_next_ability_index]
	if not ability.can_activate():
		return
	if _bot_needs_placement_points(_bot_next_ability_index):
		_bot_placement_points = _get_bot_placement_points(_bot_next_ability_index)
		_bot_active_placement_index = _bot_next_ability_index
		return
	ability.activate()
	if ability.is_placing:
		_bot_active_placement_index = _bot_next_ability_index
		_bot_placement_timer = 0.22
	else:
		_bot_next_ability_index += 1
		if _bot_next_ability_index >= _abilities.size():
			_bot_cycle_delay = 2.0


func _finish_bot_ability_placement() -> void:
	_bot_active_placement_index = -1
	_bot_placement_points.clear()
	_bot_next_ability_index += 1
	if _bot_next_ability_index >= _abilities.size():
		_bot_cycle_delay = 2.0


func _bot_needs_placement_points(ability_index: int) -> bool:
	if _bot_mode == &"spider":
		return ability_index == 1 or ability_index == 2
	if _bot_mode == &"scorpion":
		return ability_index == 2
	if _bot_mode == &"mushroom":
		return ability_index == 2
	if _bot_mode == &"octopus":
		return ability_index == 2
	return false


func _get_bot_placement_points(ability_index: int) -> Array[Vector2]:
	if _bot_mode == &"scorpion":
		return _get_scorpion_bot_placement_points(ability_index)
	if _bot_mode == &"mushroom":
		return _get_mushroom_bot_placement_points(ability_index)
	if _bot_mode == &"octopus":
		return _get_octopus_bot_placement_points(ability_index)
	return _get_spider_bot_placement_points(ability_index)


func _get_spider_bot_placement_points(ability_index: int) -> Array[Vector2]:
	var forward := (_bot_path_b - _bot_path_a).normalized()
	if forward.length_squared() < 0.01:
		forward = Vector2.RIGHT
	var side := Vector2(-forward.y, forward.x)
	var center := position
	if ability_index == 1:
		return [
			_find_clear_bot_point(center - side * 105.0, center),
			_find_clear_bot_point(center + side * 105.0, center),
		]
	return [
		_find_clear_bot_point(center + side * 82.0, center),
		_find_clear_bot_point(center - forward * 82.0 - side * 62.0, center),
		_find_clear_bot_point(center + forward * 82.0 - side * 62.0, center),
	]


func _get_scorpion_bot_placement_points(_ability_index: int) -> Array[Vector2]:
	var forward := (_bot_path_b - _bot_path_a).normalized()
	if forward.length_squared() < 0.01:
		forward = Vector2.RIGHT
	var side := Vector2(-forward.y, forward.x)
	var pattern := _bot_cycle_count % 3
	var along_offsets: Array[float] = [-34.0, 0.0, 34.0]
	var half_gaps: Array[float] = [58.0, 74.0, 90.0]
	var side_offsets: Array[float] = [150.0, -150.0, 130.0]
	var center := position + forward * along_offsets[pattern] + side * side_offsets[pattern]
	var half_gap := half_gaps[pattern]
	return [
		_find_clear_bot_point(center - side * half_gap, center),
		_find_clear_bot_point(center + side * half_gap, center),
	]


func _get_mushroom_bot_placement_points(_ability_index: int) -> Array[Vector2]:
	var forward := (_bot_path_b - _bot_path_a).normalized()
	if forward.length_squared() < 0.01:
		forward = Vector2.RIGHT
	var side := Vector2(-forward.y, forward.x)
	var center := position
	return [
		_find_clear_bot_point(center - forward * 92.0 - side * 42.0, center),
		_find_clear_bot_point(center + forward * 92.0 + side * 42.0, center),
	]


func _get_octopus_bot_placement_points(_ability_index: int) -> Array[Vector2]:
	var forward := (_bot_path_b - _bot_path_a).normalized()
	if forward.length_squared() < 0.01:
		forward = Vector2.RIGHT
	var side := Vector2(-forward.y, forward.x)
	var pattern := _bot_cycle_count % 3
	var lane_offsets: Array[float] = [-56.0, 0.0, 56.0]
	var center := position + side * lane_offsets[pattern]
	var start_point := center - forward * 132.0
	var end_point := center + forward * 132.0
	if _bot_cycle_count % 2 == 1:
		var swap := start_point
		start_point = end_point
		end_point = swap
	return [
		_find_clear_bot_point(start_point, center),
		_find_clear_bot_point(end_point, center),
	]


func _find_clear_bot_point(preferred: Vector2, fallback: Vector2) -> Vector2:
	var candidate := _clamp_bot_point(preferred)
	if _is_bot_position_clear(candidate):
		return candidate
	for radius: float in [32.0, 64.0, 96.0]:
		for i in range(8):
			var offset: Vector2 = Vector2.RIGHT.rotated(TAU * float(i) / 8.0) * radius
			candidate = _clamp_bot_point(preferred + offset)
			if _is_bot_position_clear(candidate):
				return candidate
	return _clamp_bot_point(fallback)


func _clamp_bot_point(point: Vector2) -> Vector2:
	return Vector2(
		clampf(point.x, _map_bounds.position.x + 24.0, _map_bounds.end.x - 24.0),
		clampf(point.y, _map_bounds.position.y + 24.0, _map_bounds.end.y - 24.0)
	)


func _move_bot_toward(target: Vector2, step: float) -> bool:
	var next_position := position.move_toward(target, step)
	if not _is_bot_movement_position_clear(next_position):
		return false
	position = next_position
	return true


func _is_bot_movement_position_clear(candidate: Vector2) -> bool:
	var world := get_world_2d()
	if world == null:
		return true

	var shape := CircleShape2D.new()
	shape.radius = Constants.CHARACTER_RADIUS

	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = shape
	query.transform = Transform2D(0.0, candidate)
	query.collision_mask = Constants.LAYER_WALLS | Constants.LAYER_CHARACTERS
	query.collide_with_areas = true
	query.collide_with_bodies = true

	var hits := world.direct_space_state.intersect_shape(query, 16)
	for hit: Dictionary in hits:
		var collider := hit.get("collider", null) as Node
		if collider == null:
			continue
		if _is_trap_collider(collider):
			continue
		return false
	return true


func _is_trap_collider(collider: Node) -> bool:
	var node: Node = collider
	while node != null:
		if node.is_in_group("traps"):
			return true
		node = node.get_parent()
	return false


func _is_bot_position_clear(candidate: Vector2) -> bool:
	var world := get_world_2d()
	if world == null:
		return true

	var shape := CircleShape2D.new()
	shape.radius = Constants.CHARACTER_RADIUS

	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = shape
	query.transform = Transform2D(0.0, candidate)
	query.collision_mask = Constants.LAYER_WALLS | Constants.LAYER_CHARACTERS
	query.collide_with_areas = true
	query.collide_with_bodies = true

	return world.direct_space_state.intersect_shape(query, 1).is_empty()


func _on_ability_escape_charge_used(_ability: TrapperAbility, ability_index: int) -> void:
	pass


func _update_set_reload(delta: float) -> void:
	_set_reload_timer = 0.0
	_spent_ability_indices.clear()


func get_hud_ability_entries() -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	for i in _abilities.size():
		var button := ""
		if i < 3:
			button = ["A", "X", "Y"][i]
		var ability := _abilities[i]
		var state := "READY"
		if ability.is_placing:
			state = "PLACING"
		elif GameManager.current_state == Enums.GameState.HUNT:
			state = "READY" if ability.get_strategy_uses_remaining() > 0 else "SET"
		elif ability.get_cooldown_remaining() > 0.0:
			state = "%.1fs" % ability.get_cooldown_remaining()
		elif ability.get_charges_remaining() <= 0:
			state = "EMPTY"
		elif ability.max_charges > 1:
			state = "%d/%d" % [ability.get_charges_remaining(), ability.max_charges]
		entries.append({
			"button": button,
			"name": ability.get_display_name(),
			"state": state,
			"charges": ability.get_charges_remaining(),
			"max_charges": ability.max_charges,
			"color": ability.get_display_color(),
		})
	return entries


func _show_floating_text(text: String, text_color: Color) -> void:
	_floating_text = text
	_floating_text_color = text_color
	_floating_text_timer = Constants.FLOATING_TEXT_DURATION
	queue_redraw()


func notify_ability_recharged(ability_color: Color) -> void:
	_ability_ready_flash_color = ability_color
	_ability_ready_flash_timer = 0.55
	InputManager.vibrate_player(player_index, 0.2, 0.52, 0.16)
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
	var size := 14.0
	var color := Color(char_color, 0.8)
	draw_circle(Vector2.ZERO, size + 4.0, Color(team_color, 0.14))
	_draw_trapper_character_mark(size, char_color)
	draw_line(Vector2(-size, 0), Vector2(size, 0), color, 2.0)
	draw_line(Vector2(0, -size), Vector2(0, size), color, 2.0)
	draw_arc(Vector2.ZERO, size * 0.7, 0, TAU, 12, color, 1.5)
	draw_arc(Vector2.ZERO, size + 3.5, 0, TAU, 16, Color(team_color, 0.78), 2.0)
	if _ability_ready_flash_timer > 0.0:
		var ready_ratio := clampf(_ability_ready_flash_timer / 0.55, 0.0, 1.0)
		var pulse_radius := size + 9.0 + (1.0 - ready_ratio) * 9.0
		draw_circle(Vector2.ZERO, pulse_radius, Color(_ability_ready_flash_color, 0.16 * ready_ratio))
		draw_arc(Vector2.ZERO, pulse_radius, 0.0, TAU, 28,
			Color(_ability_ready_flash_color, 0.9 * ready_ratio), 2.6)

	# Player label
	var label := "P%d" % (player_index + 1)
	if player_index >= 100:
		label = "BOT"
	_draw_player_label(label, Vector2(-10, -size - 6), 14, team_color)

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

		var denied_ratio := ability.get_cooldown_denied_ratio()
		if denied_ratio > 0.0:
			var flash_alpha := 0.25 + 0.55 * denied_ratio
			var flash_radius := size + 7.0 + i * 4.0
			draw_arc(Vector2.ZERO, flash_radius, 0.0, TAU, 20,
				Color(1.0, 0.25, 0.18, flash_alpha), 2.0)
			draw_string(ThemeDB.fallback_font,
				Vector2(-4.0, -flash_radius - 8.0),
				"!", HORIZONTAL_ALIGNMENT_CENTER, -1, 14,
				Color(1.0, 0.25, 0.18, flash_alpha))

	# Draw ability placement previews
	for ability: TrapperAbility in _abilities:
		ability.draw_preview(self)
