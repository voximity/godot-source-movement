extends CharacterBody3D


const SPEED = 5.0
const JUMP_VELOCITY = 5.5
const SENSITIVITY = 0.002

# TODO: what should these values accurately be?
const ACCELERATE = 1.0
const AIR_ACCELERATE = 100.0
const MAX_VELOCITY = 50.0
const MAX_AIR_VELOCITY = 10000000000.0
const FRICTION = 6.0

var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var mouse_captured: bool = true
var was_grounded: bool = false

func capture_mouse(value: bool) -> void:
	mouse_captured = value
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED if value else Input.MOUSE_MODE_VISIBLE)

func _ready() -> void:
	capture_mouse(true)

func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and mouse_captured:
		rotate_y(-event.relative.x * SENSITIVITY)
		$Camera3D.rotate_x(-event.relative.y * SENSITIVITY)
		$Camera3D.rotation.x = clamp($Camera3D.rotation.x, -PI / 2, PI / 2)

	if Input.is_action_just_pressed('ui_cancel'):
		capture_mouse(not mouse_captured)

func _physics_process(delta: float) -> void:
	var prev_velocity = velocity
	
	# control the timer based on movement
	$Camera3D/StepSound/Timer.paused = velocity.length() < 2.0 or not is_on_floor()

	# play a step sound when landing
	if not was_grounded and is_on_floor():
		$Camera3D/StepSound.play()

	was_grounded = is_on_floor()
	
	var input_dir := Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
	var direction := (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()

	if is_on_floor(): velocity = move_ground(direction, prev_velocity, delta)
	else: velocity = move_air(direction, prev_velocity, delta)

	if not is_on_floor(): velocity.y -= gravity * delta
	if Input.is_action_pressed("jump") and is_on_floor():
		velocity.y = JUMP_VELOCITY

	move_and_slide()
	$SpeedLabel.text = "%.02f" % velocity.length()

	# teleport when falling beneath level
	if global_position.y < -20:
		global_position = Vector3(0, 10, 0)
		velocity = Vector3.ZERO

func air_accelerate(velocity: Vector3, wish_dir: Vector3, wish_speed: float, accel: float, air_cap: float, delta: float) -> Vector3:
	wish_speed = min(wish_speed, air_cap)
	var current_speed = velocity.dot(wish_dir)
	var add_speed = wish_speed - current_speed
	if add_speed <= 0: return Vector3.ZERO

	var accel_speed = min(accel * wish_speed * delta, add_speed)
	#var fixed = wish_dir * accel_speed
	#return Vector3(fixed.x, velocity.y, fixed.z)
	return wish_dir * accel_speed

func accelerate(velocity: Vector3, wish_dir: Vector3, wish_speed: float, accel: float, delta: float, surface_friction: float) -> Vector3:
	var current_speed = velocity.dot(wish_dir)
	var add_speed = wish_speed - current_speed
	if add_speed <= 0: return Vector3.ZERO

	var accel_speed = min(accel * delta * wish_speed * surface_friction, add_speed)
	#var fixed = wish_dir * accel_speed
	#return Vector3(fixed.x, velocity.y, fixed.z)
	return wish_dir * accel_speed

func move_ground(direction: Vector3, prev_velocity: Vector3, delta: float) -> Vector3:
	var speed = prev_velocity.length()
	if speed != 0:
		var drop = speed * FRICTION * delta
		prev_velocity *= max(speed - drop, 0) / speed

	return prev_velocity + accelerate(prev_velocity, direction, MAX_VELOCITY, ACCELERATE, delta, 1.0)

func move_air(direction: Vector3, prev_velocity: Vector3, delta: float) -> Vector3:
	return prev_velocity + air_accelerate(prev_velocity, direction, MAX_AIR_VELOCITY, AIR_ACCELERATE, 1.0, delta)
