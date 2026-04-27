class_name GameHud
extends Control

## HUD showing match state. Skill cooldown feedback lives on characters.

var input_blocked: bool = false


func _process(_delta: float) -> void:
	if visible:
		queue_redraw()


func _draw() -> void:
	var screen := get_viewport_rect().size
	var font := ThemeDB.fallback_font
	var cx := screen.x / 2.0

	var bar_h := 86.0
	draw_rect(Rect2(0, 0, screen.x, bar_h), Color(0, 0, 0, 0.56))

	if GameManager.current_state == Enums.GameState.PRACTICE:
		_draw_practice_hud(font, screen, bar_h)
		return

	var round_text := "Ronda %d" % GameManager.get_competitive_round_number()
	var leg_text := GameManager.get_round_leg_label()
	var leg_color := Color(0.2, 0.8, 1.0)
	if leg_text == "Ronda de caza":
		leg_color = Color(1.0, 0.35, 0.2)
	var round_panel := Rect2(Vector2(12.0, 10.0), Vector2(220.0, 60.0))
	draw_rect(round_panel, Color(0.02, 0.02, 0.02, 0.74))
	draw_rect(round_panel, Color(leg_color, 0.82), false, 2.4)
	draw_string(font, Vector2(24.0, 32.0), round_text,
		HORIZONTAL_ALIGNMENT_LEFT, -1, 21, Color.WHITE)
	if not leg_text.is_empty():
		draw_string(font, Vector2(24.0, 57.0), leg_text,
			HORIZONTAL_ALIGNMENT_LEFT, -1, 15, leg_color)

	var t1c := Enums.team_color(Enums.Team.TEAM_1)
	var t2c := Enums.team_color(Enums.Team.TEAM_2)
	var score_text := "%d - %d" % [GameManager.match_scores[0], GameManager.match_scores[1]]
	var score_panel := Rect2(Vector2(cx - 200.0, 8.0), Vector2(400.0, 68.0))
	draw_rect(score_panel, Color(0.03, 0.03, 0.03, 0.68))
	draw_rect(score_panel, Color(0.78, 0.78, 0.78, 0.42), false, 2.0)
	var blue_name := Enums.team_name(Enums.Team.TEAM_1).to_upper()
	var red_name := Enums.team_name(Enums.Team.TEAM_2).to_upper()
	var red_w := font.get_string_size(red_name, HORIZONTAL_ALIGNMENT_LEFT, -1, 18).x
	var score_w := font.get_string_size(score_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 34).x
	draw_string(font, Vector2(score_panel.position.x + 16.0, 26.0),
		blue_name, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, t1c)
	draw_string(font, Vector2(cx - score_w / 2.0, 40.0),
		score_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 34, Color.WHITE)
	draw_string(font, Vector2(score_panel.position.x + score_panel.size.x - red_w - 16.0, 26.0),
		red_name, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, t2c)

	var esc_team := GameManager.escapist_team
	var trap_team := Enums.Team.TEAM_2 if esc_team == Enums.Team.TEAM_1 else Enums.Team.TEAM_1
	var role_text := "%s ESCAPA   |   %s CAZA" % [
		Enums.team_name(esc_team).to_upper(),
		Enums.team_name(trap_team).to_upper(),
	]
	var role_w := font.get_string_size(role_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x
	draw_string(font, Vector2(cx - role_w * 0.5, 70.0),
		role_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0.74, 0.74, 0.76))

	if GameManager.current_state == Enums.GameState.ESCAPE:
		var alive_panel := Rect2(Vector2(screen.x - 220.0, 12.0), Vector2(200.0, 28.0))
		draw_rect(alive_panel, Color(0.03, 0.03, 0.03, 0.72))
		draw_rect(alive_panel, Color(Enums.role_color(Enums.Role.ESCAPIST), 0.36), false, 1.5)
		var alive_text := "Escapistas vivos: %d" % GameManager.get_living_escapists()
		draw_string(font, Vector2(alive_panel.position.x + 12.0, alive_panel.position.y + 19.0),
			alive_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Enums.role_color(Enums.Role.ESCAPIST))

		var time_left := GameManager.get_hunt_time()
		var timer_text := "%d" % ceili(time_left)
		var timer_color := Color.WHITE if time_left > 10.0 else Color(1.0, 0.3, 0.2)
		draw_string(font, Vector2(cx - 10.0, bar_h + 30.0), timer_text,
			HORIZONTAL_ALIGNMENT_CENTER, -1, 32, timer_color)

	var phase := ""
	match GameManager.current_state:
		Enums.GameState.OBSERVATION: phase = ""
		Enums.GameState.HUNT: phase = "CAZA ESTRATÉGICA"
		Enums.GameState.ESCAPE: phase = "ESCAPA"
		Enums.GameState.ROUND_END: phase = "FIN DE RONDA"
		Enums.GameState.MATCH_END: phase = "FIN DE PARTIDA"
		Enums.GameState.PRACTICE: phase = "PRÁCTICA"
		Enums.GameState.PAUSED: phase = "PAUSA"

	if not phase.is_empty():
		draw_string(font, Vector2(screen.x - 150.0, 66.0), phase,
			HORIZONTAL_ALIGNMENT_RIGHT, -1, 15, Color.YELLOW)

