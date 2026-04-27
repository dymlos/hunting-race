extends Node2D

## Main scene — orchestrates arena, characters, UI, and game state.

const TeamSetupScene := preload("res://scenes/ui/team_setup.tscn")
const IntroScreenScene := preload("res://scenes/ui/intro_screen.gd")
const CoverScreenScene := preload("res://scenes/ui/cover_screen.tscn")
const ModeSelectScene := preload("res://scenes/ui/mode_select.gd")
const HowToPlayScene := preload("res://scenes/ui/how_to_play.gd")
const PracticeSetupScene := preload("res://scenes/ui/practice_setup.gd")
const OfficialBriefingScene := preload("res://scenes/ui/official_briefing.gd")
const StageSelectScene := preload("res://scenes/ui/stage_select.tscn")
const EscapistSelectScene := preload("res://scenes/ui/escapist_select.tscn")
const CharacterSelectScene := preload("res://scenes/ui/character_select.tscn")
const SettingsMenuScene := preload("res://scenes/ui/settings_menu.tscn")
const PauseMenuScene := preload("res://scenes/ui/pause_menu.gd")
const ArenaScene := preload("res://scenes/arena/arena.tscn")
const PhaseOverlayScene := preload("res://scenes/ui/phase_overlay.tscn")
const GameHudScene := preload("res://scenes/ui/game_hud.tscn")
const RoundReplayScene := preload("res://scenes/ui/round_replay.gd")
const EscapistScene := preload("res://scenes/characters/escapist/escapist.tscn")
const TrapperScene := preload("res://scenes/characters/trapper/trapper.tscn")
const MenuMusicPlayerScene := preload("res://scenes/audio/menu_music_player.gd")

const ROUND_REPLAY_SAMPLE_INTERVAL: float = 0.08

const PRACTICE_SPIDER_BOT_INDEX := 100
const PRACTICE_ALLY_BOT_INDEX := 101
const PRACTICE_PATROL_BOT_INDEX := 102
const PRACTICE_SCORPION_BOT_INDEX := 103
const PRACTICE_MUSHROOM_BOT_INDEX := 104
const PRACTICE_OCTOPUS_BOT_INDEX := 105
const PRACTICE_BOT_INDICES := [
	PRACTICE_SPIDER_BOT_INDEX,
	PRACTICE_ALLY_BOT_INDEX,
	PRACTICE_PATROL_BOT_INDEX,
	PRACTICE_SCORPION_BOT_INDEX,
	PRACTICE_MUSHROOM_BOT_INDEX,
	PRACTICE_OCTOPUS_BOT_INDEX,
]

var arena: Arena
var characters: Array[Node2D] = []  # Mix of Escapist and Trapper nodes
var _active_player_indices: Array[int] = []
var _prev_start_pressed: Dictionary = {}  # {device_id: bool}
var _selected_stage_index: int = 0
var _practice_bots_added: bool = false
var _round_replay_tracks: Dictionary = {}
var _round_replay_recording: bool = false
var _round_replay_elapsed: float = 0.0
var _round_replay_escape_start_time: float = 0.0
var _round_replay_sample_timer: float = 0.0
var _round_replay_active: bool = false
var _round_trapper_impacts: Dictionary = {}
var _last_round_fastest_escape_replay: Dictionary = {}
var _last_round_trapper_replay: Dictionary = {}

@onready var arena_container := $ArenaContainer as Node2D
@onready var character_container := $Characters as Node2D
@onready var camera := $Camera2D as Camera2D
@onready var ui_layer := $UILayer as CanvasLayer

# View stack
var _view_stack: Array[Control] = []

