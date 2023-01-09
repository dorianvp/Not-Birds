extends RigidBody2D

export(float) var death_velocity = 0.0
export(float) var max_aim_distance = 200.0
export(float) var speed_modifier = 8.0

var shooting = false
var shoot_pos: Vector2

var is_grounded = false

var last_velocity: Vector2
var can_take_damage = true
export(float) var health = 100.0
var initial_health = 100.0
export(Vector2) var spawn_point = Vector2.ZERO

onready var aim_pointer: Sprite = $aim_pointer
onready var hitbox: Area2D = $aim_area
onready var grounded_area: Area2D = $grounded_area
onready var max_cursor_scale = aim_pointer.scale

onready var signal_manager = $"/root/SignalManager"
onready var state_manager = $"/root/StateManager"

# length_squared() is more efficient than length(),
# so we square death_velocity too
func _ready():
	death_velocity *= death_velocity
	spawn_point = global_position
	signal_manager.connect("change_spawnpoint", self, "change_spawnpoint")
	signal_manager.connect("respawn_player", self, "_on_respawn")

func _physics_process(_delta):
	last_velocity = linear_velocity

# Prevent the character from rotating
func _integrate_forces(_state):
	rotation = 0
	angular_velocity = 0.0
	pass
	

func set_shooting(var value: bool):
	shooting = value
	aim_pointer.visible = value
	if value:
		Input.set_mouse_mode(Input.MOUSE_MODE_HIDDEN)
	else:
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

func _input(event):
	if event is InputEventMouseButton && shooting && (is_grounded || mode == RigidBody2D.MODE_KINEMATIC):
		if event.button_index == BUTTON_LEFT && !event.pressed:
			throw_not_bird()
			set_shooting(false)
	elif event is InputEventMouseMotion && shooting:
		shoot_pos = get_global_mouse_position() - global_position
		shoot_pos = shoot_pos.normalized() * clamp(shoot_pos.length(), 0, max_aim_distance)
		var pointer_scale = shoot_pos.length() / max_aim_distance
		aim_pointer.scale = max_cursor_scale * log((1+pointer_scale)*3.0)
		aim_pointer.global_position = shoot_pos + global_position

func throw_not_bird():
	mode = RigidBody2D.MODE_RIGID
	var speed = -shoot_pos
	apply_central_impulse(speed * speed_modifier)
	#if state_manager.fighting: # Only take damage when fighting
	set_health(health - 10)

# Detect when the player starts to aim
func _on_aim_area_input_event(_viewport: Node, event: InputEvent, _shape_idx: int):
	if event is InputEventMouseButton:
		var is_still = linear_velocity.length_squared() < 500.0
		if event.button_index == BUTTON_LEFT && event.pressed && is_still:
			set_shooting(true)

func _on_grounded_area_body_entered(_body):
	is_grounded = grounded_area.get_overlapping_bodies().size() > 0

func _on_grounded_area_body_exited(_body):
	is_grounded = grounded_area.get_overlapping_bodies().size() > 0

func set_health(value: float):
	health = value
	signal_manager.emit_signal("player_damaged", health)
	if health <= 0:
		respawn()
		set_health(initial_health)

func respawn():
	mode = RigidBody2D.MODE_KINEMATIC
	global_transform.origin = spawn_point
	reset_physics_interpolation()

func _on_respawn():
	call_deferred("respawn")

# When touching a checkpoint
func change_spawnpoint(value: Vector2):
	spawn_point = value

func _on_rbBird_body_entered(body):
	if body is StaticBody2D:
		if body.get_collision_layer_bit(4):
			call_deferred("set_health", 0)