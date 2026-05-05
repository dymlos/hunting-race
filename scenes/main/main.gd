extends Node2D

## Main scene — orchestrates arena, characters, UI, and game state.

const TeamSetupScene := preload("res://scenes/ui/team_setup.tscn")
const IntroScreenScene := preload("res://scenes/ui/intro_screen.gd")
const CoverScreenScene := preload("res://scenes/ui/cover_screen.tscn")
const ModeSelectScene := preload("res://scenes/ui/mode_select.gd")
const HowToPlayScene := preload("res://scenes/ui/how_to_play.gd")
const PracticeSetupScene := preload("res://scenes/ui/practice_setup.gd")
const SurvivalEscapeSetupScene := preload("res://scenes/ui/survival_escape_setup.gd")
const OfficialBriefingScene := preload("res://scenes/ui/official_briefing.gd")
const StageSelectScene := preload("res://scenes/ui/stage_select.tscn")
const EscapistSelectScene := preload("res://scenes/ui/escapist_select.tscn")
const CharacterSelectScene := preload("res://scenes/ui/character_select.tscn")
const SettingsMenuScene := preload("res://scenes/ui/settings_menu.tscn")
const PauseMenuScene := preload("res://scenes/ui/pause_menu.gd")
const ArenaScene := preload("res://scenes/arena/arena.tscn")
const PhaseOverlayScene := preload("res://scenes/ui/phase_overlay.tscn")
const GameHudScene := preload("res://scenes/ui/game_hud.tscn")
const SurvivalEscapeHudScene := preload("res://scenes/ui/survival_escape_hud.gd")
const RoundReplayScene := preload("res://scenes/ui/round_replay.gd")
const EscapistScene := preload("res://scenes/characters/escapist/escapist.tscn")
const TrapperScene := preload("res://scenes/characters/trapper/trapper.tscn")
const SurvivalTrapperScene := preload("res://scenes/characters/trapper/survival_trapper.gd")
const SurvivalZombieScene := preload("res://scenes/characters/enemies/survival_zombie.gd")
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
const GAMEPLAY_TOP_MARGIN: float = 168.0
const SURVIVAL_DEFAULT_TEAM_SIZE: int = 3
const SURVIVAL_DEFAULT_BOT_FILL_VALUE: int = 0
const SURVIVAL_DEFAULT_USER_PLAYER_INDEX: int = 0
const SURVIVAL_EXIT_HOLD_DURATION: float = 3.0
const SURVIVAL_MAP_TRANSITION_DURATION: float = 1.25
const SURVIVAL_RESULT_ADVANCE_DELAY: float = 4.5
const SURVIVAL_COMPLETION_SCORE_BONUS: int = 10000
const SURVIVAL_TIME_SCORE_MULTIPLIER: float = 10.0

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
var survival_escape_setup
var official_briefing: OfficialBriefing
var team_setup: TeamSetup
var stage_select: StageSelect
var escapist_select: EscapistSelect
var character_select: CharacterSelect
var settings_menu: SettingsMenu
var pause_menu: PauseMenu
var phase_overlay: PhaseOverlay
var game_hud: GameHud
var survival_hud
var round_replay: RoundReplay
var menu_music: MenuMusicPlayer
var _is_first_round: bool = true  # Tracks if this is the initial pre-game select
var _is_practice_flow: bool = false
var _is_survival_flow: bool = false
var _survival_map_index: int = 0
var _survival_map_data: Dictionary = {}
var _survival_goal_escapists: Dictionary = {}
var _survival_match_finished: bool = false
var _survival_exit_hold_time: float = 0.0
var _survival_time_remaining: float = 0.0
var _survival_time_total: float = Constants.SURVIVAL_ESCAPE_DURATION
var _survival_zombies: Array[Node2D] = []
var _survival_wave_number: int = 0
var _survival_wave_timer: float = 0.0
var _survival_spawn_queue: int = 0
var _survival_spawn_step_timer: float = 0.0
var _survival_death_count: int = 0
var _survival_zombie_spawn_index: int = 0
var _survival_jailed_escapists: Dictionary = {}
var _survival_carryover_jailed: Dictionary = {}
var _survival_transition_timer: float = 0.0
var _survival_transition_target_map_index: int = -1
var _survival_transition_carryover_jailed: Dictionary = {}
var _survival_leg_elapsed: float = 0.0
var _survival_leg_time_budget: float = 0.0
var _survival_series_records: Array[Dictionary] = []
var _survival_series_initial_roles: Dictionary = {}
var _survival_series_leg_index: int = 0
var _survival_result_auto_advance_timer: float = 0.0
var _survival_final_series_complete: bool = false


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
	mode_select.survival_requested.connect(_start_survival_escape_setup)
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

	survival_escape_setup = SurvivalEscapeSetupScene.new()
	ui_layer.add_child(survival_escape_setup)
	survival_escape_setup.hide()
	survival_escape_setup.survival_ready.connect(_on_survival_escape_ready)
	survival_escape_setup.settings_requested.connect(_open_settings)
	survival_escape_setup.back_requested.connect(_start_mode_select)

	official_briefing = OfficialBriefingScene.new() as OfficialBriefing
	ui_layer.add_child(official_briefing)
	official_briefing.hide()
	official_briefing.briefing_finished.connect(_on_official_briefing_finished)
	official_briefing.back_requested.connect(_on_official_briefing_back)

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
	pause_menu.next_survival_map_requested.connect(_go_to_next_survival_map_from_pause)
	pause_menu.survival_map_requested.connect(_go_to_survival_map_from_pause)

	phase_overlay = PhaseOverlayScene.instantiate() as PhaseOverlay
	ui_layer.add_child(phase_overlay)
	phase_overlay.hide()
	phase_overlay.escape_finished.connect(_on_escape_overlay_finished)

	game_hud = GameHudScene.instantiate() as GameHud
	ui_layer.add_child(game_hud)
	game_hud.hide()

	survival_hud = SurvivalEscapeHudScene.new()
	ui_layer.add_child(survival_hud)
	survival_hud.hide()

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
	_hide_survival_hud()
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
	_hide_survival_hud()
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
	_is_survival_flow = false
	if arena:
		arena.queue_free()
		arena = null
	phase_overlay.clear()
	game_hud.hide()
	_hide_survival_hud()
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
	if GameManager.is_survival_context():
		how_to_play.open_survival()
	else:
		how_to_play.open()
	push_view(how_to_play)


func _close_how_to_play() -> void:
	pop_view()
	if pause_menu and (get_tree().paused or GameManager.current_state == Enums.GameState.PAUSED):
		_restore_pause_menu_after_subscreen()
		return
	if _view_stack.is_empty():
		_start_mode_select()


func _hide_survival_hud() -> void:
	if survival_hud:
		survival_hud.hide()


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
	_is_survival_flow = false
	if arena:
		arena.queue_free()
		arena = null
	phase_overlay.clear()
	game_hud.hide()
	_hide_survival_hud()
	menu_music.use_menu_volume()
	menu_music.start_music()

	while not _view_stack.is_empty():
		pop_view()

	practice_setup.setup()
	push_view(practice_setup)


func _start_survival_escape_setup(seed_device_id: int = -1) -> void:
	get_tree().paused = false
	_clear_pause_menu()
	_cleanup_round()
	_practice_bots_added = false
	_active_player_indices.clear()
	GameManager.reset_match()
	if not GameManager.settings_overrides.has(&"survival_static_bots"):
		GameManager.settings_overrides[&"survival_static_bots"] = true
	_apply_survival_setup_defaults()
	_is_practice_flow = false
	_is_survival_flow = true
	_reset_survival_series_state()
	if arena:
		arena.queue_free()
		arena = null
	phase_overlay.clear()
	game_hud.hide()
	_hide_survival_hud()
	menu_music.use_menu_volume()
	menu_music.start_music()

	while not _view_stack.is_empty():
		pop_view()

	survival_escape_setup.setup(seed_device_id)
	push_view(survival_escape_setup)


func _reset_survival_series_state() -> void:
	_survival_map_index = 0
	_survival_leg_elapsed = 0.0
	_survival_leg_time_budget = 0.0
	_survival_series_records.clear()
	_survival_series_initial_roles.clear()
	_survival_series_leg_index = 0
	_survival_result_auto_advance_timer = 0.0
	_survival_final_series_complete = false
	_survival_transition_timer = 0.0
	_survival_transition_target_map_index = -1
	_survival_transition_carryover_jailed.clear()
	GameManager.set_survival_score_records([])


func _apply_survival_setup_defaults() -> void:
	if not GameManager.settings_overrides.has(&"bot_fill"):
		GameManager.settings_overrides[&"bot_fill"] = SURVIVAL_DEFAULT_BOT_FILL_VALUE
	if not GameManager.settings_overrides.has(&"team_size"):
		GameManager.settings_overrides[&"team_size"] = SURVIVAL_DEFAULT_TEAM_SIZE
	var bot_fill_value: int = GameManager.settings_overrides.get(
		&"bot_fill",
		SURVIVAL_DEFAULT_BOT_FILL_VALUE
	) as int
	survival_escape_setup.auto_fill_bots = bot_fill_value == 0
	settings_menu.set_setting_value("bot_fill", bot_fill_value)
	settings_menu.set_setting_value("team_size", GameManager.settings_overrides.get(
		&"team_size",
		SURVIVAL_DEFAULT_TEAM_SIZE
	))


func _on_practice_ready(team_assignments: Dictionary, role_assignments: Dictionary) -> void:
	_is_practice_flow = true
	GameManager.set_practice_assignments(team_assignments, role_assignments)
	_active_player_indices.clear()
	for pi: int in team_assignments:
		_active_player_indices.append(pi)
	_active_player_indices.sort()
	_show_escapist_select(true)


func _on_survival_escape_ready(role_assignments: Dictionary) -> void:
	_is_practice_flow = false
	_is_survival_flow = true
	_reset_survival_series_state()
	_survival_series_initial_roles = role_assignments.duplicate()
	_survival_series_leg_index = 0
	_apply_survival_role_assignments(role_assignments)

	while not _view_stack.is_empty():
		pop_view()

	_begin_survival_leg()
	_start_survival_escape_session()


