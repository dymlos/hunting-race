class_name MenuMusicPlayer
extends AudioStreamPlayer

const MENU_MUSIC_PATH: String = "res://Musica y sonidos/Pixel Critter Chase OGG.ogg"
const INTRO_MIN_MULTIPLIER: float = 0.65
const MENU_VOLUME_DB: float = -3.0
const ROUND_VOLUME_DB: float = -12.0

var _music: AudioStream = preload(MENU_MUSIC_PATH)
var _base_volume_db: float = MENU_VOLUME_DB
var _music_volume: float = 1.0
var _intro_multiplier: float = 1.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	stream = _music
	_apply_volume()
	finished.connect(_on_finished)


func start_music() -> void:
	if not playing:
		play()


func stop_music() -> void:
	if playing:
		stop()


func use_intro_volume() -> void:
	_base_volume_db = MENU_VOLUME_DB
	_intro_multiplier = INTRO_MIN_MULTIPLIER
	_apply_volume()


func use_menu_volume() -> void:
	_base_volume_db = MENU_VOLUME_DB
	_intro_multiplier = 1.0
	_apply_volume()


func use_round_volume() -> void:
	_base_volume_db = ROUND_VOLUME_DB
	_intro_multiplier = 1.0
	_apply_volume()


func set_music_volume(value: float) -> void:
	_music_volume = clampf(value, 0.0, 1.0)
	_apply_volume()


func set_intro_progress(value: float) -> void:
	var progress := clampf(value, 0.0, 1.0)
	var eased := progress * progress * (3.0 - 2.0 * progress)
	_intro_multiplier = lerpf(INTRO_MIN_MULTIPLIER, 1.0, eased)
	_apply_volume()


func _apply_volume() -> void:
	var effective_volume := _music_volume * _intro_multiplier
	if effective_volume <= 0.0:
		volume_db = -80.0
	else:
		volume_db = _base_volume_db + linear_to_db(effective_volume)


func _on_finished() -> void:
	if stream == _music:
		play()
