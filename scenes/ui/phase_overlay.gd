class_name PhaseOverlay
extends Control

## Displays phase announcements: countdown, hunt start, round end, match end.

signal escape_finished

var _text: String = ""
var _sub_text: String = ""
var _text_color: Color = Color.WHITE
var _show_timer: float = 0.0
var _escape_anim_time: float = 0.0
var _anchor_top: bool = false
var _detail_lines: Array[String] = []
var _score_entries: Array[Dictionary] = []
var _show_match_totals: bool = false
var _round_total_points: int = 0
var _round_team_totals: Dictionary = {}
var _round_leading_team: Enums.Team = Enums.Team.NONE
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


func show_round_intro(round_number: int, leg_label: String, escapist_team: Enums.Team) -> void:
	_text = "ROUND %d" % round_number
	var trapping_team := Enums.Team.TEAM_2 if escapist_team == Enums.Team.TEAM_1 else Enums.Team.TEAM_1
	_sub_text = "%s ESCAPES | %s TRAPS" % [
		Enums.team_name(escapist_team),
		Enums.team_name(trapping_team),
	]
	_detail_lines.clear()
	_detail_lines.append(leg_label)
	_detail_lines.append("Escapists score by reaching the goal; roles swap after this round.")
	_score_entries.clear()
	_show_match_totals = false
	_text_color = Color(1.0, 0.95, 0.25)
	_show_timer = 2.8
	_anchor_top = false
	visible = true
	queue_redraw()


func show_hunt_countdown(time_left: float) -> void:
	_text = "STRATEGY HUNT"
	_sub_text = "%d" % ceili(time_left)
	_detail_lines.clear()
	_score_entries.clear()
	_show_match_totals = false
	_text_color = Color.YELLOW
	_anchor_top = true
	visible = true
	queue_redraw()


func show_hunt() -> void:
	_text = "STRATEGY HUNT!"
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
	_show_timer = 2.6
	_escape_anim_time = 0.0
	AudioManager.play_skill(&"EscapeHeartbeat")
	_anchor_top = false
	visible = true
	queue_redraw()


func show_round_end(_escapist_team: Enums.Team, scores: Array[int], entries: Array[Dictionary]) -> void:
	_text = "ROUND OVER"
	_sub_text = "Round points: %s | %s %s | %s %s | A to continue" % [
		_format_score(_round_total_points),
		Enums.team_name(Enums.Team.TEAM_1), _format_score(scores[0]),
		Enums.team_name(Enums.Team.TEAM_2), _format_score(scores[1]),
	]
	_detail_lines.clear()
	_score_entries = entries.duplicate(true)
	_show_match_totals = false
	_round_team_totals = _compute_round_team_totals(entries)
	_round_leading_team = _get_round_leading_team(_round_team_totals)
	_text_color = Color.WHITE
	_show_timer = 0.0
	_anchor_top = false
	visible = true
	queue_redraw()


func show_match_end(winning_team: Enums.Team, scores: Array[int], entries: Array[Dictionary]) -> void:
	_text = "%s WINS!" % Enums.team_name(winning_team).to_upper()
	_sub_text = "Final: %d - %d | START to restart" % [scores[0], scores[1]]
	_detail_lines.clear()
	_score_entries = entries.duplicate(true)
	_show_match_totals = true
	_text_color = Enums.team_color(winning_team)
	_show_timer = 0.0
	_anchor_top = false
	visible = true
	queue_redraw()


func set_round_total_points(points: int) -> void:
	_round_total_points = points