func _apply_survival_role_assignments(role_assignments: Dictionary) -> void:
	var team_assignments := _build_survival_team_assignments(role_assignments)
	_active_player_indices.clear()
	_assign_survival_character_choices(role_assignments)
	var assignment_indices: Array[int] = []
	for pi: int in role_assignments:
		assignment_indices.append(pi)
	assignment_indices.sort()
	for pi: int in assignment_indices:
		_active_player_indices.append(pi)
	GameManager.set_survival_assignments(team_assignments, role_assignments)


func _build_survival_team_assignments(role_assignments: Dictionary) -> Dictionary:
	var team_assignments: Dictionary = {}
	for pi: int in role_assignments:
		var role: Enums.Role = role_assignments[pi] as Enums.Role
		team_assignments[pi] = Enums.Team.TEAM_1 if role == Enums.Role.ESCAPIST else Enums.Team.TEAM_2
	return team_assignments


func _assign_survival_character_choices(role_assignments: Dictionary) -> void:
	var escapist_order := 0
	var trapper_order := 0
	var escapist_animals: Array[Enums.EscapistAnimal] = [
		Enums.EscapistAnimal.RAT,
		Enums.EscapistAnimal.SQUIRREL,
		Enums.EscapistAnimal.FLY,
	]
	var trapper_characters: Array[Enums.TrapperCharacter] = [
		Enums.TrapperCharacter.ARANA,
		Enums.TrapperCharacter.HONGO,
		Enums.TrapperCharacter.ESCORPION,
		Enums.TrapperCharacter.PULPO,
	]
	var rabbit_player_index := _get_survival_rabbit_player_index(role_assignments)
	var assignment_indices: Array[int] = []
	for pi: int in role_assignments:
		assignment_indices.append(pi)
	assignment_indices.sort()
	for pi: int in assignment_indices:
		var role: Enums.Role = role_assignments[pi] as Enums.Role
		GameManager.escapist_selections.erase(pi)
		GameManager.character_selections.erase(pi)
		if role == Enums.Role.ESCAPIST:
			if pi == rabbit_player_index:
				GameManager.escapist_selections[pi] = Enums.EscapistAnimal.RABBIT
			else:
				GameManager.escapist_selections[pi] = escapist_animals[escapist_order % escapist_animals.size()]
				escapist_order += 1
		else:
			GameManager.character_selections[pi] = trapper_characters[trapper_order % trapper_characters.size()]
			trapper_order += 1


func _begin_survival_leg() -> void:
	_survival_leg_elapsed = 0.0
	_survival_leg_time_budget = 0.0
	_survival_result_auto_advance_timer = 0.0
	_survival_final_series_complete = false
	_survival_transition_timer = 0.0
	_survival_transition_target_map_index = -1
	_survival_transition_carryover_jailed.clear()


func _get_survival_rabbit_player_index(role_assignments: Dictionary) -> int:
	if (role_assignments.get(SURVIVAL_DEFAULT_USER_PLAYER_INDEX, Enums.Role.NONE) as Enums.Role) == Enums.Role.ESCAPIST:
		return SURVIVAL_DEFAULT_USER_PLAYER_INDEX
	var escapist_indices: Array[int] = []
	for pi: int in role_assignments:
		if (role_assignments[pi] as Enums.Role) == Enums.Role.ESCAPIST:
			escapist_indices.append(pi)
	if escapist_indices.is_empty():
		return -1
	escapist_indices.sort()
	return escapist_indices[0]


func _start_team_setup() -> void:
	get_tree().paused = false
	_clear_pause_menu()
	_cleanup_round()
	_practice_bots_added = false
	_active_player_indices.clear()
	_is_practice_flow = false
	_is_survival_flow = false
	if arena:
		arena.queue_free()
		arena = null
	phase_overlay.clear()
	game_hud.hide()
	_hide_survival_hud()
	menu_music.use_menu_volume()
	menu_music.start_music()

	while not _view_stack.is_empty():
		pop_view()

	team_setup.setup()
	push_view(team_setup)


func _on_teams_ready(t_assignments: Dictionary) -> void:
	_is_practice_flow = false
	_is_survival_flow = false
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


func _on_official_briefing_back() -> void:
	pop_view()
	game_hud.hide()
	phase_overlay.clear()
	_is_first_round = true
	menu_music.use_menu_volume()
	menu_music.start_music()
	_show_character_select(true)
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


func _setup_survival_arena() -> void:
	if arena:
		arena.queue_free()
	arena = ArenaScene.instantiate() as Arena
	arena_container.add_child(arena)
	_survival_map_index = clampi(_survival_map_index, 0, MapData.get_survival_map_count() - 1)
	_survival_map_data = MapData.get_survival_map(_survival_map_index, _get_survival_format_size())
	if not _survival_jail_enabled():
		_survival_map_data.erase("survival_jail")
	arena.load_map(_survival_map_data)
	arena.goal_body_entered.connect(_on_survival_goal_body_entered)
	arena.goal_body_exited.connect(_on_survival_goal_body_exited)
	arena.survival_objective_changed.connect(_on_survival_objective_changed)
	if arena.has_signal("survival_jail_release_completed"):
		arena.survival_jail_release_completed.connect(_on_survival_jail_release_completed)
	_setup_camera()


func _start_survival_escape_session(start_map_index: int = 0, carryover_jailed: Dictionary = {}) -> void:
	_survival_map_index = clampi(start_map_index, 0, MapData.get_survival_map_count() - 1)
	_survival_carryover_jailed = carryover_jailed.duplicate()
	_survival_transition_timer = 0.0
	_survival_transition_target_map_index = -1
	_survival_transition_carryover_jailed.clear()
	_setup_survival_arena()
	_survival_goal_escapists.clear()
	_survival_jailed_escapists.clear()
	_survival_match_finished = false
	_survival_exit_hold_time = 0.0
	_survival_time_total = _get_survival_duration()
	_survival_time_remaining = _survival_time_total
	_survival_leg_time_budget += _survival_time_total
	_reset_survival_waves()
	game_hud.hide()
	if survival_hud:
		survival_hud.open(_get_survival_escapist_total(), _get_survival_trapper_total(), _survival_time_total)
		if survival_hud.has_method("set_map_info"):
			survival_hud.call(
				"set_map_info",
				_survival_map_data.get("name", "Mapa survival") as String,
				_survival_map_data.get("survival_map_number", _survival_map_index + 1) as int,
				_survival_map_data.get("survival_map_total", MapData.get_survival_map_count()) as int
			)
		_update_survival_objective_hud()
		_update_survival_wave_hud()
	menu_music.use_round_volume()
	GameManager.start_survival()
	_prime_start_button_state()
	InputManager.suppress_edge_detection(3)


func _setup_camera() -> void:
	if not arena:
		return
	var map_size := arena.get_map_size()
	var viewport_size := get_viewport_rect().size
	var reserved_top := minf(GAMEPLAY_TOP_MARGIN, viewport_size.y * 0.24)
	var gameplay_size := Vector2(viewport_size.x, maxf(viewport_size.y - reserved_top, viewport_size.y * 0.55))
	var padding := Vector2(24.0, 24.0)
	var zoom_x := viewport_size.x / (map_size.x + padding.x)
	var zoom_y := gameplay_size.y / (map_size.y + padding.y)
	var target_zoom := minf(zoom_x, zoom_y)
	camera.position = map_size / 2.0
	if target_zoom > 0.0:
		camera.position.y -= reserved_top / (target_zoom * 2.0)
	camera.zoom = Vector2(target_zoom, target_zoom)


func _on_viewport_size_changed() -> void:
	_setup_camera()


func _on_goal_entered(escapist: Escapist) -> void:
	_capture_round_replay_finish(escapist)
	GameManager.register_escapist_scored(escapist.player_index)


func _on_survival_goal_body_entered(body: Node2D) -> void:
	if GameManager.current_state != Enums.GameState.SURVIVAL or _survival_match_finished:
		return
	if not body is Escapist:
		return
	var esc := body as Escapist
	if esc.is_dead:
		return
	if esc.get_meta("survival_jailed", false) as bool:
		return
	esc.set_meta("survival_safe_zone", true)
	_survival_goal_escapists[esc.player_index] = true
	_update_survival_exit_hud()
	_check_survival_escape_complete()


func _on_survival_goal_body_exited(body: Node2D) -> void:
	if GameManager.current_state != Enums.GameState.SURVIVAL or _survival_match_finished:
		return
	if not body is Escapist:
		return
	var esc := body as Escapist
	esc.set_meta("survival_safe_zone", false)
	_survival_goal_escapists.erase(esc.player_index)
	_survival_exit_hold_time = 0.0
	_update_survival_exit_hud()


func _update_survival_exit_hud() -> void:
	if survival_hud:
		survival_hud.set_exit_count(
			_survival_goal_escapists.size(),
			_get_survival_required_exit_count(),
			_survival_exit_hold_time,
			SURVIVAL_EXIT_HOLD_DURATION
		)


func _on_survival_objective_changed(_status: Dictionary) -> void:
	_update_survival_objective_hud()
	_update_survival_exit_hud()
	_check_survival_escape_complete()


func _update_survival_objective_hud() -> void:
	if survival_hud and arena and arena.has_method("get_survival_objective_status"):
		var status := arena.call("get_survival_objective_status") as Dictionary
		survival_hud.set_objective_status(status)


func _check_survival_escape_complete() -> void:
	if _survival_can_hold_exit():
		return
	if _survival_exit_hold_time > 0.0:
		_survival_exit_hold_time = 0.0
		_update_survival_exit_hud()


