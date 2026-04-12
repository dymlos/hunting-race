class_name BaseCharacter
extends CharacterBody2D

## Base class for all player characters. Handles input polling, movement, and rendering.

@export var player_index: int = 0
@export var team: Enums.Team = Enums.Team.NONE
@export var role: Enums.Role = Enums.Role.NONE

var player_color: Color = Color.WHITE
var aim_direction: Vector2 = Vector2.RIGHT
var input_locked: bool = true

var movement: MovementComponent


func _ready() -> void:
	add_to_group("characters")
	collision_layer = Constants.LAYER_CHARACTERS
	collision_mask = Constants.LAYER_WALLS | Constants.LAYER_CHARACTERS

	# Create movement component
	movement = MovementComponent.new()
	movement.body = self
	add_child(movement)

	# Collision shape
	var shape := CircleShape2D.new()
	shape.radius = Constants.CHARACTER_RADIUS
	var col := CollisionShape2D.new()
	col.shape = shape
	add_child(col)

	_setup_role()


func _setup_role() -> void:
	# Override in subclasses to set speed, abilities, etc.
	pass


func _physics_process(_delta: float) -> void:
	queue_redraw()

	if input_locked or player_index >= 100:
		return

	# Movement input
	var move_vec := InputManager.get_move_vector(player_index)
	if self is Escapist and (self as Escapist).controls_inverted:
		move_vec *= -1.0
	movement.apply_movement(move_vec)

	# Aim input
	var aim_vec := InputManager.get_aim_vector(player_index)
	if aim_vec.length() > 0.1:
		aim_direction = aim_vec.normalized()
	elif move_vec.length() > 0.1:
		aim_direction = move_vec.normalized()

	_handle_ability_input(_delta)


func _handle_ability_input(_delta: float) -> void:
	# Override in subclasses
	pass


func get_role() -> Enums.Role:
	return role


func get_team() -> Enums.Team:
	return team


func freeze_character() -> void:
	input_locked = true
	movement.freeze()


func unfreeze_character() -> void:
	input_locked = false
	movement.unfreeze()


func _draw() -> void:
	# Body circle
	draw_circle(Vector2.ZERO, Constants.CHARACTER_RADIUS, player_color)

	# Direction indicator
	var tip := aim_direction * (Constants.CHARACTER_RADIUS + 8.0)
	draw_line(Vector2.ZERO, tip, player_color, 2.0)

	# Player label
	var label := "P%d" % (player_index + 1)
	if player_index >= 100:
		label = "BOT"
	draw_string(ThemeDB.fallback_font, Vector2(-10, -Constants.CHARACTER_RADIUS - 6),
		label, HORIZONTAL_ALIGNMENT_CENTER, -1, 10, player_color)
