class_name Escapist
extends BaseCharacter

signal died(escapist: Escapist)
signal scored(escapist: Escapist)

var is_dead: bool = false
var has_scored: bool = false
var spawn_position: Vector2 = Vector2.ZERO
var escapist_animal: Enums.EscapistAnimal = Enums.EscapistAnimal.RABBIT

# Poison system
var poison: PoisonComponent

# Control inversion
var controls_inverted: bool = false
var _inversion_timer: float = 0.0

var _ability_available: bool = true
var _rabbit_charging: bool = false
var _rabbit_charge_time: float = 0.0
var _fly_counter_timer: float = 0.0
var _fly_boost_timer: float = 0.0
var _effect_immunity_timer: float = 0.0
var _floating_text: String = ""
var _floating_text_timer: float = 0.0
var _floating_text_color: Color = Color.WHITE
var _active_rat_tail: Node = null
var _bot_patrol_enabled: bool = false
var _bot_patrol_a: Vector2 = Vector2.ZERO
var _bot_patrol_b: Vector2 = Vector2.ZERO
var _bot_patrol_target: Vector2 = Vector2.ZERO


func _setup_role() -> void:
	role = Enums.Role.ESCAPIST
	var speed_mult: float = GameManager.settings_overrides.get(&"escapist_speed", 1.0) as float
	movement.move_speed = Constants.SPEED_ESCAPIST * speed_mult
	movement.crushed.connect(_on_crushed)
	_reset_ability()

	# Setup poison component
	poison = PoisonComponent.new()
	poison.setup(self)
	poison.poison_expired.connect(_on_poison_expired)
	add_child(poison)


func _ready() -> void:
	super._ready()
	spawn_position = position


func configure_patrol_bot(path_a: Vector2, path_b: Vector2) -> void:
	_bot_patrol_enabled = true
	_bot_patrol_a = path_a
	_bot_patrol_b = path_b
	_bot_patrol_target = path_b
	position = path_a
	spawn_position = path_a
	aim_direction = (_bot_patrol_target - position).normalized()


func kill() -> void:
	if is_dead or has_scored:
		return
	if is_effect_immune():
		return
	GameManager.register_respawn_penalty(player_index, &"death")
	if GameManager.current_state == Enums.GameState.PRACTICE:
		_return_to_spawn_with_death_message()
		_reset_ability()
		return
	AudioManager.play_effect(&"DeathRespawn")
	is_dead = true
	input_locked = true
	movement.freeze()
	visible = false
	died.emit(self)


func _on_poison_expired() -> void:
	GameManager.register_respawn_penalty(player_index, &"poison")
	respawn()


func invert_controls(duration: float) -> void:
	if is_effect_immune():
		return
	controls_inverted = true
	_inversion_timer = duration


func _physics_process(delta: float) -> void:
	if _inversion_timer > 0.0:
		_inversion_timer -= delta
		if _inversion_timer <= 0.0:
			controls_inverted = false
	if _fly_counter_timer > 0.0:
		_fly_counter_timer -= delta
	if _fly_boost_timer > 0.0:
		_fly_boost_timer -= delta
		if _fly_boost_timer <= 0.0:
			movement.remove_speed_modifier(&"fly_boost")
	if _effect_immunity_timer > 0.0:
		_effect_immunity_timer -= delta
	_update_floating_text(delta)
	_process_patrol_bot()
	super._physics_process(delta)


func _process_patrol_bot() -> void:
	if not _bot_patrol_enabled or input_locked or is_dead or has_scored:
		return
	var to_target := _bot_patrol_target - position
	if to_target.length() <= 12.0:
		_bot_patrol_target = _bot_patrol_a if _bot_patrol_target == _bot_patrol_b else _bot_patrol_b
		to_target = _bot_patrol_target - position
	if to_target.length_squared() <= 0.01:
		movement.apply_movement(Vector2.ZERO)
		return
	var move_vec := to_target.normalized()
	if controls_inverted:
		move_vec *= -1.0
	aim_direction = move_vec
	movement.apply_movement(move_vec)