# UI instances
var intro_screen: IntroScreen
var cover_screen: CoverScreen
var mode_select: ModeSelect
var how_to_play: HowToPlay
var practice_setup: PracticeSetup
var official_briefing: OfficialBriefing
var team_setup: TeamSetup
var stage_select: StageSelect
var escapist_select: EscapistSelect
var character_select: CharacterSelect
var settings_menu: SettingsMenu
var pause_menu: PauseMenu
var phase_overlay: PhaseOverlay
var game_hud: GameHud
var round_replay: RoundReplay
var menu_music: MenuMusicPlayer
var _is_first_round: bool = true  # Tracks if this is the initial pre-game select
var _is_practice_flow: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	arena_container.process_mode = Node.PROCESS_MODE_PAUSABLE
	character_container.process_mode = Node.PROCESS_MODE_PAUSABLE
	camera.process_mode = Node.PROCESS_MODE_PAUSABLE
	ui_layer.process_mode = Node.PROCESS_MODE_ALWAYS

	cover_screen = CoverScreenScene.instantiate() as CoverScreen
	ui_layer.add_child(cover_screen)
	cover_screen.hide()
	cover_screen.start_requested.connect(_on_cover_start_requested)

	intro_screen = IntroScreenScene.new() as IntroScreen
	ui_layer.add_child(intro_screen)
	intro_screen.hide()
	intro_screen.progress_changed.connect(_on_intro_progress_changed)
	intro_screen.intro_finished.connect(_on_intro_finished)

	mode_select = ModeSelectScene.new() as ModeSelect
	ui_layer.add_child(mode_select)
	mode_select.hide()
	mode_select.official_requested.connect(_start_team_setup)
	mode_select.practice_requested.connect(_start_practice_setup)
	mode_select.rules_requested.connect(_open_how_to_play)
	mode_select.back_requested.connect(_start_cover_screen)

	how_to_play = HowToPlayScene.new() as HowToPlay
	ui_layer.add_child(how_to_play)
	how_to_play.hide()
	how_to_play.back_requested.connect(_close_how_to_play)

	practice_setup = PracticeSetupScene.new() as PracticeSetup
	ui_layer.add_child(practice_setup)
	practice_setup.hide()
	practice_setup.practice_ready.connect(_on_practice_ready)
	practice_setup.back_requested.connect(_start_mode_select)

	official_briefing = OfficialBriefingScene.new() as OfficialBriefing
	ui_layer.add_child(official_briefing)
	official_briefing.hide()
	official_briefing.briefing_finished.connect(_on_official_briefing_finished)

	team_setup = TeamSetupScene.instantiate() as TeamSetup
	ui_layer.add_child(team_setup)
	team_setup.hide()
	team_setup.teams_ready.connect(_on_teams_ready)
	team_setup.settings_requested.connect(_open_settings)
	team_setup.back_requested.connect(_start_mode_select)

	stage_select = StageSelectScene.instantiate() as StageSelect
	ui_layer.add_child(stage_select)
	stage_select.hide()
	stage_select.stage_selected.connect(_on_stage_selected)
	stage_select.back_requested.connect(_on_stage_back)

	escapist_select = EscapistSelectScene.instantiate() as EscapistSelect
	ui_layer.add_child(escapist_select)
	escapist_select.hide()
	escapist_select.escapists_ready.connect(_on_escapists_ready)
	escapist_select.back_requested.connect(_on_escapist_back)

	character_select = CharacterSelectScene.instantiate() as CharacterSelect
	ui_layer.add_child(character_select)
	character_select.hide()
	character_select.characters_ready.connect(_on_characters_ready)
	character_select.back_requested.connect(_on_character_back)

	settings_menu = SettingsMenuScene.instantiate() as SettingsMenu
	ui_layer.add_child(settings_menu)
	settings_menu.hide()
	settings_menu.closed.connect(_close_settings)
	settings_menu.setting_changed.connect(_on_setting_changed)

	pause_menu = PauseMenuScene.new() as PauseMenu
	ui_layer.add_child(pause_menu)
	pause_menu.hide()
	pause_menu.resume_requested.connect(_resume_from_pause)
	pause_menu.settings_requested.connect(_open_settings)
	pause_menu.how_to_play_requested.connect(_open_how_to_play_from_pause)
	pause_menu.reset_requested.connect(_reset_to_team_setup)
	pause_menu.round_reset_requested.connect(_restart_current_round)
	pause_menu.practice_requested.connect(_start_practice_setup)
	pause_menu.practice_character_select_requested.connect(_restart_practice_character_select)
	pause_menu.practice_obstacles_toggled.connect(_on_practice_obstacles_toggled)
	pause_menu.practice_bots_toggled.connect(_on_practice_bots_toggled)

	phase_overlay = PhaseOverlayScene.instantiate() as PhaseOverlay
	ui_layer.add_child(phase_overlay)
	phase_overlay.hide()
	phase_overlay.escape_finished.connect(_on_escape_overlay_finished)

	game_hud = GameHudScene.instantiate() as GameHud
	ui_layer.add_child(game_hud)
	game_hud.hide()

	round_replay = RoundReplayScene.new() as RoundReplay
	character_container.add_child(round_replay)
	round_replay.finished.connect(_on_round_replay_finished)
	get_viewport().size_changed.connect(_on_viewport_size_changed)

	menu_music = MenuMusicPlayerScene.new() as MenuMusicPlayer
	add_child(menu_music)

	GameManager.state_changed.connect(_on_state_changed)
	GameManager.round_ended.connect(_on_round_ended)
	GameManager.match_ended.connect(_on_match_ended)
	GameManager.escapist_scored.connect(_on_escapist_scored)
	GameManager.escapist_died.connect(_on_escapist_died)
	GameManager.trap_contact_registered.connect(_on_trap_contact_registered)
	GameManager.round_advancing.connect(_on_round_advancing)

	_start_intro_screen()


func _start_intro_screen() -> void:
	get_tree().paused = false
	_clear_pause_menu()
	_cleanup_round()
	_active_player_indices.clear()
	if arena:
		arena.queue_free()
		arena = null
	phase_overlay.clear()
	game_hud.hide()
	menu_music.use_intro_volume()
	menu_music.start_music()

	while not _view_stack.is_empty():
		pop_view()

	intro_screen.open()
	push_view(intro_screen)


func _on_intro_finished() -> void:
	menu_music.set_intro_progress(1.0)
	_start_cover_screen()


func _on_intro_progress_changed(progress: float) -> void:
	menu_music.set_intro_progress(progress)


func _start_cover_screen() -> void:
	get_tree().paused = false
	_clear_pause_menu()
	_cleanup_round()
	_active_player_indices.clear()
	if arena:
		arena.queue_free()
		arena = null
	phase_overlay.clear()
	game_hud.hide()
	menu_music.use_menu_volume()
	menu_music.start_music()

	while not _view_stack.is_empty():
		pop_view()

	cover_screen.open()
	push_view(cover_screen)


func _on_cover_start_requested() -> void:
	_start_mode_select()


func _start_mode_select() -> void:
	get_tree().paused = false
	_clear_pause_menu()
	_cleanup_round()
	_active_player_indices.clear()
	_is_practice_flow = false
	if arena:
		arena.queue_free()
		arena = null
	phase_overlay.clear()
	game_hud.hide()
	menu_music.use_menu_volume()
	menu_music.start_music()

	while not _view_stack.is_empty():
		pop_view()

	mode_select.open()
	push_view(mode_select)


func _open_how_to_play() -> void:
	ui_layer.move_child(how_to_play, ui_layer.get_child_count() - 1)
	how_to_play.open()
	push_view(how_to_play)


func _open_how_to_play_from_pause() -> void:
	_hide_pause_menu_behind_subscreen()
	how_to_play.open()
	push_view(how_to_play)


func _close_how_to_play() -> void:
	pop_view()
	if pause_menu and (get_tree().paused or GameManager.current_state == Enums.GameState.PAUSED):
		_restore_pause_menu_after_subscreen()
		return
	if _view_stack.is_empty():
		_start_mode_select()


