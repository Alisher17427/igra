extends Node
## Wraps the level in the PSX low-res/dither screen and runs the sequence of nights.
## Material conversion (PSX.convert) is skipped: the Free addon only ships the "lit" shader,
## which can't handle the vegetation pack's alpha-cutout foliage cards.

const PSXScreenScript := preload("res://addons/psx_look/psx_screen.gd")
const HudScript := preload("res://scripts/hud.gd")
const NightData := preload("res://scripts/night_data.gd")
const ClueScript := preload("res://scripts/clue.gd")
const TrailScript := preload("res://scripts/trail.gd")
const ForestScene := preload("res://scenes/forest_scene.tscn")

const TITLE_TIME := 3.0
const FADE_IN_TIME := 1.6

var psx: SubViewportContainer
var hud: CanvasLayer
var level: Node


func _ready() -> void:
	psx = PSXScreenScript.new()
	add_child(psx)
	hud = HudScript.new()
	add_child(hud)
	_start_night()
	_choose_language()


func _choose_language() -> void:
	var player := level.get_node("Player")
	player.set("controls_locked", true)
	hud.call("show_language_menu")
	await Signal(hud, &"language_chosen")
	player.set("controls_locked", false)


func _start_night() -> void:
	level = ForestScene.instantiate()
	psx.viewport.add_child(level)
	_apply_night(level, NightData.config())
	hud.call("bind_player", level.get_node("Player"))
	level.get_node("CarDrop").connect(&"night_finished", _on_night_finished)
	hud.call("set_hint", NightData.config()["hint"])
	if NightData.current_night > 1:
		hud.call("fade_in", FADE_IN_TIME)


func _on_night_finished() -> void:
	if NightData.has_next():
		hud.call("show_title", NightData.NIGHTS[NightData.current_night + 1]["title"])
		await get_tree().create_timer(TITLE_TIME).timeout
		NightData.current_night += 1
		level.queue_free()
		await get_tree().process_frame
		_start_night()
		hud.call("hide_title")
	else:
		hud.call("show_title", "THE END")


func _apply_night(root: Node, cfg: Dictionary) -> void:
	var player := root.get_node("Player")
	player.set("movement_enabled", cfg["movement"])

	var spirit_nodes := root.get_node("Spirits").get_children()
	var spirit_data: Array = cfg["spirits"]
	for i in mini(spirit_nodes.size(), spirit_data.size()):
		var entry: Dictionary = spirit_data[i]
		spirit_nodes[i].call("configure", entry["pos"], entry["lens"], entry["name"])

	if cfg.has("ambience"):
		_swap_ambience(root, cfg["ambience"])

	var clues: Array = cfg.get("clues", [])
	for entry in clues:
		var clue: Node3D = ClueScript.new()
		clue.call("setup", entry["pos"], entry["lens"], entry["name"], entry["note"], entry["shape"])
		root.add_child(clue)

	if cfg.has("trail"):
		var trail_cfg: Dictionary = cfg["trail"]
		var trail: Node3D = TrailScript.new()
		trail.call("setup", trail_cfg["points"], trail_cfg["lens"])
		root.add_child(trail)

	var darkness: float = cfg["darkness"]
	if darkness > 0.0:
		_apply_darkness(root, darkness)


func _swap_ambience(root: Node, path: String) -> void:
	var stream: AudioStreamMP3
	if ResourceLoader.exists(path):
		stream = load(path) as AudioStreamMP3
	elif FileAccess.file_exists(path):
		stream = AudioStreamMP3.new()
		stream.data = FileAccess.get_file_as_bytes(path)
	else:
		return
	stream.loop = true
	var ambience := root.get_node("Ambience") as AudioStreamPlayer
	ambience.stream = stream
	ambience.play()


func _apply_darkness(root: Node, d: float) -> void:
	var env := (root.get_node("WorldEnvironment") as WorldEnvironment).environment
	var sky_material := env.sky.sky_material as ShaderMaterial
	sky_material.set_shader_parameter("sky_top_color", Color(0.34, 0.52, 0.78).lerp(Color(0.02, 0.035, 0.09), d))
	sky_material.set_shader_parameter("sky_horizon_color", Color(0.72, 0.78, 0.73).lerp(Color(0.07, 0.09, 0.14), d))
	sky_material.set_shader_parameter("ground_color", Color(0.24, 0.22, 0.16).lerp(Color(0.02, 0.03, 0.04), d))
	sky_material.set_shader_parameter("cloud_color", Color.WHITE.lerp(Color(0.16, 0.2, 0.3), d))
	env.fog_light_color = Color(0.72, 0.78, 0.73).lerp(Color(0.05, 0.08, 0.12), d)
	env.fog_density = lerpf(0.015, 0.03, d)
	env.ambient_light_energy = lerpf(1.0, 0.65, d)
	env.tonemap_exposure = lerpf(1.3, 1.25, d)
	var sun := root.get_node("Sun") as DirectionalLight3D
	sun.light_energy = lerpf(1.6, 0.45, d)
	sun.light_color = Color(1.0, 0.95, 0.85).lerp(Color(0.55, 0.68, 1.0), d)
