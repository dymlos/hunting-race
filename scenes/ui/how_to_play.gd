class_name HowToPlay
extends Control

signal back_requested

var input_blocked: bool = false
var _page_index: int = 0
var _nav_cooldown: float = 0.0
var _prev_keyboard_next: bool = false
var _prev_keyboard_back: bool = false

const NAV_COOLDOWN: float = 0.22
const PAGES := [
	{
		"title": "FLUJO DE PARTIDA",
		"accent": Color(0.95, 0.84, 0.18),
		"lines": [
			"Equipos: los jugadores se unen al Equipo Azul o al Equipo Rojo. Los bots son opcionales.",
			"Cada ronda tiene dos roles: un equipo escapa y el otro caza.",
			"Los roles cambian después de cada ronda, así ambos equipos escapan y cazan.",
			"Los escapistas deben llegar a la meta antes de que termine el tiempo. Los cazadores intentan detenerlos.",
		],
	},
	{
		"title": "FASES DE RONDA",
		"accent": Color(0.30, 0.82, 1.0),
		"lines": [
			"Vista previa: la ronda empieza con una mirada breve al mapa y a los roles.",
			"Caza estratégica: los cazadores pueden preparar y colocar trampas durante la cuenta regresiva.",
			"Escape: los escapistas corren hacia la meta mientras las trampas siguen activas.",
			"El modo práctica evita la presión del puntaje y sirve para probar movimiento, habilidades y trampas.",
		],
	},
	{
		"title": "PUNTAJE",
		"accent": Color(0.28, 0.95, 0.48),
		"lines": [
			"Escapar da 100 puntos base.",
			"Cada segundo restante suma 5 puntos.",
			"No tocar trampas da una bonificación de 50 puntos.",
			"Tocar exactamente una trampa todavía da 25 puntos de bonificación.",
			"Cada reaparición o muerte resta 10 puntos.",
		],
	},
	{
		"title": "HABILIDADES",
		"accent": Color(1.0, 0.36, 0.24),
		"lines": [
			"Las recargas avanzan con el tiempo: después de usar una habilidad, espera a que termine.",
			"Los escapistas usan A en partida. Después de usarla, la habilidad entra en recarga.",
			"Cuando una habilidad escapista vuelve a estar lista, el personaje parpadea y el control vibra.",
			"Los cazadores usan A, X e Y.",
			"En caza, cada habilidad de cazador tiene un uso gratis.",
			"En escape y práctica, cada habilidad de cazador tiene sus propias cargas y recargas.",
			"Cuando vuelve una carga, el cursor del cazador parpadea y el control vibra.",
			"Algunas habilidades de cazador tienen límite de colocación o usan varios puntos.",
			"Select cancela la colocación de varios puntos.",
		],
	},
]


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func open() -> void:
	_page_index = 0
	_nav_cooldown = 0.0
	_prev_keyboard_next = Input.is_key_pressed(KEY_ENTER) or Input.is_key_pressed(KEY_SPACE)
	_prev_keyboard_back = Input.is_key_pressed(KEY_ESCAPE) or Input.is_key_pressed(KEY_BACKSPACE)
	show()
	queue_redraw()


func _process(delta: float) -> void:
	if not visible or input_blocked:
		return

	_nav_cooldown = maxf(_nav_cooldown - delta, 0.0)

	for device_id: int in Input.get_connected_joypads():
		var move_x := Input.get_joy_axis(device_id, JOY_AXIS_LEFT_X)
		if _nav_cooldown <= 0.0:
			if move_x > 0.5:
				_next_page()
				_nav_cooldown = NAV_COOLDOWN
			elif move_x < -0.5:
				_previous_page()
				_nav_cooldown = NAV_COOLDOWN

		if InputManager.is_menu_confirm_just_pressed(device_id):
			_next_page()
			return
		if InputManager.is_menu_back_just_pressed(device_id):
			back_requested.emit()
			return

	var keyboard_next := Input.is_key_pressed(KEY_ENTER) or Input.is_key_pressed(KEY_SPACE)
	if keyboard_next and not _prev_keyboard_next:
		_next_page()
		return
	_prev_keyboard_next = keyboard_next

	var keyboard_back := Input.is_key_pressed(KEY_ESCAPE) or Input.is_key_pressed(KEY_BACKSPACE)
	if keyboard_back and not _prev_keyboard_back:
		back_requested.emit()
		return
	_prev_keyboard_back = keyboard_back

	queue_redraw()


