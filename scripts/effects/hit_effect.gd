extends Node3D
class_name HitEffect

var _weapon_id: StringName = &"pistol"
var _color: Color = Color("#ff6b72")
var _radius: float = 0.72
var _lifetime: float = 0.14

func configure(color: Color, weapon_id: StringName) -> void:
	_color = color
	_weapon_id = weapon_id
	var profile := _profile_for_weapon(weapon_id)
	_radius = float(profile["radius"])
	_lifetime = float(profile["lifetime"])
	_build_visual()

func _ready() -> void:
	if get_child_count() == 0:
		_build_visual()
	scale = Vector3.ONE * 0.58
	var tween := create_tween()
	tween.tween_property(self, "scale", Vector3.ONE * 1.18, _lifetime * 0.46).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "scale", Vector3.ZERO, _lifetime * 0.54).set_ease(Tween.EASE_IN)
	tween.tween_callback(queue_free)

func get_visual_debug() -> Dictionary:
	return {"weapon_id": String(_weapon_id), "radius": _radius, "lifetime": _lifetime, "shard_count": 4}

func _build_visual() -> void:
	for child in get_children():
		child.free()
	var dark := Color("#281923")
	var core := _add_box("ImpactCore", Vector3(0.0, 0.08, 0.0), Vector3(_radius * 0.42, 0.035, _radius * 0.42), _material(dark, dark, 0.0, 0.88, false))
	core.rotation.y = PI * 0.25
	for index in range(4):
		var angle := PI * 0.25 + float(index) * PI * 0.50
		var direction := Vector3(cos(angle), 0.0, sin(angle))
		var shard := _add_box("ImpactShard_%d" % index, direction * _radius * 0.50 + Vector3.UP * 0.10, Vector3(_radius * 0.16, 0.025, _radius * 0.58), _material(_color.lerp(Color.WHITE, 0.24), _color, 3.8, 0.82, true))
		shard.rotation.y = -angle

func _profile_for_weapon(weapon_id: StringName) -> Dictionary:
	match weapon_id:
		&"smg":
			return {"radius": 0.52, "lifetime": 0.105}
		&"ak_rifle":
			return {"radius": 0.82, "lifetime": 0.145}
		&"sniper":
			return {"radius": 1.10, "lifetime": 0.180}
		_:
			return {"radius": 0.68, "lifetime": 0.130}

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
