extends Node

signal state_changed(new_state: Enums.GameState)
signal round_started(round_number: int)
signal round_ended(escapist_team: Enums.Team, points_scored: int)
signal match_ended(winning_team: Enums.Team)
signal escapist_scored(team: Enums.Team)
signal escapist_died(team: Enums.Team)
signal round_advancing  # Emitted when round end timer expires, before next observation

var current_state: Enums.GameState = Enums.GameState.TEAM_SETUP
var team_assignments: Dictionary = {}          # {player_index: Enums.Team}
var role_assignments: Dictionary = {}          # {player_index: Enums.Role}
var character_selections: Dictionary = {}      # {player_index: Enums.TrapperCharacter}
var player_characters: Dictionary = {}         # {player_index: Node2D}
var settings_overrides: Dictionary = {}        # {StringName: Variant} — from settings menu

# Which team is currently playing as escapists
var escapist_team: Enums.Team = Enums.Team.TEAM_1

# Scoring — cumulative points (each escapist reaching goal = +1)
var round_number: int = 0
var match_scores: Array[int] = [0, 0]  # points per team

# Round tracking
var _living_escapists: int = 0  # Escapists still alive and haven't scored
var _round_points: int = 0     # Points scored this round
var hunt_active: bool = false
var trap_lifetime_active: bool = false

# Phase timer
var _phase_timer: float = 0.0
var _hunt_timer: float = 0.0
var _pre_pause_state: Enums.GameState = Enums.GameState.ESCAPE

var is_unpausing: bool = false
var _awaiting_character_select: bool = false


func _process(delta: float) -> void:
	if current_state == Enums.GameState.PAUSED:
		return

	match current_state:
		Enums.GameState.HUNT:
			_phase_timer -= delta
			if _phase_timer <= 0.0:
				activate_escape()
		Enums.GameState.ESCAPE:
			_hunt_timer -= delta
			if _hunt_timer <= 0.0:
				_end_round()
		Enums.GameState.ROUND_END:
			if _awaiting_character_select:
				return
			_phase_timer -= delta
			if _phase_timer <= 0.0:
				_advance_after_round()


func set_team_assignments(assignments: Dictionary) -> void:
	team_assignments = assignments.duplicate()


func set_character_selections(selections: Dictionary) -> void:
	for pi: int in selections:
		character_selections[pi] = selections[pi]


func get_player_character(player_index: int) -> Enums.TrapperCharacter:
	return character_selections.get(player_index, Enums.TrapperCharacter.NONE) as Enums.TrapperCharacter


func get_trapping_team() -> Enums.Team:
	## Returns the team that is trapping this round (opposite of escapist_team).
	if escapist_team == Enums.Team.TEAM_1:
		return Enums.Team.TEAM_2
	return Enums.Team.TEAM_1


func assign_round_roles() -> void:
	## Assign roles based on which team is currently escapists.
	role_assignments.clear()
	for pi: int in team_assignments:
		var t: Enums.Team = team_assignments[pi] as Enums.Team
		if t == escapist_team:
			role_assignments[pi] = Enums.Role.ESCAPIST
		else:
			role_assignments[pi] = Enums.Role.TRAPPER


func register_player_character(player_index: int, character: Node2D) -> void:
	player_characters[player_index] = character


func get_player_team(player_index: int) -> Enums.Team:
	return team_assignments.get(player_index, Enums.Team.NONE) as Enums.Team


func get_player_role(player_index: int) -> Enums.Role:
	return role_assignments.get(player_index, Enums.Role.NONE) as Enums.Role


func get_observation_time() -> float:
	return _phase_timer


func get_living_escapists() -> int:
	return _living_escapists


func start_observation() -> void:
	_awaiting_character_select = false
	round_number += 1
	hunt_active = false
	trap_lifetime_active = false
	_round_points = 0
	assign_round_roles()
	# Count escapists
	_living_escapists = 0
	for pi: int in role_assignments:
		if role_assignments[pi] == Enums.Role.ESCAPIST:
			_living_escapists += 1
	_phase_timer = settings_overrides.get(&"observation_duration", Constants.OBSERVATION_DURATION) as float
	_change_state(Enums.GameState.HUNT)
	round_started.emit(round_number)
	if not settings_overrides.get(&"hunt_countdown_enabled", true):
		activate_escape()


