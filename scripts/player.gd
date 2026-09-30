extends CharacterBody3D

signal aim_changed(aiming: bool)
signal lens_changed(lens_index: int)
signal frame_lock_changed(locked: bool)
signal photo_taken(report: Array, film: int)
signal out_of_film
signal film_reloaded(film: int)

const SPEED = 2.5
const SPRINT_SPEED = 4.0
const JUMP_VELOCITY = 4.5
const MOUSE_SENSITIVITY = 0.003

const BOB_FREQUENCY := 1.5
const BOB_AMPLITUDE_Y := 0.035
const SWAY_AMPLITUDE_X := 0.03
const SWAY_ROLL_DEG := 1.6
const BOB_SMOOTH_SPEED := 5.0

const FOV_NORMAL := 75.0
const FOV_AIM := 40.0
const AIM_SPEED_MULT := 0.5
const RAISE_TIME := 0.3
const AIM_READY := 0.9
const RAISED_POS := Vector3(0.06, -0.025, -0.3)
const MODEL_SCALE := 0.45
const RAISED_YAW_DEG := 90.0
const SWAY_PER_PIXEL := 0.0025
const SWAY_MAX := 0.14
const SWAY_RETURN := 7.0
const SWAY_POS_GAIN := 0.3
const HAND_SWAY_X := 0.022
const HAND_BOB_Y := 0.02
const HAND_ROLL_DEG := 3.0
const HAND_PHASE := 0.7

const ALL_LAYERS := 1048575
const SPIRIT_LAYERS := 14
const LENS_COUNT := 3
const FRAME_HALF := Vector2(0.22, 0.22)
const CAPTURE_MAX_DIST := 30.0
const MAX_FILM := 24
const SHOT_COOLDOWN := 1.0
const RELOAD_TIME := 5.0

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

@export var movement_enabled := false
var controls_locked := false
var shake := 0.0
var sway := Vector2.ZERO
var aiming := false
var raise_t := 0.0
var hold_xform := Transform3D.IDENTITY
var raised_xform := Transform3D.IDENTITY
var current_lens := 0
var frame_locked := false
var film_left := MAX_FILM
var shot_cooldown := 0.0
var reload_timer := 0.0
var shutter_player: AudioStreamPlayer

@onready var camera: Camera3D = $Camera3D
@onready var camera_base_pos: Vector3 = camera.position
@onready var footsteps: AudioStreamPlayer = $Footsteps
@onready var camera_model: Node3D = $Camera3D/CameraModel