func _process_survival_exit_hold(delta: float) -> void:
	if not _survival_can_hold_exit():
		if _survival_exit_hold_time > 0.0:
			_survival_exit_hold_time = 0.0
			_update_survival_exit_hud()
		return
	_survival_exit_hold_time = minf(_survival_exit_hold_time + delta, SURVIVAL_EXIT_HOLD_DURATION)
	_update_survival_exit_hud()
	if _survival_exit_hold_time >= SURVIVAL_EXIT_HOLD_DURATION:
		_complete_survival_map_escape()


func _survival_can_hold_exit() -> bool:
	var required := _get_survival_required_exit_count()
	if required <= 0:
		return false
	if not _survival_objectives_complete():
		return false
	return _survival_goal_escapists.size() >= required


func _get_survival_required_exit_count() -> int:
	var total := _get_survival_escapist_total()
	if total <= 0:
		return 0
	var jailed := _get_survival_jailed_count()
	if jailed > 0 and jailed < total:
		return total - jailed
	return total


func _get_survival_jailed_count() -> int:
	var count := 0
	var stale_keys: Array = []
	for player_index in _survival_jailed_escapists.keys():
		var esc := _survival_jailed_escapists[player_index] as Escapist
		if is_instance_valid(esc) and (esc.get_meta("survival_jailed", false) as bool):
			count += 1
		else:
			stale_keys.append(player_index)
	for player_index in stale_keys:
		_survival_jailed_escapists.erase(player_index)
	return count


func _complete_survival_map_escape() -> void:
	if _survival_match_finished:
		return
	var next_map_index := _survival_map_index + 1
	if next_map_index >= MapData.get_survival_map_count():
		_finish_survival_escape(true, "Completaron los 5 mapas.")
		return
	_begin_survival_map_transition(next_map_index, _get_survival_jailed_player_set())


func _begin_survival_map_transition(next_map_index: int, carryover_jailed: Dictionary) -> void:
	if _survival_transition_timer > 0.0:
		return
	_survival_transition_target_map_index = clampi(next_map_index, 0, MapData.get_survival_map_count() - 1)
	_survival_transition_carryover_jailed = carryover_jailed.duplicate()
	_survival_transition_timer = SURVIVAL_MAP_TRANSITION_DURATION
	_survival_exit_hold_time = 0.0
	_freeze_all()
	_set_survival_zombies_active(false)
	if survival_hud and survival_hud.has_method("start_map_transition"):
		var next_map := MapData.get_survival_map(_survival_transition_target_map_index, _get_survival_format_size())
		survival_hud.call(
			"start_map_transition",
			_survival_map_index + 1,
			_survival_transition_target_map_index + 1,
			next_map.get("name", "Mapa survival") as String,
			SURVIVAL_MAP_TRANSITION_DURATION
		)


func _update_survival_map_transition(delta: float) -> void:
	if _survival_transition_timer <= 0.0:
		return
	_survival_transition_timer = maxf(_survival_transition_timer - delta, 0.0)
	if _survival_transition_timer > 0.0:
		return
	var target_map_index := _survival_transition_target_map_index
	var carryover_jailed := _survival_transition_carryover_jailed.duplicate()
	_survival_transition_target_map_index = -1
	_survival_transition_carryover_jailed.clear()
	_start_survival_escape_session(target_map_index, carryover_jailed)


func _get_survival_jailed_player_set() -> Dictionary:
	var jailed: Dictionary = {}
	for player_index in _survival_jailed_escapists.keys():
		var esc := _survival_jailed_escapists[player_index] as Escapist
		if is_instance_valid(esc) and (esc.get_meta("survival_jailed", false) as bool):
			jailed[player_index] = true
	return jailed


func _survival_objectives_complete() -> bool:
	if arena == null or not arena.has_method("get_survival_objective_status"):
		return true
	var status := arena.call("get_survival_objective_status") as Dictionary
	return status.get("exit_unlocked", true) as bool


func _finish_survival_escape(escapists_won: bool, reason: String = "") -> void:
	if _survival_match_finished:
		return
	_survival_match_finished = true
	_survival_transition_timer = 0.0
	_freeze_all()
	_set_survival_zombies_active(false)
	if not escapists_won and arena and arena.has_method("reveal_survival_objectives"):
		arena.call("reveal_survival_objectives")
	var record := _record_survival_leg_result(escapists_won, reason)
	if survival_hud:
		var text := "ESCAPISTAS ESCAPARON" if escapists_won else "CAZADORES GANARON"
		var color := Enums.role_color(Enums.Role.ESCAPIST) if escapists_won else Enums.role_color(Enums.Role.TRAPPER)
		var required := _get_survival_required_exit_count()
		var total := _get_survival_escapist_total()
		var hint := _get_survival_result_hint(record, escapists_won, reason)
		if escapists_won and required < total:
			hint = "%s\n%d escapistas avanzaron; %d quedaron en carcel." % [hint, required, total - required]
		var footer := "Start continua"
		if _survival_series_records.size() >= 2:
			text = "IDA Y VUELTA COMPLETADA"
			color = Color(1.0, 0.88, 0.22)
			hint = _get_survival_series_summary()
			footer = "Start volver a setup"
		else:
			hint = "%s\nCambio de roles en %.0fs." % [hint, SURVIVAL_RESULT_ADVANCE_DELAY]
		survival_hud.show_result(text, color, hint, footer)
	_survival_final_series_complete = _survival_series_records.size() >= 2
	_survival_result_auto_advance_timer = 0.0
	if not _survival_final_series_complete:
		_survival_result_auto_advance_timer = SURVIVAL_RESULT_ADVANCE_DELAY


func _get_survival_duration() -> float:
	var map_duration: float = _survival_map_data.get("survival_duration", Constants.SURVIVAL_ESCAPE_DURATION) as float
	return GameManager.settings_overrides.get(&"survival_escape_duration", map_duration) as float


func _record_survival_leg_result(escapists_won: bool, reason: String) -> Dictionary:
	var time_remaining := maxf(_survival_leg_time_budget - _survival_leg_elapsed, 0.0)
	var score := 0
	if escapists_won:
		score = SURVIVAL_COMPLETION_SCORE_BONUS + int(round(time_remaining * SURVIVAL_TIME_SCORE_MULTIPLIER))
	var record := {
		"leg": _survival_series_leg_index + 1,
		"side": _survival_series_leg_index,
		"label": _get_survival_series_side_label(_survival_series_leg_index),
		"completed": escapists_won,
		"elapsed": _survival_leg_elapsed,
		"time_budget": _survival_leg_time_budget,
		"score": score,
		"map_reached": _survival_map_index + 1,
		"reason": reason,
	}
	_survival_series_records.append(record)
	GameManager.set_survival_score_records(_survival_series_records)
	return record


func _get_survival_result_hint(record: Dictionary, escapists_won: bool, reason: String) -> String:
	var label := record.get("label", "Equipo") as String
	if escapists_won:
		return "%s completo el set en %s. Puntaje: %d." % [
			label,
			_format_survival_time(record.get("elapsed", 0.0) as float),
			record.get("score", 0) as int,
		]
	if reason.is_empty():
		reason = "Los escapistas no lograron completar el set."
	return "%s: %s" % [label, reason]


func _get_survival_series_summary() -> String:
	var lines: Array[String] = []
	for record in _survival_series_records:
		lines.append(_format_survival_record(record))
	if _survival_series_records.size() >= 2:
		lines.append(_get_survival_series_winner_line())
	var summary := ""
	for i in lines.size():
		if i > 0:
			summary += "\n"
		summary += lines[i]
	return summary


func _format_survival_record(record: Dictionary) -> String:
	var label := record.get("label", "Equipo") as String
	var completed := record.get("completed", false) as bool
	if completed:
		return "%s: %d pts | %s" % [
			label,
			record.get("score", 0) as int,
			_format_survival_time(record.get("elapsed", 0.0) as float),
		]
	return "%s: derrota en mapa %d" % [
		label,
		record.get("map_reached", 1) as int,
	]


func _get_survival_series_winner_line() -> String:
	var first := _survival_series_records[0]
	var second := _survival_series_records[1]
	var first_completed := first.get("completed", false) as bool
	var second_completed := second.get("completed", false) as bool
	if first_completed and second_completed:
		var first_score := first.get("score", 0) as int
		var second_score := second.get("score", 0) as int
		if first_score == second_score:
			return "Resultado: empate."
		var score_winner := first if first_score > second_score else second
		return "Gana %s por mejor tiempo." % (score_winner.get("label", "Equipo") as String)
	if first_completed != second_completed:
		var completed_winner := first if first_completed else second
		return "Gana %s por completar el set." % (completed_winner.get("label", "Equipo") as String)
	return "Resultado: ningun equipo completo los 5 mapas."


func _get_survival_series_side_label(side_index: int) -> String:
	return "Equipo A" if side_index == 0 else "Equipo B"


func _format_survival_time(seconds: float) -> String:
	var whole := int(ceilf(maxf(seconds, 0.0)))
	var minutes := int(floorf(float(whole) / 60.0))
	var secs := whole % 60
	return "%d:%02d" % [minutes, secs]


func _get_survival_timeout_reason() -> String:
	if _survival_map_index >= MapData.get_survival_map_count() - 1:
		return "Se termino el tiempo antes de completar el mapa final."
	return "Se termino el tiempo y nadie avanzo al siguiente mapa."


func _update_survival_escape(delta: float) -> void:
	if _survival_match_finished:
		return
	_survival_leg_elapsed += delta
	_survival_time_remaining = maxf(_survival_time_remaining - delta, 0.0)
	if survival_hud:
		survival_hud.set_time_remaining(_survival_time_remaining)
	if _survival_time_remaining <= 0.0:
		_finish_survival_escape(false, _get_survival_timeout_reason())
		return
	_process_survival_exit_hold(delta)


func _reset_survival_waves() -> void:
	for zombie in _survival_zombies:
		if is_instance_valid(zombie):
			zombie.queue_free()
	_survival_zombies.clear()
	_survival_wave_number = 0
	_survival_wave_timer = Constants.SURVIVAL_FIRST_WAVE_DELAY
	_survival_spawn_queue = 0
	_survival_spawn_step_timer = 0.0
	_survival_death_count = 0
	_survival_zombie_spawn_index = 0


