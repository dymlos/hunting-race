class_name TrapperAbility
extends RefCounted

signal escape_charge_used(ability: TrapperAbility)

## Base class for trapper character abilities. Each ability handles its own
## placement logic, cooldown, active object tracking, and drawing.

var trapper: Trapper
var cooldown: float = 0.0
var max_active: int = 1
var max_charges: int = 1
var _cooldown_remaining: float = 0.0
var _cooldown_denied_timer: float = 0.0
var _active_objects: Array[Node2D] = []
var _charges_remaining: int = 1
var _queued_recharges: int = 0
var _strategy_uses_remaining: int = 1
var _strategy_uses_spent: int = 0

# Multi-point placement
var points_required: int = 1
var max_point_distance: float = 0.0  # 0 = unlimited
var _placement_points: Array[Vector2] = []
var is_placing: bool = false


func setup(p_trapper: Trapper) -> void:
	trapper = p_trapper
	reset_round_uses()


func can_activate() -> bool:
	if _skills_cooldowns_enabled():
		if _cooldown_remaining > 0.0:
			return false
		if _get_available_uses() <= 0:
			return false
		if _active_objects.size() >= _get_active_limit():
			return false
	return true


func activate() -> void:
	## Called when the player presses this ability's button.
	## For multi-point abilities, this is called once per point.
	if not can_activate() and not is_placing:
		return

	if points_required <= 1:
		if not _is_placement_safe(trapper.global_position):
			return
		if not _consume_use():
			return
		_spawn_object(trapper.global_position)
		_start_cooldown_if_needed()
	else:
		# Multi-point placement
		if not is_placing:
			is_placing = true
			_placement_points.clear()

		var pos := trapper.global_position
		if not _is_placement_safe(pos):
			return

		# Enforce max distance from previous point
		if max_point_distance > 0.0 and not _placement_points.is_empty():
			var prev: Vector2 = _placement_points.back()
			if pos.distance_to(prev) > max_point_distance:
				return  # Too far — don't place this point

		if not _is_placement_segment_safe(pos):
			return

		if _placement_points.size() + 1 >= points_required and _get_available_uses() <= 0:
			return
		_placement_points.append(pos)
		if _placement_points.size() >= points_required:
			if not _consume_use():
				_placement_points.pop_back()
				return
			_spawn_from_points(_placement_points.duplicate())
			_placement_points.clear()
			is_placing = false
			_start_cooldown_if_needed()


func cancel_placement() -> void:
	## Cancel mid-placement.
	_placement_points.clear()
	is_placing = false


func update(delta: float) -> void:
	if not _skills_cooldowns_enabled():
		_cooldown_remaining = 0.0
		_charges_remaining = max_charges
		_queued_recharges = 0
	if _cooldown_remaining > 0.0:
		_cooldown_remaining -= delta
		if _cooldown_remaining <= 0.0:
			_complete_recharge_step()
	if _cooldown_denied_timer > 0.0:
		_cooldown_denied_timer -= delta

	# Clean up destroyed objects
	var i := _active_objects.size() - 1
	while i >= 0:
		if not is_instance_valid(_active_objects[i]) or _active_objects[i].is_queued_for_deletion():
			_active_objects.remove_at(i)
		i -= 1


func _spawn_object(_pos: Vector2) -> void:
	## Override in subclass for single-point abilities.
	pass


func _spawn_from_points(_points: Array[Vector2]) -> void:
	## Override in subclass for multi-point abilities.
	pass


func _register_object(obj: Node2D) -> void:
	## Add an object to the active list and to the scene tree.
	_active_objects.append(obj)
	obj.set_meta("owner_player_index", trapper.player_index)
	if trapper.has_meta("skill_test_id"):
		obj.set_meta("skill_test_id", trapper.get_meta("skill_test_id"))
	trapper.get_parent().add_child(obj)


func reset_round_uses() -> void:
	_charges_remaining = max_charges
	_queued_recharges = 0
	_strategy_uses_remaining = 1
	_strategy_uses_spent = 0
	_cooldown_remaining = 0.0
	_placement_points.clear()
	is_placing = false


