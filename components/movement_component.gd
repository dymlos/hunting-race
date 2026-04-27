class_name MovementComponent
extends Node

## Handles character movement, dashing, and soft character separation.

signal crushed  # Emitted when pinched between two walls

@export var move_speed: float = 180.0

var velocity: Vector2 = Vector2.ZERO
var can_move: bool = true
var slippery: bool = false  # Ice zone — lerp toward target velocity instead of snapping
var _speed_modifiers: Dictionary = {}  # {StringName: float}
var _external_velocity: Vector2 = Vector2.ZERO

# Reference to parent CharacterBody2D — set by parent on ready
var body: CharacterBody2D

# Dash state
var is_dashing: bool = false
var is_airborne_dashing: bool = false
var _dash_direction: Vector2 = Vector2.ZERO
var _dash_total_distance: float = 0.0
var _dash_remaining: float = 0.0
var _dash_speed: float = 0.0
var _dash_callback: Callable
var _dash_original_collision_layer: int = 0
var _dash_original_collision_mask: int = 0
var _dash_has_collision_override: bool = false

# Sticky wall stun
var _sticky_stun_timer: float = 0.0
var _sticky_cooldowns: Dictionary = {}  # {wall_node_id: remaining_cooldown}
var _map_hazard_cooldowns: Dictionary = {}


func _physics_process(delta: float) -> void:
	if not body:
		return

	# Tick per-wall sticky cooldowns
	var expired_walls: Array[int] = []
	for wall_id: int in _sticky_cooldowns:
		_sticky_cooldowns[wall_id] -= delta
		if _sticky_cooldowns[wall_id] <= 0.0:
			expired_walls.append(wall_id)
	for wall_id in expired_walls:
		_sticky_cooldowns.erase(wall_id)

	var expired_hazards: Array[int] = []
	for hazard_id: int in _map_hazard_cooldowns:
		_map_hazard_cooldowns[hazard_id] -= delta
		if _map_hazard_cooldowns[hazard_id] <= 0.0:
			expired_hazards.append(hazard_id)
	for hazard_id in expired_hazards:
		_map_hazard_cooldowns.erase(hazard_id)

	if _sticky_stun_timer > 0.0:
		_sticky_stun_timer -= delta
		body.velocity = Vector2.ZERO
		body.move_and_slide()
		if _sticky_stun_timer <= 0.0:
			can_move = true
		return

	if is_dashing:
		var step := _dash_speed * delta
		if step >= _dash_remaining:
			step = _dash_remaining
		_dash_remaining -= step
		body.velocity = _dash_direction * _dash_speed
		body.move_and_slide()
		if _dash_remaining <= 0.0:
			_end_dash()
		return

	var separation := _compute_separation()
	body.velocity = velocity + separation + _external_velocity
	body.move_and_slide()
	_external_velocity = _external_velocity.move_toward(Vector2.ZERO, Constants.FROST_VENT_IMPULSE_DECAY * delta)
	_check_map_hazards()
	_check_sticky_walls()


func _compute_separation() -> Vector2:
	var push := Vector2.ZERO
	var tree := body.get_tree()
	if not tree:
		return push

	for node: Node in tree.get_nodes_in_group("characters"):
		if node == body or not node is CharacterBody2D:
			continue
		var other := node as CharacterBody2D
		var diff: Vector2 = body.global_position - other.global_position
		var dist: float = diff.length()
		if dist < Constants.SEPARATION_RADIUS and dist > 0.01:
			var overlap: float = 1.0 - (dist / Constants.SEPARATION_RADIUS)
			push += diff.normalized() * Constants.SEPARATION_FORCE * overlap
		elif dist <= 0.01:
			push += Vector2(randf_range(-1, 1), randf_range(-1, 1)).normalized() * Constants.SEPARATION_FORCE

	return push


func _check_sticky_walls() -> void:
	for i in body.get_slide_collision_count():
		var collision := body.get_slide_collision(i)
		var collider := collision.get_collider()
		if collider is Node and (collider as Node).is_in_group("sticky_walls"):
			var wall_id := (collider as Node).get_instance_id()
			if apply_sticky_stun(wall_id):
				return


func apply_sticky_stun(source_id: int) -> bool:
	if source_id in _sticky_cooldowns:
		return false
	if body is Escapist:
		var esc := body as Escapist
		if esc.is_dead or esc.has_scored or esc.is_effect_immune():
			return false
		GameManager.register_trap_contact(esc.player_index)
		esc.notify_trap_status("STUCK", Constants.STICKY_WALL_COLOR, 0.7)

	AudioManager.play_effect(&"StickyWall")
	freeze()
	_sticky_stun_timer = Constants.STICKY_WALL_STUN
	_sticky_cooldowns[source_id] = Constants.STICKY_WALL_STUN + Constants.STICKY_WALL_COOLDOWN
	return true


func _check_map_hazards() -> void:
	if not body is Escapist:
		return
	var esc := body as Escapist
	if esc.is_dead or esc.has_scored:
		return
	for i in body.get_slide_collision_count():
		var collision := body.get_slide_collision(i)
		var collider := collision.get_collider()
		if collider is Node and (collider as Node).is_in_group("map_hazards"):
			var hazard_id := (collider as Node).get_instance_id()
			if hazard_id in _map_hazard_cooldowns:
				continue
			_map_hazard_cooldowns[hazard_id] = Constants.STICKY_WALL_COOLDOWN
			GameManager.register_trap_contact(esc.player_index)



