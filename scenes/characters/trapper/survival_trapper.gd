class_name SurvivalTrapper
extends BaseCharacter

var trapper_character: Enums.TrapperCharacter = Enums.TrapperCharacter.ARANA
var bot_ai_enabled: bool = false
var _bot_target: Vector2 = Vector2.ZERO
var _bot_retarget_timer: float = 0.0
var _bot_last_position: Vector2 = Vector2.ZERO
var _bot_blocked_timer: float = 0.0


func _setup_role() -> void:
	role = Enums.Role.TRAPPER
	var speed_mult: float = GameManager.settings_overrides.get(&"trapper_speed", 1.0) as float
	movement.move_speed = Constants.SPEED_ESCAPIST * 0.96 * speed_mult
	collision_mask = Constants.LAYER_WALLS | Constants.LAYER_CHARACTERS | Constants.LAYER_SURVIVAL_SAFE_BLOCKERS


func configure_survival_bot() -> void:
	bot_ai_enabled = true
	_bot_retarget_timer = 0.0
	_bot_last_position = position
	_pick_patrol_target()


func set_survival_bot_static(make_static: bool) -> void:
	bot_ai_enabled = not make_static
	_bot_blocked_timer = 0.0
	if make_static and movement:
		movement.apply_movement(Vector2.ZERO)
	elif bot_ai_enabled:
		_bot_retarget_timer = 0.0
		_bot_last_position = position
		_pick_patrol_target()


func _physics_process(delta: float) -> void:
	if bot_ai_enabled:
		_process_survival_bot(delta)
	super._physics_process(delta)


func _process_survival_bot(delta: float) -> void:
	if input_locked:
		return
	var target_escapist := _find_nearest_unsafe_escapist()
	var target := _bot_target
	if target_escapist != null:
		target = target_escapist.global_position
	else:
		_bot_retarget_timer -= delta
		if _bot_retarget_timer <= 0.0 or position.distance_to(_bot_target) <= 18.0:
			_pick_patrol_target()
		target = _bot_target

	var to_target := target - position
	if to_target.length_squared() <= 9.0:
		movement.apply_movement(Vector2.ZERO)
		return
	var move_vec := to_target.normalized()
	aim_direction = move_vec
	movement.apply_movement(move_vec)

	if position.distance_to(_bot_last_position) < 1.2 and movement.velocity.length() > 20.0:
		_bot_blocked_timer += delta
	else:
		_bot_blocked_timer = 0.0
	_bot_last_position = position
	if _bot_blocked_timer >= 0.9:
		_pick_patrol_target()
		_bot_blocked_timer = 0.0


func _find_nearest_unsafe_escapist() -> Escapist:
	var best: Escapist = null
	var best_dist_sq := INF
	var tree := get_tree()
	if tree == null:
		return null
	for node: Node in tree.get_nodes_in_group("characters"):
		if not node is Escapist:
			continue
		var esc := node as Escapist
		if esc.is_dead or esc.has_scored:
			continue
		if esc.get_meta("survival_safe_zone", false) as bool:
			continue
		if esc.get_meta("survival_jailed", false) as bool:
			continue
		var dist_sq := global_position.distance_squared_to(esc.global_position)
		if dist_sq < best_dist_sq:
			best_dist_sq = dist_sq
			best = esc
	return best


func _pick_patrol_target() -> void:
	var bounds := Rect2(Vector2.ZERO, Vector2(1500.0, 860.0))
	if has_meta("map_bounds"):
		bounds = get_meta("map_bounds") as Rect2
	_bot_target = Vector2(
		randf_range(bounds.position.x + 24.0, bounds.end.x - 24.0),
		randf_range(bounds.position.y + 24.0, bounds.end.y - 24.0)
	)
	_bot_retarget_timer = randf_range(1.6, 3.2)


func _draw() -> void:
	var character_color := Enums.trapper_character_color(trapper_character)
	var team_color := Enums.team_color(team)
	var radius := Constants.CHARACTER_RADIUS
	var pulse := 0.5 + 0.5 * sin(Time.get_ticks_msec() / 180.0)

	draw_circle(Vector2.ZERO, radius + 6.0, Color(team_color, 0.16))
	draw_circle(Vector2(0.0, 5.0), radius * 0.92, Color(0.0, 0.0, 0.0, 0.28))
	draw_circle(Vector2.ZERO, radius, Color(character_color, 0.88))
	draw_arc(Vector2.ZERO, radius + 5.0, 0.0, TAU, 24, Color(team_color, 0.82), 2.2)
	draw_arc(Vector2.ZERO, radius + 9.0, 0.0, TAU, 28, Color(character_color, 0.18 + pulse * 0.10), 1.4)

	var tip := aim_direction.normalized() * (radius + 8.0)
	if tip.length_squared() <= 0.01:
		tip = Vector2.LEFT * (radius + 8.0)
	draw_line(Vector2.ZERO, tip, Color(0.0, 0.0, 0.0, 0.55), 4.0)
	draw_line(Vector2.ZERO, tip, Color.WHITE, 1.4)

	var marker := _get_character_marker()
	var marker_size := 18
	var marker_width := ThemeDB.fallback_font.get_string_size(marker, HORIZONTAL_ALIGNMENT_LEFT, -1, marker_size).x
	draw_string(ThemeDB.fallback_font, Vector2(-marker_width / 2.0, 7.0),
		marker, HORIZONTAL_ALIGNMENT_LEFT, -1, marker_size, Color(0.04, 0.04, 0.05, 0.9))
	draw_string(ThemeDB.fallback_font, Vector2(-marker_width / 2.0, 5.0),
		marker, HORIZONTAL_ALIGNMENT_LEFT, -1, marker_size, Color.WHITE)

	var label := "P%d" % (player_index + 1)
	_draw_player_label(label, Vector2(-10.0, -radius - 8.0), 14, team_color)


func _get_character_marker() -> String:
	match trapper_character:
		Enums.TrapperCharacter.ARANA:
			return "A"
		Enums.TrapperCharacter.HONGO:
			return "H"
		Enums.TrapperCharacter.ESCORPION:
			return "E"
		Enums.TrapperCharacter.PULPO:
			return "P"
	return "C"


func _draw_player_label(label: String, position: Vector2, font_size: int, label_color: Color) -> void:
	var shadow_color := Color(0.0, 0.0, 0.0, 0.85)
	for offset in [Vector2(-1.0, 0.0), Vector2(1.0, 0.0), Vector2(0.0, -1.0), Vector2(0.0, 1.0)]:
		draw_string(ThemeDB.fallback_font, position + offset,
			label, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size, shadow_color)
	for offset in [Vector2.ZERO, Vector2(0.55, 0.0), Vector2(-0.55, 0.0)]:
		draw_string(ThemeDB.fallback_font, position + offset,
			label, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size, label_color)
