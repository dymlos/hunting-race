extends Node

const MIX_RATE: int = 22050
const BUFFER_LENGTH: float = 0.08
const TAU_F: float = PI * 2.0

var _player: AudioStreamPlayer
var _playback: AudioStreamGeneratorPlayback
var _voices: Array[Dictionary] = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_player = AudioStreamPlayer.new()
	var generator := AudioStreamGenerator.new()
	generator.mix_rate = MIX_RATE
	generator.buffer_length = BUFFER_LENGTH
	_player.stream = generator
	_player.volume_db = -1.0
	add_child(_player)
	_player.play()
	_playback = _player.get_stream_playback() as AudioStreamGeneratorPlayback


func play_skill(skill_name: StringName) -> void:
	_voices.append(_make_voice(skill_name))
	if not _player.playing:
		_player.play()
		_playback = _player.get_stream_playback() as AudioStreamGeneratorPlayback


func _process(_delta: float) -> void:
	_fill_buffer()


func _fill_buffer() -> void:
	if not _playback:
		return
	var frames := _playback.get_frames_available()
	for i in range(frames):
		_playback.push_frame(Vector2.ONE * _next_sample())


func _make_voice(skill_name: StringName) -> Dictionary:
	var name := String(skill_name)
	var voice := {
		"name": name,
		"t": 0.0,
		"duration": 0.32,
		"phase": 0.0,
		"phase2": 0.0,
		"freq": 440.0,
		"freq2": 660.0,
		"volume": 0.20,
		"style": &"pluck",
	}

	match name:
		"RabbitLeap":
			voice.merge({"duration": 0.34, "freq": 520.0, "freq2": 960.0, "volume": 0.24, "style": &"sweep"}, true)
		"RatWhipOut":
			voice.merge({"duration": 0.20, "freq": 720.0, "freq2": 240.0, "volume": 0.24, "style": &"whip"}, true)
		"RatWhipReturn":
			voice.merge({"duration": 0.18, "freq": 840.0, "freq2": 180.0, "volume": 0.22, "style": &"whip"}, true)
		"SquirrelAcorn":
			voice.merge({"duration": 0.24, "freq": 760.0, "freq2": 1120.0, "volume": 0.20, "style": &"wood"}, true)
		"FlyCounter":
			voice.merge({"duration": 0.42, "freq": 430.0, "freq2": 830.0, "volume": 0.17, "style": &"buzz"}, true)
		"FlyBoost":
			voice.merge({"duration": 0.34, "freq": 650.0, "freq2": 1280.0, "volume": 0.18, "style": &"rise"}, true)
		"Web", "Elastic":
			voice.merge({"duration": 0.30, "freq": 380.0, "freq2": 520.0, "volume": 0.18, "style": &"sticky"}, true)
		"Venom", "Spores", "Confuse":
			voice.merge({"duration": 0.48, "freq": 150.0, "freq2": 720.0, "volume": 0.15, "style": &"cloud"}, true)
		"Teleport":
			voice.merge({"duration": 0.46, "freq": 620.0, "freq2": 1240.0, "volume": 0.17, "style": &"shimmer"}, true)
		"Stinger":
			voice.merge({"duration": 0.20, "freq": 920.0, "freq2": 170.0, "volume": 0.21, "style": &"sting"}, true)
		"Pincers":
			voice.merge({"duration": 0.24, "freq": 180.0, "freq2": 820.0, "volume": 0.22, "style": &"clack"}, true)
		"Quicksand":
			voice.merge({"duration": 0.44, "freq": 115.0, "freq2": 210.0, "volume": 0.18, "style": &"mud"}, true)
		"Tentacle", "Ink", "Current":
			voice.merge({"duration": 0.42, "freq": 240.0, "freq2": 520.0, "volume": 0.16, "style": &"water"}, true)
		"EscapeHeartbeat":
			voice.merge({"duration": 2.35, "freq": 58.0, "freq2": 92.0, "volume": 0.42, "style": &"heartbeat"}, true)

	return voice


func _next_sample() -> float:
	var sample := 0.0
	var i := _voices.size() - 1
	while i >= 0:
		var voice := _voices[i]
		var duration: float = voice["duration"]
		var t: float = voice["t"]
		if t >= duration:
			_voices.remove_at(i)
			i -= 1
			continue

		var ratio := t / duration
		var freq := _current_freq(voice, ratio)
		var freq2: float = voice["freq2"]
		voice["phase"] = fmod((voice["phase"] as float) + freq / MIX_RATE, 1.0)
		voice["phase2"] = fmod((voice["phase2"] as float) + freq2 / MIX_RATE, 1.0)
		sample += _voice_sample(voice, ratio) * (voice["volume"] as float)
		voice["t"] = t + 1.0 / MIX_RATE
		_voices[i] = voice
		i -= 1
	return clampf(sample, -0.9, 0.9)


