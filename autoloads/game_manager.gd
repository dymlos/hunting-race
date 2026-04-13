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
var player_score_history: Dictionary = {}
var _round_stats: Dictionary = {}

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
		Enums.GameState.OBSERVATION:
			_phase_timer -= delta
			if _phase_timer <= 0.0:
				activate_hunt()
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


func get_competitive_round_number() -> int:
	if round_number <= 0:
		return 0
	return int(ceili(float(round_number) / 2.0))


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
	_prepare_round_stats()
	_phase_timer = settings_overrides.get(&"observation_duration", Constants.OBSERVATION_DURATION) as float
	_change_state(Enums.GameState.OBSERVATION)
	round_started.emit(round_number)


func activate_hunt() -> void:
	trap_lifetime_active = false
	if not settings_overrides.get(&"hunt_countdown_enabled", true):
		activate_escape()
		return
	_phase_timer = settings_overrides.get(&"hunt_countdown_duration", Constants.HUNT_COUNTDOWN_DURATION) as float
	_change_state(Enums.GameState.HUNT)


func activate_escape() -> void:
	hunt_active = true
	trap_lifetime_active = true
	_hunt_timer = settings_overrides.get(&"hunt_duration", Constants.HUNT_DURATION) as float
	_change_state(Enums.GameState.ESCAPE)


func get_hunt_time() -> float:
	return _hunt_timer


func register_escapist_scored(player_index: int) -> void:
	if not hunt_active:
		return
	var team := get_player_team(player_index)
	var points := _finalize_player_round_score(player_index, true)
	_round_points += points
	if team == Enums.Team.TEAM_1:
		match_scores[0] += points
	else:
		match_scores[1] += points
	_living_escapists -= 1
	escapist_scored.emit(team)
	_check_round_over()


func register_escapist_died(player_index: int) -> void:
	if not hunt_active:
		return
	var team := get_player_team(player_index)
	var points := _finalize_player_round_score(player_index, false)
	_round_points += points
	_add_points_to_team(team, points)
	_living_escapists -= 1
	escapist_died.emit(team)
	_check_round_over()


func register_trap_contact(player_index: int) -> void:
	if not hunt_active:
		return
	if not _round_stats.has(player_index):
		return
	var stats: Dictionary = _round_stats[player_index]
	stats["trap_contacts"] = (stats.get("trap_contacts", 0) as int) + 1


func register_respawn_penalty(player_index: int, reason: StringName) -> void:
	if not hunt_active:
		return
	if not _round_stats.has(player_index):
		return
	var stats: Dictionary = _round_stats[player_index]
	stats["respawns"] = (stats.get("respawns", 0) as int) + 1
	var reasons: Array = stats.get("respawn_reasons", []) as Array
	reasons.append(reason)
	stats["respawn_reasons"] = reasons


func _check_round_over() -> void:
	if _living_escapists <= 0:
		_end_round()


func _end_round() -> void:
	hunt_active = false
	trap_lifetime_active = false
	_finalize_unresolved_escapists()
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
	player_score_history.clear()
	_round_stats.clear()
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
	if current_state == Enums.GameState.OBSERVATION:
		var observation_duration := settings_overrides.get(&"observation_duration", Constants.OBSERVATION_DURATION) as float
		_phase_timer = minf(_phase_timer, observation_duration)
	elif current_state == Enums.GameState.PAUSED and _pre_pause_state == Enums.GameState.OBSERVATION:
		var observation_duration := settings_overrides.get(&"observation_duration", Constants.OBSERVATION_DURATION) as float
		_phase_timer = minf(_phase_timer, observation_duration)
	if current_state == Enums.GameState.HUNT and not countdown_enabled:
		activate_escape()
	elif current_state == Enums.GameState.PAUSED and _pre_pause_state == Enums.GameState.HUNT and not countdown_enabled:
		hunt_active = true
		trap_lifetime_active = true
		_hunt_timer = settings_overrides.get(&"hunt_duration", Constants.HUNT_DURATION) as float
		_pre_pause_state = Enums.GameState.ESCAPE
	elif current_state == Enums.GameState.PAUSED and _pre_pause_state == Enums.GameState.HUNT:
		var countdown_duration := settings_overrides.get(&"hunt_countdown_duration", Constants.HUNT_COUNTDOWN_DURATION) as float
		_phase_timer = minf(_phase_timer, countdown_duration)
	elif current_state == Enums.GameState.HUNT:
		var countdown_duration := settings_overrides.get(&"hunt_countdown_duration", Constants.HUNT_COUNTDOWN_DURATION) as float
		_phase_timer = minf(_phase_timer, countdown_duration)
	elif is_escape_context:
		var duration := settings_overrides.get(&"hunt_duration", Constants.HUNT_DURATION) as float
		_hunt_timer = minf(_hunt_timer, duration)


func get_round_score_entries() -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	for pi: int in _round_stats:
		entries.append((_round_stats[pi] as Dictionary).duplicate(true))
	entries.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return (a.get("player_index", 0) as int) < (b.get("player_index", 0) as int)
	)
	return entries


