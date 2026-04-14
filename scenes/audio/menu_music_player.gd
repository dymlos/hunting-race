class_name MenuMusicPlayer
extends AudioStreamPlayer

const MIX_RATE: int = 22050
const BUFFER_LENGTH: float = 0.35
const STEP_SECONDS: float = 0.34
const ROOT_FREQ: float = 110.0
const GAIN: float = 0.135
const TAU_F: float = PI * 2.0
const MENU_VOLUME_DB: float = -3.0
const ROUND_VOLUME_DB: float = -12.0

var _playback: AudioStreamGeneratorPlayback
var _sample_time: float = 0.0
var _lead_phase: float = 0.0
var _counter_phase: float = 0.0
var _bass_phase: float = 0.0
var _pad_phase: float = 0.0
var _drone_phase: float = 0.0
var _pulse_phase: float = 0.0

var _melody: Array[int] = [0, 3, 7, 10, 7, 3, 0, -2, -5, -2, 3, 7, 6, 3, -2, -7]
var _counter_melody: Array[int] = [12, 10, 7, 3, 15, 12, 10, 6]
var _bass: Array[int] = [-24, -24, -17, -24, -21, -21, -19, -24]


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var generator := AudioStreamGenerator.new()
	generator.mix_rate = MIX_RATE
	generator.buffer_length = BUFFER_LENGTH
	stream = generator
	volume_db = MENU_VOLUME_DB


func start_music() -> void:
	if playing:
		return
	play()
	_playback = get_stream_playback() as AudioStreamGeneratorPlayback
	_fill_buffer()


func stop_music() -> void:
	if not playing:
		return
	stop()
	_playback = null


func use_menu_volume() -> void:
	volume_db = MENU_VOLUME_DB


func use_round_volume() -> void:
	volume_db = ROUND_VOLUME_DB


func _process(_delta: float) -> void:
	if playing:
		_fill_buffer()


func _fill_buffer() -> void:
	if not _playback:
		return
	var frames := _playback.get_frames_available()
	for i in range(frames):
		var sample := _next_sample()
		_playback.push_frame(Vector2(sample, sample))


func _next_sample() -> float:
	var step_index := int(_sample_time / STEP_SECONDS)
	var beat_time := fmod(_sample_time, STEP_SECONDS) / STEP_SECONDS
	var lead_freq := _note_to_freq(ROOT_FREQ, _melody[step_index % _melody.size()])
	var counter_freq := _note_to_freq(ROOT_FREQ, _counter_melody[step_index % _counter_melody.size()])
	var bass_freq := _note_to_freq(ROOT_FREQ, _bass[int(step_index / 2) % _bass.size()])
	var pad_freq := _note_to_freq(ROOT_FREQ, -12)
	var drone_freq := _note_to_freq(ROOT_FREQ, -24)
	var pulse_freq := _note_to_freq(ROOT_FREQ, -36)

	_lead_phase = fmod(_lead_phase + lead_freq / MIX_RATE, 1.0)
	_counter_phase = fmod(_counter_phase + counter_freq / MIX_RATE, 1.0)
	_bass_phase = fmod(_bass_phase + bass_freq / MIX_RATE, 1.0)
	_pad_phase = fmod(_pad_phase + pad_freq / MIX_RATE, 1.0)
	_drone_phase = fmod(_drone_phase + drone_freq / MIX_RATE, 1.0)
	_pulse_phase = fmod(_pulse_phase + pulse_freq / MIX_RATE, 1.0)

	var lead_env := _pluck_envelope(beat_time)
	var accent := 1.45 if step_index % 4 == 0 else 1.0
	if step_index % 8 == 6:
		accent = 1.25
	var pulse_env := pow(maxf(0.0, 1.0 - beat_time), 2.8)
	var slow_wobble := 0.65 + 0.35 * sin(_sample_time * TAU_F * 0.12)
	var lead := _piano_tone(_lead_phase) * lead_env * 0.82 * accent
	var counter := _piano_tone(_counter_phase) * _short_piano_envelope(beat_time) * 0.32
	var bass := _soft_square(_bass_phase) * pulse_env * 0.52
	var pad := (
		sin(_pad_phase * TAU_F)
		+ sin(_pad_phase * TAU_F * 1.5) * 0.35
	) * 0.16 * slow_wobble
	var drone := sin(_drone_phase * TAU_F) * 0.24
	var pulse := sin(_pulse_phase * TAU_F) * pulse_env * 0.34
	var shimmer := sin(_lead_phase * TAU_F * 2.0) * lead_env * 0.11

	_sample_time += 1.0 / MIX_RATE
	return clampf((lead + counter + shimmer + bass + pad + drone + pulse) * GAIN, -0.95, 0.95)


func _note_to_freq(root_freq: float, semitone_offset: int) -> float:
	return root_freq * pow(2.0, float(semitone_offset) / 12.0)


func _pluck_envelope(beat_time: float) -> float:
	var attack := clampf(beat_time / 0.025, 0.0, 1.0)
	var decay := exp(-beat_time * 3.35)
	return attack * decay


func _short_piano_envelope(beat_time: float) -> float:
	var attack := clampf(beat_time / 0.018, 0.0, 1.0)
	var decay := exp(-beat_time * 7.0)
	return attack * decay


func _piano_tone(phase: float) -> float:
	return (
		sin(phase * TAU_F)
		+ sin(phase * TAU_F * 2.0) * 0.42
		+ sin(phase * TAU_F * 3.0) * 0.18
		+ sin(phase * TAU_F * 5.0) * 0.08
	) * 0.58


func _soft_square(phase: float) -> float:
	var raw := 1.0 if phase < 0.5 else -1.0
	return raw * 0.42 + sin(phase * TAU_F) * 0.58