func respawn() -> void:
	if is_dead or has_scored:
		return
	_return_to_spawn_with_death_message()
	if poison.is_poisoned:
		poison.cure()
	_reset_ability()


func _on_crushed() -> void:
	if is_dead or has_scored:
		return
	if is_effect_immune():
		return
	GameManager.register_respawn_penalty(player_index, &"crush")
	_return_to_spawn_with_death_message()
	_reset_ability()


func _return_to_spawn_with_death_message() -> void:
	position = spawn_position
	movement.velocity = Vector2.ZERO
	movement.slippery = false
	movement.clear_speed_modifiers()
	controls_inverted = false
	_inversion_timer = 0.0
	AudioManager.play_effect(&"DeathRespawn")
	_show_floating_text("You died !!", Color.WHITE)


func _show_floating_text(text: String, text_color: Color) -> void:
	_floating_text = text
	_floating_text_color = text_color
	_floating_text_timer = Constants.FLOATING_TEXT_DURATION
	queue_redraw()


func _update_floating_text(delta: float) -> void:
	if _floating_text_timer <= 0.0:
		return
	_floating_text_timer = maxf(_floating_text_timer - delta, 0.0)
	if _floating_text_timer <= 0.0:
		_floating_text = ""
	queue_redraw()


func score() -> void:
	if is_dead or has_scored:
		return
	has_scored = true
	input_locked = true
	movement.freeze()
	visible = false
	scored.emit(self)


func _handle_ability_input(_delta: float) -> void:
	if is_dead or has_scored:
		return

	if escapist_animal == Enums.EscapistAnimal.RAT \
			and is_instance_valid(_active_rat_tail) \
			and InputManager.is_action_just_pressed(player_index, &"dash"):
		(_active_rat_tail as RatTailHook).retract()
		return

	if _skills_cooldowns_enabled() and not _ability_available:
		return

	match escapist_animal:
		Enums.EscapistAnimal.RABBIT:
			_handle_rabbit_ability(_delta)
		Enums.EscapistAnimal.RAT:
			if InputManager.is_action_just_pressed(player_index, &"dash"):
				_use_rat_rescue()
		Enums.EscapistAnimal.SQUIRREL:
			if InputManager.is_action_just_pressed(player_index, &"dash"):
				_use_squirrel_acorn()
		Enums.EscapistAnimal.FLY:
			if InputManager.is_action_just_pressed(player_index, &"dash"):
				_use_fly_counter()


func _handle_rabbit_ability(delta: float) -> void:
	if InputManager.is_action_just_pressed(player_index, &"dash"):
		_rabbit_charging = true
		_rabbit_charge_time = 0.0
	if _rabbit_charging and InputManager.is_action_pressed(player_index, &"dash"):
		_rabbit_charge_time = minf(_rabbit_charge_time + delta, Constants.RABBIT_LEAP_MAX_CHARGE)
	if _rabbit_charging and InputManager.is_action_just_released(player_index, &"dash"):
		var ratio := _rabbit_charge_time / Constants.RABBIT_LEAP_MAX_CHARGE
		var distance := lerpf(Constants.RABBIT_LEAP_MIN_DIST, Constants.RABBIT_LEAP_MAX_DIST, ratio)
		var direction := _get_ability_direction()
		AudioManager.play_skill(&"RabbitLeap")
		movement.start_dash(direction, distance, Callable(), Constants.RABBIT_LEAP_DURATION, true)
		_rabbit_charging = false
		if _skills_cooldowns_enabled():
			_ability_available = false


func _use_rat_rescue() -> void:
	if is_instance_valid(_active_rat_tail):
		(_active_rat_tail as RatTailHook).retract()
		return
	var tail := RatTailHook.new()
	tail.setup(self, _get_ability_direction())
	get_parent().add_child(tail)
	_active_rat_tail = tail
	tail.finished.connect(_on_rat_tail_finished)
	AudioManager.play_skill(&"RatWhipOut")
	if _skills_cooldowns_enabled():
		_ability_available = false


