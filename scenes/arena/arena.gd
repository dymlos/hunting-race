class_name Arena
extends Node2D

## Builds arena geometry from MapData at runtime, including hazards.

var _map_data: Dictionary = {}
var _wall_bodies: Array[StaticBody2D] = []
var _goal_zones: Array[Area2D] = []
var _hazard_nodes: Array[Node] = []
var _moving_wall_data: Array[Dictionary] = []  # For _draw() to render moving walls

signal goal_entered(escapist: Escapist)


func load_map(map_data: Dictionary) -> void:
	_map_data = map_data
	_clear()
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
	for node in _hazard_nodes:
		node.queue_free()
	_hazard_nodes.clear()
	_moving_wall_data.clear()


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

func _build_hazards() -> void:
	var hazards: Array = _map_data.get("hazards", [])
	for hazard_def in hazards:
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


func _build_moving_wall(def: Dictionary) -> void:
	var pos: Vector2 = def["pos"]
	var wall_size: Vector2 = def["size"]
	var end_pos: Vector2 = def["end_pos"]
	var period: float = def.get("period", 4.0)

	# AnimatableBody2D pushes characters when moving (unlike StaticBody2D)
	var body := AnimatableBody2D.new()
	body.collision_layer = Constants.LAYER_WALLS
	body.collision_mask = 0

	var shape := RectangleShape2D.new()
	shape.size = wall_size

	var col := CollisionShape2D.new()
	col.shape = shape
	col.position = wall_size / 2.0

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


func _on_moving_wall_crush(body: Node2D) -> void:
	if body is Escapist:
		var esc := body as Escapist
		if not esc.is_dead and not esc.has_scored:
			esc.movement.crushed.emit()


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


# --- Drawing ---

func _draw() -> void:
	if _map_data.is_empty():
		return

	var map_size := get_map_size()

	# Background
	draw_rect(Rect2(Vector2.ZERO, map_size), Color(0.08, 0.08, 0.08))

	# Grid lines
	var grid_step := 60.0
	var grid_color := Color(0.15, 0.15, 0.15)
	var x := 0.0
	while x <= map_size.x:
		draw_line(Vector2(x, 0), Vector2(x, map_size.y), grid_color, 1.0)
		x += grid_step
	var y := 0.0
	while y <= map_size.y:
		draw_line(Vector2(0, y), Vector2(map_size.x, y), grid_color, 1.0)
		y += grid_step

	# Static walls
	var wall_color := Color(0.6, 0.6, 0.6)
	var walls: Array = _map_data.get("walls", [])
	for wall_def in walls:
		var pos: Vector2 = wall_def["pos"]
		var size: Vector2 = wall_def["size"]
		draw_rect(Rect2(pos, size), wall_color)

	# Goal zone
	var goal_rect: Rect2 = _map_data.get("goal", Rect2())
	var goal_color := Color(0.2, 1.0, 0.5)  # Green — matches escapist color
	draw_rect(goal_rect, Color(goal_color, 0.2))
	draw_rect(goal_rect, goal_color, false, 2.0)

	# Hazards
	_draw_hazards()


func _draw_hazards() -> void:
	# Moving walls (drawn at their current position)
	for mw in _moving_wall_data:
		var body: StaticBody2D = mw["body"]
		var size: Vector2 = mw["size"]
		if is_instance_valid(body):
			draw_rect(Rect2(body.position, size), Constants.MOVING_WALL_COLOR)

	# Slippery zones and one-way gates from hazard defs
	var hazards: Array = _map_data.get("hazards", [])
	for hazard_def in hazards:
		var hazard_type: String = hazard_def.get("type", "") as String
		match hazard_type:
			"slippery_zone":
				var pos: Vector2 = hazard_def["pos"]
				var size: Vector2 = hazard_def["size"]
				draw_rect(Rect2(pos, size), Constants.SLIPPERY_ZONE_COLOR)
				# Ice pattern — diagonal lines
				var step := 20.0
				var ice_color := Color(0.3, 0.8, 1.0, 0.1)
				var ix := pos.x
				while ix < pos.x + size.x:
					draw_line(Vector2(ix, pos.y), Vector2(ix + size.y * 0.3, pos.y + size.y), ice_color, 1.0)
					ix += step
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


func _process(_delta: float) -> void:
	if not _moving_wall_data.is_empty():
		queue_redraw()
