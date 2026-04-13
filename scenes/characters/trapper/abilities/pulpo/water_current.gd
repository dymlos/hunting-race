class_name WaterCurrent
extends TrapperAbility

## Pulpo Ability 3 (X): Directional flow between 2 points. Escapists inside
## are pushed in the flow direction, overriding their movement in that axis.


func setup(p_trapper: Trapper) -> void:
	super.setup(p_trapper)
	cooldown = Constants.PULPO_CURRENT_COOLDOWN
	max_active = Constants.PULPO_CURRENT_MAX
	points_required = 2


func _spawn_from_points(points: Array[Vector2]) -> void:
	var current := CurrentZone.new()
	current.setup(trapper.team, points[0], points[1])
	_register_object(current)


func get_display_name() -> String:
	return "Current"


func get_display_color() -> Color:
	return Color(0.2, 0.7, 1.0)


func draw_preview(trapper_node: Trapper) -> void:
	if not is_placing or _placement_points.is_empty():
		return
	var color := Color(get_display_color(), 0.4)
	var local_start := _placement_points[0] - trapper_node.global_position
	trapper_node.draw_circle(local_start, 5.0, color)
	# Arrow showing direction
	trapper_node.draw_line(local_start, Vector2.ZERO, color, 2.0)
	var dir := (Vector2.ZERO - local_start).normalized()
	var arrow_size := 8.0
	trapper_node.draw_line(Vector2.ZERO, -dir.rotated(0.5) * arrow_size, color, 2.0)
	trapper_node.draw_line(Vector2.ZERO, -dir.rotated(-0.5) * arrow_size, color, 2.0)


## --- CurrentZone inner node ---

class CurrentZone extends Area2D:
	var owner_team: Enums.Team = Enums.Team.NONE
	var _lifetime: float = Constants.PULPO_CURRENT_LIFETIME
	var _color: Color = Color(0.2, 0.7, 1.0)
	var _point_a: Vector2 = Vector2.ZERO
	var _point_b: Vector2 = Vector2.ZERO
	var _flow_dir: Vector2 = Vector2.ZERO
	var _bodies_inside: Dictionary = {}  # {Node: true}

	func setup(team: Enums.Team, a: Vector2, b: Vector2) -> void:
		owner_team = team
		_point_a = a
		_point_b = b
		_flow_dir = (b - a).normalized()
		add_to_group("traps")

		collision_layer = Constants.LAYER_TRAPS
		collision_mask = Constants.LAYER_CHARACTERS
		monitoring = true
		monitorable = true

		# Position at midpoint
		position = (a + b) / 2.0

		# Rectangle collision along the line
		var line_vec: Vector2 = b - a
		var length: float = line_vec.length()
		var angle: float = line_vec.angle()

		var shape := RectangleShape2D.new()
		shape.size = Vector2(length, Constants.PULPO_CURRENT_WIDTH)
		var col := CollisionShape2D.new()
		col.shape = shape
		col.rotation = angle
		add_child(col)

		body_entered.connect(_on_body_entered)
		body_exited.connect(_on_body_exited)

	func _process(delta: float) -> void:
		if GameManager.trap_lifetime_active:
			_lifetime -= delta
		if _lifetime <= 0.0:
			queue_free()
			return

		if not GameManager.hunt_active:
			queue_redraw()
			return

		# Apply current force to all bodies inside
		for body: Node in _bodies_inside:
			if not is_instance_valid(body) or not body is BaseCharacter:
				continue
			var character := body as BaseCharacter
			if character.team == owner_team:
				continue
			# Strong push in flow direction
			character.movement.velocity += _flow_dir * Constants.PULPO_CURRENT_FORCE * delta

		queue_redraw()

	func _on_body_entered(body: Node2D) -> void:
		if body is BaseCharacter:
			var character := body as BaseCharacter
			if character.team == owner_team:
				return
			GameManager.register_trap_contact(character.player_index)
			_bodies_inside[body] = true

	func _on_body_exited(body: Node2D) -> void:
		_bodies_inside.erase(body)

	func _draw() -> void:
		var local_a := _point_a - global_position
		var local_b := _point_b - global_position
		var t := Time.get_ticks_msec() / 1000.0
		var half_w := Constants.PULPO_CURRENT_WIDTH / 2.0
		var perp := _flow_dir.rotated(PI / 2.0) * half_w

		# Zone rectangle
		var corners: PackedVector2Array = PackedVector2Array([
			local_a + perp, local_b + perp, local_b - perp, local_a - perp
		])
		draw_colored_polygon(corners, Color(_color, 0.08))

		# Border
		for i in corners.size():
			draw_line(corners[i], corners[(i + 1) % corners.size()], Color(_color, 0.25), 1.5)

		# Flowing arrows
		var length: float = local_a.distance_to(local_b)
		var arrow_count := int(length / 30.0)
		for i in arrow_count:
			var ratio := fmod(float(i) / float(arrow_count) + t * 0.5, 1.0)
			var pos := local_a.lerp(local_b, ratio)
			var arrow_size := 6.0
			var dir_local := (local_b - local_a).normalized()
			# Arrow head
			draw_line(pos, pos - dir_local.rotated(0.5) * arrow_size,
				Color(_color, 0.4), 1.5)
			draw_line(pos, pos - dir_local.rotated(-0.5) * arrow_size,
				Color(_color, 0.4), 1.5)

		# Flow lines (wavy)
		for offset_i in 3:
			var offset_ratio := (float(offset_i) - 1.0) / 2.0
			var line_offset := perp * offset_ratio * 0.6
			var points_count := 10
			var prev_pt := local_a + line_offset
			for pi in range(1, points_count + 1):
				var r := float(pi) / float(points_count)
				var base := local_a.lerp(local_b, r) + line_offset
				var wave := perp.normalized() * sin(r * 8.0 + t * 4.0 + offset_i) * 3.0
				var pt := base + wave
				draw_line(prev_pt, pt, Color(_color, 0.2), 1.0)
				prev_pt = pt