func _start_practice_setup() -> void:
	get_tree().paused = false
	_clear_pause_menu()
	_cleanup_round()
	_practice_bots_added = false
	_active_player_indices.clear()
	GameManager.reset_match()
	GameManager.settings_overrides[&"skill_cooldowns_enabled"] = true
	GameManager.settings_overrides[&"practice_obstacles_enabled"] = true
	GameManager.settings_overrides[&"practice_bots_enabled"] = false
	_is_practice_flow = true
	if arena:
		arena.queue_free()
		arena = null
	phase_overlay.clear()
	game_hud.hide()
	menu_music.use_menu_volume()
	menu_music.start_music()

	while not _view_stack.is_empty():
		pop_view()

	practice_setup.setup()
	push_view(practice_setup)


func _on_practice_ready(team_assignments: Dictionary, role_assignments: Dictionary) -> void:
	_is_practice_flow = true
	GameManager.set_practice_assignments(team_assignments, role_assignments)
	_active_player_indices.clear()
	for pi: int in team_assignments:
		_active_player_indices.append(pi)
	_active_player_indices.sort()
	_show_escapist_select(true)


func _start_team_setup() -> void:
	get_tree().paused = false
	_clear_pause_menu()
	_cleanup_round()
	_practice_bots_added = false
	_active_player_indices.clear()
	_is_practice_flow = false
	if arena:
		arena.queue_free()
		arena = null
	phase_overlay.clear()
	game_hud.hide()
	menu_music.use_menu_volume()
	menu_music.start_music()

	while not _view_stack.is_empty():
		pop_view()

	team_setup.setup()
	push_view(team_setup)


func _on_teams_ready(t_assignments: Dictionary) -> void:
	_is_practice_flow = false
	GameManager.set_team_assignments(t_assignments)
	_active_player_indices.clear()
	for pi: int in t_assignments:
		_active_player_indices.append(pi)
	_active_player_indices.sort()

	# Go to stage select
	replace_view(stage_select)
	stage_select.setup()


func _on_stage_selected(stage_index: int) -> void:
	_selected_stage_index = stage_index
	_is_first_round = true
	_show_escapist_select(true)


func _on_stage_back() -> void:
	_start_team_setup()


func _show_escapist_select(allow_back: bool) -> void:
	if _view_stack.is_empty():
		push_view(escapist_select)
	else:
		replace_view(escapist_select)
	escapist_select.setup(_active_player_indices, GameManager.team_assignments,
		GameManager.escapist_team, allow_back)


func _show_character_select(allow_back: bool) -> void:
	if _view_stack.is_empty():
		push_view(character_select)
	else:
		replace_view(character_select)
	character_select.setup(_active_player_indices, GameManager.team_assignments,
		GameManager.get_trapping_team(), allow_back)


func _on_escapists_ready(selections: Dictionary) -> void:
	GameManager.set_escapist_selections(selections)
	_show_character_select(_is_practice_flow or _is_first_round)


func _on_characters_ready(selections: Dictionary) -> void:
	GameManager.set_character_selections(selections)

	while not _view_stack.is_empty():
		pop_view()

	for pi in _active_player_indices:
		_prev_start_pressed[pi] = true

	if _is_practice_flow:
		_start_practice_session()
		return

	if _is_first_round:
		_setup_arena()
		_is_first_round = false
		_show_official_briefing()
		return
	menu_music.use_round_volume()
	game_hud.show()
	GameManager.start_observation()


func _show_official_briefing() -> void:
	game_hud.hide()
	phase_overlay.clear()
	menu_music.use_menu_volume()
	menu_music.start_music()
	official_briefing.open()
	push_view(official_briefing)


func _on_official_briefing_finished() -> void:
	pop_view()
	menu_music.use_round_volume()
	game_hud.show()
	GameManager.start_observation()
	_prime_start_button_state()
	InputManager.suppress_edge_detection(3)


func _on_character_back() -> void:
	_show_escapist_select(true)


func _on_escapist_back() -> void:
	if _is_practice_flow:
		_start_practice_setup()
		return
	replace_view(stage_select)
	stage_select.setup()


func _on_round_advancing() -> void:
	# Between rounds: pick escapists first, then trappers.
	phase_overlay.clear()
	game_hud.hide()
	menu_music.use_menu_volume()
	menu_music.start_music()
	_show_escapist_select(false)


func _setup_arena() -> void:
	if arena:
		arena.queue_free()
	arena = ArenaScene.instantiate() as Arena
	arena_container.add_child(arena)
	var stages := MapData.get_all()
	var map_data: Dictionary = stages[_selected_stage_index]
	arena.load_map(map_data)
	arena.goal_entered.connect(_on_goal_entered)
	_setup_camera()


func _setup_practice_arena() -> void:
	if arena:
		arena.queue_free()
	arena = ArenaScene.instantiate() as Arena
	arena_container.add_child(arena)
	arena.load_map(MapData.get_practice_map())
	var obstacles_enabled := GameManager.settings_overrides.get(&"practice_obstacles_enabled", false) as bool
	arena.set_practice_obstacles_enabled(obstacles_enabled)
	_setup_camera()


func _start_practice_session() -> void:
	_setup_practice_arena()
	menu_music.use_round_volume()
	game_hud.show()
	GameManager.start_practice()
	var bots_enabled := GameManager.settings_overrides.get(&"practice_bots_enabled", false) as bool
	if bots_enabled:
		_add_practice_bots()


func _setup_camera() -> void:
	if not arena:
		return
	var map_size := arena.get_map_size()
	camera.position = map_size / 2.0
	var viewport_size := get_viewport_rect().size
	var padding := Vector2(18.0, 18.0)
	var zoom_x := viewport_size.x / (map_size.x + padding.x)
	var zoom_y := viewport_size.y / (map_size.y + padding.y)
	var target_zoom := minf(zoom_x, zoom_y)
	camera.zoom = Vector2(target_zoom, target_zoom)


func _on_viewport_size_changed() -> void:
	_setup_camera()


func _on_goal_entered(escapist: Escapist) -> void:
	_capture_round_replay_finish(escapist)
	GameManager.register_escapist_scored(escapist.player_index)


func _cleanup_round() -> void:
	_clear_round_replay()
	for c in characters:
		if is_instance_valid(c):
			c.queue_free()
	characters.clear()
	for node in get_tree().get_nodes_in_group("traps"):
		node.queue_free()
	for node in get_tree().get_nodes_in_group("projectiles"):
		node.queue_free()


