class_name PhaseOverlay
extends Control

## Displays phase announcements: countdown, deployment, hunt start, round end.

var _text: String = ""
var _sub_text: String = ""
var _text_color: Color = Color.WHITE
var _show_timer: float = 0.0
var input_blocked: bool = false


func show_observation(time_left: float) -> void:
	_text = "OBSERVE"
	_sub_text = "%d" % ceili(time_left)
	_text_color = Color.YELLOW
	visible = true
	queue_redraw()


func show_deployment(role_name: String) -> void:
	_text = "%s DEPLOYED" % role_name.to_upper()
	_sub_text = ""
	_text_color = Color.CYAN
	_show_timer = 1.5
	visible = true
	queue_redraw()


func show_hunt() -> void:
	_text = "HUNT!"
	_sub_text = ""
	_text_color = Color.RED
	_show_timer = 2.0
	visible = true
	queue_redraw()


func show_round_end(winning_team: Enums.Team, scores: Array[int]) -> void:
	_text = "TEAM %d WINS!" % winning_team
	_sub_text = "Score: %d - %d" % [scores[0], scores[1]]
	_text_color = Enums.team_color(winning_team)
	visible = true
	queue_redraw()


func show_match_end(winning_team: Enums.Team, scores: Array[int]) -> void:
	_text = "TEAM %d WINS THE MATCH!" % winning_team
	_sub_text = "Final: %d - %d | START to restart" % [scores[0], scores[1]]
	_text_color = Enums.team_color(winning_team)
	visible = true
	queue_redraw()


func clear() -> void:
	_text = ""
	_sub_text = ""
	visible = false


func _process(delta: float) -> void:
	if _show_timer > 0.0:
		_show_timer -= delta
		if _show_timer <= 0.0:
			clear()


func _draw() -> void:
	if _text.is_empty():
		return

	var screen := get_viewport_rect().size
	var cx := screen.x / 2.0
	var cy := screen.y / 2.0
	var font := ThemeDB.fallback_font

	# Semi-transparent backdrop
	draw_rect(Rect2(0, cy - 60, screen.x, 120), Color(0, 0, 0, 0.6))

	# Main text
	draw_string(font, Vector2(cx - _text.length() * 10, cy),
		_text, HORIZONTAL_ALIGNMENT_CENTER, -1, 36, _text_color)

	# Sub text
	if not _sub_text.is_empty():
		draw_string(font, Vector2(cx - _sub_text.length() * 5, cy + 36),
			_sub_text, HORIZONTAL_ALIGNMENT_CENTER, -1, 18, Color(0.8, 0.8, 0.8))