func _on_rat_tail_finished(tail: Node) -> void:
	if _active_rat_tail == tail:
		_active_rat_tail = null


func _complete_rat_rescue(ally: Escapist) -> void:
	if not is_instance_valid(ally) or ally.is_dead or ally.has_scored:
		return
	var pull_vector := global_position - ally.global_position
	var pull_distance := maxf(pull_vector.length() - Constants.RAT_RESCUE_PULL_STOP_DISTANCE, 0.0)
	if pull_distance <= 0.0:
		return
	var direction := pull_vector.normalized()
	ally.movement.unfreeze()
	ally.movement.velocity = Vector2.ZERO
	ally.movement.slippery = false
	ally.movement.clear_speed_modifiers()
	var duration := pull_distance / Constants.RAT_RESCUE_PULL_SPEED
	ally.movement.start_dash_ghost_pull(direction, pull_distance, Callable(), duration)


func _use_squirrel_acorn() -> void:
	var acorn := AcornProjectile.new()
	acorn.setup(global_position, _get_ability_direction())
	get_parent().add_child(acorn)
	AudioManager.play_skill(&"AcornThrow")
	if _skills_cooldowns_enabled():
		_ability_available = false


func _use_fly_counter() -> void:
	_fly_counter_timer = Constants.FLY_COUNTER_DURATION
	if _skills_cooldowns_enabled():
		_ability_available = false
	AudioManager.play_skill(&"FlyCounter")


func notify_trap_contact() -> void:
	if escapist_animal == Enums.EscapistAnimal.FLY and _fly_counter_timer > 0.0:
		_fly_counter_timer = 0.0
		_fly_boost_timer = Constants.FLY_BOOST_DURATION
		_effect_immunity_timer = Constants.FLY_BOOST_DURATION
		movement.set_speed_modifier(&"fly_boost", Constants.FLY_SPEED_BOOST)


func is_effect_immune() -> bool:
	return _effect_immunity_timer > 0.0


func _reset_ability() -> void:
	_ability_available = true
	_rabbit_charging = false
	_rabbit_charge_time = 0.0
	_fly_counter_timer = 0.0
	_fly_boost_timer = 0.0
	_effect_immunity_timer = 0.0
	if is_instance_valid(_active_rat_tail):
		_active_rat_tail.queue_free()
	_active_rat_tail = null
	if movement:
		movement.remove_speed_modifier(&"fly_boost")


func _skills_cooldowns_enabled() -> bool:
	return GameManager.settings_overrides.get(&"skill_cooldowns_enabled", true) as bool


func _get_ability_direction() -> Vector2:
	var direction := aim_direction
	var move_vec := InputManager.get_move_vector(player_index)
	if move_vec.length() > 0.1:
		direction = move_vec.normalized()
	if direction.length() < 0.1:
		direction = Vector2.RIGHT
	return direction.normalized()


func _get_animal_mark_alpha() -> float:
	if not movement:
		return 0.95
	var speed := maxf(movement.velocity.length(), velocity.length())
	if movement.is_dashing:
		speed = movement.move_speed * 1.4
	var move_ratio := clampf(speed / maxf(movement.move_speed, 1.0), 0.0, 1.0)
	return lerpf(0.95, 0.48, move_ratio)


func _make_animal_mark_color(base_color: Color, alpha_scale: float = 1.0) -> Color:
	var alpha := _get_animal_mark_alpha() * alpha_scale
	return Color(base_color, alpha)


func _get_rabbit_jump_lift() -> float:
	if escapist_animal != Enums.EscapistAnimal.RABBIT or not movement:
		return 0.0
	if not movement.is_airborne_dashing:
		return 0.0
	return sin(movement.get_dash_progress() * PI) * Constants.RABBIT_LEAP_VISUAL_HEIGHT