func _spawn_characters() -> void:
	_cleanup_round()

	var escapist_idx := 0

	for pi in _active_player_indices:
		var t: Enums.Team = GameManager.get_player_team(pi)
		var r: Enums.Role = GameManager.get_player_role(pi)

		if r == Enums.Role.ESCAPIST:
			var esc := EscapistScene.instantiate() as Escapist
			esc.player_index = pi
			esc.team = t
			esc.escapist_animal = GameManager.get_player_escapist_animal(pi)
			esc.player_color = Enums.escapist_animal_color(esc.escapist_animal)
			esc.position = arena.get_spawn(escapist_idx)
			esc.aim_direction = Vector2.RIGHT
			escapist_idx += 1
			esc.died.connect(_on_escapist_character_died)
			character_container.add_child(esc)
			characters.append(esc)
			GameManager.register_player_character(pi, esc)

		elif r == Enums.Role.TRAPPER:
			var trapper := TrapperScene.instantiate() as Trapper
			trapper.player_index = pi
			trapper.team = t
			trapper.player_color = Enums.role_color(Enums.Role.TRAPPER)
			trapper.trapper_character = GameManager.get_player_character(pi)
			trapper.position = arena.get_map_center()
			trapper.setup(arena.get_map_size())
			character_container.add_child(trapper)
			characters.append(trapper)
			GameManager.register_player_character(pi, trapper)


func _on_escapist_character_died(_escapist: Escapist) -> void:
	GameManager.register_escapist_died(_escapist.player_index)


func _on_state_changed(new_state: Enums.GameState) -> void:
	if GameManager.is_unpausing:
		GameManager.is_unpausing = false
		return

	match new_state:
		Enums.GameState.OBSERVATION:
			_clear_round_replay()
			menu_music.use_round_volume()
			if arena:
				arena.randomize_hazards_for_round(GameManager.get_competitive_round_number())
			_spawn_characters()
			_freeze_all()
			phase_overlay.show_round_intro(
				GameManager.get_competitive_round_number(),
				GameManager.get_round_leg_label(),
				GameManager.escapist_team
		)
		Enums.GameState.HUNT:
			_freeze_escapists_only()
			_start_round_replay_recording()
		Enums.GameState.ESCAPE:
			_round_replay_escape_start_time = _round_replay_elapsed
			phase_overlay.show_escape()
			_unfreeze_all()
			_start_round_replay_recording()
		Enums.GameState.ROUND_END:
			_round_replay_recording = false
			_freeze_all()
		Enums.GameState.MATCH_END:
			_freeze_all()
		Enums.GameState.PRACTICE:
			menu_music.use_round_volume()
			_spawn_characters()
			_unfreeze_all()
			phase_overlay.clear()


func _on_escape_overlay_finished() -> void:
	GameManager.start_escape_timer()


func _on_round_ended(escapist_team: Enums.Team, points_scored: int) -> void:
	var round_entries := GameManager.get_round_score_entries()
	_last_round_fastest_escape_replay = _build_fastest_round_replay(round_entries)
	_last_round_trapper_replay = _build_trapper_impact_replay()
	phase_overlay.set_round_total_points(points_scored)
	phase_overlay.show_round_end(
		escapist_team,
		GameManager.match_scores,
		round_entries,
		not _last_round_fastest_escape_replay.is_empty(),
		not _last_round_trapper_replay.is_empty()
	)
	_prime_start_button_state()
	InputManager.suppress_edge_detection(3)


func _on_match_ended(winning_team: Enums.Team) -> void:
	phase_overlay.show_match_end(winning_team, GameManager.match_scores, GameManager.get_match_score_entries())


func _on_escapist_scored(_team: Enums.Team) -> void:
	pass  # HUD updates automatically via _draw


func _on_escapist_died(_team: Enums.Team) -> void:
	pass  # HUD updates automatically via _draw


func _on_trap_contact_registered(escapist_player_index: int, trapper_player_index: int) -> void:
	if not _round_replay_recording or trapper_player_index < 0:
		return
	_round_trapper_impacts[trapper_player_index] = (_round_trapper_impacts.get(trapper_player_index, 0) as int) + 1
	if not _round_replay_tracks.has(trapper_player_index):
		return
	var track: Dictionary = _round_replay_tracks[trapper_player_index] as Dictionary
	track["impact_count"] = _round_trapper_impacts[trapper_player_index]
	var events: Array = track.get("events", []) as Array
	var victim := GameManager.player_characters.get(escapist_player_index, null) as Node2D
	var event_position := Vector2.ZERO
	if victim and is_instance_valid(victim):
		event_position = victim.global_position
	events.append({
		"time": _round_replay_elapsed,
		"position": event_position,
	})
	track["events"] = events
	_round_replay_tracks[trapper_player_index] = track


func _start_round_replay_recording() -> void:
	if GameManager.practice_mode:
		return
	if _round_replay_recording:
		return
	_round_replay_tracks.clear()
	_round_trapper_impacts.clear()
	_last_round_fastest_escape_replay.clear()
	_last_round_trapper_replay.clear()
	_round_replay_recording = true
	_round_replay_elapsed = 0.0
	_round_replay_escape_start_time = 0.0
	_round_replay_sample_timer = 0.0
	_capture_round_replay_sample(true)


func _update_round_replay_recording(delta: float) -> void:
	if not _round_replay_recording:
		return
	if GameManager.practice_mode:
		return
	if GameManager.current_state != Enums.GameState.HUNT and GameManager.current_state != Enums.GameState.ESCAPE:
		return
	_round_replay_elapsed += delta
	_round_replay_sample_timer -= delta
	if _round_replay_sample_timer > 0.0:
		return
	_capture_round_replay_sample(false)
	_round_replay_sample_timer = ROUND_REPLAY_SAMPLE_INTERVAL


