extends Node3D
class_name MuzzleFlash

const CombatVisualResourceCache = preload("res://scripts/effects/combat_visual_resource_cache.gd")

var _weapon_id: StringName = &"pistol"
var _color: Color = Color("#ff6b72")
var _length: float = 0.72
var _width: float = 0.28
var _lifetime: float = 0.065
var _light_energy: float = 0.80
var _style: StringName = &"star"
var _petal_count: int = 4
var _ring_count: int = 0
var _visual_build_count := 0

func configure(direction: Vector3, color: Color, weapon_id: StringName) -> void:
	_weapon_id = weapon_id
	_color = color
	var profile := _profile_for_weapon(weapon_id)
	_length = float(profile["length"])
	_width = float(profile["width"])
	_lifetime = float(profile["lifetime"])
	_light_energy = float(profile["light_energy"])
	_style = StringName(profile["style"])
	_petal_count = int(profile["petal_count"])
	_ring_count = int(profile.get("ring_count", 0))
	var aim_dir := direction.normalized() if direction.length_squared() > 0.0001 else Vector3.FORWARD
	transform.basis = Basis.looking_at(aim_dir, Vector3.UP)
	_build_visual()

func _ready() -> void:
	if get_child_count() == 0:
		_build_visual()
	scale = Vector3.ONE * 0.72
	var tween := create_tween()
	tween.tween_property(self, "scale", Vector3(1.10, 0.84, 1.10), _lifetime * 0.42).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "scale", Vector3.ZERO, _lifetime * 0.58).set_ease(Tween.EASE_IN)
	tween.tween_callback(queue_free)

func get_visual_debug() -> Dictionary:
	return {
		"weapon_id": String(_weapon_id),
		"length": _length,
		"width": _width,
		"lifetime": _lifetime,
		"light_energy": _light_energy,
		"petal_axis": "horizontal_y",
		"petal_count": _petal_count,
		"ring_count": _ring_count,
		"shape": String(_style),
		"build_count": _visual_build_count,
	}

func _build_visual() -> void:
	_visual_build_count += 1
	for child in get_children():
		child.free()
	_add_blob(
		"MuzzleCore",
		Vector3(0.0, 0.014, -_length * 0.18),
		Vector3(_width * 0.38, _width * 0.22, _length * 0.25),
		_material(_color, _color, 1.65, 0.88, false)
	)
	match _style:
		&"needle":
			_build_fan(2, 0.22, 0.78, 0.76)
		&"fork":
			_build_fan(3, 0.50, 0.96, 0.86)
		&"lance":
			_build_fan(2, 0.18, 0.48, 1.10)
			for side in [-1.0, 1.0]:
				var rail := _add_box(
					"MuzzleRail_%s" % ("L" if side < 0.0 else "R"),
					Vector3(side * _width * 0.40, 0.0, -_length * 0.48),
					Vector3(_width * 0.14, 0.024, _length * 0.72),
					_material(_color.darkened(0.08), _color, 1.25, 0.76, true)
				)
				rail.rotation.y = side * 0.055
		&"rotary":
			_build_fan(3, 0.34, 0.66, 0.72)
		&"crown":
			_build_fan(5, 1.10, 1.10, 0.80)
		_:
			_build_fan(4, 0.78, 0.94, 0.82)
	if _ring_count > 0:
		_add_ring(
			"MuzzleShockRing",
			Vector3(0.0, 0.0, -_length * 0.10),
			_width * 1.10,
			_material(_color, _color, 1.10, 0.62, true)
		)
	var light := OmniLight3D.new()
	light.name = "MuzzleLight"
	light.position = Vector3(0.0, 0.16, -_length * 0.28)
	light.light_color = _color.lerp(Color.WHITE, 0.26)
	light.light_energy = _light_energy
	light.omni_range = 2.0 + _length * 0.75
	light.shadow_enabled = false
	add_child(light)

func _profile_for_weapon(weapon_id: StringName) -> Dictionary:
	match weapon_id:
		&"smg":
			return {"length": 0.52, "width": 0.20, "lifetime": 0.045, "light_energy": 0.58, "style": &"needle", "petal_count": 2}
		&"ak_rifle":
			return {"length": 0.82, "width": 0.30, "lifetime": 0.060, "light_energy": 0.92, "style": &"fork", "petal_count": 3}
		&"sniper":
			return {"length": 1.12, "width": 0.32, "lifetime": 0.080, "light_energy": 1.20, "style": &"lance", "petal_count": 2, "ring_count": 1}
		&"gatling":
			return {"length": 0.46, "width": 0.18, "lifetime": 0.040, "light_energy": 0.46, "style": &"rotary", "petal_count": 3}
		&"shotgun":
			return {"length": 0.88, "width": 0.48, "lifetime": 0.075, "light_energy": 1.12, "style": &"crown", "petal_count": 5}
		_:
			return {"length": 0.68, "width": 0.26, "lifetime": 0.060, "light_energy": 0.74, "style": &"star", "petal_count": 4}

func _build_fan(count: int, fan_radians: float, width_scale: float, length_scale: float) -> void:
	for index in range(count):
		var ratio := 0.0 if count <= 1 else float(index) / float(count - 1)
		var signed_ratio := ratio * 2.0 - 1.0
		var angle := signed_ratio * fan_radians * 0.5
		var center_weight := 1.0 - absf(signed_ratio)
		var petal_length := _length * length_scale * lerpf(0.74, 1.0, center_weight)
		var petal_width := _width * width_scale * lerpf(0.20, 0.28, center_weight)
		_add_wedge(
			"MuzzlePetal_%d" % index,
			angle,
			petal_length,
			petal_width,
			_material(_color, _color, 1.35, 0.74, true)
		)

func _add_wedge(node_name: String, angle: float, petal_length: float, petal_width: float, material: StandardMaterial3D) -> MeshInstance3D:
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = node_name
	mesh_instance.mesh = CombatVisualResourceCache.wedge_mesh(
		angle,
		petal_length,
		petal_width,
		_length * 0.04
	)
	mesh_instance.position.y = 0.012
	mesh_instance.material_override = material
	mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mesh_instance)
	return mesh_instance

func _add_ring(node_name: String, pos: Vector3, ring_scale: float, material: StandardMaterial3D) -> MeshInstance3D:
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = node_name
	mesh_instance.mesh = CombatVisualResourceCache.torus_mesh(0.40, 0.50, 20, 6)
	mesh_instance.position = pos
	mesh_instance.rotation.x = PI * 0.5
	mesh_instance.scale = Vector3.ONE * ring_scale
	mesh_instance.material_override = material
	mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mesh_instance)
	return mesh_instance

func _add_blob(node_name: String, pos: Vector3, visual_scale: Vector3, material: StandardMaterial3D) -> MeshInstance3D:
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = node_name
	mesh_instance.mesh = CombatVisualResourceCache.sphere_mesh(12, 5)
	mesh_instance.position = pos
	mesh_instance.scale = visual_scale
	mesh_instance.material_override = material
	mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mesh_instance)
	return mesh_instance

func _add_box(node_name: String, pos: Vector3, visual_scale: Vector3, material: StandardMaterial3D) -> MeshInstance3D:
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = node_name
	mesh_instance.mesh = CombatVisualResourceCache.box_mesh()
	mesh_instance.position = pos
	mesh_instance.scale = visual_scale
	mesh_instance.material_override = material
	mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mesh_instance)
	return mesh_instance

func _material(albedo: Color, emission: Color, energy: float, alpha: float, additive: bool) -> StandardMaterial3D:
	return CombatVisualResourceCache.material(albedo, emission, energy, alpha, additive)
