class_name RoundReplay
extends Node2D

signal finished

const MIN_PLAY_SECONDS: float = 2.4
const MAX_PLAY_SECONDS: float = 8.0
const TRAIL_WIDTH: float = 5.0
const GHOST_RADIUS: float = 18.0

var _track: Dictionary = {}
var _positions: Array = []
var _times: Array = []
var _events: Array = []
var _rivals: Array = []
var _color: Color = Color.WHITE
var _label: String = ""
var _is_trapper_replay: bool = false
var _source_start_time: float = 0.0
var _source_duration: float = 0.0
var _play_duration: float = 0.0
var _elapsed: float = 0.0
var _playing: bool = false


func _ready() -> void:
	hide()
	set_process(false)


func play(track: Dictionary) -> void:
	_track = track.duplicate(true)
	_positions = _track.get("positions", []) as Array
	_times = _track.get("times", []) as Array
	_events = _track.get("events", []) as Array
	_rivals = _track.get("rivals", []) as Array
	_color = _track.get("color", Color.WHITE) as Color
	_label = _track.get("label", "ESCAPE MÁS RÁPIDO") as String
	_is_trapper_replay = (_track.get("role", Enums.Role.NONE) as Enums.Role) == Enums.Role.TRAPPER
	var requested_start := _track.get("playback_start_time", _get_source_start_time()) as float
	_source_start_time = maxf(requested_start, _get_source_start_time())
	_source_duration = _get_source_duration()
	_play_duration = clampf(_source_duration * 0.55, MIN_PLAY_SECONDS, MAX_PLAY_SECONDS)
	_elapsed = 0.0
	_playing = _positions.size() >= 2 and _times.size() >= 2 and _source_duration > 0.0
	visible = _playing
	set_process(_playing)
	queue_redraw()
	if not _playing:
		finished.emit()


func stop() -> void:
	_playing = false
	hide()
	set_process(false)
	queue_redraw()


func _process(delta: float) -> void:
	if not _playing:
		return
	_elapsed += delta
	queue_redraw()
	if _elapsed >= _play_duration:
		stop()
		finished.emit()


func _draw() -> void:
	if not _playing or _positions.size() < 2:
		return

	var progress := clampf(_elapsed / maxf(_play_duration, 0.001), 0.0, 1.0)
	var source_time := _source_start_time + progress * _source_duration
	var current_pos := _position_at_time(source_time)
	var pulse := 0.5 + 0.5 * sin(_elapsed * 9.0)

	_draw_rivals(source_time)
	_draw_full_trail()
	_draw_played_trail(source_time)
	_draw_event_markers(source_time)
	_draw_highlight(current_pos, pulse)


func _draw_full_trail() -> void:
	for i in range(_positions.size() - 1):
		draw_line(_positions[i] as Vector2, _positions[i + 1] as Vector2,
			Color(_color, 0.18), TRAIL_WIDTH)


func _draw_played_trail(source_time: float) -> void:
	for i in range(_positions.size() - 1):
		var t0 := _times[i] as float
		var t1 := _times[i + 1] as float
		if t0 > source_time:
			break
		var p0 := _positions[i] as Vector2
		var p1 := _positions[i + 1] as Vector2
		var end_pos := p1
		if t1 > source_time:
			var segment_t := inverse_lerp(t0, t1, source_time)
			end_pos = p0.lerp(p1, clampf(segment_t, 0.0, 1.0))
		draw_line(p0, end_pos, Color(_color, 0.9), TRAIL_WIDTH + 2.0)


func _draw_highlight(pos: Vector2, pulse: float) -> void:
	var ring_radius := GHOST_RADIUS + pulse * 8.0
	var core_radius := GHOST_RADIUS - 3.0 if _is_trapper_replay else GHOST_RADIUS
	draw_circle(pos, core_radius + 6.0, Color(_color, 0.18))
	draw_circle(pos, core_radius, Color(_color, 0.82))
	if _is_trapper_replay:
		draw_line(pos + Vector2(-16.0, 0.0), pos + Vector2(16.0, 0.0), Color.WHITE, 3.0)
		draw_line(pos + Vector2(0.0, -16.0), pos + Vector2(0.0, 16.0), Color.WHITE, 3.0)
	draw_arc(pos, ring_radius, 0.0, TAU, 48, Color(1.0, 1.0, 1.0, 0.95), 3.0)
	draw_arc(pos, ring_radius + 8.0, 0.0, TAU, 48, Color(_color, 0.55), 2.0)

	var font := ThemeDB.fallback_font
	var label_width := 230.0
	var label_pos := pos + Vector2(-label_width * 0.5, -GHOST_RADIUS - 42.0)
	draw_string(font, label_pos + Vector2(2.0, 2.0), _label,
		HORIZONTAL_ALIGNMENT_CENTER, label_width, 18, Color(0.0, 0.0, 0.0, 0.82))
	draw_string(font, label_pos, _label,
		HORIZONTAL_ALIGNMENT_CENTER, label_width, 18, Color(1.0, 1.0, 1.0))