func _update_survival_waves(delta: float) -> void:
	if _survival_match_finished:
		return
	_survival_wave_timer = maxf(_survival_wave_timer - delta, 0.0)
	if _survival_spawn_queue > 0:
		_survival_spawn_step_timer = maxf(_survival_spawn_step_timer - delta, 0.0)
		while _survival_spawn_queue > 0 and _survival_spawn_step_timer <= 0.0:
			_spawn_survival_zombie()
			_survival_spawn_queue -= 1
			_survival_spawn_step_timer += Constants.SURVIVAL_ZOMBIE_SPAWN_STEP
	if _survival_wave_timer <= 0.0 and _survival_spawn_queue <= 0:
		_start_survival_wave()
	_update_survival_wave_hud()


func _start_survival_wave() -> void:
	_survival_wave_number += 1
	_survival_spawn_queue = Constants.SURVIVAL_WAVE_BASE_COUNT \
		+ (_survival_wave_number - 1) * Constants.SURVIVAL_WAVE_GROWTH \
		+ int(floorf(float(_survival_death_count) * 0.5))
	_survival_spawn_step_timer = 0.0
	var death_pressure := minf(float(_survival_death_count) * 1.5, 10.0)
	_survival_wave_timer = maxf(Constants.SURVIVAL_WAVE_INTERVAL - death_pressure, 10.0)
	_apply_survival_zombie_speed()


func _spawn_survival_zombie() -> void:
	if arena == null:
		return
	var spawn_position := _get_survival_zombie_spawn(_survival_zombie_spawn_index)
	_survival_zombie_spawn_index += 1
	var zombie = SurvivalZombieScene.new()
	zombie.setup(_survival_zombie_spawn_index, spawn_position, _get_survival_zombie_speed())
	zombie.escapist_caught.connect(_on_survival_zombie_caught)
	character_container.add_child(zombie)
	_survival_zombies.append(zombie)


func _get_survival_zombie_spawn(index: int) -> Vector2:
	var spawns: Array = _survival_map_data.get("survival_zombie_spawns", []) as Array
	if not spawns.is_empty():
		return spawns[index % spawns.size()] as Vector2
	var map_size := arena.get_map_size() if arena else Vector2(1500.0, 860.0)
	return Vector2(map_size.x * 0.5, 80.0)


func _get_survival_zombie_speed() -> float:
	var wave_bonus := maxf(float(_survival_wave_number - 1), 0.0) * Constants.SURVIVAL_ZOMBIE_SPEED_PER_WAVE
	return Constants.SURVIVAL_ZOMBIE_SPEED \
		+ wave_bonus \
		+ float(_survival_death_count) * Constants.SURVIVAL_ZOMBIE_SPEED_PER_DEATH


func _apply_survival_zombie_speed() -> void:
	var updated_speed := _get_survival_zombie_speed()
	for zombie in _survival_zombies:
		if is_instance_valid(zombie):
			zombie.set("move_speed", updated_speed)


func _get_survival_zombie_alive_count() -> int:
	var alive := 0
	var valid_zombies: Array[Node2D] = []
	for zombie in _survival_zombies:
		if not is_instance_valid(zombie):
			continue
		valid_zombies.append(zombie)
		alive += 1
	_survival_zombies = valid_zombies
	return alive


func _update_survival_wave_hud() -> void:
	if survival_hud:
		survival_hud.set_wave_status(
			_survival_wave_number,
			_get_survival_zombie_alive_count(),
			_survival_death_count,
			_survival_wave_timer
		)


func _on_survival_zombie_caught(escapist: Escapist, _zombie: Node) -> void:
	if GameManager.current_state != Enums.GameState.SURVIVAL or _survival_match_finished:
		return
	if not is_instance_valid(escapist) or escapist.is_dead or escapist.has_scored:
		return
	if escapist.is_effect_immune():
		return
	_survival_death_count += 1
	_survival_goal_escapists.erase(escapist.player_index)
	_survival_exit_hold_time = 0.0
	escapist.set_meta("survival_safe_zone", false)
	escapist.notify_trap_status("ZOMBIE", Color(0.60, 1.0, 0.42), 0.9)
	if arena and arena.has_method("drop_survival_keys_for_escapist"):
		arena.call("drop_survival_keys_for_escapist", escapist)
	escapist.respawn()
	for zombie in _survival_zombies:
		if is_instance_valid(zombie) and zombie.has_method("release_if_attached_to"):
			zombie.call("release_if_attached_to", escapist)
	_survival_wave_timer = maxf(_survival_wave_timer - 3.0, 4.0)
	_apply_survival_zombie_speed()
	_update_survival_exit_hud()
	_update_survival_wave_hud()


func _on_survival_escapist_respawning(escapist: Escapist, death_position: Vector2) -> void:
	if GameManager.current_state != Enums.GameState.SURVIVAL or _survival_match_finished:
		return
	_survival_goal_escapists.erase(escapist.player_index)
	_survival_exit_hold_time = 0.0
	escapist.set_meta("survival_safe_zone", false)
	if arena and arena.has_method("drop_survival_keys_for_escapist_at"):
		arena.call("drop_survival_keys_for_escapist_at", escapist, death_position)
	if _survival_jail_enabled():
		_prepare_survival_escapist_jail_respawn(escapist)
		call_deferred("_lock_survival_jailed_escapist", escapist)


func _on_survival_escapist_died(escapist: Escapist) -> void:
	if GameManager.current_state != Enums.GameState.SURVIVAL or _survival_match_finished:
		return
	_survival_goal_escapists.erase(escapist.player_index)
	_survival_exit_hold_time = 0.0
	escapist.set_meta("survival_safe_zone", false)
	if arena and arena.has_method("drop_survival_keys_for_escapist"):
		arena.call("drop_survival_keys_for_escapist", escapist)
	if _survival_jail_enabled():
		_prepare_survival_escapist_jail_respawn(escapist)
	call_deferred("_revive_survival_dead_escapist", escapist)


func _survival_jail_enabled() -> bool:
	return _get_survival_escapist_total() > 1


func _prepare_survival_escapist_jail_respawn(escapist: Escapist) -> void:
	if arena == null or not arena.has_method("get_survival_jail_spawn_position"):
		return
	escapist.spawn_position = arena.call("get_survival_jail_spawn_position") as Vector2
	escapist.set_meta("survival_jailed", true)


func _revive_survival_dead_escapist(escapist: Escapist) -> void:
	if not is_instance_valid(escapist) or not escapist.is_dead:
		return
	if escapist.has_method("revive_from_death_at_spawn"):
		escapist.call("revive_from_death_at_spawn")
	if escapist.get_meta("survival_jailed", false) as bool:
		_lock_survival_jailed_escapist(escapist)


func _lock_survival_jailed_escapist(escapist: Escapist) -> void:
	if not is_instance_valid(escapist) or not (escapist.get_meta("survival_jailed", false) as bool):
		return
	_survival_jailed_escapists[escapist.player_index] = escapist
	_survival_goal_escapists.erase(escapist.player_index)
	_survival_exit_hold_time = 0.0
	escapist.set_meta("survival_safe_zone", false)
	escapist.input_locked = true
	if escapist.movement:
		escapist.movement.freeze()
	escapist.notify_trap_status("CARCEL", Color(0.45, 0.85, 1.0), 0.9)
	_update_survival_jail_state()
	_update_survival_exit_hud()
	_check_survival_all_jailed_defeat()


func _on_survival_jail_release_completed(_rescuer: Escapist) -> void:
	for player_index in _survival_jailed_escapists.keys():
		var esc := _survival_jailed_escapists[player_index] as Escapist
		if not is_instance_valid(esc):
			_survival_jailed_escapists.erase(player_index)
			continue
		_release_survival_jailed_escapist(esc)
		break
	_update_survival_jail_state()


func _release_survival_jailed_escapist(escapist: Escapist) -> void:
	_survival_jailed_escapists.erase(escapist.player_index)
	escapist.set_meta("survival_jailed", false)
	if arena and arena.has_method("get_survival_jail_release_position"):
		escapist.global_position = arena.call("get_survival_jail_release_position") as Vector2
	escapist.input_locked = false
	if escapist.movement:
		escapist.movement.unfreeze()
	escapist.notify_trap_status("LIBRE", Color(0.45, 1.0, 0.72), 0.9)
	_survival_exit_hold_time = 0.0
	_update_survival_exit_hud()


func _update_survival_jail_state() -> void:
	if arena and arena.has_method("set_survival_jail_has_prisoner"):
		arena.call("set_survival_jail_has_prisoner", not _survival_jailed_escapists.is_empty())


func _check_survival_all_jailed_defeat() -> void:
	if _survival_match_finished or _survival_transition_timer > 0.0:
		return
	var total := _get_survival_escapist_total()
	if total <= 0:
		return
	if _get_survival_jailed_count() >= total:
		_finish_survival_escape(false, "Todos los escapistas quedaron encerrados en la carcel.")


func _set_survival_zombies_active(active: bool) -> void:
	for zombie in _survival_zombies:
		if is_instance_valid(zombie) and zombie.has_method("set_active"):
			zombie.call("set_active", active)


func _cleanup_round() -> void:
	_clear_round_replay()
	for c in characters:
		if is_instance_valid(c):
			c.queue_free()
	characters.clear()
	for zombie in get_tree().get_nodes_in_group("survival_zombies"):
		zombie.queue_free()
	_survival_zombies.clear()
	for node in get_tree().get_nodes_in_group("traps"):
		node.queue_free()
	for node in get_tree().get_nodes_in_group("projectiles"):
		node.queue_free()


func _spawn_characters() -> void:
	_cleanup_round()

	var escapist_idx := 0
	var map_bounds := _get_character_map_bounds()

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
			esc.set_meta("map_bounds", map_bounds)
			esc.aim_direction = Vector2.RIGHT
			if pi >= 100:
				esc.configure_official_route_bot(_build_official_escapist_bot_route(esc.position))
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
			trapper.set_meta("map_bounds", map_bounds)
			trapper.setup(arena.get_map_size())
			if pi >= 100:
				_configure_official_trapper_bot(trapper)
			character_container.add_child(trapper)
			characters.append(trapper)
			GameManager.register_player_character(pi, trapper)


