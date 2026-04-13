class_name Quicksand
extends TrapperAbility

## Escorpión Ability 2 (RB): Circular zone that pulls escapists toward center.
## Reaching the center = death. Escape by moving in circles (tangential movement
## reduces pull strength).


func setup(p_trapper: Trapper) -> void:
	super.setup(p_trapper)
	cooldown = Constants.ESCORPION_QUICKSAND_COOLDOWN
	max_active = Constants.ESCORPION_QUICKSAND_MAX
	points_required = 1


func _spawn_object(pos: Vector2) -> void:
	var sand := QuicksandZone.new()
	sand.setup(trapper.team, pos)
	_register_object(sand)


func get_display_name() -> String:
	return "Quicksand"


func get_display_color() -> Color:
	return Color(0.85, 0.7, 0.3)


## --- QuicksandZone inner node ---

class QuicksandZone extends Area2D:
	var owner_team: Enums.Team = Enums.Team.NONE
	var _lifetime: float = Constants.ESCORPION_QUICKSAND_LIFETIME
	var _color: Color = Color(0.85, 0.7, 0.3)
	var _bodies_inside: Dictionary = {}  # {Node: prev_angle}

	func setup(team: Enums.Team, pos: Vector2) -> void:
		owner_team = team
		position = pos
		add_to_group("traps")

		collision_layer = Constants.LAYER_TRAPS
		collision_mask = Constants.LAYER_CHARACTERS
		monitoring = true
		monitorable = true

		var shape := CircleShape2D.new()
		shape.radius = Constants.ESCORPION_QUICKSAND_RADIUS
		var col := CollisionShape2D.new()
		col.shape = shape
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

		# Apply pull force to all bodies inside
		for body: Node in _bodies_inside:
			if not is_instance_valid(body) or not body is BaseCharacter:
				continue
			var character := body as BaseCharacter
			if character.team == owner_team:
				continue
			if character is Escapist:
				var esc := character as Escapist
				if esc.is_dead or esc.has_scored:
					continue

			var to_center: Vector2 = global_position - character.global_position
			var dist: float = to_center.length()

			# Kill at center
			if dist < Constants.ESCORPION_QUICKSAND_KILL_RADIUS:
				if character is Escapist:
					(character as Escapist).kill()
				continue

			# Calculate tangential movement to reduce pull
			var current_angle: float = (character.global_position - global_position).angle()
			var prev_angle: float = _bodies_inside[body] as float
			var angular_diff: float = absf(angle_difference(prev_angle, current_angle))
			_bodies_inside[body] = current_angle

			# Higher angular velocity = less pull (reward circular motion)
			var angular_factor := clampf(1.0 - angular_diff * 8.0, 0.2, 1.0)

			# Pull toward center
			var pull_dir := to_center.normalized()
			var pull_strength := Constants.ESCORPION_QUICKSAND_PULL * angular_factor * delta

			# Apply as direct velocity addition (stronger than speed modifier)
			character.movement.velocity += pull_dir * pull_strength

		queue_redraw()

	func _on_body_entered(body: Node2D) -> void:
		if body is BaseCharacter:
			var character := body as BaseCharacter
			if character.team == owner_team:
				return
			var angle: float = (body.global_position - global_position).angle()
			_bodies_inside[body] = angle

	func _on_body_exited(body: Node2D) -> void:
		_bodies_inside.erase(body)

	func _draw() -> void:
		var r := Constants.ESCORPION_QUICKSAND_RADIUS
		var t := Time.get_ticks_msec() / 1000.0

		# Sandy fill
		draw_circle(Vector2.ZERO, r, Color(_color, 0.12))

		# Spiral pattern
		var spiral_points := 20
		for i in spiral_points:
			var ratio := float(i) / float(spiral_points)
			var angle := ratio * TAU * 2.0 + t * 1.5
			var dist := r * ratio * 0.9
			var pt := Vector2.from_angle(angle) * dist
			var size := 1.5 + ratio * 1.5
			draw_circle(pt, size, Color(_color, 0.2 + 0.15 * (1.0 - ratio)))

		# Border
		draw_arc(Vector2.ZERO, r, 0, TAU, 16, Color(_color, 0.35), 2.0)

		# Center danger zone
		draw_circle(Vector2.ZERO, Constants.ESCORPION_QUICKSAND_KILL_RADIUS,
			Color(1.0, 0.2, 0.1, 0.3 + 0.1 * sin(t * 3.0)))
