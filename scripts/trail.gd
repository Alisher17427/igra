extends Node3D
## A trail of glowing footprints along a path, visible only through one lens. A pulse runs along
## the prints toward the destination.

const LENS_COLORS: Array[Color] = [
	Color(0.72, 0.95, 1.0),
	Color(1.0, 0.62, 0.35),
	Color(0.78, 0.6, 1.0),
]
const STEP := 1.3
const SIDE := 0.17
const BASE_ALPHA := 0.6
const PULSE_SPEED := 3.0
const PULSE_SPACING := 0.45

var points: Array = []
var lens := 2
var time := 0.0
var materials: Array[StandardMaterial3D] = []


func setup(new_points: Array, new_lens: int) -> void:
	points = new_points
	lens = new_lens


func _ready() -> void:
	var index := 0
	var carry := 0.0
	for i in points.size() - 1:
		var a: Vector3 = points[i]
		var b: Vector3 = points[i + 1]
		var segment := b - a
		var length := segment.length()
		var dir := segment / length
		var side_dir := Vector3(-dir.z, 0.0, dir.x)
		var d := carry
		while d < length:
			var offset := SIDE if index % 2 == 0 else -SIDE
			_add_print(a + dir * d + side_dir * offset, atan2(-dir.x, -dir.z))
			index += 1
			d += STEP
		carry = d - length


func _process(delta: float) -> void:
	time += delta
	for i in materials.size():
		var wave := 0.5 + 0.5 * sin(time * PULSE_SPEED - i * PULSE_SPACING)
		var c := materials[i].albedo_color
		c.a = BASE_ALPHA * (0.15 + 0.85 * wave)
		materials[i].albedo_color = c


func _add_print(pos: Vector3, yaw: float) -> void:
	var material := StandardMaterial3D.new()
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var base := LENS_COLORS[lens]
	material.albedo_color = Color(base.r, base.g, base.b, BASE_ALPHA)
	materials.append(material)

	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.13, 0.01, 0.3)
	var inst := MeshInstance3D.new()
	inst.mesh = mesh
	inst.material_override = material
	inst.position = Vector3(pos.x, 0.02, pos.z)
	inst.rotation.y = yaw
	inst.layers = 2 << lens
	inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(inst)
