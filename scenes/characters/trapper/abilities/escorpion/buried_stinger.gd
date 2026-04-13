class_name BuriedStinger
extends TrapperAbility

## Escorpión Ability 1 (A): Nearly invisible trap. Poison + stun on contact. Single-use.


func setup(p_trapper: Trapper) -> void:
	super.setup(p_trapper)
	cooldown = Constants.ESCORPION_STINGER_COOLDOWN
	max_active = Constants.ESCORPION_STINGER_MAX
	points_required = 1


func _spawn_object(pos: Vector2) -> void:
	var stinger := StingerTrap.new()
	stinger.setup(trapper.team, pos)
	_register_object(stinger)


func get_display_name() -> String:
	return "Stinger"


func get_display_color() -> Color:
	return Enums.trapper_character_color(Enums.TrapperCharacter.ESCORPION)


## --- StingerTrap inner node ---

class StingerTrap extends Area2D:
	var owner_team: Enums.Team = Enums.Team.NONE
	var _lifetime: float = Constants.ESCORPION_STINGER_LIFETIME
	var _color: Color = Enums.trapper_character_color(Enums.TrapperCharacter.ESCORPION)

	func setup(team: Enums.Team, pos: Vector2) -> void:
		owner_team = team
		position = pos
		add_to_group("traps")

		collision_layer = Constants.LAYER_TRAPS
		collision_mask = Constants.LAYER_CHARACTERS
		monitoring = true
		monitorable = true

		var shape := CircleShape2D.new()
		shape.radius = Constants.ESCORPION_STINGER_RADIUS
		var col := CollisionShape2D.new()
		col.shape = shape
		add_child(col)

		body_entered.connect(_on_body_entered)

	func _process(delta: float) -> void:
		if GameManager.trap_lifetime_active:
			_lifetime -= delta
		if _lifetime <= 0.0:
			queue_free()
			return
		queue_redraw()

	func _on_body_entered(body: Node2D) -> void:
		if not GameManager.hunt_active:
			return
		if body is Escapist:
			var esc := body as Escapist
			if esc.team == owner_team:
				return
			if esc.is_dead or esc.has_scored:
				return
			GameManager.register_trap_contact(esc.player_index)
			if esc.is_effect_immune():
				queue_free()
				return
			# Stun
			if esc.has_node("StatusEffectComponent"):
				var status := esc.get_node("StatusEffectComponent") as StatusEffectComponent
				status.apply_effect(Enums.CCType.STUN, Constants.ESCORPION_STINGER_STUN)
			else:
				# Fallback: freeze movement directly
				esc.movement.freeze()
				esc.get_tree().create_timer(Constants.ESCORPION_STINGER_STUN).timeout.connect(
					func():
						if is_instance_valid(esc):
							esc.movement.unfreeze()
				)
			# Poison
			esc.poison.apply_poison()
			queue_free()  # Single-use

	func _draw() -> void:
		# Nearly invisible — very faint shimmer
		var pulse := 0.3 + 0.15 * sin(Time.get_ticks_msec() / 600.0)
		var r := Constants.ESCORPION_STINGER_RADIUS

		# Faint circle — hard to spot
		draw_circle(Vector2.ZERO, r * 0.5, Color(_color, 0.05 * pulse))
		# Tiny shimmer dots
		var angle := Time.get_ticks_msec() / 1000.0
		for i in 3:
			var a := angle + i * TAU / 3.0
			var offset := Vector2.from_angle(a) * r * 0.3
			draw_circle(offset, 1.5, Color(_color, 0.08 * pulse))