func _draw_animal_mark(base_color: Color) -> void:
	var mark_color := _make_animal_mark_color(base_color)
	match escapist_animal:
		Enums.EscapistAnimal.RABBIT:
			_draw_rabbit_mark(mark_color)
		Enums.EscapistAnimal.RAT:
			_draw_rat_mark(mark_color)
		Enums.EscapistAnimal.SQUIRREL:
			_draw_squirrel_mark(mark_color)
		Enums.EscapistAnimal.FLY:
			_draw_fly_mark(base_color)


func _draw_rabbit_mark(mark_color: Color) -> void:
	draw_colored_polygon(PackedVector2Array([
		Vector2(-5.8, -3.5),
		Vector2(-10.8, -13.0),
		Vector2(-6.0, -14.2),
		Vector2(-2.0, -4.6),
	]), mark_color)
	draw_colored_polygon(PackedVector2Array([
		Vector2(5.8, -3.5),
		Vector2(10.8, -13.0),
		Vector2(6.0, -14.2),
		Vector2(2.0, -4.6),
	]), mark_color)
	draw_colored_polygon(PackedVector2Array([
		Vector2(-8.0, -2.0),
		Vector2(-4.0, -7.0),
		Vector2(4.0, -7.0),
		Vector2(8.0, -2.0),
		Vector2(7.0, 5.5),
		Vector2(2.0, 10.0),
		Vector2(-2.0, 10.0),
		Vector2(-7.0, 5.5),
	]), mark_color)


func _draw_filled_ellipse(center: Vector2, radii: Vector2, fill_color: Color, point_count: int = 18) -> void:
	var points := PackedVector2Array()
	for i in range(point_count):
		var angle := TAU * float(i) / float(point_count)
		points.append(center + Vector2(cos(angle) * radii.x, sin(angle) * radii.y))
	draw_colored_polygon(points, fill_color)


func _draw_rat_mark(mark_color: Color) -> void:
	var eye_color := Color(0.01, 0.01, 0.01, mark_color.a)
	var tail_color := Color(mark_color.r, mark_color.g, mark_color.b, mark_color.a * 0.55)
	draw_polyline(PackedVector2Array([
		Vector2(-6.2, 7.6),
		Vector2(-12.8, 9.2),
		Vector2(-15.0, 6.0),
		Vector2(-9.4, 4.5),
	]), tail_color, 2.4)
	_draw_filled_ellipse(Vector2(-5.0, 2.4), Vector2(8.0, 8.8), mark_color)
	_draw_filled_ellipse(Vector2(1.0, -3.8), Vector2(6.4, 4.8), mark_color)
	draw_colored_polygon(PackedVector2Array([
		Vector2(3.5, -7.4),
		Vector2(13.8, -3.0),
		Vector2(5.0, 1.4),
	]), mark_color)
	draw_circle(Vector2(-1.6, -7.6), 3.5, mark_color)
	draw_circle(Vector2(2.4, -7.8), 3.2, mark_color)
	draw_circle(Vector2(5.5, -4.8), 1.1, eye_color)
	draw_colored_polygon(PackedVector2Array([
		Vector2(2.0, 1.0),
		Vector2(5.0, 1.6),
		Vector2(3.5, 5.2),
	]), mark_color)
	draw_colored_polygon(PackedVector2Array([
		Vector2(-8.0, 9.4),
		Vector2(2.0, 9.0),
		Vector2(-0.5, 11.0),
	]), mark_color)