func _ready() -> void:
	add_to_group("player")
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_update_cull_mask()
	hold_xform = camera_model.transform
	var raised_basis := Basis(Vector3.UP, deg_to_rad(RAISED_YAW_DEG)).scaled(Vector3.ONE * MODEL_SCALE)
	raised_xform = Transform3D(raised_basis, RAISED_POS)
	shutter_player = AudioStreamPlayer.new()
	shutter_player.stream = _make_shutter_sound()
	shutter_player.volume_db = -6.0
	add_child(shutter_player)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var sensitivity := MOUSE_SENSITIVITY * (camera.fov / FOV_NORMAL)
		rotate_y(-event.relative.x * sensitivity)
		camera.rotate_x(-event.relative.y * sensitivity)
		camera.rotation.x = clamp(camera.rotation.x, deg_to_rad(-80), deg_to_rad(80))
		sway -= event.relative * SWAY_PER_PIXEL
		sway = sway.clampf(-SWAY_MAX, SWAY_MAX)
	if event.is_action_pressed("ui_cancel"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED else Input.MOUSE_MODE_CAPTURED


func _physics_process(delta: float) -> void:
	var want_aim := Input.is_action_pressed("camera_aim") and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and not controls_locked
	raise_t = move_toward(raise_t, 1.0 if want_aim else 0.0, delta / RAISE_TIME)
	_set_aiming(want_aim and raise_t >= AIM_READY)

	if not is_on_floor():
		velocity.y -= gravity * delta

	if Input.is_action_just_pressed("ui_accept") and is_on_floor() and movement_enabled and not controls_locked:
		velocity.y = JUMP_VELOCITY

	var can_move := movement_enabled and not controls_locked
	var input_dir := Input.get_vector("move_left", "move_right", "move_forward", "move_back") if can_move else Vector2.ZERO
	var direction := (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	var base_speed := SPRINT_SPEED if Input.is_action_pressed("sprint") and raise_t < 0.05 else SPEED
	var current_speed: float = base_speed * lerpf(1.0, AIM_SPEED_MULT, raise_t)

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
	if shake > 0.001:
		camera.position += Vector3(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0), 0.0) * shake * 0.06
		camera.rotation.z += randf_range(-1.0, 1.0) * shake * 0.05
		shake = move_toward(shake, 0.0, delta * 1.4)

	var bob_y := absf(sin(bob_time * BOB_FREQUENCY))
	var rising := bob_y > prev_bob_y
	if prev_bob_rising and not rising and bob_intensity > 0.05 and is_on_floor():
		_play_footstep()
	prev_bob_y = bob_y
	prev_bob_rising = rising

	_update_camera(delta)


func kick(power: float) -> void:
	shake = maxf(shake, power)


func _update_camera(delta: float) -> void:
	var eased := smoothstep(0.0, 1.0, raise_t)
	camera.fov = lerpf(FOV_NORMAL, FOV_AIM, eased)
	var model_xform := hold_xform.interpolate_with(raised_xform, eased)
	sway = sway.lerp(Vector2.ZERO, 1.0 - exp(-SWAY_RETURN * delta))
	var hand_sway := sway * (1.0 - raise_t)
	model_xform.basis = Basis.from_euler(Vector3(-hand_sway.y, -hand_sway.x, 0.0)) * model_xform.basis
	model_xform.origin += Vector3(hand_sway.x, -hand_sway.y, 0.0) * SWAY_POS_GAIN

	var walk_side := sin(bob_time * BOB_FREQUENCY - HAND_PHASE)
	var walk_scale := bob_intensity * (1.0 - raise_t)
	var walk_roll := -walk_side * deg_to_rad(HAND_ROLL_DEG) * walk_scale
	model_xform.basis = Basis.from_euler(Vector3(0.0, 0.0, walk_roll)) * model_xform.basis
	model_xform.origin += Vector3(walk_side * HAND_SWAY_X, -absf(walk_side) * HAND_BOB_Y, 0.0) * walk_scale
	camera_model.transform = model_xform
	camera_model.visible = not aiming

	shot_cooldown = maxf(0.0, shot_cooldown - delta)
	if reload_timer > 0.0:
		reload_timer -= delta
		if reload_timer <= 0.0:
			film_left = MAX_FILM
			film_reloaded.emit(film_left)

	if not aiming:
		return

	if Input.is_action_just_pressed("lens_next"):
		_cycle_lens(1)
	elif Input.is_action_just_pressed("lens_prev"):
		_cycle_lens(-1)

	var locked := not _spirits_in_frame().is_empty()
	if locked != frame_locked:
		frame_locked = locked
		frame_lock_changed.emit(locked)

	if Input.is_action_just_pressed("camera_shoot") and shot_cooldown <= 0.0 and film_left > 0:
		_take_photo()


func _set_aiming(value: bool) -> void:
	if value == aiming:
		return
	aiming = value
	_update_cull_mask()
	aim_changed.emit(aiming)
	if not aiming and frame_locked:
		frame_locked = false
		frame_lock_changed.emit(false)


func _cycle_lens(step: int) -> void:
	current_lens = posmod(current_lens + step, LENS_COUNT)
	_update_cull_mask()
	lens_changed.emit(current_lens)


func _update_cull_mask() -> void:
	var mask := ALL_LAYERS & ~SPIRIT_LAYERS
	if aiming:
		mask |= 2 << current_lens
	camera.cull_mask = mask


func _spirits_in_frame() -> Array:
	var found: Array = []
	var vp_size := camera.get_viewport().get_visible_rect().size
	for node in get_tree().get_nodes_in_group("spirits"):
		var spirit := node as Node3D
		if spirit == null or not spirit.call("is_capturable"):
			continue
		if int(spirit.get("lens")) != current_lens:
			continue
		var target := spirit.global_position + Vector3(0.0, float(spirit.get("aim_height")), 0.0)
		if camera.is_position_behind(target):
			continue
		var dist := camera.global_position.distance_to(target)
		if dist > CAPTURE_MAX_DIST:
			continue
		var offset := (camera.unproject_position(target) - vp_size * 0.5) / vp_size
		if absf(offset.x) > FRAME_HALF.x or absf(offset.y) > FRAME_HALF.y:
			continue
		var centered := 1.0 - clampf(offset.length() / FRAME_HALF.length(), 0.0, 1.0)
		var closeness := 1.0 - clampf(dist / CAPTURE_MAX_DIST, 0.0, 1.0)
		found.append({
			"node": spirit,
			"name": spirit.get("spirit_name"),
			"kind": spirit.get("kind"),
			"note": spirit.get("note"),
			"score": clampf(0.7 * centered + 0.3 * closeness, 0.0, 1.0),
		})
	return found


func _take_photo() -> void:
	film_left -= 1
	shot_cooldown = SHOT_COOLDOWN
	shutter_player.play()
	var report: Array = []
	for entry in _spirits_in_frame():
		var spirit := entry["node"] as Node3D
		spirit.call("capture", entry["score"])
		report.append({"name": entry["name"], "score": entry["score"], "kind": entry["kind"], "note": entry["note"]})
	photo_taken.emit(report, film_left)
	if film_left <= 0:
		reload_timer = RELOAD_TIME
		out_of_film.emit()


func _make_shutter_sound() -> AudioStreamWAV:
	var rate := 22050
	var total := int(rate * 0.16)
	var data := PackedByteArray()
	data.resize(total * 2)
	for i in total:
		var t := float(i) / rate
		var env := 0.0
		if t < 0.05:
			env = exp(-t * 90.0)
		elif t >= 0.09:
			env = exp(-(t - 0.09) * 70.0) * 0.7
		var sample := randf_range(-1.0, 1.0) * env
		data.encode_s16(i * 2, int(clampf(sample, -1.0, 1.0) * 30000.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = rate
	wav.stereo = false
	wav.data = data
	return wav


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