func _spawn_survival_characters() -> void:
	_cleanup_round()
	var escapist_idx := 0
	var trapper_idx := 0
	var map_bounds := _get_character_map_bounds()

	for pi in _active_player_indices:
		var t: Enums.Team = GameManager.get_player_team(pi)
		var r: Enums.Role = GameManager.get_player_role(pi)

		if r == Enums.Role.ESCAPIST:
			var esc := EscapistScene.instantiate() as Escapist
			esc.player_index = pi
			esc.team = t
			esc.escapist_animal = GameManager.get_player_escapist_animal(pi)
			esc.player_color = Enums.escapist_animal_color(esc.escapist_animal)
			var starts_jailed := _survival_carryover_jailed.has(pi) and _survival_jail_enabled()
			esc.position = _get_survival_escapist_spawn(escapist_idx)
			if starts_jailed and arena and arena.has_method("get_survival_jail_spawn_position"):
				esc.position = arena.call("get_survival_jail_spawn_position") as Vector2
			esc.set_meta("map_bounds", map_bounds)
			esc.set_meta("survival_safe_zone", false)
			esc.set_meta("survival_jailed", starts_jailed)
			esc.spawn_position = esc.position
			esc.aim_direction = Vector2.RIGHT
			escapist_idx += 1
			if pi >= 100 and not _survival_bots_static() and esc.has_method("configure_survival_objective_bot"):
				esc.call("configure_survival_objective_bot", _build_survival_escapist_bot_route(esc.position, escapist_idx - 1))
			esc.respawning.connect(_on_survival_escapist_respawning)
			esc.died.connect(_on_survival_escapist_died)
			character_container.add_child(esc)
			characters.append(esc)
			GameManager.register_player_character(pi, esc)
			if starts_jailed:
				call_deferred("_lock_survival_jailed_escapist", esc)
		elif r == Enums.Role.TRAPPER:
			var trapper = SurvivalTrapperScene.new()
			trapper.player_index = pi
			trapper.team = t
			trapper.trapper_character = GameManager.get_player_character(pi)
			trapper.player_color = Enums.trapper_character_color(trapper.trapper_character)
			trapper.position = _get_survival_trapper_spawn(trapper_idx)
			trapper.set_meta("map_bounds", map_bounds)
			trapper.aim_direction = Vector2.LEFT
			trapper_idx += 1
			if pi >= 100 and not _survival_bots_static() and trapper.has_method("configure_survival_bot"):
				trapper.call("configure_survival_bot")
			character_container.add_child(trapper)
			characters.append(trapper)
			GameManager.register_player_character(pi, trapper)
	_survival_carryover_jailed.clear()


func _get_survival_escapist_spawn(index: int) -> Vector2:
	var spawns: Array = _survival_map_data.get("spawns", []) as Array
	if index < spawns.size():
		return spawns[index] as Vector2
	return arena.get_map_center() if arena else Vector2.ZERO


func _get_survival_trapper_spawn(index: int) -> Vector2:
	var spawns: Array = _survival_map_data.get("survival_trapper_spawns", []) as Array
	if index < spawns.size():
		return spawns[index] as Vector2
	return arena.get_map_center() if arena else Vector2.ZERO


func _get_character_map_bounds() -> Rect2:
	if arena == null:
		return Rect2(Vector2.ZERO, Vector2.ZERO)
	return Rect2(Vector2.ZERO, arena.get_map_size()).grow(-Constants.CHARACTER_RADIUS - 2.0)


func _get_survival_format_size() -> int:
	var role_max := maxi(_get_survival_escapist_total(), _get_survival_trapper_total())
	return clampi(maxi(role_max, 1), 1, 4)


func _survival_bots_static() -> bool:
	return GameManager.settings_overrides.get(&"survival_static_bots", true) as bool


func _apply_survival_bot_static_setting() -> void:
	if not GameManager.is_survival_context():
		return
	var make_static := _survival_bots_static()
	var escapist_bot_order := 0
	for c in characters:
		if not is_instance_valid(c) or not c is BaseCharacter:
			continue
		var character := c as BaseCharacter
		if character.player_index < 100:
			continue
		if c is Escapist:
			var esc := c as Escapist
			if make_static:
				if esc.has_method("set_survival_bot_static"):
					esc.call("set_survival_bot_static", true)
			elif esc.has_method("configure_survival_objective_bot"):
				esc.call("configure_survival_objective_bot",
					_build_survival_escapist_bot_route(esc.global_position, escapist_bot_order))
			escapist_bot_order += 1
		elif character.role == Enums.Role.TRAPPER:
			if make_static:
				if c.has_method("set_survival_bot_static"):
					c.call("set_survival_bot_static", true)
			elif c.has_method("configure_survival_bot"):
				c.call("configure_survival_bot")


func _get_survival_escapist_total() -> int:
	var total := 0
	for pi: int in GameManager.role_assignments:
		if GameManager.role_assignments[pi] == Enums.Role.ESCAPIST:
			total += 1
	return total


func _get_survival_trapper_total() -> int:
	var total := 0
	for pi: int in GameManager.role_assignments:
		if GameManager.role_assignments[pi] == Enums.Role.TRAPPER:
			total += 1
	return total


func _build_official_escapist_bot_route(spawn_position: Vector2) -> Array[Vector2]:
	if arena == null:
		return []
	var route: Array[Vector2] = []
	if spawn_position.y < 520.0:
		route.append_array([
			Vector2(260.0, 320.0),
			Vector2(820.0, 300.0),
			Vector2(1040.0, 500.0),
			Vector2(1300.0, 560.0),
		])
	elif spawn_position.y < 720.0:
		route.append_array([
			Vector2(260.0, 610.0),
			Vector2(840.0, 620.0),
			Vector2(1100.0, 610.0),
			Vector2(1300.0, 560.0),
		])
	else:
		route.append_array([
			Vector2(260.0, 920.0),
			Vector2(820.0, 925.0),
			Vector2(1085.0, 780.0),
			Vector2(1300.0, 650.0),
		])
	route.append_array([
		Vector2(1500.0, 600.0),
		Vector2(1720.0, 600.0),
		Vector2(1860.0, 600.0),
		Vector2(1985.0, 640.0),
		Vector2(2120.0, 640.0),
		Vector2(2245.0, 640.0),
		arena.get_goal_center(),
	])
	return route


func _build_survival_escapist_bot_route(spawn_position: Vector2, bot_order: int) -> Array[Dictionary]:
	var route: Array[Dictionary] = []
	_add_survival_bot_waypoint(route, spawn_position + _scale_survival_route_point(Vector2(90.0, 0.0)))
	var locks: Array = _survival_map_data.get("survival_locks", []) as Array
	if locks.is_empty():
		if arena:
			_add_survival_bot_waypoint(route, arena.get_goal_center())
		return route
	var lock_count := locks.size()
	for offset in range(lock_count):
		var lock_def := locks[(bot_order + offset) % lock_count] as Dictionary
		_add_survival_bot_lock_route(route, lock_def)
	if arena:
		_add_survival_bot_waypoint(route, arena.get_goal_center())
	return route


func _add_survival_bot_lock_route(route: Array[Dictionary], lock_def: Dictionary) -> void:
	var lock_id := lock_def.get("id", "") as String
	var key_rect: Rect2 = lock_def.get("key_rect", Rect2()) as Rect2
	var gate_rect: Rect2 = lock_def.get("gate_rect", Rect2()) as Rect2
	var button_rect: Rect2 = lock_def.get("button_rect", Rect2()) as Rect2
	if key_rect.size.x <= 0.0 or gate_rect.size.x <= 0.0:
		return
	_add_survival_bot_approach_to_key(route, lock_id)
	_add_survival_bot_waypoint(route, key_rect.get_center(), 3.25, 32.0)
	_add_survival_bot_approach_to_gate(route, lock_id)
	_add_survival_bot_waypoint(route, gate_rect.get_center(), 3.25, 58.0)
	if button_rect.size.x > 0.0:
		_add_survival_bot_approach_to_button(route, lock_id)
		_add_survival_bot_waypoint(route, button_rect.get_center(), 0.35, 24.0)


