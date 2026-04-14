class_name Arena
extends Node2D

## Builds arena geometry from MapData at runtime, including hazards.

var _map_data: Dictionary = {}
var _wall_bodies: Array[StaticBody2D] = []
var _goal_zones: Array[Area2D] = []
var _hazard_nodes: Array[Node] = []
var _moving_wall_data: Array[Dictionary] = []  # For _draw() to render moving walls
var _frost_vent_data: Array[Dictionary] = []
var _hazard_tweens: Array[Tween] = []
var _base_hazards: Array[Dictionary] = []
var _active_hazards: Array[Dictionary] = []

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


func _duplicate_hazards(hazards: Array) -> Array[Dictionary]:
	var copies: Array[Dictionary] = []
	for hazard_def in hazards:
		if hazard_def is Dictionary:
			copies.append((hazard_def as Dictionary).duplicate(true))
	return copies


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
	crush_shape.size = wall_size * 0.3
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

	_moving_wall_data.append({"body": body, "size": wall_size})

	# Ping-pong tween
	var tween := create_tween().set_loops()
	tween.tween_property(body, "position", end_pos, period / 2.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(body, "position", pos, period / 2.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_hazard_tweens.append(tween)


func _on_moving_wall_crush(body: Node2D) -> void:
	if body is Escapist:
		var esc := body as Escapist
		if not esc.is_dead and not esc.has_scored:
			esc.movement.crushed.emit()


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
	var period: float = def.get("period", Constants.FROST_VENT_PERIOD) as float

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
	add_child(area)
	_hazard_nodes.append(area)

	var timer := Timer.new()
	timer.wait_time = period
	timer.autostart = true
	timer.timeout.connect(_on_frost_vent_timeout.bind(area, direction, force))
	area.add_child(timer)

	_frost_vent_data.append({
		"area": area,
		"vent_pos": pos,
		"vent_size": vent_size,
		"blast_rect": blast_rect,
		"direction": direction,
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


func _on_frost_vent_timeout(area: Area2D, direction: Vector2, force: float) -> void:
	if not is_instance_valid(area):
		return
	area.set_meta("pulse_timer", Constants.FROST_VENT_WARNING)
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

	# Background
	draw_rect(Rect2(Vector2.ZERO, map_size), Color(0.08, 0.08, 0.08))

	# Static walls
	var wall_color := Color(0.6, 0.6, 0.6)
	var walls: Array = _map_data.get("walls", [])
	for wall_def in walls:
		var pos: Vector2 = wall_def["pos"]
		var size: Vector2 = wall_def["size"]
		draw_rect(Rect2(pos, size), wall_color)

	# Goal zone
	var goal_rect: Rect2 = _map_data.get("goal", Rect2())
	if goal_rect.size.x > 0.0 and goal_rect.size.y > 0.0:
		var goal_color := Color(0.2, 1.0, 0.5)
		draw_rect(goal_rect, Color(goal_color, 0.2))
		draw_rect(goal_rect, goal_color, false, 2.0)

	if _map_data.get("show_respawn_marker", false) as bool:
		_draw_respawn_marker()

	# Hazards
	_draw_hazards()


func _draw_respawn_marker() -> void:
	var spawns: Array = _map_data.get("spawns", [])
	if spawns.is_empty():
		return
	var spawn: Vector2 = spawns[0] as Vector2
	var pulse := 0.5 + 0.5 * sin(Time.get_ticks_msec() / 360.0)
	var color := Color(0.25, 0.85, 1.0, 0.45 + pulse * 0.25)
	draw_circle(spawn, 30.0 + pulse * 4.0, Color(color, 0.12))
	draw_arc(spawn, 30.0 + pulse * 4.0, 0.0, TAU, 32, color, 2.0)
	draw_line(spawn + Vector2(-18.0, 0.0), spawn + Vector2(18.0, 0.0), color, 2.0)
	draw_line(spawn + Vector2(0.0, -18.0), spawn + Vector2(0.0, 18.0), color, 2.0)


func _draw_hazards() -> void:
	var now := Time.get_ticks_msec() / 1000.0

	# Moving walls (drawn at their current position)
	for mw in _moving_wall_data:
		var body: Node2D = mw["body"]
		var size: Vector2 = mw["size"]
		if is_instance_valid(body):
			draw_rect(Rect2(body.position, size), Constants.MOVING_WALL_COLOR)

	# Slippery zones and one-way gates from hazard defs
	for hazard_def in _active_hazards:
		var hazard_type: String = hazard_def.get("type", "") as String
		match hazard_type:
			"slippery_zone":
				var pos: Vector2 = hazard_def["pos"]
				var size: Vector2 = hazard_def["size"]
				draw_rect(Rect2(pos, size), Constants.SLIPPERY_ZONE_COLOR)
			"one_way_gate":
				var pos: Vector2 = hazard_def["pos"]
				var size: Vector2 = hazard_def["size"]
				var dir: Vector2 = hazard_def["direction"]
				draw_rect(Rect2(pos, size), Constants.ONE_WAY_COLOR)
				# Arrow in allowed direction
				var center := pos + size / 2.0
				var arrow_len := minf(size.x, size.y) * 0.3
				var tip := center + dir.normalized() * arrow_len
				var base := center - dir.normalized() * arrow_len
				draw_line(base, tip, Color(0.2, 1.0, 0.4, 0.8), 3.0)
				# Arrowhead
				var perp := Vector2(-dir.y, dir.x).normalized() * 6.0
				draw_line(tip, tip - dir.normalized() * 10.0 + perp, Color(0.2, 1.0, 0.4, 0.8), 2.0)
				draw_line(tip, tip - dir.normalized() * 10.0 - perp, Color(0.2, 1.0, 0.4, 0.8), 2.0)
			"sticky_wall":
				var pos: Vector2 = hazard_def["pos"]
				var size: Vector2 = hazard_def["size"]
				draw_rect(Rect2(pos, size), Constants.STICKY_WALL_COLOR)
				# Hatching pattern to indicate danger
				var step := 12.0
				var hatch_color := Color(Constants.STICKY_WALL_COLOR, 0.5)
				var hx := pos.x
				while hx < pos.x + size.x + size.y:
					var x0 := maxf(hx, pos.x)
					var x1 := minf(hx + size.y, pos.x + size.x)
					if x0 < pos.x + size.x and x1 > pos.x:
						var y0 := pos.y + (x0 - hx)
						var y1 := pos.y + (x1 - hx)
						draw_line(Vector2(x0, y0), Vector2(x1, y1), hatch_color, 1.0)
					hx += step
			"ice_box":
				var pos: Vector2 = hazard_def["pos"]
				var size: Vector2 = hazard_def["size"]
				draw_rect(Rect2(pos, size), Color(0.62, 0.62, 0.62))
				draw_rect(Rect2(pos, size), Color(0.86, 0.86, 0.86, 0.65), false, 2.0)
			"frost_vent":
				var pos: Vector2 = hazard_def["pos"]
				var size: Vector2 = hazard_def["size"]
				draw_rect(Rect2(pos, size), Constants.FROST_VENT_COLOR)
				draw_rect(Rect2(pos, size), Color(0.75, 1.0, 1.0, 0.8), false, 2.0)
				var direction: Vector2 = (hazard_def.get("direction", Vector2.DOWN) as Vector2).normalized()
				var center := pos + size / 2.0
				draw_line(center, center + direction * 18.0, Color(0.75, 1.0, 1.0, 0.9), 3.0)

	for vent_data in _frost_vent_data:
		var area: Area2D = vent_data["area"] as Area2D
		if not is_instance_valid(area):
			continue
		var pulse_timer: float = area.get_meta("pulse_timer", 0.0) as float
		if pulse_timer <= 0.0:
			continue
		var blast_rect: Rect2 = vent_data["blast_rect"] as Rect2
		var direction: Vector2 = vent_data["direction"] as Vector2
		var alpha := clampf(pulse_timer / Constants.FROST_VENT_WARNING, 0.0, 1.0)
		_draw_frost_waves(blast_rect, direction, alpha, now)


func _draw_frost_waves(rect: Rect2, direction: Vector2, alpha: float, time: float) -> void:
	var dir := direction.normalized()
	if dir == Vector2.ZERO:
		dir = Vector2.RIGHT
	var along_horizontal := absf(dir.x) >= absf(dir.y)
	var travel_len := rect.size.x if along_horizontal else rect.size.y
	var cross_len := rect.size.y if along_horizontal else rect.size.x
	var travel_axis := Vector2.RIGHT if along_horizontal else Vector2.DOWN
	var cross_axis := Vector2.DOWN if along_horizontal else Vector2.RIGHT
	if dir.dot(travel_axis) < 0.0:
		travel_axis = -travel_axis
	var origin := rect.position
	if travel_axis.x < 0.0:
		origin.x = rect.end.x
	if travel_axis.y < 0.0:
		origin.y = rect.end.y

	var base_color := Color(Constants.FROST_VENT_COLOR, 0.25 + alpha * 0.25)
	var wave_count := 3
	for wave_index in range(wave_count):
		var wave_offset := (float(wave_index) - 1.0) * cross_len * 0.18
		var amplitude := cross_len * (0.05 + 0.015 * float(wave_index))
		var points := PackedVector2Array()
		var steps := 18
		for i in range(steps + 1):
			var ratio := float(i) / float(steps)
			var travel := ratio * travel_len
			var wobble := sin(ratio * TAU * 1.6 + time * 4.0 + float(wave_index) * 0.8) * amplitude
			var cross := cross_len * 0.5 + wave_offset + wobble
			var point := origin + travel_axis * travel + cross_axis * cross
			points.append(point)
		draw_polyline(points, Color(base_color.r, base_color.g, base_color.b, base_color.a), 4.0)

		var spark_phase := fmod(time * 1.4 + float(wave_index) * 0.33, 1.0)
		var spark_pos := origin + travel_axis * (travel_len * spark_phase) + cross_axis * (cross_len * 0.5 + wave_offset)
		draw_circle(spark_pos, 4.0 + alpha * 2.0, Color(1.0, 1.0, 1.0, 0.18 + alpha * 0.22))


func _process(_delta: float) -> void:
	for vent_data in _frost_vent_data:
		var area: Area2D = vent_data["area"] as Area2D
		if not is_instance_valid(area):
			continue
		var pulse_timer: float = area.get_meta("pulse_timer", 0.0) as float
		if pulse_timer > 0.0:
			area.set_meta("pulse_timer", maxf(0.0, pulse_timer - _delta))
	if not _moving_wall_data.is_empty() or not _frost_vent_data.is_empty():
		queue_redraw()
