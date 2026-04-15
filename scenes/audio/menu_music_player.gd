class_name MenuMusicPlayer
extends AudioStreamPlayer

const MENU_MUSIC_PATH: String = "res://Musica y sonidos/Pixel Critter Chase OGG.ogg"
const MENU_VOLUME_DB: float = -3.0
const ROUND_VOLUME_DB: float = -12.0

var _music: AudioStream = preload(MENU_MUSIC_PATH)


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	stream = _music
	volume_db = MENU_VOLUME_DB
	finished.connect(_on_finished)


func start_music() -> void:
	if not playing:
		play()


func stop_music() -> void:
	if playing:
		stop()


func use_menu_volume() -> void:
	volume_db = MENU_VOLUME_DB


func use_round_volume() -> void:
	volume_db = ROUND_VOLUME_DB


func _on_finished() -> void:
	if stream == _music:
		play()
