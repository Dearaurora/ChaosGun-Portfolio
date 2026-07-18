extends Node3D
class_name TwinBaysPortalVFX

const RuntimeGlobals = preload("res://scripts/globals/runtime_globals.gd")
const TwinBaysLayoutScript = preload("res://scripts/maps/twin_bays_layout.gd")
const TRANSFER_SOUND := preload("res://assets/audio/scifi-sounds/Audio/forceField_003.ogg")
const RING_SCALE_MULTIPLIER := 0.88
const RING_PULSE_AMPLITUDE := 0.018
const FOAM_OUTER_RADIUS_MULTIPLIER := 1.12
const FOAM_PULSE_AMPLITUDE := 0.026
const INNER_FOAM_OUTER_RADIUS_MULTIPLIER := 1.04
const CORE_SCALE_MULTIPLIER := 0.92

var _portal: TwinBaysPortal = null
var _ring: MeshInstance3D = null
var _foam: MeshInstance3D = null
var _inner_foam: MeshInstance3D = null
var _core: MeshInstance3D = null
var _burst: CPUParticles3D = null
var _audio: AudioStreamPlayer3D = null
var _ring_base_scale := Vector3.ONE
var _foam_base_scale := Vector3.ONE
var _phase := 0.0

func get_dynamic_envelope_contract() -> Dictionary:
	return {
		"ring_scale_multiplier": RING_SCALE_MULTIPLIER,
		"ring_pulse_amplitude": RING_PULSE_AMPLITUDE,
		"foam_outer_radius_multiplier": FOAM_OUTER_RADIUS_MULTIPLIER,
		"foam_pulse_amplitude": FOAM_PULSE_AMPLITUDE,
		"inner_foam_outer_radius_multiplier": INNER_FOAM_OUTER_RADIUS_MULTIPLIER,
		"core_scale_multiplier": CORE_SCALE_MULTIPLIER,
	}

func configure(portal: TwinBaysPortal, portal_data: Dictionary) -> void:
	_portal = portal
	_phase = 0.0 if portal.position.x < 0.0 else PI
	_build_visuals(portal_data)
	if not portal.character_teleported.is_connected(_on_character_teleported):
		portal.character_teleported.connect(_on_character_teleported)
	set_process(true)

func _process(_delta: float) -> void:
	if _ring == null or _foam == null:
		return
	var pulse := 1.0 + sin(Time.get_ticks_msec() * 0.0032 + _phase) * RING_PULSE_AMPLITUDE
	var foam_pulse := 1.0 + sin(Time.get_ticks_msec() * 0.0041 + _phase + 0.8) * FOAM_PULSE_AMPLITUDE
	_ring.scale = _ring_base_scale * pulse
	_foam.scale = _foam_base_scale * foam_pulse

func play_transfer_burst() -> void:
	if _burst:
		_burst.restart()
	if _audio and not RuntimeGlobals.runtime_audio_disabled():
		_audio.play()

func _build_visuals(portal_data: Dictionary) -> void:
	for child in get_children():
		child.free()
	name = "PortalVFX"

	var normal := TwinBaysLayoutScript.vector3(portal_data["normal"], "portal.normal").normalized()
	var ring_data := portal_data["ring"] as Dictionary
	var core_data := portal_data["core"] as Dictionary
	# Gameplay normal, water plane and pipe mouth share one exact axis.  The ring
	# sits just in front of the annulus, while its maximum animated foam envelope
	# remains inside the authored inner pipe radii.
	var basis_value := _portal_basis(normal)
	var ring_position := TwinBaysLayoutScript.vector3(ring_data["local_position"], "portal.ring.local_position") + normal * 0.18
	var ring_scale := TwinBaysLayoutScript.vector3(ring_data["scale"], "portal.ring.scale") * RING_SCALE_MULTIPLIER

	_ring = MeshInstance3D.new()
	_ring.name = "PortalWaterRing"
	_ring.mesh = _build_ring_mesh(float(ring_data["inner_radius"]), float(ring_data["outer_radius"]), int(ring_data["segments"]))
	_ring.position = ring_position
	_ring.basis = basis_value
	_ring.scale = ring_scale
	_ring_base_scale = ring_scale
	_ring.material_override = _portal_material(Color("#36D9FF"), 3.4, 0.96)
	_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_ring)

	_inner_foam = MeshInstance3D.new()
	_inner_foam.name = "PortalInnerFoamRim"
	_inner_foam.mesh = _build_ring_mesh(float(ring_data["inner_radius"]) * 0.86, float(ring_data["inner_radius"]) * INNER_FOAM_OUTER_RADIUS_MULTIPLIER, int(ring_data["segments"]))
	_inner_foam.position = ring_position + normal * 0.025
	_inner_foam.basis = basis_value
	_inner_foam.scale = ring_scale
	_inner_foam.material_override = _portal_material(Color("#F0FDFF"), 1.35, 0.92)
	_inner_foam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_inner_foam)

	_foam = MeshInstance3D.new()
	_foam.name = "PortalFoamRim"
	_foam.mesh = _build_ring_mesh(float(ring_data["outer_radius"]) * 0.94, float(ring_data["outer_radius"]) * FOAM_OUTER_RADIUS_MULTIPLIER, int(ring_data["segments"]))
	_foam.position = ring_position + normal * 0.04
	_foam.basis = basis_value
	_foam.scale = ring_scale
	_foam_base_scale = ring_scale
	_foam.material_override = _portal_material(Color("#D9FAFF"), 1.15, 0.68)
	_foam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_foam)

	_core = MeshInstance3D.new()
	_core.name = "PortalWaterCore"
	_core.mesh = _build_disc_mesh(float(core_data["radius"]), int(core_data["segments"]))
	_core.position = TwinBaysLayoutScript.vector3(core_data["local_position"], "portal.core.local_position") + normal * 0.14
	_core.basis = basis_value
	_core.scale = TwinBaysLayoutScript.vector3(core_data["scale"], "portal.core.scale") * CORE_SCALE_MULTIPLIER
	_core.material_override = _portal_material(Color("#12B7DA"), 1.15, 0.86)
	_core.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_core)

	_build_foam_bubbles(ring_position)
	_build_transfer_burst(ring_position)
	_build_audio(ring_position)

