class_name GameHud
extends Control

## HUD showing scores, round info, escapist count, and current roles.

var input_blocked: bool = false


func _process(_delta: float) -> void:
	if visible:
		queue_redraw()


func _draw() -> void:
	var screen := get_viewport_rect().size
	var font := ThemeDB.fallback_font
	var cx := screen.x / 2.0

	# Score bar at top
	var bar_h := 76.0
	draw_rect(Rect2(0, 0, screen.x, bar_h), Color(0, 0, 0, 0.5))

	if GameManager.current_state == Enums.GameState.PRACTICE:
		_draw_practice_hud(font, screen, bar_h)
		return

	# Round indicator
	var round_text := "Round %d" % GameManager.get_competitive_round_number()
	var leg_text := GameManager.get_round_leg_label()
	var leg_color := Color(0.2, 0.8, 1.0)
	if leg_text == "Hunt Round":
		leg_color = Color(1.0, 0.35, 0.2)
	var round_panel := Rect2(Vector2(12.0, 8.0), Vector2(190.0, 54.0))
	draw_rect(round_panel, Color(0.02, 0.02, 0.02, 0.72))
	draw_rect(round_panel, Color(leg_color, 0.75), false, 2.0)
	draw_string(font, Vector2(24, 28), round_text,
		HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color.WHITE)
	if not leg_text.is_empty():
		draw_string(font, Vector2(24, 50), leg_text,
			HORIZONTAL_ALIGNMENT_LEFT, -1, 14, leg_color)

	# Scores
	var t1c := Enums.team_color(Enums.Team.TEAM_1)
	var t2c := Enums.team_color(Enums.Team.TEAM_2)
	var score_text := "%d - %d" % [GameManager.match_scores[0], GameManager.match_scores[1]]
	var score_panel := Rect2(Vector2(cx - 170.0, 6.0), Vector2(340.0, 62.0))
	draw_rect(score_panel, Color(0.03, 0.03, 0.03, 0.64))
	draw_rect(score_panel, Color(0.65, 0.65, 0.65, 0.4), false, 2.0)
	var blue_name := Enums.team_name(Enums.Team.TEAM_1).to_upper()
	var red_name := Enums.team_name(Enums.Team.TEAM_2).to_upper()
	var red_w := font.get_string_size(red_name, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x
	var score_w := font.get_string_size(score_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 30).x
	draw_string(font, Vector2(score_panel.position.x + 14.0, 24.0),
		blue_name, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, t1c)
	draw_string(font, Vector2(cx - score_w / 2.0, 36.0),
		score_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 30, Color.WHITE)
	draw_string(font, Vector2(score_panel.position.x + score_panel.size.x - red_w - 14.0, 24.0),
		red_name, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, t2c)

	# Current role assignment
	var esc_team := GameManager.escapist_team
	var trap_team := Enums.Team.TEAM_2 if esc_team == Enums.Team.TEAM_1 else Enums.Team.TEAM_1
	var role_text := "%s: ESCAPISTS | %s: TRAPPERS" % [
		Enums.team_name(esc_team),
		Enums.team_name(trap_team),
	]
	draw_string(font, Vector2(220, 64), role_text,
		HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.7, 0.7, 0.7))

	# Hunt info (during hunt)
	if GameManager.current_state == Enums.GameState.ESCAPE:
		var alive_text := "Escapists alive: %d" % GameManager.get_living_escapists()
		draw_string(font, Vector2(screen.x - 180, 50), alive_text,
			HORIZONTAL_ALIGNMENT_RIGHT, -1, 12, Enums.role_color(Enums.Role.ESCAPIST))

		# Round timer
		var time_left := GameManager.get_hunt_time()
		var timer_text := "%d" % ceili(time_left)
		var timer_color := Color.WHITE if time_left > 10.0 else Color(1.0, 0.3, 0.2)
		draw_string(font, Vector2(cx - 10, bar_h + 26), timer_text,
			HORIZONTAL_ALIGNMENT_CENTER, -1, 28, timer_color)

	# Phase indicator
	var phase := ""
	match GameManager.current_state:
		Enums.GameState.OBSERVATION: phase = ""
		Enums.GameState.HUNT: phase = "STRATEGY HUNT"
		Enums.GameState.ESCAPE: phase = "ESCAPE"
		Enums.GameState.ROUND_END: phase = "ROUND END"
		Enums.GameState.MATCH_END: phase = "MATCH END"
		Enums.GameState.PRACTICE: phase = "PRACTICE"
		Enums.GameState.PAUSED: phase = "PAUSED"

	if not phase.is_empty():
		draw_string(font, Vector2(screen.x - 120, 26), phase,
			HORIZONTAL_ALIGNMENT_RIGHT, -1, 14, Color.YELLOW)

	_draw_control_legend(font, screen)


func _draw_practice_hud(font: Font, screen: Vector2, bar_h: float) -> void:
	var title := "PRACTICE MODE"
	draw_string(font, Vector2(24.0, 30.0),
		title, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color(0.25, 0.85, 1.0))

	var detail := "Free training | START pause"
	draw_string(font, Vector2(24.0, 54.0),
		detail, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0.7, 0.7, 0.7))

	draw_string(font, Vector2(screen.x - 130.0, 28.0),
		"PRACTICE", HORIZONTAL_ALIGNMENT_RIGHT, -1, 14, Color.YELLOW)

	_draw_practice_controls(font, screen)


func _draw_control_legend(font: Font, screen: Vector2) -> void:
	var panel_w := 360.0
	var panel_h := 54.0
	var panel_pos := Vector2(14.0, screen.y - panel_h - 14.0)
	var panel_rect := Rect2(panel_pos, Vector2(panel_w, panel_h))
	draw_rect(panel_rect, Color(0.02, 0.02, 0.02, 0.68))
	draw_rect(panel_rect, Color(0.72, 0.72, 0.72, 0.35), false, 2.0)

	var esc_label := "Escapists: A skill | START pause"
	var trap_label := "Trappers: A/X/Y skills | START pause"
	draw_string(font, Vector2(panel_pos.x + 14.0, panel_pos.y + 20.0),
		esc_label, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Enums.role_color(Enums.Role.ESCAPIST))
	draw_string(font, Vector2(panel_pos.x + 14.0, panel_pos.y + 39.0),
		trap_label, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Enums.role_color(Enums.Role.TRAPPER))


func _draw_practice_controls(font: Font, screen: Vector2) -> void:
	var panel_w := 320.0
	var panel_h := 34.0
	var panel_pos := Vector2(14.0, screen.y - panel_h - 14.0)
	var panel_rect := Rect2(panel_pos, Vector2(panel_w, panel_h))
	draw_rect(panel_rect, Color(0.02, 0.02, 0.02, 0.68))
	draw_rect(panel_rect, Color(0.72, 0.72, 0.72, 0.35), false, 2.0)
	draw_string(font, Vector2(panel_pos.x + 14.0, panel_pos.y + 22.0),
		"START pause | Practice skills on the selection screens",
		HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0.7, 0.7, 0.7))
