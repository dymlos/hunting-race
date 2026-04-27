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
	var radius := Constants.TRAP_LETHAL_RADIUS if is_lethal else Constants.TRAP_RADIUS
	var time := Time.get_ticks_msec() / 1000.0
	var pulse := 0.5 + 0.5 * sin(time * (5.5 if is_lethal else 3.6))
	var life_ratio := clampf(_lifetime / Constants.TRAP_LIFETIME, 0.0, 1.0)
	var r := radius * (0.9 + 0.12 * pulse)

	draw_circle(Vector2.ZERO, r + 6.0 + pulse * 3.0, Color(_color, 0.06 + pulse * 0.05))
	draw_circle(Vector2.ZERO, r, Color(_color, 0.18 if is_lethal else 0.13))
	draw_arc(Vector2.ZERO, r, 0, TAU, 36, Color(_color, 0.85), 2.4)
	draw_arc(Vector2.ZERO, r + 4.0, -PI / 2.0, -PI / 2.0 + TAU * life_ratio, 36,
		Color(1.0, 0.95, 0.72, 0.62), 1.6)

	var spoke_count := 8 if is_lethal else 6
	for i in range(spoke_count):
		var angle := TAU * float(i) / float(spoke_count) + time * (0.35 if is_lethal else -0.22)
		var dir := Vector2.from_angle(angle)
		var inner := dir * radius * 0.42
		var outer := dir * (r + (4.0 if is_lethal else 1.0))
		var spoke_color := Color(_color, 0.54 if is_lethal else 0.36)
		draw_line(inner, outer, spoke_color, 1.4)

	if is_lethal:
		var jaw_color := Color(1.0, 0.36, 0.18, 0.95)
		var tooth_color := Color(1.0, 0.82, 0.55, 0.88)
		var jaw_open := 0.25 + pulse * 0.22
		for side in [-1.0, 1.0]:
			var arc_center := Vector2(0.0, side * radius * jaw_open)
			draw_arc(arc_center, radius * 0.74, PI * (0.08 if side > 0.0 else 1.08),
				PI * (0.92 if side > 0.0 else 1.92), 18, jaw_color, 3.0)
			for i in range(4):
				var tooth_ratio := (float(i) + 0.5) / 4.0
				var x := lerpf(-radius * 0.48, radius * 0.48, tooth_ratio)
				var base := Vector2(x, side * radius * (0.22 + jaw_open))
				var tip := Vector2(x + sin(time * 2.0 + float(i)) * 1.4, side * radius * 0.03)
				draw_colored_polygon(PackedVector2Array([
					base + Vector2(-3.0, 0.0),
					base + Vector2(3.0, 0.0),
					tip,
				]), tooth_color)
		var s := radius * 0.46
		draw_line(Vector2(-s, -s), Vector2(s, s), Color(1.0, 0.14, 0.1, 0.78), 2.4)
		draw_line(Vector2(s, -s), Vector2(-s, s), Color(1.0, 0.14, 0.1, 0.78), 2.4)
	else:
		var rune_color := Color(1.0, 0.9, 0.35, 0.62 + pulse * 0.22)
		for i in range(3):
			var angle := time * 0.85 + float(i) * TAU / 3.0
			var center := Vector2.from_angle(angle) * radius * 0.36
			draw_arc(center, radius * 0.18, angle + PI * 0.2, angle + PI * 1.45, 10, rune_color, 1.5)
			draw_circle(center, 2.2 + pulse, Color(rune_color, 0.45))
		var s := radius * 0.48
		draw_line(Vector2(-s, 0.0), Vector2(s, 0.0), Color(_color, 0.48), 1.4)
		draw_line(Vector2(0.0, -s), Vector2(0.0, s), Color(_color, 0.48), 1.4)
