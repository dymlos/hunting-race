class_name StatusEffectComponent
extends Node

## Manages CC effects (stun, root, slow) with duration timers.

signal effect_applied(cc_type: Enums.CCType, duration: float)
signal effect_removed(cc_type: Enums.CCType)

var _active_effects: Dictionary = {}  # {CCType: remaining_duration}
var _movement: MovementComponent


func setup(movement: MovementComponent) -> void:
	_movement = movement


func _process(delta: float) -> void:
	var expired: Array[Enums.CCType] = []
	for cc_type: int in _active_effects:
		_active_effects[cc_type] -= delta
		if _active_effects[cc_type] <= 0.0:
			expired.append(cc_type as Enums.CCType)

	for cc_type in expired:
		_remove_effect(cc_type)


func apply_effect(cc_type: Enums.CCType, duration: float, slow_multiplier: float = 0.4) -> void:
	_active_effects[cc_type] = duration

	match cc_type:
		Enums.CCType.STUN, Enums.CCType.ROOT:
			if _movement:
				_movement.freeze()
		Enums.CCType.SLOW:
			if _movement:
				_movement.set_speed_modifier(&"cc_slow", slow_multiplier)

	effect_applied.emit(cc_type, duration)


func _remove_effect(cc_type: Enums.CCType) -> void:
	_active_effects.erase(cc_type)

	match cc_type:
		Enums.CCType.STUN, Enums.CCType.ROOT:
			# Only unfreeze if no other freeze-type effects remain
			if not is_stunned() and not is_rooted():
				if _movement:
					_movement.unfreeze()
		Enums.CCType.SLOW:
			if _movement:
				_movement.remove_speed_modifier(&"cc_slow")

	effect_removed.emit(cc_type)


func is_stunned() -> bool:
	return _active_effects.has(Enums.CCType.STUN)


func is_rooted() -> bool:
	return _active_effects.has(Enums.CCType.ROOT)


func is_slowed() -> bool:
	return _active_effects.has(Enums.CCType.SLOW)


func clear_all() -> void:
	var keys: Array = _active_effects.keys()
	for cc_type: int in keys:
		_remove_effect(cc_type as Enums.CCType)
