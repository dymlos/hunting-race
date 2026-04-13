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
var _dash_direction: Vector2 = Vector2.ZERO
var _dash_remaining: float = 0.0
var _dash_speed: float = 0.0
var _dash_callback: Callable

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
			if body is Escapist and (body as Escapist).is_effect_immune():
				continue
			var wall_id := (collider as Node).get_instance_id()
			if wall_id in _sticky_cooldowns:
				continue  # This wall is still on cooldown
			if body is Escapist:
				var esc := body as Escapist
				if not esc.is_dead and not esc.has_scored:
					GameManager.register_trap_contact(esc.player_index)
			_sticky_stun_timer = Constants.STICKY_WALL_STUN
			_sticky_cooldowns[wall_id] = Constants.STICKY_WALL_STUN + Constants.STICKY_WALL_COOLDOWN
			can_move = false
			velocity = Vector2.ZERO
			return


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


func start_dash(direction: Vector2, distance: float, on_complete: Callable = Callable(), duration: float = 0.1) -> void:
	if body is Escapist and (body as Escapist).is_effect_immune():
		return
	_dash_direction = direction.normalized()
	_dash_remaining = distance
	_dash_speed = distance / duration
	_dash_callback = on_complete
	is_dashing = true
	# Pass through characters during dash
	body.set_collision_mask_value(2, false)
	body.set_collision_layer_value(2, false)


func _end_dash() -> void:
	is_dashing = false
	_dash_remaining = 0.0
	_dash_speed = 0.0
	body.velocity = Vector2.ZERO
	# Restore character collision
	body.set_collision_mask_value(2, true)
	body.set_collision_layer_value(2, true)
	var callback := _dash_callback
	_dash_callback = Callable()
	if callback.is_valid():
		callback.call()


func freeze() -> void:
	can_move = false
	velocity = Vector2.ZERO
	_external_velocity = Vector2.ZERO


func unfreeze() -> void:
	can_move = true