func _add_survival_bot_approach_to_key(route: Array[Dictionary], lock_id: String) -> void:
	if _survival_map_index == 4:
		match lock_id:
			"blue":
				_add_survival_bot_waypoint(route, _scale_survival_route_point(Vector2(232.0, 368.0)))
				_add_survival_bot_waypoint(route, _scale_survival_route_point(Vector2(368.0, 384.0)))
				_add_survival_bot_waypoint(route, _scale_survival_route_point(Vector2(536.0, 392.0)))
				_add_survival_bot_waypoint(route, _scale_survival_route_point(Vector2(624.0, 304.0)))
				_add_survival_bot_waypoint(route, _scale_survival_route_point(Vector2(672.0, 240.0)))
			"red":
				_add_survival_bot_waypoint(route, _scale_survival_route_point(Vector2(320.0, 568.0)))
				_add_survival_bot_waypoint(route, _scale_survival_route_point(Vector2(360.0, 632.0)))
				_add_survival_bot_waypoint(route, _scale_survival_route_point(Vector2(480.0, 808.0)))
				_add_survival_bot_waypoint(route, _scale_survival_route_point(Vector2(480.0, 912.0)))
				_add_survival_bot_waypoint(route, _scale_survival_route_point(Vector2(1408.0, 920.0)))
				_add_survival_bot_waypoint(route, _scale_survival_route_point(Vector2(1480.0, 888.0)))
			"yellow":
				_add_survival_bot_waypoint(route, _scale_survival_route_point(Vector2(232.0, 368.0)))
				_add_survival_bot_waypoint(route, _scale_survival_route_point(Vector2(368.0, 384.0)))
				_add_survival_bot_waypoint(route, _scale_survival_route_point(Vector2(560.0, 544.0)))
				_add_survival_bot_waypoint(route, _scale_survival_route_point(Vector2(672.0, 544.0)))
				_add_survival_bot_waypoint(route, _scale_survival_route_point(Vector2(768.0, 520.0)))
			"violet":
				_add_survival_bot_waypoint(route, _scale_survival_route_point(Vector2(232.0, 368.0)))
				_add_survival_bot_waypoint(route, _scale_survival_route_point(Vector2(368.0, 384.0)))
				_add_survival_bot_waypoint(route, _scale_survival_route_point(Vector2(656.0, 392.0)))
				_add_survival_bot_waypoint(route, _scale_survival_route_point(Vector2(736.0, 368.0)))
				_add_survival_bot_waypoint(route, _scale_survival_route_point(Vector2(888.0, 520.0)))
				_add_survival_bot_waypoint(route, _scale_survival_route_point(Vector2(1072.0, 560.0)))
				_add_survival_bot_waypoint(route, _scale_survival_route_point(Vector2(1192.0, 512.0)))
				_add_survival_bot_waypoint(route, _scale_survival_route_point(Vector2(1280.0, 488.0)))
				_add_survival_bot_waypoint(route, _scale_survival_route_point(Vector2(1448.0, 424.0)))
			"orange":
				_add_survival_bot_waypoint(route, _scale_survival_route_point(Vector2(192.0, 384.0)))
				_add_survival_bot_waypoint(route, _scale_survival_route_point(Vector2(376.0, 400.0)))
				_add_survival_bot_waypoint(route, _scale_survival_route_point(Vector2(528.0, 528.0)))
				_add_survival_bot_waypoint(route, _scale_survival_route_point(Vector2(600.0, 592.0)))
				_add_survival_bot_waypoint(route, _scale_survival_route_point(Vector2(600.0, 760.0)))
				_add_survival_bot_waypoint(route, _scale_survival_route_point(Vector2(1040.0, 768.0)))
				_add_survival_bot_waypoint(route, _scale_survival_route_point(Vector2(1112.0, 808.0)))
			_:
				_add_survival_bot_waypoint(route, _scale_survival_route_point(Vector2(900.0, 520.0)))
		return
	if _survival_map_index == 3:
		match lock_id:
			"blue":
				_add_survival_bot_waypoint(route, _scale_survival_route_point(Vector2(345.0, 350.0)))
				_add_survival_bot_waypoint(route, _scale_survival_route_point(Vector2(500.0, 350.0)))
				_add_survival_bot_waypoint(route, _scale_survival_route_point(Vector2(610.0, 250.0)))
			"red":
				_add_survival_bot_waypoint(route, _scale_survival_route_point(Vector2(345.0, 710.0)))
				_add_survival_bot_waypoint(route, _scale_survival_route_point(Vector2(560.0, 740.0)))
				_add_survival_bot_waypoint(route, _scale_survival_route_point(Vector2(900.0, 740.0)))
				_add_survival_bot_waypoint(route, _scale_survival_route_point(Vector2(1180.0, 740.0)))
				_add_survival_bot_waypoint(route, _scale_survival_route_point(Vector2(1380.0, 780.0)))
			"yellow":
				_add_survival_bot_waypoint(route, _scale_survival_route_point(Vector2(345.0, 470.0)))
				_add_survival_bot_waypoint(route, _scale_survival_route_point(Vector2(540.0, 470.0)))
				_add_survival_bot_waypoint(route, _scale_survival_route_point(Vector2(700.0, 490.0)))
			"violet":
				_add_survival_bot_waypoint(route, _scale_survival_route_point(Vector2(345.0, 470.0)))
				_add_survival_bot_waypoint(route, _scale_survival_route_point(Vector2(660.0, 470.0)))
				_add_survival_bot_waypoint(route, _scale_survival_route_point(Vector2(1020.0, 480.0)))
				_add_survival_bot_waypoint(route, _scale_survival_route_point(Vector2(1220.0, 470.0)))
				_add_survival_bot_waypoint(route, _scale_survival_route_point(Vector2(1360.0, 400.0)))
			"orange":
				_add_survival_bot_waypoint(route, _scale_survival_route_point(Vector2(345.0, 710.0)))
				_add_survival_bot_waypoint(route, _scale_survival_route_point(Vector2(650.0, 720.0)))
				_add_survival_bot_waypoint(route, _scale_survival_route_point(Vector2(940.0, 740.0)))
			_:
				_add_survival_bot_waypoint(route, _scale_survival_route_point(Vector2(840.0, 500.0)))
		return
	if _survival_map_index == 2:
		match lock_id:
			"blue":
				_add_survival_bot_waypoint(route, _scale_survival_route_point(Vector2(340.0, 470.0)))
				_add_survival_bot_waypoint(route, _scale_survival_route_point(Vector2(470.0, 470.0)))
				_add_survival_bot_waypoint(route, _scale_survival_route_point(Vector2(590.0, 350.0)))
			"red":
				_add_survival_bot_waypoint(route, _scale_survival_route_point(Vector2(340.0, 635.0)))
				_add_survival_bot_waypoint(route, _scale_survival_route_point(Vector2(650.0, 660.0)))
				_add_survival_bot_waypoint(route, _scale_survival_route_point(Vector2(970.0, 650.0)))
				_add_survival_bot_waypoint(route, _scale_survival_route_point(Vector2(1230.0, 650.0)))
			"yellow":
				_add_survival_bot_waypoint(route, _scale_survival_route_point(Vector2(340.0, 470.0)))
				_add_survival_bot_waypoint(route, _scale_survival_route_point(Vector2(545.0, 470.0)))
				_add_survival_bot_waypoint(route, _scale_survival_route_point(Vector2(690.0, 470.0)))
			"violet":
				_add_survival_bot_waypoint(route, _scale_survival_route_point(Vector2(340.0, 470.0)))
				_add_survival_bot_waypoint(route, _scale_survival_route_point(Vector2(650.0, 470.0)))
				_add_survival_bot_waypoint(route, _scale_survival_route_point(Vector2(1035.0, 460.0)))
				_add_survival_bot_waypoint(route, _scale_survival_route_point(Vector2(1245.0, 420.0)))
			_:
				_add_survival_bot_waypoint(route, _scale_survival_route_point(Vector2(820.0, 470.0)))
		return
	if _survival_map_index == 1:
		match lock_id:
			"blue":
				_add_survival_bot_waypoint(route, _scale_survival_route_point(Vector2(285.0, 260.0)))
				_add_survival_bot_waypoint(route, _scale_survival_route_point(Vector2(430.0, 260.0)))
			"red":
				_add_survival_bot_waypoint(route, _scale_survival_route_point(Vector2(285.0, 620.0)))
				_add_survival_bot_waypoint(route, _scale_survival_route_point(Vector2(930.0, 655.0)))
				_add_survival_bot_waypoint(route, _scale_survival_route_point(Vector2(1245.0, 760.0)))
			"yellow":
				_add_survival_bot_waypoint(route, _scale_survival_route_point(Vector2(285.0, 620.0)))
				_add_survival_bot_waypoint(route, _scale_survival_route_point(Vector2(520.0, 520.0)))
				_add_survival_bot_waypoint(route, _scale_survival_route_point(Vector2(735.0, 500.0)))
			_:
				_add_survival_bot_waypoint(route, _scale_survival_route_point(Vector2(720.0, 450.0)))
		return
	match lock_id:
		"yellow":
			_add_survival_bot_waypoint(route, _scale_survival_route_point(Vector2(210.0, 430.0)))
		"red":
			_add_survival_bot_waypoint(route, _scale_survival_route_point(Vector2(455.0, 430.0)))
			_add_survival_bot_waypoint(route, _scale_survival_route_point(Vector2(900.0, 430.0)))
			_add_survival_bot_waypoint(route, _scale_survival_route_point(Vector2(1110.0, 420.0)))
			_add_survival_bot_waypoint(route, _scale_survival_route_point(Vector2(1110.0, 210.0)))
		"blue":
			_add_survival_bot_waypoint(route, _scale_survival_route_point(Vector2(900.0, 760.0)))
			_add_survival_bot_waypoint(route, _scale_survival_route_point(Vector2(1265.0, 760.0)))
		_:
			_add_survival_bot_waypoint(route, _scale_survival_route_point(Vector2(760.0, 430.0)))