func apply_movement(input_vector: Vector2) -> void:
	if not can_move:
		velocity = Vector2.ZERO
		return
	var target := input_vector * move_speed * get_speed_multiplier()
	if slippery:
		# Ice: lerp toward target velocity — high speed, low control
		target *= Constants.SLIPPERY_MULTIPLIER
		velocity = velocity.lerp(target, Constants.SLIPPERY_LERP_WEIGHT)
	else:
		velocity = target


func set_speed_modifier(key: StringName, value: float) -> void:
	if key != &"fly_boost" and body is Escapist and (body as Escapist).is_effect_immune():
		return
	_speed_modifiers[key] = value


func remove_speed_modifier(key: StringName) -> void:
	_speed_modifiers.erase(key)


func get_speed_multiplier() -> float:
	var m := 1.0
	for v: float in _speed_modifiers.values():
		m *= v
	return m


func clear_speed_modifiers() -> void:
	_speed_modifiers.clear()


func apply_impulse(impulse: Vector2) -> void:
	if not can_move:
		return
	if body is Escapist and (body as Escapist).is_effect_immune():
		return
	_external_velocity += impulse


func apply_vortex_pull(direction: Vector2, target_speed: float, acceleration: float,
		inertia_dampen: float, delta: float) -> void:
	if not can_move:
		return
	if body is Escapist and (body as Escapist).is_effect_immune():
		return
	var pull_dir := direction.normalized()
	if pull_dir.length_squared() <= 0.01:
		return

	var current_pull := _external_velocity.dot(pull_dir)
	var needed_pull := maxf(target_speed - current_pull, 0.0)
	_external_velocity += pull_dir * minf(needed_pull, acceleration * delta)

	var outward_speed := velocity.dot(-pull_dir)
	if outward_speed > 0.0:
		velocity += pull_dir * minf(outward_speed, inertia_dampen * delta)


func start_dash(direction: Vector2, distance: float, on_complete: Callable = Callable(),
		duration: float = 0.1, ignore_collisions: bool = false) -> void:
	_start_dash(direction, distance, on_complete, duration, ignore_collisions, false, false)


func start_dash_ghost_pull(direction: Vector2, distance: float, on_complete: Callable = Callable(),
		duration: float = 0.1) -> void:
	_start_dash(direction, distance, on_complete, duration, true, true, true)


func _start_dash(direction: Vector2, distance: float, on_complete: Callable,
		duration: float, ignore_collisions: bool, keep_area_detection: bool,
		ignore_effect_immunity: bool) -> void:
	if not ignore_effect_immunity and body is Escapist and (body as Escapist).is_effect_immune():
		return
	duration = maxf(duration, 0.01)
	if is_dashing:
		_restore_dash_collision()
	_dash_direction = direction.normalized()
	_dash_total_distance = distance
	_dash_remaining = distance
	_dash_speed = distance / duration
	_dash_callback = on_complete
	is_dashing = true
	is_airborne_dashing = ignore_collisions
	_apply_dash_collision(ignore_collisions, keep_area_detection)


func get_dash_progress() -> float:
	if _dash_total_distance <= 0.0:
		return 0.0
	return clampf(1.0 - (_dash_remaining / _dash_total_distance), 0.0, 1.0)


func _apply_dash_collision(ignore_collisions: bool, keep_area_detection: bool = false) -> void:
	if not body:
		return
	_dash_original_collision_layer = body.collision_layer
	_dash_original_collision_mask = body.collision_mask
	_dash_has_collision_override = true
	if ignore_collisions:
		if keep_area_detection:
			body.collision_layer = Constants.LAYER_CHARACTERS
			body.collision_mask = 0
			return
		body.collision_layer = 0
		body.collision_mask = 0
		return
	# Pass through characters during dash
	body.set_collision_mask_value(2, false)
	body.set_collision_layer_value(2, false)


func _restore_dash_collision() -> void:
	if not body or not _dash_has_collision_override:
		return
	body.collision_layer = _dash_original_collision_layer
	body.collision_mask = _dash_original_collision_mask
	_dash_has_collision_override = false


func _end_dash() -> void:
	if is_airborne_dashing:
		_resolve_airborne_landing()
	is_dashing = false
	is_airborne_dashing = false
	_dash_total_distance = 0.0
	_dash_remaining = 0.0
	_dash_speed = 0.0
	body.velocity = Vector2.ZERO
	_restore_dash_collision()
	var callback := _dash_callback
	_dash_callback = Callable()
	if callback.is_valid():
		callback.call()


func _resolve_airborne_landing() -> void:
	if not body or _is_landing_clear(body.global_position):
		return
	var start_position := body.global_position
	var step := Constants.CHARACTER_RADIUS * 0.75
	for i in range(1, 18):
		var candidate := start_position + _dash_direction * step * float(i)
		if _is_landing_clear(candidate):
			body.global_position = candidate
			return
	for i in range(1, 28):
		var candidate := start_position - _dash_direction * step * float(i)
		if _is_landing_clear(candidate):
			body.global_position = candidate
			return


func _is_landing_clear(position: Vector2) -> bool:
	if not body or not body.get_world_2d():
		return true
	var shape := CircleShape2D.new()
	shape.radius = Constants.CHARACTER_RADIUS
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = shape
	query.transform = Transform2D(0.0, position)
	query.collision_mask = Constants.LAYER_WALLS
	query.exclude = [body.get_rid()]
	return body.get_world_2d().direct_space_state.intersect_shape(query, 1).is_empty()


func freeze() -> void:
	can_move = false
	is_dashing = false
	is_airborne_dashing = false
	_dash_total_distance = 0.0
	_dash_remaining = 0.0
	_dash_speed = 0.0
	_restore_dash_collision()
	velocity = Vector2.ZERO
	_external_velocity = Vector2.ZERO


func unfreeze() -> void:
	can_move = true
