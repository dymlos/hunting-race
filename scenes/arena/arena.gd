class_name Arena
extends Node2D

## Builds arena geometry from MapData at runtime, including hazards.

var _map_data: Dictionary = {}
var _wall_bodies: Array[StaticBody2D] = []
var _goal_zones: Array[Area2D] = []
var _hazard_nodes: Array[Node] = []
var _moving_wall_data: Array[Dictionary] = []  # For _draw() to render moving walls
var _frost_vent_data: Array[Dictionary] = []
var _sticky_blob_data: Array[Dictionary] = []
var _moving_sticky_wall_data: Array[Dictionary] = []
var _hazard_tweens: Array[Tween] = []
var _base_hazards: Array[Dictionary] = []
var _active_hazards: Array[Dictionary] = []

const FROST_VENT_VISUAL_ON_DURATION: float = 2.55
const FROST_VENT_VISUAL_OFF_DURATION: float = 0.55

signal goal_entered(escapist: Escapist)


func load_map(map_data: Dictionary) -> void:
	_map_data = map_data
	_clear()
	_base_hazards = _duplicate_hazards(_map_data.get("hazards", []))
	_active_hazards = _duplicate_hazards(_base_hazards)
	_build_walls()
	_build_goals()
	_build_hazards()
	queue_redraw()


func set_practice_obstacles_enabled(enabled: bool) -> void:
	if (_map_data.get("name", "") as String) != "Practice Room":
		return
	_active_hazards = _duplicate_hazards(_base_hazards)
	if enabled:
		for hazard_def in _get_practice_obstacle_hazards():
			_active_hazards.append(hazard_def)
	_clear_hazards()
	_build_hazards()
	queue_redraw()


func get_map_size() -> Vector2:
	return _map_data.get("size", Vector2(1600, 900)) as Vector2


func get_map_center() -> Vector2:
	return get_map_size() / 2.0


func get_spawn(index: int) -> Vector2:
	var spawns: Array = _map_data.get("spawns", [])
	if index < spawns.size():
		return spawns[index] as Vector2
	return get_map_center()


func _clear() -> void:
	for body in _wall_bodies:
		body.queue_free()
	_wall_bodies.clear()
	for zone in _goal_zones:
		zone.queue_free()
	_goal_zones.clear()
	_clear_hazards()
	_base_hazards.clear()
	_active_hazards.clear()


func _clear_hazards() -> void:
	for tween in _hazard_tweens:
		if is_instance_valid(tween):
			tween.kill()
	_hazard_tweens.clear()
	for node in _hazard_nodes:
		if not is_instance_valid(node):
			continue
		if node.get_parent() == self:
			remove_child(node)
		node.queue_free()
	_hazard_nodes.clear()
	_moving_wall_data.clear()
	_frost_vent_data.clear()
	_sticky_blob_data.clear()
	_moving_sticky_wall_data.clear()


func _duplicate_hazards(hazards: Array) -> Array[Dictionary]:
	var copies: Array[Dictionary] = []
	for hazard_def in hazards:
		if hazard_def is Dictionary:
			copies.append((hazard_def as Dictionary).duplicate(true))
	return copies


func _get_practice_obstacle_hazards() -> Array[Dictionary]:
	var map_size := get_map_size()
	var center := map_size / 2.0
	return [
		{
			"type": "ice_box",
			"pos": center + Vector2(-310.0, -170.0),
			"size": Vector2(190.0, 24.0),
		},
		{
			"type": "ice_box",
			"pos": center + Vector2(180.0, 150.0),
			"size": Vector2(210.0, 24.0),
		},
		{
			"type": "ice_box",
			"pos": center + Vector2(-70.0, -300.0),
			"size": Vector2(24.0, 190.0),
		},
		{
			"type": "ice_box",
			"pos": center + Vector2(330.0, -70.0),
			"size": Vector2(24.0, 190.0),
		},
		{
			"type": "sticky_wall",
			"pos": center + Vector2(-390.0, 120.0),
			"size": Vector2(170.0, 18.0),
		},
		{
			"type": "sticky_wall",
			"pos": center + Vector2(60.0, -205.0),
			"size": Vector2(18.0, 170.0),
		},
		{
			"type": "sticky_wall",
			"pos": center + Vector2(250.0, 255.0),
			"size": Vector2(180.0, 18.0),
		},
	]


func _build_walls() -> void:
	var walls: Array = _map_data.get("walls", [])
	for wall_def in walls:
		var pos: Vector2 = wall_def["pos"]
		var wall_size: Vector2 = wall_def["size"]
		_create_static_wall(pos, wall_size)


func _create_static_wall(pos: Vector2, wall_size: Vector2) -> StaticBody2D:
	var body := StaticBody2D.new()
	body.collision_layer = Constants.LAYER_WALLS
	body.collision_mask = 0

	var shape := RectangleShape2D.new()
	shape.size = wall_size

	var col := CollisionShape2D.new()
	col.shape = shape
	col.position = wall_size / 2.0

	body.position = pos
	body.add_child(col)
	add_child(body)
	_wall_bodies.append(body)
	return body


func _build_goals() -> void:
	var goal_rect: Rect2 = _map_data.get("goal", Rect2())
	if goal_rect.size.x <= 0.0 or goal_rect.size.y <= 0.0:
		return
	_goal_zones.append(_create_goal_zone(goal_rect))


func _create_goal_zone(rect: Rect2) -> Area2D:
	var area := Area2D.new()
	area.collision_layer = Constants.LAYER_GOAL_ZONES
	area.collision_mask = Constants.LAYER_CHARACTERS
	area.monitoring = true
	area.monitorable = false

	var shape := RectangleShape2D.new()
	shape.size = rect.size

	var col := CollisionShape2D.new()
	col.shape = shape
	col.position = rect.size / 2.0

	area.position = rect.position
	area.add_child(col)
	add_child(area)

	area.body_entered.connect(_on_goal_body_entered)
	return area


func _on_goal_body_entered(body: Node2D) -> void:
	if not GameManager.hunt_active:
		return
	if body is Escapist:
		var esc := body as Escapist
		if not esc.has_scored and not esc.is_dead:
			esc.score()
			goal_entered.emit(esc)


# --- Hazards ---

func randomize_hazards_for_round(round_number: int) -> void:
	if _base_hazards.is_empty():
		return

	var rng := RandomNumberGenerator.new()
	var seed_text := "%s:%d" % [str(_map_data.get("name", "map")), round_number]
	var seed_value := hash(seed_text)
	if seed_value < 0:
		seed_value = -seed_value
	rng.seed = seed_value

	_active_hazards.clear()
	for hazard_def in _base_hazards:
		_active_hazards.append(_randomized_hazard(hazard_def, rng))

	_clear_hazards()
	_build_hazards()
	queue_redraw()