func activate_escape() -> void:
	hunt_active = true
	trap_lifetime_active = true
	_hunt_timer = settings_overrides.get(&"hunt_duration", Constants.HUNT_DURATION) as float
	_change_state(Enums.GameState.ESCAPE)


func get_hunt_time() -> float:
	return _hunt_timer


func register_escapist_scored(team: Enums.Team) -> void:
	if not hunt_active:
		return
	_round_points += 1
	if team == Enums.Team.TEAM_1:
		match_scores[0] += 1
	else:
		match_scores[1] += 1
	_living_escapists -= 1
	escapist_scored.emit(team)
	_check_round_over()


func register_escapist_died(team: Enums.Team) -> void:
	if not hunt_active:
		return
	_living_escapists -= 1
	escapist_died.emit(team)
	_check_round_over()


func _check_round_over() -> void:
	if _living_escapists <= 0:
		_end_round()


func _end_round() -> void:
	hunt_active = false
	trap_lifetime_active = false
	_phase_timer = Constants.ROUND_END_DURATION
	_change_state(Enums.GameState.ROUND_END)
	round_ended.emit(escapist_team, _round_points)


func swap_team_roles() -> void:
	if escapist_team == Enums.Team.TEAM_1:
		escapist_team = Enums.Team.TEAM_2
	else:
		escapist_team = Enums.Team.TEAM_1


func pause_game() -> void:
	if current_state == Enums.GameState.PAUSED:
		return
	_pre_pause_state = current_state
	_change_state(Enums.GameState.PAUSED)


func unpause_game() -> void:
	if current_state != Enums.GameState.PAUSED:
		return
	is_unpausing = true
	_change_state(_pre_pause_state)


func reset_match() -> void:
	round_number = 0
	match_scores = [0, 0]
	hunt_active = false
	trap_lifetime_active = false
	_awaiting_character_select = false
	escapist_team = Enums.Team.TEAM_1
	player_characters.clear()
	role_assignments.clear()
	character_selections.clear()
	_change_state(Enums.GameState.TEAM_SETUP)


func _change_state(new_state: Enums.GameState) -> void:
	current_state = new_state
	state_changed.emit(new_state)


func apply_runtime_settings() -> void:
	var countdown_enabled: bool = settings_overrides.get(&"hunt_countdown_enabled", true)
	var is_escape_context := (
		current_state == Enums.GameState.ESCAPE
		or (current_state == Enums.GameState.PAUSED and _pre_pause_state == Enums.GameState.ESCAPE)
	)
	if current_state == Enums.GameState.HUNT and not countdown_enabled:
		activate_escape()
	elif current_state == Enums.GameState.PAUSED and _pre_pause_state == Enums.GameState.HUNT and not countdown_enabled:
		hunt_active = true
		trap_lifetime_active = true
		_hunt_timer = settings_overrides.get(&"hunt_duration", Constants.HUNT_DURATION) as float
		_pre_pause_state = Enums.GameState.ESCAPE
	elif current_state == Enums.GameState.PAUSED and _pre_pause_state == Enums.GameState.HUNT:
		var countdown_duration := settings_overrides.get(&"observation_duration", Constants.OBSERVATION_DURATION) as float
		_phase_timer = minf(_phase_timer, countdown_duration)
	elif is_escape_context:
		var duration := settings_overrides.get(&"hunt_duration", Constants.HUNT_DURATION) as float
		_hunt_timer = minf(_hunt_timer, duration)


func _advance_after_round() -> void:
	# Check if either team reached score threshold
	var win_score: int = settings_overrides.get(&"score_to_win", Constants.SCORE_TO_WIN) as int
	if match_scores[0] >= win_score:
		_change_state(Enums.GameState.MATCH_END)
		match_ended.emit(Enums.Team.TEAM_1)
	elif match_scores[1] >= win_score:
		_change_state(Enums.GameState.MATCH_END)
		match_ended.emit(Enums.Team.TEAM_2)
	else:
		swap_team_roles()
		player_characters.clear()
		_awaiting_character_select = true
		round_advancing.emit()
