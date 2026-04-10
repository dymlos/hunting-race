class_name Predator
extends BaseCharacter

var hitbox: HitboxComponent
var status_effects: StatusEffectComponent
var _dash_cooldown: float = 0.0
var _dash_active: bool = false
var _dash_hit: bool = false


func _setup_role() -> void:
	role = Enums.Role.PREDATOR
	movement.move_speed = Constants.SPEED_PREDATOR

	# Status effects (for self-stun on miss)
	status_effects = StatusEffectComponent.new()
	status_effects.setup(movement)
	add_child(status_effects)

	# Hitbox — activated during dash
	hitbox = HitboxComponent.new()
	hitbox.setup(self, team, Constants.CHARACTER_RADIUS * 1.5)
	add_child(hitbox)
	hitbox.hit_landed.connect(_on_hit_landed)


func _handle_ability_input(delta: float) -> void:
	if _dash_cooldown > 0.0:
		_dash_cooldown -= delta

	if _dash_active or status_effects.is_stunned():
		return

	if InputManager.is_action_just_pressed(player_index, &"dash") and _dash_cooldown <= 0.0:
		_start_dash()


func _start_dash() -> void:
	_dash_active = true
	_dash_hit = false
	hitbox.activate()
	movement.start_dash(aim_direction, Constants.PREDATOR_DASH_DISTANCE,
		_on_dash_complete, Constants.PREDATOR_DASH_DURATION)


func _on_hit_landed(target: Node2D) -> void:
	_dash_hit = true
	# Check if target is an enemy Escapist
	if target is Escapist:
		var esc := target as Escapist
		if esc.team != team:
			# Kill — our team wins the round
			GameManager.end_round(team)


func _on_dash_complete() -> void:
	hitbox.deactivate()
	_dash_active = false
	_dash_cooldown = Constants.PREDATOR_DASH_COOLDOWN

	if not _dash_hit:
		# Missed — self-stun
		status_effects.apply_effect(Enums.CCType.STUN, Constants.PREDATOR_MISS_STUN)


func _draw() -> void:
	var r := Constants.CHARACTER_RADIUS

	# Angular shape — triangle pointing in aim direction
	var forward := aim_direction * r * 1.3
	var left := aim_direction.rotated(2.4) * r
	var right := aim_direction.rotated(-2.4) * r
	var pts := PackedVector2Array([forward, left, right])

	var color := player_color
	if status_effects and status_effects.is_stunned():
		# Flash when stunned
		color = Color(0.5, 0.5, 0.5, 0.6)

	draw_colored_polygon(pts, color)

	# Dash trail during dash
	if _dash_active:
		var behind := -aim_direction * r * 2.0
		draw_line(Vector2.ZERO, behind, Color(color, 0.4), 4.0)

	# Cooldown indicator — arc around character
	if _dash_cooldown > 0.0:
		var ratio := _dash_cooldown / Constants.PREDATOR_DASH_COOLDOWN
		draw_arc(Vector2.ZERO, r + 4.0, -PI / 2.0, -PI / 2.0 + TAU * (1.0 - ratio),
			16, Color(1.0, 1.0, 1.0, 0.3), 2.0)

	# Stun indicator
	if status_effects and status_effects.is_stunned():
		var t := fmod(Time.get_ticks_msec() / 200.0, TAU)
		for i in 3:
			var angle := t + i * TAU / 3.0
			var star_pos := Vector2(cos(angle), sin(angle)) * (r + 8.0)
			draw_circle(star_pos, 3.0, Color.YELLOW)

	# Direction line
	var tip := aim_direction * (r + 10.0)
	draw_line(Vector2.ZERO, tip, color, 2.0)

	# Label
	var label := "P%d" % (player_index + 1)
	if player_index >= 100:
		label = "BOT"
	draw_string(ThemeDB.fallback_font, Vector2(-10, -r - 6),
		label, HORIZONTAL_ALIGNMENT_CENTER, -1, 10, color)
	draw_string(ThemeDB.fallback_font, Vector2(-10, r + 14),
		"PRED", HORIZONTAL_ALIGNMENT_CENTER, -1, 8, color)