func _capture_round_replay_sample(force: bool) -> void:
	for c in characters:
		if not is_instance_valid(c):
			continue
		if c is Escapist:
			var esc := c as Escapist
			if esc.is_dead or esc.has_scored:
				continue
			_append_round_replay_sample(esc, force)
		elif c is Trapper:
			_append_round_replay_sample(c as Node2D, force)


func _capture_round_replay_finish(escapist: Escapist) -> void:
	if not _round_replay_recording or GameManager.practice_mode:
		return
	_append_round_replay_sample(escapist, true)
	var track: Dictionary = _round_replay_tracks.get(escapist.player_index, {}) as Dictionary
	track["escaped"] = true
	_round_replay_tracks[escapist.player_index] = track


func _append_round_replay_sample(character: Node2D, force: bool) -> void:
	var track := _get_or_create_round_replay_track(character)
	var positions: Array = track.get("positions", []) as Array
	var times: Array = track.get("times", []) as Array
	if not force and not positions.is_empty():
		var last_pos := positions[positions.size() - 1] as Vector2
		if last_pos.distance_squared_to(character.position) < 4.0:
			return
	var sample_time := _round_replay_elapsed
	if not times.is_empty():
		sample_time = maxf(sample_time, (times[times.size() - 1] as float) + 0.001)
	positions.append(character.position)
	times.append(sample_time)
	track["positions"] = positions
	track["times"] = times
	var player_index := track.get("player_index", -1) as int
	_round_replay_tracks[player_index] = track


func _get_or_create_round_replay_track(character: Node2D) -> Dictionary:
	var player_index := -1
	var team := Enums.Team.NONE
	var color := Color.WHITE
	var role := Enums.Role.NONE
	var label := "REPETICIÓN"
	if character is Escapist:
		var esc := character as Escapist
		player_index = esc.player_index
		team = esc.team
		color = esc.player_color
		role = Enums.Role.ESCAPIST
		label = "P%d ESCAPE MÁS RÁPIDO" % (player_index + 1)
		if player_index >= 100:
			label = "BOT ESCAPE MÁS RÁPIDO"
	elif character is Trapper:
		var trapper := character as Trapper
		player_index = trapper.player_index
		team = trapper.team
		color = Enums.trapper_character_color(trapper.trapper_character)
		role = Enums.Role.TRAPPER
		label = "P%d REPETICIÓN CAZADOR" % (player_index + 1)
		if player_index >= 100:
			label = "BOT REPETICIÓN CAZADOR"

	if _round_replay_tracks.has(player_index):
		return _round_replay_tracks[player_index] as Dictionary
	var track := {
		"player_index": player_index,
		"team": team,
		"role": role,
		"color": color,
		"label": label,
		"positions": [],
		"times": [],
		"events": [],
		"escaped": false,
		"impact_count": 0,
	}
	_round_replay_tracks[player_index] = track
	return track


func _build_fastest_round_replay(entries: Array[Dictionary]) -> Dictionary:
	var best_entry: Dictionary = {}
	var best_time := 999999.0
	for entry: Dictionary in entries:
		if not entry.get("escaped", false):
			continue
		var player_index := entry.get("player_index", -1) as int
		if not _round_replay_tracks.has(player_index):
			continue
		var track: Dictionary = _round_replay_tracks[player_index] as Dictionary
		var positions: Array = track.get("positions", []) as Array
		var times: Array = track.get("times", []) as Array
		if positions.size() < 2 or times.size() < 2:
			continue
		var escape_time := entry.get("escape_time", 9999.0) as float
		if escape_time < best_time:
			best_time = escape_time
			best_entry = entry
	if best_entry.is_empty():
		return {}

	var best_player_index := best_entry.get("player_index", -1) as int
	var best_track: Dictionary = (_round_replay_tracks[best_player_index] as Dictionary).duplicate(true)
	var player_label := "P%d" % (best_player_index + 1) if best_player_index < 100 else "BOT"
	best_track["label"] = "%s ESCAPE MÁS RÁPIDO  %.1fs" % [
		player_label,
		best_entry.get("escape_time", 0.0) as float,
	]
	best_track["playback_start_time"] = _round_replay_escape_start_time
	best_track["rivals"] = _get_rival_replay_tracks(best_track)
	best_track["score_entry"] = best_entry.duplicate(true)
	return best_track


func _build_trapper_impact_replay() -> Dictionary:
	var best_player_index := -1
	var best_count := 0
	for player_index: int in _round_trapper_impacts:
		var count := _round_trapper_impacts[player_index] as int
		if count > best_count:
			best_count = count
			best_player_index = player_index
	if best_player_index < 0 or best_count <= 0:
		return {}
	if not _round_replay_tracks.has(best_player_index):
		return {}
	var track: Dictionary = (_round_replay_tracks[best_player_index] as Dictionary).duplicate(true)
	var positions: Array = track.get("positions", []) as Array
	var times: Array = track.get("times", []) as Array
	if positions.size() < 2 or times.size() < 2:
		return {}
	var player_label := "P%d" % (best_player_index + 1) if best_player_index < 100 else "BOT"
	track["label"] = "%s IMPACTO CAZADOR  %d golpes" % [player_label, best_count]
	track["impact_count"] = best_count
	track["playback_start_time"] = 0.0
	track["rivals"] = _get_rival_replay_tracks(track)
	return track


func _get_rival_replay_tracks(main_track: Dictionary) -> Array[Dictionary]:
	var rivals: Array[Dictionary] = []
	var main_player_index := main_track.get("player_index", -1) as int
	var main_team := main_track.get("team", Enums.Team.NONE) as Enums.Team
	for player_index: int in _round_replay_tracks:
		if player_index == main_player_index:
			continue
		var rival: Dictionary = _round_replay_tracks[player_index] as Dictionary
		var rival_team := rival.get("team", Enums.Team.NONE) as Enums.Team
		if rival_team == main_team or rival_team == Enums.Team.NONE:
			continue
		var positions: Array = rival.get("positions", []) as Array
		var times: Array = rival.get("times", []) as Array
		if positions.size() < 1 or times.size() < 1:
			continue
		rivals.append(rival.duplicate(true))
	return rivals