func _draw_practice_hud(font: Font, screen: Vector2, _bar_h: float) -> void:
	draw_string(font, Vector2(24.0, 34.0),
		"MODO PRÁCTICA", HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color(0.25, 0.85, 1.0))
	draw_string(font, Vector2(24.0, 60.0),
		"Recargas activas | Start pausa | Select cancela colocación de trampas",
		HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(0.74, 0.74, 0.74))
	draw_string(font, Vector2(screen.x - 144.0, 34.0),
		"PRÁCTICA", HORIZONTAL_ALIGNMENT_RIGHT, -1, 15, Color.YELLOW)


func _draw_team_ability_panels(font: Font, screen: Vector2) -> void:
	var panel_y := 100.0
	var panel_w := minf(400.0, screen.x * 0.27)
	var left_rect := Rect2(14.0, panel_y, panel_w, screen.y - panel_y - 14.0)
	var right_rect := Rect2(screen.x - panel_w - 14.0, panel_y, panel_w, screen.y - panel_y - 14.0)

	_draw_role_panel(font, left_rect, Enums.Role.ESCAPIST)
	_draw_role_panel(font, right_rect, Enums.Role.TRAPPER)


func _draw_role_panel(font: Font, rect: Rect2, role: Enums.Role) -> void:
	var entries := _get_hud_entries_for_role(role)
	if entries.is_empty():
		return

	var team := entries[0].get("team", Enums.Team.NONE) as Enums.Team
	var accent := Enums.team_color(team)
	var title := "%s %s" % [Enums.team_name(team).to_upper(), Enums.role_name(role).to_upper()]
	draw_rect(rect, Color(0.02, 0.02, 0.03, 0.78))
	draw_rect(rect, Color(accent, 0.7), false, 2.0)
	draw_rect(Rect2(rect.position, Vector2(rect.size.x, 6.0)), accent)
	draw_string(font, Vector2(rect.position.x + 16.0, rect.position.y + 26.0),
		title, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, accent)

	var y := rect.position.y + 50.0
	for entry: Dictionary in entries:
		var block_h := _estimate_entry_height(entry, role)
		if y + block_h > rect.end.y - 8.0:
			break
		var block_rect := Rect2(rect.position.x + 10.0, y, rect.size.x - 20.0, block_h - 6.0)
		draw_rect(block_rect, Color(accent, 0.08))
		draw_rect(block_rect, Color(accent, 0.22), false, 1.2)
		var label := entry.get("label", "") as String
		var label_color := entry.get("label_color", accent) as Color
		draw_string(font, Vector2(block_rect.position.x + 12.0, block_rect.position.y + 18.0),
			label, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, label_color)

		var line_y := block_rect.position.y + 38.0
		if role == Enums.Role.ESCAPIST:
			var ability_line := entry.get("ability_line", "") as String
			draw_string(font, Vector2(block_rect.position.x + 12.0, line_y),
				ability_line, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0.9, 0.9, 0.9))
			line_y += 18.0
			line_y += _draw_wrapped_text(font, entry.get("desc", "") as String,
				Vector2(block_rect.position.x + 12.0, line_y), block_rect.size.x - 24.0,
				11, Color(0.64, 0.64, 0.66), 14.0, 2)
		else:
			var abilities: Array = entry.get("abilities", []) as Array
			for ability_entry in abilities:
				var ability_dict := ability_entry as Dictionary
				var ability_text := "%s  %s  %s" % [
					ability_dict.get("button", "") as String,
					ability_dict.get("name", "") as String,
					ability_dict.get("state", "LISTA") as String,
				]
				draw_string(font, Vector2(block_rect.position.x + 12.0, line_y),
					ability_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 12,
					ability_dict.get("color", Color.WHITE) as Color)
				line_y += 16.0
				line_y += _draw_wrapped_text(font, ability_dict.get("desc", "") as String,
					Vector2(block_rect.position.x + 18.0, line_y), block_rect.size.x - 30.0,
					10, Color(0.64, 0.64, 0.66), 13.0, 2)
				line_y += 6.0

		y += block_h


