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
var _active_objects: Array[Node2D] = []
var _charges_remaining: int = 1
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
		if not _consume_use():
			return
		_spawn_object(trapper.global_position)
		AudioManager.play_skill(StringName(get_display_name()))
		_start_cooldown_if_needed()
	else:
		# Multi-point placement
		if not is_placing:
			is_placing = true
			_placement_points.clear()

		var pos := trapper.global_position

		# Enforce max distance from previous point
		if max_point_distance > 0.0 and not _placement_points.is_empty():
			var prev: Vector2 = _placement_points.back()
			if pos.distance_to(prev) > max_point_distance:
				return  # Too far — don't place this point

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
			AudioManager.play_skill(StringName(get_display_name()))
			_start_cooldown_if_needed()


func cancel_placement() -> void:
	## Cancel mid-placement (B button).
	_placement_points.clear()
	is_placing = false


func update(delta: float) -> void:
	if _cooldown_remaining > 0.0:
		_cooldown_remaining -= delta

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
	trapper.get_parent().add_child(obj)


func reset_round_uses() -> void:
	_charges_remaining = max_charges
	_strategy_uses_remaining = 1
	_strategy_uses_spent = 0
	_cooldown_remaining = 0.0
	_placement_points.clear()
	is_placing = false


func _get_available_uses() -> int:
	if GameManager.current_state == Enums.GameState.HUNT:
		return _strategy_uses_remaining
	if GameManager.current_state == Enums.GameState.ESCAPE:
		return _charges_remaining
	return 0


func _consume_use() -> bool:
	if GameManager.current_state == Enums.GameState.HUNT:
		if _strategy_uses_remaining <= 0:
			return false
		_strategy_uses_remaining -= 1
		_strategy_uses_spent += 1
		return true
	if GameManager.current_state == Enums.GameState.ESCAPE:
		if _charges_remaining <= 0:
			return false
		_charges_remaining -= 1
		escape_charge_used.emit(self)
		return true
	return false


func _start_cooldown_if_needed() -> void:
	if GameManager.current_state == Enums.GameState.ESCAPE:
		_cooldown_remaining = cooldown
	else:
		_cooldown_remaining = 0.0


func _get_active_limit() -> int:
	return max_active + _strategy_uses_spent


func get_display_name() -> String:
	return "Ability"


func get_display_color() -> Color:
	return Color.WHITE


func get_cooldown_ratio() -> float:
	if cooldown <= 0.0:
		return 0.0
	return clampf(_cooldown_remaining / cooldown, 0.0, 1.0)


func get_active_count() -> int:
	return _active_objects.size()


func get_charges_remaining() -> int:
	return _charges_remaining


func get_strategy_uses_remaining() -> int:
	return _strategy_uses_remaining


func refill_charges() -> void:
	_charges_remaining = max_charges
	_cooldown_remaining = 0.0


func is_placement_valid(cursor_pos: Vector2) -> bool:
	## Whether the cursor is within valid distance of the last placed point.
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
