extends Node
## After the third captured spirit the phone rings; F answers. Model and ringtone are loaded
## straight from disk when the editor hasn't imported them yet.

signal ring_started
signal answered
signal subtitle_changed(text: String)
signal choice_requested
signal choice_made(answer: String)
signal call_ended

enum State { IDLE, WAITING, RINGING, ANSWERED, DONE }

const SPIRITS_NEEDED := 3
const RING_DELAY := 2.5
const MODEL_PATH := "res://models/motorola_razr_cell_phone.glb"
const RING_PATH := "res://audio/ringtone_razr.mp3"
const VOICE_PATH := "res://audio/call_voice.mp3"
const PICKUP_PATH := "res://audio/phone_pickup.mp3"
const YES_PATH := "res://audio/call_yes.mp3"
const NO_PATH := "res://audio/call_no.mp3"
const VOICE_DELAY := 1.0
const VOICE_SUBTITLE := "You're done with the ghosts?"
const YES_SUBTITLE := "Alright, hop in the car."
const NO_SUBTITLE := "Please don't lie to me."
const PHONE_SCALE := 0.4
const MODEL_CENTER := Vector3(0.0, -0.27, 0.0)
const HOLD_POS := Vector3(-0.2, -0.15, -0.42)
const HOLD_ROT_DEG := Vector3(35.0, 200.0, 0.0)
const EAR_POS := Vector3(-0.2, 0.02, -0.16)
const EAR_ROT_DEG := Vector3(10.0, 250.0, -25.0)

var state := State.IDLE
var total_captured := 0
var time := 0.0
var show_t := 0.0
var ear_t := 0.0
var holder: Node3D
var ringtone: AudioStreamPlayer
var voice: AudioStreamPlayer
var pickup: AudioStreamPlayer
var yes_voice: AudioStreamPlayer
var no_voice: AudioStreamPlayer
var player: Node3D
var waiting_choice := false
var answer_choice := ""
var hold_xform := Transform3D.IDENTITY
var ear_xform := Transform3D.IDENTITY


func _ready() -> void:
	player = get_parent() as Node3D
	hold_xform = Transform3D(Basis.from_euler(_deg_to_rad_vec(HOLD_ROT_DEG)), HOLD_POS)
	ear_xform = Transform3D(Basis.from_euler(_deg_to_rad_vec(EAR_ROT_DEG)), EAR_POS)

	holder = Node3D.new()
	holder.visible = false
	var model := _load_model()
	if model != null:
		model.position = MODEL_CENTER
		holder.add_child(model)
	player.get_node("Camera3D").add_child.call_deferred(holder)

	ringtone = AudioStreamPlayer.new()
	ringtone.stream = _load_mp3(RING_PATH, true)
	ringtone.volume_db = -4.0
	add_child(ringtone)

	voice = AudioStreamPlayer.new()
	voice.stream = _load_mp3(VOICE_PATH, false)
	voice.volume_db = -2.0
	add_child(voice)

	pickup = AudioStreamPlayer.new()
	pickup.stream = _load_mp3(PICKUP_PATH, false)
	add_child(pickup)

	yes_voice = AudioStreamPlayer.new()
	yes_voice.stream = _load_mp3(YES_PATH, false)
	yes_voice.volume_db = -2.0
	add_child(yes_voice)

	no_voice = AudioStreamPlayer.new()
	no_voice.stream = _load_mp3(NO_PATH, false)
	no_voice.volume_db = -2.0
	add_child(no_voice)

	player.connect(&"photo_taken", _on_photo_taken)


func _process(delta: float) -> void:
	time += delta
	if state == State.RINGING and Input.is_action_just_pressed("answer_phone"):
		_answer()

	var aiming_away := float(player.get("raise_t")) > 0.5
	var phone_out := (state == State.RINGING or state == State.ANSWERED) and not aiming_away
	show_t = move_toward(show_t, 1.0 if phone_out else 0.0, delta / 0.35)
	ear_t = move_toward(ear_t, 1.0 if state == State.ANSWERED else 0.0, delta / 0.5)
	holder.visible = show_t > 0.01

	var xf := hold_xform.interpolate_with(ear_xform, smoothstep(0.0, 1.0, ear_t))
	xf.origin.y -= (1.0 - smoothstep(0.0, 1.0, show_t)) * 0.4
	if state == State.RINGING:
		xf.origin += Vector3(sin(time * 70.0), cos(time * 83.0), 0.0) * 0.004
		xf.basis = Basis.from_euler(Vector3(0.0, 0.0, sin(time * 60.0) * 0.05)) * xf.basis
	xf.basis = xf.basis.scaled(Vector3.ONE * PHONE_SCALE)
	holder.transform = xf


func _on_photo_taken(report: Array, _film: int) -> void:
	total_captured += report.size()
	if state == State.IDLE and total_captured >= SPIRITS_NEEDED:
		state = State.WAITING
		await get_tree().create_timer(RING_DELAY).timeout
		_start_ringing()


func _start_ringing() -> void:
	state = State.RINGING
	ringtone.play()
	ring_started.emit()


func _answer() -> void:
	state = State.ANSWERED
	ringtone.stop()
	pickup.play()
	answered.emit()
	await get_tree().create_timer(VOICE_DELAY).timeout
	if voice.stream != null:
		voice.play()
		subtitle_changed.emit(VOICE_SUBTITLE)
		await voice.finished
		subtitle_changed.emit("")
	player.set("controls_locked", true)
	waiting_choice = true
	choice_requested.emit()


func submit_choice(answer: String) -> void:
	if not waiting_choice:
		return
	waiting_choice = false
	answer_choice = answer
	player.set("controls_locked", false)
	choice_made.emit(answer)
	var reply := yes_voice if answer == "Yes" else no_voice
	var reply_text := YES_SUBTITLE if answer == "Yes" else NO_SUBTITLE
	if reply.stream != null:
		reply.play()
		subtitle_changed.emit(reply_text)
		await reply.finished
		subtitle_changed.emit("")
	else:
		await get_tree().create_timer(1.2).timeout
	state = State.DONE
	call_ended.emit()


func _deg_to_rad_vec(v: Vector3) -> Vector3:
	return Vector3(deg_to_rad(v.x), deg_to_rad(v.y), deg_to_rad(v.z))


func _load_model() -> Node3D:
	if ResourceLoader.exists(MODEL_PATH):
		return (load(MODEL_PATH) as PackedScene).instantiate() as Node3D
	var doc := GLTFDocument.new()
	var gltf_state := GLTFState.new()
	if doc.append_from_file(ProjectSettings.globalize_path(MODEL_PATH), gltf_state) != OK:
		push_warning("Phone model could not be loaded")
		return null
	return doc.generate_scene(gltf_state) as Node3D


func _load_mp3(path: String, loop: bool) -> AudioStream:
	var stream: AudioStreamMP3
	if ResourceLoader.exists(path):
		stream = load(path) as AudioStreamMP3
	else:
		stream = AudioStreamMP3.new()
		stream.data = FileAccess.get_file_as_bytes(path)
	stream.loop = loop
	return stream
