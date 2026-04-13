class_name BindingTentacle
extends TrapperAbility

## Pulpo Ability 2 (RB): Capture point. First escapist is rooted. If a second
## escapist comes to help, both get linked and must move with averaged input.


func setup(p_trapper: Trapper) -> void:
	super.setup(p_trapper)
	cooldown = Constants.PULPO_TENTACLE_COOLDOWN
	max_active = Constants.PULPO_TENTACLE_MAX
	points_required = 1


func _spawn_object(pos: Vector2) -> void:
	var tentacle := TentacleNode.new()
	tentacle.setup(trapper.team, pos)
	_register_object(tentacle)


func get_display_name() -> String:
	return "Tentacle"


func get_display_color() -> Color:
	return Color(0.3, 0.7, 0.9)


## --- TentacleNode inner node ---

class TentacleNode extends Area2D:
	var owner_team: Enums.Team = Enums.Team.NONE
	var _lifetime: float = Constants.PULPO_TENTACLE_LIFETIME
	var _color: Color = Color(0.3, 0.7, 0.9)

	enum TentacleState { WAITING, CAPTURED_ONE, LINKED, DONE }
	var _state: TentacleState = TentacleState.WAITING

	var _captured_a: Escapist  # First victim
	var _captured_b: Escapist  # Second victim (helper)
	var _link_timer: float = 0.0
	var _original_locked_a: bool = false
	var _original_locked_b: bool = false

	func setup(team: Enums.Team, pos: Vector2) -> void:
		owner_team = team
		position = pos
		add_to_group("traps")

		collision_layer = Constants.LAYER_TRAPS
		collision_mask = Constants.LAYER_CHARACTERS
		monitoring = true
		monitorable = true

		var shape := CircleShape2D.new()
		shape.radius = Constants.PULPO_TENTACLE_RADIUS
		var col := CollisionShape2D.new()
		col.shape = shape
		add_child(col)

		body_entered.connect(_on_body_entered)

	func _process(delta: float) -> void:
		if GameManager.trap_lifetime_active:
			_lifetime -= delta
		if _lifetime <= 0.0:
			_release_all()
			queue_free()
			return

		match _state:
			TentacleState.CAPTURED_ONE:
				# Keep first victim rooted
				if not is_instance_valid(_captured_a) or _captured_a.is_dead:
					_release_all()
					_state = TentacleState.WAITING
					_captured_a = null

			TentacleState.LINKED:
				_link_timer -= delta
				if _link_timer <= 0.0:
					_release_all()
					_state = TentacleState.DONE
					queue_free()
					return

				# Average movement of both linked players
				if is_instance_valid(_captured_a) and is_instance_valid(_captured_b):
					if not _captured_a.is_dead and not _captured_b.is_dead:
						_apply_linked_movement(delta)
					else:
						_release_all()
						queue_free()
						return

		queue_redraw()

	func _on_body_entered(body: Node2D) -> void:
		if not GameManager.hunt_active:
			return
		if not body is Escapist:
			return
		var esc := body as Escapist
		if esc.team == owner_team or esc.is_dead or esc.has_scored:
			return

		match _state:
			TentacleState.WAITING:
				_captured_a = esc
				_captured_a.movement.freeze()
				_state = TentacleState.CAPTURED_ONE
			TentacleState.CAPTURED_ONE:
				if esc == _captured_a:
					return
				_captured_b = esc
				# Unfreeze first victim, both now linked
				_captured_a.movement.unfreeze()
				_link_timer = Constants.PULPO_TENTACLE_LINK_DURATION
				_state = TentacleState.LINKED

	func _apply_linked_movement(delta: float) -> void:
		# Override: both players get averaged movement
		var vec_a := Vector2.ZERO
		var vec_b := Vector2.ZERO
		if _captured_a.player_index < 100:
			vec_a = InputManager.get_move_vector(_captured_a.player_index)
		if _captured_b.player_index < 100:
			vec_b = InputManager.get_move_vector(_captured_b.player_index)

		var avg_vec := (vec_a + vec_b) / 2.0
		_captured_a.movement.apply_movement(avg_vec)
		_captured_b.movement.apply_movement(avg_vec)

		# Keep them close together — pull toward midpoint
		var mid := (_captured_a.global_position + _captured_b.global_position) / 2.0
		var max_dist := 60.0
		var dist_a: float = _captured_a.global_position.distance_to(mid)
		var dist_b: float = _captured_b.global_position.distance_to(mid)
		if dist_a > max_dist:
			var pull := (mid - _captured_a.global_position).normalized() * 100.0 * delta
			_captured_a.global_position += pull
		if dist_b > max_dist:
			var pull := (mid - _captured_b.global_position).normalized() * 100.0 * delta
			_captured_b.global_position += pull

	func _release_all() -> void:
		if is_instance_valid(_captured_a) and not _captured_a.is_dead:
			_captured_a.movement.unfreeze()
		if is_instance_valid(_captured_b) and not _captured_b.is_dead:
			_captured_b.movement.unfreeze()

	func _draw() -> void:
		var r := Constants.PULPO_TENTACLE_RADIUS
		var t := Time.get_ticks_msec() / 1000.0

		match _state:
			TentacleState.WAITING:
				# Idle tentacle
				draw_circle(Vector2.ZERO, r * 0.4, Color(_color, 0.2))
				draw_arc(Vector2.ZERO, r, 0, TAU, 12, Color(_color, 0.3), 1.5)
				# Wiggling tentacles
				for i in 4:
					var angle := i * TAU / 4.0 + sin(t * 2.0 + i) * 0.3
					var tip := Vector2.from_angle(angle) * r * 0.8
					var ctrl := Vector2.from_angle(angle) * r * 0.4 + Vector2(sin(t * 3.0 + i) * 5.0, cos(t * 2.5 + i) * 5.0)
					draw_line(Vector2.ZERO, ctrl, Color(_color, 0.4), 2.0)
					draw_line(ctrl, tip, Color(_color, 0.3), 1.5)

			TentacleState.CAPTURED_ONE:
				draw_circle(Vector2.ZERO, r * 0.5, Color(1.0, 0.3, 0.3, 0.3))
				draw_arc(Vector2.ZERO, r, 0, TAU, 12, Color(1.0, 0.3, 0.3, 0.5), 2.0)
				# Line to captured player
				if is_instance_valid(_captured_a):
					var local_pos := _captured_a.global_position - global_position
					draw_line(Vector2.ZERO, local_pos, Color(_color, 0.6), 2.5)

			TentacleState.LINKED:
				draw_circle(Vector2.ZERO, r * 0.3, Color(1.0, 0.5, 0.1, 0.2))
				# Lines to both players
				if is_instance_valid(_captured_a):
					var la := _captured_a.global_position - global_position
					draw_line(Vector2.ZERO, la, Color(_color, 0.4), 1.5)
				if is_instance_valid(_captured_b):
					var lb := _captured_b.global_position - global_position
					draw_line(Vector2.ZERO, lb, Color(_color, 0.4), 1.5)
				# Link line between the two players
				if is_instance_valid(_captured_a) and is_instance_valid(_captured_b):
					var la := _captured_a.global_position - global_position
					var lb := _captured_b.global_position - global_position
					var wobble := sin(t * 4.0) * 3.0
					var mid := (la + lb) / 2.0 + Vector2(0, wobble)
					draw_line(la, mid, Color(1.0, 0.5, 0.1, 0.6), 2.0)
					draw_line(mid, lb, Color(1.0, 0.5, 0.1, 0.6), 2.0)
