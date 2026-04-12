class_name FungalTeleport
extends TrapperAbility

## Hongo Ability 3 (X): Place two linked mushroom portals. Stepping in one
## teleports to the other. Per-player cooldown prevents loops.


func setup(p_trapper: Trapper) -> void:
	super.setup(p_trapper)
	cooldown = Constants.HONGO_TELEPORT_COOLDOWN
	max_active = Constants.HONGO_TELEPORT_MAX
	points_required = 2


func _spawn_from_points(points: Array[Vector2]) -> void:
	var pair := TeleportPair.new()
	pair.setup(trapper.team, points[0], points[1])
	_register_object(pair)


func get_display_name() -> String:
	return "Teleport"


func get_display_color() -> Color:
	return Color(0.9, 0.4, 0.9)


func draw_preview(trapper_node: Trapper) -> void:
	if not is_placing or _placement_points.is_empty():
		return
	var color := Color(get_display_color(), 0.4)
	var local_start := _placement_points[0] - trapper_node.global_position
	trapper_node.draw_circle(local_start, Constants.HONGO_TELEPORT_RADIUS * 0.5, Color(color, 0.2))
	trapper_node.draw_arc(local_start, Constants.HONGO_TELEPORT_RADIUS * 0.5, 0, TAU, 8, color, 1.5)
	trapper_node.draw_line(local_start, Vector2.ZERO, Color(color, 0.3), 1.0)


## --- TeleportPair inner node ---

class TeleportPair extends Node2D:
	var owner_team: Enums.Team = Enums.Team.NONE
	var _lifetime: float = Constants.HONGO_TELEPORT_LIFETIME
	var _portal_a: TeleportPortal
	var _portal_b: TeleportPortal

	func setup(team: Enums.Team, pos_a: Vector2, pos_b: Vector2) -> void:
		owner_team = team
		add_to_group("traps")

		_portal_a = TeleportPortal.new()
		_portal_b = TeleportPortal.new()
		_portal_a.setup(team, pos_a, self, true)
		_portal_b.setup(team, pos_b, self, false)
		add_child(_portal_a)
		add_child(_portal_b)
		_portal_a.partner = _portal_b
		_portal_b.partner = _portal_a

	func _process(delta: float) -> void:
		_lifetime -= delta
		if _lifetime <= 0.0:
			queue_free()
			return

	func _draw() -> void:
		# Draw connecting line between portals
		var a_local := _portal_a.position
		var b_local := _portal_b.position
		var pulse := 0.3 + 0.2 * sin(Time.get_ticks_msec() / 500.0)
		draw_dashed_line(a_local, b_local,
			Color(0.9, 0.4, 0.9, pulse), 1.0, 8.0)
		queue_redraw()


class TeleportPortal extends Area2D:
	var owner_team: Enums.Team = Enums.Team.NONE
	var partner: TeleportPortal
	var _is_primary: bool = true
	var _pair_node: Node2D
	var _player_cooldowns: Dictionary = {}  # {Node: remaining}
	var _color: Color = Color(0.9, 0.4, 0.9)

	func setup(team: Enums.Team, pos: Vector2, pair: Node2D, primary: bool) -> void:
		owner_team = team
		position = pos
		_pair_node = pair
		_is_primary = primary

		collision_layer = Constants.LAYER_TRAPS
		collision_mask = Constants.LAYER_CHARACTERS
		monitoring = true
		monitorable = true

		var shape := CircleShape2D.new()
		shape.radius = Constants.HONGO_TELEPORT_RADIUS
		var col := CollisionShape2D.new()
		col.shape = shape
		add_child(col)

		body_entered.connect(_on_body_entered)

	func _process(delta: float) -> void:
		var expired: Array[Node] = []
		for target: Node in _player_cooldowns:
			_player_cooldowns[target] -= delta
			if _player_cooldowns[target] <= 0.0:
				expired.append(target)
		for target in expired:
			_player_cooldowns.erase(target)
		queue_redraw()

	func _on_body_entered(body: Node2D) -> void:
		if not GameManager.hunt_active:
			return
		if not partner:
			return
		if body in _player_cooldowns:
			return
		if body is BaseCharacter:
			# Teleport to partner portal
			body.global_position = partner.global_position
			# Set cooldown on both portals to prevent loops
			_player_cooldowns[body] = Constants.HONGO_TELEPORT_PLAYER_COOLDOWN
			partner._player_cooldowns[body] = Constants.HONGO_TELEPORT_PLAYER_COOLDOWN

	func _draw() -> void:
		var pulse := 0.7 + 0.3 * sin(Time.get_ticks_msec() / 300.0 + (0.0 if _is_primary else PI))
		var r := Constants.HONGO_TELEPORT_RADIUS

		draw_circle(Vector2.ZERO, r * pulse, Color(_color, 0.15))
		# Rotating ring
		var rotation_offset := Time.get_ticks_msec() / 500.0
		draw_arc(Vector2.ZERO, r * pulse, rotation_offset, rotation_offset + TAU * 0.7,
			10, Color(_color, 0.6), 2.0)
		# Inner glow
		draw_circle(Vector2.ZERO, r * 0.3, Color(_color, 0.3 * pulse))
