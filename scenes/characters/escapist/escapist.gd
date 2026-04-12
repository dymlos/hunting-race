class_name Escapist
extends BaseCharacter

signal died(escapist: Escapist)
signal scored(escapist: Escapist)

var is_dead: bool = false
var has_scored: bool = false
var spawn_position: Vector2 = Vector2.ZERO

# Poison system
var poison: PoisonComponent

# Control inversion
var controls_inverted: bool = false
var _inversion_timer: float = 0.0


func _setup_role() -> void:
	role = Enums.Role.ESCAPIST
	movement.move_speed = Constants.SPEED_ESCAPIST
	movement.crushed.connect(_on_crushed)

	# Setup poison component
	poison = PoisonComponent.new()
	poison.setup(self)
	poison.poison_expired.connect(_on_poison_expired)
	add_child(poison)


func _ready() -> void:
	super._ready()
	spawn_position = position


func kill() -> void:
	if is_dead or has_scored:
		return
	is_dead = true
	input_locked = true
	movement.freeze()
	visible = false
	died.emit(self)


func _on_poison_expired() -> void:
	respawn()


func invert_controls(duration: float) -> void:
	controls_inverted = true
	_inversion_timer = duration


func _physics_process(delta: float) -> void:
	if _inversion_timer > 0.0:
		_inversion_timer -= delta
		if _inversion_timer <= 0.0:
			controls_inverted = false
	super._physics_process(delta)


func respawn() -> void:
	if is_dead or has_scored:
		return
	position = spawn_position
	movement.velocity = Vector2.ZERO
	movement.slippery = false
	movement.clear_speed_modifiers()
	controls_inverted = false
	_inversion_timer = 0.0
	if poison.is_poisoned:
		poison.cure()


func _on_crushed() -> void:
	if is_dead or has_scored:
		return
	position = spawn_position
	movement.velocity = Vector2.ZERO
	movement.slippery = false
	movement.clear_speed_modifiers()


func score() -> void:
	if is_dead or has_scored:
		return
	has_scored = true
	input_locked = true
	movement.freeze()
	visible = false
	scored.emit(self)


func _draw() -> void:
	var draw_color := player_color

	# Poison tint
	if poison and poison.is_poisoned:
		var pulse := 0.5 + 0.5 * sin(Time.get_ticks_msec() / 200.0)
		draw_color = draw_color.lerp(Color(0.2, 0.9, 0.1), 0.4 + 0.2 * pulse)

	# Inverted controls indicator
	if controls_inverted:
		draw_color = draw_color.lerp(Color(1.0, 0.0, 1.0), 0.3)

	# Circle with ring
	draw_circle(Vector2.ZERO, Constants.CHARACTER_RADIUS - 2.0, draw_color)
	draw_arc(Vector2.ZERO, Constants.CHARACTER_RADIUS + 2.0, 0, TAU, 16,
		draw_color, 1.5)

	# Direction indicator
	var tip := aim_direction * (Constants.CHARACTER_RADIUS + 8.0)
	draw_line(Vector2.ZERO, tip, draw_color, 2.0)

	# Label
	var label := "P%d" % (player_index + 1)
	if player_index >= 100:
		label = "BOT"
	draw_string(ThemeDB.fallback_font, Vector2(-10, -Constants.CHARACTER_RADIUS - 6),
		label, HORIZONTAL_ALIGNMENT_CENTER, -1, 10, draw_color)
	draw_string(ThemeDB.fallback_font, Vector2(-10, Constants.CHARACTER_RADIUS + 14),
		"ESC", HORIZONTAL_ALIGNMENT_CENTER, -1, 8, draw_color)

	# Poison timer indicator
	if poison and poison.is_poisoned:
		var ratio := poison.get_timer_ratio()
		draw_arc(Vector2.ZERO, Constants.CHARACTER_RADIUS + 5.0,
			-PI / 2.0, -PI / 2.0 + TAU * ratio, 12,
			Color(0.2, 0.9, 0.1, 0.6), 2.0)