func _add_survival_bot_approach_to_gate(route: Array[Dictionary], lock_id: String) -> void:
	if _survival_map_index == 4:
		match lock_id:
			"blue":
				_add_survival_bot_waypoint(route, _scale_survival_route_point(Vector2(928.0, 256.0)))
				_add_survival_bot_waypoint(route, _scale_survival_route_point(Vector2(992.0, 352.0)))
				_add_survival_bot_waypoint(route, _scale_survival_route_point(Vector2(1064.0, 360.0)))
				_add_survival_bot_waypoint(route, _scale_survival_route_point(Vector2(1064.0, 448.0)))
				_add_survival_bot_waypoint(route, _scale_survival_route_point(Vector2(1136.0, 456.0)))
				_add_survival_bot_waypoint(route, _scale_survival_route_point(Vector2(1200.0, 520.0)))
			"red":
				_add_survival_bot_waypoint(route, _scale_survival_route_point(Vector2(1400.0, 920.0)))
				_add_survival_bot_waypoint(route, _scale_survival_route_point(Vector2(488.0, 920.0)))
				_add_survival_bot_waypoint(route, _scale_survival_route_point(Vector2(464.0, 848.0)))
				_add_survival_bot_waypoint(route, _scale_survival_route_point(Vector2(432.0, 776.0)))
			"yellow":
				_add_survival_bot_waypoint(route, _scale_survival_route_point(Vector2(880.0, 520.0)))
				_add_survival_bot_waypoint(route, _scale_survival_route_point(Vector2(1072.0, 560.0)))
				_add_survival_bot_waypoint(route, _scale_survival_route_point(Vector2(1160.0, 512.0)))
				_add_survival_bot_waypoint(route, _scale_survival_route_point(Vector2(1344.0, 520.0)))
				_add_survival_bot_waypoint(route, _scale_survival_route_point(Vector2(1416.0, 496.0)))
				_add_survival_bot_waypoint(route, _scale_survival_route_point(Vector2(1448.0, 656.0)))
			"violet":
				_add_survival_bot_waypoint(route, _scale_survival_route_point(Vector2(1448.0, 488.0)))
				_add_survival_bot_waypoint(route, _scale_survival_route_point(Vector2(1272.0, 496.0)))
				_add_survival_bot_waypoint(route, _scale_survival_route_point(Vector2(1200.0, 520.0)))
				_add_survival_bot_waypoint(route, _scale_survival_route_point(Vector2(1136.0, 456.0)))
				_add_survival_bot_waypoint(route, _scale_survival_route_point(Vector2(1064.0, 448.0)))
				_add_survival_bot_waypoint(route, _scale_survival_route_point(Vector2(1064.0, 360.0)))
				_add_survival_bot_waypoint(route, _scale_survival_route_point(Vector2(968.0, 328.0)))
				_add_survival_bot_waypoint(route, _scale_survival_route_point(Vector2(928.0, 256.0)))
				_add_survival_bot_waypoint(route, _scale_survival_route_point(Vector2(840.0, 256.0)))
			"orange":
				_add_survival_bot_waypoint(route, _scale_survival_route_point(Vector2(1192.0, 768.0)))
				_add_survival_bot_waypoint(route, _scale_survival_route_point(Vector2(1240.0, 576.0)))
				_add_survival_bot_waypoint(route, _scale_survival_route_point(Vector2(1320.0, 544.0)))
				_add_survival_bot_waypoint(route, _scale_survival_route_point(Vector2(1552.0, 496.0)))
				_add_survival_bot_waypoint(route, _scale_survival_route_point(Vector2(1624.0, 528.0)))
			_:
				_add_survival_bot_waypoint(route, _scale_survival_route_point(Vector2(900.0, 520.0)))
		return
	if _survival_map_index == 3:
		match lock_id:
			"blue":
				_add_survival_bot_waypoint(route, _scale_survival_route_point(Vector2(800.0, 350.0)))
				_add_survival_bot_waypoint(route, _scale_survival_route_point(Vector2(1050.0, 440.0)))
				_add_survival_bot_waypoint(route, _scale_survival_route_point(Vector2(1160.0, 450.0)))
			"red":
				_add_survival_bot_waypoint(route, _scale_survival_route_point(Vector2(1180.0, 740.0)))
				_add_survival_bot_waypoint(route, _scale_survival_route_point(Vector2(800.0, 720.0)))
				_add_survival_bot_waypoint(route, _scale_survival_route_point(Vector2(500.0, 700.0)))
			"yellow":
				_add_survival_bot_waypoint(route, _scale_survival_route_point(Vector2(900.0, 530.0)))
				_add_survival_bot_waypoint(route, _scale_survival_route_point(Vector2(1160.0, 610.0)))
				_add_survival_bot_waypoint(route, _scale_survival_route_point(Vector2(1300.0, 640.0)))
			"violet":
				_add_survival_bot_waypoint(route, _scale_survival_route_point(Vector2(1300.0, 450.0)))
				_add_survival_bot_waypoint(route, _scale_survival_route_point(Vector2(1060.0, 360.0)))
				_add_survival_bot_waypoint(route, _scale_survival_route_point(Vector2(840.0, 250.0)))
			"orange":
				_add_survival_bot_waypoint(route, _scale_survival_route_point(Vector2(1180.0, 740.0)))
				_add_survival_bot_waypoint(route, _scale_survival_route_point(Vector2(1380.0, 640.0)))
				_add_survival_bot_waypoint(route, _scale_survival_route_point(Vector2(1530.0, 540.0)))
			_:
				_add_survival_bot_waypoint(route, _scale_survival_route_point(Vector2(840.0, 500.0)))
		return
	if _survival_map_index == 2:
		match lock_id:
			"blue":
				_add_survival_bot_waypoint(route, _scale_survival_route_point(Vector2(760.0, 470.0)))
				_add_survival_bot_waypoint(route, _scale_survival_route_point(Vector2(950.0, 435.0)))
			"red":
				_add_survival_bot_waypoint(route, _scale_survival_route_point(Vector2(1230.0, 650.0)))
				_add_survival_bot_waypoint(route, _scale_survival_route_point(Vector2(960.0, 650.0)))
				_add_survival_bot_waypoint(route, _scale_survival_route_point(Vector2(650.0, 660.0)))
				_add_survival_bot_waypoint(route, _scale_survival_route_point(Vector2(455.0, 650.0)))
			"yellow":
				_add_survival_bot_waypoint(route, _scale_survival_route_point(Vector2(720.0, 430.0)))
				_add_survival_bot_waypoint(route, _scale_survival_route_point(Vector2(980.0, 330.0)))
				_add_survival_bot_waypoint(route, _scale_survival_route_point(Vector2(1120.0, 430.0)))
				_add_survival_bot_waypoint(route, _scale_survival_route_point(Vector2(1260.0, 430.0)))
				_add_survival_bot_waypoint(route, _scale_survival_route_point(Vector2(1260.0, 580.0)))
			"violet":
				_add_survival_bot_waypoint(route, _scale_survival_route_point(Vector2(1245.0, 420.0)))
				_add_survival_bot_waypoint(route, _scale_survival_route_point(Vector2(1035.0, 460.0)))
				_add_survival_bot_waypoint(route, _scale_survival_route_point(Vector2(840.0, 360.0)))
				_add_survival_bot_waypoint(route, _scale_survival_route_point(Vector2(720.0, 250.0)))
			_:
				_add_survival_bot_waypoint(route, _scale_survival_route_point(Vector2(820.0, 470.0)))
		return
	if _survival_map_index == 1:
		match lock_id:
			"blue":
				_add_survival_bot_waypoint(route, _scale_survival_route_point(Vector2(930.0, 455.0)))
			"red":
				_add_survival_bot_waypoint(route, _scale_survival_route_point(Vector2(930.0, 655.0)))
				_add_survival_bot_waypoint(route, _scale_survival_route_point(Vector2(380.0, 645.0)))
			"yellow":
				_add_survival_bot_waypoint(route, _scale_survival_route_point(Vector2(950.0, 520.0)))
				_add_survival_bot_waypoint(route, _scale_survival_route_point(Vector2(1218.0, 627.0)))
			_:
				_add_survival_bot_waypoint(route, _scale_survival_route_point(Vector2(720.0, 450.0)))
		return
	match lock_id:
		"blue":
			_add_survival_bot_waypoint(route, _scale_survival_route_point(Vector2(900.0, 430.0)))
			_add_survival_bot_waypoint(route, _scale_survival_route_point(Vector2(425.0, 430.0)))
		"red":
			_add_survival_bot_waypoint(route, _scale_survival_route_point(Vector2(900.0, 760.0)))
		"yellow":
			_add_survival_bot_waypoint(route, _scale_survival_route_point(Vector2(900.0, 430.0)))
			_add_survival_bot_waypoint(route, _scale_survival_route_point(Vector2(1265.0, 430.0)))
		_:
			_add_survival_bot_waypoint(route, _scale_survival_route_point(Vector2(760.0, 430.0)))


func _add_survival_bot_approach_to_button(route: Array[Dictionary], lock_id: String) -> void:
	if _survival_map_index == 4:
		match lock_id:
			"blue":
				_add_survival_bot_waypoint(route, _scale_survival_route_point(Vector2(1440.0, 496.0)))
				_add_survival_bot_waypoint(route, _scale_survival_route_point(Vector2(1464.0, 408.0)))
			"yellow":
				_add_survival_bot_waypoint(route, _scale_survival_route_point(Vector2(1536.0, 672.0)))
			"violet":
				_add_survival_bot_waypoint(route, _scale_survival_route_point(Vector2(808.0, 240.0)))
			"orange":
				_add_survival_bot_waypoint(route, _scale_survival_route_point(Vector2(1760.0, 552.0)))
		return
	if _survival_map_index == 3:
		match lock_id:
			"blue":
				_add_survival_bot_waypoint(route, _scale_survival_route_point(Vector2(1300.0, 430.0)))
				_add_survival_bot_waypoint(route, _scale_survival_route_point(Vector2(1400.0, 350.0)))
			"yellow":
				_add_survival_bot_waypoint(route, _scale_survival_route_point(Vector2(1400.0, 640.0)))
			"violet":
				_add_survival_bot_waypoint(route, _scale_survival_route_point(Vector2(830.0, 230.0)))
			"orange":
				_add_survival_bot_waypoint(route, _scale_survival_route_point(Vector2(1625.0, 530.0)))
		return
	if _survival_map_index != 2:
		return
	match lock_id:
		"blue":
			_add_survival_bot_waypoint(route, _scale_survival_route_point(Vector2(1210.0, 420.0)))
			_add_survival_bot_waypoint(route, _scale_survival_route_point(Vector2(1325.0, 355.0)))
		"yellow":
			_add_survival_bot_waypoint(route, _scale_survival_route_point(Vector2(1300.0, 630.0)))
		"violet":
			_add_survival_bot_waypoint(route, _scale_survival_route_point(Vector2(800.0, 220.0)))


func _scale_survival_route_point(point: Vector2) -> Vector2:
	var scale: float = _survival_map_data.get("survival_team_scale", 1.0) as float
	return point * scale


func _add_survival_bot_waypoint(route: Array[Dictionary], position: Vector2, hold_time: float = 0.0,
		arrival_radius: float = 24.0) -> void:
	route.append({
		"position": position,
		"hold_time": hold_time,
		"arrival_radius": arrival_radius,
	})


