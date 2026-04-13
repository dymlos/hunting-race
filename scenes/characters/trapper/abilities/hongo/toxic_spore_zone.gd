class_name ToxicSporeZone
extends TrapperAbility

## Hongo Ability 2 (RB): Toxic area — slow while inside, poison on exit.


func setup(p_trapper: Trapper) -> void:
	super.setup(p_trapper)
	cooldown = Constants.HONGO_SPORE_COOLDOWN
	max_active = Constants.HONGO_SPORE_MAX
	points_required = 1


func _spawn_object(pos: Vector2) -> void:
	var zone := SporeZone.new()
	zone.setup(trapper.team, pos)
	_register_object(zone)


func get_display_name() -> String:
	return "Spores"


func get_display_color() -> Color:
	return Color(0.4, 0.7, 0.1)


## --- SporeZone inner node ---

class SporeZone extends Area2D:
	var owner_team: Enums.Team = Enums.Team.NONE
	var _lifetime: float = Constants.HONGO_SPORE_LIFETIME
	var _color: Color = Color(0.4, 0.7, 0.1)
	var _bodies_inside: Dictionary = {}  # {Node: true}

	func setup(team: Enums.Team, pos: Vector2) -> void:
		owner_team = team
		position = pos
		add_to_group("traps")

		collision_layer = Constants.LAYER_TRAPS
		collision_mask = Constants.LAYER_CHARACTERS
		monitoring = true
		monitorable = true

		var shape := CircleShape2D.new()
		shape.radius = Constants.HONGO_SPORE_RADIUS
		var col := CollisionShape2D.new()
		col.shape = shape
		add_child(col)

		body_entered.connect(_on_body_entered)
		body_exited.connect(_on_body_exited)

	func _process(delta: float) -> void:
		if GameManager.trap_lifetime_active:
			_lifetime -= delta
		if _lifetime <= 0.0:
			_cleanup()
			queue_free()
			return
		queue_redraw()

	func _on_body_entered(body: Node2D) -> void:
		if not GameManager.hunt_active:
			return
		if body is BaseCharacter:
			var character := body as BaseCharacter
			if character.team == owner_team:
				return
			_bodies_inside[body] = true
			character.movement.set_speed_modifier(&"spore_slow", Constants.HONGO_SPORE_SLOW)

	func _on_body_exited(body: Node2D) -> void:
		if body not in _bodies_inside:
			return
		_bodies_inside.erase(body)

		if is_instance_valid(body) and body is BaseCharacter:
			var character := body as BaseCharacter
			character.movement.remove_speed_modifier(&"spore_slow")

			# Poison on exit
			if body is Escapist:
				var esc := body as Escapist
				if not esc.is_dead and not esc.has_scored and esc.team != owner_team:
					esc.poison.apply_poison()

	func _cleanup() -> void:
		for body: Node in _bodies_inside:
			if is_instance_valid(body) and body is BaseCharacter:
				(body as BaseCharacter).movement.remove_speed_modifier(&"spore_slow")
		_bodies_inside.clear()

	func _draw() -> void:
		var r := Constants.HONGO_SPORE_RADIUS
		var pulse := 0.7 + 0.3 * sin(Time.get_ticks_msec() / 500.0)

		# Cloud fill
		draw_circle(Vector2.ZERO, r * pulse, Color(_color, 0.1))
		draw_arc(Vector2.ZERO, r * pulse, 0, TAU, 16, Color(_color, 0.3), 2.0)

		# Floating spore particles
		for i in 5:
			var t := Time.get_ticks_msec() / 1000.0 + i * 1.2
			var angle := t * 0.8
			var dist := r * 0.3 + r * 0.4 * sin(t * 0.5 + i)
			var offset := Vector2.from_angle(angle) * dist
			var size := 2.0 + sin(t * 2.0 + i) * 1.0
			draw_circle(offset, size, Color(_color, 0.4 * pulse))
