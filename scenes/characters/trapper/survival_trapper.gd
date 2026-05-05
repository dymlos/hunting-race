class_name SurvivalTrapper
extends BaseCharacter

const PersistentVenomAbility := preload("res://scenes/characters/trapper/abilities/arana/persistent_venom.gd")
const ElasticWebAbility := preload("res://scenes/characters/trapper/abilities/arana/elastic_web.gd")
const ExpansiveWebAbility := preload("res://scenes/characters/trapper/abilities/arana/expansive_web.gd")
const ConfusingMushroomAbility := preload("res://scenes/characters/trapper/abilities/hongo/confusing_mushroom.gd")
const ToxicSporeZoneAbility := preload("res://scenes/characters/trapper/abilities/hongo/toxic_spore_zone.gd")
const FungalTeleportAbility := preload("res://scenes/characters/trapper/abilities/hongo/fungal_teleport.gd")
const CrushingPincersAbility := preload("res://scenes/characters/trapper/abilities/escorpion/crushing_pincers.gd")
const BindingTentacleAbility := preload("res://scenes/characters/trapper/abilities/pulpo/binding_tentacle.gd")
const InkStainAbility := preload("res://scenes/characters/trapper/abilities/pulpo/ink_stain.gd")
const WaterCurrentAbility := preload("res://scenes/characters/trapper/abilities/pulpo/water_current.gd")

const SURVIVAL_ABILITY_HOLD_THRESHOLD: float = 0.34
const SURVIVAL_ABILITY_READY := &"ready"
const SURVIVAL_ABILITY_USED := &"used"

var trapper_character: Enums.TrapperCharacter = Enums.TrapperCharacter.ARANA
var bot_ai_enabled: bool = false
var _bot_target: Vector2 = Vector2.ZERO
var _bot_retarget_timer: float = 0.0
var _bot_last_position: Vector2 = Vector2.ZERO
var _bot_blocked_timer: float = 0.0
var _bot_survival_ability_timer: float = 1.0
var _survival_ability_state: StringName = SURVIVAL_ABILITY_READY
var _survival_placement_points: Array[Vector2] = []
var _ability_button_held: bool = false
var _ability_button_hold_time: float = 0.0
var _floating_text: String = ""
var _floating_text_timer: float = 0.0
var _floating_text_duration: float = 0.85
var _floating_text_color: Color = Color.WHITE
var _ability_ready_flash_timer: float = 0.0


func _setup_role() -> void:
	role = Enums.Role.TRAPPER
	var speed_mult: float = GameManager.settings_overrides.get(&"trapper_speed", 1.0) as float
	movement.move_speed = Constants.SPEED_ESCAPIST * 0.96 * speed_mult
	collision_mask = Constants.LAYER_WALLS | Constants.LAYER_CHARACTERS | Constants.LAYER_SURVIVAL_SAFE_BLOCKERS


func configure_survival_bot() -> void:
	bot_ai_enabled = true
	_bot_retarget_timer = 0.0
	_bot_survival_ability_timer = randf_range(0.8, 1.4)
	_bot_last_position = position
	_pick_patrol_target()


func set_survival_bot_static(make_static: bool) -> void:
	bot_ai_enabled = not make_static
	_bot_blocked_timer = 0.0
	if make_static and movement:
		movement.apply_movement(Vector2.ZERO)
	elif bot_ai_enabled:
		_bot_retarget_timer = 0.0
		_bot_survival_ability_timer = randf_range(0.8, 1.4)
		_bot_last_position = position
		_pick_patrol_target()


func _physics_process(delta: float) -> void:
	_update_survival_ability_feedback(delta)
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
		_process_survival_bot_ability(delta, target_escapist)
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
	_process_survival_bot_ability(delta, target_escapist)


func _process_survival_bot_ability(delta: float, target_escapist: Escapist) -> void:
	if _survival_ability_state != SURVIVAL_ABILITY_READY:
		return
	_bot_survival_ability_timer = maxf(_bot_survival_ability_timer - delta, 0.0)
	if _bot_survival_ability_timer > 0.0:
		return
	if target_escapist == null or not is_instance_valid(target_escapist):
		return
	if global_position.distance_to(target_escapist.global_position) > 92.0:
		return
	_spawn_survival_single_point_ability(global_position)
	_bot_survival_ability_timer = randf_range(3.0, 5.0)