func _draw_squirrel_mark(mark_color: Color) -> void:
	var eye_color := Color(0.01, 0.01, 0.01, mark_color.a)
	draw_arc(Vector2(-4.5, -2.0), 8.6, -PI * 0.18, PI * 1.6, 26, mark_color, 3.1)
	draw_arc(Vector2(-5.0, -2.0), 4.4, PI * 0.82, PI * 1.95, 18, mark_color, 3.0)
	draw_line(Vector2(-5.0, 2.0), Vector2(-5.0, 10.2), mark_color, 3.1)
	_draw_filled_ellipse(Vector2(2.0, 5.0), Vector2(5.8, 6.0), mark_color)
	draw_colored_polygon(PackedVector2Array([
		Vector2(4.0, -4.0),
		Vector2(8.0, -7.5),
		Vector2(12.8, -3.0),
		Vector2(9.5, 1.8),
		Vector2(4.0, 1.0),
	]), mark_color)
	draw_colored_polygon(PackedVector2Array([
		Vector2(5.6, -5.0),
		Vector2(6.8, -10.0),
		Vector2(9.0, -5.8),
	]), mark_color)
	draw_circle(Vector2(9.2, -2.5), 0.9, eye_color)
	draw_polyline(PackedVector2Array([
		Vector2(7.5, 1.2),
		Vector2(10.8, 3.8),
		Vector2(6.5, 4.8),
	]), mark_color, 2.0)
	draw_line(Vector2(3.0, 9.5), Vector2(9.0, 9.5), mark_color, 2.8)


func _draw_fly_mark(base_color: Color) -> void:
	var wing_color := _make_animal_mark_color(base_color, 0.62)
	var body_color := _make_animal_mark_color(base_color)
	draw_colored_polygon(PackedVector2Array([
		Vector2(-1.5, -3.0),
		Vector2(-12.5, -8.5),
		Vector2(-14.0, 0.8),
		Vector2(-5.0, 5.6),
	]), wing_color)
	draw_colored_polygon(PackedVector2Array([
		Vector2(1.5, -3.0),
		Vector2(12.5, -8.5),
		Vector2(14.0, 0.8),
		Vector2(5.0, 5.6),
	]), wing_color)
	draw_colored_polygon(PackedVector2Array([
		Vector2(-2.8, -8.5),
		Vector2(2.8, -8.5),
		Vector2(4.0, 6.8),
		Vector2(0.0, 11.0),
		Vector2(-4.0, 6.8),
	]), body_color)


func _draw_player_label(label: String, position: Vector2, font_size: int, label_color: Color) -> void:
	var shadow_color := Color(0.0, 0.0, 0.0, 0.85)
	for offset in [
		Vector2(-1.0, 0.0),
		Vector2(1.0, 0.0),
		Vector2(0.0, -1.0),
		Vector2(0.0, 1.0),
	]:
		draw_string(ThemeDB.fallback_font, position + offset,
			label, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size, shadow_color)
	for offset in [Vector2.ZERO, Vector2(0.55, 0.0), Vector2(-0.55, 0.0)]:
		draw_string(ThemeDB.fallback_font, position + offset,
			label, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size, label_color)