func _build_foam_bubbles(ring_position: Vector3) -> void:
	var bubbles := CPUParticles3D.new()
	bubbles.name = "PortalFoamBubbles"
	bubbles.position = ring_position
	bubbles.amount = 14
	bubbles.lifetime = 1.35
	bubbles.emitting = true
	bubbles.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	bubbles.emission_box_extents = Vector3(0.12, 2.1, 1.65)
	bubbles.direction = Vector3.UP
	bubbles.spread = 28.0
	bubbles.gravity = Vector3(0.0, 0.42, 0.0)
	bubbles.initial_velocity_min = 0.18
	bubbles.initial_velocity_max = 0.55
	bubbles.scale_amount_min = 0.18
	bubbles.scale_amount_max = 0.42
	bubbles.color = Color("#C9F8FF")
	var bubble_mesh := SphereMesh.new()
	bubble_mesh.radius = 0.11
	bubble_mesh.height = 0.22
	bubble_mesh.radial_segments = 8
	bubble_mesh.rings = 4
	bubbles.mesh = bubble_mesh
	add_child(bubbles)

func _build_transfer_burst(ring_position: Vector3) -> void:
	_burst = CPUParticles3D.new()
	_burst.name = "PortalTransferSplash"
	_burst.position = ring_position
	_burst.amount = 40
	_burst.lifetime = 0.48
	_burst.one_shot = true
	_burst.explosiveness = 0.92
	_burst.emitting = false
	_burst.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	_burst.emission_sphere_radius = 1.35
	_burst.direction = Vector3.UP
	_burst.spread = 78.0
	_burst.gravity = Vector3(0.0, -2.6, 0.0)
	_burst.initial_velocity_min = 2.0
	_burst.initial_velocity_max = 5.2
	_burst.scale_amount_min = 0.35
	_burst.scale_amount_max = 0.8
	_burst.color = Color("#B9F5FF")
	var drop_mesh := SphereMesh.new()
	drop_mesh.radius = 0.18
	drop_mesh.height = 0.42
	drop_mesh.radial_segments = 8
	drop_mesh.rings = 4
	_burst.mesh = drop_mesh
	add_child(_burst)

func _build_audio(ring_position: Vector3) -> void:
	_audio = AudioStreamPlayer3D.new()
	_audio.name = "PortalTransferAudio"
	_audio.position = ring_position
	_audio.stream = TRANSFER_SOUND
	_audio.volume_db = -6.0
	_audio.max_distance = 78.0
	_audio.unit_size = 14.0
	add_child(_audio)

func _on_character_teleported(_character: BaseCharacter, _from: TwinBaysPortal, to_portal: TwinBaysPortal) -> void:
	play_transfer_burst()
	var destination_vfx := to_portal.get_node_or_null("PortalVFX") as TwinBaysPortalVFX
	if destination_vfx:
		destination_vfx.play_transfer_burst()

func _portal_material(color: Color, energy: float, alpha: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(color, alpha)
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.no_depth_test = false
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.emission_enabled = true
	material.emission = color
	material.emission_energy_multiplier = energy
	material.roughness = 0.32
	material.render_priority = 1
	return material

func _portal_basis(normal: Vector3) -> Basis:
	var y_axis := normal.normalized()
	var z_axis := Vector3.UP
	var x_axis := y_axis.cross(z_axis).normalized()
	return Basis(x_axis, y_axis, z_axis)

func _build_ring_mesh(inner_radius: float, outer_radius: float, segments: int) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for index in range(segments):
		var angle_a := TAU * float(index) / float(segments)
		var angle_b := TAU * float(index + 1) / float(segments)
		var outer_a := Vector3(cos(angle_a) * outer_radius, 0.0, sin(angle_a) * outer_radius)
		var outer_b := Vector3(cos(angle_b) * outer_radius, 0.0, sin(angle_b) * outer_radius)
		var inner_a := Vector3(cos(angle_a) * inner_radius, 0.0, sin(angle_a) * inner_radius)
		var inner_b := Vector3(cos(angle_b) * inner_radius, 0.0, sin(angle_b) * inner_radius)
		for vertex in [outer_a, inner_b, inner_a, outer_a, outer_b, inner_b]:
			st.set_normal(Vector3.UP)
			st.add_vertex(vertex)
	return st.commit()

func _build_disc_mesh(radius: float, segments: int) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for index in range(segments):
		var angle_a := TAU * float(index) / float(segments)
		var angle_b := TAU * float(index + 1) / float(segments)
		for vertex in [
			Vector3.ZERO,
			Vector3(cos(angle_b) * radius, 0.0, sin(angle_b) * radius),
			Vector3(cos(angle_a) * radius, 0.0, sin(angle_a) * radius),
		]:
			st.set_normal(Vector3.UP)
			st.add_vertex(vertex)
	return st.commit()
