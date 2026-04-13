class_name CrushingPincers
extends TrapperAbility

## Escorpión Ability 3 (X): Two walls placed at 2 points. When an escapist enters
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
	return "Pincers"


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
		_wall_a = _create_wall(point_a - _center, perp_angle)
		_wall_b = _create_wall(point_b - _center, perp_angle)
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

	func _create_wall(local_pos: Vector2, angle: float) -> AnimatableBody2D:
		var wall := AnimatableBody2D.new()
		wall.position = local_pos
		wall.rotation = angle

		var shape := RectangleShape2D.new()
		shape.size = Vector2(Constants.ESCORPION_PINCERS_WALL_LENGTH, 8.0)
		var col := CollisionShape2D.new()
		col.shape = shape
		wall.add_child(col)

		wall.collision_layer = Constants.LAYER_WALLS
		wall.collision_mask = 0

		return wall

	func _process(delta: float) -> void:
		if GameManager.trap_lifetime_active:
			_lifetime -= delta
		if _lifetime <= 0.0:
			queue_free()
			return

		match _state:
			PincerState.CLOSING:
				_state_timer -= delta
				var ratio := 1.0 - clampf(_state_timer / Constants.ESCORPION_PINCERS_CLOSE_TIME, 0.0, 1.0)
				var local_a := _pos_a - _center
				var local_b := _pos_b - _center
				_wall_a.position = local_a.lerp(Vector2.ZERO, ratio)
				_wall_b.position = local_b.lerp(Vector2.ZERO, ratio)
				if _state_timer <= 0.0:
					_state = PincerState.CLOSED
					_state_timer = Constants.ESCORPION_PINCERS_RESET_TIME

			PincerState.CLOSED:
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
		if not GameManager.hunt_active:
			return
		if _state != PincerState.OPEN:
			return
		if body is BaseCharacter:
			var character := body as BaseCharacter
			if character.team == owner_team:
				return
			GameManager.register_trap_contact(character.player_index)
			_state = PincerState.CLOSING
			_state_timer = Constants.ESCORPION_PINCERS_CLOSE_TIME

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
		draw_line(local_a - perp * half_len, local_a + perp * half_len, wall_color, 6.0)
		# Wall B
		draw_line(local_b - perp * half_len, local_b + perp * half_len, wall_color, 6.0)

		# Danger zone between walls (when open)
		if _state == PincerState.OPEN:
			var zone_color := Color(_color, 0.05 + 0.03 * sin(Time.get_ticks_msec() / 300.0))
			draw_line(local_a, local_b, zone_color, Constants.ESCORPION_PINCERS_WALL_LENGTH * 0.3)
