extends Node3D
## Drops a car from the sky in front of the player once the phone call is over. The model is
## loaded straight from disk when the editor hasn't imported it yet.

signal landed
signal blackout
signal subtitle_changed(text: String)
signal night_finished

const NightData := preload("res://scripts/night_data.gd")

const MODEL_PATH := "res://models/dirty_car.glb"
const BLACKOUT_TIME := 1.6
const DREAM_DELAY := 1.0
const CAR_SCALE := 0.006
const MODEL_YAW_DEG := 0.0
const YAW_OFFSET_DEG := 90.0
const FORWARD_DISTANCE := 4.5
const DROP_HEIGHT := 45.0
const FALL_GRAVITY := 22.0
const BOUNCE_DAMPING := 0.12
const MIN_IMPACT_SPEED := 4.0
const MAX_IMPACT_SPEED := 44.0

var holder: Node3D
var thud: AudioStreamPlayer
var dream_voice: AudioStreamPlayer
var dream_text := ""
var falling := false
var has_landed := false
var blacked_out := false
var velocity_y := 0.0


func _ready() -> void:
	holder = Node3D.new()
	holder.visible = false
	add_child(holder)
	var model := _load_model()
	if model != null:
		model.rotation.y = deg_to_rad(MODEL_YAW_DEG)
		model.scale = Vector3.ONE * CAR_SCALE
		holder.add_child(model)

	thud = AudioStreamPlayer.new()
	thud.stream = _make_thud_sound()
	thud.volume_db = 2.0
	add_child(thud)

	var cfg := NightData.config()
	dream_voice = AudioStreamPlayer.new()
	dream_voice.stream = _load_mp3(cfg["dream"]["voice"])
	add_child(dream_voice)
	dream_text = cfg["dream"]["text"]

	var car_drops: bool = cfg["car_drops"]
	if not car_drops and NightData.car_saved:
		holder.transform = NightData.car_transform
		holder.visible = true

	var phone := get_node_or_null("../Player/PhoneCall")
	if phone != null:
		phone.connect(&"call_ended", drop if car_drops else _enable_ending)


func _enable_ending() -> void:
	has_landed = true
	landed.emit()


func drop() -> void:
	var player := get_node("../Player") as Node3D
	var forward := -player.global_transform.basis.z
	forward.y = 0.0
	forward = forward.normalized()
	var target := player.global_position + forward * FORWARD_DISTANCE
	holder.position = Vector3(target.x, DROP_HEIGHT, target.z)
	holder.rotation.y = atan2(-forward.x, -forward.z) + deg_to_rad(YAW_OFFSET_DEG)
	holder.visible = true
	velocity_y = 0.0
	falling = true


func _process(_delta: float) -> void:
	if has_landed and not blacked_out and Input.is_action_just_pressed("blackout"):
		blacked_out = true
		get_node("../Player").set("controls_locked", true)
		blackout.emit()
		_play_dream_line()


func _play_dream_line() -> void:
	await get_tree().create_timer(BLACKOUT_TIME).timeout
	var ambience := get_node_or_null("../Ambience") as AudioStreamPlayer
	if ambience != null:
		ambience.stop()
	await get_tree().create_timer(DREAM_DELAY).timeout
	AudioServer.set_bus_volume_db(0, 0.0)
	subtitle_changed.emit(dream_text)
	if dream_voice.stream != null:
		dream_voice.play()
		await dream_voice.finished
	else:
		await get_tree().create_timer(1.5 + dream_text.length() * 0.06).timeout
	subtitle_changed.emit("")
	night_finished.emit()


func _physics_process(delta: float) -> void:
	if not falling:
		return
	velocity_y -= FALL_GRAVITY * delta
	holder.position.y += velocity_y * delta
	if holder.position.y <= 0.0:
		holder.position.y = 0.0
		var speed := absf(velocity_y)
		if speed > MIN_IMPACT_SPEED:
			_impact(speed)
			velocity_y = speed * BOUNCE_DAMPING
		else:
			velocity_y = 0.0
			falling = false
			has_landed = true
			NightData.car_transform = holder.transform
			NightData.car_saved = true
			landed.emit()


func _impact(speed: float) -> void:
	var power := clampf(speed / MAX_IMPACT_SPEED, 0.15, 1.0)
	thud.pitch_scale = randf_range(0.92, 1.05)
	thud.volume_db = lerpf(-8.0, 2.0, power)
	thud.play()
	var player := get_node_or_null("../Player")
	if player != null:
		player.call("kick", power)


func _make_thud_sound() -> AudioStreamWAV:
	var rate := 22050
	var total := int(rate * 1.3)
	var data := PackedByteArray()
	data.resize(total * 2)
	var low := 0.0
	for i in total:
		var t := float(i) / rate
		var tone := sin(TAU * 55.0 * t * (1.0 - 0.3 * t)) * exp(-t * 4.0)
		low += (randf_range(-1.0, 1.0) - low) * 0.06
		var crunch := low * exp(-t * 8.0) * 1.8
		var sample := (tone * 0.9 + crunch) * 0.9
		data.encode_s16(i * 2, int(clampf(sample, -1.0, 1.0) * 30000.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = rate
	wav.stereo = false
	wav.data = data
	return wav


func _load_mp3(path: String) -> AudioStream:
	if ResourceLoader.exists(path):
		return load(path) as AudioStreamMP3
	if FileAccess.file_exists(path):
		var stream := AudioStreamMP3.new()
		stream.data = FileAccess.get_file_as_bytes(path)
		return stream
	return null


func _load_model() -> Node3D:
	if ResourceLoader.exists(MODEL_PATH):
		return (load(MODEL_PATH) as PackedScene).instantiate() as Node3D
	var doc := GLTFDocument.new()
	var gltf_state := GLTFState.new()
	if doc.append_from_file(ProjectSettings.globalize_path(MODEL_PATH), gltf_state) != OK:
		push_warning("Car model could not be loaded")
		return null
	return doc.generate_scene(gltf_state) as Node3D