func _randomized_hazard(def: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	var result := def.duplicate(true)
	if result.get("fixed", false) as bool:
		return result
	var jitter: Vector2 = result.get("jitter", Vector2.ZERO) as Vector2
	if jitter == Vector2.ZERO or not result.has("pos"):
		return result

	var offset := Vector2(
		rng.randf_range(-jitter.x, jitter.x),
		rng.randf_range(-jitter.y, jitter.y)
	)
	offset = _clamp_hazard_offset(result, offset)

	var pos: Vector2 = result["pos"] as Vector2
	result["pos"] = pos + offset
	if result.has("end_pos"):
		var end_pos: Vector2 = result["end_pos"] as Vector2
		result["end_pos"] = end_pos + offset
	return result


func _clamp_hazard_offset(def: Dictionary, offset: Vector2) -> Vector2:
	if not def.has("bounds"):
		return offset

	var bounds: Rect2 = def["bounds"] as Rect2
	var pos: Vector2 = def["pos"] as Vector2
	var hazard_size: Vector2 = def.get("size", Vector2.ZERO) as Vector2
	var min_offset := bounds.position - pos
	var max_offset := bounds.end - (pos + hazard_size)

	if def.has("end_pos"):
		var end_pos: Vector2 = def["end_pos"] as Vector2
		var end_min_offset := bounds.position - end_pos
		var end_max_offset := bounds.end - (end_pos + hazard_size)
		min_offset.x = maxf(min_offset.x, end_min_offset.x)
		min_offset.y = maxf(min_offset.y, end_min_offset.y)
		max_offset.x = minf(max_offset.x, end_max_offset.x)
		max_offset.y = minf(max_offset.y, end_max_offset.y)

	var clamped := offset
	if min_offset.x <= max_offset.x:
		clamped.x = clampf(offset.x, min_offset.x, max_offset.x)
	else:
		clamped.x = 0.0
	if min_offset.y <= max_offset.y:
		clamped.y = clampf(offset.y, min_offset.y, max_offset.y)
	else:
		clamped.y = 0.0
	return clamped


func _build_hazards() -> void:
	for hazard_def in _active_hazards:
		var hazard_type: String = hazard_def.get("type", "") as String
		match hazard_type:
			"moving_wall":
				_build_moving_wall(hazard_def)
			"one_way_gate":
				_build_one_way_gate(hazard_def)
			"slippery_zone":
				_build_slippery_zone(hazard_def)
			"sticky_wall":
				_build_sticky_wall(hazard_def)
			"ice_box":
				_build_ice_box(hazard_def)
			"frost_vent":
				_build_frost_vent(hazard_def)


func _build_moving_wall(def: Dictionary) -> void:
	var pos: Vector2 = def["pos"]
	var wall_size: Vector2 = def["size"]
	var end_pos: Vector2 = def["end_pos"]
	var period: float = def.get("period", 4.0)

	# AnimatableBody2D pushes characters when moving (unlike StaticBody2D)
	var body := AnimatableBody2D.new()
	body.collision_layer = Constants.LAYER_WALLS
	body.collision_mask = 0
	body.add_to_group("map_hazards")

	var shape := RectangleShape2D.new()
	shape.size = wall_size

	var col := CollisionShape2D.new()
	col.shape = shape
	col.position = wall_size / 2.0

	var contact_area := Area2D.new()
	contact_area.collision_layer = 0
	contact_area.collision_mask = Constants.LAYER_CHARACTERS
	contact_area.monitoring = true
	contact_area.monitorable = false
	var contact_shape := RectangleShape2D.new()
	contact_shape.size = wall_size + Vector2(8.0, 8.0)
	var contact_col := CollisionShape2D.new()
	contact_col.shape = contact_shape
	contact_col.position = wall_size / 2.0
	contact_area.add_child(contact_col)
	body.add_child(contact_area)
	contact_area.body_entered.connect(_on_moving_wall_contact)

	# Crush detection — Area2D that detects characters overlapping with the wall
	var crush_area := Area2D.new()
	crush_area.collision_layer = 0
	crush_area.collision_mask = Constants.LAYER_CHARACTERS
	crush_area.monitoring = true
	crush_area.monitorable = false
	var crush_shape := RectangleShape2D.new()
	# Very small — only triggers when character center is deep inside the wall
	crush_shape.size = wall_size * 0.35
	var crush_col := CollisionShape2D.new()
	crush_col.shape = crush_shape
	crush_col.position = wall_size / 2.0
	crush_area.add_child(crush_col)
	body.add_child(crush_area)
	crush_area.body_entered.connect(_on_moving_wall_crush)

	body.position = pos
	body.add_child(col)
	add_child(body)
	_hazard_nodes.append(body)

	_moving_wall_data.append({
		"body": body,
		"size": wall_size,
		"last_position": body.global_position,
	})

	# Ping-pong tween
	var tween := create_tween().set_loops()
	tween.tween_property(body, "position", end_pos, period / 2.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(body, "position", pos, period / 2.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_hazard_tweens.append(tween)


func _on_moving_wall_crush(body: Node2D) -> void:
	_register_map_hazard_contact(body)


func _on_moving_wall_contact(body: Node2D) -> void:
	_register_map_hazard_contact(body)


func _build_one_way_gate(def: Dictionary) -> void:
	var pos: Vector2 = def["pos"]
	var gate_size: Vector2 = def["size"]
	var direction: Vector2 = (def["direction"] as Vector2).normalized()

	# StaticBody2D with one_way_collision.
	# Default one-way normal = local -Y (blocks from above, passes from below).
	# We rotate the body so the blocking normal faces the direction bodies CANNOT go.
	# For direction=(1,0) "allow right": block from right → normal = +X → rotate PI/2.
	#
	# Rotation also rotates the shape, so we swap dimensions to compensate.
	var body := StaticBody2D.new()
	body.collision_layer = Constants.LAYER_WALLS
	body.collision_mask = 0
	body.position = pos + gate_size / 2.0

	# Compute rotation: we want the normal (+Y after rotation of -Y... let's just compute)
	# Normal in world = Vector2(0,-1).rotated(rotation) should equal +direction
	# (blocking normal faces the allowed direction — blocks bodies approaching from that side)
	# Vector2(0,-1).rotated(r) = direction → r = direction.angle() + PI/2
	var rot := direction.angle() + PI / 2.0
	body.rotation = rot

	# Swap shape dimensions to compensate for rotation
	var shape := RectangleShape2D.new()
	var needs_swap := absf(sin(rot)) > 0.5  # Rotating ~90 or ~270 degrees
	if needs_swap:
		shape.size = Vector2(gate_size.y, gate_size.x)
	else:
		shape.size = gate_size

	var col := CollisionShape2D.new()
	col.shape = shape
	col.one_way_collision = true
	col.one_way_collision_margin = maxf(gate_size.x, gate_size.y)

	body.add_child(col)
	add_child(body)
	_hazard_nodes.append(body)

	body.set_meta("gate_direction", direction)
	body.set_meta("gate_size", gate_size)
	body.set_meta("gate_pos", pos)


func _build_slippery_zone(def: Dictionary) -> void:
	var pos: Vector2 = def["pos"]
	var zone_size: Vector2 = def["size"]

	var area := Area2D.new()
	area.collision_layer = 0
	area.collision_mask = Constants.LAYER_CHARACTERS
	area.monitoring = true
	area.monitorable = false

	var shape := RectangleShape2D.new()
	shape.size = zone_size

	var col := CollisionShape2D.new()
	col.shape = shape
	col.position = zone_size / 2.0

	area.position = pos
	area.add_child(col)
	add_child(area)
	_hazard_nodes.append(area)

	area.set_meta("zone_size", zone_size)
	area.set_meta("is_slippery", true)
	area.body_entered.connect(_on_slippery_entered)
	area.body_exited.connect(_on_slippery_exited)


func _on_slippery_entered(body: Node2D) -> void:
	if body is BaseCharacter:
		var character := body as BaseCharacter
		character.movement.slippery = true
	_register_map_hazard_contact(body)


func _on_slippery_exited(body: Node2D) -> void:
	if body is BaseCharacter:
		var character := body as BaseCharacter
		character.movement.slippery = false


func _build_sticky_wall(def: Dictionary) -> void:
	var pos: Vector2 = def["pos"]
	var wall_size: Vector2 = def["size"]
	if maxf(wall_size.x, wall_size.y) <= 14.0:
		_build_passable_sticky_blob(def)
		return
	if def.has("end_pos"):
		_build_moving_sticky_wall(def)
		return

	var body := StaticBody2D.new()
	body.collision_layer = Constants.LAYER_WALLS
	body.collision_mask = 0
	body.add_to_group("sticky_walls")

	var shape := RectangleShape2D.new()
	shape.size = wall_size

	var col := CollisionShape2D.new()
	col.shape = shape
	col.position = wall_size / 2.0

	body.position = pos
	body.add_child(col)
	add_child(body)
	_hazard_nodes.append(body)


func _build_moving_sticky_wall(def: Dictionary) -> void:
	var pos: Vector2 = def["pos"]
	var wall_size: Vector2 = def["size"]
	var end_pos: Vector2 = def["end_pos"]
	var period: float = def.get("period", 3.0)

	var body := AnimatableBody2D.new()
	body.collision_layer = Constants.LAYER_WALLS
	body.collision_mask = 0
	body.add_to_group("sticky_walls")

	var shape := RectangleShape2D.new()
	shape.size = wall_size

	var col := CollisionShape2D.new()
	col.shape = shape
	col.position = wall_size / 2.0

	var contact_area := Area2D.new()
	contact_area.collision_layer = 0
	contact_area.collision_mask = Constants.LAYER_CHARACTERS
	contact_area.monitoring = true
	contact_area.monitorable = false
	var contact_shape := RectangleShape2D.new()
	contact_shape.size = wall_size + Vector2(10.0, 10.0)
	var contact_col := CollisionShape2D.new()
	contact_col.shape = contact_shape
	contact_col.position = wall_size / 2.0
	contact_area.add_child(contact_col)
	body.add_child(contact_area)
	contact_area.body_entered.connect(_on_moving_sticky_wall_contact.bind(body))

	body.position = pos
	body.add_child(col)
	add_child(body)
	_hazard_nodes.append(body)

	_moving_sticky_wall_data.append({
		"body": body,
		"size": wall_size,
	})

	var tween := create_tween().set_loops()
	tween.tween_property(body, "position", end_pos, period / 2.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(body, "position", pos, period / 2.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_hazard_tweens.append(tween)


func _on_moving_sticky_wall_contact(body: Node2D, wall: AnimatableBody2D) -> void:
	if not is_instance_valid(wall) or not body is BaseCharacter:
		return
	var character := body as BaseCharacter
	character.movement.apply_sticky_stun(wall.get_instance_id())


func _build_passable_sticky_blob(def: Dictionary) -> void:
	var pos: Vector2 = def["pos"]
	var blob_size: Vector2 = def["size"]

	var area := Area2D.new()
	area.collision_layer = 0
	area.collision_mask = Constants.LAYER_CHARACTERS
	area.monitoring = true
	area.monitorable = false
	area.add_to_group("sticky_walls")

	var shape := CircleShape2D.new()
	shape.radius = maxf(blob_size.x, blob_size.y) * 0.5

	var col := CollisionShape2D.new()
	col.shape = shape
	col.position = blob_size / 2.0

	area.position = pos
	area.add_child(col)
	add_child(area)
	_hazard_nodes.append(area)
	area.body_entered.connect(_on_sticky_blob_entered.bind(area))

	_sticky_blob_data.append({
		"area": area,
		"size": blob_size,
	})
	_start_sticky_blob_patrol(area, def)


func _start_sticky_blob_patrol(area: Area2D, def: Dictionary) -> void:
	var pos: Vector2 = def["pos"]
	var blob_size: Vector2 = def["size"]
	var blob_index := _sticky_blob_data.size() - 1
	var seed := float(blob_index) * 19.71 + pos.x * 0.037 + pos.y * 0.023
	var angle := fmod(seed, TAU)
	var distance := 12.0 + fmod(seed * 1.83, 13.0)
	var offset := Vector2.from_angle(angle) * distance
	var bounds: Rect2 = def.get("bounds", Rect2(pos - Vector2(28.0, 28.0), blob_size + Vector2(56.0, 56.0))) as Rect2
	var endpoint_a := _clamp_blob_patrol_point(pos + offset, blob_size, bounds)
	var endpoint_b := _clamp_blob_patrol_point(pos - offset.rotated(0.35), blob_size, bounds)
	if endpoint_a.distance_to(endpoint_b) < 4.0:
		return

	var period := 1.55 + fmod(seed * 0.41, 0.95)
	var tween := create_tween().set_loops()
	tween.tween_property(area, "position", endpoint_a, period * 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(area, "position", endpoint_b, period).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(area, "position", pos, period * 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_hazard_tweens.append(tween)


func _clamp_blob_patrol_point(point: Vector2, blob_size: Vector2, bounds: Rect2) -> Vector2:
	return Vector2(
		clampf(point.x, bounds.position.x, bounds.end.x - blob_size.x),
		clampf(point.y, bounds.position.y, bounds.end.y - blob_size.y)
	)


func _on_sticky_blob_entered(body: Node2D, blob: Area2D) -> void:
	if not is_instance_valid(blob) or not body is BaseCharacter:
		return
	var character := body as BaseCharacter
	character.movement.apply_sticky_stun(blob.get_instance_id())


func _build_ice_box(def: Dictionary) -> void:
	var pos: Vector2 = def["pos"]
	var box_size: Vector2 = def["size"]

	var body := StaticBody2D.new()
	body.collision_layer = Constants.LAYER_WALLS
	body.collision_mask = 0

	var shape := RectangleShape2D.new()
	shape.size = box_size

	var col := CollisionShape2D.new()
	col.shape = shape
	col.position = box_size / 2.0

	body.position = pos
	body.add_child(col)
	add_child(body)
	_hazard_nodes.append(body)


func _build_frost_vent(def: Dictionary) -> void:
	var pos: Vector2 = def["pos"]
	var vent_size: Vector2 = def["size"]
	var blast_rect := _get_frost_vent_blast_rect(def)
	var direction: Vector2 = (def.get("direction", Vector2.DOWN) as Vector2).normalized()
	var force: float = def.get("force", Constants.FROST_VENT_FORCE) as float
	var on_duration: float = def.get("on_duration", FROST_VENT_VISUAL_ON_DURATION) as float
	var off_duration: float = def.get("off_duration", FROST_VENT_VISUAL_OFF_DURATION) as float
	var cycle_duration := maxf(0.15, on_duration + off_duration)
	var vent_index := _frost_vent_data.size()
	var default_phase := fmod(float(vent_index) * cycle_duration * 0.37, cycle_duration)
	var phase_offset: float = def.get("phase_offset", default_phase) as float

	var area := Area2D.new()
	area.collision_layer = 0
	area.collision_mask = Constants.LAYER_CHARACTERS
	area.monitoring = true
	area.monitorable = false

	var shape := RectangleShape2D.new()
	shape.size = blast_rect.size

	var col := CollisionShape2D.new()
	col.shape = shape
	col.position = blast_rect.size / 2.0

	area.position = blast_rect.position
	area.add_child(col)
	area.set_meta("pulse_timer", 0.0)
	area.set_meta("pulse_duration", on_duration)
	add_child(area)
	_hazard_nodes.append(area)

	_frost_vent_data.append({
		"area": area,
		"vent_pos": pos,
		"vent_size": vent_size,
		"blast_rect": blast_rect,
		"direction": direction,
		"force": force,
		"on_duration": on_duration,
		"cycle_duration": cycle_duration,
		"phase_offset": phase_offset,
		"was_active": false,
	})


func _get_frost_vent_blast_rect(def: Dictionary) -> Rect2:
	var pos: Vector2 = def["pos"]
	var vent_size: Vector2 = def["size"]
	var direction: Vector2 = (def.get("direction", Vector2.DOWN) as Vector2).normalized()
	var blast_range: float = def.get("range", 240.0) as float
	var blast_width: float = def.get("width", 120.0) as float

	if absf(direction.x) > absf(direction.y):
		var y := pos.y + vent_size.y / 2.0 - blast_width / 2.0
		if direction.x > 0.0:
			return Rect2(Vector2(pos.x + vent_size.x, y), Vector2(blast_range, blast_width))
		return Rect2(Vector2(pos.x - blast_range, y), Vector2(blast_range, blast_width))

	var x := pos.x + vent_size.x / 2.0 - blast_width / 2.0
	if direction.y > 0.0:
		return Rect2(Vector2(x, pos.y + vent_size.y), Vector2(blast_width, blast_range))
	return Rect2(Vector2(x, pos.y - blast_range), Vector2(blast_width, blast_range))


func _apply_frost_vent_force(area: Area2D, direction: Vector2, force: float) -> void:
	for body in area.get_overlapping_bodies():
		if not body is BaseCharacter:
			continue
		var character := body as BaseCharacter
		if character is Escapist:
			var esc := character as Escapist
			if esc.is_dead or esc.has_scored or esc.is_effect_immune():
				continue
			GameManager.register_trap_contact(esc.player_index)
		character.movement.apply_impulse(direction * force)


func _register_map_hazard_contact(body: Node2D) -> void:
	if body is Escapist:
		var esc := body as Escapist
		if not esc.is_dead and not esc.has_scored:
			GameManager.register_trap_contact(esc.player_index)


# --- Drawing ---

func _draw() -> void:
	if _map_data.is_empty():
		return

	var map_size := get_map_size()
	var now := Time.get_ticks_msec() / 1000.0

	# Background
	_draw_arena_floor(map_size, now)

	# Static walls
	var walls: Array = _map_data.get("walls", [])
	for wall_def in walls:
		var pos: Vector2 = wall_def["pos"]
		var size: Vector2 = wall_def["size"]
		_draw_stone_wall(Rect2(pos, size), now)

	# Goal zone
	var goal_rect: Rect2 = _map_data.get("goal", Rect2())
	if goal_rect.size.x > 0.0 and goal_rect.size.y > 0.0:
		_draw_goal_zone(goal_rect, now)

	if _map_data.get("show_respawn_marker", false) as bool:
		_draw_respawn_marker()

	# Hazards
	_draw_hazards()


func _draw_rounded_rect(rect: Rect2, color: Color, radius: float) -> void:
	var r := minf(radius, minf(rect.size.x, rect.size.y) * 0.5)
	if r <= 0.5:
		draw_rect(rect, color)
		return
	draw_rect(Rect2(rect.position + Vector2(r, 0.0), Vector2(rect.size.x - r * 2.0, rect.size.y)), color)
	draw_rect(Rect2(rect.position + Vector2(0.0, r), Vector2(rect.size.x, rect.size.y - r * 2.0)), color)
	draw_circle(rect.position + Vector2(r, r), r, color)
	draw_circle(rect.position + Vector2(rect.size.x - r, r), r, color)
	draw_circle(rect.position + Vector2(r, rect.size.y - r), r, color)
	draw_circle(rect.position + Vector2(rect.size.x - r, rect.size.y - r), r, color)


func _draw_rounded_rect_outline(rect: Rect2, color: Color, radius: float, width: float = 1.0) -> void:
	var r := minf(radius, minf(rect.size.x, rect.size.y) * 0.5)
	if r <= 0.5:
		draw_rect(rect, color, false, width)
		return
	var top_left := rect.position + Vector2(r, r)
	var top_right := rect.position + Vector2(rect.size.x - r, r)
	var bottom_left := rect.position + Vector2(r, rect.size.y - r)
	var bottom_right := rect.position + Vector2(rect.size.x - r, rect.size.y - r)
	draw_line(rect.position + Vector2(r, 0.0), rect.position + Vector2(rect.size.x - r, 0.0), color, width)
	draw_line(rect.position + Vector2(r, rect.size.y), rect.position + Vector2(rect.size.x - r, rect.size.y), color, width)
	draw_line(rect.position + Vector2(0.0, r), rect.position + Vector2(0.0, rect.size.y - r), color, width)
	draw_line(rect.position + Vector2(rect.size.x, r), rect.position + Vector2(rect.size.x, rect.size.y - r), color, width)
	draw_arc(top_left, r, PI, PI * 1.5, 10, color, width)
	draw_arc(top_right, r, PI * 1.5, TAU, 10, color, width)
	draw_arc(bottom_right, r, 0.0, PI * 0.5, 10, color, width)
	draw_arc(bottom_left, r, PI * 0.5, PI, 10, color, width)


func _draw_beveled_rounded_rect(rect: Rect2, fill: Color, outline: Color, radius: float, shadow_offset: Vector2 = Vector2(7.0, 9.0)) -> void:
	_draw_rounded_rect(Rect2(rect.position + shadow_offset, rect.size), Color(0.0, 0.0, 0.0, 0.3), radius)
	_draw_rounded_rect(Rect2(rect.position + shadow_offset * 0.42, rect.size), Color(fill.darkened(0.65), 0.42), radius)
	_draw_rounded_rect(rect, fill, radius)
	_draw_rounded_rect(Rect2(rect.position, Vector2(rect.size.x, minf(radius + 2.0, rect.size.y))), Color(1.0, 1.0, 1.0, 0.13), radius)
	_draw_rounded_rect(Rect2(rect.position + Vector2(0.0, rect.size.y - minf(radius + 1.0, rect.size.y)), Vector2(rect.size.x, minf(radius + 1.0, rect.size.y))), Color(0.0, 0.0, 0.0, 0.24), radius)
	_draw_rounded_rect_outline(rect, outline, radius, 2.0)


func _draw_arena_floor(map_size: Vector2, time: float) -> void:
	var area := Rect2(Vector2.ZERO, map_size)
	draw_rect(area, Color(0.011, 0.014, 0.017))

	var upper_haze := Color(0.025, 0.042, 0.048, 0.62)
	var lower_haze := Color(0.007, 0.009, 0.012, 0.72)
	draw_rect(Rect2(Vector2.ZERO, Vector2(map_size.x, map_size.y * 0.34)), upper_haze)
	draw_rect(Rect2(Vector2(0.0, map_size.y * 0.34), Vector2(map_size.x, map_size.y * 0.66)), lower_haze)

	for i in range(9):
		var seed := float(i)
		var center := Vector2(
			fmod(seed * 313.0 + sin(time * 0.08 + seed) * 45.0, map_size.x),
			map_size.y * (0.18 + 0.72 * fmod(seed * 0.23, 1.0))
		)
		var radius := 150.0 + fmod(seed * 71.0, 210.0)
		draw_circle(center, radius, Color(0.08, 0.19, 0.18, 0.025))
		draw_circle(center + Vector2(24.0, 18.0), radius * 0.58, Color(0.0, 0.0, 0.0, 0.035))

	var dust_color := Color(0.62, 0.92, 0.86, 0.08)
	for i in range(42):
		var seed := float(i)
		var px := fmod(seed * 271.0 + sin(time * 0.3 + seed) * 34.0, map_size.x)
		var py := fmod(seed * 157.0 + cos(time * 0.22 + seed * 0.7) * 26.0, map_size.y)
		draw_circle(Vector2(px, py), 1.5 + fmod(seed, 4.0), dust_color)

	draw_rect(area, Color(0.0, 0.0, 0.0, 0.22), false, 34.0)


func _draw_stone_wall(rect: Rect2, time: float) -> void:
	var radius := minf(8.0, minf(rect.size.x, rect.size.y) * 0.42)
	_draw_beveled_rounded_rect(rect, Color(0.24, 0.28, 0.29), Color(0.68, 0.86, 0.82, 0.22), radius, Vector2(5.0, 7.0))
	_draw_rounded_rect(Rect2(rect.position, Vector2(rect.size.x, minf(8.0, rect.size.y))), Color(0.47, 0.56, 0.55, 0.54), radius)
	_draw_rounded_rect(Rect2(rect.position, Vector2(minf(7.0, rect.size.x), rect.size.y)), Color(0.39, 0.48, 0.47, 0.34), radius)
	_draw_rounded_rect(Rect2(rect.position + Vector2(0.0, rect.size.y - minf(7.0, rect.size.y)), Vector2(rect.size.x, minf(7.0, rect.size.y))), Color(0.07, 0.09, 0.1, 0.42), radius)

	var long_axis := maxf(rect.size.x, rect.size.y)
	var cracks := int(clampf(long_axis / 90.0, 1.0, 6.0))
	for i in range(cracks):
		var t := (float(i) + 0.35 + 0.08 * sin(time + float(i))) / float(cracks)
		var anchor := rect.position + Vector2(rect.size.x * t, rect.size.y * (0.25 + 0.5 * fmod(float(i) * 0.37, 1.0)))
		var crack_len := minf(long_axis * 0.1, 34.0)
		draw_line(anchor, anchor + Vector2(crack_len * 0.55, -crack_len * 0.25), Color(0.08, 0.11, 0.12, 0.5), 1.0)
		draw_line(anchor, anchor + Vector2(-crack_len * 0.35, crack_len * 0.22), Color(0.62, 0.82, 0.79, 0.12), 1.0)


func _draw_goal_zone(rect: Rect2, time: float) -> void:
	var goal_color := Color(0.18, 1.0, 0.55)
	var pulse := 0.5 + 0.5 * sin(time * 4.0)
	_draw_rounded_rect(Rect2(rect.position + Vector2(8.0, 9.0), rect.size), Color(0.0, 0.0, 0.0, 0.36), 10.0)
	_draw_rounded_rect(rect, Color(goal_color, 0.10 + pulse * 0.06), 10.0)
	_draw_rounded_rect(rect.grow(-8.0), Color(goal_color, 0.08), 8.0)
	_draw_rounded_rect_outline(rect, Color(goal_color, 0.65), 10.0, 3.0)
	_draw_rounded_rect_outline(rect.grow(-10.0), Color(0.85, 1.0, 0.92, 0.25), 7.0, 1.0)
	var step := 42.0
	var y := rect.position.y + fmod(time * 42.0, step)
	while y < rect.end.y:
		draw_line(Vector2(rect.position.x + 8.0, y), Vector2(rect.end.x - 8.0, y + 22.0), Color(goal_color, 0.32), 2.0)
		y += step


func _draw_respawn_marker() -> void:
	var pulse := 0.5 + 0.5 * sin(Time.get_ticks_msec() / 360.0)
	var color := Color(0.25, 0.85, 1.0, 0.45 + pulse * 0.25)
	var respawn_rect: Rect2 = _map_data.get("respawn_zone", Rect2())
	if respawn_rect.size.x > 0.0 and respawn_rect.size.y > 0.0:
		draw_rect(respawn_rect, Color(color, 0.12))
		draw_rect(respawn_rect, color, false, 2.0)
		return
	var spawns: Array = _map_data.get("spawns", [])
	if spawns.is_empty():
		return
	var spawn: Vector2 = spawns[0] as Vector2
	draw_circle(spawn, 30.0 + pulse * 4.0, Color(color, 0.12))
	draw_arc(spawn, 30.0 + pulse * 4.0, 0.0, TAU, 32, color, 2.0)
	draw_line(spawn + Vector2(-18.0, 0.0), spawn + Vector2(18.0, 0.0), color, 2.0)
	draw_line(spawn + Vector2(0.0, -18.0), spawn + Vector2(0.0, 18.0), color, 2.0)


func _draw_hazards() -> void:
	var now := Time.get_ticks_msec() / 1000.0

	# Floor-like hazards first, so solid obstacles remain readable above them.
	for hazard_def in _active_hazards:
		var hazard_type: String = hazard_def.get("type", "") as String
		match hazard_type:
			"slippery_zone":
				var pos: Vector2 = hazard_def["pos"]
				var size: Vector2 = hazard_def["size"]
				_draw_slippery_zone_visual(Rect2(pos, size), now)

	for vent_data in _frost_vent_data:
		var area: Area2D = vent_data["area"] as Area2D
		if not is_instance_valid(area):
			continue
		var pulse_timer: float = area.get_meta("pulse_timer", 0.0) as float
		if pulse_timer <= 0.0:
			continue
		var blast_rect: Rect2 = vent_data["blast_rect"] as Rect2
		var direction: Vector2 = vent_data["direction"] as Vector2
		var vent_size: Vector2 = vent_data["vent_size"] as Vector2
		var pulse_duration: float = area.get_meta("pulse_duration", FROST_VENT_VISUAL_ON_DURATION) as float
		var remaining_ratio := clampf(pulse_timer / maxf(pulse_duration, 0.01), 0.0, 1.0)
		var travel_progress := 1.0 - remaining_ratio
		var alpha := _get_wind_alpha(travel_progress)
		_draw_frost_waves(blast_rect, direction, alpha, now, vent_size, travel_progress)

	# Solid / readable hazards are drawn after floor effects.
	for hazard_def in _active_hazards:
		var hazard_type: String = hazard_def.get("type", "") as String
		match hazard_type:
			"one_way_gate":
				var pos: Vector2 = hazard_def["pos"]
				var size: Vector2 = hazard_def["size"]
				var dir: Vector2 = hazard_def["direction"]
				_draw_one_way_gate_visual(Rect2(pos, size), dir, now)
			"sticky_wall":
				var pos: Vector2 = hazard_def["pos"]
				var size: Vector2 = hazard_def["size"]
				if maxf(size.x, size.y) <= 14.0 or hazard_def.has("end_pos"):
					continue
				_draw_sticky_wall_visual(Rect2(pos, size), now)
			"ice_box":
				var pos: Vector2 = hazard_def["pos"]
				var size: Vector2 = hazard_def["size"]
				_draw_ice_box_visual(Rect2(pos, size), now)
			"frost_vent":
				var pos: Vector2 = hazard_def["pos"]
				var size: Vector2 = hazard_def["size"]
				var direction: Vector2 = (hazard_def.get("direction", Vector2.DOWN) as Vector2).normalized()
				_draw_frost_vent_visual(Rect2(pos, size), direction, now)

	for mw in _moving_wall_data:
		var body: Node2D = mw["body"]
		var size: Vector2 = mw["size"]
		if is_instance_valid(body):
			_draw_moving_wall_visual(Rect2(body.position, size), now)

	for sticky_data in _moving_sticky_wall_data:
		var body: Node2D = sticky_data["body"]
		var size: Vector2 = sticky_data["size"]
		if is_instance_valid(body):
			_draw_sticky_wall_visual(Rect2(body.position, size), now)

	for blob_data in _sticky_blob_data:
		var area: Area2D = blob_data["area"] as Area2D
		if not is_instance_valid(area):
			continue
		var size: Vector2 = blob_data["size"] as Vector2
		_draw_sticky_blob_visual(Rect2(area.position, size), now)


func _draw_moving_wall_visual(rect: Rect2, time: float) -> void:
	var pulse := 0.5 + 0.5 * sin(time * 5.0)
	var radius := minf(7.0, minf(rect.size.x, rect.size.y) * 0.45)
	_draw_beveled_rounded_rect(rect, Color(0.76, 0.36, 0.06), Color(1.0, 0.66, 0.12, 0.55 + pulse * 0.22), radius)
	_draw_rounded_rect(Rect2(rect.position, Vector2(rect.size.x, minf(6.0, rect.size.y))), Color(1.0, 0.82, 0.24, 0.54), radius)
	_draw_rounded_rect(Rect2(rect.position + Vector2(0.0, rect.size.y - minf(5.0, rect.size.y)), Vector2(rect.size.x, minf(5.0, rect.size.y))), Color(0.22, 0.08, 0.01, 0.44), radius)
	var center := rect.position + rect.size / 2.0
	var horizontal := rect.size.x >= rect.size.y
	var axis := Vector2.RIGHT if horizontal else Vector2.DOWN
	var cross := Vector2.DOWN if horizontal else Vector2.RIGHT
	var half_len := (rect.size.x if horizontal else rect.size.y) / 2.0
	for i in range(5):
		var offset := -half_len + float(i + 1) * half_len * 2.0 / 6.0
		var p := center + axis * offset
		draw_line(p - cross * 6.0, p + cross * 6.0, Color(0.18, 0.08, 0.02, 0.55), 2.0)
	draw_circle(center, 5.0 + pulse * 2.0, Color(1.0, 0.9, 0.35, 0.4))


func _draw_slippery_zone_visual(rect: Rect2, time: float) -> void:
	_draw_rounded_rect(Rect2(rect.position + Vector2(9.0, 11.0), rect.size), Color(0.0, 0.0, 0.0, 0.22), 8.0)
	_draw_rounded_rect(rect, Color(0.24, 0.56, 0.64, 0.44), 8.0)
	_draw_rounded_rect(Rect2(rect.position + Vector2(5.0, 5.0), rect.size - Vector2(10.0, 10.0)), Color(0.72, 0.94, 1.0, 0.16), 7.0)
	_draw_rounded_rect(Rect2(rect.position, Vector2(rect.size.x, minf(12.0, rect.size.y))), Color(0.93, 1.0, 1.0, 0.18), 8.0)
	_draw_rounded_rect(Rect2(rect.position + Vector2(0.0, rect.size.y - minf(10.0, rect.size.y)), Vector2(rect.size.x, minf(10.0, rect.size.y))), Color(0.03, 0.18, 0.24, 0.22), 8.0)
	_draw_rounded_rect_outline(rect, Color(0.78, 1.0, 1.0, 0.68), 8.0, 2.2)
	_draw_rounded_rect_outline(rect.grow(-8.0), Color(0.9, 1.0, 1.0, 0.18), 6.0, 1.0)
	_draw_ice_crystal_facets(rect, time, 12, 0.54)
	_draw_ice_surface_texture(rect, time, 72, 1.0)
	_draw_ice_reflection_glints(rect, time, 8, 0.58)


func _draw_one_way_gate_visual(rect: Rect2, direction: Vector2, time: float) -> void:
	var dir := direction.normalized()
	if dir == Vector2.ZERO:
		dir = Vector2.RIGHT
	var pulse := 0.5 + 0.5 * sin(time * 5.5)
	var radius := minf(9.0, minf(rect.size.x, rect.size.y) * 0.38)
	var gate_fill := Color(0.03, 0.24, 0.48, 0.68)
	var gate_edge := Color(0.18, 0.78, 1.0, 0.68 + pulse * 0.2)
	_draw_beveled_rounded_rect(rect, gate_fill, gate_edge, radius, Vector2(8.0, 10.0))
	_draw_rounded_rect(Rect2(rect.position, Vector2(minf(6.0, rect.size.x), rect.size.y)), Color(0.72, 0.95, 1.0, 0.12), radius)

	var center := rect.position + rect.size / 2.0
	var lane_count := 5
	var perp := Vector2(-dir.y, dir.x)
	var gate_len := absf(rect.size.x * dir.x) + absf(rect.size.y * dir.y)
	var gate_cross := absf(rect.size.x * perp.x) + absf(rect.size.y * perp.y)
	var spread := maxf(gate_cross * 0.62, 14.0)
	for i in range(lane_count):
		var lane_ratio := float(i) / float(maxi(lane_count - 1, 1)) - 0.5
		var lane_center := center + perp * lane_ratio * spread
		var arrow_len := maxf(gate_len * 0.22, 18.0)
		var phase := fmod(time * 0.65 + float(i) * 0.14, 1.0)
		var base := lane_center - dir * (arrow_len * (0.62 - phase * 0.22))
		var tip := lane_center + dir * (arrow_len * (0.28 + phase * 0.24))
		var color := Color(0.78, 0.96, 1.0, 0.58 + pulse * 0.24)
		draw_line(base, tip, color, 2.5)
		draw_line(tip, tip - dir * 11.0 + perp * 5.5, color, 1.9)
		draw_line(tip, tip - dir * 11.0 - perp * 5.5, color, 1.9)

	var reverse_count := 6
	var reverse_color := Color(1.0, 0.12, 0.08, 0.7 + pulse * 0.18)
	var reverse_half_len := clampf(gate_len * 0.16, 4.5, 7.0)
	var reverse_head_len := clampf(gate_len * 0.13, 3.8, 5.5)
	var reverse_head_spread := clampf(gate_cross * 0.008, 3.0, 4.6)
	for i in range(reverse_count):
		var lane_ratio := float(i) / float(maxi(reverse_count - 1, 1)) - 0.5
		var lane_center := center + perp * lane_ratio * (spread * 0.78)
		var base := lane_center + dir * reverse_half_len
		var tip := lane_center - dir * reverse_half_len
		draw_line(base, tip, reverse_color, 2.0)
		draw_line(tip, tip + dir * reverse_head_len + perp * reverse_head_spread, reverse_color, 1.8)
		draw_line(tip, tip + dir * reverse_head_len - perp * reverse_head_spread, reverse_color, 1.8)

	var blocked_side := center - dir * (gate_len * 0.28)
	var block_color := Color(0.04, 0.14, 0.26, 0.62)
	draw_line(blocked_side - perp * gate_cross * 0.27, blocked_side + perp * gate_cross * 0.27, block_color, 2.2)
	draw_line(blocked_side - perp * gate_cross * 0.18 - dir * 5.0, blocked_side + perp * gate_cross * 0.18 - dir * 5.0, block_color, 1.4)


func _draw_sticky_wall_visual(rect: Rect2, time: float) -> void:
	if maxf(rect.size.x, rect.size.y) <= 14.0:
		_draw_sticky_blob_visual(rect, time)
		return

	var pulse := 0.5 + 0.5 * sin(time * 4.2 + rect.position.x * 0.03)
	var radius := minf(6.0, minf(rect.size.x, rect.size.y) * 0.46)
	_draw_beveled_rounded_rect(rect, Color(0.55, 0.08, 0.36, 0.96), Color(Constants.STICKY_WALL_COLOR, 0.62 + pulse * 0.2), radius)
	_draw_rounded_rect(Rect2(rect.position, Vector2(rect.size.x, minf(5.0, rect.size.y))), Color(1.0, 0.62, 0.9, 0.2), radius)
	_draw_rounded_rect(Rect2(rect.position + Vector2(0.0, rect.size.y - minf(4.0, rect.size.y)), Vector2(rect.size.x, minf(4.0, rect.size.y))), Color(0.2, 0.01, 0.11, 0.4), radius)

	var center := rect.position + rect.size / 2.0
	var horizontal := rect.size.x >= rect.size.y
	var axis := Vector2.RIGHT if horizontal else Vector2.DOWN
	var cross := Vector2.DOWN if horizontal else Vector2.RIGHT
	var length := rect.size.x if horizontal else rect.size.y
	var thickness := rect.size.y if horizontal else rect.size.x
	var strand_count := int(clampf(length / 28.0, 2.0, 8.0))
	for i in range(strand_count):
		var ratio := (float(i) + 0.5) / float(strand_count)
		var along := -length / 2.0 + ratio * length
		var wobble := sin(time * 3.0 + float(i) * 1.7) * thickness * 0.18
		var start := center + axis * along - cross * (thickness * 0.42)
		var end := center + axis * (along + sin(float(i)) * 8.0) + cross * (thickness * 0.42)
		draw_line(start, (start + end) / 2.0 + cross * wobble, Color(1.0, 0.52, 0.86, 0.5), 1.6)
		draw_line((start + end) / 2.0 + cross * wobble, end, Color(1.0, 0.78, 0.95, 0.32), 1.2)
	for i in range(3):
		var bubble_pos := rect.position + Vector2(
			fmod(float(i) * 37.0 + time * 18.0, maxf(rect.size.x, 1.0)),
			fmod(float(i) * 19.0 + time * 9.0, maxf(rect.size.y, 1.0))
		)
		draw_circle(bubble_pos, 2.0 + pulse * 1.4, Color(1.0, 0.76, 0.94, 0.28))


func _draw_sticky_blob_visual(rect: Rect2, time: float) -> void:
	var center := rect.position + rect.size / 2.0
	var radius := maxf(rect.size.x, rect.size.y) * 0.5
	var pulse := 0.5 + 0.5 * sin(time * 4.4 + rect.position.x * 0.07)
	draw_circle(center + Vector2(3.0, 4.0), radius + 2.0, Color(0.0, 0.0, 0.0, 0.28))
	draw_circle(center, radius + 1.5 + pulse * 0.7, Color(1.0, 0.22, 0.68, 0.22))
	draw_circle(center, radius, Color(0.68, 0.05, 0.42, 0.96))
	draw_circle(center - Vector2(radius * 0.28, radius * 0.32), radius * 0.32, Color(1.0, 0.72, 0.93, 0.42))
	draw_arc(center, radius + 1.0, -0.35, PI * 1.45, 14, Color(1.0, 0.45, 0.84, 0.7), 1.4)
	draw_circle(center + Vector2(radius * 0.34, radius * 0.28), radius * 0.18, Color(0.18, 0.0, 0.1, 0.34))


func _draw_ice_box_visual(rect: Rect2, time: float) -> void:
	var radius := minf(7.0, minf(rect.size.x, rect.size.y) * 0.34)
	_draw_beveled_rounded_rect(rect, Color(0.34, 0.43, 0.43, 0.98), Color(0.72, 0.86, 0.82, 0.42), radius, Vector2(8.0, 10.0))
	_draw_rounded_rect(Rect2(rect.position + Vector2(4.0, 4.0), rect.size - Vector2(8.0, 8.0)), Color(0.12, 0.18, 0.18, 0.22), radius)
	_draw_rounded_rect(Rect2(rect.position, Vector2(rect.size.x, minf(7.0, rect.size.y))), Color(0.78, 0.9, 0.86, 0.16), radius)
	_draw_rounded_rect(Rect2(rect.position + Vector2(0.0, rect.size.y - minf(6.0, rect.size.y)), Vector2(rect.size.x, minf(6.0, rect.size.y))), Color(0.02, 0.04, 0.04, 0.36), radius)
	_draw_mechanical_block_texture(rect, time, radius)


func _draw_ice_crystal_facets(rect: Rect2, time: float, count: int, intensity: float = 1.0) -> void:
	for i in range(count):
		var seed := float(i)
		var center := rect.position + Vector2(
			rect.size.x * (0.1 + 0.8 * fmod(seed * 0.312 + sin(time * 0.035 + seed) * 0.008, 1.0)),
			rect.size.y * (0.12 + 0.76 * fmod(seed * 0.487 + cos(time * 0.027 + seed) * 0.008, 1.0))
		)
		var facet := Vector2(
			18.0 + minf(rect.size.x * 0.035, 34.0) * fmod(seed * 0.73, 1.0),
			10.0 + minf(rect.size.y * 0.025, 22.0) * fmod(seed * 0.41, 1.0)
		)
		var angle := -0.52 + sin(seed * 1.8) * 0.7
		var axis := Vector2.from_angle(angle)
		var cross := Vector2(-axis.y, axis.x)
		var a := center - axis * facet.x * 0.55
		var b := center + axis * facet.x * 0.55
		var c := center + cross * facet.y
		var d := center - cross * facet.y * 0.8
		draw_colored_polygon(PackedVector2Array([a, c, b, d]), Color(0.82, 1.0, 1.0, 0.018 * intensity))
		draw_line(a, c, Color(0.92, 1.0, 1.0, 0.08 * intensity), 0.65)
		draw_line(c, b, Color(0.54, 0.9, 1.0, 0.05 * intensity), 0.65)


func _draw_mechanical_block_texture(rect: Rect2, time: float, radius: float) -> void:
	var inner := rect.grow(-6.0)
	_draw_rounded_rect_outline(inner, Color(0.04, 0.07, 0.07, 0.32), maxf(1.0, radius - 2.0), 1.0)
	var horizontal := rect.size.x >= rect.size.y
	var axis := Vector2.RIGHT if horizontal else Vector2.DOWN
	var cross := Vector2.DOWN if horizontal else Vector2.RIGHT
	var length := rect.size.x if horizontal else rect.size.y
	var center := rect.position + rect.size / 2.0
	for i in range(4):
		var ratio := (float(i) + 1.0) / 5.0
		var p := center - axis * length * 0.42 + axis * length * 0.84 * ratio
		draw_line(p - cross * 4.0, p + cross * 4.0, Color(0.02, 0.03, 0.03, 0.34), 1.2)
		draw_line(p - cross * 4.0 - axis * 1.0, p + cross * 4.0 - axis * 1.0, Color(0.78, 0.9, 0.86, 0.08), 0.7)
	for i in range(3):
		var seed := float(i)
		var bolt_pos := rect.position + Vector2(
			6.0 + fmod(seed * 17.0, maxf(rect.size.x - 12.0, 1.0)),
			6.0 + fmod(seed * 11.0, maxf(rect.size.y - 12.0, 1.0))
		)
		draw_circle(bolt_pos, 1.8, Color(0.78, 0.88, 0.84, 0.22))
		draw_circle(bolt_pos + Vector2(0.8, 1.0), 1.8, Color(0.0, 0.0, 0.0, 0.18))
	var glint := 0.5 + 0.5 * sin(time * 2.0 + rect.position.x * 0.01)
	draw_line(rect.position + Vector2(6.0, 6.0), rect.position + Vector2(rect.size.x - 8.0, 6.0),
		Color(0.86, 1.0, 0.92, 0.06 + glint * 0.04), 0.8)


func _draw_ice_surface_texture(rect: Rect2, time: float, count: int, intensity: float = 1.0) -> void:
	for i in range(count):
		var seed := float(i)
		var anchor := rect.position + Vector2(
			rect.size.x * (0.08 + 0.84 * fmod(seed * 0.618 + sin(time * 0.05 + seed) * 0.012, 1.0)),
			rect.size.y * (0.10 + 0.80 * fmod(seed * 0.347 + cos(time * 0.04 + seed * 0.7) * 0.012, 1.0))
		)
		var angle := -0.45 + sin(seed * 1.91) * 0.58
		var dir := Vector2.from_angle(angle).normalized()
		var length := minf(maxf(rect.size.x, rect.size.y) * (0.028 + 0.035 * fmod(seed * 0.23, 1.0)), 42.0)
		var alpha := (0.06 + 0.115 * fmod(seed * 0.41, 1.0)) * intensity
		var color := Color(0.84, 1.0, 1.0, alpha)
		draw_line(anchor - dir * length * 0.5, anchor + dir * length * 0.5, color, 0.85)

		if i % 3 == 0:
			var branch_dir := dir.rotated(0.55 + sin(seed) * 0.22)
			var branch_start := anchor + dir * length * 0.08
			draw_line(branch_start, branch_start + branch_dir * length * 0.32,
				Color(0.9, 1.0, 1.0, alpha * 0.78), 0.7)
		if i % 5 == 0:
			var frost_pos := anchor + Vector2(sin(seed * 2.3), cos(seed * 1.7)) * 4.0
			draw_line(frost_pos - dir.rotated(1.2) * 2.0, frost_pos + dir.rotated(1.2) * 2.0,
				Color(0.58, 0.9, 1.0, alpha * 0.55), 0.55)


func _draw_ice_scuff_patches(rect: Rect2, time: float, count: int, intensity: float = 1.0) -> void:
	for i in range(count):
		var seed := float(i)
		var center := rect.position + Vector2(
			rect.size.x * fmod(seed * 0.433 + sin(time * 0.025 + seed) * 0.018, 1.0),
			rect.size.y * fmod(seed * 0.271 + cos(time * 0.021 + seed) * 0.018, 1.0)
		)
		var alpha := (0.035 + 0.075 * fmod(seed * 0.29, 1.0)) * intensity
		var base_angle := -0.35 + sin(seed * 2.1) * 0.5
		var base_dir := Vector2.from_angle(base_angle)
		var patch_width := 10.0 + fmod(seed * 11.0, 24.0)
		for j in range(4):
			var strand_seed := seed + float(j) * 0.37
			var offset := Vector2.from_angle(base_angle + PI * 0.5) * ((float(j) - 1.5) * 3.4)
			var strand_len := patch_width * (0.45 + 0.2 * fmod(strand_seed, 1.0))
			var wobble := Vector2.from_angle(base_angle + sin(strand_seed * 3.0) * 0.18)
			var a := center + offset - wobble * strand_len * 0.5
			var b := center + offset + wobble * strand_len * 0.5
			draw_line(a, b, Color(0.78, 1.0, 1.0, alpha * (0.7 + float(j) * 0.08)), 0.58)
		if i % 4 == 0:
			var slash_dir := base_dir.rotated(0.8)
			draw_line(center - slash_dir * 4.0, center + slash_dir * 4.0,
				Color(0.9, 1.0, 1.0, alpha * 0.55), 0.55)


func _draw_ice_reflection_glints(rect: Rect2, time: float, count: int, intensity: float = 1.0) -> void:
	for i in range(count):
		var seed := float(i)
		var cycle := fmod(time * (0.16 + seed * 0.011) + seed * 0.173, 1.0)
		var twinkle := pow(sin(cycle * PI), 3.0)
		if twinkle <= 0.08:
			continue
		var local := Vector2(
			rect.size.x * (0.18 + 0.64 * fmod(seed * 0.381 + cycle * 0.035, 1.0)),
			rect.size.y * (0.20 + 0.58 * fmod(seed * 0.217 + sin(time * 0.16 + seed) * 0.02, 1.0))
		)
		var pos := rect.position + local
		var base_len := 5.0 + minf(maxf(rect.size.x, rect.size.y) * 0.018, 12.0)
		var streak_len := base_len * (0.55 + twinkle * 0.65)
		var dir := Vector2(0.94, -0.34).normalized()
		var alpha := (0.08 + 0.24 * twinkle) * intensity
		var color := Color(0.9, 1.0, 1.0, alpha)
		draw_line(pos - dir * streak_len, pos + dir * streak_len, color, 0.9)
		if twinkle > 0.65:
			var tiny_dir := Vector2(-dir.y, dir.x)
			draw_line(pos - tiny_dir * 2.2, pos + tiny_dir * 2.2, Color(1.0, 1.0, 1.0, alpha * 0.55), 0.8)


func _draw_frost_vent_visual(rect: Rect2, direction: Vector2, time: float) -> void:
	var dir := direction.normalized()
	if dir == Vector2.ZERO:
		dir = Vector2.DOWN
	var pulse := 0.5 + 0.5 * sin(time * 6.0)
	var radius := minf(6.0, minf(rect.size.x, rect.size.y) * 0.42)
	_draw_beveled_rounded_rect(rect, Color(0.12, 0.42, 0.5, 0.8), Color(Constants.FROST_VENT_COLOR, 0.72), radius, Vector2(8.0, 10.0))
	_draw_rounded_rect(Rect2(rect.position, Vector2(rect.size.x, minf(5.0, rect.size.y))), Color(0.75, 1.0, 1.0, 0.16), radius)
	var horizontal := rect.size.x >= rect.size.y
	var slot_count := 4
	for i in range(slot_count):
		var ratio := (float(i) + 1.0) / float(slot_count + 1)
		if horizontal:
			var x := rect.position.x + rect.size.x * ratio
			draw_line(Vector2(x, rect.position.y + 4.0), Vector2(x, rect.end.y - 4.0), Color(0.8, 1.0, 1.0, 0.55), 1.4)
		else:
			var y := rect.position.y + rect.size.y * ratio
			draw_line(Vector2(rect.position.x + 4.0, y), Vector2(rect.end.x - 4.0, y), Color(0.8, 1.0, 1.0, 0.55), 1.4)
	var center := rect.position + rect.size / 2.0
	draw_line(center, center + dir * (18.0 + pulse * 4.0), Color(0.82, 1.0, 1.0, 0.92), 3.0)


func _draw_frost_waves(rect: Rect2, direction: Vector2, alpha: float, time: float, vent_size: Vector2, travel_progress: float) -> void:
	var dir := direction.normalized()
	if dir == Vector2.ZERO:
		dir = Vector2.RIGHT
	var along_horizontal := absf(dir.x) >= absf(dir.y)
	var travel_len := rect.size.x if along_horizontal else rect.size.y
	var cross_len := rect.size.y if along_horizontal else rect.size.x
	var vent_cross_len := vent_size.y if along_horizontal else vent_size.x
	var travel_axis := Vector2.RIGHT if along_horizontal else Vector2.DOWN
	var cross_axis := Vector2.DOWN if along_horizontal else Vector2.RIGHT
	if dir.dot(travel_axis) < 0.0:
		travel_axis = -travel_axis
	var origin := rect.position
	if travel_axis.x < 0.0:
		origin.x = rect.end.x
	if travel_axis.y < 0.0:
		origin.y = rect.end.y

	var nozzle_width := clampf(vent_cross_len + 16.0, 18.0, cross_len * 0.58)
	var plume_width := minf(cross_len * 0.86, nozzle_width * 2.35)
	var reveal := _ease_wind_reveal(clampf(travel_progress / 0.55, 0.0, 1.0))
	var visible_len := maxf(0.0, travel_len * reveal)
	if visible_len <= 2.0 or alpha <= 0.01:
		return

	# Faint base mist, built from soft bands instead of a hard rectangle.
	for band in range(4):
		var lane := (float(band) + 0.5) / 4.0 - 0.5
		var points := PackedVector2Array()
		for i in range(20):
			var ratio := float(i) / 19.0
			var full_ratio := ratio * reveal
			var local_width := _get_wind_width(full_ratio, nozzle_width, plume_width)
			var center_shift := sin(time * 0.7 + ratio * 3.0 + float(band)) * 4.0 * sin(ratio * PI)
			var cross := cross_len * 0.5 + lane * local_width * 0.62 + center_shift
			points.append(origin + travel_axis * (visible_len * ratio) + cross_axis * cross)
		draw_polyline(points, Color(0.28, 0.86, 1.0, alpha * 0.035), 6.0 + float(band) * 1.1)

	var ribbon_count := 8
	for wave_index in range(ribbon_count):
		var lane := (float(wave_index) + 0.5) / float(ribbon_count)
		var wave_offset := lane - 0.5
		var amplitude := cross_len * (0.012 + 0.01 * fmod(float(wave_index) * 1.7, 1.0))
		var phase := time * (1.25 + float(wave_index) * 0.08) + float(wave_index) * 1.47
		var steps := 28
		var previous := Vector2.ZERO
		for i in range(steps + 1):
			var ratio := float(i) / float(steps)
			var full_ratio := ratio * reveal
			var local_width := _get_wind_width(full_ratio, nozzle_width, plume_width)
			var fade_curve := sin(ratio * PI)
			var wobble := sin(ratio * TAU * 0.9 + phase) * amplitude
			wobble += sin(ratio * TAU * 2.1 + phase * 0.6) * amplitude * 0.38
			var cross := cross_len * 0.5 + wave_offset * local_width * 0.76 + wobble * fade_curve
			var point := origin + travel_axis * (visible_len * ratio) + cross_axis * cross
			if i > 0:
				var segment_ratio := float(i - 1) / float(steps)
				var head_boost := 0.55 + 0.45 * smoothstep(0.62, 1.0, ratio)
				var segment_alpha := alpha * (0.18 + 0.15 * sin(phase + float(i) * 0.7)) * sin(segment_ratio * PI) * head_boost
				var segment_width := 0.75 + 1.35 * sin(segment_ratio * PI) * (1.0 - absf(wave_offset) * 0.65)
				draw_line(previous, point, Color(0.66, 0.97, 1.0, segment_alpha), segment_width)
			previous = point

func _get_wind_width(ratio: float, nozzle_width: float, plume_width: float) -> float:
	var opened := 1.0 - pow(1.0 - clampf(ratio, 0.0, 1.0), 2.4)
	var end_soften := lerpf(1.0, 0.74, maxf(0.0, ratio - 0.72) / 0.28)
	return lerpf(nozzle_width, plume_width, opened) * end_soften


func _ease_wind_reveal(progress: float) -> float:
	var p := clampf(progress, 0.0, 1.0)
	return 1.0 - pow(1.0 - p, 2.2)


func _get_wind_alpha(progress: float) -> float:
	var p := clampf(progress, 0.0, 1.0)
	if p < 0.16:
		return p / 0.16
	if p > 0.82:
		return (1.0 - p) / 0.18
	return 1.0


func _process(_delta: float) -> void:
	_check_moving_wall_crushes()
	var now := Time.get_ticks_msec() / 1000.0
	for vent_data in _frost_vent_data:
		var area: Area2D = vent_data["area"] as Area2D
		if not is_instance_valid(area):
			continue
		var on_duration: float = vent_data.get("on_duration", FROST_VENT_VISUAL_ON_DURATION) as float
		var cycle_duration: float = vent_data.get("cycle_duration", on_duration + FROST_VENT_VISUAL_OFF_DURATION) as float
		var phase_offset: float = vent_data.get("phase_offset", 0.0) as float
		var elapsed := fmod(now + phase_offset, maxf(cycle_duration, 0.1))
		var active := elapsed < on_duration
		var was_active: bool = vent_data.get("was_active", false) as bool
		if active:
			area.set_meta("pulse_timer", maxf(0.0, on_duration - elapsed))
			area.set_meta("pulse_duration", on_duration)
			if not was_active:
				var direction: Vector2 = vent_data["direction"] as Vector2
				var force: float = vent_data.get("force", Constants.FROST_VENT_FORCE) as float
				_apply_frost_vent_force(area, direction, force)
		else:
			area.set_meta("pulse_timer", 0.0)
		vent_data["was_active"] = active
	if not _moving_wall_data.is_empty() or not _frost_vent_data.is_empty() or not _sticky_blob_data.is_empty() or not _moving_sticky_wall_data.is_empty():
		queue_redraw()


func _check_moving_wall_crushes() -> void:
	if _moving_wall_data.is_empty():
		return
	for wall_data: Dictionary in _moving_wall_data:
		var body := wall_data.get("body", null) as Node2D
		if body == null or not is_instance_valid(body):
			continue
		var last_position := wall_data.get("last_position", body.global_position) as Vector2
		var move_delta := body.global_position - last_position
		var moved_distance := move_delta.length()
		wall_data["last_position"] = body.global_position
		if moved_distance <= 0.01:
			continue
		var move_dir := move_delta / moved_distance
		var wall_size := wall_data.get("size", Vector2.ZERO) as Vector2
		var wall_rect := Rect2(body.global_position, wall_size).grow(Constants.CHARACTER_RADIUS * 0.45)
		for node: Node in get_tree().get_nodes_in_group("characters"):
			if not (node is Escapist):
				continue
			var esc := node as Escapist
			if wall_rect.has_point(esc.global_position) and _has_wall_blocking_push(esc, move_dir, body):
				_crush_escapist(esc)


func _has_wall_blocking_push(esc: Escapist, push_dir: Vector2, moving_body: Node2D) -> bool:
	if push_dir.length_squared() <= 0.01:
		return false
	var space_state := get_world_2d().direct_space_state
	var from := esc.global_position
	var to := from + push_dir.normalized() * (Constants.CHARACTER_RADIUS + 20.0)
	var query := PhysicsRayQueryParameters2D.create(from, to)
	query.collision_mask = Constants.LAYER_WALLS
	query.collide_with_areas = false
	query.collide_with_bodies = true
	if moving_body is CollisionObject2D:
		query.exclude = [(moving_body as CollisionObject2D).get_rid()]
	var hit := space_state.intersect_ray(query)
	return not hit.is_empty()


func _crush_escapist(esc: Escapist) -> void:
	if esc.is_dead or esc.has_scored:
		return
	esc.movement.crushed.emit()