func get_match_score_entries() -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	for pi: int in player_score_history:
		var total := 0
		var base_score := 0
		var time_score := 0
		var trap_bonus := 0
		var respawn_penalty := 0
		var trap_penalty := 0
		var escaped := 0
		var trap_contacts := 0
		var respawns := 0
		var history: Array = player_score_history[pi] as Array
		for entry: Dictionary in history:
			total += entry.get("total", 0) as int
			base_score += entry.get("base_score", 0) as int
			time_score += entry.get("time_score", 0) as int
			trap_bonus += entry.get("trap_bonus", 0) as int
			respawn_penalty += entry.get("respawn_penalty", 0) as int
			trap_penalty += entry.get("trap_penalty", 0) as int
			trap_contacts += entry.get("trap_contacts", 0) as int
			respawns += entry.get("respawns", 0) as int
			if entry.get("escaped", false):
				escaped += 1
		entries.append({
			"player_index": pi,
			"team": team_assignments.get(pi, Enums.Team.NONE),
			"total": total,
			"base_score": base_score,
			"time_score": time_score,
			"trap_bonus": trap_bonus,
			"respawn_penalty": respawn_penalty,
			"trap_penalty": trap_penalty,
			"escaped": escaped,
			"trap_contacts": trap_contacts,
			"respawns": respawns,
			"rounds": history.size(),
		})
	entries.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return (a.get("player_index", 0) as int) < (b.get("player_index", 0) as int)
	)
	return entries


func _prepare_round_stats() -> void:
	_round_stats.clear()
	for pi: int in role_assignments:
		if role_assignments[pi] != Enums.Role.ESCAPIST:
			continue
		_round_stats[pi] = {
			"player_index": pi,
			"round": get_competitive_round_number(),
			"team": team_assignments.get(pi, Enums.Team.NONE),
			"escaped": false,
			"finalized": false,
			"escape_time": 0.0,
			"time_remaining": 0.0,
			"trap_contacts": 0,
			"respawns": 0,
			"respawn_reasons": [],
			"base_score": 0,
			"time_score": 0,
			"trap_bonus": 0,
			"respawn_penalty": 0,
			"trap_penalty": 0,
			"total": 0,
		}
		if not player_score_history.has(pi):
			player_score_history[pi] = []


func _finalize_unresolved_escapists() -> void:
	for pi: int in _round_stats:
		var stats: Dictionary = _round_stats[pi]
		if not stats.get("finalized", false):
			var points := _finalize_player_round_score(pi, false)
			_round_points += points
			_add_points_to_team(stats.get("team", Enums.Team.NONE) as Enums.Team, points)


func _finalize_player_round_score(player_index: int, escaped: bool) -> int:
	if not _round_stats.has(player_index):
		return 0
	var stats: Dictionary = _round_stats[player_index]
	if stats.get("finalized", false):
		return stats.get("total", 0) as int

	var trap_contacts: int = stats.get("trap_contacts", 0) as int
	var respawns: int = stats.get("respawns", 0) as int
	var base_score := Constants.SCORE_ESCAPE_BASE if escaped else 0
	var time_score := ceili(maxf(_hunt_timer, 0.0) * Constants.SCORE_ESCAPE_TIME_MULTIPLIER) if escaped else 0
	var trap_bonus := 0
	if escaped and trap_contacts == 0:
		trap_bonus = Constants.SCORE_NO_TRAP_BONUS
	elif escaped and trap_contacts == 1:
		trap_bonus = Constants.SCORE_ONE_TRAP_BONUS
	var respawn_penalty := respawns * Constants.SCORE_RESPAWN_PENALTY
	var trap_penalty := Constants.SCORE_TEN_TRAPS_PENALTY if trap_contacts >= Constants.SCORE_TRAP_PENALTY_THRESHOLD else 0
	var total := base_score + time_score + trap_bonus + respawn_penalty + trap_penalty

	stats["escaped"] = escaped
	stats["finalized"] = true
	stats["escape_time"] = (settings_overrides.get(&"hunt_duration", Constants.HUNT_DURATION) as float) - _hunt_timer if escaped else 0.0
	stats["time_remaining"] = maxf(_hunt_timer, 0.0) if escaped else 0.0
	stats["base_score"] = base_score
	stats["time_score"] = time_score
	stats["trap_bonus"] = trap_bonus
	stats["respawn_penalty"] = respawn_penalty
	stats["trap_penalty"] = trap_penalty
	stats["total"] = total

	var history: Array = player_score_history.get(player_index, []) as Array
	history.append(stats.duplicate(true))
	player_score_history[player_index] = history
	return total


func _add_points_to_team(team: Enums.Team, points: int) -> void:
	if team == Enums.Team.TEAM_1:
		match_scores[0] += points
	elif team == Enums.Team.TEAM_2:
		match_scores[1] += points


func _advance_after_round() -> void:
	var rounds_to_play: int = settings_overrides.get(&"score_to_win", Constants.SCORE_TO_WIN) as int
	var completed_competitive_round := round_number > 0 and round_number % 2 == 0
	if completed_competitive_round and get_competitive_round_number() >= rounds_to_play and match_scores[0] != match_scores[1]:
		var winning_team := Enums.Team.TEAM_1 if match_scores[0] > match_scores[1] else Enums.Team.TEAM_2
		_change_state(Enums.GameState.MATCH_END)
		match_ended.emit(winning_team)
	else:
		swap_team_roles()
		player_characters.clear()
		_awaiting_character_select = true
		round_advancing.emit()
