class_name SkillTestView
extends SubViewportContainer

## Embedded practice sandbox used by character selectors.
## It renders real gameplay nodes in a SubViewport so skills use real physics,
## traps, cooldowns and character scripts without leaving the selector.

const ArenaScene := preload("res://scenes/arena/arena.tscn")
const EscapistScene := preload("res://scenes/characters/escapist/escapist.tscn")
const TrapperScene := preload("res://scenes/characters/trapper/trapper.tscn")

const TEST_SIZE := Vector2(560.0, 300.0)
const TEST_TEAM := Enums.Team.TEAM_1
const OPPONENT_TEAM := Enums.Team.TEAM_2
const TRAPPER_TEST_BOT_SPEED_SCALE := 0.38

var _viewport: SubViewport
var _root: Node2D
var _camera: Camera2D
var _arena: Arena
var _player_index: int = -1
var _skill_test_id: String = ""
var _had_previous_player_character: bool = false
var _previous_player_character: Node2D = null


func setup_escapist(player_index: int, animal: Enums.EscapistAnimal) -> void:
	_prepare(player_index, "escapist_%d_%d" % [player_index, Time.get_ticks_msec()])
	_spawn_escapist_player(animal)
	_spawn_escapist_context(animal)


func setup_trapper(player_index: int, character: Enums.TrapperCharacter) -> void:
	_prepare(player_index, "trapper_%d_%d" % [player_index, Time.get_ticks_msec()])
	_spawn_trapper_player(character)
	_spawn_trapper_context(character)


func set_view_rect(rect: Rect2) -> void:
	position = rect.position
	size = rect.size
	_update_viewport_size()


func _exit_tree() -> void:
	GameManager.end_skill_test_context()
	if _player_index >= 0:
		if _had_previous_player_character:
			GameManager.player_characters[_player_index] = _previous_player_character
		else:
			GameManager.player_characters.erase(_player_index)


func _prepare(player_index: int, skill_test_id: String) -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	stretch = true
	_player_index = player_index
	_skill_test_id = skill_test_id
	_had_previous_player_character = GameManager.player_characters.has(player_index)
	_previous_player_character = GameManager.player_characters.get(player_index, null) as Node2D
	GameManager.settings_overrides[&"skill_cooldowns_enabled"] = true
	GameManager.begin_skill_test_context()
	_ensure_viewport()
	_clear_root()
	_build_arena()


func _ensure_viewport() -> void:
	if _viewport != null:
		return
	_viewport = SubViewport.new()
	_viewport.disable_3d = true
	_viewport.transparent_bg = false
	_viewport.world_2d = World2D.new()
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(_viewport)
	_root = Node2D.new()
	_viewport.add_child(_root)
	_camera = Camera2D.new()
	_camera.enabled = true
	_viewport.add_child(_camera)
	_update_viewport_size()


func _update_viewport_size() -> void:
	if _viewport == null:
		return
	var w := maxi(180, int(size.x))
	var h := maxi(100, int(size.y))
	_viewport.size = Vector2i(w, h)
	if _camera != null:
		_camera.position = TEST_SIZE * 0.5
		var zoom := minf(float(w) / TEST_SIZE.x, float(h) / TEST_SIZE.y)
		_camera.zoom = Vector2(zoom, zoom)


func _clear_root() -> void:
	if _root == null:
		return
	for child: Node in _root.get_children():
		child.queue_free()


func _build_arena() -> void:
	_arena = ArenaScene.instantiate() as Arena
	_root.add_child(_arena)
	_arena.load_map(_get_skill_test_map())


func _get_skill_test_map() -> Dictionary:
	var w := TEST_SIZE.x
	var h := TEST_SIZE.y
	return {
		"name": "Prueba de habilidad",
		"description": "Prueba integrada del selector.",
		"size": TEST_SIZE,
		"walls": [
			{"pos": Vector2(0.0, 0.0), "size": Vector2(w, 10.0)},
			{"pos": Vector2(0.0, h - 10.0), "size": Vector2(w, 10.0)},
			{"pos": Vector2(0.0, 0.0), "size": Vector2(10.0, h)},
			{"pos": Vector2(w - 10.0, 0.0), "size": Vector2(10.0, h)},
			{"pos": Vector2(270.0, 82.0), "size": Vector2(22.0, 136.0)},
			{"pos": Vector2(348.0, 210.0), "size": Vector2(108.0, 18.0)},
		],
		"hazards": [
			{"type": "sticky_wall", "pos": Vector2(368.0, 64.0), "size": Vector2(92.0, 18.0)},
		],
		"spawns": [Vector2(92.0, 150.0)],
		"goal": Rect2(),
	}


