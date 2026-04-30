class_name SurvivalZombie
extends CharacterBody2D

signal escapist_caught(escapist: Escapist, zombie: Node)

var zombie_index: int = 0
var move_speed: float = Constants.SURVIVAL_ZOMBIE_SPEED

var _active: bool = true
var _wander_direction: Vector2 = Vector2.RIGHT
var _attached_escapist: Escapist = null
var _attach_offset: Vector2 = Vector2.ZERO
var _grab_elapsed: float = 0.0
var _release_cooldown: float = 0.0
var _collision_layer_default: int = 0
var _collision_mask_default: int = 0


func setup(index: int, spawn_position: Vector2, speed: float) -> void:
	zombie_index = index
	global_position = spawn_position
	move_speed = speed
	_wander_direction = Vector2.from_angle(randf() * TAU)
	if _wander_direction.length_squared() <= 0.01:
		_wander_direction = Vector2.RIGHT


func _ready() -> void:
	add_to_group("survival_zombies")
	collision_layer = Constants.LAYER_CHARACTERS
	collision_mask = Constants.LAYER_WALLS | Constants.LAYER_CHARACTERS
	_collision_layer_default = collision_layer
	_collision_mask_default = collision_mask
	z_index = 6

	var shape := CircleShape2D.new()
	shape.radius = Constants.CHARACTER_RADIUS * 0.86
	var collision := CollisionShape2D.new()
	collision.shape = shape
	add_child(collision)


func set_active(value: bool) -> void:
	_active = value
	if not _active:
		velocity = Vector2.ZERO
	set_physics_process(_active)
	queue_redraw()


func release_if_attached_to(escapist: Escapist) -> void:
	if _attached_escapist == escapist:
		_release_from_escapist(0.45)


func _physics_process(delta: float) -> void:
	if _release_cooldown > 0.0:
		_release_cooldown = maxf(_release_cooldown - delta, 0.0)
	if not _active:
		return
	if _attached_escapist != null:
		_update_attached(delta)
		return

	var target := _find_nearest_escapist()
	var move_direction := _wander_direction
	if target != null:
		var to_target := target.global_position - global_position
		if to_target.length_squared() > 0.01:
			move_direction = to_target.normalized()
	else:
		_wander_direction = _wander_direction.rotated(sin(Time.get_ticks_msec() / 380.0) * 0.018)

	velocity = move_direction * move_speed
	move_and_slide()
	_check_grab_contacts()
	queue_redraw()


func _update_attached(delta: float) -> void:
	if not is_instance_valid(_attached_escapist) \
			or _attached_escapist.is_dead \
			or _attached_escapist.has_scored:
		_release_from_escapist(0.6)
		return
	if _attached_escapist.movement and _attached_escapist.movement.is_airborne_dashing:
		_release_from_escapist(0.8)
		return

	global_position = _attached_escapist.global_position + _attach_offset
	velocity = Vector2.ZERO

	if _is_touching_wall_or_trapper() or _is_touching_loose_zombie():
		_release_from_escapist(0.8)
		return

	_grab_elapsed += delta
	var attached_count := _get_attached_count_for_escapist(_attached_escapist)
	var kill_time := maxf(
		Constants.SURVIVAL_ZOMBIE_MIN_GRAB_DURATION,
		Constants.SURVIVAL_ZOMBIE_GRAB_DURATION - float(maxi(attached_count - 1, 0))
	)
	if _grab_elapsed >= kill_time:
		escapist_caught.emit(_attached_escapist, self)
		_release_from_escapist(0.9)
		return
	queue_redraw()


func _find_nearest_escapist() -> Escapist:
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
		var dist_sq := global_position.distance_squared_to(esc.global_position)
		if dist_sq < best_dist_sq:
			best_dist_sq = dist_sq
			best = esc
	return best


func _check_grab_contacts() -> void:
	if _release_cooldown > 0.0:
		return
	var tree := get_tree()
	if tree == null:
		return
	for node: Node in tree.get_nodes_in_group("characters"):
		if not node is Escapist:
			continue
		var esc := node as Escapist
		if esc.is_dead or esc.has_scored or esc.is_effect_immune():
			continue
		if global_position.distance_to(esc.global_position) > Constants.SURVIVAL_ZOMBIE_GRAB_RADIUS:
			continue
		esc.notify_trap_contact()
		if esc.is_effect_immune():
			return
		_attach_to_escapist(esc)
		return


func _attach_to_escapist(escapist: Escapist) -> void:
	_attached_escapist = escapist
	_grab_elapsed = 0.0
	var away := global_position - escapist.global_position
	if away.length_squared() <= 0.01:
		away = Vector2.from_angle(randf() * TAU)
	_attach_offset = away.normalized() * (Constants.CHARACTER_RADIUS + 9.0)
	collision_layer = 0
	collision_mask = 0
	z_index = 9
	escapist.notify_trap_status("AGARRE", Color(0.65, 1.0, 0.42), 0.75)
	queue_redraw()


func _release_from_escapist(cooldown: float) -> void:
	_attached_escapist = null
	_grab_elapsed = 0.0
	_release_cooldown = cooldown
	collision_layer = _collision_layer_default
	collision_mask = _collision_mask_default
	z_index = 6
	queue_redraw()


