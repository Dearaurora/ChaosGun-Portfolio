extends Node3D
class_name MuzzleFlash

var _weapon_id: StringName = &"pistol"
var _color: Color = Color("#ff6b72")
var _length: float = 0.72
var _width: float = 0.28
var _lifetime: float = 0.065

func configure(direction: Vector3, color: Color, weapon_id: StringName) -> void:
	_weapon_id = weapon_id
	_color = color
	var profile := _profile_for_weapon(weapon_id)
	_length = float(profile["length"])
	_width = float(profile["width"])
	_lifetime = float(profile["lifetime"])
	var aim_dir := direction.normalized() if direction.length_squared() > 0.0001 else Vector3.FORWARD
	transform.basis = Basis.looking_at(aim_dir, Vector3.UP)
	_build_visual()

func _ready() -> void:
	if get_child_count() == 0:
		_build_visual()
	var tween := create_tween()
	tween.tween_property(self, "scale", Vector3(1.08, 0.72, 0.82), _lifetime * 0.42).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "scale", Vector3.ZERO, _lifetime * 0.58).set_ease(Tween.EASE_IN)
	tween.tween_callback(queue_free)

func get_visual_debug() -> Dictionary:
	return {
		"weapon_id": String(_weapon_id),
		"length": _length,
		"width": _width,
		"lifetime": _lifetime,
		"petal_count": 2,
	}

func _build_visual() -> void:
	for child in get_children():
		child.free()
	_add_blob("MuzzleCore", Vector3(0.0, 0.012, -_length * 0.40), Vector3(_width * 0.72, _width * 0.28, _length * 0.54), _material(_color.lerp(Color.WHITE, 0.34), _color, 4.2, 0.92, true))
	for side in [-1.0, 1.0]:
		var petal := _add_box("MuzzlePetal", Vector3(side * _width * 0.42, 0.0, -_length * 0.30), Vector3(_width * 0.66, 0.025, _length * 0.46), _material(_color.lerp(Color.WHITE, 0.12), _color, 3.2, 0.76, true))
		petal.rotation.z = side * 0.58

func _profile_for_weapon(weapon_id: StringName) -> Dictionary:
	match weapon_id:
		&"smg":
			return {"length": 0.52, "width": 0.20, "lifetime": 0.045}
		&"ak_rifle":
			return {"length": 0.82, "width": 0.30, "lifetime": 0.060}
		&"sniper":
			return {"length": 1.08, "width": 0.34, "lifetime": 0.080}
		_:
			return {"length": 0.68, "width": 0.26, "lifetime": 0.060}

func _add_blob(node_name: String, pos: Vector3, visual_scale: Vector3, material: StandardMaterial3D) -> MeshInstance3D:
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = node_name
	var mesh := SphereMesh.new()
	mesh.radius = 1.0
	mesh.height = 2.0
	mesh.radial_segments = 12
	mesh.rings = 5
	mesh_instance.mesh = mesh
	mesh_instance.position = pos
	mesh_instance.scale = visual_scale
	mesh_instance.material_override = material
	add_child(mesh_instance)
	return mesh_instance

func _add_box(node_name: String, pos: Vector3, visual_scale: Vector3, material: StandardMaterial3D) -> MeshInstance3D:
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = node_name
	var mesh := BoxMesh.new()
	mesh.size = Vector3.ONE
	mesh_instance.mesh = mesh
	mesh_instance.position = pos
	mesh_instance.scale = visual_scale
	mesh_instance.material_override = material
	add_child(mesh_instance)
	return mesh_instance

func _material(albedo: Color, emission: Color, energy: float, alpha: float, additive: bool) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = Color(albedo.r, albedo.g, albedo.b, alpha)
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.emission_enabled = energy > 0.0
	material.emission = emission
	material.emission_energy_multiplier = energy
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	if additive:
		material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	return material
