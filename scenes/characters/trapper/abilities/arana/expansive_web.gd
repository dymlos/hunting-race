class_name ExpansiveWeb
extends TrapperAbility

## Spider Ability 1 (A): Weave a web between 3 points forming a slow zone.


func setup(p_trapper: Trapper) -> void:
	super.setup(p_trapper)
	cooldown = Constants.ARANA_WEB_COOLDOWN
	max_active = Constants.ARANA_WEB_MAX
	points_required = 3
	max_point_distance = Constants.ARANA_WEB_MAX_DIST


func _spawn_from_points(points: Array[Vector2]) -> void:
	var web := WebZone.new()
	web.setup(trapper.team, points)
	_register_object(web)


func get_display_name() -> String:
	return "Web"


func get_display_color() -> Color:
	return Enums.trapper_character_color(Enums.TrapperCharacter.ARANA)


func draw_preview(trapper_node: Trapper) -> void:
	if not is_placing or _placement_points.is_empty():
		return
	var base_color := get_display_color()
	var valid := is_placement_valid(trapper_node.global_position)
	var cursor_color := Color(base_color, 0.7) if valid else Color(base_color, 0.15)

	# Draw placed points and lines between them
	var prev := Vector2.ZERO
	for i in _placement_points.size():
		var local := _placement_points[i] - trapper_node.global_position
		trapper_node.draw_circle(local, 5.0, Color(base_color, 0.5))
		if i > 0:
			trapper_node.draw_line(prev, local, Color(base_color, 0.4), 1.5)
		prev = local

	# Line from last point to cursor
	trapper_node.draw_line(prev, Vector2.ZERO, cursor_color, 1.5)

	# Range circle around last placed point
	trapper_node.draw_arc(prev, Constants.ARANA_WEB_MAX_DIST, 0, TAU, 24,
		Color(base_color, 0.12), 1.0)


## --- WebZone inner node ---

class WebZone extends Area2D:
	var owner_team: Enums.Team = Enums.Team.NONE
	var _lifetime: float = Constants.ARANA_WEB_LIFETIME
	var _points: Array[Vector2] = []
	var _color: Color = Color.WHITE
	var _affected_bodies: Dictionary = {}  # {Node: true}

	func setup(team: Enums.Team, points: Array[Vector2]) -> void:
		owner_team = team
		_points = points
		_color = Enums.trapper_character_color(Enums.TrapperCharacter.ARANA)
		add_to_group("traps")

		collision_layer = Constants.LAYER_TRAPS
		collision_mask = Constants.LAYER_CHARACTERS
		monitoring = true
		monitorable = true

		# Position at centroid
		var centroid := Vector2.ZERO
		for pt: Vector2 in _points:
			centroid += pt
		centroid /= float(_points.size())
		position = centroid

		# Create polygon collision
		var polygon := PackedVector2Array()
		for pt: Vector2 in _points:
			polygon.append(pt - centroid)
		var shape := ConvexPolygonShape2D.new()
		shape.points = polygon
		var col := CollisionShape2D.new()
		col.shape = shape
		add_child(col)

		body_entered.connect(_on_body_entered)
		body_exited.connect(_on_body_exited)

	func _process(delta: float) -> void:
		if GameManager.is_trap_lifetime_active():
			_lifetime -= delta
		if _lifetime <= 0.0:
			_cleanup_effects()
			queue_free()
			return

		# Apply slow to all bodies inside
		for body: Node in _affected_bodies:
			if is_instance_valid(body) and body is BaseCharacter:
				var character := body as BaseCharacter
				if character.team != owner_team:
					character.movement.set_speed_modifier(&"web_slow", Constants.ARANA_WEB_SLOW)

		queue_redraw()

	func _on_body_entered(body: Node2D) -> void:
		if not GameManager.is_trap_interaction_active():
			return
		if body is BaseCharacter:
			var character := body as BaseCharacter
			if character.team == owner_team:
				return
			GameManager.register_trap_contact(character.player_index, int(get_meta("owner_player_index", -1)))
			_affected_bodies[body] = true
			character.movement.set_speed_modifier(&"web_slow", Constants.ARANA_WEB_SLOW)
			AudioManager.play_effect(&"SlowMovement")

	func _on_body_exited(body: Node2D) -> void:
		_affected_bodies.erase(body)
		if is_instance_valid(body) and body is BaseCharacter:
			(body as BaseCharacter).movement.remove_speed_modifier(&"web_slow")

	func _cleanup_effects() -> void:
		for body: Node in _affected_bodies:
			if is_instance_valid(body) and body is BaseCharacter:
				(body as BaseCharacter).movement.remove_speed_modifier(&"web_slow")
		_affected_bodies.clear()

	func _draw() -> void:
		var pulse := 0.7 + 0.3 * sin(Time.get_ticks_msec() / 400.0)
		var local_pts: Array[Vector2] = []
		for pt: Vector2 in _points:
			local_pts.append(pt - global_position)

		# Fill
		if local_pts.size() >= 3:
			var packed := PackedVector2Array()
			for pt: Vector2 in local_pts:
				packed.append(pt)
			draw_colored_polygon(packed, Color(_color, 0.1 * pulse))

		# Web lines between all points
		for i in local_pts.size():
			for j in range(i + 1, local_pts.size()):
				draw_line(local_pts[i], local_pts[j], Color(_color, 0.4 * pulse), 1.5)

		# Cross-hatch pattern
		var center := Vector2.ZERO
		for pt: Vector2 in local_pts:
			draw_line(center, pt, Color(_color, 0.25 * pulse), 1.0)