func _draw() -> void:
	var animal_color := Enums.escapist_animal_color(escapist_animal)
	var team_color := Enums.team_color(team)
	var draw_color := animal_color
	var jump_lift := _get_rabbit_jump_lift()

	# Poison tint
	if poison and poison.is_poisoned:
		var pulse := 0.5 + 0.5 * sin(Time.get_ticks_msec() / 200.0)
		draw_color = draw_color.lerp(Color(0.2, 0.9, 0.1), 0.4 + 0.2 * pulse)

	# Inverted controls indicator
	if controls_inverted:
		draw_color = draw_color.lerp(Color(1.0, 0.0, 1.0), 0.3)

	if jump_lift > 0.0:
		var lift_ratio := jump_lift / Constants.RABBIT_LEAP_VISUAL_HEIGHT
		_draw_filled_ellipse(Vector2(0.0, 7.0), Vector2(13.0 + lift_ratio * 5.0, 4.2),
			Color(0.0, 0.0, 0.0, lerpf(0.24, 0.08, lift_ratio)), 20)
		draw_arc(Vector2.ZERO, Constants.CHARACTER_RADIUS + 12.0 + lift_ratio * 8.0,
			0.0, TAU, 28, Color(animal_color, lerpf(0.32, 0.08, lift_ratio)), 1.6)
		draw_set_transform(Vector2(0.0, -jump_lift), 0.0, Vector2.ONE)

	# Animal mark with outer team ring
	_draw_animal_mark(draw_color)
	draw_arc(Vector2.ZERO, Constants.CHARACTER_RADIUS + 5.5, 0, TAU, 24,
		Color(team_color, 0.55), 1.4)

	# Label
	var label := "P%d" % (player_index + 1)
	if player_index >= 100:
		label = "BOT"
	_draw_player_label(label, Vector2(-10, -Constants.CHARACTER_RADIUS - 6), 12, team_color)
	if _floating_text_timer > 0.0 and not _floating_text.is_empty():
		var text_alpha := clampf(_floating_text_timer / Constants.FLOATING_TEXT_DURATION, 0.0, 1.0)
		var text_size := 18
		var text_w := ThemeDB.fallback_font.get_string_size(
			_floating_text, HORIZONTAL_ALIGNMENT_LEFT, -1, text_size).x
		var text_pos := Vector2(-text_w / 2.0, -Constants.CHARACTER_RADIUS - 36)
		draw_string(ThemeDB.fallback_font, text_pos + Vector2(2.0, 2.0),
			_floating_text, HORIZONTAL_ALIGNMENT_LEFT, -1, text_size,
			Color(0.0, 0.0, 0.0, 0.65 * text_alpha))
		draw_string(ThemeDB.fallback_font, text_pos,
			_floating_text, HORIZONTAL_ALIGNMENT_LEFT, -1, text_size,
			Color(_floating_text_color, text_alpha))

	var ability_color := Color(0.2, 1.0, 0.4, 0.45) if _ability_available else Color(0.45, 0.45, 0.45, 0.32)
	draw_arc(Vector2.ZERO, Constants.CHARACTER_RADIUS + 8.5, 0, TAU, 24, ability_color, 1.2)
	if _rabbit_charging:
		var ratio := _rabbit_charge_time / Constants.RABBIT_LEAP_MAX_CHARGE
		draw_arc(Vector2.ZERO, Constants.CHARACTER_RADIUS + 10.0,
			-PI / 2.0, -PI / 2.0 + TAU * ratio, 18, Color(1.0, 1.0, 0.2), 2.0)
	if _fly_counter_timer > 0.0:
		draw_arc(Vector2.ZERO, Constants.CHARACTER_RADIUS + 10.0,
			-PI / 2.0, -PI / 2.0 + TAU * (_fly_counter_timer / Constants.FLY_COUNTER_DURATION),
			18, Color(0.3, 0.9, 0.85), 2.0)
	if _effect_immunity_timer > 0.0:
		draw_circle(Vector2.ZERO, Constants.CHARACTER_RADIUS + 4.0, Color(0.3, 0.9, 0.85, 0.18))

	# Poison timer indicator
	if poison and poison.is_poisoned:
		var ratio := poison.get_timer_ratio()
		draw_arc(Vector2.ZERO, Constants.CHARACTER_RADIUS + 5.0,
			-PI / 2.0, -PI / 2.0 + TAU * ratio, 12,
			Color(0.2, 0.9, 0.1, 0.6), 2.0)

	if jump_lift > 0.0:
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


