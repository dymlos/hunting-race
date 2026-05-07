class_name SurvivalEscapeHud
extends Control

const ABILITY_STATUS_MAX_WIDTH: float = 310.0
const ABILITY_STATUS_MIN_WIDTH: float = 110.0
const ABILITY_STATUS_TOP: float = 12.0
const ABILITY_STATUS_HEIGHT: float = 84.0
const ABILITY_STATUS_MAX_ROW_HEIGHT: float = 22.0
const ABILITY_STATUS_MIN_ROW_HEIGHT: float = 16.0

var input_blocked: bool = false

var _escapist_total: int = 0
var _trapper_total: int = 0
var _escapists_in_exit: int = 0
var _escapists_required_in_exit: int = 0
var _exit_hold_time: float = 0.0
var _exit_hold_duration: float = 0.0
var _time_total: float = Constants.SURVIVAL_ESCAPE_DURATION
var _time_remaining: float = Constants.SURVIVAL_ESCAPE_DURATION
var _wave_number: int = 0
var _zombie_count: int = 0
var _death_count: int = 0
var _next_wave_time: float = 0.0
var _objective_keys_collected: int = 0
var _objective_keys_total: int = 0
var _objective_buttons_pressed: int = 0
var _objective_buttons_total: int = 0
var _objective_exit_unlocked: bool = true
var _map_name: String = "Mapa basico"
var _map_number: int = 1
var _map_total: int = 1
var _result_text: String = ""
var _result_hint: String = ""
var _result_footer: String = "Start continuar"
var _result_color: Color = Color.WHITE
var _transition_text: String = ""
var _transition_subtext: String = ""
var _transition_timer: float = 0.0
var _transition_duration: float = 0.0


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST


func open(escapist_total: int, trapper_total: int, duration: float = Constants.SURVIVAL_ESCAPE_DURATION) -> void:
	_escapist_total = escapist_total
	_trapper_total = trapper_total
	_escapists_in_exit = 0
	_escapists_required_in_exit = escapist_total
	_exit_hold_time = 0.0
	_exit_hold_duration = 0.0
	_time_total = maxf(duration, 1.0)
	_time_remaining = _time_total
	_wave_number = 0
	_zombie_count = 0
	_death_count = 0
	_next_wave_time = Constants.SURVIVAL_FIRST_WAVE_DELAY
	_objective_keys_collected = 0
	_objective_keys_total = 0
	_objective_buttons_pressed = 0
	_objective_buttons_total = 0
	_objective_exit_unlocked = true
	_result_text = ""
	_result_hint = ""
	_result_footer = "Start continuar"
	_result_color = Color.WHITE
	_transition_text = ""
	_transition_subtext = ""
	_transition_timer = 0.0
	_transition_duration = 0.0
	show()
	queue_redraw()


func set_map_info(map_name: String, map_number: int, map_total: int) -> void:
	_map_name = map_name
	_map_number = maxi(map_number, 1)
	_map_total = maxi(map_total, _map_number)
	queue_redraw()


func set_exit_count(value: int, required: int = -1, hold_time: float = 0.0, hold_duration: float = 0.0) -> void:
	_escapists_in_exit = clampi(value, 0, maxi(_escapist_total, 0))
	_escapists_required_in_exit = clampi(required if required >= 0 else _escapist_total, 0, maxi(_escapist_total, 0))
	_exit_hold_time = maxf(hold_time, 0.0)
	_exit_hold_duration = maxf(hold_duration, 0.0)
	queue_redraw()


func set_time_remaining(value: float) -> void:
	_time_remaining = clampf(value, 0.0, _time_total)
	queue_redraw()


func set_wave_status(wave_number: int, zombie_count: int, death_count: int, next_wave_time: float) -> void:
	_wave_number = maxi(wave_number, 0)
	_zombie_count = maxi(zombie_count, 0)
	_death_count = maxi(death_count, 0)
	_next_wave_time = maxf(next_wave_time, 0.0)
	queue_redraw()


func set_objective_status(status: Dictionary) -> void:
	_objective_keys_collected = status.get("keys_collected", 0) as int
	_objective_keys_total = status.get("keys_total", 0) as int
	_objective_buttons_pressed = status.get("buttons_pressed", 0) as int
	_objective_buttons_total = status.get("buttons_total", 0) as int
	_objective_exit_unlocked = status.get("exit_unlocked", true) as bool
	queue_redraw()


func show_result(text: String, color: Color, hint: String = "", footer: String = "Start continuar") -> void:
	_result_text = text
	_result_hint = hint
	_result_footer = footer
	_result_color = color
	queue_redraw()


