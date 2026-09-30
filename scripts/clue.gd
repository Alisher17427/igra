extends Node3D
## A belonging of the missing daughter, visible only through its lens. Photograph it to find it.

const LENS_COLORS: Array[Color] = [
	Color(0.72, 0.95, 1.0),
	Color(1.0, 0.62, 0.35),
	Color(0.78, 0.6, 1.0),
]
const BASE_ALPHA := 0.6

var spirit_name := "Clue"
var note := ""
var lens := 0
var kind := "clue"
var aim_height := 0.4
var shape := "backpack"
var capturable := true
var fade := 1.0
var time := 0.0
var phase := 0.0
var home := Vector3.ZERO
var spins := true
var material: StandardMaterial3D


func setup(pos: Vector3, new_lens: int, new_name: String, new_note: String, new_shape: String) -> void:
	position = pos
	lens = new_lens
	spirit_name = new_name
	note = new_note
	shape = new_shape


func _ready() -> void:
	add_to_group("spirits")
	home = position
	phase = randf() * TAU
	material = StandardMaterial3D.new()
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	var base := LENS_COLORS[lens]
	material.albedo_color = Color(base.r, base.g, base.b, BASE_ALPHA)
	_build()


func _process(delta: float) -> void:
	if not visible:
		return
	time += delta
	position = home + Vector3(0.0, 0.25 + sin(time * 1.4 + phase) * 0.06, 0.0)
	if spins:
		rotation.y = time * 0.5 + phase
	var flicker := 1.0 + 0.2 * sin(time * 3.3 + phase) * sin(time * 1.9)
	var c := material.albedo_color
	c.a = clampf(BASE_ALPHA * fade * flicker, 0.0, 1.0)
	material.albedo_color = c


func is_capturable() -> bool:
	return capturable


func capture(_score: float) -> void:
	if not capturable:
		return
	capturable = false
	var tween := create_tween()
	tween.tween_property(self, "fade", 2.2, 0.1)
	tween.tween_property(self, "fade", 0.0, 1.2)
	await tween.finished
	visible = false


func _build() -> void:
	match shape:
		"backpack":
			_add(_box(0.34, 0.44, 0.18), Vector3(0.0, 0.22, 0.0))
			_add(_box(0.26, 0.18, 0.08), Vector3(0.0, 0.12, -0.12))
		"notebook":
			_add(_box(0.3, 0.04, 0.22), Vector3(0.0, 0.05, 0.0), Vector3(0.0, 20.0, 0.0))
		"coat":
			_add(_capsule(0.16, 0.6), Vector3(0.0, 0.14, 0.0), Vector3(0.0, 0.0, 90.0))
			_add(_capsule(0.07, 0.4), Vector3(0.12, 0.1, 0.2), Vector3(0.0, 0.0, 70.0))
			_add(_capsule(0.07, 0.4), Vector3(-0.12, 0.1, -0.2), Vector3(0.0, 0.0, 110.0))
		"phone":
			_add(_box(0.14, 0.03, 0.26), Vector3(0.0, 0.05, 0.0), Vector3(0.0, 35.0, 0.0))
			_add(_box(0.1, 0.03, 0.12), Vector3(0.0, 0.05, 0.2), Vector3(0.0, 35.0, 25.0))
		"headlights":
			spins = false
			aim_height = 0.7
			_add(_sphere(0.22), Vector3(-0.55, 0.55, 0.0))
			_add(_sphere(0.22), Vector3(0.55, 0.55, 0.0))
			_add(_box(1.5, 0.12, 0.3), Vector3(0.0, 0.25, 0.0))


func _add(mesh: Mesh, pos: Vector3, rot_deg := Vector3.ZERO) -> void:
	var inst := MeshInstance3D.new()
	inst.mesh = mesh
	inst.material_override = material
	inst.position = pos
	inst.rotation_degrees = rot_deg
	inst.layers = 2 << lens
	inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(inst)


func _box(x: float, y: float, z: float) -> BoxMesh:
	var mesh := BoxMesh.new()
	mesh.size = Vector3(x, y, z)
	return mesh


func _sphere(radius: float) -> SphereMesh:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = 8
	mesh.rings = 4
	return mesh


func _capsule(radius: float, length: float) -> CapsuleMesh:
	var mesh := CapsuleMesh.new()
	mesh.radius = radius
	mesh.height = length
	mesh.radial_segments = 8
	mesh.rings = 2
	return mesh
