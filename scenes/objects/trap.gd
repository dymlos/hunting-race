class_name Trap
extends Area2D

## Placed by Trapper. Can be slow (reduces speed) or lethal (kills on contact).

signal destroyed(trap: Trap)

var owner_team: Enums.Team = Enums.Team.NONE
var is_lethal: bool = false
var _lifetime: float = Constants.TRAP_LIFETIME
var _triggered_targets: Dictionary = {}  # {Node: cooldown_remaining}
var _color: Color = Color.WHITE

const RETRIGGER_COOLDOWN: float = 2.0


func setup(team: Enums.Team, pos: Vector2, lethal: bool = false) -> void:
	owner_team = team
	is_lethal = lethal
	position = pos
	add_to_group("traps")

	if lethal:
		_color = Color(1.0, 0.2, 0.2, 0.8)  # Red for lethal
	else:
		_color = Enums.team_color(team)
		_color.a = 0.6

	collision_layer = Constants.LAYER_TRAPS
	collision_mask = Constants.LAYER_CHARACTERS
	monitoring = true
	monitorable = true

	var radius := Constants.TRAP_LETHAL_RADIUS if lethal else Constants.TRAP_RADIUS
	if get_child_count() == 0:
		var shape := CircleShape2D.new()
		shape.radius = radius
		var col := CollisionShape2D.new()
		col.shape = shape
		add_child(col)

	body_entered.connect(_on_body_entered)


func _process(delta: float) -> void:
	if GameManager.is_trap_lifetime_active():
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
	if not GameManager.is_trap_interaction_active():
		return
	if body in _triggered_targets:
		return

	if body is BaseCharacter:
		var character := body as BaseCharacter
		if character.team == owner_team:
			return  # No friendly fire
		GameManager.register_trap_contact(character.player_index, int(get_meta("owner_player_index", -1)))

		if is_lethal:
			# Kill the escapist
			if character is Escapist:
				var esc := character as Escapist
				esc.notify_trap_status("CRUSHED", Color(1.0, 0.2, 0.2), 0.65)
				esc.kill()
			_destroy()  # Lethal traps are single-use
		else:
			# Apply slow
			if character is Escapist:
				(character as Escapist).notify_trap_status("SLOWED", Color(1.0, 0.85, 0.15), 0.9)
			character.movement.set_speed_modifier(&"trap_slow", Constants.TRAP_SLOW_MULTIPLIER)
			AudioManager.play_effect(&"SlowMovement")
			get_tree().create_timer(Constants.TRAP_SLOW_DURATION).timeout.connect(
				func():
					if is_instance_valid(character):
						character.movement.remove_speed_modifier(&"trap_slow")
			)
			_triggered_targets[body] = RETRIGGER_COOLDOWN


func _destroy() -> void:
	destroyed.emit(self)
	queue_free()


func _draw() -> void:
	var pulse := 0.8 + 0.2 * sin(Time.get_ticks_msec() / 300.0)
	var radius := Constants.TRAP_LETHAL_RADIUS if is_lethal else Constants.TRAP_RADIUS
	var r := radius * pulse
	draw_circle(Vector2.ZERO, r, Color(_color, 0.3))
	draw_arc(Vector2.ZERO, r, 0, TAU, 12, _color, 2.0)

	if is_lethal:
		# Skull/danger pattern — thick X
		var s := radius * 0.6
		draw_line(Vector2(-s, -s), Vector2(s, s), _color, 3.0)
		draw_line(Vector2(s, -s), Vector2(-s, s), _color, 3.0)
	else:
		# Slow pattern — thin X
		var s := radius * 0.5
		draw_line(Vector2(-s, -s), Vector2(s, s), _color, 1.5)
		draw_line(Vector2(s, -s), Vector2(-s, s), _color, 1.5)
