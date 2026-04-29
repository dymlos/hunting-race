extends Node

## Custom per-device input polling for up to 8 controllers.
## Godot's action map doesn't handle 8 players natively, so we poll raw device state.

signal player_device_lost(player_index: int)
signal player_device_restored(player_index: int)

# Maps player_index (0-7) to joy device_id (-1 if disconnected but slot preserved)
var device_assignments: Dictionary = {}  # {player_index: device_id}

# Player indices that lost a device, mapped to their GUID for identity-based reconnect
var _disconnected_guids: Dictionary = {}  # {player_index: guid_string}

# Double-buffered button state for edge detection
var _prev_button_state: Dictionary = {}  # {device_id: {button: bool}}
var _curr_button_state: Dictionary = {}  # {device_id: {button: bool}}

# Edge suppression — view transitions set this to prevent false edge triggers
var _edge_suppress_frames: int = 0

# Abstract action names to JoyButton mappings
const ACTION_MAP: Dictionary = {
	&"dash": JOY_BUTTON_A,
	&"ability": JOY_BUTTON_Y,
	&"cancel": JOY_BUTTON_B,
	&"interact": JOY_BUTTON_X,
}

const PLAYSTATION_NAME_MARKERS: Array[String] = [
	"sony",
	"playstation",
	"playstation(r)",
	"dualshock",
	"dualsense",
	"wireless controller",
	"ps3",
	"ps4",
	"ps5",
]
const LOGITECH_NAME_MARKERS: Array[String] = [
	"logitech",
	"f310",
	"f510",
	"f710",
	"rumblepad",
]

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	Input.joy_connection_changed.connect(_on_joy_connection_changed)
	for device_id: int in Input.get_connected_joypads():
		_prev_button_state[device_id] = {}


func _on_joy_connection_changed(device_id: int, connected: bool) -> void:
	if connected:
		_prev_button_state[device_id] = {}
		if not _disconnected_guids.is_empty():
			var new_guid := Input.get_joy_guid(device_id)
			var matched_pi: int = -1
			for pi: int in _disconnected_guids:
				if _disconnected_guids[pi] == new_guid:
					matched_pi = pi
					break
			if matched_pi < 0:
				var oldest_pi: int = -1
				for pi: int in _disconnected_guids:
					if oldest_pi < 0 or pi < oldest_pi:
						oldest_pi = pi
				matched_pi = oldest_pi
			if matched_pi >= 0:
				_disconnected_guids.erase(matched_pi)
				device_assignments[matched_pi] = device_id
				player_device_restored.emit(matched_pi)
	else:
		var guid := Input.get_joy_guid(device_id)
		_prev_button_state.erase(device_id)
		_curr_button_state.erase(device_id)
		for player_index: int in device_assignments:
			if device_assignments[player_index] == device_id:
				device_assignments[player_index] = -1
				_disconnected_guids[player_index] = guid
				player_device_lost.emit(player_index)
				break


func _process(_delta: float) -> void:
	for device_id: int in Input.get_connected_joypads():
		if _curr_button_state.has(device_id):
			_prev_button_state[device_id] = _curr_button_state[device_id].duplicate()
		else:
			_prev_button_state[device_id] = {}

		var state: Dictionary = {}
		for button: int in range(JOY_BUTTON_MAX):
			state[button] = Input.is_joy_button_pressed(device_id, button as JoyButton)
		_curr_button_state[device_id] = state

	if _edge_suppress_frames > 0:
		_edge_suppress_frames -= 1


func assign_device(player_index: int, device_id: int) -> void:
	device_assignments[player_index] = device_id


func unassign_device(player_index: int) -> void:
	device_assignments.erase(player_index)
	_disconnected_guids.erase(player_index)


func is_player_disconnected(player_index: int) -> bool:
	return player_index in _disconnected_guids


func clear_disconnected_players() -> void:
	_disconnected_guids.clear()


func get_player_for_device(device_id: int) -> int:
	for pi: int in device_assignments:
		if device_assignments[pi] == device_id:
			return pi
	return -1


func is_assigned_device(device_id: int) -> bool:
	return get_player_for_device(device_id) >= 0


func get_device_id(player_index: int) -> int:
	return device_assignments.get(player_index, -1)


func vibrate_player(player_index: int, weak_magnitude: float = 0.22,
		strong_magnitude: float = 0.55, duration: float = 0.18) -> void:
	var device_id := get_device_id(player_index)
	if device_id < 0:
		return
	Input.start_joy_vibration(device_id, weak_magnitude, strong_magnitude, duration)


func get_assigned_player_count() -> int:
	return device_assignments.size()


func get_move_vector(player_index: int) -> Vector2:
	var device_id := get_device_id(player_index)
	if device_id < 0:
		return Vector2.ZERO
	var x := Input.get_joy_axis(device_id, JOY_AXIS_LEFT_X)
	var y := Input.get_joy_axis(device_id, JOY_AXIS_LEFT_Y)
	var vec := Vector2(x, y)
	var length := vec.length()
	if length < Constants.STICK_DEADZONE_INNER:
		return Vector2.ZERO
	var remapped := (length - Constants.STICK_DEADZONE_INNER) / (Constants.STICK_DEADZONE_OUTER - Constants.STICK_DEADZONE_INNER)
	remapped = clampf(remapped, 0.0, 1.0)
	return vec.normalized() * remapped