func _handle_ability_input(delta: float) -> void:
	if InputManager.is_action_just_pressed(player_index, &"cancel"):
		_cancel_survival_ability_placement()
		return
	if InputManager.is_action_just_pressed(player_index, &"dash"):
		_ability_button_held = true
		_ability_button_hold_time = 0.0
	if _ability_button_held and InputManager.is_action_pressed(player_index, &"dash"):
		_ability_button_hold_time += delta
		queue_redraw()
	if _ability_button_held and InputManager.is_action_just_released(player_index, &"dash"):
		var held := _ability_button_hold_time >= SURVIVAL_ABILITY_HOLD_THRESHOLD
		_ability_button_held = false
		_ability_button_hold_time = 0.0
		_resolve_survival_ability_input(held)


func _resolve_survival_ability_input(held: bool) -> void:
	if _survival_ability_state != SURVIVAL_ABILITY_READY:
		_notify_survival_ability_denied("USADA")
		return
	var point := global_position
	if _survival_placement_points.is_empty():
		if held:
			_spawn_survival_single_point_ability(point)
		else:
			_add_survival_placement_point(point)
		return
	if _survival_placement_points.size() == 1:
		if not _survival_point_distance_is_valid(point, held):
			_notify_survival_ability_denied("LEJOS")
			return
		if held:
			_spawn_survival_two_point_ability([
				_survival_placement_points[0],
				point,
			])
		else:
			_add_survival_placement_point(point)
		return
	if not _survival_point_distance_is_valid(point, held):
		_notify_survival_ability_denied("LEJOS")
		return
	if trapper_character != Enums.TrapperCharacter.ARANA and not held:
		_notify_survival_ability_denied("MANTENER")
		return
	_spawn_survival_three_point_ability([
		_survival_placement_points[0],
		_survival_placement_points[1],
		point,
	])


func _add_survival_placement_point(point: Vector2) -> void:
	_survival_placement_points.append(point)
	_show_survival_ability_status("PUNTO %d" % _survival_placement_points.size(),
		Enums.trapper_character_color(trapper_character), 0.75)
	queue_redraw()


func _cancel_survival_ability_placement() -> void:
	if _survival_placement_points.is_empty():
		return
	_survival_placement_points.clear()
	_ability_button_held = false
	_ability_button_hold_time = 0.0
	_show_survival_ability_status("CANCELADO", Color(0.85, 0.85, 0.85), 0.65)
	queue_redraw()


func _survival_point_distance_is_valid(point: Vector2, held: bool) -> bool:
	if _survival_placement_points.is_empty():
		return true
	var max_distance := _get_survival_point_max_distance(held)
	if max_distance <= 0.0:
		return true
	return point.distance_to(_survival_placement_points.back()) <= max_distance


func _get_survival_point_max_distance(held: bool) -> float:
	if trapper_character != Enums.TrapperCharacter.ARANA:
		return 0.0
	if _survival_placement_points.size() == 1 and held:
		return Constants.ARANA_ELASTIC_MAX_DIST
	return Constants.ARANA_WEB_MAX_DIST


func _spawn_survival_single_point_ability(point: Vector2) -> void:
	var obj: Node2D = null
	var label := ""
	var color := Enums.trapper_character_color(trapper_character)
	match trapper_character:
		Enums.TrapperCharacter.ARANA:
			obj = PersistentVenomAbility.VenomPuddle.new()
			obj.call("setup", team, point)
			label = "VENENO"
			color = Color(0.2, 0.9, 0.1)
		Enums.TrapperCharacter.HONGO:
			obj = ConfusingMushroomAbility.ConfuseShroom.new()
			obj.call("setup", team, point)
			label = "CONFUSION"
		Enums.TrapperCharacter.ESCORPION:
			obj = SurvivalStingerTrap.new()
			obj.setup(team, point)
			label = "AGUIJON"
		Enums.TrapperCharacter.PULPO:
			obj = BindingTentacleAbility.TentacleNode.new()
			obj.call("setup", team, point)
			label = "TENTACULO"
			color = Color(0.3, 0.7, 0.9)
	if obj != null:
		_register_survival_ability_object(obj, label, color)