func start_map_transition(from_map: int, to_map: int, next_map_name: String, duration: float) -> void:
	_transition_text = "MAPA %d COMPLETADO" % from_map
	_transition_subtext = "Entrando a mapa %d/%d - %s" % [to_map, _map_total, next_map_name]
	_transition_duration = maxf(duration, 0.1)
	_transition_timer = _transition_duration
	queue_redraw()


func _process(delta: float) -> void:
	if _transition_timer > 0.0:
		_transition_timer = maxf(_transition_timer - delta, 0.0)
	if visible:
		queue_redraw()


func _draw() -> void:
	var screen := get_viewport_rect().size
	var font := ThemeDB.fallback_font
	var cx := screen.x * 0.5
	var bar_h := minf(154.0, screen.y * 0.22)

	draw_rect(Rect2(0.0, 0.0, screen.x, bar_h), Color(0.0, 0.0, 0.0, 0.90))
	draw_rect(Rect2(0.0, bar_h - 30.0, screen.x, 30.0), Color(0.02, 0.03, 0.025, 0.96))
	draw_line(Vector2(0.0, bar_h - 1.0), Vector2(screen.x, bar_h - 1.0), Color(0.20, 0.85, 0.48, 0.72), 2.0)

	_draw_panel(Rect2(18.0, 18.0, 255.0, 62.0), Color(0.02, 0.035, 0.026, 0.82), Color(0.20, 0.85, 0.48, 0.72), 2.0)
	draw_string(font, Vector2(34.0, 43.0), "SURVIVAL ESCAPE",
		HORIZONTAL_ALIGNMENT_LEFT, -1, 21, Color(0.72, 1.0, 0.78))
	draw_string(font, Vector2(34.0, 66.0), "Mapa %d/%d - %s" % [_map_number, _map_total, _map_name],
		HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0.66, 0.70, 0.68))

	var timer_color := Color(1.0, 0.95, 0.18)
	if _time_remaining <= Constants.SURVIVAL_TIME_WARNING:
		var pulse := 0.72 + 0.28 * absf(sin(Time.get_ticks_msec() / 110.0))
		timer_color = Color(1.0, 0.14, 0.10, pulse)
	var timer_rect := Rect2(cx - 118.0, 16.0, 236.0, 78.0)
	_draw_panel(timer_rect, Color(0.025, 0.020, 0.015, 0.86), Color(timer_color, 0.92), 2.5)
	draw_rect(Rect2(timer_rect.position, Vector2(timer_rect.size.x, 5.0)), timer_color)
	_draw_centered_text_in_rect(font, "TIEMPO",
		Rect2(timer_rect.position.x, timer_rect.position.y + 10.0, timer_rect.size.x, 18.0), 12, Color(0.70, 0.70, 0.64))
	_draw_centered_text_in_rect(font, _format_time(_time_remaining),
		Rect2(timer_rect.position.x, timer_rect.position.y + 30.0, timer_rect.size.x, 40.0), 34, timer_color)
	_draw_survival_ability_statuses(font, screen, timer_rect)

	var objective_rect := Rect2(cx - 380.0, 100.0, 760.0, 32.0)
	_draw_panel(objective_rect, Color(0.025, 0.027, 0.028, 0.78), Color(0.42, 0.46, 0.44, 0.48), 1.5)
	_draw_centered_text_in_rect(font, "OBJETIVO",
		Rect2(objective_rect.position.x + 14.0, objective_rect.position.y + 8.0, 95.0, 16.0), 11, Color(0.62, 0.66, 0.64))
	var objective_text := "Todos los escapistas deben entrar juntos en la zona verde antes de que termine el tiempo."
	if _objective_keys_total > 0:
		if _objective_exit_unlocked:
			objective_text = "Puerta verde desbloqueada. Mantengan la salida durante 3 segundos."
		else:
			objective_text = "Llaves %d/%d | Botones %d/%d | Zona verde segura" % [
				_objective_keys_collected,
				_objective_keys_total,
				_objective_buttons_pressed,
				_objective_buttons_total,
			]
	_draw_centered_text_in_rect(font, objective_text,
		Rect2(objective_rect.position.x + 104.0, objective_rect.position.y + 6.0, objective_rect.size.x - 116.0, 20.0), 14, Color.WHITE)

	var required_total := _escapists_required_in_exit if _escapists_required_in_exit > 0 else _escapist_total
	var exit_text := "%d/%d en salida" % [_escapists_in_exit, required_total]
	if _objective_keys_total > 0 and not _objective_exit_unlocked:
		exit_text = "Segura"
	elif _exit_hold_duration > 0.0 and _exit_hold_time > 0.0:
		exit_text = "%.1fs" % maxf(_exit_hold_duration - _exit_hold_time, 0.0)
	var exit_rect := Rect2(screen.x - 260.0, 18.0, 242.0, 62.0)
	_draw_panel(exit_rect, Color(0.02, 0.035, 0.026, 0.82), Color(0.20, 0.85, 0.48, 0.76), 2.0)
	_draw_centered_text_in_rect(font, "SALIDA",
		Rect2(exit_rect.position.x, exit_rect.position.y + 8.0, exit_rect.size.x, 18.0), 12, Color(0.62, 0.76, 0.66))
	_draw_centered_text_in_rect(font, exit_text,
		Rect2(exit_rect.position.x, exit_rect.position.y + 28.0, exit_rect.size.x, 28.0), 22, Color(0.42, 1.0, 0.58))

	var wave_rect := Rect2(screen.x - 260.0, 88.0, 242.0, 34.0)
	_draw_panel(wave_rect, Color(0.025, 0.035, 0.022, 0.82), Color(0.42, 0.78, 0.36, 0.60), 1.5)
	var wave_text := "Oleada %d | Zombies %d" % [_wave_number, _zombie_count]
	if _wave_number <= 0:
		wave_text = "1ra oleada en %.0fs" % _next_wave_time
	_draw_centered_text_in_rect(font, wave_text,
		Rect2(wave_rect.position.x + 8.0, wave_rect.position.y + 4.0, wave_rect.size.x - 16.0, 16.0), 12, Color(0.72, 1.0, 0.62))
	_draw_centered_text_in_rect(font, "Muertes: %d" % _death_count,
		Rect2(wave_rect.position.x + 8.0, wave_rect.position.y + 18.0, wave_rect.size.x - 16.0, 14.0), 10, Color(0.70, 0.74, 0.70))

	var footer := "Select volver a la pantalla anterior"
	var footer_w := font.get_string_size(footer, HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x
	draw_string(font, Vector2(cx - footer_w * 0.5, bar_h - 10.0),
		footer, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color.YELLOW)

	if not _result_text.is_empty():
		var hint_lines := _get_result_hint_lines()
		var panel_size := Vector2(620.0, 176.0 + maxf(0.0, float(hint_lines.size() - 1)) * 23.0)
		var panel := Rect2(cx - panel_size.x * 0.5, screen.y * 0.5 - panel_size.y * 0.5, panel_size.x, panel_size.y)
		_draw_panel(panel, Color(0.03, 0.035, 0.032, 0.96), Color(_result_color, 0.92), 2.5)
		draw_rect(Rect2(panel.position, Vector2(panel.size.x, 6.0)), _result_color)
		_draw_centered_text_in_rect(font, _result_text,
			Rect2(panel.position.x, panel.position.y + 34.0, panel.size.x, 42.0), 32, _result_color)
		var hint := _result_hint
		if hint.is_empty():
			hint = "Etapa 4 completada: timer, salida grupal y oleadas de zombies."
		_draw_centered_multiline_in_rect(font, hint,
			Rect2(panel.position.x + 24.0, panel.position.y + 84.0, panel.size.x - 48.0, panel.size.y - 128.0), 14, Color(0.78, 0.82, 0.80), 22.0)
		_draw_centered_text_in_rect(font, _result_footer,
			Rect2(panel.position.x, panel.end.y - 44.0, panel.size.x, 24.0), 16, Color.YELLOW)

	if _transition_timer > 0.0:
		_draw_transition_overlay(font, screen)


func _draw_panel(rect: Rect2, fill: Color, outline: Color, outline_width: float = 2.0) -> void:
	draw_rect(rect, fill)
	draw_rect(rect, outline, false, outline_width)


func _draw_centered_text_in_rect(font: Font, text: String, rect: Rect2, font_size: int, color: Color) -> void:
	var text_size := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
	var line_height := font.get_height(font_size)
	var baseline_y := rect.position.y + (rect.size.y - line_height) * 0.5 + font.get_ascent(font_size)
	var pos := Vector2(rect.position.x + (rect.size.x - text_size.x) * 0.5, baseline_y)
	var shadow := Color(0.0, 0.0, 0.0, 0.72 * color.a)
	draw_string(font, pos + Vector2(2.0, 2.0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, shadow)
	draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)


func _draw_survival_ability_statuses(font: Font, screen: Vector2, timer_rect: Rect2) -> void:
	var escapist_entries := _get_survival_ability_entries(Enums.Role.ESCAPIST)
	var trapper_entries := _get_survival_ability_entries(Enums.Role.TRAPPER)

	var left_end := timer_rect.position.x - 10.0
	var left_start := maxf(286.0, left_end - ABILITY_STATUS_MAX_WIDTH)
	var left_width := left_end - left_start
	if left_width >= ABILITY_STATUS_MIN_WIDTH:
		_draw_ability_status_column(font, escapist_entries,
			Rect2(left_start, ABILITY_STATUS_TOP, left_width, ABILITY_STATUS_HEIGHT))

	var right_start := timer_rect.end.x + 10.0
	var right_limit := screen.x - 278.0
	var right_width := minf(ABILITY_STATUS_MAX_WIDTH, right_limit - right_start)
	if right_width >= ABILITY_STATUS_MIN_WIDTH:
		_draw_ability_status_column(font, trapper_entries,
			Rect2(right_start, ABILITY_STATUS_TOP, right_width, ABILITY_STATUS_HEIGHT))


func _get_survival_ability_entries(role_filter: Enums.Role) -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	var tree := get_tree()
	if tree == null:
		return entries
	for node: Node in tree.get_nodes_in_group("characters"):
		if not is_instance_valid(node) or not node.has_method("get_survival_ability_hud_entry"):
			continue
		var entry := node.call("get_survival_ability_hud_entry") as Dictionary
		if entry.is_empty():
			continue
		if int(entry.get("role", Enums.Role.NONE)) != int(role_filter):
			continue
		entries.append(entry)
	entries.sort_custom(Callable(self, "_sort_ability_status_entries"))
	return entries


func _sort_ability_status_entries(a: Dictionary, b: Dictionary) -> bool:
	return int(a.get("player_index", 0)) < int(b.get("player_index", 0))


func _draw_ability_status_column(font: Font, entries: Array[Dictionary], rect: Rect2) -> void:
	if entries.is_empty():
		return
	var row_height := clampf(
		rect.size.y / float(maxi(entries.size(), 1)),
		ABILITY_STATUS_MIN_ROW_HEIGHT,
		ABILITY_STATUS_MAX_ROW_HEIGHT
	)
	for i in entries.size():
		var panel := Rect2(
			rect.position.x,
			rect.position.y + float(i) * row_height,
			rect.size.x,
			maxf(row_height - 2.0, 14.0)
		)
		if panel.end.y > rect.end.y + 1.0:
			break
		_draw_ability_status_entry(font, entries[i], panel)


func _draw_ability_status_entry(font: Font, entry: Dictionary, panel: Rect2) -> void:
	var status_color := Color.WHITE
	var color_variant: Variant = entry.get("status_color", Color.WHITE)
	if color_variant is Color:
		status_color = color_variant as Color
	var base_color := Color.WHITE
	var base_variant: Variant = entry.get("color", Color.WHITE)
	if base_variant is Color:
		base_color = base_variant as Color
	var disabled := entry.get("disabled", false) as bool
	var ready := entry.get("ready", false) as bool
	var blink := 1.0
	if ready:
		blink = 0.35 + 0.65 * absf(sin(float(Time.get_ticks_msec()) / 145.0))
	var fill := Color(0.018, 0.022, 0.024, 0.84)
	if disabled:
		fill = Color(0.018, 0.018, 0.020, 0.72)
	draw_rect(panel, fill)
	var outline_alpha := 0.62 if not disabled else 0.38
	draw_rect(panel, Color(status_color, outline_alpha), false, 1.2)

	var icon_size := minf(panel.size.y - 3.0, 20.0)
	var icon_rect := Rect2(
		panel.position + Vector2(3.0, (panel.size.y - icon_size) * 0.5),
		Vector2(icon_size, icon_size)
	)
	_draw_ability_status_sprite(entry, icon_rect, base_color, disabled)

	var prefix := "%s " % str(entry.get("player_label", "P?"))
	var status_text := str(entry.get("status", ""))
	var text := "%s%s" % [prefix, status_text]
	var text_rect := Rect2(
		icon_rect.end.x + 5.0,
		panel.position.y,
		maxf(8.0, panel.end.x - icon_rect.end.x - 8.0),
		panel.size.y
	)
	var font_size := _fit_text_size(font, text, text_rect.size.x, 10, 7)
	var baseline_y := text_rect.position.y + (text_rect.size.y - font.get_height(font_size)) * 0.5 + font.get_ascent(font_size)
	var pos := Vector2(text_rect.position.x, baseline_y)
	var prefix_width := font.get_string_size(prefix, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	var prefix_color := Color(0.74, 0.80, 0.78) if not disabled else Color(0.58, 0.60, 0.62)
	var text_color := status_color if not disabled else Color(status_color, 0.72)
	if ready:
		text_color = Color(status_color, 0.32 + 0.68 * blink)
	draw_string(font, pos + Vector2(1.0, 1.0), prefix, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color(0.0, 0.0, 0.0, 0.74))
	draw_string(font, pos, prefix, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, prefix_color)
	var status_pos := pos + Vector2(prefix_width, 0.0)
	draw_string(font, status_pos + Vector2(1.0, 1.0), status_text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color(0.0, 0.0, 0.0, 0.74))
	draw_string(font, status_pos, status_text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, text_color)


func _draw_ability_status_sprite(entry: Dictionary, rect: Rect2, base_color: Color, disabled: bool) -> void:
	var center := rect.get_center()
	draw_circle(center + Vector2(1.2, 1.4), rect.size.x * 0.50, Color(0.0, 0.0, 0.0, 0.48))
	draw_circle(center, rect.size.x * 0.48, Color(base_color, 0.22 if not disabled else 0.12))
	var texture_variant: Variant = entry.get("sprite_texture", null)
	if texture_variant is Texture2D:
		var texture := texture_variant as Texture2D
		var texture_size := texture.get_size()
		if texture_size.x > 0.0 and texture_size.y > 0.0:
			var scale := minf(rect.size.x / texture_size.x, rect.size.y / texture_size.y)
			var draw_size := texture_size * scale
			var draw_rect := Rect2(center - draw_size * 0.5, draw_size)
			var modulate := Color.WHITE
			var modulate_variant: Variant = entry.get("sprite_modulate", Color.WHITE)
			if modulate_variant is Color:
				modulate = modulate_variant as Color
			if disabled:
				modulate = modulate.lerp(Color(0.58, 0.58, 0.58), 0.52)
				modulate.a *= 0.60
			draw_texture_rect(texture, draw_rect, false, modulate)
			return
	var initial := _get_status_entry_initial(entry)
	var font_size := 9
	var text_width := ThemeDB.fallback_font.get_string_size(initial, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	draw_string(ThemeDB.fallback_font, center + Vector2(-text_width * 0.5, 3.5),
		initial, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color(base_color, 0.92))


func _get_status_entry_initial(entry: Dictionary) -> String:
	var name := str(entry.get("name", "?"))
	if name.is_empty():
		return "?"
	return name.substr(0, 1)


func _fit_text_size(font: Font, text: String, width: float, preferred_size: int, min_size: int) -> int:
	var size := preferred_size
	while size > min_size and font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x > width:
		size -= 1
	return size


func _draw_centered_multiline_in_rect(font: Font, text: String, rect: Rect2, font_size: int, color: Color,
		line_height: float) -> void:
	var lines := text.split("\n", false)
	if lines.is_empty():
		return
	var total_h := float(lines.size()) * line_height
	var start_y := rect.position.y + maxf(0.0, (rect.size.y - total_h) * 0.5)
	for i in lines.size():
		_draw_centered_text_in_rect(
			font,
			lines[i],
			Rect2(rect.position.x, start_y + float(i) * line_height, rect.size.x, line_height),
			font_size,
			color
		)


func _get_result_hint_lines() -> PackedStringArray:
	if _result_hint.is_empty():
		return PackedStringArray()
	return _result_hint.split("\n", false)


func _draw_transition_overlay(font: Font, screen: Vector2) -> void:
	var progress := 1.0 - clampf(_transition_timer / maxf(_transition_duration, 0.1), 0.0, 1.0)
	var wave := sin(progress * PI)
	draw_rect(Rect2(Vector2.ZERO, screen), Color(0.0, 0.0, 0.0, 0.42 + wave * 0.34))
	var wipe_w := screen.x * clampf(progress, 0.0, 1.0)
	draw_rect(Rect2(0.0, screen.y * 0.5 - 3.0, wipe_w, 6.0), Color(0.20, 0.95, 0.50, 0.92))
	_draw_centered_text_in_rect(font, _transition_text,
		Rect2(0.0, screen.y * 0.5 - 58.0, screen.x, 44.0), 34, Color(0.72, 1.0, 0.78))
	_draw_centered_text_in_rect(font, _transition_subtext,
		Rect2(0.0, screen.y * 0.5 + 18.0, screen.x, 28.0), 18, Color.WHITE)


func _format_time(seconds: float) -> String:
	var whole := int(ceilf(maxf(seconds, 0.0)))
	var minutes := int(floorf(float(whole) / 60.0))
	var secs := whole % 60
	return "%d:%02d" % [minutes, secs]
