class_name IntroScreen
extends Control

signal intro_finished
signal progress_changed(progress: float)

const TEXT_DURATION: float = 14.0
const TOTAL_DURATION: float = 14.5
const FADE_DURATION: float = 0.2
const PARAGRAPH_PAUSE: float = 0.55
const LINE_PAUSE: float = 0.18
const TYPE_SPEED_MULTIPLIER: float = 1.7
const PARAGRAPHS := [
	[
		"Maestros del engaño,",
		"expertos en trampas y persecución.",
	],
	[
		"Podrías hacerte daño,",
		"incluso escapando de cada rincón.",
	],
	[
		"Cazadores implacables,",
		"en una carrera como nunca antes viste.",
	],
	[
		"No confies en sus caras amigables,",
		"aunque Mati diga: \"Que me trajiste?\"",
	],
]

var input_blocked: bool = false
var _elapsed: float = 0.0
var _finished: bool = false


func open() -> void:
	_elapsed = 0.0
	_finished = false
	show()
	progress_changed.emit(0.0)
	queue_redraw()


func _process(delta: float) -> void:
	if not visible or _finished:
		return
	_elapsed += delta
	progress_changed.emit(clampf(_elapsed / TOTAL_DURATION, 0.0, 1.0))
	if _elapsed >= TOTAL_DURATION:
		_finished = true
		progress_changed.emit(1.0)
		intro_finished.emit()
		return
	queue_redraw()