func _next_page() -> void:
	_page_index = (_page_index + 1) % PAGES.size()
	queue_redraw()


func _previous_page() -> void:
	_page_index = (_page_index - 1 + PAGES.size()) % PAGES.size()
	queue_redraw()


func _draw() -> void:
	var screen := get_viewport_rect().size
	var cx := screen.x / 2.0
	var font := ThemeDB.fallback_font
	var page: Dictionary = PAGES[_page_index]
	var page_title: String = page["title"] as String
	var accent: Color = page["accent"] as Color

	draw_rect(Rect2(Vector2.ZERO, screen), Color(0.015, 0.015, 0.018, 1.0))
	draw_rect(Rect2(Vector2.ZERO, Vector2(screen.x, screen.y * 0.42)), Color(accent, 0.08))

	_draw_centered_text_in_rect(font, "CÓMO JUGAR", Rect2(cx - 260.0, 38.0, 520.0, 42.0), 34, Color.WHITE)
	_draw_centered_text_in_rect(font, "Las partidas oficiales alternan rondas de escape y caza.",
		Rect2(cx - 420.0, 82.0, 840.0, 24.0), 15, Color(0.68, 0.68, 0.70))

	var panel_rect := Rect2(cx - 470.0, 138.0, 940.0, 500.0)
	_draw_panel(panel_rect, Color(0.055, 0.055, 0.065, 0.96), Color(accent, 0.78), 2.0)
	draw_rect(Rect2(panel_rect.position, Vector2(panel_rect.size.x, 6.0)), accent)

	_draw_centered_text_in_rect(font, page_title,
		Rect2(panel_rect.position.x, panel_rect.position.y + 26.0, panel_rect.size.x, 40.0), 30, accent)

	if page_title == "HABILIDADES":
		_draw_skills_page(font, panel_rect, accent)
		var indicator := "%d / %d" % [_page_index + 1, PAGES.size()]
		_draw_centered_text_in_rect(font, indicator, Rect2(cx - 100.0, panel_rect.end.y - 42.0, 200.0, 24.0),
			16, Color(0.72, 0.72, 0.74))
		var hint := "Izq./Der. páginas | Start siguiente | Select volver"
		_draw_centered_text_in_rect(font, hint, Rect2(cx - 250.0, screen.y - 58.0, 500.0, 24.0),
			16, Color(0.98, 0.92, 0.25))
		return

	var lines: Array = page["lines"] as Array
	var y := panel_rect.position.y + 112.0
	for i in lines.size():
		var bullet_rect := Rect2(panel_rect.position.x + 58.0, y - 12.0, 16.0, 16.0)
		draw_rect(bullet_rect, Color(accent, 0.24))
		draw_rect(bullet_rect, accent, false, 1.5)
		y += _draw_wrapped_text(font, lines[i] as String, Vector2(panel_rect.position.x + 92.0, y),
			panel_rect.size.x - 150.0, 19, Color(0.88, 0.88, 0.88), 25.0, 3)
		y += 22.0

	var indicator := "%d / %d" % [_page_index + 1, PAGES.size()]
	_draw_centered_text_in_rect(font, indicator, Rect2(cx - 100.0, panel_rect.end.y - 42.0, 200.0, 24.0),
		16, Color(0.72, 0.72, 0.74))

	var hint := "Izq./Der. páginas | Start siguiente | Select volver"
	_draw_centered_text_in_rect(font, hint, Rect2(cx - 250.0, screen.y - 58.0, 500.0, 24.0),
		16, Color(0.98, 0.92, 0.25))


