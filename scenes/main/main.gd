extends Node2D

## Main scene — orchestrates arena, characters, UI, and game state.

const TeamSetupScene := preload("res://scenes/ui/team_setup.tscn")
const CoverScreenScene := preload("res://scenes/ui/cover_screen.tscn")
const StageSelectScene := preload("res://scenes/ui/stage_select.tscn")
const EscapistSelectScene := preload("res://scenes/ui/escapist_select.tscn")
const CharacterSelectScene := preload("res://scenes/ui/character_select.tscn")
const SettingsMenuScene := preload("res://scenes/ui/settings_menu.tscn")
const PauseMenuScene := preload("res://scenes/ui/pause_menu.gd")
const ArenaScene := preload("res://scenes/arena/arena.tscn")
const PhaseOverlayScene := preload("res://scenes/ui/phase_overlay.tscn")
const GameHudScene := preload("res://scenes/ui/game_hud.tscn")
const EscapistScene := preload("res://scenes/characters/escapist/escapist.tscn")
const TrapperScene := preload("res://scenes/characters/trapper/trapper.tscn")
const MenuMusicPlayerScene := preload("res://scenes/audio/menu_music_player.gd")

var arena: Arena
var characters: Array[Node2D] = []  # Mix of Escapist and Trapper nodes
var _active_player_indices: Array[int] = []
var _prev_start_pressed: Dictionary = {}  # {device_id: bool}
var _selected_stage_index: int = 0

@onready var arena_container := $ArenaContainer as Node2D
@onready var character_container := $Characters as Node2D
@onready var camera := $Camera2D as Camera2D
@onready var ui_layer := $UILayer as CanvasLayer

# View stack
var _view_stack: Array[Control] = []

# UI instances
var cover_screen: CoverScreen
var team_setup: TeamSetup
var stage_select: StageSelect
var escapist_select: EscapistSelect
var character_select: CharacterSelect
var settings_menu: SettingsMenu
var pause_menu: PauseMenu
var phase_overlay: PhaseOverlay
var game_hud: GameHud
var menu_music: MenuMusicPlayer
var _is_first_round: bool = true  # Tracks if this is the initial pre-game select


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

	team_setup = TeamSetupScene.instantiate() as TeamSetup
	ui_layer.add_child(team_setup)
	team_setup.hide()
	team_setup.teams_ready.connect(_on_teams_ready)
	team_setup.settings_requested.connect(_open_settings)

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
	pause_menu.reset_requested.connect(_reset_to_team_setup)

	phase_overlay = PhaseOverlayScene.instantiate() as PhaseOverlay
	ui_layer.add_child(phase_overlay)
	phase_overlay.hide()

	game_hud = GameHudScene.instantiate() as GameHud
	ui_layer.add_child(game_hud)
	game_hud.hide()

	menu_music = MenuMusicPlayerScene.new() as MenuMusicPlayer
	add_child(menu_music)

	GameManager.state_changed.connect(_on_state_changed)
	GameManager.round_ended.connect(_on_round_ended)
	GameManager.match_ended.connect(_on_match_ended)
	GameManager.escapist_scored.connect(_on_escapist_scored)
	GameManager.escapist_died.connect(_on_escapist_died)
	GameManager.round_advancing.connect(_on_round_advancing)

	_start_cover_screen()


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
	menu_music.start_music()

	while not _view_stack.is_empty():
		pop_view()

	cover_screen.open()
	push_view(cover_screen)


func _on_cover_start_requested() -> void:
	_start_team_setup()


func _start_team_setup() -> void:
	get_tree().paused = false
	_clear_pause_menu()
	_cleanup_round()
	_active_player_indices.clear()
	if arena:
		arena.queue_free()
		arena = null
	phase_overlay.clear()
	game_hud.hide()
	menu_music.start_music()

	while not _view_stack.is_empty():
		pop_view()

	team_setup.setup()
	push_view(team_setup)


func _on_teams_ready(t_assignments: Dictionary) -> void:
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
	_show_character_select(_is_first_round)