func _spawn_escapist_player(animal: Enums.EscapistAnimal) -> Escapist:
	var esc := EscapistScene.instantiate() as Escapist
	esc.player_index = _player_index
	esc.team = TEST_TEAM
	esc.escapist_animal = animal
	esc.player_color = Enums.escapist_animal_color(animal)
	esc.position = Vector2(98.0, 150.0)
	esc.aim_direction = Vector2.RIGHT
	esc.set_meta("skill_test_id", _skill_test_id)
	_root.add_child(esc)
	esc.unfreeze_character()
	GameManager.player_characters[_player_index] = esc
	return esc


func _spawn_escapist_context(animal: Enums.EscapistAnimal) -> void:
	match animal:
		Enums.EscapistAnimal.RAT:
			_spawn_ally_escapist(Vector2(390.0, 112.0))
		Enums.EscapistAnimal.SQUIRREL:
			_spawn_breakable_obstacle(Vector2(206.0, 150.0), Vector2(40.0, 76.0))
		Enums.EscapistAnimal.FLY:
			_spawn_pulse_trap(Vector2(352.0, 150.0), Vector2(448.0, 150.0))
		_:
			_spawn_breakable_trap(Vector2(410.0, 150.0), Vector2(30.0, 30.0))


func _spawn_ally_escapist(pos: Vector2) -> void:
	var ally := EscapistScene.instantiate() as Escapist
	ally.player_index = 9001
	ally.team = TEST_TEAM
	ally.escapist_animal = Enums.EscapistAnimal.RABBIT
	ally.player_color = Enums.escapist_animal_color(Enums.EscapistAnimal.RABBIT)
	ally.position = pos
	ally.aim_direction = Vector2.LEFT
	ally.set_meta("skill_test_id", _skill_test_id)
	_root.add_child(ally)
	ally.freeze_character()


func _spawn_trapper_player(character: Enums.TrapperCharacter) -> Trapper:
	var trapper := TrapperScene.instantiate() as Trapper
	trapper.player_index = _player_index
	trapper.team = OPPONENT_TEAM
	trapper.player_color = Enums.role_color(Enums.Role.TRAPPER)
	trapper.trapper_character = character
	trapper.position = Vector2(132.0, 150.0)
	trapper.set_meta("skill_test_id", _skill_test_id)
	_root.add_child(trapper)
	trapper.setup(TEST_SIZE)
	trapper.unfreeze_character()
	GameManager.player_characters[_player_index] = trapper
	return trapper


func _spawn_trapper_context(character: Enums.TrapperCharacter) -> void:
	var enemy := _spawn_enemy_escapist(Vector2(430.0, 150.0))
	enemy.configure_patrol_bot(Vector2(370.0, 150.0), Vector2(488.0, 150.0))
	if character == Enums.TrapperCharacter.ESCORPION:
		_spawn_breakable_trap(Vector2(430.0, 96.0), Vector2(30.0, 30.0))
	elif character == Enums.TrapperCharacter.PULPO:
		enemy.configure_patrol_bot(Vector2(386.0, 112.0), Vector2(492.0, 188.0))


func _spawn_enemy_escapist(pos: Vector2) -> Escapist:
	var esc := EscapistScene.instantiate() as Escapist
	esc.player_index = 9002
	esc.team = TEST_TEAM
	esc.escapist_animal = Enums.EscapistAnimal.RABBIT
	esc.player_color = Enums.escapist_animal_color(Enums.EscapistAnimal.RABBIT)
	esc.position = pos
	esc.aim_direction = Vector2.LEFT
	esc.set_meta("skill_test_id", _skill_test_id)
	_root.add_child(esc)
	esc.unfreeze_character()
	esc.movement.set_speed_modifier(&"skill_test_bot", TRAPPER_TEST_BOT_SPEED_SCALE)
	return esc


func _spawn_breakable_obstacle(pos: Vector2, obstacle_size: Vector2) -> void:
	var obstacle := SkillTestBreakableObstacle.new()
	obstacle.setup(pos, obstacle_size, _skill_test_id)
	_root.add_child(obstacle)


func _spawn_breakable_trap(pos: Vector2, trap_size: Vector2) -> void:
	var trap := SkillTestBreakableTrap.new()
	trap.setup(pos, trap_size, OPPONENT_TEAM, _skill_test_id)
	_root.add_child(trap)


func _spawn_pulse_trap(a: Vector2, b: Vector2) -> void:
	var trap := SkillTestPulseTrap.new()
	trap.setup(a, b, OPPONENT_TEAM, _skill_test_id)
	_root.add_child(trap)