func _start_round_replay(replay_track: Dictionary) -> void:
	if replay_track.is_empty() or _round_replay_active:
		return
	_round_replay_active = true
	phase_overlay.clear()
	round_replay.play(replay_track)
	InputManager.suppress_edge_detection(3)


func _on_round_replay_finished() -> void:
	_finish_round_replay()


func _finish_round_replay() -> void:
	if not _round_replay_active:
		return
	_round_replay_active = false
	round_replay.stop()
	phase_overlay.show_round_end(
		GameManager.escapist_team,
		GameManager.match_scores,
		GameManager.get_round_score_entries(),
		not _last_round_fastest_escape_replay.is_empty(),
		not _last_round_trapper_replay.is_empty()
	)
	_prime_start_button_state()
	InputManager.suppress_edge_detection(3)


func _check_round_replay_skip_input() -> void:
	for pi in _active_player_indices:
		var device_id := InputManager.get_device_id(pi)
		if device_id < 0:
			continue
		if InputManager.is_button_just_pressed_on_device(device_id, JOY_BUTTON_A) \
				or InputManager.is_button_just_pressed_on_device(device_id, JOY_BUTTON_B) \
				or InputManager.is_button_just_pressed_on_device(device_id, JOY_BUTTON_X) \
				or InputManager.is_button_just_pressed_on_device(device_id, JOY_BUTTON_Y):
			_finish_round_replay()
			return


func _clear_round_replay() -> void:
	_round_replay_active = false
	_round_replay_recording = false
	_round_replay_tracks.clear()
	_round_trapper_impacts.clear()
	_last_round_fastest_escape_replay.clear()
	_last_round_trapper_replay.clear()
	if round_replay != null:
		round_replay.stop()


func _process(delta: float) -> void:
	_update_round_replay_recording(delta)
	var state := GameManager.current_state

	if state == Enums.GameState.PAUSED:
		_check_pause_input()
		return

	if _round_replay_active:
		_check_round_replay_skip_input()
		return

	if state == Enums.GameState.HUNT:
		phase_overlay.show_hunt_countdown(GameManager.get_observation_time())

	if state == Enums.GameState.OBSERVATION \
			or state == Enums.GameState.HUNT \
			or state == Enums.GameState.ESCAPE \
			or state == Enums.GameState.PRACTICE:
		_check_pause_input()

	if state == Enums.GameState.ESCAPE:
		_check_debug_input()

	if state == Enums.GameState.MATCH_END:
		_check_restart_input()
	elif GameManager.is_round_end_waiting_for_continue():
		_check_round_end_skip_input()


# --- Debug ---

func _check_debug_input() -> void:
	for pi in _active_player_indices:
		var device_id := InputManager.get_device_id(pi)
		if device_id < 0:
			continue
		if InputManager.is_button_just_pressed_on_device(device_id, JOY_BUTTON_BACK):
			_kill_all_escapists()
			return


func _kill_all_escapists() -> void:
	for c in characters:
		if c is Escapist:
			var esc := c as Escapist
			if not esc.is_dead and not esc.has_scored:
				esc.kill()


# --- Freeze/Unfreeze ---

func _freeze_all() -> void:
	for c in characters:
		if is_instance_valid(c):
			if c is BaseCharacter:
				(c as BaseCharacter).freeze_character()
			elif c is Trapper:
				(c as Trapper).freeze_character()


func _unfreeze_all() -> void:
	for c in characters:
		if is_instance_valid(c):
			if c is BaseCharacter:
				(c as BaseCharacter).unfreeze_character()
			elif c is Trapper:
				(c as Trapper).unfreeze_character()


func _freeze_escapists_only() -> void:
	for c in characters:
		if is_instance_valid(c):
			if c is BaseCharacter:
				(c as BaseCharacter).freeze_character()
			elif c is Trapper:
				(c as Trapper).unfreeze_character()


# --- Pause ---

func _check_pause_input() -> void:
	for pi in _active_player_indices:
		var device_id := InputManager.get_device_id(pi)
		if device_id < 0:
			_prev_start_pressed[pi] = false
			continue
		var pressed := Input.is_joy_button_pressed(device_id, JOY_BUTTON_START)
		var was_pressed: bool = _prev_start_pressed.get(pi, false)
		_prev_start_pressed[pi] = pressed
		if pressed and not was_pressed:
			if GameManager.current_state == Enums.GameState.PAUSED:
				_resume_from_pause()
			else:
				_pause_game()
			return


func _check_restart_input() -> void:
	for pi in _active_player_indices:
		var device_id := InputManager.get_device_id(pi)
		if device_id < 0:
			_prev_start_pressed[pi] = false
			continue
		var pressed := Input.is_joy_button_pressed(device_id, JOY_BUTTON_START)
		var was_pressed: bool = _prev_start_pressed.get(pi, false)
		_prev_start_pressed[pi] = pressed
		if pressed and not was_pressed:
			_reset_to_team_setup()
			return


func _check_round_end_skip_input() -> void:
	for pi in _active_player_indices:
		var device_id := InputManager.get_device_id(pi)
		if device_id < 0:
			continue
		if not _last_round_fastest_escape_replay.is_empty() \
				and InputManager.is_button_just_pressed_on_device(device_id, JOY_BUTTON_Y):
			_start_round_replay(_last_round_fastest_escape_replay)
			return
		if not _last_round_trapper_replay.is_empty() \
				and InputManager.is_button_just_pressed_on_device(device_id, JOY_BUTTON_X):
			_start_round_replay(_last_round_trapper_replay)
			return
		var pressed := Input.is_joy_button_pressed(device_id, JOY_BUTTON_START)
		var was_pressed: bool = _prev_start_pressed.get(pi, false)
		_prev_start_pressed[pi] = pressed
		if pressed and not was_pressed:
			GameManager.confirm_round_end()
			_prime_start_button_state()
			InputManager.suppress_edge_detection(3)
			return