class RatTailHook extends Node2D:
	signal finished(tail: Node)

	var _owner_rat: Escapist
	var _direction: Vector2 = Vector2.RIGHT
	var _distance: float = 0.0
	var _hook_end_position: Vector2 = Vector2.ZERO
	var _target: Escapist = null
	var _is_returning: bool = false
	var _is_holding: bool = false
	var _hold_timer: float = Constants.RAT_RESCUE_HOLD_DURATION
	var _fade_timer: float = 0.18
	var _color: Color = Enums.escapist_animal_color(Enums.EscapistAnimal.RAT)

	func setup(owner_rat: Escapist, direction: Vector2) -> void:
		_owner_rat = owner_rat
		_direction = direction.normalized()
		if _direction.length_squared() < 0.01:
			_direction = Vector2.RIGHT
		global_position = _owner_rat.global_position
		_hook_end_position = _owner_rat.global_position
		z_index = 8

	func _process(delta: float) -> void:
		if not is_instance_valid(_owner_rat) or _owner_rat.is_dead or _owner_rat.has_scored:
			_finish()
			return
		if _is_returning:
			_update_return(delta)
			return
		if _is_holding:
			_update_hold(delta)
			return

		var previous_distance := _distance
		_distance = minf(_distance + Constants.RAT_RESCUE_HOOK_SPEED * delta, Constants.RAT_RESCUE_RANGE)
		var hook_start := _owner_rat.global_position + _direction * previous_distance
		_hook_end_position = _owner_rat.global_position + _direction * _distance
		var ally := _find_hooked_ally_between(hook_start, _hook_end_position)
		if ally != null:
			_hook_ally(ally)
			return
		if _distance >= Constants.RAT_RESCUE_RANGE:
			_is_holding = true
		queue_redraw()

	func _update_return(delta: float) -> void:
		_fade_timer -= delta
		if is_instance_valid(_target):
			_distance = _owner_rat.global_position.distance_to(_target.global_position)
		else:
			_hook_end_position = _hook_end_position.move_toward(
				_owner_rat.global_position,
				Constants.RAT_RESCUE_HOOK_SPEED * delta
			)
			_distance = _owner_rat.global_position.distance_to(_hook_end_position)
		if _fade_timer <= 0.0 or _distance <= Constants.RAT_RESCUE_PULL_STOP_DISTANCE:
			_finish()
			return
		queue_redraw()

	func _update_hold(delta: float) -> void:
		_hold_timer -= delta
		var ally := _find_hooked_ally_between(_owner_rat.global_position, _hook_end_position)
		if ally != null:
			_hook_ally(ally)
			return
		if _hold_timer <= 0.0:
			retract()
			return
		queue_redraw()

	func retract() -> void:
		if _is_returning:
			return
		if not _is_holding:
			_hook_end_position = _owner_rat.global_position + _direction * _distance
		_is_holding = false
		_is_returning = true
		_distance = _owner_rat.global_position.distance_to(_hook_end_position)
		_fade_timer = maxf(0.18, _distance / Constants.RAT_RESCUE_HOOK_SPEED)
		queue_redraw()

	func _find_hooked_ally_between(hook_start: Vector2, hook_end: Vector2) -> Escapist:
		var tree := get_tree()
		if not tree:
			return null
		var best: Escapist = null
		var best_distance := 999999.0
		for node: Node in tree.get_nodes_in_group("characters"):
			if node == _owner_rat or not (node is Escapist):
				continue
			var ally := node as Escapist
			if ally.team != _owner_rat.team or ally.is_dead or ally.has_scored:
				continue
			var distance_to_segment := _distance_to_segment(ally.global_position, hook_start, hook_end)
			if distance_to_segment > Constants.RAT_RESCUE_WIDTH:
				continue
			var distance_from_owner := _owner_rat.global_position.distance_to(ally.global_position)
			if distance_from_owner < best_distance:
				best_distance = distance_from_owner
				best = ally
		return best

	func _hook_ally(ally: Escapist) -> void:
		_target = ally
		_distance = _owner_rat.global_position.distance_to(ally.global_position)
		_hook_end_position = ally.global_position
		_is_returning = true
		_fade_timer = maxf(0.18, _distance / Constants.RAT_RESCUE_PULL_SPEED)
		_owner_rat._complete_rat_rescue(ally)
		queue_redraw()

	func _distance_to_segment(point: Vector2, segment_start: Vector2, segment_end: Vector2) -> float:
		var segment := segment_end - segment_start
		var segment_length_sq := segment.length_squared()
		if segment_length_sq <= 0.01:
			return point.distance_to(segment_start)
		var t := clampf((point - segment_start).dot(segment) / segment_length_sq, 0.0, 1.0)
		var closest := segment_start + segment * t
		return point.distance_to(closest)

	func _finish() -> void:
		finished.emit(self)
		queue_free()

	func _draw() -> void:
		if not is_instance_valid(_owner_rat):
			return
		var start := _owner_rat.global_position - global_position
		var end := _hook_end_position - global_position
		if is_instance_valid(_target):
			end = _target.global_position - global_position
		var alpha := 0.72
		if _is_returning and not is_instance_valid(_target):
			alpha = clampf(_fade_timer / 0.18, 0.0, 1.0) * 0.72
		elif _is_holding:
			alpha = 0.62 + 0.1 * sin(Time.get_ticks_msec() / 110.0)
		var pulse := 0.75 + 0.25 * sin(Time.get_ticks_msec() / 80.0)
		var line_color := Color(_color, alpha * pulse)
		draw_line(start, end, Color(0.0, 0.0, 0.0, alpha * 0.45), 7.0)
		draw_line(start, end, line_color, 4.0)
		draw_circle(end, 8.0, Color(_color, alpha))


