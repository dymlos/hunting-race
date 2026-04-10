extends Node

signal state_changed(new_state: Enums.GameState)
signal round_started(round_number: int)
signal round_ended(winning_team: Enums.Team)
signal match_ended(winning_team: Enums.Team)
signal deployment_tick(role: Enums.Role)
signal escapist_killed(killed_team: Enums.Team)
signal escapist_reached_goal(scoring_team: Enums.Team)

var current_state: Enums.GameState = Enums.GameState.TEAM_SETUP
var team_assignments: Dictionary = {}   # {player_index: Enums.Team}
var role_assignments: Dictionary = {}   # {player_index: Enums.Role}
var player_characters: Dictionary = {}  # {player_index: Node2D}

# Scoring
var round_number: int = 0
var match_scores: Array[int] = [0, 0]  # rounds won per team

# Phase timer
var _phase_timer: float = 0.0
var _pre_pause_state: Enums.GameState = Enums.GameState.HUNT

# Deployment queue: Array of {role: Enums.Role, time: float, deployed: bool}
var _deployment_queue: Array[Dictionary] = []
var _deploy_timer: float = 0.0

# Hunt active flag
var hunt_active: bool = false


func _process(delta: float) -> void:
	if current_state == Enums.GameState.PAUSED:
		return

	match current_state:
		Enums.GameState.OBSERVATION:
			_phase_timer -= delta
			if _phase_timer <= 0.0:
				start_deployment()
		Enums.GameState.DEPLOYMENT:
			_deploy_timer += delta
			for entry in _deployment_queue:
				if not entry["deployed"] and _deploy_timer >= entry["time"]:
					entry["deployed"] = true
					deployment_tick.emit(entry["role"] as Enums.Role)
			# Check if all deployed
			var all_deployed := true
			for entry in _deployment_queue:
				if not entry["deployed"]:
					all_deployed = false
					break
			if all_deployed:
				activate_hunt()
		Enums.GameState.ROUND_END:
			_phase_timer -= delta
			if _phase_timer <= 0.0:
				_advance_after_round()


func set_team_assignments(assignments: Dictionary) -> void:
	team_assignments = assignments.duplicate()


func set_role_assignments(roles: Dictionary) -> void:
	role_assignments = roles.duplicate()


func register_player_character(player_index: int, character: Node2D) -> void:
	player_characters[player_index] = character


func get_player_team(player_index: int) -> Enums.Team:
	return team_assignments.get(player_index, Enums.Team.NONE) as Enums.Team


func get_player_role(player_index: int) -> Enums.Role:
	return role_assignments.get(player_index, Enums.Role.NONE) as Enums.Role


func get_observation_time() -> float:
	return _phase_timer


func start_observation() -> void:
	round_number += 1
	hunt_active = false
	_phase_timer = Constants.OBSERVATION_DURATION
	_change_state(Enums.GameState.OBSERVATION)
	round_started.emit(round_number)


func start_deployment() -> void:
	hunt_active = false
	_deploy_timer = 0.0
	_deployment_queue = [
		{"role": Enums.Role.TRAPPER, "time": Constants.DEPLOY_TRAPPER, "deployed": false},
		{"role": Enums.Role.PREDATOR, "time": Constants.DEPLOY_PREDATOR, "deployed": false},
		{"role": Enums.Role.ESCAPIST, "time": Constants.DEPLOY_ESCAPIST, "deployed": false},
	]
	_change_state(Enums.GameState.DEPLOYMENT)


func activate_hunt() -> void:
	hunt_active = true
	_change_state(Enums.GameState.HUNT)


func end_round(winning_team: Enums.Team) -> void:
	if current_state == Enums.GameState.ROUND_END:
		return
	hunt_active = false
	if winning_team == Enums.Team.TEAM_1:
		match_scores[0] += 1
	else:
		match_scores[1] += 1
	_phase_timer = Constants.ROUND_END_DURATION
	_change_state(Enums.GameState.ROUND_END)
	round_ended.emit(winning_team)


func pause_game() -> void:
	if current_state == Enums.GameState.PAUSED:
		return
	_pre_pause_state = current_state
	_change_state(Enums.GameState.PAUSED)


var is_unpausing: bool = false

func unpause_game() -> void:
	if current_state != Enums.GameState.PAUSED:
		return
	is_unpausing = true
	_change_state(_pre_pause_state)


func reset_match() -> void:
	round_number = 0
	match_scores = [0, 0]
	hunt_active = false
	player_characters.clear()
	_change_state(Enums.GameState.TEAM_SETUP)


func _change_state(new_state: Enums.GameState) -> void:
	current_state = new_state
	state_changed.emit(new_state)


func rotate_roles() -> void:
	## Rotate roles within each team: Escapist→Predator→Trapper→Escapist.
	var role_cycle: Array[Enums.Role] = [Enums.Role.ESCAPIST, Enums.Role.PREDATOR, Enums.Role.TRAPPER]
	for pi: int in role_assignments:
		var current: Enums.Role = role_assignments[pi] as Enums.Role
		var idx := role_cycle.find(current)
		if idx >= 0:
			role_assignments[pi] = role_cycle[(idx + 1) % role_cycle.size()]


func _advance_after_round() -> void:
	if match_scores[0] >= Constants.ROUNDS_TO_WIN:
		_change_state(Enums.GameState.MATCH_END)
		match_ended.emit(Enums.Team.TEAM_1)
	elif match_scores[1] >= Constants.ROUNDS_TO_WIN:
		_change_state(Enums.GameState.MATCH_END)
		match_ended.emit(Enums.Team.TEAM_2)
	else:
		rotate_roles()
		player_characters.clear()
		start_observation()
