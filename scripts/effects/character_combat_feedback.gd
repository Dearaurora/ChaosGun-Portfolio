extends Node3D
class_name CharacterCombatFeedback

const SHIELD_COLOR := Color("#45d5ef")

var _shield_root: Node3D
var _shield_rings: Array[MeshInstance3D] = []
var _shield_active := false
var _shield_phase := 0.0
var _hit_serial := 0
var _flight_root: Node3D
var _flight_streaks: Array[MeshInstance3D] = []
var _danger_root: Node3D
var _flight_active := false
var _danger_active := false
var _motion_phase := 0.0

func _ready() -> void:
	_build_shield()
	_build_motion_feedback()

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

func update_motion_feedback(world_velocity: Vector3, launched: bool, danger: bool) -> void:
	var horizontal_velocity := Vector3(world_velocity.x, 0.0, world_velocity.z)
	_flight_active = launched and horizontal_velocity.length() > 7.0
	_danger_active = danger
	if _flight_root:
		_flight_root.visible = _flight_active
	if _danger_root:
		_danger_root.visible = _danger_active
	if horizontal_velocity.length_squared() <= 0.001:
		return
	var local_direction := basis.inverse() * horizontal_velocity.normalized()
	var motion_basis := Basis.looking_at(local_direction, Vector3.UP)
	if _flight_root:
		_flight_root.basis = motion_basis
		var trail_length := clampf(horizontal_velocity.length() / 13.0, 0.70, 1.55)
		for streak in _flight_streaks:
			streak.scale.z = trail_length
			streak.position.z = 0.30 + trail_length * 0.5
	if _danger_root:
		_danger_root.basis = motion_basis

func get_visual_debug() -> Dictionary:
	return {
		"shield_active": _shield_active,
		"shield_ring_count": _shield_rings.size(),
		"hit_serial": _hit_serial,
		"flight_active": _flight_active,
		"flight_streak_count": _flight_streaks.size(),
		"danger_active": _danger_active,
	}

func _process(delta: float) -> void:
	if _shield_active and _shield_root:
		_shield_phase += delta
		var shield_pulse := 1.0 + sin(_shield_phase * 5.2) * 0.025
		_shield_root.scale = Vector3.ONE * shield_pulse
		for i in range(_shield_rings.size()):
			var ring := _shield_rings[i]
			ring.rotation.y += delta * (0.45 if i == 0 else -0.32)
			ring.position.y = 0.68 + float(i) * 1.45 + sin(_shield_phase * 3.4 + float(i) * 1.8) * 0.06
	if _flight_active or _danger_active:
		_motion_phase += delta
	if _flight_active and _flight_root:
		var flight_pulse := 0.94 + sin(_motion_phase * 17.0) * 0.06
		_flight_root.scale = Vector3(1.0, flight_pulse, 1.0)
	if _danger_active and _danger_root:
		var danger_pulse := 1.0 + sin(_motion_phase * 10.0) * 0.07
		_danger_root.scale = Vector3.ONE * danger_pulse

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

func _build_motion_feedback() -> void:
	_flight_root = Node3D.new()
	_flight_root.name = "KnockbackFlightTrails"
	add_child(_flight_root)
	for i in range(2):
		var side := -1.0 if i == 0 else 1.0
		var streak := _add_piece(
			_flight_root,
			"FlightStreak_%d" % i,
			Vector3(side * 0.36, 1.14 + float(i) * 0.20, 1.10),
			Vector3(0.10, 0.055, 1.0),
			Color(0.95, 0.97, 1.0, 0.72),
			0.65
		)
		_flight_streaks.append(streak)
	_flight_root.visible = false

	_danger_root = Node3D.new()
	_danger_root.name = "RingoutDangerWarning"
	add_child(_danger_root)
	var danger_ring := MeshInstance3D.new()
	danger_ring.name = "DangerRing"
	var torus := TorusMesh.new()
	torus.inner_radius = 1.34
	torus.outer_radius = 1.52
	torus.rings = 28
	torus.ring_segments = 8
	danger_ring.mesh = torus
	danger_ring.position.y = 0.12
	danger_ring.material_override = _material(Color(1.0, 0.20, 0.28, 0.82), Color("#ff4357"), 0.65, true)
	danger_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_danger_root.add_child(danger_ring)
	for i in range(2):
		var chevron := _add_piece(
			_danger_root,
			"DangerChevron_%d" % i,
			Vector3((-0.24 if i == 0 else 0.24), 0.20, -1.48),
			Vector3(0.11, 0.065, 0.48),
			Color("#fff0c4"),
			1.0
		)
		chevron.rotation.y = deg_to_rad(-28.0 if i == 0 else 28.0)
	_danger_root.visible = false

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
