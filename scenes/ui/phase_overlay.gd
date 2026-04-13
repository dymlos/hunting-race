class_name PhaseOverlay
extends Control

## Displays phase announcements: countdown, hunt start, round end, match end.

var _text: String = ""
var _sub_text: String = ""
var _text_color: Color = Color.WHITE
var _show_timer: float = 0.0
var _anchor_top: bool = false
var _detail_lines: Array[String] = []
var _score_entries: Array[Dictionary] = []
var _show_match_totals: bool = false
var input_blocked: bool = false


func show_observation(_time_left: float) -> void:
	_text = ""
	_sub_text = ""
	_detail_lines.clear()
	_score_entries.clear()
	_show_match_totals = false
	_anchor_top = false
	visible = false
	queue_redraw()


func show_hunt_countdown(time_left: float) -> void:
	_text = "HUNT"
	_sub_text = "%d" % ceili(time_left)
	_detail_lines.clear()
	_score_entries.clear()
	_show_match_totals = false
	_text_color = Color.YELLOW
	_anchor_top = true
	visible = true
	queue_redraw()


func show_hunt() -> void:
	_text = "HUNT!"
	_sub_text = ""
	_detail_lines.clear()
	_score_entries.clear()
	_show_match_totals = false
	_text_color = Color.RED
	_show_timer = 2.0
	_anchor_top = true
	visible = true
	queue_redraw()


func show_escape() -> void:
	_text = "ESCAPE!"
	_sub_text = ""
	_detail_lines.clear()
	_score_entries.clear()
	_show_match_totals = false
	_text_color = Color.RED
	_show_timer = 2.0
	_anchor_top = false
	visible = true
	queue_redraw()


func show_round_end(_escapist_team: Enums.Team, scores: Array[int], entries: Array[Dictionary]) -> void:
	_text = "ROUND OVER"
	_sub_text = "Score: %d - %d" % [scores[0], scores[1]]
	_detail_lines.clear()
	_score_entries = entries.duplicate(true)
	_show_match_totals = false
	_text_color = Color.WHITE
	_anchor_top = false
	visible = true
	queue_redraw()


func show_match_end(winning_team: Enums.Team, scores: Array[int], entries: Array[Dictionary]) -> void:
	_text = "TEAM %d WINS!" % winning_team
	_sub_text = "Final: %d - %d | START to restart" % [scores[0], scores[1]]
	_detail_lines.clear()
	_score_entries = entries.duplicate(true)
	_show_match_totals = true
	_text_color = Enums.team_color(winning_team)
	_anchor_top = false
	visible = true
	queue_redraw()


func clear() -> void:
	_text = ""
	_sub_text = ""
	_detail_lines.clear()
	_score_entries.clear()
	_show_match_totals = false
	visible = false


func _build_round_lines(entries: Array[Dictionary]) -> Array[String]:
	var lines: Array[String] = []
	for entry: Dictionary in entries:
		var player_index: int = entry.get("player_index", 0) as int
		var player_label := "P%d" % (player_index + 1) if player_index < 100 else "BOT"
		var state := "escaped" if entry.get("escaped", false) else "not escaped"
		var time_left: float = entry.get("time_remaining", 0.0) as float
		var total: int = entry.get("total", 0) as int
		var traps: int = entry.get("trap_contacts", 0) as int
		var respawns: int = entry.get("respawns", 0) as int
		var score_parts := "base %d, time %d, trap bonus %d, respawn %d, trap penalty %d" % [
			entry.get("base_score", 0) as int,
			entry.get("time_score", 0) as int,
			entry.get("trap_bonus", 0) as int,
			entry.get("respawn_penalty", 0) as int,
			entry.get("trap_penalty", 0) as int,
		]
		lines.append("%s: %s | %s | left %.1fs | traps %d | respawns %d" % [
			player_label, state, _format_score(total), time_left, traps, respawns
		])
		lines.append("  %s" % score_parts)
	return lines


func _format_score(value: int) -> String:
	if value > 0:
		return "+%d" % value
	return "%d" % value