func get_aim_vector(player_index: int) -> Vector2:
	var device_id := get_device_id(player_index)
	if device_id < 0:
		return Vector2.RIGHT
	var x := Input.get_joy_axis(device_id, JOY_AXIS_RIGHT_X)
	var y := Input.get_joy_axis(device_id, JOY_AXIS_RIGHT_Y)
	var vec := Vector2(x, y)
	var length := vec.length()
	if length < Constants.STICK_DEADZONE_INNER:
		return Vector2.ZERO
	var remapped := (length - Constants.STICK_DEADZONE_INNER) / (Constants.STICK_DEADZONE_OUTER - Constants.STICK_DEADZONE_INNER)
	remapped = clampf(remapped, 0.0, 1.0)
	return vec.normalized() * remapped


func suppress_edge_detection(frames: int = 2) -> void:
	_edge_suppress_frames = frames


func is_menu_confirm_just_pressed(device_id: int) -> bool:
	return is_button_just_pressed_on_device(device_id, JOY_BUTTON_START)


func is_menu_back_just_pressed(device_id: int) -> bool:
	return is_button_just_pressed_on_device(device_id, JOY_BUTTON_BACK)


func is_button_just_pressed_on_device(device_id: int, button: int) -> bool:
	if _edge_suppress_frames > 0:
		return false
	if not _curr_button_state.has(device_id):
		return false
	return _get_button_pressed_for_aliases(_curr_button_state[device_id], device_id, button) \
			and not _get_button_pressed_for_aliases(_prev_button_state.get(device_id, {}), device_id, button)


func is_button_pressed_on_device(device_id: int, button: int) -> bool:
	if not _curr_button_state.has(device_id):
		return false
	return _get_button_pressed_for_aliases(_curr_button_state[device_id], device_id, button)


func is_action_just_pressed(player_index: int, action: StringName) -> bool:
	if _edge_suppress_frames > 0:
		return false
	var device_id := get_device_id(player_index)
	if device_id < 0:
		return false
	var current := _get_button_state(device_id, action)
	var previous := _get_prev_button_state(device_id, action)
	return current and not previous


func is_action_pressed(player_index: int, action: StringName) -> bool:
	var device_id := get_device_id(player_index)
	if device_id < 0:
		return false
	return _get_button_state(device_id, action)


func is_action_just_released(player_index: int, action: StringName) -> bool:
	if _edge_suppress_frames > 0:
		return false
	var device_id := get_device_id(player_index)
	if device_id < 0:
		return false
	var current := _get_button_state(device_id, action)
	var previous := _get_prev_button_state(device_id, action)
	return not current and previous


# --- Private helpers ---

func _get_button_state(device_id: int, action: StringName) -> bool:
	if not _curr_button_state.has(device_id):
		return false
	var state: Dictionary = _curr_button_state[device_id]
	var button: int = ACTION_MAP.get(action, -1)
	if button < 0:
		return false
	return _get_button_pressed_for_aliases(state, device_id, button)


func _get_prev_button_state(device_id: int, action: StringName) -> bool:
	if not _prev_button_state.has(device_id):
		return false
	var state: Dictionary = _prev_button_state[device_id]
	var button: int = ACTION_MAP.get(action, -1)
	if button < 0:
		return false
	return _get_button_pressed_for_aliases(state, device_id, button)


func _get_button_pressed_for_aliases(state: Dictionary, device_id: int, button: int) -> bool:
	for alias: int in _get_button_aliases(device_id, button):
		if state.get(alias, false):
			return true
	return false


func _get_button_aliases(device_id: int, button: int) -> Array[int]:
	var aliases: Array[int] = [button]
	if not _needs_directinput_face_aliases(device_id):
		return aliases

	var is_playstation := _is_playstation_device(device_id)
	match button:
		JOY_BUTTON_A:
			aliases.append(1)
			if is_playstation:
				aliases.append(14)
		JOY_BUTTON_B:
			aliases.append(2)
			if is_playstation:
				aliases.append(13)
		JOY_BUTTON_X:
			aliases.append(0)
			if is_playstation:
				aliases.append(15)
		JOY_BUTTON_Y:
			aliases.append(3)
			if is_playstation:
				aliases.append(12)
		JOY_BUTTON_START:
			aliases.append(9)
			if is_playstation:
				aliases.append(3)
		JOY_BUTTON_BACK:
			aliases.append(8)
			if is_playstation:
				aliases.append(0)

	var unique: Array[int] = []
	for alias: int in aliases:
		if alias >= 0 and not unique.has(alias):
			unique.append(alias)
	return unique


func _is_playstation_device(device_id: int) -> bool:
	var joy_name := Input.get_joy_name(device_id).to_lower()
	for marker: String in PLAYSTATION_NAME_MARKERS:
		if joy_name.contains(marker):
			return true
	var guid := Input.get_joy_guid(device_id).to_lower()
	if guid.contains("054c") or guid.contains("4c05"):
		return true
	return false


func _is_logitech_device(device_id: int) -> bool:
	var joy_name := Input.get_joy_name(device_id).to_lower()
	for marker: String in LOGITECH_NAME_MARKERS:
		if joy_name.contains(marker):
			return true
	return false


func _needs_directinput_face_aliases(device_id: int) -> bool:
	if Input.has_method("is_joy_known") and Input.call("is_joy_known", device_id):
		return false
	return _is_playstation_device(device_id) or _is_logitech_device(device_id)
