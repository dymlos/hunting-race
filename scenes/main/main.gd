extends Node2D

## Main scene — orchestrates arena, characters, UI, and game state.

const TeamSetupScene := preload("res://scenes/ui/team_setup.tscn")
const StageSelectScene := preload("res://scenes/ui/stage_select.tscn")
const ArenaScene := preload("res://scenes/arena/arena.tscn")
const PhaseOverlayScene := preload("res://scenes/ui/phase_overlay.tscn")
const GameHudScene := preload("res://scenes/ui/game_hud.tscn")
const EscapistScene := preload("res://scenes/characters/escapist/escapist.tscn")
const TrapperScene := preload("res://scenes/characters/trapper/trapper.tscn")

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
var team_setup: TeamSetup
var stage_select: StageSelect
var phase_overlay: PhaseOverlay
var game_hud: GameHud


func _ready() -> void:
	team_setup = TeamSetupScene.instantiate() as TeamSetup
	ui_layer.add_child(team_setup)
	team_setup.hide()
	team_setup.teams_ready.connect(_on_teams_ready)

	stage_select = StageSelectScene.instantiate() as StageSelect
	ui_layer.add_child(stage_select)
	stage_select.hide()
	stage_select.stage_selected.connect(_on_stage_selected)
	stage_select.back_requested.connect(_on_stage_back)

	phase_overlay = PhaseOverlayScene.instantiate() as PhaseOverlay
	ui_layer.add_child(phase_overlay)
	phase_overlay.hide()

	game_hud = GameHudScene.instantiate() as GameHud
	ui_layer.add_child(game_hud)
	game_hud.hide()

	GameManager.state_changed.connect(_on_state_changed)
	GameManager.round_ended.connect(_on_round_ended)
	GameManager.match_ended.connect(_on_match_ended)
	GameManager.escapist_scored.connect(_on_escapist_scored)
	GameManager.escapist_died.connect(_on_escapist_died)

	_start_team_setup()


func _start_team_setup() -> void:
	_cleanup_round()
	_active_player_indices.clear()
	if arena:
		arena.queue_free()
		arena = null
	phase_overlay.clear()
	game_hud.hide()

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

	while not _view_stack.is_empty():
		pop_view()

	for pi in _active_player_indices:
		_prev_start_pressed[pi] = true

	_setup_arena()
	game_hud.show()
	GameManager.start_observation()


func _on_stage_back() -> void:
	_start_team_setup()


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


func _on_goal_entered(scoring_team: Enums.Team) -> void:
	# Find the escapist that just scored and mark them
	# (arena signal doesn't tell us which one, but we handle it in the escapist)
	GameManager.register_escapist_scored(scoring_team)


func _cleanup_round() -> void:
	for c in characters:
		if is_instance_valid(c):
			c.queue_free()
	characters.clear()
	for node in get_tree().get_nodes_in_group("traps"):
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
			esc.player_color = Enums.team_color(t)
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
			trapper.position = arena.get_map_center()
			trapper.setup(arena.get_map_size())
			character_container.add_child(trapper)
			characters.append(trapper)
			GameManager.register_player_character(pi, trapper)


func _on_escapist_character_died(_escapist: Escapist) -> void:
	GameManager.register_escapist_died(_escapist.team)


func _on_state_changed(new_state: Enums.GameState) -> void:
	if GameManager.is_unpausing:
		GameManager.is_unpausing = false
		return

	match new_state:
		Enums.GameState.OBSERVATION:
			_spawn_characters()
			_freeze_all()
		Enums.GameState.HUNT:
			phase_overlay.show_hunt()
			_unfreeze_all()
		Enums.GameState.ROUND_END:
			_freeze_all()
		Enums.GameState.MATCH_END:
			_freeze_all()


func _on_round_ended(escapist_team: Enums.Team, points_scored: int) -> void:
	phase_overlay.show_round_end(escapist_team, GameManager.match_scores)


func _on_match_ended(winning_team: Enums.Team) -> void:
	phase_overlay.show_match_end(winning_team, GameManager.match_scores)


func _on_escapist_scored(_team: Enums.Team) -> void:
	pass  # HUD updates automatically via _draw


func _on_escapist_died(_team: Enums.Team) -> void:
	pass  # HUD updates automatically via _draw


func _process(_delta: float) -> void:
	var state := GameManager.current_state

	if state == Enums.GameState.OBSERVATION:
		phase_overlay.show_observation(GameManager.get_observation_time())

	if state == Enums.GameState.HUNT:
		_check_pause_input()
		_check_debug_input()

	if state == Enums.GameState.MATCH_END:
		_check_restart_input()


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
			GameManager.pause_game()
			get_tree().paused = true
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
			GameManager.reset_match()
			_start_team_setup()
			return


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