func _pause_game() -> void:
	GameManager.pause_game()
	_prime_start_button_state()
	push_view(pause_menu)
	pause_menu.open()
	InputManager.suppress_edge_detection(3)
	get_tree().paused = true


func _resume_from_pause() -> void:
	if GameManager.current_state != Enums.GameState.PAUSED:
		return
	get_tree().paused = false
	_clear_pause_menu()
	_apply_runtime_settings()
	GameManager.unpause_game()
	_prime_start_button_state()
	InputManager.suppress_edge_detection(3)


func _restart_current_round() -> void:
	if GameManager.practice_mode:
		return
	get_tree().paused = false
	_clear_pause_menu()
	phase_overlay.clear()
	GameManager.restart_current_round()
	_prime_start_button_state()
	InputManager.suppress_edge_detection(3)


func _on_practice_obstacles_toggled(enabled: bool) -> void:
	if arena and GameManager.practice_mode:
		arena.set_practice_obstacles_enabled(enabled)


func _on_practice_bots_toggled(enabled: bool) -> void:
	if not GameManager.practice_mode:
		return
	if enabled:
		_add_practice_bots()
	else:
		_remove_practice_bots()


func _add_practice_bots() -> void:
	if not GameManager.practice_mode or arena == null or _practice_bots_added:
		return

	_register_practice_trapper_bot(PRACTICE_SPIDER_BOT_INDEX, Enums.TrapperCharacter.ARANA)
	_register_practice_trapper_bot(PRACTICE_SCORPION_BOT_INDEX, Enums.TrapperCharacter.ESCORPION)
	_register_practice_trapper_bot(PRACTICE_MUSHROOM_BOT_INDEX, Enums.TrapperCharacter.HONGO)
	_register_practice_trapper_bot(PRACTICE_OCTOPUS_BOT_INDEX, Enums.TrapperCharacter.PULPO)
	_register_practice_escapist_bot(PRACTICE_ALLY_BOT_INDEX)
	_register_practice_escapist_bot(PRACTICE_PATROL_BOT_INDEX)

	for bot_index: int in PRACTICE_BOT_INDICES:
		if bot_index not in _active_player_indices:
			_active_player_indices.append(bot_index)
	_active_player_indices.sort()

	_spawn_practice_bot(PRACTICE_SPIDER_BOT_INDEX)
	_spawn_practice_bot(PRACTICE_SCORPION_BOT_INDEX)
	_spawn_practice_bot(PRACTICE_MUSHROOM_BOT_INDEX)
	_spawn_practice_bot(PRACTICE_OCTOPUS_BOT_INDEX)
	_spawn_practice_bot(PRACTICE_ALLY_BOT_INDEX)
	_spawn_practice_bot(PRACTICE_PATROL_BOT_INDEX)
	_practice_bots_added = true


func _register_practice_trapper_bot(player_index: int, character: Enums.TrapperCharacter) -> void:
	GameManager.team_assignments[player_index] = GameManager.get_trapping_team()
	GameManager.role_assignments[player_index] = Enums.Role.TRAPPER
	GameManager.character_selections[player_index] = character


func _register_practice_escapist_bot(player_index: int) -> void:
	GameManager.team_assignments[player_index] = GameManager.escapist_team
	GameManager.role_assignments[player_index] = Enums.Role.ESCAPIST
	GameManager.escapist_selections[player_index] = Enums.EscapistAnimal.RABBIT


func _spawn_practice_bot(player_index: int) -> void:
	if arena == null:
		return
	var role: Enums.Role = GameManager.get_player_role(player_index)
	var team: Enums.Team = GameManager.get_player_team(player_index)
	if role == Enums.Role.TRAPPER:
		var trapper := TrapperScene.instantiate() as Trapper
		trapper.player_index = player_index
		trapper.team = team
		trapper.player_color = Enums.role_color(Enums.Role.TRAPPER)
		trapper.trapper_character = GameManager.get_player_character(player_index)
		trapper.position = arena.get_map_center()
		trapper.setup(arena.get_map_size())
		var map_size := arena.get_map_size()
		var path_a := Vector2.ZERO
		var path_b := Vector2.ZERO
		match trapper.trapper_character:
			Enums.TrapperCharacter.ARANA:
				path_a = Vector2(map_size.x * 0.68, map_size.y * 0.32)
				path_b = Vector2(map_size.x * 0.84, map_size.y * 0.32)
				trapper.configure_spider_bot(path_a, path_b)
			Enums.TrapperCharacter.HONGO:
				path_a = Vector2(map_size.x * 0.10, map_size.y * 0.18)
				path_b = Vector2(map_size.x * 0.28, map_size.y * 0.18)
				trapper.configure_mushroom_bot(path_a, path_b)
			Enums.TrapperCharacter.ESCORPION:
				path_a = Vector2(map_size.x * 0.08, map_size.y * 0.82)
				path_b = Vector2(map_size.x * 0.32, map_size.y * 0.82)
				trapper.configure_scorpion_bot(path_a, path_b)
			Enums.TrapperCharacter.PULPO:
				path_a = Vector2(map_size.x * 0.70, map_size.y * 0.18)
				path_b = Vector2(map_size.x * 0.92, map_size.y * 0.18)
				trapper.configure_octopus_bot(path_a, path_b)
		trapper.unfreeze_character()
		character_container.add_child(trapper)
		characters.append(trapper)
		GameManager.register_player_character(player_index, trapper)
	elif role == Enums.Role.ESCAPIST:
		var esc := EscapistScene.instantiate() as Escapist
		esc.player_index = player_index
		esc.team = team
		esc.escapist_animal = GameManager.get_player_escapist_animal(player_index)
		esc.player_color = Enums.escapist_animal_color(esc.escapist_animal)
		var map_size := arena.get_map_size()
		esc.position = Vector2(map_size.x * 0.78, map_size.y * 0.72)
		esc.aim_direction = Vector2.RIGHT
		if player_index == PRACTICE_PATROL_BOT_INDEX:
			var path_a := Vector2(map_size.x * 0.70, map_size.y * 0.84)
			var path_b := Vector2(map_size.x * 0.93, map_size.y * 0.84)
			esc.configure_patrol_bot(path_a, path_b)
		esc.died.connect(_on_escapist_character_died)
		character_container.add_child(esc)
		esc.unfreeze_character()
		characters.append(esc)
		GameManager.register_player_character(player_index, esc)


