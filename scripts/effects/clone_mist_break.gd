extends Node3D
class_name CloneMistBreak

var mist_color := Color("#a9dcff")
var _built := false
var _lifetime := 0.62
var _soft_mist_texture: GradientTexture2D = null

func configure(color: Color) -> void:
	mist_color = color.lerp(Color("#d9efff"), 0.58)
	_build()

func _ready() -> void:
	add_to_group("clone_dissolve_effect")
	if not _built:
		_build()
	var tween := create_tween().set_parallel(true)
	for index in range(get_child_count()):
		var puff := get_child(index) as MeshInstance3D
		if puff == null:
			continue
		var angle := TAU * float(index) / float(maxi(get_child_count(), 1)) + float(index % 2) * 0.34
		var drift := Vector3(cos(angle), 0.22 + float(index % 3) * 0.10, sin(angle)) * (0.82 + float(index % 4) * 0.14)
		tween.tween_property(puff, "position", puff.position + drift, _lifetime).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.tween_property(puff, "scale", puff.scale * 1.65, _lifetime).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		var material := puff.material_override as StandardMaterial3D
		if material:
			tween.tween_property(material, "albedo_color:a", 0.0, _lifetime * 0.72).set_delay(_lifetime * 0.28)
	tween.chain().tween_callback(queue_free)

func _build() -> void:
	if _built:
		return
	_built = true
	for index in range(14):
		var puff := MeshInstance3D.new()
		puff.name = "MistPuff_%d" % index
		var mesh := QuadMesh.new()
		mesh.size = Vector2(1.0, 0.62)
		puff.mesh = mesh
		var angle := TAU * float(index) / 14.0 + sin(float(index) * 2.17) * 0.34
		var radius := 0.20 + float(index % 5) * 0.09
		puff.position = Vector3(cos(angle) * radius, 0.42 + float(index % 6) * 0.25, sin(angle) * radius)
		var size := 0.26 + float(index % 4) * 0.075
		puff.scale = Vector3(size * 2.15, size * 1.05, 1.0)
		puff.material_override = _material(Color(mist_color.r, mist_color.g, mist_color.b, 0.20))
		puff.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(puff)

func get_visual_debug() -> Dictionary:
	return {
		"puff_count": get_child_count(),
		"lifetime": _lifetime,
	}

func _material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = color
	material.albedo_texture = _get_soft_mist_texture()
	material.roughness = 0.88
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	return material

func _get_soft_mist_texture() -> GradientTexture2D:
	if _soft_mist_texture:
		return _soft_mist_texture
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 0.48, 0.78, 1.0])
	gradient.colors = PackedColorArray([
		Color(1.0, 1.0, 1.0, 0.86),
		Color(1.0, 1.0, 1.0, 0.52),
		Color(1.0, 1.0, 1.0, 0.16),
		Color(1.0, 1.0, 1.0, 0.0),
	])
	_soft_mist_texture = GradientTexture2D.new()
	_soft_mist_texture.gradient = gradient
	_soft_mist_texture.width = 64
	_soft_mist_texture.height = 64
	_soft_mist_texture.fill = GradientTexture2D.FILL_RADIAL
	_soft_mist_texture.fill_from = Vector2(0.5, 0.5)
	_soft_mist_texture.fill_to = Vector2(1.0, 0.5)
	return _soft_mist_texture