func _get_hud_entries_for_role(role: Enums.Role) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var player_indices: Array[int] = []
	for player_index: int in GameManager.player_characters:
		if player_index >= 100:
			continue
		var node := GameManager.player_characters[player_index] as Node
		if node == null or not is_instance_valid(node):
			continue
		if GameManager.get_player_role(player_index) != role:
			continue
		player_indices.append(player_index)
	player_indices.sort()

	for player_index in player_indices:
		var node: Node = GameManager.player_characters[player_index] as Node
		if role == Enums.Role.ESCAPIST and node is Escapist:
			var esc := node as Escapist
			var animal_data := EscapistAnimals.get_by_id(esc.escapist_animal)
			var ability_entry := esc.get_hud_ability_entry()
			result.append({
				"team": esc.team,
				"label": "P%d  %s" % [player_index + 1, animal_data.get("name", "ESCAPISTA") as String],
				"label_color": animal_data.get("color", Color.WHITE) as Color,
				"ability_line": "[%s] %s  %s" % [
					ability_entry.get("button", "A") as String,
					ability_entry.get("name", "Habilidad") as String,
					ability_entry.get("state", "LISTA") as String,
				],
				"desc": (animal_data.get("ability", {}) as Dictionary).get("desc", "") as String,
			})
		elif role == Enums.Role.TRAPPER and node is Trapper:
			var trapper := node as Trapper
			var trapper_data := TrapperCharacters.get_by_id(trapper.trapper_character)
			var desc_map: Dictionary = {}
			var trapper_abilities: Array = trapper_data.get("abilities", []) as Array
			for ability_data in trapper_abilities:
				var ability_dict := ability_data as Dictionary
				desc_map[ability_dict.get("name", "") as String] = ability_dict.get("desc", "") as String
			var dynamic_entries: Array[Dictionary] = []
			for ability_entry in trapper.get_hud_ability_entries():
				var dynamic_entry := ability_entry.duplicate(true)
				dynamic_entry["button"] = "[%s]" % (dynamic_entry.get("button", "") as String)
				var ability_name := dynamic_entry.get("name", "") as String
				dynamic_entry["desc"] = desc_map.get(ability_name, "") as String
				dynamic_entries.append(dynamic_entry)
			result.append({
				"team": trapper.team,
				"label": "P%d  %s" % [player_index + 1, trapper_data.get("name", "CAZADOR") as String],
				"label_color": trapper_data.get("color", Color.WHITE) as Color,
				"abilities": dynamic_entries,
			})
	return result


func _estimate_entry_height(entry: Dictionary, role: Enums.Role) -> float:
	if role == Enums.Role.ESCAPIST:
		return 104.0
	var abilities: Array = entry.get("abilities", []) as Array
	return 64.0 + float(abilities.size()) * 48.0


func _draw_wrapped_text(font: Font, text: String, position: Vector2, max_width: float,
		font_size: int, color: Color, line_height: float, max_lines: int) -> float:
	var words := text.split(" ", false)
	var lines: Array[String] = []
	var current := ""
	for word: String in words:
		var candidate := word if current.is_empty() else "%s %s" % [current, word]
		if font.get_string_size(candidate, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x <= max_width \
				or current.is_empty():
			current = candidate
		else:
			lines.append(current)
			current = word
	if not current.is_empty():
		lines.append(current)

	if lines.size() > max_lines:
		lines = lines.slice(0, max_lines)
		var last_line := lines[max_lines - 1]
		while not last_line.is_empty():
			var trimmed := "%s..." % last_line
			if font.get_string_size(trimmed, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x <= max_width:
				lines[max_lines - 1] = trimmed
				break
			last_line = last_line.substr(0, last_line.length() - 1).strip_edges()

	for i in lines.size():
		draw_string(font, position + Vector2(0.0, float(i) * line_height),
			lines[i], HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)
	return float(lines.size()) * line_height
