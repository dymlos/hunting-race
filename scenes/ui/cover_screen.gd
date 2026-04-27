class_name CoverScreen
extends Control

signal start_requested

const COVER_TEXTURE := preload("res://assets/ui/cover.png")

var input_blocked: bool = false
var _prompt_time: float = 0.0


func open() -> void:
	_prompt_time = 0.0
	show()
	queue_redraw()


func _process(delta: float) -> void:
	if not visible or input_blocked:
		return
	_prompt_time += delta
	queue_redraw()
	if Input.is_key_pressed(KEY_ENTER) or Input.is_key_pressed(KEY_SPACE):
		start_requested.emit()
		return
	for device_id in Input.get_connected_joypads():
		if InputManager.is_button_just_pressed_on_device(device_id, JOY_BUTTON_START):
			start_requested.emit()
			return


func _draw() -> void:
	var screen := get_viewport_rect().size
	draw_rect(Rect2(Vector2.ZERO, screen), Color.BLACK)

	var texture_size := COVER_TEXTURE.get_size()
	var scale := minf(screen.x / texture_size.x, screen.y / texture_size.y)
	var draw_size := texture_size * scale
	var draw_position := (screen - draw_size) / 2.0
	draw_texture_rect(COVER_TEXTURE, Rect2(draw_position, draw_size), false)

	var prompt := "Presiona Start"
	var font := ThemeDB.fallback_font
	var beat := pow(maxf(0.0, sin(_prompt_time * TAU * 1.25)), 6.0)
	beat += pow(maxf(0.0, sin(_prompt_time * TAU * 1.25 - 0.55)), 8.0) * 0.45
	beat = clampf(beat, 0.0, 1.0)
	var prompt_alpha := lerpf(0.42, 1.0, beat)
	var font_size := 22 + int(round(beat * 4.0))
	var prompt_size := font.get_string_size(prompt, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
	var prompt_pos := Vector2((screen.x - prompt_size.x) / 2.0, screen.y - 44.0)
	draw_rect(Rect2(Vector2(0.0, screen.y - 78.0), Vector2(screen.x, 78.0)), Color(0.0, 0.0, 0.0, 0.55))
	draw_string(font, prompt_pos + Vector2(2.0, 2.0),
		prompt, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color(0.0, 0.0, 0.0, 0.75 * prompt_alpha))
	draw_string(font, prompt_pos,
		prompt, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color(1.0, 0.9, 0.25, prompt_alpha))
