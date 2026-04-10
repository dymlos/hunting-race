extends Node2D

## Main scene — orchestrates arena, characters, UI, and game state.

const TeamSetupScene := preload("res://scenes/ui/team_setup.tscn")
const ArenaScene := preload("res://scenes/arena/arena.tscn")
const PhaseOverlayScene := preload("res://scenes/ui/phase_overlay.tscn")
const GameHudScene := preload("res://scenes/ui/game_hud.tscn")
const EscapistScene := preload("res://scenes/characters/escapist/escapist.tscn")
const PredatorScene := preload("res://scenes/characters/predator/predator.tscn")
const TrapperScene := preload("res://scenes/characters/trapper/trapper.tscn")

var arena: Arena
var characters: Array[Node2D] = []
var _active_player_indices: Array[int] = []
var _prev_start_pressed: Dictionary = {}  # {device_id: bool}

@onready var arena_container := $ArenaContainer as Node2D
@onready var character_container := $Characters as Node2D
@onready var camera := $Camera2D as Camera2D
@onready var ui_layer := $UILayer as CanvasLayer

# View stack
var _view_stack: Array[Control] = []

# UI instances
var team_setup: TeamSetup
var phase_overlay: PhaseOverlay
var game_hud: GameHud


func _ready() -> void:
	# Create UI
	team_setup = TeamSetupScene.instantiate() as TeamSetup
	ui_layer.add_child(team_setup)
	team_setup.hide()
	team_setup.teams_ready.connect(_on_teams_ready)

	phase_overlay = PhaseOverlayScene.instantiate() as PhaseOverlay
	ui_layer.add_child(phase_overlay)
	phase_overlay.hide()

	game_hud = GameHudScene.instantiate() as GameHud
	ui_layer.add_child(game_hud)
	game_hud.hide()

	GameManager.state_changed.connect(_on_state_changed)
	GameManager.round_started.connect(_on_round_started)
	GameManager.round_ended.connect(_on_round_ended)
	GameManager.match_ended.connect(_on_match_ended)
	GameManager.deployment_tick.connect(_on_deployment_tick)

	_start_team_setup()


func _start_team_setup() -> void:
	# Clear previous state
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


func _on_teams_ready(t_assignments: Dictionary, r_assignments: Dictionary) -> void:
	GameManager.set_team_assignments(t_assignments)
	GameManager.set_role_assignments(r_assignments)
	_active_player_indices.clear()
	for pi: int in t_assignments:
		_active_player_indices.append(pi)
	_active_player_indices.sort()

	# Pop team setup
	while not _view_stack.is_empty():
		pop_view()

	# Seed START state to prevent immediate pause
	for pi in _active_player_indices:
		_prev_start_pressed[pi] = true

	# Spawn arena
	_setup_arena()
	game_hud.show()

	# Start round phases — OBSERVATION state handler will spawn characters
	GameManager.start_observation()


func _setup_arena() -> void:
	if arena:
		arena.queue_free()
	arena = ArenaScene.instantiate() as Arena
	arena_container.add_child(arena)
	arena.load_map(MapData.get_test_map())
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
	GameManager.end_round(scoring_team)


func _hide_characters_by_role() -> void:
	## Hide all characters — they become visible when their role is deployed.
	for c in characters:
		if is_instance_valid(c):
			c.visible = false


func _cleanup_round() -> void:
	## Remove characters and traps from previous round.
	for c in characters:
		if is_instance_valid(c):
			c.queue_free()
	characters.clear()
	# Remove traps
	for node in get_tree().get_nodes_in_group("traps"):
		node.queue_free()


func _spawn_characters() -> void:
	for c in characters:
		if is_instance_valid(c):
			c.queue_free()
	characters.clear()

	# Count per-team spawn indices
	var team_spawn_idx: Dictionary = {Enums.Team.TEAM_1: 0, Enums.Team.TEAM_2: 0}

	for pi in _active_player_indices:
		var t: Enums.Team = GameManager.get_player_team(pi)
		var r: Enums.Role = GameManager.get_player_role(pi)

		var character: BaseCharacter
		match r:
			Enums.Role.ESCAPIST:
				character = EscapistScene.instantiate() as BaseCharacter
			Enums.Role.PREDATOR:
				character = PredatorScene.instantiate() as BaseCharacter
			Enums.Role.TRAPPER:
				character = TrapperScene.instantiate() as BaseCharacter
			_:
				character = EscapistScene.instantiate() as BaseCharacter

		character.player_index = pi
		character.team = t
		character.role = r
		character.player_color = Enums.role_color(r)

		var spawn_idx: int = team_spawn_idx[t]
		character.position = arena.get_team_spawn(t, spawn_idx)
		# Aim toward center of map
		character.aim_direction = (arena.get_map_center() - character.position).normalized()
		team_spawn_idx[t] = spawn_idx + 1

		character_container.add_child(character)
		characters.append(character)
		GameManager.register_player_character(pi, character)


func _on_state_changed(new_state: Enums.GameState) -> void:
	if GameManager.is_unpausing:
		GameManager.is_unpausing = false
		return

	match new_state:
		Enums.GameState.OBSERVATION:
			# Re-spawn characters for the new round (roles may have rotated)
			_cleanup_round()
			_spawn_characters()
			_freeze_all()
			_hide_characters_by_role()
		Enums.GameState.DEPLOYMENT:
			pass  # Deployment ticks handle showing characters
		Enums.GameState.HUNT:
			phase_overlay.show_hunt()
		Enums.GameState.ROUND_END:
			_freeze_all()
		Enums.GameState.MATCH_END:
			_freeze_all()


func _on_round_started(_rn: int) -> void:
	pass


func _on_round_ended(winning_team: Enums.Team) -> void:
	phase_overlay.show_round_end(winning_team, GameManager.match_scores)


func _on_match_ended(winning_team: Enums.Team) -> void:
	phase_overlay.show_match_end(winning_team, GameManager.match_scores)


func _on_deployment_tick(role: Enums.Role) -> void:
	phase_overlay.show_deployment(Enums.role_name(role))
	# Show and unfreeze characters of this role
	for c in characters:
		if not is_instance_valid(c):
			continue
		var bc := c as BaseCharacter
		if bc and bc.role == role:
			bc.visible = true
			# During deployment, allow movement but not abilities
			bc.input_locked = false
			bc.movement.unfreeze()


func _process(_delta: float) -> void:
	var state := GameManager.current_state

	# Observation countdown display
	if state == Enums.GameState.OBSERVATION:
		phase_overlay.show_observation(GameManager.get_observation_time())

	# Pause input during gameplay
	if state in [Enums.GameState.DEPLOYMENT, Enums.GameState.HUNT]:
		_check_pause_input()

	# Match end: START to restart
	if state == Enums.GameState.MATCH_END:
		_check_restart_input()


# --- Freeze/Unfreeze helpers ---

func _freeze_all() -> void:
	for c in characters:
		if is_instance_valid(c):
			var bc := c as BaseCharacter
			if bc:
				bc.freeze_character()


func _unfreeze_all() -> void:
	for c in characters:
		if is_instance_valid(c):
			var bc := c as BaseCharacter
			if bc:
				bc.unfreeze_character()


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
			# TODO: push pause menu (M8)
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
