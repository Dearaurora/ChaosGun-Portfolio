extends Node3D
class_name ShotTracer

var _length: float = 5.5
var _width: float = 0.22
var _lifetime: float = 0.10
var _color: Color = Color("#ffce3a")
var _timer_started := false

func setup(start_position: Vector3, direction: Vector3, color: Color, profile: Dictionary = {}) -> void:
	if is_inside_tree():
		global_position = start_position
	else:
		position = start_position
	_color = color
	_length = clampf(float(profile.get("length", _length)), 1.6, 12.0)
	_width = clampf(float(profile.get("width", _width)), 0.12, 0.42)
	_lifetime = clampf(float(profile.get("lifetime", _lifetime)), 0.06, 0.16)

	var aim_dir := direction
	aim_dir.y = 0.0
	if aim_dir.length_squared() <= 0.001:
		aim_dir = Vector3.FORWARD
	transform.basis = Basis.looking_at(aim_dir.normalized(), Vector3.UP)

	_build_visual()
	if is_inside_tree() and not _timer_started:
		_start_lifetime()

func get_visual_debug() -> Dictionary:
	return {
		"length": _length,
		"width": _width,
		"lifetime": _lifetime,
		"color": _color,
	}

func _ready() -> void:
	if get_child_count() == 0:
		_build_visual()
	if not _timer_started:
		_start_lifetime()

func _build_visual() -> void:
	for child in get_children():
		child.queue_free()

	var dark := Color("#111420")
	_add_box(
		"TracerUnderlay",
		Vector3(0.0, -0.020, -_length * 0.50),
		Vector3(_width + 0.11, 0.030, _length),
		_make_material(dark, dark, 0.0, 0.56, false)
	)
	_add_box(
		"TracerCore",
		Vector3(0.0, 0.012, -_length * 0.52),
		Vector3(_width * 1.08, 0.020, _length * 0.90),
		_make_material(_color.lerp(Color.WHITE, 0.10), _color, 4.6, 0.70, true)
	)
	_add_sphere(
		"TracerLead",
		Vector3(0.0, 0.055, -_length * 0.98),
		Vector3(_width * 0.92, _width * 0.34, _width * 0.92),
		_make_material(Color.WHITE, _color, 5.8, 0.94, true)
	)

func _start_lifetime() -> void:
	_timer_started = true
	var hold := _lifetime * 0.34
	var fade := maxf(0.02, _lifetime - hold)
	var tw := create_tween()
	tw.tween_interval(hold)
	tw.tween_property(self, "scale", Vector3(1.0, 0.45, 0.72), fade).set_ease(Tween.EASE_IN)
	tw.tween_callback(queue_free)

func _add_box(mesh_name: String, pos: Vector3, visual_scale: Vector3, mat: StandardMaterial3D) -> MeshInstance3D:
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = mesh_name
	var mesh := BoxMesh.new()
	mesh.size = Vector3.ONE
	mesh_instance.mesh = mesh
	mesh_instance.position = pos
	mesh_instance.scale = visual_scale
	mesh_instance.material_override = mat
	add_child(mesh_instance)
	return mesh_instance

func _add_sphere(mesh_name: String, pos: Vector3, visual_scale: Vector3, mat: StandardMaterial3D) -> MeshInstance3D:
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = mesh_name
	var mesh := SphereMesh.new()
	mesh.radius = 1.0
	mesh.height = 2.0
	mesh.radial_segments = 14
	mesh.rings = 6
	mesh_instance.mesh = mesh
	mesh_instance.position = pos
	mesh_instance.scale = visual_scale
	mesh_instance.material_override = mat
	add_child(mesh_instance)
	return mesh_instance

func _make_material(albedo: Color, emission: Color, energy: float, alpha: float, additive: bool) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA if alpha < 0.99 else BaseMaterial3D.TRANSPARENCY_DISABLED
	mat.albedo_color = Color(albedo.r, albedo.g, albedo.b, alpha)
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.emission_enabled = energy > 0.0
	mat.emission = emission
	mat.emission_energy_multiplier = energy
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	if additive:
		mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	return mat
