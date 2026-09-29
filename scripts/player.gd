extends CharacterBody3D

const SPEED = 2.5
const SPRINT_SPEED = 4.0
const JUMP_VELOCITY = 4.5
const MOUSE_SENSITIVITY = 0.003

const BOB_FREQUENCY := 1.5
const BOB_AMPLITUDE_Y := 0.035
const SWAY_AMPLITUDE_X := 0.03
const SWAY_ROLL_DEG := 1.6
const BOB_SMOOTH_SPEED := 5.0

var footstep_sounds: Array[AudioStream] = [
	preload("res://audio/footsteps/grass_step_1.mp3"),
	preload("res://audio/footsteps/grass_step_2.mp3"),
	preload("res://audio/footsteps/grass_step_3.mp3"),
]

var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var bob_time := 0.0
var bob_intensity := 0.0
var last_footstep_index := -1
var prev_bob_y := 0.0
var prev_bob_rising := false

@onready var camera: Camera3D = $Camera3D
@onready var camera_base_pos: Vector3 = camera.position
@onready var footsteps: AudioStreamPlayer = $Footsteps


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		rotate_y(-event.relative.x * MOUSE_SENSITIVITY)
		camera.rotate_x(-event.relative.y * MOUSE_SENSITIVITY)
		camera.rotation.x = clamp(camera.rotation.x, deg_to_rad(-80), deg_to_rad(80))
	if event.is_action_pressed("ui_cancel"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED else Input.MOUSE_MODE_CAPTURED


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= gravity * delta

	if Input.is_action_just_pressed("ui_accept") and is_on_floor():
		velocity.y = JUMP_VELOCITY

	var input_dir := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var direction := (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	var current_speed := SPRINT_SPEED if Input.is_action_pressed("sprint") else SPEED

	if direction:
		velocity.x = direction.x * current_speed
		velocity.z = direction.z * current_speed
	else:
		velocity.x = move_toward(velocity.x, 0, current_speed)
		velocity.z = move_toward(velocity.z, 0, current_speed)

	move_and_slide()

	var forward_speed := absf(input_dir.y) * current_speed
	bob_time += delta * forward_speed * float(is_on_floor())
	var target_intensity: float = clamp(forward_speed / SPRINT_SPEED, 0.0, 1.0)
	bob_intensity = move_toward(bob_intensity, target_intensity, delta * BOB_SMOOTH_SPEED)

	camera.position = camera_base_pos + _head_bob(bob_time, bob_intensity)
	camera.rotation.z = sin(bob_time * BOB_FREQUENCY) * deg_to_rad(SWAY_ROLL_DEG) * bob_intensity

	var bob_y := absf(sin(bob_time * BOB_FREQUENCY))
	var rising := bob_y > prev_bob_y
	if prev_bob_rising and not rising and bob_intensity > 0.05 and is_on_floor():
		_play_footstep()
	prev_bob_y = bob_y
	prev_bob_rising = rising


func _head_bob(time: float, intensity: float) -> Vector3:
	var offset := Vector3.ZERO
	offset.y = abs(sin(time * BOB_FREQUENCY)) * BOB_AMPLITUDE_Y * intensity
	offset.x = sin(time * BOB_FREQUENCY) * SWAY_AMPLITUDE_X * intensity
	return offset


func _play_footstep() -> void:
	var index := randi() % footstep_sounds.size()
	if footstep_sounds.size() > 1:
		while index == last_footstep_index:
			index = randi() % footstep_sounds.size()
	last_footstep_index = index
	footsteps.stream = footstep_sounds[index]
	footsteps.pitch_scale = randf_range(0.92, 1.1)
	footsteps.play()