func _get_available_uses() -> int:
	if GameManager.current_state == Enums.GameState.HUNT:
		return _strategy_uses_remaining
	if GameManager.current_state == Enums.GameState.ESCAPE \
			or GameManager.current_state == Enums.GameState.PRACTICE \
			or _is_skill_test_context():
		if not _skills_cooldowns_enabled():
			return max_charges
		return _charges_remaining
	return 0


func _consume_use() -> bool:
	if GameManager.current_state == Enums.GameState.HUNT:
		if _strategy_uses_remaining <= 0:
			return false
		_strategy_uses_remaining -= 1
		_strategy_uses_spent += 1
		return true
	if GameManager.current_state == Enums.GameState.PRACTICE \
			or GameManager.current_state == Enums.GameState.ESCAPE \
			or _is_skill_test_context():
		if _skills_cooldowns_enabled():
			if _charges_remaining <= 0:
				return false
			_charges_remaining -= 1
			_queued_recharges = mini(_queued_recharges + 1, max_charges)
			escape_charge_used.emit(self)
		return true
	return false


func _start_cooldown_if_needed() -> void:
	if _skills_cooldowns_enabled() and (
			GameManager.current_state == Enums.GameState.ESCAPE \
			or GameManager.current_state == Enums.GameState.PRACTICE \
			or _is_skill_test_context()):
		if _queued_recharges > 0 and _cooldown_remaining <= 0.0:
			_cooldown_remaining = cooldown
	else:
		_cooldown_remaining = 0.0


func _get_active_limit() -> int:
	return max_active + _strategy_uses_spent


func get_display_name() -> String:
	return "Habilidad"


func get_display_color() -> Color:
	return Color.WHITE


func get_cooldown_remaining() -> float:
	return maxf(_cooldown_remaining, 0.0)


func get_cooldown_ratio() -> float:
	if cooldown <= 0.0:
		return 0.0
	return clampf(_cooldown_remaining / cooldown, 0.0, 1.0)


func get_cooldown_denied_ratio() -> float:
	if _cooldown_denied_timer <= 0.0:
		return 0.0
	return clampf(_cooldown_denied_timer / 0.3, 0.0, 1.0)


func get_active_count() -> int:
	return _active_objects.size()


func get_charges_remaining() -> int:
	if not _skills_cooldowns_enabled():
		return max_charges
	return _charges_remaining


func get_strategy_uses_remaining() -> int:
	return _strategy_uses_remaining


func refill_charges() -> void:
	_charges_remaining = max_charges
	_queued_recharges = 0
	_cooldown_remaining = 0.0
	_cooldown_denied_timer = 0.0


func notify_cooldown_denied() -> void:
	_cooldown_denied_timer = 0.3
	AudioManager.play_effect(&"CooldownDenied")


func _skills_cooldowns_enabled() -> bool:
	return GameManager.settings_overrides.get(&"skill_cooldowns_enabled", true) as bool


func _is_skill_test_context() -> bool:
	return trapper != null and is_instance_valid(trapper) and trapper.has_meta("skill_test_id")


func is_placement_valid(cursor_pos: Vector2) -> bool:
	## Whether the cursor is within valid distance of the last placed point.
	if not _is_placement_safe(cursor_pos):
		return false
	if not _is_placement_segment_safe(cursor_pos):
		return false
	if max_point_distance <= 0.0:
		return true
	if _placement_points.is_empty():
		return true
	return cursor_pos.distance_to(_placement_points.back() as Vector2) <= max_point_distance