func _spawn_survival_two_point_ability(points: Array[Vector2]) -> void:
	var obj: Node2D = null
	var label := ""
	var color := Enums.trapper_character_color(trapper_character)
	match trapper_character:
		Enums.TrapperCharacter.ARANA:
			obj = ElasticWebAbility.ElasticLine.new()
			obj.call("setup", team, points[0], points[1])
			label = "ELASTICA"
			color = Color(0.8, 0.3, 0.9)
		Enums.TrapperCharacter.HONGO:
			obj = FungalTeleportAbility.TeleportPair.new()
			obj.call("setup", team, points[0], points[1])
			label = "PORTAL"
			color = Color(0.9, 0.4, 0.9)
		Enums.TrapperCharacter.ESCORPION:
			obj = CrushingPincersAbility.PincersNode.new()
			obj.call("setup", team, points[0], points[1])
			label = "PINZAS"
			color = Color(0.9, 0.3, 0.1)
		Enums.TrapperCharacter.PULPO:
			obj = WaterCurrentAbility.CurrentZone.new()
			obj.call("setup", team, points[0], points[1])
			label = "CORRIENTE"
			color = Color(0.2, 0.7, 1.0)
	if obj != null:
		_register_survival_ability_object(obj, label, color)


func _spawn_survival_three_point_ability(points: Array[Vector2]) -> void:
	var obj: Node2D = null
	var label := ""
	var color := Enums.trapper_character_color(trapper_character)
	match trapper_character:
		Enums.TrapperCharacter.ARANA:
			obj = ExpansiveWebAbility.WebZone.new()
			obj.call("setup", team, points)
			label = "TELARANA"
		Enums.TrapperCharacter.HONGO:
			obj = ToxicSporeZoneAbility.SporeZone.new()
			obj.call("setup", team, _get_points_centroid(points))
			label = "ESPORAS"
			color = Color(0.4, 0.7, 0.1)
		Enums.TrapperCharacter.ESCORPION:
			obj = SurvivalTriangleQuicksandZone.new()
			obj.setup(team, points)
			label = "ARENAS"
			color = Color(0.85, 0.7, 0.3)
		Enums.TrapperCharacter.PULPO:
			obj = InkStainAbility.InkZone.new()
			obj.call("setup", team, _get_points_centroid(points))
			label = "TINTA"
	if obj != null:
		_register_survival_ability_object(obj, label, color)


func _register_survival_ability_object(obj: Node2D, label: String, color: Color) -> void:
	obj.set_meta("owner_player_index", player_index)
	var target_parent := get_parent()
	if target_parent != null:
		target_parent.add_child(obj)
	else:
		add_child(obj)
	_survival_ability_state = SURVIVAL_ABILITY_USED
	_survival_placement_points.clear()
	_ability_button_held = false
	_ability_button_hold_time = 0.0
	_show_survival_ability_status(label, color, 0.85)
	InputManager.vibrate_player(player_index, 0.18, 0.48, 0.14)
	queue_redraw()


func refill_all_abilities(show_feedback: bool = true) -> void:
	var was_used := _survival_ability_state != SURVIVAL_ABILITY_READY
	_survival_ability_state = SURVIVAL_ABILITY_READY
	_survival_placement_points.clear()
	_ability_button_held = false
	_ability_button_hold_time = 0.0
	_ability_ready_flash_timer = 0.62
	if show_feedback and was_used:
		_show_survival_ability_status("RECARGA", Enums.trapper_character_color(trapper_character), 0.85)
		InputManager.vibrate_player(player_index, 0.20, 0.54, 0.16)
	queue_redraw()


func _notify_survival_ability_denied(text: String) -> void:
	_show_survival_ability_status(text, Color(1.0, 0.22, 0.14), 0.65)
	AudioManager.play_effect(&"CooldownDenied")
	queue_redraw()


func _show_survival_ability_status(text: String, color: Color, duration: float) -> void:
	_floating_text = text
	_floating_text_color = color
	_floating_text_duration = maxf(duration, 0.05)
	_floating_text_timer = _floating_text_duration


