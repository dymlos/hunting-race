class_name Escapist
extends BaseCharacter

var hurtbox: HurtboxComponent


func _setup_role() -> void:
	role = Enums.Role.ESCAPIST
	movement.move_speed = Constants.SPEED_ESCAPIST

	# Hurtbox — vulnerable to Predator attacks
	hurtbox = HurtboxComponent.new()
	hurtbox.setup(self, team)
	add_child(hurtbox)


func _draw() -> void:
	# Smaller, distinct circle with speed lines
	draw_circle(Vector2.ZERO, Constants.CHARACTER_RADIUS - 2.0, player_color)

	# Inner ring for visual distinction
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