func draw_preview(trapper_node: Trapper) -> void:
	## Draw placement preview on the trapper's canvas. Called from trapper._draw().
	if not is_placing or _placement_points.is_empty():
		return
	var valid := is_placement_valid(trapper_node.global_position)
	var color := get_display_color() if valid else Color(get_display_color(), 0.2)
	# Draw placed points
	for pt: Vector2 in _placement_points:
		var local := pt - trapper_node.global_position
		trapper_node.draw_circle(local, 4.0, get_display_color())
	# Draw line from last point to cursor with validity color
	var last_local: Vector2 = (_placement_points.back() as Vector2) - trapper_node.global_position
	trapper_node.draw_line(last_local, Vector2.ZERO, color, 1.5)
	# Draw max range circle around last point
	if max_point_distance > 0.0:
		trapper_node.draw_arc(last_local, max_point_distance, 0, TAU, 24,
			Color(color, 0.15), 1.0)


func _is_placement_safe(pos: Vector2) -> bool:
	if not _should_protect_moving_escapists():
		return true
	return not _is_near_moving_enemy_escapist(pos)


func _is_placement_segment_safe(pos: Vector2) -> bool:
	if not _should_protect_moving_escapists():
		return true
	if _placement_points.is_empty():
		return true
	var previous: Vector2 = _placement_points.back()
	for node: Node in trapper.get_tree().get_nodes_in_group("characters"):
		if not node is Escapist:
			continue
		var esc := node as Escapist
		if not _shares_skill_test_scope(esc):
			continue
		if not _is_enemy_escapist_placement_blocker(esc):
			continue
		var distance := _distance_point_to_segment(esc.global_position, previous, pos)
		if distance < Constants.TRAPPER_MOVING_ESCAPIST_PLACE_MIN_DISTANCE:
			return false
	return true


func _should_protect_moving_escapists() -> bool:
	return GameManager.current_state == Enums.GameState.HUNT \
		or GameManager.current_state == Enums.GameState.ESCAPE \
		or GameManager.current_state == Enums.GameState.PRACTICE \
		or _is_skill_test_context()


func _is_near_moving_enemy_escapist(pos: Vector2) -> bool:
	for node: Node in trapper.get_tree().get_nodes_in_group("characters"):
		if not node is Escapist:
			continue
		var esc := node as Escapist
		if not _shares_skill_test_scope(esc):
			continue
		if not _is_enemy_escapist_placement_blocker(esc):
			continue
		if esc.global_position.distance_to(pos) < Constants.TRAPPER_MOVING_ESCAPIST_PLACE_MIN_DISTANCE:
			return true
	return false


func _is_moving_enemy_escapist(esc: Escapist) -> bool:
	if esc.team == trapper.team or esc.is_dead or esc.has_scored:
		return false
	var speed := esc.velocity.length()
	if esc.movement != null:
		speed = maxf(speed, esc.movement.velocity.length())
	return speed >= Constants.TRAPPER_MOVING_ESCAPIST_SPEED_THRESHOLD


func _is_enemy_escapist_placement_blocker(esc: Escapist) -> bool:
	if esc.team == trapper.team or esc.is_dead or esc.has_scored:
		return false
	return true


func _shares_skill_test_scope(node: Node) -> bool:
	var own_scope := ""
	if trapper != null and is_instance_valid(trapper) and trapper.has_meta("skill_test_id"):
		own_scope = str(trapper.get_meta("skill_test_id"))
	var other_scope := ""
	if node.has_meta("skill_test_id"):
		other_scope = str(node.get_meta("skill_test_id"))
	if own_scope.is_empty() and other_scope.is_empty():
		return true
	return own_scope == other_scope


func _distance_point_to_segment(point: Vector2, a: Vector2, b: Vector2) -> float:
	var segment := b - a
	var length_sq := segment.length_squared()
	if length_sq <= 0.01:
		return point.distance_to(a)
	var t := clampf((point - a).dot(segment) / length_sq, 0.0, 1.0)
	return point.distance_to(a + segment * t)


func _complete_recharge_step() -> void:
	if _queued_recharges <= 0:
		_cooldown_remaining = 0.0
		return
	_queued_recharges -= 1
	_charges_remaining = mini(_charges_remaining + 1, max_charges)
	if trapper != null and is_instance_valid(trapper):
		trapper.notify_ability_recharged(get_display_color())
	if _queued_recharges > 0:
		_cooldown_remaining = cooldown
	else:
		_cooldown_remaining = 0.0