func _update_survival_ability_feedback(delta: float) -> void:
	if _floating_text_timer > 0.0:
		_floating_text_timer = maxf(_floating_text_timer - delta, 0.0)
		if _floating_text_timer <= 0.0:
			_floating_text = ""
	if _ability_ready_flash_timer > 0.0:
		_ability_ready_flash_timer = maxf(_ability_ready_flash_timer - delta, 0.0)


func _get_points_centroid(points: Array[Vector2]) -> Vector2:
	if points.is_empty():
		return global_position
	var centroid := Vector2.ZERO
	for point in points:
		centroid += point
	return centroid / float(points.size())


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


func _draw_survival_ability_preview(character_color: Color) -> void:
	if _survival_placement_points.is_empty():
		return
	var previous := Vector2.ZERO
	for i in _survival_placement_points.size():
		var local := _survival_placement_points[i] - global_position
		draw_circle(local, 5.0, Color(character_color, 0.78))
		draw_arc(local, 7.0, 0.0, TAU, 14, Color(0.0, 0.0, 0.0, 0.55), 1.4)
		if i > 0:
			draw_line(previous, local, Color(character_color, 0.44), 1.7)
		previous = local
	var valid := _survival_point_distance_is_valid(global_position, _is_holding_ability_button())
	var preview_color := Color(character_color, 0.70) if valid else Color(1.0, 0.16, 0.08, 0.72)
	draw_line(previous, Vector2.ZERO, preview_color, 1.7)
	var max_distance := _get_survival_point_max_distance(_is_holding_ability_button())
	if max_distance > 0.0:
		draw_arc(previous, max_distance, 0.0, TAU, 40, Color(character_color, 0.12), 1.0)


func _draw_survival_ability_indicator(character_color: Color) -> void:
	var label := "A LISTA" if _survival_ability_state == SURVIVAL_ABILITY_READY else "A USADA"
	var label_color := Color(0.36, 1.0, 0.56) if _survival_ability_state == SURVIVAL_ABILITY_READY else Color(0.95, 0.30, 0.22)
	if not _survival_placement_points.is_empty():
		label = "P%d" % _survival_placement_points.size()
		label_color = character_color
	var font_size := 10
	var width := ThemeDB.fallback_font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	var pos := Vector2(-width * 0.5, Constants.CHARACTER_RADIUS + 24.0)
	for offset in [Vector2(-1.0, 0.0), Vector2(1.0, 0.0), Vector2(0.0, -1.0), Vector2(0.0, 1.0)]:
		draw_string(ThemeDB.fallback_font, pos + offset,
			label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color(0.0, 0.0, 0.0, 0.82))
	draw_string(ThemeDB.fallback_font, pos,
		label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, label_color)

	if _is_holding_ability_button():
		var ratio := clampf(_ability_button_hold_time / SURVIVAL_ABILITY_HOLD_THRESHOLD, 0.0, 1.0)
		draw_arc(Vector2.ZERO, Constants.CHARACTER_RADIUS + 12.0,
			-PI / 2.0, -PI / 2.0 + TAU * ratio, 24, Color(1.0, 0.94, 0.32, 0.92), 2.3)
	if _ability_ready_flash_timer > 0.0:
		var ratio := clampf(_ability_ready_flash_timer / 0.62, 0.0, 1.0)
		draw_arc(Vector2.ZERO, Constants.CHARACTER_RADIUS + 12.0,
			0.0, TAU, 26, Color(character_color, 0.82 * ratio), 2.6)


func _is_holding_ability_button() -> bool:
	return _ability_button_held and _ability_button_hold_time > 0.0


