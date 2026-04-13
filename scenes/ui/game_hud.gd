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
	var bar_h := 68.0
	draw_rect(Rect2(0, 0, screen.x, bar_h), Color(0, 0, 0, 0.5))

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
	draw_string(font, Vector2(cx - 30, 28), score_text,
		HORIZONTAL_ALIGNMENT_CENTER, -1, 24, Color.WHITE)
	draw_string(font, Vector2(cx - 80, 28), "T1",
		HORIZONTAL_ALIGNMENT_CENTER, -1, 14, t1c)
	draw_string(font, Vector2(cx + 60, 28), "T2",
		HORIZONTAL_ALIGNMENT_CENTER, -1, 14, t2c)

	# Current role assignment
	var esc_team := GameManager.escapist_team
	var trap_team := Enums.Team.TEAM_2 if esc_team == Enums.Team.TEAM_1 else Enums.Team.TEAM_1
	var role_text := "T%d: ESCAPISTS | T%d: TRAPPERS" % [esc_team, trap_team]
	draw_string(font, Vector2(220, 58), role_text,
		HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.7, 0.7, 0.7))

	# Hunt info (during hunt)
	if GameManager.current_state == Enums.GameState.ESCAPE:
		var alive_text := "Escapists alive: %d" % GameManager.get_living_escapists()
		draw_string(font, Vector2(screen.x - 180, 42), alive_text,
			HORIZONTAL_ALIGNMENT_RIGHT, -1, 12, Enums.role_color(Enums.Role.ESCAPIST))

		# Round timer
		var time_left := GameManager.get_hunt_time()
		var timer_text := "%d" % ceili(time_left)
		var timer_color := Color.WHITE if time_left > 10.0 else Color(1.0, 0.3, 0.2)
		draw_string(font, Vector2(cx - 10, bar_h + 30), timer_text,
			HORIZONTAL_ALIGNMENT_CENTER, -1, 28, timer_color)

	# Phase indicator
	var phase := ""
	match GameManager.current_state:
		Enums.GameState.OBSERVATION: phase = ""
		Enums.GameState.HUNT: phase = "STRATEGY HUNT"
		Enums.GameState.ESCAPE: phase = "ESCAPE"
		Enums.GameState.ROUND_END: phase = "ROUND END"
		Enums.GameState.MATCH_END: phase = "MATCH END"
		Enums.GameState.PAUSED: phase = "PAUSED"

	if not phase.is_empty():
		draw_string(font, Vector2(screen.x - 120, 20), phase,
			HORIZONTAL_ALIGNMENT_RIGHT, -1, 14, Color.YELLOW)
