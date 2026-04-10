class_name Trap
extends Area2D

## Placed by Trapper. Slows enemies on contact. Has a lifetime and can be destroyed by Predator dash.

signal destroyed(trap: Trap)

var owner_team: Enums.Team = Enums.Team.NONE
var _lifetime: float = Constants.TRAP_LIFETIME
var _triggered_targets: Dictionary = {}  # {Node: cooldown_remaining}
var _color: Color = Color.WHITE

const RETRIGGER_COOLDOWN: float = 2.0


func setup(team: Enums.Team, pos: Vector2) -> void:
	owner_team = team
	position = pos
	add_to_group("traps")
	_color = Enums.team_color(team)
	_color.a = 0.6

	collision_layer = Constants.LAYER_TRAPS
	collision_mask = Constants.LAYER_CHARACTERS
	monitoring = true
	monitorable = true

	if get_child_count() == 0:
		var shape := CircleShape2D.new()
		shape.radius = Constants.TRAP_RADIUS
		var col := CollisionShape2D.new()
		col.shape = shape
		add_child(col)

	body_entered.connect(_on_body_entered)


func _process(delta: float) -> void:
	_lifetime -= delta
	if _lifetime <= 0.0:
		_destroy()
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

	if body is BaseCharacter:
		var character := body as BaseCharacter
		if character.team == owner_team:
			return  # No friendly fire

		# Apply slow
		character.movement.set_speed_modifier(&"trap_slow", Constants.TRAP_SLOW_MULTIPLIER)
		# Remove slow after duration
		get_tree().create_timer(Constants.TRAP_SLOW_DURATION).timeout.connect(
			func():
				if is_instance_valid(character):
					character.movement.remove_speed_modifier(&"trap_slow")
		)
		_triggered_targets[body] = RETRIGGER_COOLDOWN

		# Predator dash destroys traps
		if character is Predator:
			var pred := character as Predator
			if pred.movement.is_dashing:
				_destroy()


func _destroy() -> void:
	destroyed.emit(self)
	queue_free()


func _draw() -> void:
	# Trap visual — pulsing circle
	var pulse := 0.8 + 0.2 * sin(Time.get_ticks_msec() / 300.0)
	var r := Constants.TRAP_RADIUS * pulse
	draw_circle(Vector2.ZERO, r, Color(_color, 0.3))
	draw_arc(Vector2.ZERO, r, 0, TAU, 12, _color, 2.0)

	# X pattern
	var s := Constants.TRAP_RADIUS * 0.5
	draw_line(Vector2(-s, -s), Vector2(s, s), _color, 1.5)
	draw_line(Vector2(s, -s), Vector2(-s, s), _color, 1.5)
