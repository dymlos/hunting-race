class_name PersistentVenom
extends TrapperAbility

## Araña Ability 3 (X): Poison puddle. Stepping on it poisons the escapist.
## Ally touch cures; otherwise death after timer.


func setup(p_trapper: Trapper) -> void:
	super.setup(p_trapper)
	cooldown = Constants.ARANA_VENOM_COOLDOWN
	max_active = Constants.ARANA_VENOM_MAX
	points_required = 1


func _spawn_object(pos: Vector2) -> void:
	var puddle := VenomPuddle.new()
	puddle.setup(trapper.team, pos)
	_register_object(puddle)


func get_display_name() -> String:
	return "Venom"


func get_display_color() -> Color:
	return Color(0.2, 0.9, 0.1)


## --- VenomPuddle inner node ---

class VenomPuddle extends Area2D:
	var owner_team: Enums.Team = Enums.Team.NONE
	var _lifetime: float = Constants.ARANA_VENOM_LIFETIME
	var _color: Color = Color(0.2, 0.9, 0.1)
	var _triggered_targets: Dictionary = {}  # {Node: cooldown}

	func setup(team: Enums.Team, pos: Vector2) -> void:
		owner_team = team
		position = pos
		add_to_group("traps")

		collision_layer = Constants.LAYER_TRAPS
		collision_mask = Constants.LAYER_CHARACTERS
		monitoring = true
		monitorable = true

		var shape := CircleShape2D.new()
		shape.radius = Constants.ARANA_VENOM_RADIUS
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
		if body is Escapist:
			var esc := body as Escapist
			if esc.team == owner_team:
				return
			if esc.is_dead or esc.has_scored:
				return
			# Apply poison
			esc.poison.apply_poison()
			_triggered_targets[body] = 3.0  # Don't re-poison for 3s

	func _draw() -> void:
		var pulse := 0.7 + 0.3 * sin(Time.get_ticks_msec() / 350.0)
		var r := Constants.ARANA_VENOM_RADIUS * pulse

		# Puddle fill
		draw_circle(Vector2.ZERO, r, Color(_color, 0.2))
		draw_arc(Vector2.ZERO, r, 0, TAU, 12, Color(_color, 0.5), 2.0)

		# Bubble dots
		for i in 3:
			var angle := TAU / 3.0 * i + Time.get_ticks_msec() / 800.0
			var offset := Vector2.from_angle(angle) * r * 0.5
			draw_circle(offset, 3.0, Color(_color, 0.4 * pulse))
