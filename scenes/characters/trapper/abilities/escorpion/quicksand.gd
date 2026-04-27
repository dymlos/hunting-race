class_name Quicksand
extends TrapperAbility

## Scorpion Ability 2 (RB): Circular zone that pulls escapists toward center.
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
	return "Arenas"


func get_display_color() -> Color:
	return Color(0.85, 0.7, 0.3)


## --- QuicksandZone inner node ---

class QuicksandZone extends Area2D:
	var owner_team: Enums.Team = Enums.Team.NONE
	var _lifetime: float = Constants.ESCORPION_QUICKSAND_LIFETIME
	var _color: Color = Color(0.85, 0.7, 0.3)
	var _bodies_inside: Dictionary = {}  # {Node: {angle, move_dir, escape_control}}

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
		if GameManager.is_trap_lifetime_active():
			_lifetime -= delta
		if _lifetime <= 0.0:
			queue_free()
			return

		if not GameManager.is_trap_interaction_active():
			queue_redraw()
			return

		_refresh_bodies_inside()

		# Apply pull force to all bodies inside
		for body: Node in _bodies_inside.keys():
			if not is_instance_valid(body) or not body is BaseCharacter:
				continue
			var character := body as BaseCharacter
			if not _can_affect_character(character):
				continue

			var to_center: Vector2 = global_position - character.global_position
			var dist: float = to_center.length()

			# Kill at center
			if dist < Constants.ESCORPION_QUICKSAND_KILL_RADIUS:
				if character is Escapist:
					(character as Escapist).kill()
				continue

			# Calculate evasive movement to reduce pull.
			var state := _bodies_inside[body] as Dictionary
			var current_angle: float = (character.global_position - global_position).angle()
			var prev_angle: float = state.get("angle", current_angle) as float
			var angular_diff: float = absf(angle_difference(prev_angle, current_angle))
			var move_dir := _get_character_move_direction(character)
			var prev_move_dir: Vector2 = state.get("move_dir", Vector2.ZERO) as Vector2
			var direction_change := 0.0
			if move_dir.length_squared() > 0.01 and prev_move_dir.length_squared() > 0.01:
				direction_change = clampf((1.0 - move_dir.dot(prev_move_dir)) * 0.5, 0.0, 1.0)
			var angular_escape := clampf(angular_diff * 18.0, 0.0, 1.0)
			var control_gain := maxf(direction_change, angular_escape)
			var escape_control: float = state.get("escape_control", 0.0) as float
			escape_control = clampf(
				escape_control + control_gain * delta * 3.0 - (1.0 - control_gain) * delta * 0.9,
				0.0,
				1.0
			)
			state["angle"] = current_angle
			if move_dir.length_squared() > 0.01:
				state["move_dir"] = move_dir
			state["escape_control"] = escape_control

			# Straight movement gets punished; varied movement can bleed off part of the pull.
			var escape_factor := lerpf(1.55, 0.62, escape_control)

			# Stronger pull when the target is carrying more momentum.
			var pull_dir := to_center.normalized()
			var base_speed := maxf(character.movement.move_speed, 1.0)
			var current_speed := character.movement.velocity.length()
			var speed_factor := clampf(current_speed / base_speed, 0.0, 1.5)
			var depth_factor := 1.0 - clampf(dist / Constants.ESCORPION_QUICKSAND_RADIUS, 0.0, 1.0)
			var target_pull_speed := (
				Constants.ESCORPION_QUICKSAND_PULL
				* escape_factor
				* lerpf(1.2, 1.75, speed_factor)
				* lerpf(1.05, 1.35, depth_factor)
			)
			character.movement.apply_vortex_pull(
				pull_dir,
				target_pull_speed,
				Constants.ESCORPION_QUICKSAND_PULL * 80.0,
				Constants.ESCORPION_QUICKSAND_PULL * 3.0,
				delta
			)
			var swirl_dir := pull_dir.rotated(PI / 2.0)
			var target_swirl_speed := Constants.ESCORPION_QUICKSAND_PULL * lerpf(0.9, 0.45, depth_factor)
			character.movement.apply_vortex_pull(
				swirl_dir,
				target_swirl_speed,
				Constants.ESCORPION_QUICKSAND_PULL * 60.0,
				0.0,
				delta
			)

		queue_redraw()

	func _on_body_entered(body: Node2D) -> void:
		if body is BaseCharacter:
			var character := body as BaseCharacter
			_track_character(character)

	func _on_body_exited(body: Node2D) -> void:
		_bodies_inside.erase(body)

	func _refresh_bodies_inside() -> void:
		var expired: Array[Node] = []
		for body: Node in _bodies_inside.keys():
			if not is_instance_valid(body) or not body is BaseCharacter:
				expired.append(body)
				continue
			var character := body as BaseCharacter
			var overlap_radius := Constants.ESCORPION_QUICKSAND_RADIUS + Constants.CHARACTER_RADIUS
			if character.global_position.distance_to(global_position) > overlap_radius:
				expired.append(body)
		for body in expired:
			_bodies_inside.erase(body)

		var tree := get_tree()
		if not tree:
			return
		var overlap_radius := Constants.ESCORPION_QUICKSAND_RADIUS + Constants.CHARACTER_RADIUS
		for node: Node in tree.get_nodes_in_group("characters"):
			if not node is BaseCharacter:
				continue
			var character := node as BaseCharacter
			if not _shares_skill_test_scope(character):
				continue
			if character.global_position.distance_to(global_position) <= overlap_radius:
				_track_character(character)

	func _track_character(character: BaseCharacter) -> void:
		if not _can_affect_character(character):
			return
		if character in _bodies_inside:
			return
		GameManager.register_trap_contact(character.player_index, int(get_meta("owner_player_index", -1)))
		if character is Escapist:
			(character as Escapist).notify_trap_status("HUNDIÉNDOSE", Color(1.0, 0.8, 0.25), 0.8)
		AudioManager.play_effect(&"QuicksandTrap")
		_bodies_inside[character] = {
			"angle": (character.global_position - global_position).angle(),
			"move_dir": Vector2.ZERO,
			"escape_control": 0.0,
		}

	func _can_affect_character(character: BaseCharacter) -> bool:
		if not _shares_skill_test_scope(character):
			return false
		if character.team == owner_team:
			return false
		if not character.movement:
			return false
		if character is Escapist:
			var esc := character as Escapist
			if esc.is_dead or esc.has_scored or esc.is_effect_immune():
				return false
		return true

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

	func _get_character_move_direction(character: BaseCharacter) -> Vector2:
		var velocity := character.movement.velocity
		if velocity.length_squared() <= 64.0:
			velocity = character.velocity
		if velocity.length_squared() <= 64.0:
			return Vector2.ZERO
		return velocity.normalized()

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
