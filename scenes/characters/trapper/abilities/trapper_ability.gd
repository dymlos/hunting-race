class_name TrapperAbility
extends RefCounted

## Base class for trapper character abilities. Each ability handles its own
## placement logic, cooldown, active object tracking, and drawing.

var trapper: Trapper
var cooldown: float = 0.0
var max_active: int = 1
var _cooldown_remaining: float = 0.0
var _active_objects: Array[Node2D] = []

# Multi-point placement
var points_required: int = 1
var max_point_distance: float = 0.0  # 0 = unlimited
var _placement_points: Array[Vector2] = []
var is_placing: bool = false


func setup(p_trapper: Trapper) -> void:
	trapper = p_trapper


func can_activate() -> bool:
	if _cooldown_remaining > 0.0:
		return false
	if _active_objects.size() >= max_active:
		return false
	return true


func activate() -> void:
	## Called when the player presses this ability's button.
	## For multi-point abilities, this is called once per point.
	if not can_activate() and not is_placing:
		return

	if points_required <= 1:
		_spawn_object(trapper.global_position)
		_cooldown_remaining = cooldown
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

		_placement_points.append(pos)
		if _placement_points.size() >= points_required:
			_spawn_from_points(_placement_points.duplicate())
			_placement_points.clear()
			is_placing = false
			_cooldown_remaining = cooldown


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
