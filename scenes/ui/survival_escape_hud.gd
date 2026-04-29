class_name SurvivalEscapeHud
extends Control

var input_blocked: bool = false

var _escapist_total: int = 0
var _trapper_total: int = 0
var _escapists_in_exit: int = 0
var _result_text: String = ""
var _result_color: Color = Color.WHITE


func open(escapist_total: int, trapper_total: int) -> void:
	_escapist_total = escapist_total
	_trapper_total = trapper_total
	_escapists_in_exit = 0
	_result_text = ""
	_result_color = Color.WHITE
	show()
	queue_redraw()


func set_exit_count(value: int) -> void:
	_escapists_in_exit = clampi(value, 0, maxi(_escapist_total, 0))
	queue_redraw()


func show_result(text: String, color: Color) -> void:
	_result_text = text
	_result_color = color
	queue_redraw()


func _process(_delta: float) -> void:
	if visible:
		queue_redraw()


func _draw() -> void:
	var screen := get_viewport_rect().size
	var font := ThemeDB.fallback_font
	var cx := screen.x * 0.5
	var bar_h := minf(132.0, screen.y * 0.20)

	draw_rect(Rect2(0.0, 0.0, screen.x, bar_h), Color(0.0, 0.0, 0.0, 0.90))
	draw_rect(Rect2(0.0, bar_h - 30.0, screen.x, 30.0), Color(0.02, 0.03, 0.025, 0.96))
	draw_line(Vector2(0.0, bar_h - 1.0), Vector2(screen.x, bar_h - 1.0), Color(0.20, 0.85, 0.48, 0.72), 2.0)

	_draw_panel(Rect2(18.0, 18.0, 255.0, 62.0), Color(0.02, 0.035, 0.026, 0.82), Color(0.20, 0.85, 0.48, 0.72), 2.0)
	draw_string(font, Vector2(34.0, 43.0), "SURVIVAL ESCAPE",
		HORIZONTAL_ALIGNMENT_LEFT, -1, 21, Color(0.72, 1.0, 0.78))
	draw_string(font, Vector2(34.0, 66.0), "Mapa basico",
		HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0.66, 0.70, 0.68))

	var objective_rect := Rect2(cx - 310.0, 18.0, 620.0, 62.0)
	_draw_panel(objective_rect, Color(0.025, 0.027, 0.028, 0.78), Color(0.42, 0.46, 0.44, 0.48), 1.5)
	_draw_centered_text_in_rect(font, "OBJETIVO",
		Rect2(objective_rect.position.x, objective_rect.position.y + 8.0, objective_rect.size.x, 18.0), 12, Color(0.62, 0.66, 0.64))
	_draw_centered_text_in_rect(font, "Todos los escapistas deben entrar juntos en la zona verde.",
		Rect2(objective_rect.position.x, objective_rect.position.y + 28.0, objective_rect.size.x, 24.0), 16, Color.WHITE)

	var exit_text := "%d/%d en salida" % [_escapists_in_exit, _escapist_total]
	var exit_rect := Rect2(screen.x - 260.0, 18.0, 242.0, 62.0)
	_draw_panel(exit_rect, Color(0.02, 0.035, 0.026, 0.82), Color(0.20, 0.85, 0.48, 0.76), 2.0)
	_draw_centered_text_in_rect(font, "SALIDA",
		Rect2(exit_rect.position.x, exit_rect.position.y + 8.0, exit_rect.size.x, 18.0), 12, Color(0.62, 0.76, 0.66))
	_draw_centered_text_in_rect(font, exit_text,
		Rect2(exit_rect.position.x, exit_rect.position.y + 28.0, exit_rect.size.x, 28.0), 22, Color(0.42, 1.0, 0.58))

	var footer := "Select volver a la pantalla anterior"
	var footer_w := font.get_string_size(footer, HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x
	draw_string(font, Vector2(cx - footer_w * 0.5, bar_h - 10.0),
		footer, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color.YELLOW)

	if not _result_text.is_empty():
		var panel_size := Vector2(560.0, 176.0)
		var panel := Rect2(cx - panel_size.x * 0.5, screen.y * 0.5 - panel_size.y * 0.5, panel_size.x, panel_size.y)
		_draw_panel(panel, Color(0.03, 0.035, 0.032, 0.96), Color(_result_color, 0.92), 2.5)
		draw_rect(Rect2(panel.position, Vector2(panel.size.x, 6.0)), _result_color)
		_draw_centered_text_in_rect(font, _result_text,
			Rect2(panel.position.x, panel.position.y + 34.0, panel.size.x, 42.0), 32, _result_color)
		_draw_centered_text_in_rect(font, "Etapa 2 completada: movimiento, roles fisicos y salida grupal.",
			Rect2(panel.position.x + 24.0, panel.position.y + 88.0, panel.size.x - 48.0, 24.0), 14, Color(0.78, 0.82, 0.80))
		_draw_centered_text_in_rect(font, "Select para volver",
			Rect2(panel.position.x, panel.position.y + 126.0, panel.size.x, 24.0), 16, Color.YELLOW)


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
