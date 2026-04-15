class_name MenuMusicPlayer
extends AudioStreamPlayer

const MIX_RATE: int = 22050
const BUFFER_LENGTH: float = 0.35
const STEP_SECONDS: float = 0.34
const LOOP_STEPS: int = 64
const SECTION_STEPS: int = 16
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
var _variation_one_lead: Array[int] = [0, 3, 7, 10, 12, 10, 7, 3, 0, -2, 3, 7, 10, 7, 3, 0]
var _variation_one_counter: Array[int] = [15, 12, 10, 7, 15, 12, 10, 6, 17, 15, 12, 10, 15, 12, 10, 7]
var _variation_one_bass: Array[int] = [-24, -24, -21, -24, -19, -19, -21, -24, -24, -21, -19, -17, -19, -21, -24, -24]
var _variation_two_lead: Array[int] = [0, -2, 3, 7, 10, 7, 3, 0, -5, -2, 3, 6, 10, 6, 3, -2]
var _variation_two_counter: Array[int] = [12, 15, 17, 15, 12, 10, 7, 6, 12, 15, 17, 15, 10, 7, 6, 3]
var _variation_two_bass: Array[int] = [-24, -21, -19, -24, -24, -21, -19, -17, -24, -24, -21, -19, -17, -19, -21, -24]


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
	var loop_step := step_index % LOOP_STEPS
	var section := int(loop_step / SECTION_STEPS)
	var section_step := loop_step % SECTION_STEPS
	var beat_time := fmod(_sample_time, STEP_SECONDS) / STEP_SECONDS

	var lead_note := _pattern_note(section, section_step, _melody, _variation_one_lead, _variation_two_lead)
	var counter_note := _pattern_note(section, section_step, _counter_melody, _variation_one_counter, _variation_two_counter)
	var bass_step := int(step_index / 2) if section == 0 or section == 2 else section_step
	var bass_note := _pattern_note(section, bass_step, _bass, _variation_one_bass, _variation_two_bass)

	var lead_freq := _note_to_freq(ROOT_FREQ, lead_note)
	var counter_freq := _note_to_freq(ROOT_FREQ, counter_note)
	var bass_freq := _note_to_freq(ROOT_FREQ, bass_note)
	var pad_freq := _note_to_freq(ROOT_FREQ, -12)
	var drone_freq := _note_to_freq(ROOT_FREQ, -24)
	var pulse_freq := _note_to_freq(ROOT_FREQ, -36)

	_lead_phase = fmod(_lead_phase + lead_freq / MIX_RATE, 1.0)
	_counter_phase = fmod(_counter_phase + counter_freq / MIX_RATE, 1.0)
	_bass_phase = fmod(_bass_phase + bass_freq / MIX_RATE, 1.0)
	_pad_phase = fmod(_pad_phase + pad_freq / MIX_RATE, 1.0)
	_drone_phase = fmod(_drone_phase + drone_freq / MIX_RATE, 1.0)
	_pulse_phase = fmod(_pulse_phase + pulse_freq / MIX_RATE, 1.0)

	var lead_env := _section_lead_envelope(section, beat_time, section_step)
	var counter_env := _section_counter_envelope(section, beat_time, section_step)
	var bass_env := _section_bass_envelope(section, beat_time, section_step)
	var pad_env := _section_pad_envelope(section, section_step)
	var pulse_env := _section_pulse_envelope(section, beat_time, section_step)
	var drone_env := _section_drone_envelope(section)

	var lead := _piano_tone(_lead_phase) * lead_env * 0.82 * _section_accent(section, section_step)
	var counter := _piano_tone(_counter_phase) * counter_env * 0.32
	var bass := _soft_square(_bass_phase) * bass_env * 0.52
	var pad := (
		sin(_pad_phase * TAU_F)
		+ sin(_pad_phase * TAU_F * 1.5) * 0.35
	) * pad_env * 0.16
	var drone := sin(_drone_phase * TAU_F) * drone_env
	var pulse := sin(_pulse_phase * TAU_F) * pulse_env * 0.34
	var shimmer := sin(_lead_phase * TAU_F * 2.0) * lead_env * 0.11

	_sample_time += 1.0 / MIX_RATE
	return clampf((lead + counter + shimmer + bass + pad + drone + pulse) * GAIN, -0.95, 0.95)


func _pattern_note(section: int, section_step: int, main_pattern: Array[int], variation_one: Array[int], variation_two: Array[int]) -> int:
	match section:
		0, 2:
			return main_pattern[section_step % main_pattern.size()]
		1:
			return variation_one[section_step % variation_one.size()]
		3:
			return variation_two[section_step % variation_two.size()]
	return main_pattern[section_step % main_pattern.size()]


func _section_accent(section: int, section_step: int) -> float:
	match section:
		1:
			return 1.16 if section_step % 4 == 1 or section_step % 4 == 3 else 0.94
		3:
			return 1.28 if section_step % 2 == 0 else 0.98
	return 1.45 if section_step % 4 == 0 else 1.0


func _section_lead_envelope(section: int, beat_time: float, section_step: int) -> float:
	var base := _pluck_envelope(beat_time)
	match section:
		1:
			return base * (1.0 if section_step % 4 != 2 else 0.72)
		3:
			return base * (1.0 if section_step % 3 != 1 else 0.66)
	return base


func _section_counter_envelope(section: int, beat_time: float, section_step: int) -> float:
	var base := _short_piano_envelope(beat_time)
	match section:
		1:
			return base * (1.0 if section_step % 2 == 0 else 0.55)
		3:
			return base * (1.0 if section_step % 4 < 2 else 0.48)
	return base * 0.94


func _section_bass_envelope(section: int, beat_time: float, section_step: int) -> float:
	var pulse := pow(maxf(0.0, 1.0 - beat_time), 2.8)
	match section:
		1:
			return pulse * (1.12 if section_step % 4 == 0 or section_step % 4 == 3 else 0.92)
		3:
			return pulse * (1.22 if section_step % 2 == 0 else 0.88)
	return pulse


func _section_pad_envelope(section: int, section_step: int) -> float:
	var wobble := 0.65 + 0.35 * sin(_sample_time * TAU_F * 0.12)
	match section:
		1:
			return wobble * (0.20 if section_step % 4 == 1 else 0.12)
		3:
			return wobble * (0.18 if section_step % 4 == 0 or section_step % 4 == 3 else 0.10)
	return wobble * 0.24


func _section_pulse_envelope(section: int, beat_time: float, section_step: int) -> float:
	var pulse_env := pow(maxf(0.0, 1.0 - beat_time), 2.8)
	match section:
		1:
			return pulse_env * (0.62 if section_step % 2 == 0 else 0.28)
		3:
			return pulse_env * (0.78 if section_step % 4 == 0 or section_step % 4 == 2 else 0.36)
	return pulse_env * 0.34


func _section_drone_envelope(section: int) -> float:
	match section:
		1:
			return 0.18
		3:
			return 0.14
	return 0.24


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