func _current_freq(voice: Dictionary, ratio: float) -> float:
	var freq: float = voice["freq"]
	var freq2: float = voice["freq2"]
	match voice["style"]:
		&"sweep", &"rise", &"shimmer":
			return lerpf(freq, freq2, ratio)
		&"twang", &"mud":
			return lerpf(freq, freq2, ratio)
		&"whip":
			return lerpf(freq, freq2, ratio)
	return freq


func _voice_sample(voice: Dictionary, ratio: float) -> float:
	var phase: float = voice["phase"]
	var phase2: float = voice["phase2"]
	var env := _env(ratio)
	match voice["style"]:
		&"sweep":
			return (sin(phase * TAU_F) + sin(phase2 * TAU_F) * 0.22) * env
		&"twang":
			return (sin(phase * TAU_F) + _soft_square(phase2) * 0.28) * _fast_env(ratio)
		&"whip":
			var snap := sin(phase * TAU_F * 2.0)
			var crack := _soft_square(fmod(phase2 + ratio * 0.35, 1.0))
			return (snap * 0.82 + crack * 0.38) * _click_env(ratio)
		&"wood":
			return (sin(phase * TAU_F) * 0.7 + sin(phase2 * TAU_F) * 0.35) * _click_env(ratio)
		&"buzz":
			var wobble := sin(ratio * TAU_F * 8.0) * 0.15
			return (_soft_square(fmod(phase + wobble, 1.0)) * 0.55 + sin(phase2 * TAU_F) * 0.18) * env
		&"rise":
			return (sin(phase * TAU_F) + sin(phase2 * TAU_F) * 0.3) * _fast_env(ratio)
		&"sticky":
			return (sin(phase * TAU_F) - sin(phase2 * TAU_F) * 0.25) * _fast_env(ratio)
		&"cloud":
			return (sin(phase * TAU_F) * 0.28 + _soft_square(phase2) * 0.24) * _slow_env(ratio)
		&"shimmer":
			return (sin(phase * TAU_F) * 0.5 + sin(phase2 * TAU_F) * 0.45) * env
		&"sting":
			return (sin(phase * TAU_F) * 0.65 + _soft_square(phase2) * 0.25) * _click_env(ratio)
		&"clack":
			return (_soft_square(phase) * 0.38 + sin(phase2 * TAU_F) * 0.35) * _click_env(ratio)
		&"mud":
			return (sin(phase * TAU_F) * 0.45 + sin(phase2 * TAU_F) * 0.18) * _slow_env(ratio)
		&"water":
			return (sin(phase * TAU_F) * 0.32 + sin(phase2 * TAU_F) * 0.24) * _slow_env(ratio)
		&"heartbeat":
			return _heartbeat_sample(phase, phase2, ratio)
	return sin(phase * TAU_F) * env


func _env(ratio: float) -> float:
	var attack := clampf(ratio / 0.12, 0.0, 1.0)
	return attack * pow(1.0 - ratio, 1.8)


func _fast_env(ratio: float) -> float:
	var attack := clampf(ratio / 0.06, 0.0, 1.0)
	return attack * pow(1.0 - ratio, 2.5)


func _slow_env(ratio: float) -> float:
	var attack := clampf(ratio / 0.18, 0.0, 1.0)
	return attack * pow(1.0 - ratio, 1.2)


func _click_env(ratio: float) -> float:
	var attack := clampf(ratio / 0.025, 0.0, 1.0)
	return attack * pow(1.0 - ratio, 4.0)


func _heartbeat_sample(phase: float, phase2: float, ratio: float) -> float:
	var beat_time := fmod(ratio * 3.2, 1.0)
	var fade := pow(1.0 - ratio, 0.42)
	var first := _heart_thump(beat_time, 0.08, 0.13)
	var second := _heart_thump(beat_time, 0.27, 0.11) * 0.78
	var tail := _heart_thump(beat_time, 0.42, 0.20) * 0.18
	var body := sin(phase * TAU_F) * 0.78 + sin(phase2 * TAU_F) * 0.22
	return body * (first + second + tail) * fade


func _heart_thump(ratio: float, center: float, width: float) -> float:
	var distance := absf(ratio - center) / width
	return pow(maxf(0.0, 1.0 - distance), 2.35)


func _soft_square(phase: float) -> float:
	var raw := 1.0 if phase < 0.5 else -1.0
	return raw * 0.35 + sin(phase * TAU_F) * 0.65