class SkillTestBreakableTrap extends Area2D:
	var owner_team: Enums.Team = Enums.Team.NONE
	var _size: Vector2 = Vector2(30.0, 30.0)
	var _color: Color = Color(1.0, 0.25, 0.15)

	func setup(pos: Vector2, trap_size: Vector2, team: Enums.Team, skill_test_id: String) -> void:
		position = pos
		_size = trap_size
		owner_team = team
		add_to_group("traps")
		set_meta("skill_test_id", skill_test_id)
		collision_layer = Constants.LAYER_TRAPS
		collision_mask = Constants.LAYER_CHARACTERS
		monitoring = true
		monitorable = true
		var shape := RectangleShape2D.new()
		shape.size = _size
		var col := CollisionShape2D.new()
		col.shape = shape
		add_child(col)
		body_entered.connect(_on_body_entered)

	func _on_body_entered(body: Node2D) -> void:
		if body is Escapist:
			var esc := body as Escapist
			if esc.team == owner_team:
				return
			if not _shares_skill_test_scope(esc):
				return
			GameManager.register_trap_contact(esc.player_index, int(get_meta("owner_player_index", -1)))
			esc.notify_trap_status("TRAMPA", Color(1.0, 0.72, 0.12), 0.75)

	func _shares_skill_test_scope(node: Node) -> bool:
		return node.has_meta("skill_test_id") and str(node.get_meta("skill_test_id")) == str(get_meta("skill_test_id"))

	func _draw() -> void:
		var rect := Rect2(-_size * 0.5, _size)
		rect.size = _size
		draw_rect(Rect2(-_size * 0.5, _size), Color(_color, 0.22))
		draw_rect(Rect2(-_size * 0.5, _size), Color(_color, 0.88), false, 2.0)


class SkillTestBreakableObstacle extends StaticBody2D:
	var _size: Vector2 = Vector2(40.0, 76.0)
	var _color: Color = Enums.escapist_animal_color(Enums.EscapistAnimal.SQUIRREL)

	func setup(pos: Vector2, obstacle_size: Vector2, skill_test_id: String) -> void:
		position = pos
		_size = obstacle_size
		add_to_group("traps")
		set_meta("skill_test_id", skill_test_id)
		collision_layer = Constants.LAYER_WALLS | Constants.LAYER_TRAPS
		collision_mask = 0
		var shape := RectangleShape2D.new()
		shape.size = _size
		var col := CollisionShape2D.new()
		col.shape = shape
		add_child(col)

	func _draw() -> void:
		var rect := Rect2(-_size * 0.5, _size)
		draw_rect(rect, Color(_color, 0.24))
		draw_rect(rect, Color(_color, 0.92), false, 2.5)
		draw_line(rect.position + Vector2(8.0, 10.0), rect.position + Vector2(rect.size.x - 8.0, rect.size.y - 12.0),
			Color(1.0, 1.0, 1.0, 0.32), 1.5)
		draw_line(rect.position + Vector2(rect.size.x - 9.0, 12.0), rect.position + Vector2(11.0, rect.size.y - 10.0),
			Color(1.0, 1.0, 1.0, 0.26), 1.2)


class SkillTestPulseTrap extends Area2D:
	var owner_team: Enums.Team = Enums.Team.NONE
	var _path_a: Vector2 = Vector2.ZERO
	var _path_b: Vector2 = Vector2.ZERO
	var _target: Vector2 = Vector2.ZERO
	var _color: Color = Color(1.0, 0.3, 0.12)

	func setup(a: Vector2, b: Vector2, team: Enums.Team, skill_test_id: String) -> void:
		_path_a = a
		_path_b = b
		_target = b
		position = a
		owner_team = team
		add_to_group("traps")
		set_meta("skill_test_id", skill_test_id)
		collision_layer = Constants.LAYER_TRAPS
		collision_mask = Constants.LAYER_CHARACTERS
		monitoring = true
		monitorable = true
		var shape := CircleShape2D.new()
		shape.radius = 18.0
		var col := CollisionShape2D.new()
		col.shape = shape
		add_child(col)
		body_entered.connect(_on_body_entered)

	func _process(delta: float) -> void:
		position = position.move_toward(_target, delta * 120.0)
		if position.distance_to(_target) <= 2.0:
			_target = _path_a if _target == _path_b else _path_b
		queue_redraw()

	func _on_body_entered(body: Node2D) -> void:
		if body is Escapist:
			var esc := body as Escapist
			if esc.team == owner_team:
				return
			if not _shares_skill_test_scope(esc):
				return
			GameManager.register_trap_contact(esc.player_index, int(get_meta("owner_player_index", -1)))
			esc.notify_trap_status("GOLPE", Color(1.0, 0.5, 0.16), 0.65)

	func _shares_skill_test_scope(node: Node) -> bool:
		return node.has_meta("skill_test_id") and str(node.get_meta("skill_test_id")) == str(get_meta("skill_test_id"))

	func _draw() -> void:
		var pulse := 0.68 + 0.32 * sin(Time.get_ticks_msec() / 120.0)
		draw_circle(Vector2.ZERO, 18.0 + 4.0 * pulse, Color(_color, 0.18))
		draw_arc(Vector2.ZERO, 18.0, 0.0, TAU, 18, Color(_color, 0.86), 2.2)