func _draw_skills_page(font: Font, panel_rect: Rect2, accent: Color) -> void:
	var left_title := "ESCAPISTAS"
	var right_title := "CAZADORES"
	var col_gap := 46.0
	var content_margin := 34.0
	var header_y := panel_rect.position.y + 88.0
	var top_y := panel_rect.position.y + 142.0
	var col_w := (panel_rect.size.x - content_margin * 2.0 - col_gap) * 0.5
	var left_rect := Rect2(panel_rect.position.x + content_margin, top_y, col_w, 300.0)
	var right_rect := Rect2(left_rect.end.x + col_gap, top_y, col_w, 300.0)
	var left_header := Rect2(left_rect.position.x, header_y, left_rect.size.x, 30.0)
	var right_header := Rect2(right_rect.position.x, header_y, right_rect.size.x, 30.0)

	_draw_centered_text_in_rect(font, left_title, left_header, 15, Color(0.9, 0.9, 0.92))
	_draw_centered_text_in_rect(font, right_title, right_header, 15, accent)
	var divider_y := header_y + 38.0
	draw_line(Vector2(left_rect.position.x, divider_y), Vector2(left_rect.end.x, divider_y), Color(accent, 0.34), 1.2)
	draw_line(Vector2(right_rect.position.x, divider_y), Vector2(right_rect.end.x, divider_y), Color(accent, 0.34), 1.2)

	var left_lines: Array[String] = [
		"Las recargas avanzan con el tiempo, no con objetos ni puntaje.",
		"Los escapistas usan A en partida. Después de usarla, la habilidad entra en recarga.",
		"Cuando vuelve a estar lista, el personaje parpadea y el control vibra.",
	]
	var right_lines: Array[String] = [
		"Los cazadores usan A, X e Y.",
		"En caza, cada habilidad tiene un uso gratis.",
		"En escape y práctica, cada habilidad tiene sus propias cargas y recargas.",
		"Cuando vuelve una carga, el cursor del cazador parpadea y el control vibra.",
		"Algunas habilidades tienen límite de colocación o usan varios puntos.",
		"Select cancela la colocación de varios puntos.",
	]

	_draw_skills_column(font, left_rect, accent, left_lines, 16, 17.0, 10.0)
	_draw_skills_column(font, right_rect, accent, right_lines, 15, 17.0, 10.0)


func _draw_skills_column(font: Font, rect: Rect2, accent: Color, lines: Array[String], font_size: int, line_height: float, gap: float) -> void:
	var y := rect.position.y
	for line in lines:
		var bullet_rect := Rect2(rect.position.x + 2.0, y - 8.0, 12.0, 12.0)
		draw_rect(bullet_rect, Color(accent, 0.24))
		draw_rect(bullet_rect, accent, false, 1.2)
		y += _draw_wrapped_text(font, line, Vector2(rect.position.x + 26.0, y),
			rect.size.x - 28.0, font_size, Color(0.88, 0.88, 0.88), line_height, 2)
		y += gap


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


func _draw_wrapped_text(font: Font, text: String, position: Vector2,
		max_width: float, font_size: int, color: Color, line_height: float, max_lines: int) -> float:
	var words := text.split(" ", false)
	var lines: Array[String] = []
	var current := ""

	for word: String in words:
		var candidate := word if current.is_empty() else "%s %s" % [current, word]
		var candidate_width := font.get_string_size(candidate, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
		if candidate_width <= max_width or current.is_empty():
			current = candidate
		else:
			lines.append(current)
			current = word

	if not current.is_empty():
		lines.append(current)

	if lines.size() > max_lines:
		lines = lines.slice(0, max_lines)
		var trimmed_line := lines[max_lines - 1] as String
		lines[max_lines - 1] = "%s..." % trimmed_line.trim_suffix(".")

	for i in lines.size():
		draw_string(font, position + Vector2(0.0, float(i) * line_height),
			lines[i], HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)

	return float(lines.size()) * line_height
