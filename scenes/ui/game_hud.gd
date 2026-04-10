class_name GameHud
extends Control

## Simple HUD showing round number, match score, and current phase.

var input_blocked: bool = false


func _process(_delta: float) -> void:
	if visible:
		queue_redraw()


func _draw() -> void:
	var screen := get_viewport_rect().size
	var font := ThemeDB.fallback_font

	# Score bar at top
	var bar_h := 36.0
	draw_rect(Rect2(0, 0, screen.x, bar_h), Color(0, 0, 0, 0.5))

	# Round number
	var round_text := "Round %d" % GameManager.round_number
	draw_string(font, Vector2(20, 24), round_text,
		HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color.WHITE)

	# Scores
	var t1c := Enums.team_color(Enums.Team.TEAM_1)
	var t2c := Enums.team_color(Enums.Team.TEAM_2)
	var score_text := "%d - %d" % [GameManager.match_scores[0], GameManager.match_scores[1]]
	var cx := screen.x / 2.0
	draw_string(font, Vector2(cx - 30, 24), score_text,
		HORIZONTAL_ALIGNMENT_CENTER, -1, 20, Color.WHITE)

	# Team labels
	draw_string(font, Vector2(cx - 80, 24), "T1",
		HORIZONTAL_ALIGNMENT_CENTER, -1, 14, t1c)
	draw_string(font, Vector2(cx + 60, 24), "T2",
		HORIZONTAL_ALIGNMENT_CENTER, -1, 14, t2c)

	# Phase indicator
	var phase := ""
	match GameManager.current_state:
		Enums.GameState.OBSERVATION: phase = "OBSERVE"
		Enums.GameState.DEPLOYMENT: phase = "DEPLOY"
		Enums.GameState.HUNT: phase = "HUNT"
		Enums.GameState.ROUND_END: phase = "ROUND END"
		Enums.GameState.MATCH_END: phase = "MATCH END"
		Enums.GameState.PAUSED: phase = "PAUSED"

	if not phase.is_empty():
		draw_string(font, Vector2(screen.x - 150, 24), phase,
			HORIZONTAL_ALIGNMENT_RIGHT, -1, 14, Color.YELLOW)
