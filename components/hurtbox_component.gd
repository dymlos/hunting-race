class_name HurtboxComponent
extends Area2D

## Damage receiver — always active on vulnerable characters.

var owner_character: BaseCharacter
var owner_team: Enums.Team


func setup(character: BaseCharacter, team: Enums.Team, radius: float = Constants.CHARACTER_RADIUS) -> void:
	owner_character = character
	owner_team = team

	collision_layer = Constants.LAYER_HURTBOXES
	collision_mask = 0  # Doesn't detect anything itself — hitboxes detect it
	monitoring = false
	monitorable = true

	if get_child_count() == 0:
		var shape := CircleShape2D.new()
		shape.radius = radius
		var col := CollisionShape2D.new()
		col.shape = shape
		add_child(col)