func _configure_official_trapper_bot(trapper: Trapper) -> void:
	if arena == null:
		return
	var map_size := arena.get_map_size()
	var path_a := arena.get_map_center()
	var path_b := path_a + Vector2(220.0, 0.0)
	match trapper.trapper_character:
		Enums.TrapperCharacter.ARANA:
			path_a = Vector2(map_size.x * 0.18, map_size.y * 0.27)
			path_b = Vector2(map_size.x * 0.38, map_size.y * 0.31)
			trapper.configure_spider_bot(path_a, path_b)
		Enums.TrapperCharacter.HONGO:
			path_a = Vector2(map_size.x * 0.43, map_size.y * 0.42)
			path_b = Vector2(map_size.x * 0.67, map_size.y * 0.58)
			trapper.configure_mushroom_bot(path_a, path_b)
		Enums.TrapperCharacter.ESCORPION:
			path_a = Vector2(map_size.x * 0.18, map_size.y * 0.76)
			path_b = Vector2(map_size.x * 0.50, map_size.y * 0.58)
			trapper.configure_scorpion_bot(path_a, path_b)
		Enums.TrapperCharacter.PULPO:
			path_a = Vector2(map_size.x * 0.73, map_size.y * 0.48)
			path_b = Vector2(map_size.x * 0.93, map_size.y * 0.58)
			trapper.configure_octopus_bot(path_a, path_b)
		_:
			trapper.configure_octopus_bot(path_a, path_b)


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
			phase_overlay.show_escape()
			_freeze_all()
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
		Enums.GameState.SURVIVAL:
			menu_music.use_round_volume()
			_spawn_survival_characters()
			_unfreeze_all()
			phase_overlay.clear()


func _on_escape_overlay_finished() -> void:
	if GameManager.current_state != Enums.GameState.ESCAPE:
		return
	_round_replay_escape_start_time = _round_replay_elapsed
	if GameManager.is_strategic_hunt_enabled():
		_unfreeze_escapists_only()
	else:
		_unfreeze_all()
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


func _update_survival_result_flow(delta: float) -> void:
	if _survival_final_series_complete:
		return
	if _survival_result_auto_advance_timer <= 0.0:
		return
	_survival_result_auto_advance_timer = maxf(_survival_result_auto_advance_timer - delta, 0.0)
	if _survival_result_auto_advance_timer <= 0.0:
		_advance_after_survival_result()


func _check_survival_result_input() -> void:
	for pi in _active_player_indices:
		var device_id := InputManager.get_device_id(pi)
		if device_id < 0:
			continue
		var start_pressed := InputManager.is_button_just_pressed_on_device(device_id, JOY_BUTTON_START)
		var back_pressed := InputManager.is_button_just_pressed_on_device(device_id, JOY_BUTTON_BACK)
		if start_pressed or back_pressed:
			_advance_after_survival_result()
			return


func _advance_after_survival_result() -> void:
	if _survival_final_series_complete:
		_start_survival_escape_setup()
		_prime_start_button_state()
		InputManager.suppress_edge_detection(3)
		return
	if _survival_series_records.size() <= 0:
		return
	_start_survival_return_leg()


func _start_survival_return_leg() -> void:
	if _survival_series_initial_roles.is_empty():
		_start_survival_escape_setup()
		return
	get_tree().paused = false
	_clear_pause_menu()
	_cleanup_round()
	if arena:
		arena.queue_free()
		arena = null
	phase_overlay.clear()
	game_hud.hide()
	_hide_survival_hud()
	_survival_series_leg_index = 1
	var swapped_roles := _build_swapped_survival_roles(_survival_series_initial_roles)
	_apply_survival_role_assignments(swapped_roles)
	_begin_survival_leg()
	_start_survival_escape_session()
	_prime_start_button_state()
	InputManager.suppress_edge_detection(3)


func _build_swapped_survival_roles(source_roles: Dictionary) -> Dictionary:
	var swapped: Dictionary = {}
	for pi: int in source_roles:
		var role: Enums.Role = source_roles[pi] as Enums.Role
		swapped[pi] = Enums.Role.TRAPPER if role == Enums.Role.ESCAPIST else Enums.Role.ESCAPIST
	return swapped


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

	if state == Enums.GameState.SURVIVAL:
		if _survival_transition_timer > 0.0:
			_update_survival_map_transition(delta)
			return
		if _survival_match_finished:
			_update_survival_result_flow(delta)
			_check_survival_result_input()
			return
		_update_survival_escape(delta)
		_update_survival_waves(delta)
		_check_pause_input()
		return

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

func _check_survival_return_input() -> void:
	for pi in _active_player_indices:
		var device_id := InputManager.get_device_id(pi)
		if device_id < 0:
			continue
		if InputManager.is_menu_back_just_pressed(device_id):
			_return_to_survival_placeholder()
			return


func _return_to_survival_placeholder() -> void:
	get_tree().paused = false
	_clear_pause_menu()
	_cleanup_round()
	if arena:
		arena.queue_free()
		arena = null
	phase_overlay.clear()
	game_hud.hide()
	_hide_survival_hud()
	menu_music.use_menu_volume()
	menu_music.start_music()
	GameManager.reset_match()
	_survival_goal_escapists.clear()
	_survival_match_finished = false
	_survival_time_remaining = 0.0
	_reset_survival_waves()
	_reset_survival_series_state()

	while not _view_stack.is_empty():
		pop_view()

	survival_escape_setup.reopen_placeholder()
	push_view(survival_escape_setup)
	InputManager.suppress_edge_detection(3)

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


func _unfreeze_escapists_only() -> void:
	for c in characters:
		if is_instance_valid(c):
			if c is BaseCharacter:
				(c as BaseCharacter).unfreeze_character()
			elif c is Trapper:
				(c as Trapper).freeze_character()


# --- Pause ---

func _check_pause_input() -> void:
	for pi in _active_player_indices:
		var device_id := InputManager.get_device_id(pi)
		if device_id < 0:
			_prev_start_pressed[pi] = false
			continue
		var pressed := InputManager.is_button_pressed_on_device(device_id, JOY_BUTTON_START)
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
		var pressed := InputManager.is_button_pressed_on_device(device_id, JOY_BUTTON_START)
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
		var pressed := InputManager.is_button_pressed_on_device(device_id, JOY_BUTTON_START)
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
	if GameManager.is_survival_context():
		_restart_survival_escape_session()
		return
	if GameManager.practice_mode:
		return
	get_tree().paused = false
	_clear_pause_menu()
	phase_overlay.clear()
	GameManager.restart_current_round()
	_prime_start_button_state()
	InputManager.suppress_edge_detection(3)


func _go_to_next_survival_map_from_pause() -> void:
	if not GameManager.is_survival_context():
		return
	get_tree().paused = false
	_clear_pause_menu()
	var next_map_index := mini(_survival_map_index + 1, MapData.get_survival_map_count() - 1)
	_start_survival_escape_session(next_map_index, _get_survival_jailed_player_set())
	_prime_start_button_state()
	InputManager.suppress_edge_detection(3)


func _go_to_survival_map_from_pause(map_index: int) -> void:
	if not GameManager.is_survival_context():
		return
	get_tree().paused = false
	_clear_pause_menu()
	_start_survival_escape_session(clampi(map_index, 0, MapData.get_survival_map_count() - 1))
	_prime_start_button_state()
	InputManager.suppress_edge_detection(3)


func _restart_survival_escape_session() -> void:
	get_tree().paused = false
	_clear_pause_menu()
	_cleanup_round()
	if arena:
		arena.queue_free()
		arena = null
	phase_overlay.clear()
	game_hud.hide()
	_hide_survival_hud()
	_begin_survival_leg()
	_start_survival_escape_session()


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
	if GameManager.is_survival_context() or _is_survival_flow:
		_start_survival_escape_setup()
		_prime_start_button_state()
		InputManager.suppress_edge_detection(3)
		return
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
		_prev_start_pressed[pi] = device_id >= 0 and InputManager.is_button_pressed_on_device(device_id, JOY_BUTTON_START)


# --- Settings ---

func _open_settings() -> void:
	ui_layer.move_child(settings_menu, ui_layer.get_child_count() - 1)
	if get_tree().paused or GameManager.current_state == Enums.GameState.PAUSED:
		_hide_pause_menu_behind_subscreen()
	settings_menu.set_survival_context(_is_survival_flow or GameManager.is_survival_context())
	push_view(settings_menu)
	settings_menu.open()


func _close_settings() -> void:
	pop_view()
	if pause_menu and (get_tree().paused or GameManager.current_state == Enums.GameState.PAUSED):
		_restore_pause_menu_after_subscreen()


func _on_setting_changed(key: String, value: Variant) -> void:
	match key:
		"bot_fill":
			GameManager.settings_overrides[&"bot_fill"] = value
			team_setup.auto_fill_bots = (int(value) == 0)  # 0 = "On"
			if survival_escape_setup:
				survival_escape_setup.auto_fill_bots = (int(value) == 0)
				survival_escape_setup.queue_redraw()
		"bot_ai":
			GameManager.settings_overrides[&"bot_ai"] = (int(value) == 1)  # 1 = "On"
		"survival_static_bots":
			GameManager.settings_overrides[&"survival_static_bots"] = (int(value) == 0)  # 0 = "On"
			_apply_survival_bot_static_setting()
		"hunt_duration":
			GameManager.settings_overrides[&"hunt_duration"] = value
		"survival_escape_duration":
			GameManager.settings_overrides[&"survival_escape_duration"] = value
			if GameManager.is_survival_context():
				_survival_time_total = float(value)
				_survival_time_remaining = minf(_survival_time_remaining, _survival_time_total)
		"observation_duration":
			GameManager.settings_overrides[&"observation_duration"] = value
		"hunt_countdown_duration":
			GameManager.settings_overrides[&"hunt_countdown_duration"] = value
		"score_to_win":
			GameManager.settings_overrides[&"score_to_win"] = value
		"team_size":
			GameManager.settings_overrides[&"team_size"] = value
			if survival_escape_setup:
				survival_escape_setup.queue_redraw()
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
