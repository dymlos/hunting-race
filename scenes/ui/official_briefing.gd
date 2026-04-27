class_name OfficialBriefing
extends Control

signal briefing_finished

var input_blocked: bool = false
var _prev_keyboard_confirm: bool = false

const LINES: Array[String] = [
	"Los escapistas deben llegar a la zona verde antes de que termine el tiempo.",
	"Los cazadores intentarán detenerlos colocando trampas y controlando el mapa.",
	"El escenario también tendrá peligros propios: paredes adhesivas, corrientes, hielo y otros obstáculos.",
	"Las habilidades tienen recarga: vuelven con el tiempo después de usarlas. En la fase de caza, cada habilidad de cazador tiene un uso gratis.",
]


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func open() -> void:
	_prev_keyboard_confirm = Input.is_key_pressed(KEY_ENTER) or Input.is_key_pressed(KEY_SPACE)
	InputManager.suppress_edge_detection(3)
	show()
	queue_redraw()


func _process(_delta: float) -> void:
	if not visible or input_blocked:
		return

	for device_id: int in Input.get_connected_joypads():
		if InputManager.is_menu_confirm_just_pressed(device_id):
			briefing_finished.emit()
			return

	var keyboard_confirm := Input.is_key_pressed(KEY_ENTER) or Input.is_key_pressed(KEY_SPACE)
	if keyboard_confirm and not _prev_keyboard_confirm:
		briefing_finished.emit()
		return
	_prev_keyboard_confirm = keyboard_confirm

	queue_redraw()


func _draw() -> void:
	var screen := get_viewport_rect().size
	var cx := screen.x / 2.0
	var font := ThemeDB.fallback_font

	draw_rect(Rect2(Vector2.ZERO, screen), Color(0.01, 0.01, 0.012, 1.0))
	draw_rect(Rect2(Vector2.ZERO, Vector2(screen.x, screen.y * 0.46)), Color(0.10, 0.14, 0.11, 0.32))

	_draw_centered_text_in_rect(font, "PARTIDA OFICIAL",
		Rect2(cx - 320.0, 62.0, 640.0, 46.0), 34, Color.WHITE)
	_draw_centered_text_in_rect(font, "Objetivo rápido antes de empezar",
		Rect2(cx - 320.0, 108.0, 640.0, 24.0), 16, Color(0.72, 0.74, 0.72))

	var panel := Rect2(cx - 520.0, 168.0, 1040.0, 370.0)
	draw_rect(panel, Color(0.055, 0.055, 0.062, 0.96))
	draw_rect(panel, Color(0.24, 0.85, 0.42, 0.75), false, 2.0)
	draw_rect(Rect2(panel.position, Vector2(panel.size.x, 6.0)), Color(0.24, 0.85, 0.42, 0.95))

	var y := panel.position.y + 72.0
	for line in LINES:
		var bullet := Rect2(panel.position.x + 58.0, y - 14.0, 16.0, 16.0)
		draw_rect(bullet, Color(0.24, 0.85, 0.42, 0.24))
		draw_rect(bullet, Color(0.24, 0.85, 0.42, 0.9), false, 1.4)
		y += _draw_wrapped_text(font, line, Vector2(panel.position.x + 92.0, y),
			panel.size.x - 150.0, 18, Color(0.9, 0.9, 0.9), 24.0, 3)
		y += 22.0

	_draw_centered_text_in_rect(font, "Start para comenzar",
		Rect2(cx - 240.0, screen.y - 78.0, 480.0, 28.0), 18, Color.YELLOW)


func _draw_centered_text_in_rect(font: Font, text: String, rect: Rect2, font_size: int, color: Color) -> void:
	var text_size := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
	var line_height := font.get_height(font_size)
	var baseline_y := rect.position.y + (rect.size.y - line_height) * 0.5 + font.get_ascent(font_size)
	var pos := Vector2(rect.position.x + (rect.size.x - text_size.x) * 0.5, baseline_y)
	draw_string(font, pos + Vector2(2.0, 2.0), text,
		HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color(0.0, 0.0, 0.0, 0.72 * color.a))
	draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)


func _draw_wrapped_text(font: Font, text: String, position: Vector2,
		max_width: float, font_size: int, color: Color, line_height: float, max_lines: int) -> float:
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