func _draw() -> void:
	var screen := get_viewport_rect().size
	var font := ThemeDB.fallback_font
	draw_rect(Rect2(Vector2.ZERO, screen), Color(0.0, 0.0, 0.0, 1.0))

	var progress := clampf(_elapsed / TEXT_DURATION, 0.0, 1.0)
	var glow := 0.5 + 0.5 * sin(_elapsed * 1.2)
	draw_rect(Rect2(Vector2.ZERO, screen), Color(0.04, 0.02, 0.015, 0.18 + 0.04 * glow))

	var font_size := 30
	var line_h := 39.0
	var total_h := line_h * 2.0
	var y := maxf(90.0, (screen.y - total_h) / 2.0)
	var paragraph_duration := _get_paragraph_duration()
	var current_paragraph_index := _get_current_paragraph_index(paragraph_duration)
	var current_cursor_line := _get_current_cursor_line(paragraph_duration)

	var paragraph: Array = PARAGRAPHS[current_paragraph_index]
	var paragraph_start := float(current_paragraph_index) * (paragraph_duration + PARAGRAPH_PAUSE)
	var paragraph_elapsed := _elapsed - paragraph_start
	var visible_lines := _get_visible_paragraph_lines(paragraph, paragraph_elapsed, paragraph_duration)
	var paragraph_alpha := 1.0
	if paragraph_elapsed < 0.25:
		paragraph_alpha = clampf(paragraph_elapsed / 0.25, 0.0, 1.0)

	for line_index in paragraph.size():
		var text := visible_lines[line_index] as String
		if not text.is_empty():
			var full_line := paragraph[line_index] as String
			var full_text_size := font.get_string_size(full_line, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
			var text_size := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
			var pos := Vector2((screen.x - full_text_size.x) / 2.0, y)
			_draw_intro_line(font, text, pos, font_size, paragraph_alpha)
			if current_cursor_line == Vector2i(current_paragraph_index, line_index):
				_draw_cursor(font, pos + Vector2(text_size.x + 8.0, 0.0), font_size)
		y += line_h

	var fade_start := TOTAL_DURATION - FADE_DURATION
	var fade_progress := clampf((_elapsed - fade_start) / FADE_DURATION, 0.0, 1.0)
	var fade_alpha := fade_progress * fade_progress * (3.0 - 2.0 * fade_progress)
	if fade_alpha > 0.0:
		draw_rect(Rect2(Vector2.ZERO, screen), Color(0.0, 0.0, 0.0, fade_alpha))

	var ember_alpha := 0.08 + 0.06 * sin(_elapsed * 1.8)
	draw_line(Vector2(screen.x * 0.18, screen.y * 0.12), Vector2(screen.x * 0.82, screen.y * 0.12),
		Color(1.0, 0.22, 0.08, ember_alpha), 2.0)
	draw_line(Vector2(screen.x * 0.18, screen.y * 0.88), Vector2(screen.x * 0.82, screen.y * 0.88),
		Color(0.25, 0.65, 1.0, ember_alpha), 2.0)
	_draw_progress_bar(screen, progress)


func _draw_intro_line(font: Font, text: String, pos: Vector2, font_size: int, alpha: float) -> void:
	var shadow := Color(0.0, 0.0, 0.0, 0.82 * alpha)
	draw_string(font, pos + Vector2(2.0, 2.0),
		text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, shadow)
	draw_string(font, pos,
		text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color(0.95, 0.9, 0.78, alpha))


func _draw_cursor(font: Font, pos: Vector2, font_size: int) -> void:
	var blink := 0.45 + 0.55 * maxf(0.0, sin(_elapsed * TAU * 1.6))
	draw_string(font, pos, "_", HORIZONTAL_ALIGNMENT_LEFT, -1, font_size,
		Color(1.0, 0.72, 0.2, blink))


func _draw_progress_bar(screen: Vector2, progress: float) -> void:
	var bar_w := minf(440.0, screen.x - 140.0)
	var bar_h := 4.0
	var bar_pos := Vector2((screen.x - bar_w) / 2.0, screen.y - 58.0)
	draw_rect(Rect2(bar_pos, Vector2(bar_w, bar_h)), Color(1.0, 1.0, 1.0, 0.12))
	draw_rect(Rect2(bar_pos, Vector2(bar_w * progress, bar_h)), Color(1.0, 0.56, 0.14, 0.72))


func _get_paragraph_duration() -> float:
	var pauses := PARAGRAPH_PAUSE * float(PARAGRAPHS.size() - 1)
	return (TEXT_DURATION - pauses) / float(PARAGRAPHS.size())


func _get_current_paragraph_index(paragraph_duration: float) -> int:
	var cycle_duration := paragraph_duration + PARAGRAPH_PAUSE
	return mini(int(floor(_elapsed / cycle_duration)), PARAGRAPHS.size() - 1)


func _get_visible_paragraph_lines(paragraph: Array, elapsed: float, paragraph_duration: float) -> Array[String]:
	var lines: Array[String] = ["", ""]
	if elapsed <= 0.0:
		return lines
	if elapsed >= paragraph_duration:
		var full_lines: Array[String] = [paragraph[0] as String, paragraph[1] as String]
		return full_lines

	var line_duration := (paragraph_duration - LINE_PAUSE) / 2.0
	if elapsed <= line_duration:
		lines[0] = _take_visible_chars(paragraph[0] as String, (elapsed / line_duration) * TYPE_SPEED_MULTIPLIER)
		return lines

	lines[0] = paragraph[0] as String
	if elapsed <= line_duration + LINE_PAUSE:
		return lines

	lines[1] = _take_visible_chars(paragraph[1] as String,
		((elapsed - line_duration - LINE_PAUSE) / line_duration) * TYPE_SPEED_MULTIPLIER)
	return lines


func _take_visible_chars(text: String, ratio: float) -> String:
	var count := int(floor(float(text.length()) * clampf(ratio, 0.0, 1.0)))
	return text.substr(0, count)


func _get_current_cursor_line(paragraph_duration: float) -> Vector2i:
	for paragraph_index in PARAGRAPHS.size():
		var paragraph_start := float(paragraph_index) * (paragraph_duration + PARAGRAPH_PAUSE)
		var paragraph_elapsed := _elapsed - paragraph_start
		if paragraph_elapsed < 0.0 or paragraph_elapsed >= paragraph_duration:
			continue
		var line_duration := (paragraph_duration - LINE_PAUSE) / 2.0
		if paragraph_elapsed <= line_duration:
			return Vector2i(paragraph_index, 0)
		if paragraph_elapsed > line_duration + LINE_PAUSE:
			return Vector2i(paragraph_index, 1)
	return Vector2i(-1, -1)
