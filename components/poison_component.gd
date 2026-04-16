class_name PoisonComponent
extends Node

## Manages poison state on an Escapist. Poisoned players can be cured by ally touch
## or die when the timer expires.

signal poisoned
signal cured
signal poison_expired

var is_poisoned: bool = false
var _poison_timer: float = 0.0
var _poison_total_duration: float = 0.0
var _owner_escapist: Node2D  # The Escapist this component belongs to


func setup(escapist: Node2D) -> void:
	_owner_escapist = escapist


func apply_poison(duration: float = -1.0) -> void:
	if _owner_escapist is Escapist and (_owner_escapist as Escapist).is_effect_immune():
		return
	if duration < 0.0:
		duration = GameManager.settings_overrides.get(&"poison_duration", Constants.POISON_DURATION) as float
	if is_poisoned:
		return
	is_poisoned = true
	_poison_timer = duration
	_poison_total_duration = duration
	poisoned.emit()
	AudioManager.play_effect(&"Poison")


func cure() -> void:
	if not is_poisoned:
		return
	is_poisoned = false
	_poison_timer = 0.0
	cured.emit()
	AudioManager.play_effect(&"PoisonCure")


func _process(delta: float) -> void:
	if not is_poisoned:
		return

	_poison_timer -= delta * _get_poison_tick_multiplier()

	# Check for ally cure
	if _check_ally_cure():
		cure()
		return

	if _poison_timer <= 0.0:
		is_poisoned = false
		_poison_timer = 0.0
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
	return clampf(_poison_timer / maxf(_poison_total_duration, 0.01), 0.0, 1.0)


func _get_poison_tick_multiplier() -> float:
	if not _owner_escapist or not is_instance_valid(_owner_escapist):
		return 1.0
	if not (_owner_escapist is Escapist):
		return 1.0

	var esc := _owner_escapist as Escapist
	if not esc.movement or not esc.movement.body:
		return 1.0

	var base_speed := maxf(esc.movement.move_speed, 1.0)
	var current_speed := esc.movement.body.velocity.length()
	if esc.movement.is_dashing:
		current_speed = maxf(current_speed, base_speed * 1.35)

	var move_ratio := clampf(current_speed / base_speed, 0.0, 1.5)
	return lerpf(0.35, 1.7, move_ratio)
