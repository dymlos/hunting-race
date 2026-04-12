class_name PoisonComponent
extends Node

## Manages poison state on an Escapist. Poisoned players can be cured by ally touch
## or die when the timer expires.

signal poisoned
signal cured
signal poison_expired

var is_poisoned: bool = false
var _poison_timer: float = 0.0
var _owner_escapist: Node2D  # The Escapist this component belongs to


func setup(escapist: Node2D) -> void:
	_owner_escapist = escapist


func apply_poison(duration: float = Constants.POISON_DURATION) -> void:
	if is_poisoned:
		# Refresh timer
		_poison_timer = duration
		return
	is_poisoned = true
	_poison_timer = duration
	poisoned.emit()


func cure() -> void:
	if not is_poisoned:
		return
	is_poisoned = false
	_poison_timer = 0.0
	cured.emit()


func _process(delta: float) -> void:
	if not is_poisoned:
		return

	_poison_timer -= delta

	# Check for ally cure
	if _check_ally_cure():
		cure()
		return

	if _poison_timer <= 0.0:
		is_poisoned = false
		poison_expired.emit()


func _check_ally_cure() -> bool:
	if not _owner_escapist or not is_instance_valid(_owner_escapist):
		return false

	var tree := _owner_escapist.get_tree()
	if not tree:
		return false

	var owner_team: Enums.Team = _owner_escapist.team as Enums.Team
	var owner_pos: Vector2 = _owner_escapist.global_position

	for node: Node in tree.get_nodes_in_group("characters"):
		if node == _owner_escapist:
			continue
		if not node is CharacterBody2D:
			continue
		var other := node as BaseCharacter
		if other.team != owner_team:
			continue
		# Check if the other is an escapist that is alive and not poisoned
		if other is Escapist:
			var other_esc := other as Escapist
			if other_esc.is_dead or other_esc.has_scored:
				continue
			if other_esc.poison and other_esc.poison.is_poisoned:
				continue
		var dist: float = owner_pos.distance_to(other.global_position)
		if dist < Constants.POISON_CURE_RADIUS:
			return true

	return false


func get_timer_ratio() -> float:
	if not is_poisoned:
		return 0.0
	return clampf(_poison_timer / Constants.POISON_DURATION, 0.0, 1.0)