func _is_touching_wall_or_trapper() -> bool:
	if _is_touching_wall():
		return true
	var tree := get_tree()
	if tree == null:
		return false
	for node: Node in tree.get_nodes_in_group("characters"):
		if node == _attached_escapist:
			continue
		if not node is BaseCharacter:
			continue
		var character := node as BaseCharacter
		if character.role != Enums.Role.TRAPPER:
			continue
		var trapper := character as Node2D
		if global_position.distance_to(trapper.global_position) <= Constants.SURVIVAL_ZOMBIE_RELEASE_CONTACT_RADIUS:
			return true
	return false


func _is_touching_wall() -> bool:
	var world := get_world_2d()
	if world == null:
		return false
	var shape := CircleShape2D.new()
	shape.radius = Constants.CHARACTER_RADIUS * 0.70
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = shape
	query.transform = Transform2D(0.0, global_position)
	query.collision_mask = Constants.LAYER_WALLS
	query.exclude = [get_rid()]
	return not world.direct_space_state.intersect_shape(query, 1).is_empty()


func _is_touching_loose_zombie() -> bool:
	var tree := get_tree()
	if tree == null:
		return false
	for node: Node in tree.get_nodes_in_group("survival_zombies"):
		if node == self or not node is Node2D:
			continue
		if node.has_method("is_attached_to") and node.call("is_attached_to", _attached_escapist):
			continue
		var other := node as Node2D
		if global_position.distance_to(other.global_position) <= Constants.SURVIVAL_ZOMBIE_RELEASE_CONTACT_RADIUS:
			return true
	return false


func is_attached_to(escapist: Escapist) -> bool:
	return _attached_escapist == escapist


func _get_attached_count_for_escapist(escapist: Escapist) -> int:
	var count := 0
	var tree := get_tree()
	if tree == null:
		return 1
	for node: Node in tree.get_nodes_in_group("survival_zombies"):
		if node.has_method("is_attached_to") and node.call("is_attached_to", escapist):
			count += 1
	return maxi(count, 1)


func _draw() -> void:
	var pulse := 0.5 + 0.5 * sin(Time.get_ticks_msec() / 145.0 + float(zombie_index))
	var attached := _attached_escapist != null
	var body_color := Color(0.42, 0.78, 0.36)
	if attached:
		body_color = Color(0.84, 0.92, 0.32)
	var glow_color := Color(body_color, 0.16 + pulse * 0.08)
	var eye_color := Color(0.08, 0.02, 0.02)
	var radius := Constants.CHARACTER_RADIUS * 0.86

	draw_circle(Vector2.ZERO, radius + 8.0, glow_color)
	draw_circle(Vector2(0.0, 5.0), radius * 0.95, Color(0.0, 0.0, 0.0, 0.30))
	draw_circle(Vector2.ZERO, radius, Color(body_color, 0.92))
	draw_arc(Vector2.ZERO, radius + 3.0, 0.0, TAU, 22, Color(0.10, 0.16, 0.10, 0.92), 2.0)
	draw_circle(Vector2(-4.5, -3.0), 2.4, eye_color)
	draw_circle(Vector2(4.5, -3.0), 2.4, eye_color)
	draw_line(Vector2(-5.5, 5.0), Vector2(4.5, 6.0), Color(0.05, 0.08, 0.05), 1.8)

	if attached:
		var attached_count := _get_attached_count_for_escapist(_attached_escapist)
		var kill_time := maxf(
			Constants.SURVIVAL_ZOMBIE_MIN_GRAB_DURATION,
			Constants.SURVIVAL_ZOMBIE_GRAB_DURATION - float(maxi(attached_count - 1, 0))
		)
		var ratio := clampf(_grab_elapsed / kill_time, 0.0, 1.0)
		draw_arc(Vector2.ZERO, radius + 8.0, -PI / 2.0, -PI / 2.0 + TAU * ratio, 28,
			Color(1.0, 0.18, 0.10, 0.92), 3.2)
		var left := maxf(kill_time - _grab_elapsed, 0.0)
		var text := "%.0f" % ceilf(left)
		var text_size := 13
		var text_width := ThemeDB.fallback_font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, text_size).x
		draw_string(ThemeDB.fallback_font, Vector2(-text_width / 2.0 + 1.0, -radius - 10.0 + 1.0),
			text, HORIZONTAL_ALIGNMENT_LEFT, -1, text_size, Color.BLACK)
		draw_string(ThemeDB.fallback_font, Vector2(-text_width / 2.0, -radius - 10.0),
			text, HORIZONTAL_ALIGNMENT_LEFT, -1, text_size, Color(1.0, 0.28, 0.16))
		return

	var label := "Z"
	var label_size := 13
	var label_width := ThemeDB.fallback_font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, label_size).x
	draw_string(ThemeDB.fallback_font, Vector2(-label_width / 2.0 + 1.0, -radius - 8.0 + 1.0),
		label, HORIZONTAL_ALIGNMENT_LEFT, -1, label_size, Color.BLACK)
	draw_string(ThemeDB.fallback_font, Vector2(-label_width / 2.0, -radius - 8.0),
		label, HORIZONTAL_ALIGNMENT_LEFT, -1, label_size, Color(0.64, 1.0, 0.54))
