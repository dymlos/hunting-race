class_name ConfusingMushroom
extends TrapperAbility

## Mushroom Ability 1 (A): Mushroom that inverts controls on contact. Single-use.


func setup(p_trapper: Trapper) -> void:
	super.setup(p_trapper)
	cooldown = Constants.HONGO_CONFUSE_COOLDOWN
	max_active = Constants.HONGO_CONFUSE_MAX
	points_required = 1


func _spawn_object(pos: Vector2) -> void:
	var shroom := ConfuseShroom.new()
	shroom.setup(trapper.team, pos)
	_register_object(shroom)


func get_display_name() -> String:
	return "Confusión"


func get_display_color() -> Color:
	return Enums.trapper_character_color(Enums.TrapperCharacter.HONGO)


## --- ConfuseShroom inner node ---

class ConfuseShroom extends Area2D:
	var owner_team: Enums.Team = Enums.Team.NONE
	var _lifetime: float = Constants.HONGO_CONFUSE_LIFETIME
	var _color: Color = Enums.trapper_character_color(Enums.TrapperCharacter.HONGO)

	func setup(team: Enums.Team, pos: Vector2) -> void:
		owner_team = team
		position = pos
		add_to_group("traps")

		collision_layer = Constants.LAYER_TRAPS
		collision_mask = Constants.LAYER_CHARACTERS
		monitoring = true
		monitorable = true

		var shape := CircleShape2D.new()
		shape.radius = Constants.HONGO_CONFUSE_RADIUS
		var col := CollisionShape2D.new()
		col.shape = shape
		add_child(col)

		body_entered.connect(_on_body_entered)

	func _process(delta: float) -> void:
		if GameManager.is_trap_lifetime_active():
			_lifetime -= delta
		if _lifetime <= 0.0:
			queue_free()
			return
		queue_redraw()

	func _on_body_entered(body: Node2D) -> void:
		if not GameManager.is_trap_interaction_active():
			return
		if body is Escapist:
			var esc := body as Escapist
			if esc.team == owner_team:
				return
			if esc.is_dead or esc.has_scored:
				return
			GameManager.register_trap_contact(esc.player_index, int(get_meta("owner_player_index", -1)))
			esc.notify_trap_status("CONFUSO", Color(1.0, 0.25, 1.0), 0.85)
			esc.invert_controls(Constants.HONGO_CONFUSE_DURATION)
			AudioManager.play_effect(&"ConfuseTrap")
			queue_free()  # Single-use

	func _draw() -> void:
		var pulse := 0.8 + 0.2 * sin(Time.get_ticks_msec() / 300.0)
		var r := Constants.HONGO_CONFUSE_RADIUS

		# Mushroom cap (half circle on top)
		draw_arc(Vector2(0, -4), r * 0.6 * pulse, PI, TAU, 8, Color(_color, 0.7), 3.0)
		draw_circle(Vector2(0, -4), r * 0.4 * pulse, Color(_color, 0.25))

		# Stem
		draw_line(Vector2(0, -4 + r * 0.3), Vector2(0, r * 0.4), Color(_color, 0.5), 2.0)

		# Confusion spirals
		var angle := Time.get_ticks_msec() / 400.0
		for i in 2:
			var a := angle + i * PI
			var offset := Vector2.from_angle(a) * r * 0.3
			draw_arc(offset + Vector2(0, -6), 3.0, a, a + PI * 1.5, 6,
				Color(1.0, 0.8, 0.2, 0.5 * pulse), 1.0)
