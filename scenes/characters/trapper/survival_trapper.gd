class_name SurvivalTrapper
extends BaseCharacter

var trapper_character: Enums.TrapperCharacter = Enums.TrapperCharacter.ARANA


func _setup_role() -> void:
	role = Enums.Role.TRAPPER
	var speed_mult: float = GameManager.settings_overrides.get(&"trapper_speed", 1.0) as float
	movement.move_speed = Constants.SPEED_ESCAPIST * 0.96 * speed_mult


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
