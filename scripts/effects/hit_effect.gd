extends Node3D
class_name HitEffect

const CombatVisualResourceCache = preload("res://scripts/effects/combat_visual_resource_cache.gd")
const IMPACT_GOLD := Color("#ffc83d")
const IMPACT_WHITE := Color("#fff8d8")

var _weapon_id: StringName = &"pistol"
var _color: Color = Color("#ff6b72")
var _radius: float = 0.72
var _lifetime: float = 0.14
var _impact_direction: Vector3 = Vector3.FORWARD
var _fan_degrees: float = 42.0
var _elongation: float = 0.88
var _shape: StringName = &"snap"
var _shard_count: int = 3
var _ring_count: int = 0
var _visual_build_count := 0

func configure(color: Color, weapon_id: StringName, impact_direction: Vector3 = Vector3.FORWARD) -> void:
	_color = color
	_weapon_id = weapon_id
	_impact_direction = Vector3(impact_direction.x, 0.0, impact_direction.z)
	if _impact_direction.length_squared() <= 0.0001:
		_impact_direction = Vector3.FORWARD
	else:
		_impact_direction = _impact_direction.normalized()
	var profile := _profile_for_weapon(weapon_id)
	_radius = float(profile["radius"])
	_lifetime = float(profile["lifetime"])
	_fan_degrees = float(profile["fan_degrees"])
	_elongation = float(profile["elongation"])
	_shape = StringName(profile["shape"])
	_shard_count = int(profile["shard_count"])
	_ring_count = int(profile.get("ring_count", 0))
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
	return {
		"weapon_id": String(_weapon_id),
		"radius": _radius,
		"lifetime": _lifetime,
		"shard_count": _shard_count,
		"ring_count": _ring_count,
		"shape": String(_shape),
		"impact_direction": _impact_direction,
		"fan_degrees": _fan_degrees,
		"elongation": _elongation,
		"build_count": _visual_build_count,
	}

func _build_visual() -> void:
	_visual_build_count += 1
	for child in get_children():
		child.free()
	var dark := Color("#281923")
	_add_blob(
		"ImpactCore",
		_impact_direction * _radius * 0.06 + Vector3.UP * 0.08,
		Vector3(_radius * 0.21, 0.020, _radius * 0.21),
		_material(dark, dark, 0.0, 0.88, false)
	)
	for index in range(_shard_count):
		var ratio := 0.0 if _shard_count <= 1 else float(index) / float(_shard_count - 1)
		var spread_weight := ratio * 1.64 - 0.82
		var angle := deg_to_rad(_fan_degrees * 0.5 * spread_weight)
		var shard_direction := _impact_direction.rotated(Vector3.UP, angle)
		var center_weight := 1.0 - absf(spread_weight)
		var shard_length := _radius * _elongation * lerpf(0.72, 1.0, center_weight)
		var shard_reach := _radius * lerpf(0.42, 0.54, center_weight)
		var shard_scale := Vector3(_radius * lerpf(0.08, 0.12, center_weight), 0.025, shard_length)
		var shard_color := IMPACT_WHITE if center_weight > 0.45 else IMPACT_GOLD
		var shard := _add_box(
			"ImpactShard_%d" % index,
			shard_direction * shard_reach + Vector3.UP * 0.10,
			shard_scale,
			_material(shard_color, shard_color, 1.95, 0.86, true)
		)
		shard.basis = Basis.looking_at(shard_direction, Vector3.UP)
		shard.scale = shard_scale
	if _ring_count > 0:
		_add_impact_ring()

func _profile_for_weapon(weapon_id: StringName) -> Dictionary:
	match weapon_id:
		&"smg":
			return {"radius": 0.62, "lifetime": 0.105, "fan_degrees": 28.0, "elongation": 0.76, "shape": &"rapid_chips", "shard_count": 3}
		&"ak_rifle":
			return {"radius": 1.10, "lifetime": 0.180, "fan_degrees": 34.0, "elongation": 1.00, "shape": &"directional_slash", "shard_count": 4}
		&"sniper":
			return {"radius": 1.28, "lifetime": 0.180, "fan_degrees": 16.0, "elongation": 1.24, "shape": &"pierce_ring", "shard_count": 3, "ring_count": 1}
		&"gatling":
			return {"radius": 0.54, "lifetime": 0.095, "fan_degrees": 24.0, "elongation": 0.68, "shape": &"rotary_sparks", "shard_count": 2}
		&"shotgun":
			return {"radius": 0.90, "lifetime": 0.125, "fan_degrees": 84.0, "elongation": 0.82, "shape": &"wide_burst", "shard_count": 5}
		_:
			return {"radius": 0.82, "lifetime": 0.130, "fan_degrees": 42.0, "elongation": 0.88, "shape": &"snap", "shard_count": 3}

func _add_impact_ring() -> void:
	var ring := MeshInstance3D.new()
	ring.name = "ImpactShockRing"
	ring.mesh = CombatVisualResourceCache.torus_mesh(0.38, 0.50, 24, 6)
	ring.position = _impact_direction * _radius * 0.16 + Vector3.UP * 0.10
	ring.basis = Basis.looking_at(_impact_direction, Vector3.UP) * Basis(Vector3.RIGHT, PI * 0.5)
	ring.scale = Vector3.ONE * _radius * 0.62
	ring.material_override = _material(_color, _color, 1.20, 0.66, true)
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(ring)

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

func _add_blob(node_name: String, pos: Vector3, visual_scale: Vector3, material: StandardMaterial3D) -> MeshInstance3D:
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = node_name
	mesh_instance.mesh = CombatVisualResourceCache.sphere_mesh(14, 6)
	mesh_instance.position = pos
	mesh_instance.scale = visual_scale
	mesh_instance.material_override = material
	mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mesh_instance)
	return mesh_instance

func _material(albedo: Color, emission: Color, energy: float, alpha: float, additive: bool) -> StandardMaterial3D:
	return CombatVisualResourceCache.material(albedo, emission, energy, alpha, additive)