func _build_match_lines(entries: Array[Dictionary]) -> Array[String]:
	var lines: Array[String] = []
	for entry: Dictionary in entries:
		var player_index: int = entry.get("player_index", 0) as int
		var player_label := "P%d" % (player_index + 1) if player_index < 100 else "BOT"
		lines.append("%s: total %d | escapes %d/%d | traps %d | respawns %d" % [
			player_label,
			entry.get("total", 0) as int,
			entry.get("escaped", 0) as int,
			entry.get("rounds", 0) as int,
			entry.get("trap_contacts", 0) as int,
			entry.get("respawns", 0) as int,
		])
	return lines


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
	var cy := 112.0 if _anchor_top else screen.y / 2.0
	var font := ThemeDB.fallback_font

	var text_size := 36
	var sub_text_size := 18
	var text_w := font.get_string_size(_text, HORIZONTAL_ALIGNMENT_LEFT, -1, text_size).x
	var sub_text_w := 0.0
	if not _sub_text.is_empty():
		sub_text_w = font.get_string_size(_sub_text, HORIZONTAL_ALIGNMENT_LEFT, -1, sub_text_size).x
	var panel_w := maxf(text_w, sub_text_w) + 96.0
	var panel_h := 82.0 if _sub_text.is_empty() else 118.0
	if not _detail_lines.is_empty():
		panel_w = maxf(panel_w, minf(screen.x - 120.0, 900.0))
		panel_h += _detail_lines.size() * 18.0 + 24.0
	if not _score_entries.is_empty():
		panel_w = minf(screen.x - 160.0, 1040.0)
		panel_h = 178.0 + _score_entries.size() * 82.0
	var panel_rect := Rect2(
		Vector2(cx - panel_w / 2.0, cy - panel_h / 2.0),
		Vector2(panel_w, panel_h)
	)
	draw_rect(panel_rect, Color(0, 0, 0, 0.68))
	draw_rect(panel_rect, Color(0.8, 0.8, 0.8, 0.35), false, 2.0)

	var title_w := font.get_string_size(_text, HORIZONTAL_ALIGNMENT_LEFT, -1, text_size).x
	draw_string(font, Vector2(cx - title_w / 2.0, panel_rect.position.y + 48.0),
		_text, HORIZONTAL_ALIGNMENT_CENTER, -1, text_size, _text_color)

	if not _sub_text.is_empty():
		var sub_w := font.get_string_size(_sub_text, HORIZONTAL_ALIGNMENT_LEFT, -1, sub_text_size).x
		draw_string(font, Vector2(cx - sub_w / 2.0, panel_rect.position.y + 78.0),
			_sub_text, HORIZONTAL_ALIGNMENT_CENTER, -1, sub_text_size, Color(0.8, 0.8, 0.8))

	if not _score_entries.is_empty():
		_draw_score_entries(font, panel_rect)
		return

	if not _detail_lines.is_empty():
		var detail_y := panel_rect.position.y + 86.0
		for line in _detail_lines:
			draw_string(font, Vector2(panel_rect.position.x + 24.0, detail_y),
				line, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0.8, 0.8, 0.8))
			detail_y += 18.0


func _draw_score_entries(font: Font, panel_rect: Rect2) -> void:
	var x := panel_rect.position.x + 32.0
	var y := panel_rect.position.y + 134.0
	var row_w := panel_rect.size.x - 64.0
	var row_h := 70.0

	for entry: Dictionary in _score_entries:
		var player_index: int = entry.get("player_index", 0) as int
		var player_label := "P%d" % (player_index + 1) if player_index < 100 else "BOT"
		var team: Enums.Team = entry.get("team", Enums.Team.NONE) as Enums.Team
		var total: int = entry.get("total", 0) as int
		var escaped_text := ""
		if _show_match_totals:
			escaped_text = "Escapes %d/%d" % [
				entry.get("escaped", 0) as int,
				entry.get("rounds", 0) as int,
			]
		else:
			escaped_text = "Escaped" if entry.get("escaped", false) else "No escape"

		var row_rect := Rect2(Vector2(x, y - 26.0), Vector2(row_w, row_h))
		draw_rect(row_rect, Color(0.08, 0.08, 0.08, 0.86))
		draw_rect(row_rect, Color(Enums.team_color(team), 0.55), false, 1.5)

		var title := "%s  Team %d  |  %s  |  Total %s" % [
			player_label,
			team,
			escaped_text,
			_format_score(total),
		]
		draw_string(font, Vector2(x + 14.0, y),
			title, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Enums.team_color(team))

		var breakdown := "Base %s   Time %s   Trap bonus %s   Respawn %s   10 traps %s" % [
			_format_score(entry.get("base_score", 0) as int),
			_format_score(entry.get("time_score", 0) as int),
			_format_score(entry.get("trap_bonus", 0) as int),
			_format_score(entry.get("respawn_penalty", 0) as int),
			_format_score(entry.get("trap_penalty", 0) as int),
		]
		draw_string(font, Vector2(x + 14.0, y + 22.0),
			breakdown, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0.86, 0.86, 0.86))

		var stats := "Traps touched: %d   Respawns/deaths: %d" % [
			entry.get("trap_contacts", 0) as int,
			entry.get("respawns", 0) as int,
		]
		if not _show_match_totals:
			stats += "   Time left: %.1fs" % (entry.get("time_remaining", 0.0) as float)
		draw_string(font, Vector2(x + 14.0, y + 40.0),
			stats, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.62, 0.62, 0.62))

		y += 82.0