func clear() -> void:
	_text = ""
	_sub_text = ""
	_detail_lines.clear()
	_score_entries.clear()
	_show_match_totals = false
	_round_total_points = 0
	_round_team_totals.clear()
	_round_leading_team = Enums.Team.NONE
	_escape_anim_time = 0.0
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
		var score_parts := "base %d, time %d, trap bonus %d, respawn %d" % [
			entry.get("base_score", 0) as int,
			entry.get("time_score", 0) as int,
			entry.get("trap_bonus", 0) as int,
			entry.get("respawn_penalty", 0) as int,
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


func _compute_round_team_totals(entries: Array[Dictionary]) -> Dictionary:
	var totals: Dictionary = {
		Enums.Team.TEAM_1: 0,
		Enums.Team.TEAM_2: 0,
	}
	for entry: Dictionary in entries:
		var team: Enums.Team = entry.get("team", Enums.Team.NONE) as Enums.Team
		if team != Enums.Team.TEAM_1 and team != Enums.Team.TEAM_2:
			continue
		totals[team] = (totals.get(team, 0) as int) + (entry.get("total", 0) as int)
	return totals


func _get_round_leading_team(totals: Dictionary) -> Enums.Team:
	var blue := totals.get(Enums.Team.TEAM_1, 0) as int
	var red := totals.get(Enums.Team.TEAM_2, 0) as int
	if blue == red:
		return Enums.Team.NONE
	if blue > red:
		return Enums.Team.TEAM_1
	return Enums.Team.TEAM_2


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
		var finished_text := _text
		if _text == "ESCAPE!":
			_escape_anim_time += delta
		queue_redraw()
		if _show_timer <= 0.0:
			clear()
			if finished_text == "ESCAPE!":
				escape_finished.emit()


func _draw() -> void:
	if _text.is_empty():
		return

	var screen := get_viewport_rect().size
	var cx := screen.x / 2.0
	var cy := 112.0 if _anchor_top else screen.y / 2.0
	var font := ThemeDB.fallback_font
	var now := Time.get_ticks_msec() / 1000.0
	var anim_time := _escape_anim_time if _text == "ESCAPE!" else now

	var text_size := 36
	var sub_text_size := 18
	if _text == "ESCAPE!":
		text_size = 96
		sub_text_size = 24
	var text_w := font.get_string_size(_text, HORIZONTAL_ALIGNMENT_LEFT, -1, text_size).x
	var sub_text_w := 0.0
	if not _sub_text.is_empty():
		sub_text_w = font.get_string_size(_sub_text, HORIZONTAL_ALIGNMENT_LEFT, -1, sub_text_size).x
	var panel_w := maxf(text_w, sub_text_w) + 96.0
	var panel_h := 82.0 if _sub_text.is_empty() else 118.0
	if _text == "ESCAPE!":
		panel_w = screen.x
		panel_h = screen.y
	if not _detail_lines.is_empty():
		panel_w = maxf(panel_w, minf(screen.x - 120.0, 900.0))
		panel_h += _detail_lines.size() * 18.0 + 24.0
	if not _score_entries.is_empty():
		if _show_match_totals:
			panel_w = minf(screen.x - 160.0, 1040.0)
			panel_h = 178.0 + _score_entries.size() * 82.0
		else:
			panel_w = minf(screen.x - 120.0, 1160.0)
			var team_1_count := 0
			var team_2_count := 0
			for entry: Dictionary in _score_entries:
				var team: Enums.Team = entry.get("team", Enums.Team.NONE) as Enums.Team
				if team == Enums.Team.TEAM_1:
					team_1_count += 1
				elif team == Enums.Team.TEAM_2:
					team_2_count += 1
			var max_rows := maxi(team_1_count, team_2_count)
			panel_h = 238.0 + float(max_rows) * 84.0
	var panel_rect := Rect2(
		Vector2(cx - panel_w / 2.0, cy - panel_h / 2.0),
		Vector2(panel_w, panel_h)
	)
	var panel_alpha := 0.68
	if _text == "ESCAPE!":
		panel_alpha = 0.82
	draw_rect(panel_rect, Color(0, 0, 0, panel_alpha))
	draw_rect(panel_rect, Color(0.8, 0.8, 0.8, 0.35), false, 2.0)

	var title_w := font.get_string_size(_text, HORIZONTAL_ALIGNMENT_LEFT, -1, text_size).x
	var title_pos_y := panel_rect.position.y + 48.0
	if _text == "ESCAPE!":
		var beat_phase := fmod(anim_time * 1.35, 1.0)
		var beat_primary := clampf(1.0 - absf(beat_phase - 0.12) / 0.12, 0.0, 1.0)
		var beat_secondary := clampf(1.0 - absf(beat_phase - 0.32) / 0.09, 0.0, 1.0) * 0.55
		var heartbeat := maxf(beat_primary, beat_secondary)
		var idle_pulse := 0.5 + 0.5 * sin(anim_time * 2.4)
		var flash_strength := 0.32 + 0.42 * heartbeat + 0.12 * idle_pulse
		var escape_size := int(text_size * (1.0 + 0.16 * heartbeat + 0.025 * idle_pulse))
		var escape_w := font.get_string_size(_text, HORIZONTAL_ALIGNMENT_LEFT, -1, escape_size).x
		title_pos_y = screen.y * 0.5 - 36.0 - heartbeat * 10.0
		var title_pos := Vector2(cx - escape_w / 2.0, title_pos_y)
		draw_rect(Rect2(Vector2(0, 0), screen), Color(1.0, 0.06, 0.02, flash_strength * 0.10))
		for ring in range(4):
			var radius := 5.0 + float(ring) * 7.0 + heartbeat * 10.0
			var alpha := (0.22 - 0.035 * float(ring)) + heartbeat * 0.18
			for i in range(16):
				var angle := (TAU / 16.0) * float(i)
				var offset := Vector2.from_angle(angle) * radius
				draw_string(font, title_pos + offset,
					_text, HORIZONTAL_ALIGNMENT_CENTER, -1, escape_size,
					Color(1.0, 0.12 + 0.08 * float(ring), 0.02, alpha))
		var white_glow_alpha := 0.20 + 0.34 * heartbeat
		for i in range(8):
			var angle := (TAU / 8.0) * float(i) + anim_time * 0.6
			var offset := Vector2.from_angle(angle) * (3.0 + heartbeat * 3.0)
			draw_string(font, title_pos + offset,
				_text, HORIZONTAL_ALIGNMENT_CENTER, -1, escape_size,
				Color(1.0, 1.0, 1.0, white_glow_alpha))
		var glow_color := Color(1.0, 0.34, 0.08, 0.62 + 0.26 * heartbeat)
		draw_string(font, title_pos + Vector2(6.0, 6.0),
			_text, HORIZONTAL_ALIGNMENT_CENTER, -1, escape_size, Color(0.0, 0.0, 0.0, 0.8))
		draw_string(font, title_pos + Vector2(1.5, 1.5),
			_text, HORIZONTAL_ALIGNMENT_CENTER, -1, escape_size, Color(0.0, 0.0, 0.0, 0.45))
		draw_string(font, title_pos,
			_text, HORIZONTAL_ALIGNMENT_CENTER, -1, escape_size, Color(1.0, 1.0, 1.0))
		draw_string(font, title_pos + Vector2(0.0, -4.0),
			_text, HORIZONTAL_ALIGNMENT_CENTER, -1, escape_size, glow_color)
	else:
		draw_string(font, Vector2(cx - title_w / 2.0, title_pos_y),
			_text, HORIZONTAL_ALIGNMENT_CENTER, -1, text_size, _text_color)

	if not _sub_text.is_empty():
		var sub_w := font.get_string_size(_sub_text, HORIZONTAL_ALIGNMENT_LEFT, -1, sub_text_size).x
		draw_string(font, Vector2(cx - sub_w / 2.0, panel_rect.position.y + 78.0),
			_sub_text, HORIZONTAL_ALIGNMENT_CENTER, -1, sub_text_size, Color(0.8, 0.8, 0.8))

	if not _score_entries.is_empty():
		if _show_match_totals:
			_draw_score_entries(font, panel_rect)
		else:
			_draw_round_score_entries(font, panel_rect)
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

		var title := "%s  %s  |  %s  |  Total %s" % [
			player_label,
			Enums.team_name(team),
			escaped_text,
			_format_score(total),
		]
		draw_string(font, Vector2(x + 14.0, y),
			title, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Enums.team_color(team))

		var breakdown := "Base %s   Time %s   Trap bonus %s   Respawn %s" % [
			_format_score(entry.get("base_score", 0) as int),
			_format_score(entry.get("time_score", 0) as int),
			_format_score(entry.get("trap_bonus", 0) as int),
			_format_score(entry.get("respawn_penalty", 0) as int),
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


func _draw_round_score_entries(font: Font, panel_rect: Rect2) -> void:
	var intro_y := panel_rect.position.y + 112.0
	var intro := "Each card shows how the round score was built: base, time, trap bonus, and respawn penalty."
	draw_string(font, Vector2(panel_rect.position.x + 24.0, intro_y),
		intro, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0.82, 0.82, 0.82))

	var totals_y := intro_y + 26.0
	var blue_total := _round_team_totals.get(Enums.Team.TEAM_1, 0) as int
	var red_total := _round_team_totals.get(Enums.Team.TEAM_2, 0) as int
	var leading_team_name := "Tied round"
	var leading_team_color := Color(0.78, 0.78, 0.78)
	if _round_leading_team != Enums.Team.NONE:
		leading_team_name = "%s leads this round" % Enums.team_name(_round_leading_team)
		leading_team_color = Enums.team_color(_round_leading_team)
	draw_string(font, Vector2(panel_rect.position.x + 24.0, totals_y),
		"%s | %s %s | %s %s" % [
			leading_team_name,
			Enums.team_name(Enums.Team.TEAM_1), _format_score(blue_total),
			Enums.team_name(Enums.Team.TEAM_2), _format_score(red_total),
		],
		HORIZONTAL_ALIGNMENT_LEFT, -1, 15, leading_team_color)

	var left_x := panel_rect.position.x + 22.0
	var top_y := panel_rect.position.y + 176.0
	var gap := 20.0
	var col_w := (panel_rect.size.x - 64.0 - gap) / 2.0
	var row_h := 74.0
	var teams := [Enums.Team.TEAM_1, Enums.Team.TEAM_2]
	for team_index in teams.size():
		var team: Enums.Team = teams[team_index] as Enums.Team
		var col_x := left_x + float(team_index) * (col_w + gap)
		var team_color := Enums.team_color(team)
		var team_entries: Array[Dictionary] = []
		var escaped_count := 0
		var trap_contacts := 0
		var respawns := 0
		for entry: Dictionary in _score_entries:
			if (entry.get("team", Enums.Team.NONE) as Enums.Team) != team:
				continue
			team_entries.append(entry)
			if entry.get("escaped", false):
				escaped_count += 1
			trap_contacts += entry.get("trap_contacts", 0) as int
			respawns += entry.get("respawns", 0) as int

		var team_total := _round_team_totals.get(team, 0) as int
		var section_rect := Rect2(Vector2(col_x, top_y - 26.0), Vector2(col_w, 54.0))
		draw_rect(section_rect, Color(0.08, 0.08, 0.08, 0.88))
		draw_rect(section_rect, Color(team_color, 0.7), false, 2.0)
		draw_string(font, Vector2(col_x + 14.0, top_y - 2.0),
			Enums.team_name(team).to_upper(), HORIZONTAL_ALIGNMENT_LEFT, -1, 18, team_color)
		draw_string(font, Vector2(col_x + 14.0, top_y + 18.0),
			"Round total %s | Escaped %d/%d | Traps %d | Respawns %d" % [
				_format_score(team_total),
				escaped_count,
				team_entries.size(),
				trap_contacts,
				respawns,
			],
			HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.85, 0.85, 0.85))

		var y := top_y + 52.0
		for entry: Dictionary in team_entries:
			var player_index: int = entry.get("player_index", 0) as int
			var player_label := "P%d" % (player_index + 1) if player_index < 100 else "BOT"
			var total: int = entry.get("total", 0) as int
			var escaped_text := "Escaped" if entry.get("escaped", false) else "No escape"
			var row_rect := Rect2(Vector2(col_x, y - 24.0), Vector2(col_w, row_h))
			draw_rect(row_rect, Color(0.06, 0.06, 0.06, 0.9))
			draw_rect(row_rect, Color(team_color, 0.48), false, 1.5)
			draw_string(font, Vector2(col_x + 12.0, y),
				"%s | %s | Total %s" % [player_label, escaped_text, _format_score(total)],
				HORIZONTAL_ALIGNMENT_LEFT, -1, 15, team_color)
			draw_string(font, Vector2(col_x + 12.0, y + 22.0),
				"Base %s   Time %s   Bonus %s   Respawn %s" % [
					_format_score(entry.get("base_score", 0) as int),
					_format_score(entry.get("time_score", 0) as int),
					_format_score(entry.get("trap_bonus", 0) as int),
					_format_score(entry.get("respawn_penalty", 0) as int),
				],
				HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.9, 0.9, 0.9))
			draw_string(font, Vector2(col_x + 12.0, y + 40.0),
				"Traps %d | Respawns %d | Time left %.1fs" % [
					entry.get("trap_contacts", 0) as int,
					entry.get("respawns", 0) as int,
					entry.get("time_remaining", 0.0) as float,
				],
				HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.68, 0.68, 0.68))
			y += 84.0
