class_name InkStain
extends TrapperAbility

## Pulpo Ability 1 (A): Large dark zone. Escapists inside cannot see their
## surroundings — a black fog covers the zone with a tiny visible radius
## around each escapist inside.


func setup(p_trapper: Trapper) -> void:
	super.setup(p_trapper)
	cooldown = Constants.PULPO_INK_COOLDOWN
	max_active = Constants.PULPO_INK_MAX
	points_required = 1


func _spawn_object(pos: Vector2) -> void:
	var ink := InkZone.new()
	ink.setup(trapper.team, pos)
	_register_object(ink)


func get_display_name() -> String:
	return "Ink"


func get_display_color() -> Color:
	return Enums.trapper_character_color(Enums.TrapperCharacter.PULPO)


## --- InkZone inner node ---

class InkZone extends Area2D:
	var owner_team: Enums.Team = Enums.Team.NONE
	var _lifetime: float = Constants.PULPO_INK_LIFETIME
	var _color: Color = Color(0.1, 0.05, 0.15)
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
		shape.radius = Constants.PULPO_INK_RADIUS
		var col := CollisionShape2D.new()
		col.shape = shape
		add_child(col)

		body_entered.connect(_on_body_entered)
		body_exited.connect(_on_body_exited)

		# Draw on top of most things
		z_index = 5

	func _process(delta: float) -> void:
		if GameManager.trap_lifetime_active:
			_lifetime -= delta
		if _lifetime <= 0.0:
			queue_free()
			return
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
		var r := Constants.PULPO_INK_RADIUS
		var pulse := 0.85 + 0.15 * sin(Time.get_ticks_msec() / 600.0)

		# Main dark fog — opaque black circle
		draw_circle(Vector2.ZERO, r * pulse, Color(0.02, 0.01, 0.04, Constants.PULPO_INK_ALPHA))

		# Slightly lighter border
		draw_arc(Vector2.ZERO, r * pulse, 0, TAU, 20,
			Color(0.15, 0.05, 0.2, 0.5), 3.0)

		# Cut out small visibility circles around affected escapists inside
		# Since we can't actually subtract in _draw, we draw a lighter hole
		# to simulate the "flashlight" effect
		var visible_radius := Constants.PULPO_INK_VISIBLE_RADIUS
		for body: Node in _bodies_inside:
			if not is_instance_valid(body):
				continue
			var local_pos: Vector2 = (body as Node2D).global_position - global_position
			# Draw a slightly brighter circle to simulate visibility
			draw_circle(local_pos, visible_radius, Color(0.03, 0.02, 0.045, 0.92))
			draw_arc(local_pos, visible_radius, 0, TAU, 10,
				Color(0.18, 0.1, 0.26, 0.08), 1.2)

		# Ink splatter spots
		for i in 4:
			var angle := i * TAU / 4.0 + Time.get_ticks_msec() / 2000.0
			var dist := r * 0.6
			var offset := Vector2.from_angle(angle) * dist
			draw_circle(offset, r * 0.2, Color(0.02, 0.01, 0.04, 0.4))
