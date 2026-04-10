class_name HitboxComponent
extends Area2D

## Damage dealer — activate during attacks, deactivate after.

signal hit_landed(target: Node2D)

var _owner_character: BaseCharacter
var _owner_team: Enums.Team
var _hit_targets: Array[Node] = []


func setup(character: BaseCharacter, team: Enums.Team, radius: float = Constants.CHARACTER_RADIUS) -> void:
	_owner_character = character
	_owner_team = team

	collision_layer = Constants.LAYER_HITBOXES
	collision_mask = Constants.LAYER_HURTBOXES
	monitoring = false
	monitorable = false

	# Create shape if not already present
	if get_child_count() == 0:
		var shape := CircleShape2D.new()
		shape.radius = radius
		var col := CollisionShape2D.new()
		col.shape = shape
		add_child(col)


func activate() -> void:
	_hit_targets.clear()
	monitoring = true


func deactivate() -> void:
	monitoring = false
	_hit_targets.clear()


func _on_area_entered(area: Area2D) -> void:
	if area is HurtboxComponent:
		var hurtbox := area as HurtboxComponent
		if hurtbox.owner_character in _hit_targets:
			return
		if hurtbox.owner_team == _owner_team:
			return  # No friendly fire
		_hit_targets.append(hurtbox.owner_character)
		hit_landed.emit(hurtbox.owner_character)


func _ready() -> void:
	area_entered.connect(_on_area_entered)
