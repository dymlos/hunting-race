class_name Arena
extends Node2D

## Builds arena geometry from MapData at runtime.

var _map_data: Dictionary = {}
var _wall_bodies: Array[StaticBody2D] = []
var _goal_zones: Array[Area2D] = []  # [0] = team1 goal, [1] = team2 goal

signal goal_entered(scoring_team: Enums.Team)


func load_map(map_data: Dictionary) -> void:
	_map_data = map_data
	_clear()
	_build_walls()
	_build_goals()
	queue_redraw()


func get_map_size() -> Vector2:
	return _map_data.get("size", Vector2(1600, 900)) as Vector2


func get_map_center() -> Vector2:
	return get_map_size() / 2.0


func get_team_spawn(team: Enums.Team, index: int) -> Vector2:
	var key := "spawn_team1" if team == Enums.Team.TEAM_1 else "spawn_team2"
	var spawns: Array = _map_data.get(key, [])
	if index < spawns.size():
		return spawns[index] as Vector2
	return get_map_center()


func _clear() -> void:
	for body in _wall_bodies:
		body.queue_free()
	_wall_bodies.clear()
	for zone in _goal_zones:
		zone.queue_free()
	_goal_zones.clear()


func _build_walls() -> void:
	var walls: Array = _map_data.get("walls", [])
	for wall_def in walls:
		var pos: Vector2 = wall_def["pos"]
		var size: Vector2 = wall_def["size"]

		var body := StaticBody2D.new()
		body.collision_layer = Constants.LAYER_WALLS
		body.collision_mask = 0

		var shape := RectangleShape2D.new()
		shape.size = size

		var col := CollisionShape2D.new()
		col.shape = shape
		col.position = size / 2.0

		body.position = pos
		body.add_child(col)
		add_child(body)
		_wall_bodies.append(body)


func _build_goals() -> void:
	# Team 1's goal (where team 1's Escapist must reach)
	var goal1_rect: Rect2 = _map_data.get("goal_team1", Rect2())
	_goal_zones.append(_create_goal_zone(goal1_rect, Enums.Team.TEAM_1))

	# Team 2's goal
	var goal2_rect: Rect2 = _map_data.get("goal_team2", Rect2())
	_goal_zones.append(_create_goal_zone(goal2_rect, Enums.Team.TEAM_2))


func _create_goal_zone(rect: Rect2, team: Enums.Team) -> Area2D:
	var area := Area2D.new()
	area.collision_layer = Constants.LAYER_GOAL_ZONES
	area.collision_mask = Constants.LAYER_CHARACTERS
	area.monitoring = true
	area.monitorable = false

	var shape := RectangleShape2D.new()
	shape.size = rect.size

	var col := CollisionShape2D.new()
	col.shape = shape
	col.position = rect.size / 2.0

	area.position = rect.position
	area.add_child(col)
	add_child(area)

	area.body_entered.connect(_on_goal_body_entered.bind(team))
	return area


func _on_goal_body_entered(body: Node2D, goal_team: Enums.Team) -> void:
	if not GameManager.hunt_active:
		return
	# Only the Escapist of the matching team can score
	if body.has_method("get_role") and body.has_method("get_team"):
		var role: Enums.Role = body.get_role()
		var team: Enums.Team = body.get_team()
		if role == Enums.Role.ESCAPIST and team == goal_team:
			goal_entered.emit(goal_team)


func _draw() -> void:
	if _map_data.is_empty():
		return

	var map_size := get_map_size()

	# Background
	draw_rect(Rect2(Vector2.ZERO, map_size), Color(0.08, 0.08, 0.08))

	# Grid lines
	var grid_step := 60.0
	var grid_color := Color(0.15, 0.15, 0.15)
	var x := 0.0
	while x <= map_size.x:
		draw_line(Vector2(x, 0), Vector2(x, map_size.y), grid_color, 1.0)
		x += grid_step
	var y := 0.0
	while y <= map_size.y:
		draw_line(Vector2(0, y), Vector2(map_size.x, y), grid_color, 1.0)
		y += grid_step

	# Walls
	var wall_color := Color(0.6, 0.6, 0.6)
	var walls: Array = _map_data.get("walls", [])
	for wall_def in walls:
		var pos: Vector2 = wall_def["pos"]
		var size: Vector2 = wall_def["size"]
		draw_rect(Rect2(pos, size), wall_color)

	# Goal zones
	var goal1_rect: Rect2 = _map_data.get("goal_team1", Rect2())
	var goal2_rect: Rect2 = _map_data.get("goal_team2", Rect2())
	var t1c := Enums.team_color(Enums.Team.TEAM_1)
	var t2c := Enums.team_color(Enums.Team.TEAM_2)
	draw_rect(goal1_rect, Color(t1c, 0.2))
	draw_rect(goal1_rect, t1c, false, 2.0)
	draw_rect(goal2_rect, Color(t2c, 0.2))
	draw_rect(goal2_rect, t2c, false, 2.0)