func _draw_event_markers(source_time: float) -> void:
	if _events.is_empty():
		return
	var font := ThemeDB.fallback_font
	for event: Dictionary in _events:
		var event_time := event.get("time", 0.0) as float
		var event_pos := event.get("position", Vector2.ZERO) as Vector2
		var reached := event_time <= source_time
		var alpha := 0.95 if reached else 0.22
		var radius := 18.0 if reached else 11.0
		if reached:
			var burst := 0.5 + 0.5 * sin((_elapsed + event_time) * 12.0)
			radius += burst * 5.0
		draw_circle(event_pos, radius, Color(1.0, 0.2, 0.05, 0.16 * alpha))
		draw_arc(event_pos, radius, 0.0, TAU, 24, Color(1.0, 0.3, 0.1, alpha), 2.5)
		if reached:
			draw_string(font, event_pos + Vector2(-36.0, -24.0), "GOLPE",
				HORIZONTAL_ALIGNMENT_CENTER, 52.0, 14, Color(1.0, 0.92, 0.2, alpha))


func _draw_rivals(source_time: float) -> void:
	if _rivals.is_empty():
		return
	var font := ThemeDB.fallback_font
	for rival: Dictionary in _rivals:
		var rival_positions: Array = rival.get("positions", []) as Array
		var rival_times: Array = rival.get("times", []) as Array
		if rival_positions.is_empty() or rival_times.is_empty():
			continue
		var rival_color := rival.get("color", Color.WHITE) as Color
		var rival_role := rival.get("role", Enums.Role.NONE) as Enums.Role
		var player_index := rival.get("player_index", -1) as int
		var label := "P%d" % (player_index + 1) if player_index >= 0 and player_index < 100 else "BOT"
		var pos := _position_for_track(rival_positions, rival_times, source_time)
		if rival_role == Enums.Role.TRAPPER:
			_draw_rival_trapper(pos, rival_color)
		else:
			_draw_rival_escapist(pos, rival_color)
		draw_string(font, pos + Vector2(-24.0, -24.0), label,
			HORIZONTAL_ALIGNMENT_CENTER, 48.0, 11, Color(rival_color, 0.72))


func _draw_rival_escapist(pos: Vector2, rival_color: Color) -> void:
	draw_circle(pos, 12.0, Color(rival_color, 0.36))
	draw_arc(pos, 16.0, 0.0, TAU, 24, Color(rival_color, 0.62), 2.0)


func _draw_rival_trapper(pos: Vector2, rival_color: Color) -> void:
	draw_circle(pos, 10.0, Color(rival_color, 0.18))
	draw_line(pos + Vector2(-14.0, 0.0), pos + Vector2(14.0, 0.0), Color(rival_color, 0.68), 2.0)
	draw_line(pos + Vector2(0.0, -14.0), pos + Vector2(0.0, 14.0), Color(rival_color, 0.68), 2.0)
	draw_arc(pos, 13.0, 0.0, TAU, 20, Color(rival_color, 0.52), 1.6)


func _position_at_time(source_time: float) -> Vector2:
	return _position_for_track(_positions, _times, source_time)


func _position_for_track(positions: Array, times: Array, source_time: float) -> Vector2:
	if positions.is_empty() or times.is_empty():
		return Vector2.ZERO
	if source_time <= (times[0] as float):
		return positions[0] as Vector2
	for i in range(times.size() - 1):
		var t0 := times[i] as float
		var t1 := times[i + 1] as float
		if source_time <= t1:
			var p0 := positions[i] as Vector2
			var p1 := positions[i + 1] as Vector2
			var segment_t := inverse_lerp(t0, t1, source_time)
			return p0.lerp(p1, clampf(segment_t, 0.0, 1.0))
	return positions[positions.size() - 1] as Vector2


func _get_source_duration() -> float:
	if _times.size() < 2:
		return 0.0
	var end_time := _times[_times.size() - 1] as float
	return maxf(end_time - _source_start_time, 0.001)


func _get_source_start_time() -> float:
	if _times.is_empty():
		return 0.0
	return _times[0] as float