func _draw_survival_floating_text() -> void:
	if _floating_text_timer <= 0.0 or _floating_text.is_empty():
		return
	var alpha := clampf(_floating_text_timer / maxf(_floating_text_duration, 0.01), 0.0, 1.0)
	var font_size := 17
	var width := ThemeDB.fallback_font.get_string_size(
		_floating_text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	var pos := Vector2(-width * 0.5, -Constants.CHARACTER_RADIUS - 35.0)
	draw_string(ThemeDB.fallback_font, pos + Vector2(2.0, 2.0),
		_floating_text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size,
		Color(0.0, 0.0, 0.0, 0.65 * alpha))
	draw_string(ThemeDB.fallback_font, pos,
		_floating_text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size,
		Color(_floating_text_color, alpha))


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
	_draw_survival_ability_preview(character_color)
	_draw_survival_ability_indicator(character_color)
	_draw_survival_floating_text()


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


class SurvivalStingerTrap extends Area2D:
	var owner_team: Enums.Team = Enums.Team.NONE
	var _lifetime: float = Constants.ESCORPION_STINGER_LIFETIME
	var _color: Color = Enums.trapper_character_color(Enums.TrapperCharacter.ESCORPION)
	var _visibility_ratio: float = 0.0

	func setup(team: Enums.Team, pos: Vector2) -> void:
		owner_team = team
		position = pos
		add_to_group("traps")
		collision_layer = Constants.LAYER_TRAPS
		collision_mask = Constants.LAYER_CHARACTERS
		monitoring = true
		monitorable = true

		var shape := CircleShape2D.new()
		shape.radius = Constants.ESCORPION_STINGER_RADIUS
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
		_update_visibility(delta)
		queue_redraw()

	func _update_visibility(delta: float) -> void:
		var reveal_radius := 170.0
		var target_ratio := 0.0
		var tree := get_tree()
		if tree != null:
			for node: Node in tree.get_nodes_in_group("characters"):
				if not node is Escapist:
					continue
				var esc := node as Escapist
				if esc.team == owner_team or esc.is_dead or esc.has_scored:
					continue
				if esc.get_meta("survival_safe_zone", false) as bool:
					continue
				if esc.get_meta("survival_jailed", false) as bool:
					continue
				var distance := global_position.distance_to(esc.global_position)
				if distance > reveal_radius:
					continue
				target_ratio = maxf(target_ratio, 1.0 - distance / reveal_radius)
		_visibility_ratio = lerpf(_visibility_ratio, target_ratio, clampf(delta * 7.0, 0.0, 1.0))

	func _on_body_entered(body: Node2D) -> void:
		if not GameManager.is_trap_interaction_active():
			return
		if not body is Escapist:
			return
		var esc := body as Escapist
		if esc.team == owner_team or esc.is_dead or esc.has_scored:
			return
		GameManager.register_trap_contact(esc.player_index, int(get_meta("owner_player_index", -1)))
		if esc.is_effect_immune():
			queue_free()
			return
		esc.notify_trap_status("ENVENENADO", Color(0.15, 0.95, 0.2), 0.9)
		esc.poison.apply_poison()
		queue_free()

	func _draw() -> void:
		var r := Constants.ESCORPION_STINGER_RADIUS
		var pulse := 0.55 + 0.45 * sin(Time.get_ticks_msec() / 230.0)
		var alpha := clampf(0.02 + _visibility_ratio * 0.85, 0.0, 0.9)
		draw_circle(Vector2.ZERO, r * (0.42 + _visibility_ratio * 0.24), Color(_color, alpha * 0.26))
		draw_arc(Vector2.ZERO, r * (0.62 + pulse * 0.08), 0.0, TAU, 16,
			Color(_color, alpha), 1.6 + _visibility_ratio * 1.2)
		for i in 4:
			var angle := Time.get_ticks_msec() / 720.0 + float(i) * TAU / 4.0
			var offset := Vector2.from_angle(angle) * r * 0.38
			draw_circle(offset, 1.4 + _visibility_ratio * 1.8, Color(1.0, 0.78, 0.28, alpha * pulse))


class SurvivalTriangleQuicksandZone extends Area2D:
	var owner_team: Enums.Team = Enums.Team.NONE
	var _lifetime: float = Constants.ESCORPION_QUICKSAND_LIFETIME
	var _color: Color = Color(0.85, 0.7, 0.3)
	var _points: Array[Vector2] = []
	var _bodies_inside: Dictionary = {}

	func setup(team: Enums.Team, points: Array[Vector2]) -> void:
		owner_team = team
		_points = _valid_triangle(points)
		add_to_group("traps")
		collision_layer = Constants.LAYER_TRAPS
		collision_mask = Constants.LAYER_CHARACTERS
		monitoring = true
		monitorable = true

		var centroid := Vector2.ZERO
		for point in _points:
			centroid += point
		position = centroid / float(_points.size())

		var polygon := PackedVector2Array()
		for point in _points:
			polygon.append(point - position)
		var shape := ConvexPolygonShape2D.new()
		shape.points = polygon
		var col := CollisionShape2D.new()
		col.shape = shape
		add_child(col)

		body_entered.connect(_on_body_entered)
		body_exited.connect(_on_body_exited)

	func _valid_triangle(points: Array[Vector2]) -> Array[Vector2]:
		var result := points.duplicate()
		if result.size() >= 3 and absf(_triangle_area(result[0], result[1], result[2])) >= 72.0:
			return [
				result[0],
				result[1],
				result[2],
			]
		var center: Vector2 = result[0] if not result.is_empty() else Vector2.ZERO
		var radius: float = Constants.ESCORPION_QUICKSAND_RADIUS
		return [
			center + Vector2.UP * radius,
			center + Vector2(-0.86, 0.5) * radius,
			center + Vector2(0.86, 0.5) * radius,
		]

	func _triangle_area(a: Vector2, b: Vector2, c: Vector2) -> float:
		return (b - a).cross(c - a) * 0.5

	func _process(delta: float) -> void:
		if GameManager.is_trap_lifetime_active():
			_lifetime -= delta
		if _lifetime <= 0.0:
			queue_free()
			return
		if not GameManager.is_trap_interaction_active():
			queue_redraw()
			return
		_refresh_bodies_inside()
		for body: Node in _bodies_inside.keys():
			if not is_instance_valid(body) or not body is BaseCharacter:
				continue
			var character := body as BaseCharacter
			if not _can_affect_character(character):
				continue
			_apply_quicksand_pull(character, delta)
		queue_redraw()

	func _on_body_entered(body: Node2D) -> void:
		if body is BaseCharacter:
			_track_character(body as BaseCharacter)

	func _on_body_exited(body: Node2D) -> void:
		_bodies_inside.erase(body)

	func _refresh_bodies_inside() -> void:
		var expired: Array[Node] = []
		for body: Node in _bodies_inside.keys():
			if not is_instance_valid(body) or not body is BaseCharacter:
				expired.append(body)
				continue
			var character := body as BaseCharacter
			if not _point_is_inside(character.global_position):
				expired.append(body)
		for body in expired:
			_bodies_inside.erase(body)

		var tree := get_tree()
		if tree == null:
			return
		for node: Node in tree.get_nodes_in_group("characters"):
			if not node is BaseCharacter:
				continue
			var character := node as BaseCharacter
			if _point_is_inside(character.global_position):
				_track_character(character)

	func _point_is_inside(point: Vector2) -> bool:
		var polygon := PackedVector2Array()
		for triangle_point in _points:
			polygon.append(triangle_point)
		return Geometry2D.is_point_in_polygon(point, polygon)

	func _track_character(character: BaseCharacter) -> void:
		if character in _bodies_inside:
			return
		if not _can_affect_character(character):
			return
		GameManager.register_trap_contact(character.player_index, int(get_meta("owner_player_index", -1)))
		if character is Escapist and (character as Escapist).is_effect_immune():
			return
		if character is Escapist:
			(character as Escapist).notify_trap_status("HUNDIENDOSE", Color(1.0, 0.8, 0.25), 0.8)
		AudioManager.play_effect(&"QuicksandTrap")
		_bodies_inside[character] = {
			"angle": (character.global_position - global_position).angle(),
			"move_dir": Vector2.ZERO,
			"escape_control": 0.0,
		}

	func _can_affect_character(character: BaseCharacter) -> bool:
		if character.team == owner_team:
			return false
		if character.movement == null:
			return false
		if character is Escapist:
			var esc := character as Escapist
			if esc.is_dead or esc.has_scored or esc.is_effect_immune():
				return false
		return true

	func _apply_quicksand_pull(character: BaseCharacter, delta: float) -> void:
		var to_center := global_position - character.global_position
		var dist := to_center.length()
		if dist < Constants.ESCORPION_QUICKSAND_KILL_RADIUS:
			if character is Escapist:
				(character as Escapist).kill()
			return
		var state := _bodies_inside[character] as Dictionary
		var current_angle := (character.global_position - global_position).angle()
		var prev_angle: float = state.get("angle", current_angle) as float
		var angular_diff := absf(angle_difference(prev_angle, current_angle))
		var move_dir := _get_character_move_direction(character)
		var prev_move_dir: Vector2 = state.get("move_dir", Vector2.ZERO) as Vector2
		var direction_change := 0.0
		if move_dir.length_squared() > 0.01 and prev_move_dir.length_squared() > 0.01:
			direction_change = clampf((1.0 - move_dir.dot(prev_move_dir)) * 0.5, 0.0, 1.0)
		var angular_escape := clampf(angular_diff * 18.0, 0.0, 1.0)
		var control_gain := maxf(direction_change, angular_escape)
		var escape_control: float = state.get("escape_control", 0.0) as float
		escape_control = clampf(
			escape_control + control_gain * delta * 3.0 - (1.0 - control_gain) * delta * 0.9,
			0.0,
			1.0
		)
		state["angle"] = current_angle
		if move_dir.length_squared() > 0.01:
			state["move_dir"] = move_dir
		state["escape_control"] = escape_control

		var escape_factor := lerpf(1.55, 0.62, escape_control)
		var pull_dir := to_center.normalized()
		var base_speed := maxf(character.movement.move_speed, 1.0)
		var current_speed := character.movement.velocity.length()
		var speed_factor := clampf(current_speed / base_speed, 0.0, 1.5)
		var depth_factor := 1.0 - clampf(dist / Constants.ESCORPION_QUICKSAND_RADIUS, 0.0, 1.0)
		var target_pull_speed := (
			Constants.ESCORPION_QUICKSAND_PULL
			* escape_factor
			* lerpf(1.2, 1.75, speed_factor)
			* lerpf(1.05, 1.35, depth_factor)
		)
		character.movement.apply_vortex_pull(
			pull_dir,
			target_pull_speed,
			Constants.ESCORPION_QUICKSAND_PULL * 80.0,
			Constants.ESCORPION_QUICKSAND_PULL * 3.0,
			delta
		)
		var swirl_dir := pull_dir.rotated(PI / 2.0)
		character.movement.apply_vortex_pull(
			swirl_dir,
			Constants.ESCORPION_QUICKSAND_PULL * lerpf(0.9, 0.45, depth_factor),
			Constants.ESCORPION_QUICKSAND_PULL * 60.0,
			0.0,
			delta
		)

	func _get_character_move_direction(character: BaseCharacter) -> Vector2:
		var velocity := character.movement.velocity
		if velocity.length_squared() <= 64.0:
			velocity = character.velocity
		if velocity.length_squared() <= 64.0:
			return Vector2.ZERO
		return velocity.normalized()

	func _draw() -> void:
		var local_points := PackedVector2Array()
		for point in _points:
			local_points.append(point - global_position)
		var pulse := 0.72 + 0.28 * sin(Time.get_ticks_msec() / 360.0)
		draw_colored_polygon(local_points, Color(_color, 0.13 * pulse))
		for i in local_points.size():
			draw_line(local_points[i], local_points[(i + 1) % local_points.size()],
				Color(_color, 0.48), 2.0)
		for i in 14:
			var ratio := float(i) / 13.0
			var angle := ratio * TAU * 2.2 + Time.get_ticks_msec() / 720.0
			var dist := Constants.ESCORPION_QUICKSAND_RADIUS * ratio * 0.72
			var point := Vector2.from_angle(angle) * dist
			if Geometry2D.is_point_in_polygon(global_position + point, PackedVector2Array(_points)):
				draw_circle(point, 1.5 + ratio * 1.6, Color(_color, 0.22 + 0.18 * (1.0 - ratio)))
		draw_circle(Vector2.ZERO, Constants.ESCORPION_QUICKSAND_KILL_RADIUS + 2.0,
			Color(1.0, 0.2, 0.1, 0.35 + 0.10 * pulse))