func _remove_practice_bots() -> void:
	for bot_index: int in PRACTICE_BOT_INDICES:
		var character := GameManager.player_characters.get(bot_index, null) as Node2D
		if character and is_instance_valid(character):
			characters.erase(character)
			character.queue_free()
	_clear_practice_bots()
	_practice_bots_added = false


func _restart_practice_character_select() -> void:
	get_tree().paused = false
	_clear_pause_menu()
	_cleanup_round()
	if arena:
		arena.queue_free()
		arena = null
	phase_overlay.clear()
	game_hud.hide()
	menu_music.use_menu_volume()
	menu_music.start_music()
	_is_practice_flow = true
	_clear_practice_bots()
	GameManager.prepare_practice_character_select()
	_practice_bots_added = false
	_active_player_indices.clear()
	for pi: int in GameManager.team_assignments:
		_active_player_indices.append(pi)
	_active_player_indices.sort()
	while not _view_stack.is_empty():
		pop_view()
	_show_escapist_select(true)
	_prime_start_button_state()
	InputManager.suppress_edge_detection(3)


func _clear_practice_bots() -> void:
	for bot_index: int in PRACTICE_BOT_INDICES:
		GameManager.team_assignments.erase(bot_index)
		GameManager.role_assignments.erase(bot_index)
		GameManager.character_selections.erase(bot_index)
		GameManager.escapist_selections.erase(bot_index)
		GameManager.player_characters.erase(bot_index)
		_active_player_indices.erase(bot_index)


func _reset_to_team_setup() -> void:
	get_tree().paused = false
	_clear_pause_menu()
	GameManager.reset_match()
	_start_team_setup()
	_prime_start_button_state()
	InputManager.suppress_edge_detection(3)


func _clear_pause_menu() -> void:
	while pause_menu and pause_menu in _view_stack:
		pop_view()
	if pause_menu:
		pause_menu.hide()
		pause_menu.input_blocked = false


func _hide_pause_menu_behind_subscreen() -> void:
	if pause_menu and pause_menu.visible:
		pause_menu.hide()
		pause_menu.input_blocked = true


func _restore_pause_menu_after_subscreen() -> void:
	if not pause_menu:
		return
	pause_menu.show()
	pause_menu.input_blocked = false
	pause_menu.queue_redraw()


func _prime_start_button_state() -> void:
	for pi in _active_player_indices:
		var device_id := InputManager.get_device_id(pi)
		_prev_start_pressed[pi] = device_id >= 0 and Input.is_joy_button_pressed(device_id, JOY_BUTTON_START)


# --- Settings ---

func _open_settings() -> void:
	ui_layer.move_child(settings_menu, ui_layer.get_child_count() - 1)
	if get_tree().paused or GameManager.current_state == Enums.GameState.PAUSED:
		_hide_pause_menu_behind_subscreen()
	push_view(settings_menu)
	settings_menu.open()


func _close_settings() -> void:
	pop_view()
	if pause_menu and (get_tree().paused or GameManager.current_state == Enums.GameState.PAUSED):
		_restore_pause_menu_after_subscreen()


func _on_setting_changed(key: String, value: Variant) -> void:
	match key:
		"bot_fill":
			team_setup.auto_fill_bots = (int(value) == 0)  # 0 = "On"
		"bot_ai":
			GameManager.settings_overrides[&"bot_ai"] = (int(value) == 1)  # 1 = "On"
		"hunt_duration":
			GameManager.settings_overrides[&"hunt_duration"] = value
		"observation_duration":
			GameManager.settings_overrides[&"observation_duration"] = value
		"hunt_countdown_duration":
			GameManager.settings_overrides[&"hunt_countdown_duration"] = value
		"score_to_win":
			GameManager.settings_overrides[&"score_to_win"] = value
		"team_size":
			GameManager.settings_overrides[&"team_size"] = value
		"escapist_speed":
			GameManager.settings_overrides[&"escapist_speed"] = value
		"trapper_speed":
			GameManager.settings_overrides[&"trapper_speed"] = value
		"poison_duration":
			GameManager.settings_overrides[&"poison_duration"] = value
		"hunt_countdown_enabled":
			GameManager.settings_overrides[&"hunt_countdown_enabled"] = (int(value) == 0)  # 0 = "On"
		"music_volume":
			var music_volume := float(value) / 100.0
			GameManager.settings_overrides[&"music_volume"] = music_volume
			menu_music.set_music_volume(music_volume)
		"effects_volume":
			var effects_volume := float(value) / 100.0
			GameManager.settings_overrides[&"effects_volume"] = effects_volume
			AudioManager.set_effects_volume(effects_volume)


func _apply_runtime_settings() -> void:
	GameManager.apply_runtime_settings()
	for c in characters:
		if not is_instance_valid(c):
			continue
		if c is Escapist:
			var speed_mult: float = GameManager.settings_overrides.get(&"escapist_speed", 1.0) as float
			(c as Escapist).movement.move_speed = Constants.SPEED_ESCAPIST * speed_mult


# --- View stack ---

func push_view(view: Control) -> void:
	if not _view_stack.is_empty():
		var top := _view_stack.back() as Control
		top.set("input_blocked", true)
	_view_stack.append(view)
	view.show()
	view.set("input_blocked", false)
	InputManager.suppress_edge_detection(3)


func pop_view() -> Control:
	if _view_stack.is_empty():
		return null
	var view := _view_stack.pop_back() as Control
	view.hide()
	if not _view_stack.is_empty():
		var top := _view_stack.back() as Control
		top.set("input_blocked", false)
	InputManager.suppress_edge_detection(3)
	return view


func replace_view(view: Control) -> void:
	pop_view()
	push_view(view)
