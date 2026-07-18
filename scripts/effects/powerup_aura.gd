extends Node3D
class_name PowerupAura

var powerup_id: StringName = PowerupCatalog.SPEED
var _elapsed := 0.0
var _ring: MeshInstance3D = null
var _effect_pieces: Array[MeshInstance3D] = []
var _built := false

func configure(id: StringName) -> void:
	powerup_id = id
	_build()

func _ready() -> void:
	if not _built:
		_build()

func _process(delta: float) -> void:
	_elapsed += delta
	if _ring:
		var pulse := 1.0 + sin(_elapsed * 6.0) * 0.045
		_ring.scale = Vector3(pulse, 1.0, pulse)
	if powerup_id == PowerupCatalog.SPEED:
		_animate_speed_gusts()
	elif powerup_id == PowerupCatalog.FURY:
		_animate_fury_flames()

func _build() -> void:
	if _built:
		return
	_built = true
	var color := Color("#24df62") if powerup_id == PowerupCatalog.SPEED else Color("#ff3342")
	var ring_radius := 1.22 if powerup_id == PowerupCatalog.SPEED else 1.48
	var outline := MeshInstance3D.new()
	outline.name = "FootRingOutline"
	var outline_torus := TorusMesh.new()
	outline_torus.inner_radius = ring_radius - 0.05
	outline_torus.outer_radius = ring_radius + 0.20
	outline_torus.rings = 36
	outline_torus.ring_segments = 8
	outline.mesh = outline_torus
	outline.position.y = 0.075
	outline.material_override = _material(Color(0.08, 0.09, 0.14, 0.62), Color("#171925"), 0.0, false)
	outline.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(outline)

	_ring = MeshInstance3D.new()
	_ring.name = "FootRing"
	var torus := TorusMesh.new()
	torus.inner_radius = ring_radius
	torus.outer_radius = ring_radius + 0.13
	torus.rings = 36
	torus.ring_segments = 8
	_ring.mesh = torus
	_ring.position.y = 0.10
	_ring.material_override = _material(Color(color.r, color.g, color.b, 0.96), color, 1.05, false)
	_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_ring)

	if powerup_id == PowerupCatalog.SPEED:
		_build_speed_gusts(color)
	elif powerup_id == PowerupCatalog.FURY:
		_build_fury_flames(color)

func _build_speed_gusts(color: Color) -> void:
	for index in range(7):
		var gust := MeshInstance3D.new()
		gust.name = "WindGust_%d" % index
		var mesh := BoxMesh.new()
		mesh.size = Vector3(0.08, 0.10, 0.72)
		gust.mesh = mesh
		gust.material_override = _material(
			Color(color.r, color.g, color.b, 0.58),
			color.lerp(Color("#baffef"), 0.42),
			1.25,
			true
		)
		gust.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(gust)
		_effect_pieces.append(gust)

func _build_fury_flames(color: Color) -> void:
	for index in range(8):
		var flame := MeshInstance3D.new()
		flame.name = "RageFlame_%d" % index
		var mesh := CylinderMesh.new()
		mesh.top_radius = 0.035
		mesh.bottom_radius = 0.20
		mesh.height = 0.62
		mesh.radial_segments = 9
		flame.mesh = mesh
		var flame_color := color.lerp(Color("#ffbd3f"), float(index % 3) * 0.23)
		flame.material_override = _material(
			Color(flame_color.r, flame_color.g, flame_color.b, 0.72),
			flame_color,
			1.65,
			true
		)
		flame.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(flame)
		_effect_pieces.append(flame)

func _animate_speed_gusts() -> void:
	for index in range(_effect_pieces.size()):
		var gust := _effect_pieces[index]
		var phase := _elapsed * 3.8 + TAU * float(index) / float(_effect_pieces.size())
		var radius := 1.05 + sin(_elapsed * 4.2 + float(index)) * 0.18
		gust.position = Vector3(cos(phase) * radius, 0.20 + float(index % 3) * 0.13, sin(phase) * radius)
		gust.rotation.y = -phase + PI * 0.5
		var stretch := 0.82 + sin(_elapsed * 7.0 + float(index)) * 0.18
		gust.scale = Vector3(1.0, 1.0, stretch)

func _animate_fury_flames() -> void:
	for index in range(_effect_pieces.size()):
		var flame := _effect_pieces[index]
		var phase := fmod(_elapsed * 1.45 + float(index) * 0.137, 1.0)
		var angle := TAU * float(index) / float(_effect_pieces.size()) + sin(_elapsed * 2.2) * 0.12
		var radius := 1.02 + sin(_elapsed * 5.0 + float(index)) * 0.10
		flame.position = Vector3(cos(angle) * radius, 0.20 + phase * 1.08, sin(angle) * radius)
		var flicker := 0.72 + sin(_elapsed * 9.0 + float(index) * 1.7) * 0.22
		flame.scale = Vector3(flicker, 0.72 + (1.0 - phase) * 0.45, flicker)

func get_visual_debug() -> Dictionary:
	return {
		"powerup_id": String(powerup_id),
		"has_ring": _ring != null,
		"effect_piece_count": _effect_pieces.size(),
	}

func _material(albedo: Color, emission: Color, energy: float, additive: bool) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = albedo
	material.roughness = 0.48
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.emission_enabled = true
	material.emission = emission
	material.emission_energy_multiplier = energy
	material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD if additive else BaseMaterial3D.BLEND_MODE_MIX
	return material
