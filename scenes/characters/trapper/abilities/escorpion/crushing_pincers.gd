class_name CrushingPincers
extends TrapperAbility

## Scorpion Ability 3 (X): Two walls placed at 2 points. When an escapist enters
## the zone between them, the walls close and crush. Uses existing crush detection.


func setup(p_trapper: Trapper) -> void:
	super.setup(p_trapper)
	cooldown = Constants.ESCORPION_PINCERS_COOLDOWN
	max_active = Constants.ESCORPION_PINCERS_MAX
	points_required = 2


func _spawn_from_points(points: Array[Vector2]) -> void:
	var pincers := PincersNode.new()
	pincers.setup(trapper.team, points[0], points[1])
	_register_object(pincers)


func get_display_name() -> String:
	return "Pinzas"


func get_display_color() -> Color:
	return Color(0.9, 0.3, 0.1)


func draw_preview(trapper_node: Trapper) -> void:
	if not is_placing or _placement_points.is_empty():
		return
	var color := Color(get_display_color(), 0.4)
	var local_start := _placement_points[0] - trapper_node.global_position
	trapper_node.draw_circle(local_start, 5.0, color)
	# Draw wall preview
	var perp := (Vector2.ZERO - local_start).normalized().rotated(PI / 2.0)
	var half_len := Constants.ESCORPION_PINCERS_WALL_LENGTH / 2.0
	trapper_node.draw_line(local_start - perp * half_len, local_start + perp * half_len, color, 3.0)
	trapper_node.draw_line(-perp * half_len, perp * half_len, Color(color, 0.2), 3.0)


## --- PincersNode inner node ---