class AcornProjectile extends Node2D:
	var _velocity: Vector2 = Vector2.ZERO
	var _lifetime: float = Constants.SQUIRREL_ACORN_LIFETIME
	var _bounces_left: int = Constants.SQUIRREL_ACORN_BOUNCES
	var _color: Color = Enums.escapist_animal_color(Enums.EscapistAnimal.SQUIRREL)
	var _is_stuck: bool = false
	var _stuck_timer: float = 0.0

	func setup(start_position: Vector2, direction: Vector2) -> void:
		global_position = start_position
		_velocity = direction.normalized() * Constants.SQUIRREL_ACORN_SPEED
		add_to_group("projectiles")

	func _process(delta: float) -> void:
		if _is_stuck:
			_stuck_timer -= delta
			if _stuck_timer <= 0.0:
				queue_free()
				return
			queue_redraw()
			return

		_lifetime -= delta
		if _lifetime <= 0.0:
			queue_free()
			return

		var from := global_position
		var to := from + _velocity * delta
		var query := PhysicsRayQueryParameters2D.create(from, to)
		query.collision_mask = Constants.LAYER_WALLS | Constants.LAYER_TRAPS
		query.collide_with_areas = true
		query.collide_with_bodies = true
		var hit := get_world_2d().direct_space_state.intersect_ray(query)
		if hit.is_empty():
			global_position = to
		else:
			global_position = hit["position"] as Vector2
			var collider := hit["collider"] as Node
			if collider and collider.is_in_group("traps"):
				collider.queue_free()
				queue_free()
				return
			if collider and collider.is_in_group("sticky_walls"):
				_stick_to_wall(hit["position"] as Vector2)
				return
			AudioManager.play_effect(&"Bounce")
			_bounces_left -= 1
			if _bounces_left < 0:
				queue_free()
				return
			var normal: Vector2 = hit["normal"] as Vector2
			_velocity = _velocity.bounce(normal)
			global_position += normal * 2.0

		queue_redraw()

	func _stick_to_wall(stick_position: Vector2) -> void:
		global_position = stick_position
		_velocity = Vector2.ZERO
		_is_stuck = true
		_stuck_timer = Constants.STICKY_WALL_STUN
		queue_redraw()

	func _draw() -> void:
		draw_circle(Vector2.ZERO, Constants.SQUIRREL_ACORN_RADIUS, Color(_color, 0.85))
		draw_arc(Vector2.ZERO, Constants.SQUIRREL_ACORN_RADIUS + 2.0, 0, TAU, 12,
			Color(1.0, 1.0, 1.0, 0.45), 1.0)
		if _is_stuck:
			var pulse := 0.65 + 0.35 * sin(Time.get_ticks_msec() / 90.0)
			draw_arc(Vector2.ZERO, Constants.SQUIRREL_ACORN_RADIUS + 5.0, 0, TAU, 14,
				Color(Constants.STICKY_WALL_COLOR, 0.55 * pulse), 2.0)
