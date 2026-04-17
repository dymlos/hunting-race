class_name ElasticWeb
extends TrapperAbility

## Spider Ability 2 (RB): Taut web between 2 points that bounces escapists backward.


func setup(p_trapper: Trapper) -> void:
	super.setup(p_trapper)
	cooldown = Constants.ARANA_ELASTIC_COOLDOWN
	max_active = Constants.ARANA_ELASTIC_MAX
	points_required = 2
	max_point_distance = Constants.ARANA_ELASTIC_MAX_DIST


func _spawn_from_points(points: Array[Vector2]) -> void:
	var web := ElasticLine.new()
	web.setup(trapper.team, points[0], points[1])
	_register_object(web)


func get_display_name() -> String:
	return "Elastic"


func get_display_color() -> Color:
	return Color(0.8, 0.3, 0.9)


func draw_preview(trapper_node: Trapper) -> void:
	if not is_placing or _placement_points.is_empty():
		return
	var base_color := get_display_color()
	var valid := is_placement_valid(trapper_node.global_position)
	var cursor_color := Color(base_color, 0.7) if valid else Color(base_color, 0.15)

	var local_start := _placement_points[0] - trapper_node.global_position
	trapper_node.draw_circle(local_start, 5.0, Color(base_color, 0.5))
	trapper_node.draw_line(local_start, Vector2.ZERO, cursor_color, 1.5)

	# Range circle
	trapper_node.draw_arc(local_start, Constants.ARANA_ELASTIC_MAX_DIST, 0, TAU, 24,
		Color(base_color, 0.12), 1.0)


## --- ElasticLine inner node ---

class ElasticLine extends Area2D:
	var owner_team: Enums.Team = Enums.Team.NONE
	var _lifetime: float = Constants.ARANA_ELASTIC_LIFETIME
	var _point_a: Vector2 = Vector2.ZERO
	var _point_b: Vector2 = Vector2.ZERO
	var _color: Color = Color(0.8, 0.3, 0.9)
	var _triggered_targets: Dictionary = {}  # {Node: cooldown}

	func setup(team: Enums.Team, a: Vector2, b: Vector2) -> void:
		owner_team = team
		_point_a = a
		_point_b = b
		add_to_group("traps")

		collision_layer = Constants.LAYER_TRAPS
		collision_mask = Constants.LAYER_CHARACTERS
		monitoring = true
		monitorable = true

		# Position at midpoint
		position = (a + b) / 2.0

		# Create thin rectangle collision along the line
		var line_vec: Vector2 = b - a
		var length: float = line_vec.length()
		var angle: float = line_vec.angle()

		var shape := RectangleShape2D.new()
		shape.size = Vector2(length, Constants.ARANA_ELASTIC_WIDTH)
		var col := CollisionShape2D.new()
		col.shape = shape
		col.rotation = angle
		add_child(col)

		body_entered.connect(_on_body_entered)

	func _process(delta: float) -> void:
		if GameManager.trap_lifetime_active:
			_lifetime -= delta
		if _lifetime <= 0.0:
			queue_free()
			return

		# Tick retrigger cooldowns
		var expired: Array[Node] = []
		for target: Node in _triggered_targets:
			_triggered_targets[target] -= delta
			if _triggered_targets[target] <= 0.0:
				expired.append(target)
		for target in expired:
			_triggered_targets.erase(target)

		queue_redraw()

	func _on_body_entered(body: Node2D) -> void:
		if not GameManager.hunt_active:
			return
		if body in _triggered_targets:
			return
		if body is BaseCharacter:
			var character := body as BaseCharacter
			if character.team == owner_team:
				return
			GameManager.register_trap_contact(character.player_index, int(get_meta("owner_player_index", -1)))
			if character is Escapist:
				(character as Escapist).notify_trap_status("BOUNCED", Color(0.95, 0.35, 1.0), 0.75)
			AudioManager.play_effect(&"Bounce")

			# Calculate bounce direction: push away from the line
			var line_dir: Vector2 = (_point_b - _point_a).normalized()
			var to_body: Vector2 = body.global_position - _point_a
			var projected: Vector2 = line_dir * to_body.dot(line_dir)
			var perpendicular: Vector2 = (to_body - projected).normalized()

			if perpendicular.length_squared() < 0.01:
				perpendicular = Vector2(-line_dir.y, line_dir.x)

			# Use dash to bounce the character
			character.movement.start_dash(
				perpendicular,
				Constants.ARANA_ELASTIC_BOUNCE_DIST,
				Callable(),
				0.15
			)

			_triggered_targets[body] = 1.5  # Retrigger cooldown

	func _draw() -> void:
		var pulse := 0.8 + 0.2 * sin(Time.get_ticks_msec() / 150.0)
		var local_a := _point_a - global_position
		var local_b := _point_b - global_position

		# Main line with oscillation
		var mid := (local_a + local_b) / 2.0
		var perp := (local_b - local_a).normalized().rotated(PI / 2.0)
		var wobble := perp * sin(Time.get_ticks_msec() / 100.0) * 3.0

		draw_line(local_a, mid + wobble, Color(_color, 0.7 * pulse), 2.5)
		draw_line(mid + wobble, local_b, Color(_color, 0.7 * pulse), 2.5)

		# End points
		draw_circle(local_a, 4.0, Color(_color, 0.8))
		draw_circle(local_b, 4.0, Color(_color, 0.8))