class PincersNode extends Node2D:
	var owner_team: Enums.Team = Enums.Team.NONE
	var _lifetime: float = Constants.ESCORPION_PINCERS_LIFETIME
	var _color: Color = Enums.trapper_character_color(Enums.TrapperCharacter.ESCORPION)

	var _wall_a: AnimatableBody2D
	var _wall_b: AnimatableBody2D
	var _pos_a: Vector2 = Vector2.ZERO  # Open position
	var _pos_b: Vector2 = Vector2.ZERO  # Open position
	var _center: Vector2 = Vector2.ZERO
	var _wall_angle: float = 0.0

	# Trigger zone
	var _trigger: Area2D

	enum PincerState { OPEN, CLOSING, CLOSED, RESETTING }
	var _state: PincerState = PincerState.OPEN
	var _state_timer: float = 0.0
	var _close_time: float = Constants.ESCORPION_PINCERS_CLOSE_TIME

	func setup(team: Enums.Team, point_a: Vector2, point_b: Vector2) -> void:
		owner_team = team
		_pos_a = point_a
		_pos_b = point_b
		_center = (point_a + point_b) / 2.0
		position = _center
		add_to_group("traps")

		var line_vec: Vector2 = point_b - point_a
		_wall_angle = line_vec.angle()
		var perp_angle := _wall_angle + PI / 2.0

		# Create two wall segments
		_wall_a = _create_wall(point_a - _center, perp_angle, -1.0)
		_wall_b = _create_wall(point_b - _center, perp_angle, 1.0)
		add_child(_wall_a)
		add_child(_wall_b)

		# Create trigger zone between the two walls
		_trigger = Area2D.new()
		_trigger.collision_layer = 0
		_trigger.collision_mask = Constants.LAYER_CHARACTERS
		_trigger.monitoring = true
		var trigger_shape := RectangleShape2D.new()
		var dist: float = point_a.distance_to(point_b)
		trigger_shape.size = Vector2(dist, Constants.ESCORPION_PINCERS_WALL_LENGTH)
		var trigger_col := CollisionShape2D.new()
		trigger_col.shape = trigger_shape
		trigger_col.rotation = _wall_angle
		_trigger.add_child(trigger_col)
		add_child(_trigger)
		_trigger.body_entered.connect(_on_trigger_entered)

	func _create_wall(local_pos: Vector2, angle: float, inward_sign: float) -> AnimatableBody2D:
		var wall := AnimatableBody2D.new()
		wall.position = local_pos
		wall.rotation = angle

		var shape := RectangleShape2D.new()
		shape.size = Vector2(
			Constants.ESCORPION_PINCERS_WALL_LENGTH,
			Constants.ESCORPION_PINCERS_WALL_THICKNESS)
		var col := CollisionShape2D.new()
		col.shape = shape
		wall.add_child(col)
		_add_teeth_collisions(wall, inward_sign)

		wall.collision_layer = Constants.LAYER_WALLS
		wall.collision_mask = 0

		return wall

	func _add_teeth_collisions(wall: AnimatableBody2D, inward_sign: float) -> void:
		var count := Constants.ESCORPION_PINCERS_TEETH_COUNT
		var spacing := Constants.ESCORPION_PINCERS_WALL_LENGTH / float(count + 1)
		var base_y := inward_sign * Constants.ESCORPION_PINCERS_WALL_THICKNESS / 2.0
		var tip_y := inward_sign * (
			Constants.ESCORPION_PINCERS_WALL_THICKNESS / 2.0
			+ Constants.ESCORPION_PINCERS_TOOTH_DEPTH)
		for i in range(count):
			var center_x := -Constants.ESCORPION_PINCERS_WALL_LENGTH / 2.0 + spacing * float(i + 1)
			var half_width := Constants.ESCORPION_PINCERS_TOOTH_WIDTH / 2.0
			var tooth := CollisionPolygon2D.new()
			tooth.polygon = PackedVector2Array([
				Vector2(center_x - half_width, base_y),
				Vector2(center_x + half_width, base_y),
				Vector2(center_x, tip_y),
			])
			wall.add_child(tooth)

	func _process(delta: float) -> void:
		if GameManager.is_trap_lifetime_active():
			_lifetime -= delta
		if _lifetime <= 0.0:
			queue_free()
			return

		match _state:
			PincerState.CLOSING:
				if _should_break_from_blocker():
					queue_free()
					return
				_state_timer -= delta
				var ratio := 1.0 - clampf(_state_timer / _close_time, 0.0, 1.0)
				var local_a := _pos_a - _center
				var local_b := _pos_b - _center
				_wall_a.position = local_a.lerp(Vector2.ZERO, ratio)
				_wall_b.position = local_b.lerp(Vector2.ZERO, ratio)
				_damage_targets_touching_walls()
				_crush_targets_between_pincers()
				if _state_timer <= 0.0:
					_state = PincerState.CLOSED
					_state_timer = Constants.ESCORPION_PINCERS_RESET_TIME

			PincerState.CLOSED:
				_damage_targets_touching_walls()
				_crush_targets_between_pincers()
				_state_timer -= delta
				if _state_timer <= 0.0:
					_state = PincerState.RESETTING
					_state_timer = 0.5

			PincerState.RESETTING:
				_state_timer -= delta
				var ratio := clampf(_state_timer / 0.5, 0.0, 1.0)
				var local_a := _pos_a - _center
				var local_b := _pos_b - _center
				_wall_a.position = local_a.lerp(Vector2.ZERO, ratio)
				_wall_b.position = local_b.lerp(Vector2.ZERO, ratio)
				if _state_timer <= 0.0:
					_wall_a.position = _pos_a - _center
					_wall_b.position = _pos_b - _center
					_state = PincerState.OPEN

		queue_redraw()

	func _on_trigger_entered(body: Node2D) -> void:
		if not GameManager.is_trap_interaction_active():
			return
		if _state != PincerState.OPEN:
			return
		if body is BaseCharacter:
			var character := body as BaseCharacter
			if character.team == owner_team:
				return
			GameManager.register_trap_contact(character.player_index, int(get_meta("owner_player_index", -1)))
			if character is Escapist:
				(character as Escapist).notify_trap_status("APRETADO", Color(1.0, 0.32, 0.12), 0.8)
			_close_time = _get_close_time()
			if _should_break_from_blocker():
				queue_free()
				return
			_state = PincerState.CLOSING
			_state_timer = _close_time
			AudioManager.play_effect(&"PincersClose")

	func _get_close_time() -> float:
		var dist := _pos_a.distance_to(_pos_b)
		var distance_ratio := inverse_lerp(
			Constants.ESCORPION_PINCERS_SLOW_DISTANCE,
			Constants.ESCORPION_PINCERS_FAST_DISTANCE,
			dist)
		distance_ratio = clampf(distance_ratio, 0.0, 1.0)
		return lerpf(
			Constants.ESCORPION_PINCERS_MAX_CLOSE_TIME,
			Constants.ESCORPION_PINCERS_MIN_CLOSE_TIME,
			distance_ratio)

	func _should_break_from_blocker() -> bool:
		if _pos_a.distance_to(_pos_b) < Constants.ESCORPION_PINCERS_BREAK_DISTANCE:
			return false

		var space_state := get_world_2d().direct_space_state
		var query := PhysicsRayQueryParameters2D.create(
			_wall_a.global_position,
			_wall_b.global_position,
			Constants.LAYER_WALLS | Constants.LAYER_TRAPS)
		query.collide_with_areas = true
		query.collide_with_bodies = true
		query.exclude = [_wall_a.get_rid(), _wall_b.get_rid()]
		return not space_state.intersect_ray(query).is_empty()

	func _crush_targets_between_pincers() -> void:
		var wall_distance := _wall_a.global_position.distance_to(_wall_b.global_position)
		var crush_distance := Constants.CHARACTER_RADIUS * 2.0 \
			+ Constants.ESCORPION_PINCERS_WALL_THICKNESS \
			+ Constants.ESCORPION_PINCERS_CRUSH_MARGIN
		if wall_distance > crush_distance:
			return

		var close_axis := (_wall_b.global_position - _wall_a.global_position).normalized()
		if close_axis.length_squared() <= 0.01:
			return
		var wall_axis := close_axis.rotated(PI / 2.0)
		var center := (_wall_a.global_position + _wall_b.global_position) / 2.0
		var half_gap := wall_distance / 2.0 + Constants.CHARACTER_RADIUS
		var half_length := Constants.ESCORPION_PINCERS_WALL_LENGTH / 2.0 \
			+ Constants.CHARACTER_RADIUS \
			+ Constants.ESCORPION_PINCERS_TOOTH_DEPTH

		for node: Node in get_tree().get_nodes_in_group("characters"):
			if not node is Escapist:
				continue
			var esc := node as Escapist
			if not _shares_skill_test_scope(esc):
				continue
			if esc.team == owner_team or esc.is_dead or esc.has_scored:
				continue
			var offset := esc.global_position - center
			if absf(offset.dot(close_axis)) > half_gap:
				continue
			if absf(offset.dot(wall_axis)) > half_length:
				continue
			esc.movement.crushed.emit()

	func _damage_targets_touching_walls() -> void:
		for node: Node in get_tree().get_nodes_in_group("characters"):
			if not node is Escapist:
				continue
			var esc := node as Escapist
			if not _shares_skill_test_scope(esc):
				continue
			if esc.team == owner_team or esc.is_dead or esc.has_scored:
				continue
			if _is_touching_wall_segment(esc.global_position, _wall_a.global_position) \
					or _is_touching_wall_segment(esc.global_position, _wall_b.global_position):
				esc.notify_trap_status("APRETADO", Color(1.0, 0.32, 0.12), 0.8)
				esc.movement.crushed.emit()

	func _is_touching_wall_segment(target: Vector2, wall_center: Vector2) -> bool:
		var wall_axis := Vector2.from_angle(_wall_angle + PI / 2.0)
		var segment_start := wall_center - wall_axis * (Constants.ESCORPION_PINCERS_WALL_LENGTH * 0.5)
		var segment_end := wall_center + wall_axis * (Constants.ESCORPION_PINCERS_WALL_LENGTH * 0.5)
		var touch_radius := Constants.CHARACTER_RADIUS \
			+ Constants.ESCORPION_PINCERS_WALL_THICKNESS * 0.5 \
			+ Constants.ESCORPION_PINCERS_TOOTH_DEPTH * 0.55
		return _distance_point_to_segment(target, segment_start, segment_end) <= touch_radius

	func _distance_point_to_segment(point: Vector2, a: Vector2, b: Vector2) -> float:
		var segment := b - a
		var length_sq := segment.length_squared()
		if length_sq <= 0.01:
			return point.distance_to(a)
		var t := clampf((point - a).dot(segment) / length_sq, 0.0, 1.0)
		return point.distance_to(a + segment * t)

	func _shares_skill_test_scope(node: Node) -> bool:
		var own_scope := ""
		if has_meta("skill_test_id"):
			own_scope = str(get_meta("skill_test_id"))
		var other_scope := ""
		if node.has_meta("skill_test_id"):
			other_scope = str(node.get_meta("skill_test_id"))
		if own_scope.is_empty() and other_scope.is_empty():
			return true
		return own_scope == other_scope

	func _draw() -> void:
		var local_a := _wall_a.position
		var local_b := _wall_b.position
		var perp := Vector2.from_angle(_wall_angle + PI / 2.0)
		var half_len := Constants.ESCORPION_PINCERS_WALL_LENGTH / 2.0

		var wall_color := _color
		if _state == PincerState.CLOSING:
			wall_color = Color(1.0, 0.2, 0.1)
		elif _state == PincerState.CLOSED:
			wall_color = Color(1.0, 0.1, 0.05)

		# Wall A
		draw_line(
			local_a - perp * half_len,
			local_a + perp * half_len,
			wall_color,
			Constants.ESCORPION_PINCERS_WALL_THICKNESS)
		# Wall B
		draw_line(
			local_b - perp * half_len,
			local_b + perp * half_len,
			wall_color,
			Constants.ESCORPION_PINCERS_WALL_THICKNESS)
		_draw_teeth(local_a, perp, Vector2.from_angle(_wall_angle), wall_color)
		_draw_teeth(local_b, perp, -Vector2.from_angle(_wall_angle), wall_color)

		# Danger zone between walls (when open)
		if _state == PincerState.OPEN:
			var zone_color := Color(_color, 0.05 + 0.03 * sin(Time.get_ticks_msec() / 300.0))
			draw_line(local_a, local_b, zone_color, Constants.ESCORPION_PINCERS_WALL_LENGTH * 0.3)

	func _draw_teeth(wall_pos: Vector2, wall_axis: Vector2, inward_dir: Vector2, color: Color) -> void:
		var count := Constants.ESCORPION_PINCERS_TEETH_COUNT
		var spacing := Constants.ESCORPION_PINCERS_WALL_LENGTH / float(count + 1)
		var base_offset := inward_dir * Constants.ESCORPION_PINCERS_WALL_THICKNESS / 2.0
		var tip_offset := inward_dir * (
			Constants.ESCORPION_PINCERS_WALL_THICKNESS / 2.0
			+ Constants.ESCORPION_PINCERS_TOOTH_DEPTH)
		for i in range(count):
			var center := -Constants.ESCORPION_PINCERS_WALL_LENGTH / 2.0 + spacing * float(i + 1)
			var half_width := Constants.ESCORPION_PINCERS_TOOTH_WIDTH / 2.0
			var base_left := wall_pos + wall_axis * (center - half_width) + base_offset
			var base_right := wall_pos + wall_axis * (center + half_width) + base_offset
			var tip := wall_pos + wall_axis * center + tip_offset
			draw_colored_polygon(PackedVector2Array([base_left, base_right, tip]), color)
