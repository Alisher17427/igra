extends Node3D
## A spirit that only exists on one render layer: the player's camera sees it only while
## the photo camera is raised with the matching lens (layer = 2 << lens).

const LENS_COLORS: Array[Color] = [
	Color(0.72, 0.95, 1.0),
	Color(1.0, 0.62, 0.35),
	Color(0.78, 0.6, 1.0),
]
const NAMES: Array[String] = [
	"Wandering Spirit",
	"Moss Maiden",
	"Hollow Whisper",
	"Keeper of Pines",
	"Lost Lantern",
]

@export var spirit_name: String = "Wandering Spirit"
@export_range(0, 2) var lens: int = 0
@export var wander_radius: float = 1.6
@export var respawn_delay: float = 10.0

var fade := 1.0
var home := Vector3.ZERO
var time := 0.0
var phase := 0.0
var capturable := true
var ghost_material: StandardMaterial3D
var materials: Array[StandardMaterial3D] = []
var base_alphas: Array[float] = []

@onready var body: Node3D = $Body


func _ready() -> void:
	add_to_group("spirits")
	home = global_position
	phase = randf() * TAU
	time = randf() * 10.0
	ghost_material = $Body/BodyMesh.material_override as StandardMaterial3D
	for node in find_children("*", "GeometryInstance3D", true, false):
		var mesh := node as GeometryInstance3D
		mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var mat := mesh.material_override as StandardMaterial3D
		if mat != null and not materials.has(mat):
			materials.append(mat)
			base_alphas.append(mat.albedo_color.a)
	_apply_lens()


func _process(delta: float) -> void:
	if not visible:
		return
	time += delta
	var offset := Vector3(cos(time * 0.3 + phase), 0.0, sin(time * 0.23 + phase)) * wander_radius
	global_position = home + offset + Vector3(0.0, 0.25 + sin(time * 1.2 + phase) * 0.15, 0.0)
	body.rotation.z = sin(time * 0.9 + phase) * 0.08

	var player := get_tree().get_first_node_in_group("player") as Node3D
	if player != null:
		var to_player := player.global_position - global_position
		var target_yaw := atan2(-to_player.x, -to_player.z)
		rotation.y = lerp_angle(rotation.y, target_yaw, clampf(delta * 1.5, 0.0, 1.0))
	_apply_alpha()


func is_capturable() -> bool:
	return capturable


func capture(_score: float) -> void:
	if not capturable:
		return
	capturable = false
	var tween := create_tween()
	tween.tween_property(self, "fade", 2.2, 0.1)
	tween.tween_property(self, "fade", 0.0, 1.4)
	await tween.finished
	visible = false
	await get_tree().create_timer(respawn_delay).timeout
	_respawn()


func _respawn() -> void:
	var player := get_tree().get_first_node_in_group("player") as Node3D
	var center := Vector3.ZERO if player == null else player.global_position
	var angle := randf() * TAU
	var radius := randf_range(9.0, 18.0)
	home = Vector3(
		clampf(center.x + cos(angle) * radius, -65.0, 65.0),
		0.0,
		clampf(center.z + sin(angle) * radius, -65.0, 65.0)
	)
	spirit_name = NAMES.pick_random()
	lens = randi() % LENS_COLORS.size()
	_apply_lens()
	fade = 0.0
	visible = true
	capturable = true
	var tween := create_tween()
	tween.tween_property(self, "fade", 1.0, 2.0)


func _apply_lens() -> void:
	for node in find_children("*", "GeometryInstance3D", true, false):
		var mesh := node as GeometryInstance3D
		mesh.layers = 2 << lens
	var base := LENS_COLORS[lens]
	ghost_material.albedo_color = Color(base.r, base.g, base.b, ghost_material.albedo_color.a)


func _apply_alpha() -> void:
	var flicker := 1.0 + 0.25 * sin(time * 3.1 + phase) * sin(time * 1.7)
	for i in materials.size():
		var c := materials[i].albedo_color
		c.a = clampf(base_alphas[i] * fade * flicker, 0.0, 1.0)
		materials[i].albedo_color = c
