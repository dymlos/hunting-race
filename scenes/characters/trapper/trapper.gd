class_name Trapper
extends Node2D

## Trapper cursor — non-physical entity that moves freely and places traps.

var player_index: int = 0
var team: Enums.Team = Enums.Team.NONE
var role: Enums.Role = Enums.Role.TRAPPER
var player_color: Color = Color.WHITE
var input_locked: bool = true

var _active_traps: Array[Trap] = []
var _slow_trap_cooldown: float = 0.0
var _lethal_trap_cooldown: float = 0.0
var _map_bounds: Rect2 = Rect2()


func setup(map_size: Vector2) -> void:
	_map_bounds = Rect2(Vector2.ZERO, map_size)


func get_role() -> Enums.Role:
	return Enums.Role.TRAPPER


func get_team() -> Enums.Team:
	return team


func freeze_character() -> void:
	input_locked = true


func unfreeze_character() -> void:
	input_locked = false


func _process(delta: float) -> void:
	if input_locked or player_index >= 100:
		queue_redraw()
		return

	# Move cursor with left stick
	var move_vec := InputManager.get_move_vector(player_index)
	position += move_vec * Constants.TRAPPER_CURSOR_SPEED * delta
	# Clamp to map bounds
	position.x = clampf(position.x, _map_bounds.position.x, _map_bounds.end.x)
	position.y = clampf(position.y, _map_bounds.position.y, _map_bounds.end.y)

	# Slow trap — RB
	if _slow_trap_cooldown > 0.0:
		_slow_trap_cooldown -= delta
	if InputManager.is_action_just_pressed(player_index, &"ability") and _slow_trap_cooldown <= 0.0:
		if _active_traps.size() < Constants.TRAP_MAX_ACTIVE:
			_place_trap(false)

	# Lethal trap — A
	if _lethal_trap_cooldown > 0.0:
		_lethal_trap_cooldown -= delta
	if InputManager.is_action_just_pressed(player_index, &"dash") and _lethal_trap_cooldown <= 0.0:
		if _active_traps.size() < Constants.TRAP_MAX_ACTIVE:
			_place_trap(true)

	queue_redraw()


func _place_trap(lethal: bool) -> void:
	var trap := Trap.new()
	trap.setup(team, global_position, lethal)
	trap.destroyed.connect(_on_trap_destroyed)
	get_parent().add_child(trap)
	_active_traps.append(trap)
	if lethal:
		_lethal_trap_cooldown = Constants.TRAP_LETHAL_COOLDOWN
	else:
		_slow_trap_cooldown = Constants.TRAP_COOLDOWN


func _on_trap_destroyed(trap: Trap) -> void:
	_active_traps.erase(trap)


func _draw() -> void:
	# Crosshair cursor
	var size := 12.0
	var color := Color(player_color, 0.8)
	draw_line(Vector2(-size, 0), Vector2(size, 0), color, 2.0)
	draw_line(Vector2(0, -size), Vector2(0, size), color, 2.0)
	draw_arc(Vector2.ZERO, size * 0.7, 0, TAU, 12, color, 1.5)

	# Player label
	var label := "P%d" % (player_index + 1)
	if player_index >= 100:
		label = "BOT"
	draw_string(ThemeDB.fallback_font, Vector2(-10, -size - 4),
		label, HORIZONTAL_ALIGNMENT_CENTER, -1, 10, color)

	# Trap count
	var trap_text := "%d/%d" % [_active_traps.size(), Constants.TRAP_MAX_ACTIVE]
	draw_string(ThemeDB.fallback_font, Vector2(-10, size + 14),
		trap_text, HORIZONTAL_ALIGNMENT_CENTER, -1, 8, Color(0.8, 0.8, 0.8))

	# Cooldown indicators
	if _slow_trap_cooldown > 0.0:
		var ratio := _slow_trap_cooldown / Constants.TRAP_COOLDOWN
		draw_arc(Vector2.ZERO, size + 4.0, -PI / 2.0, -PI / 2.0 + TAU * (1.0 - ratio),
			12, Color(0.5, 0.5, 1.0, 0.4), 2.0)
	if _lethal_trap_cooldown > 0.0:
		var ratio := _lethal_trap_cooldown / Constants.TRAP_LETHAL_COOLDOWN
		draw_arc(Vector2.ZERO, size + 8.0, -PI / 2.0, -PI / 2.0 + TAU * (1.0 - ratio),
			12, Color(1.0, 0.3, 0.3, 0.4), 2.0)
