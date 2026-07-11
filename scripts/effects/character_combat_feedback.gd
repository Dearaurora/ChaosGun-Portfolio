extends Node3D
class_name CharacterCombatFeedback

const SHIELD_COLOR := Color("#45d5ef")

var _shield_root: Node3D
var _shield_rings: Array[MeshInstance3D] = []
var _shield_active := false
var _shield_phase := 0.0
var _hit_serial := 0

func _ready() -> void:
	_build_shield()

func set_shield_active(active: bool) -> void:
	_shield_active = active
	if _shield_root:
		_shield_root.visible = active
	if active:
		_shield_phase = 0.0

func play_hit(impact_direction: Vector3, strength: float = 1.0) -> void:
	_hit_serial += 1
	var accent := Node3D.new()
	accent.name = "DirectionalHitAccent_%d" % _hit_serial
	add_child(accent)

	var flat_direction := Vector3(impact_direction.x, 0.0, impact_direction.z)
	if flat_direction.length_squared() <= 0.0001:
		flat_direction = Vector3.FORWARD
	var local_incoming := basis.inverse() * -flat_direction.normalized()
	accent.position = local_incoming * 1.42 + Vector3.UP * 1.72
	accent.look_at(accent.global_position + flat_direction.normalized(), Vector3.UP)

	var clamped_strength := clampf(strength, 0.45, 1.35)
	for i in range(3):
		var offset_x := (float(i) - 1.0) * 0.18
		var shard_rotation := -24.0 + float(i) * 24.0
		var shard := _add_piece(
			accent,
			"ImpactSlash_%d" % i,
			Vector3(offset_x, (1.0 - absf(float(i) - 1.0)) * 0.12, 0.0),
			Vector3(0.10, 0.40 - absf(float(i) - 1.0) * 0.06, 0.06) * clamped_strength,
			Color("#fff0c4"),
			1.65
		)
		shard.rotation_degrees.z = shard_rotation

	accent.scale = Vector3.ONE * 0.62
	var tween := accent.create_tween().set_parallel(true)
	tween.tween_property(accent, "scale", Vector3.ONE, 0.045).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(accent, "position", accent.position + local_incoming * 0.22, 0.13).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.chain().tween_callback(accent.queue_free).set_delay(0.015)

func get_visual_debug() -> Dictionary:
	return {
		"shield_active": _shield_active,
		"shield_ring_count": _shield_rings.size(),
		"hit_serial": _hit_serial,
	}

func _process(delta: float) -> void:
	if not _shield_active or _shield_root == null:
		return
	_shield_phase += delta
	var pulse := 1.0 + sin(_shield_phase * 5.2) * 0.025
	_shield_root.scale = Vector3.ONE * pulse
	for i in range(_shield_rings.size()):
		var ring := _shield_rings[i]
		ring.rotation.y += delta * (0.45 if i == 0 else -0.32)
		ring.position.y = 0.68 + float(i) * 1.45 + sin(_shield_phase * 3.4 + float(i) * 1.8) * 0.06

func _build_shield() -> void:
	_shield_root = Node3D.new()
	_shield_root.name = "RespawnShield"
	add_child(_shield_root)

	var shell := MeshInstance3D.new()
	shell.name = "ShieldShell"
	var shell_mesh := SphereMesh.new()
	shell_mesh.radius = 1.0
	shell_mesh.height = 2.0
	shell_mesh.radial_segments = 24
	shell_mesh.rings = 12
	shell.mesh = shell_mesh
	shell.position = Vector3(0.0, 1.46, 0.0)
	shell.scale = Vector3(1.62, 1.52, 1.62)
	shell.material_override = _material(Color(SHIELD_COLOR.r, SHIELD_COLOR.g, SHIELD_COLOR.b, 0.055), SHIELD_COLOR, 0.32, true)
	shell.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_shield_root.add_child(shell)

	for i in range(2):
		var ring := MeshInstance3D.new()
		ring.name = "ShieldBand_%d" % i
		var torus := TorusMesh.new()
		torus.inner_radius = 1.48
		torus.outer_radius = 1.55
		torus.rings = 32
		torus.ring_segments = 8
		ring.mesh = torus
		ring.position.y = 0.68 + float(i) * 1.45
		ring.material_override = _material(Color(SHIELD_COLOR.r, SHIELD_COLOR.g, SHIELD_COLOR.b, 0.68), SHIELD_COLOR, 0.28, true)
		ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_shield_root.add_child(ring)
		_shield_rings.append(ring)

	_shield_root.visible = false

func _add_piece(parent: Node3D, piece_name: String, pos: Vector3, size: Vector3, color: Color, emission: float) -> MeshInstance3D:
	var piece := MeshInstance3D.new()
	piece.name = piece_name
	var mesh := BoxMesh.new()
	mesh.size = Vector3.ONE
	piece.mesh = mesh
	piece.position = pos
	piece.scale = size
	piece.material_override = _material(color, color, emission, color.a < 0.99)
	piece.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(piece)
	return piece

func _material(albedo: Color, emission: Color, energy: float, transparent: bool) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = albedo
	material.roughness = 0.55
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA if transparent else BaseMaterial3D.TRANSPARENCY_DISABLED
	material.emission_enabled = energy > 0.0
	material.emission = emission
	material.emission_energy_multiplier = energy
	return material
