class_name Escapist
extends BaseCharacter

signal died(escapist: Escapist)
signal scored(escapist: Escapist)

var is_dead: bool = false
var has_scored: bool = false


func _setup_role() -> void:
	role = Enums.Role.ESCAPIST
	movement.move_speed = Constants.SPEED_ESCAPIST


func kill() -> void:
	if is_dead or has_scored:
		return
	is_dead = true
	input_locked = true
	movement.freeze()
	visible = false
	died.emit(self)


func score() -> void:
	if is_dead or has_scored:
		return
	has_scored = true
	input_locked = true
	movement.freeze()
	visible = false
	scored.emit(self)


func _draw() -> void:
	# Circle with ring
	draw_circle(Vector2.ZERO, Constants.CHARACTER_RADIUS - 2.0, player_color)
	draw_arc(Vector2.ZERO, Constants.CHARACTER_RADIUS + 2.0, 0, TAU, 16,
		player_color, 1.5)

	# Direction indicator
	var tip := aim_direction * (Constants.CHARACTER_RADIUS + 8.0)
	draw_line(Vector2.ZERO, tip, player_color, 2.0)

	# Label
	var label := "P%d" % (player_index + 1)
	if player_index >= 100:
		label = "BOT"
	draw_string(ThemeDB.fallback_font, Vector2(-10, -Constants.CHARACTER_RADIUS - 6),
		label, HORIZONTAL_ALIGNMENT_CENTER, -1, 10, player_color)
	draw_string(ThemeDB.fallback_font, Vector2(-10, Constants.CHARACTER_RADIUS + 14),
		"ESC", HORIZONTAL_ALIGNMENT_CENTER, -1, 8, player_color)
