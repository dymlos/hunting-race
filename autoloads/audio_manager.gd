extends Node

const MIX_RATE: int = 22050
const BUFFER_LENGTH: float = 0.08
const TAU_F: float = PI * 2.0

var _player: AudioStreamPlayer
var _playback: AudioStreamGeneratorPlayback
var _voices: Array[Dictionary] = []
var _sample_streams: Dictionary = {}

const SAMPLE_PATHS: Dictionary = {
	&"RabbitLeap": "res://Musica y sonidos/Rabbit Charged Leap.wav",
	&"RatWhipOut": "res://Musica y sonidos/Rat Rescue Tail.wav",
	&"AcornThrow": "res://Musica y sonidos/Squirrel Ricochet Acorn.wav",
	&"FlyCounter": "res://Musica y sonidos/Fly Adrenaline Reflex.wav",
	&"DeathRespawn": "res://Musica y sonidos/Efecto al morirse y respawnear.wav",
	&"StickyWall": "res://Musica y sonidos/Efecto al pegarse en una Sticky Wall.wav",
	&"WaterCurrentStep": "res://Musica y sonidos/Efecto de corriente de agua al ser pisada.wav",
	&"Poison": "res://Musica y sonidos/Efecto de envenenamiento.wav",
	&"PoisonCure": "res://Musica y sonidos/Efecto de curar envenenamiento.wav",
	&"Immobilize": "res://Musica y sonidos/Efecto de inmovilización.wav",
	&"PincersClose": "res://Musica y sonidos/Efecto de las dos tenazas que se cierran.wav",
	&"Bounce": "res://Musica y sonidos/Efecto de rebote.wav",
	&"SlowMovement": "res://Musica y sonidos/Efecto de relentización de movimiento.wav",
	&"ConfuseTrap": "res://Musica y sonidos/Efecto de trampa de controles invertidos.wav",
	&"QuicksandTrap": "res://Musica y sonidos/Efecto de trampa de remolino (quicksand).wav",
}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_load_sample_streams()
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
	if _play_sample(skill_name):
		return
	if skill_name != &"EscapeHeartbeat":
		return
	_voices.append(_make_voice(skill_name))
	if not _player.playing:
		_player.play()
		_playback = _player.get_stream_playback() as AudioStreamGeneratorPlayback


func play_effect(effect_name: StringName) -> void:
	_play_sample(effect_name)


func _load_sample_streams() -> void:
	for sample_name: StringName in SAMPLE_PATHS:
		var path: String = SAMPLE_PATHS[sample_name] as String
		var stream := load(path) as AudioStream
		if stream == null:
			push_warning("Audio sample not found: %s" % path)
			continue
		_sample_streams[sample_name] = stream


func _play_sample(sample_name: StringName) -> bool:
	if not _sample_streams.has(sample_name):
		return false
	var player := AudioStreamPlayer.new()
	player.stream = _sample_streams[sample_name] as AudioStream
	player.volume_db = -1.0
	player.finished.connect(player.queue_free)
	add_child(player)
	player.play()
	return true


func _process(_delta: float) -> void:
	_fill_buffer()


func _fill_buffer() -> void:
	if not _playback:
		return
	var frames := _playback.get_frames_available()
	for i in range(frames):
		_playback.push_frame(Vector2.ONE * _next_sample())


func _make_voice(_skill_name: StringName) -> Dictionary:
	return {
		"t": 0.0,
		"duration": 2.35,
		"phase": 0.0,
		"phase2": 0.0,
		"freq": 58.0,
		"freq2": 92.0,
		"volume": 0.42,
	}


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


func _current_freq(voice: Dictionary, _ratio: float) -> float:
	return voice["freq"] as float


func _voice_sample(voice: Dictionary, ratio: float) -> float:
	var phase: float = voice["phase"]
	var phase2: float = voice["phase2"]
	return _heartbeat_sample(phase, phase2, ratio)


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