func _on_characters_ready(selections: Dictionary) -> void:
	GameManager.set_character_selections(selections)

	while not _view_stack.is_empty():
		pop_view()

	for pi in _active_player_indices:
		_prev_start_pressed[pi] = true

	if _is_first_round:
		_setup_arena()
	_is_first_round = false
	game_hud.show()
	GameManager.start_observation()


func _on_character_back() -> void:
	_show_escapist_select(true)


func _on_escapist_back() -> void:
	replace_view(stage_select)
	stage_select.setup()


func _on_round_advancing() -> void:
	# Between rounds: pick escapists first, then trappers.
	phase_overlay.clear()
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


func _setup_camera() -> void:
	if not arena:
		return
	var map_size := arena.get_map_size()
	camera.position = map_size / 2.0
	var viewport_size := get_viewport_rect().size
	var zoom_x := viewport_size.x / (map_size.x + 100.0)
	var zoom_y := viewport_size.y / (map_size.y + 100.0)
	var target_zoom := minf(zoom_x, zoom_y)
	camera.zoom = Vector2(target_zoom, target_zoom)


func _on_goal_entered(escapist: Escapist) -> void:
	GameManager.register_escapist_scored(escapist.player_index)


func _cleanup_round() -> void:
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
			if arena:
				arena.randomize_hazards_for_round(GameManager.get_competitive_round_number())
			_spawn_characters()
			_freeze_all()
			phase_overlay.show_round_intro(
				GameManager.get_competitive_round_number(),
				GameManager.get_round_leg_label()
			)
		Enums.GameState.HUNT:
			_freeze_escapists_only()
		Enums.GameState.ESCAPE:
			phase_overlay.show_escape()
			_unfreeze_all()
		Enums.GameState.ROUND_END:
			_freeze_all()
		Enums.GameState.MATCH_END:
			_freeze_all()


func _on_round_ended(escapist_team: Enums.Team, points_scored: int) -> void:
	phase_overlay.show_round_end(escapist_team, GameManager.match_scores, GameManager.get_round_score_entries())
	_prime_start_button_state()
	InputManager.suppress_edge_detection(3)


func _on_match_ended(winning_team: Enums.Team) -> void:
	phase_overlay.show_match_end(winning_team, GameManager.match_scores, GameManager.get_match_score_entries())


func _on_escapist_scored(_team: Enums.Team) -> void:
	pass  # HUD updates automatically via _draw


func _on_escapist_died(_team: Enums.Team) -> void:
	pass  # HUD updates automatically via _draw


func _process(_delta: float) -> void:
	var state := GameManager.current_state

	if state == Enums.GameState.PAUSED:
		_check_pause_input()
		return

	if state == Enums.GameState.HUNT:
		phase_overlay.show_hunt_countdown(GameManager.get_observation_time())

	if state == Enums.GameState.OBSERVATION or state == Enums.GameState.HUNT or state == Enums.GameState.ESCAPE:
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
			_prev_start_pressed[pi] = false
			continue
		var start_pressed := Input.is_joy_button_pressed(device_id, JOY_BUTTON_START)
		var was_start_pressed: bool = _prev_start_pressed.get(pi, false)
		_prev_start_pressed[pi] = start_pressed
		if start_pressed and not was_start_pressed:
			GameManager.confirm_round_end()
			_prime_start_button_state()
			InputManager.suppress_edge_detection(3)
			return
		if InputManager.is_button_just_pressed_on_device(device_id, JOY_BUTTON_A):
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


func _prime_start_button_state() -> void:
	for pi in _active_player_indices:
		var device_id := InputManager.get_device_id(pi)
		_prev_start_pressed[pi] = device_id >= 0 and Input.is_joy_button_pressed(device_id, JOY_BUTTON_START)


# --- Settings ---

func _open_settings() -> void:
	ui_layer.move_child(settings_menu, ui_layer.get_child_count() - 1)
	push_view(settings_menu)
	settings_menu.open()


func _close_settings() -> void:
	pop_view()


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
