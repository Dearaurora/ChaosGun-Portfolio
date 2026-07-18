extends Node3D
class_name CharacterTransitionBurst

var _mode: StringName = &"ringout"
var _color := Color("#ff6a3d")
var _radius := 1.4
var _lifetime := 0.28
var _built := false

func configure(mode: StringName, color: Color, radius: float) -> void:
	_mode = mode
	_color = color
	_radius = radius
	match mode:
		&"match_spawn":
			_lifetime = 0.46
		&"winner":
			_lifetime = 0.68
		&"respawn":
			_lifetime = 0.30
		_:
			_lifetime = 0.24
	_build()

func _ready() -> void:
	if not _built:
		_build()
	var initial_scale := 0.70
	if _mode == &"respawn":
		initial_scale = 0.35
	elif _mode == &"match_spawn":
		initial_scale = 0.24
	elif _mode == &"winner":
		initial_scale = 0.42
	scale = Vector3.ONE * initial_scale
	var tween := create_tween().set_parallel(true)
	tween.tween_property(self, "scale", Vector3.ONE, _lifetime).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	for child in get_children():
		if child is MeshInstance3D:
			var material := (child as MeshInstance3D).material_override as StandardMaterial3D
			if material:
				tween.tween_property(material, "albedo_color:a", 0.0, _lifetime * 0.62).set_delay(_lifetime * 0.38)
	tween.chain().tween_callback(queue_free)

func get_visual_debug() -> Dictionary:
	return {
		"mode": String(_mode),
		"lifetime": _lifetime,
		"ray_count": _count_prefixed("BurstRay_"),
		"ring_count": _count_prefixed("TransitionRing"),
	}

func _build() -> void:
	if _built:
		return
	_built = true

	var outline := MeshInstance3D.new()
	outline.name = "TransitionOutline"
	var outline_torus := TorusMesh.new()
	outline_torus.inner_radius = _radius * 0.70
	outline_torus.outer_radius = _radius * 0.94
	outline_torus.rings = 32
	outline_torus.ring_segments = 8
	outline.mesh = outline_torus
	outline.position.y = 0.075
	outline.material_override = _material(Color(0.12, 0.10, 0.18, 0.62), Color("#231c32"), 0.0)
	outline.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(outline)

	var ring := MeshInstance3D.new()
	ring.name = "TransitionRing"
	var torus := TorusMesh.new()
	torus.inner_radius = _radius * 0.70
	torus.outer_radius = _radius * 0.88
	torus.rings = 32
	torus.ring_segments = 8
	ring.mesh = torus
	ring.position.y = 0.105
	ring.material_override = _material(Color(_color.r, _color.g, _color.b, 0.82), _color, 1.3)
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(ring)
	if _mode == &"match_spawn" or _mode == &"winner":
		var inner_ring := MeshInstance3D.new()
		inner_ring.name = "TransitionRingInner"
		var inner_torus := TorusMesh.new()
		inner_torus.inner_radius = _radius * 0.38
		inner_torus.outer_radius = _radius * 0.50
		inner_torus.rings = 32
		inner_torus.ring_segments = 8
		inner_ring.mesh = inner_torus
		inner_ring.position.y = 0.13
		inner_ring.material_override = _material(_color.lerp(Color.WHITE, 0.32), _color, 1.55)
		inner_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(inner_ring)

	var core := MeshInstance3D.new()
	core.name = "TransitionCore"
	var core_mesh := SphereMesh.new()
	core_mesh.radius = 1.0
	core_mesh.height = 2.0
	core_mesh.radial_segments = 16
	core_mesh.rings = 8
	core.mesh = core_mesh
	var is_arrival := _mode == &"respawn" or _mode == &"match_spawn"
	core.position.y = 0.72 if is_arrival else 1.10
	core.scale = Vector3(_radius * 0.44, 0.62 if is_arrival else 0.38, _radius * 0.44)
	core.material_override = _material(Color(_color.r, _color.g, _color.b, 0.42), _color, 0.8)
	core.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(core)

	var ray_count := 4 if _mode == &"respawn" else 6
	if _mode == &"winner":
		ray_count = 8
	for i in range(ray_count):
		var angle := TAU * float(i) / float(ray_count)
		var ray := MeshInstance3D.new()
		ray.name = "BurstRay_%d" % i
		var ray_mesh := BoxMesh.new()
		ray_mesh.size = Vector3.ONE
		ray.mesh = ray_mesh
		var distance := _radius * (0.48 if is_arrival else 0.62)
		ray.position = Vector3(cos(angle) * distance, 0.66 + float(i % 2) * 0.24, sin(angle) * distance)
		ray.scale = Vector3(0.12, 0.34 if is_arrival else 0.22, _radius * 0.56)
		ray.rotation.y = -angle
		ray.rotation.z = deg_to_rad(12.0 if i % 2 == 0 else -12.0)
		ray.material_override = _material(_color.lerp(Color.WHITE, 0.42), _color, 1.45)
		ray.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(ray)

func _count_prefixed(prefix: String) -> int:
	var count := 0
	for child in get_children():
		if String(child.name).begins_with(prefix):
			count += 1
	return count

func _material(albedo: Color, emission: Color, energy: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = albedo
	material.roughness = 0.58
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.emission_enabled = energy > 0.0
	material.emission = emission
	material.emission_energy_multiplier = energy
	return material
