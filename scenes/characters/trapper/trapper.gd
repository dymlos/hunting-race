class_name Trapper
extends BaseCharacter

var _active_traps: Array[Trap] = []
var _trap_cooldown: float = 0.0


func _setup_role() -> void:
	role = Enums.Role.TRAPPER
	movement.move_speed = Constants.SPEED_TRAPPER


func _handle_ability_input(delta: float) -> void:
	if _trap_cooldown > 0.0:
		_trap_cooldown -= delta

	if InputManager.is_action_just_pressed(player_index, &"ability") and _trap_cooldown <= 0.0:
		if _active_traps.size() < Constants.TRAP_MAX_ACTIVE:
			_place_trap()


func _place_trap() -> void:
	var trap := Trap.new()
	trap.setup(team, global_position)
	trap.destroyed.connect(_on_trap_destroyed.bind(trap))
	# Add to arena (parent of characters' parent)
	get_parent().get_parent().add_child(trap)
	_active_traps.append(trap)
	_trap_cooldown = Constants.TRAP_COOLDOWN
	_update_speed_bonus()


func _on_trap_destroyed(trap: Trap) -> void:
	_active_traps.erase(trap)
	_update_speed_bonus()


func _update_speed_bonus() -> void:
	var bonus := _active_traps.size() * Constants.TRAPPER_SPEED_BONUS_PER_TRAP
	movement.move_speed = Constants.SPEED_TRAPPER + bonus


func _draw() -> void:
	# Square shape for Trapper
	var r := Constants.CHARACTER_RADIUS
	var pts := PackedVector2Array([
		Vector2(-r, -r), Vector2(r, -r),
		Vector2(r, r), Vector2(-r, r),
	])
	draw_colored_polygon(pts, player_color)

	# Direction line
	var tip := aim_direction * (r + 10.0)
	draw_line(Vector2.ZERO, tip, player_color, 2.0)

	# Trap count indicator
	var trap_text := "%d/%d" % [_active_traps.size(), Constants.TRAP_MAX_ACTIVE]
	draw_string(ThemeDB.fallback_font, Vector2(-10, r + 24),
		trap_text, HORIZONTAL_ALIGNMENT_CENTER, -1, 8, Color(0.8, 0.8, 0.8))

	# Cooldown indicator
	if _trap_cooldown > 0.0:
		var ratio := _trap_cooldown / Constants.TRAP_COOLDOWN
		draw_arc(Vector2.ZERO, r + 4.0, -PI / 2.0, -PI / 2.0 + TAU * (1.0 - ratio),
			12, Color(1.0, 1.0, 1.0, 0.3), 2.0)

	# Label
	var label := "P%d" % (player_index + 1)
	if player_index >= 100:
		label = "BOT"
	draw_string(ThemeDB.fallback_font, Vector2(-10, -r - 6),
		label, HORIZONTAL_ALIGNMENT_CENTER, -1, 10, player_color)
	draw_string(ThemeDB.fallback_font, Vector2(-10, r + 14),
		"TRAP", HORIZONTAL_ALIGNMENT_CENTER, -1, 8, player_color)
