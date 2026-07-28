extends Node3D
class_name TwinBaysPortalVFX

const RuntimeGlobals = preload("res://scripts/globals/runtime_globals.gd")
const TwinBaysLayoutScript = preload("res://scripts/maps/twin_bays_layout.gd")
const TRANSFER_SOUND := preload("res://assets/audio/scifi-sounds/Audio/forceField_003.ogg")
const PORTAL_WATER_SHADER_V5: Shader = preload(
	"res://assets/shaders/twin_bays_portal_water_v5.gdshader"
)
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
var _art_version := 4
var _art_profile: Dictionary = {}
var _portal_data: Dictionary = {}

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
	_portal_data = portal_data.duplicate(true)
	_phase = 0.0 if portal.position.x < 0.0 else PI
	_build_visuals(portal_data)
	if not portal.character_teleported.is_connected(_on_character_teleported):
		portal.character_teleported.connect(_on_character_teleported)
	set_process(true)

func apply_art_profile(art_profile: Dictionary) -> void:
	_art_profile = art_profile.duplicate(true)
	_art_version = int(art_profile.get("version", 4))
	if not _portal_data.is_empty():
		_build_visuals(_portal_data)

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
	var portal_art := _art_profile.get("portal_art", {}) as Dictionary
	var palette := _art_profile.get("palette", {}) as Dictionary
	var premium_portal := _art_version >= 5
	var portal_color := Color(String(palette.get("portal_cyan", "#36D9FF"))) \
		if premium_portal else Color("#36D9FF")
	var foam_color := Color(String(portal_art.get(
		"water_entry_foam_color",
		palette.get("foam", "#D9FAFF")
	))) if premium_portal else Color("#D9FAFF")
	var ripple_color := Color(String(portal_art.get("ripple_color", "#8EF6FF"))) \
		if premium_portal else Color("#F0FDFF")
	var core_color := Color(String(portal_art.get("core_color", "#12B7DA"))) \
		if premium_portal else Color("#12B7DA")
	var ring_energy := float(portal_art.get("ring_energy", 3.4)) if premium_portal else 3.4
	var core_energy := float(portal_art.get("core_energy", 1.15)) if premium_portal else 1.15
	var cascade_length := 0.0
	if _art_version >= 5 and bool(portal_art.get("continuous_water_cascade", false)):
		cascade_length = float(portal_art.get("cascade_length", 2.4))
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
	_ring.material_override = _portal_material(portal_color, ring_energy, 0.96)
	_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_ring)

	_inner_foam = MeshInstance3D.new()
	_inner_foam.name = "PortalInnerFoamRim"
	var inner_foam_scallop := (
		float(portal_art.get("inner_foam_scallop_strength", 0.0))
		if _art_version >= 6 else 0.0
	)
	_inner_foam.mesh = _build_ring_mesh(
		float(ring_data["inner_radius"]) * 0.86,
		float(ring_data["inner_radius"]) * INNER_FOAM_OUTER_RADIUS_MULTIPLIER,
		int(ring_data["segments"]),
		inner_foam_scallop
	)
	_inner_foam.position = ring_position + normal * 0.025
	_inner_foam.basis = basis_value
	_inner_foam.scale = ring_scale
	_inner_foam.material_override = _portal_material(
		ripple_color,
		ring_energy * 0.58 if premium_portal else 1.35,
		0.92
	)
	_inner_foam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_inner_foam)

	_foam = MeshInstance3D.new()
	_foam.name = "PortalFoamRim"
	var outer_foam_scallop := (
		float(portal_art.get("foam_rim_scallop_strength", 0.0))
		if _art_version >= 6 else 0.0
	)
	_foam.mesh = _build_ring_mesh(
		float(ring_data["outer_radius"]) * 0.94,
		float(ring_data["outer_radius"]) * FOAM_OUTER_RADIUS_MULTIPLIER,
		int(ring_data["segments"]),
		outer_foam_scallop,
		_art_version >= 6
	)
	_foam.position = ring_position + normal * 0.04
	_foam.basis = basis_value
	_foam.scale = ring_scale
	_foam_base_scale = ring_scale
	_foam.material_override = (
		_portal_foam_material(
			foam_color,
			float(portal_art.get("foam_alpha", 0.68))
		)
		if _art_version >= 6
		else _portal_material(
			foam_color,
			ring_energy * 0.46 if premium_portal else 1.15,
			float(portal_art.get("foam_alpha", 0.68)) if premium_portal else 0.68
		)
	)
	_foam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_foam)

	_core = MeshInstance3D.new()
	_core.name = "PortalWaterCore"
	_core.mesh = _build_disc_mesh(
		float(core_data["radius"]),
		int(core_data["segments"]),
		cascade_length,
		float(portal_art.get("cascade_width_wave", 0.0)) if _art_version >= 6 else 0.0,
		float(portal_art.get("cascade_lip_curl", 0.0)) if _art_version >= 6 else 0.0
	)
	_core.position = TwinBaysLayoutScript.vector3(core_data["local_position"], "portal.core.local_position") + normal * 0.14
	_core.basis = basis_value
	_core.scale = TwinBaysLayoutScript.vector3(core_data["scale"], "portal.core.scale") * CORE_SCALE_MULTIPLIER
	_core.material_override = (
		_portal_water_material(
			core_color,
			foam_color,
			float(portal_art.get("cascade_alpha", 0.78)),
			float(portal_art.get("cascade_highlight_strength", 0.58))
		)
		if premium_portal
		else _portal_material(core_color, core_energy, 0.90)
	)
	_core.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_core)

	_build_foam_bubbles(ring_position, foam_color, premium_portal)
	_build_transfer_burst(
		ring_position,
		ripple_color if premium_portal else Color("#B9F5FF"),
		premium_portal
	)
	_build_audio(ring_position)

func _build_foam_bubbles(
	ring_position: Vector3,
	foam_color: Color,
	premium_portal: bool
) -> void:
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
	bubbles.color = foam_color
	var bubble_mesh := SphereMesh.new()
	bubble_mesh.radius = 0.11
	bubble_mesh.height = 0.22
	bubble_mesh.radial_segments = 8
	bubble_mesh.rings = 4
	if premium_portal:
		bubble_mesh.material = _portal_material(foam_color, 0.65, 0.90)
	bubbles.mesh = bubble_mesh
	add_child(bubbles)

func _build_transfer_burst(
	ring_position: Vector3,
	ripple_color: Color,
	premium_portal: bool
) -> void:
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
	_burst.color = ripple_color
	var drop_mesh := SphereMesh.new()
	drop_mesh.radius = 0.14 if premium_portal else 0.18
	drop_mesh.height = 0.48 if premium_portal else 0.42
	drop_mesh.radial_segments = 8
	drop_mesh.rings = 4
	if premium_portal:
		drop_mesh.material = _portal_material(ripple_color, 0.90, 0.92)
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


func _portal_foam_material(color: Color, alpha: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(color, alpha)
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.roughness = 0.24
	material.metallic_specular = 0.72
	material.emission_enabled = true
	material.emission = color
	material.emission_energy_multiplier = 0.10
	material.render_priority = 1
	return material


func _portal_water_material(
	color: Color,
	foam_color: Color,
	alpha: float,
	highlight_strength: float
) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = PORTAL_WATER_SHADER_V5
	material.set_shader_parameter("water_color", color)
	material.set_shader_parameter("foam_color", foam_color)
	material.set_shader_parameter("alpha_scale", alpha)
	material.set_shader_parameter("highlight_strength", highlight_strength)
	material.set_meta("visual_only", true)
	material.set_meta("portal_water_v5", true)
	return material

func _portal_basis(normal: Vector3) -> Basis:
	var y_axis := normal.normalized()
	var z_axis := Vector3.UP
	var x_axis := y_axis.cross(z_axis).normalized()
	return Basis(x_axis, y_axis, z_axis)

func _build_ring_mesh(
	inner_radius: float,
	outer_radius: float,
	segments: int,
	scallop_strength: float = 0.0,
	broken_arc: bool = false
) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for index in range(segments):
		if broken_arc and index % 16 == 7:
			continue
		var angle_a := TAU * float(index) / float(segments)
		var angle_b := TAU * float(index + 1) / float(segments)
		var scallop_a := (
			sin(angle_a * 7.0 + 0.35) + sin(angle_a * 13.0 - 0.8) * 0.34
		) * scallop_strength
		var scallop_b := (
			sin(angle_b * 7.0 + 0.35) + sin(angle_b * 13.0 - 0.8) * 0.34
		) * scallop_strength
		var outer_radius_a := outer_radius * (1.0 + scallop_a)
		var outer_radius_b := outer_radius * (1.0 + scallop_b)
		var inner_radius_a := inner_radius * (1.0 + scallop_a * 0.22)
		var inner_radius_b := inner_radius * (1.0 + scallop_b * 0.22)
		var outer_a := Vector3(cos(angle_a) * outer_radius_a, 0.0, sin(angle_a) * outer_radius_a)
		var outer_b := Vector3(cos(angle_b) * outer_radius_b, 0.0, sin(angle_b) * outer_radius_b)
		var inner_a := Vector3(cos(angle_a) * inner_radius_a, 0.0, sin(angle_a) * inner_radius_a)
		var inner_b := Vector3(cos(angle_b) * inner_radius_b, 0.0, sin(angle_b) * inner_radius_b)
		for vertex in [outer_a, inner_b, inner_a, outer_a, outer_b, inner_b]:
			st.set_normal(Vector3.UP)
			st.add_vertex(vertex)
	return st.commit()

func _build_disc_mesh(
	radius: float,
	segments: int,
	cascade_length: float = 0.0,
	cascade_width_wave: float = 0.0,
	cascade_lip_curl: float = 0.0
) -> ArrayMesh:
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
	if cascade_length > 0.0:
		# Keep the cascade in the existing core batch: a broad lip narrows through
		# several soft steps so it reads as a toy-waterfall, not one flat triangle.
		# Vector3 stores vertical position, half-width, and inward mouth offset.
		# The increasing offset carries the fall over the deck lip instead of
		# letting the static pipe throat hide it.
		var cascade_rows := [
			Vector3(
				-radius * 0.44,
				radius * 0.70,
				-cascade_length * cascade_lip_curl * 0.12
			),
			Vector3(-radius * 0.70, radius * 0.67, cascade_length * 0.08),
			Vector3(-radius * 0.92, radius * 0.62, cascade_length * 0.21),
			Vector3(-radius - cascade_length * 0.25, radius * 0.54, cascade_length * 0.34),
			Vector3(-radius - cascade_length * 0.50, radius * 0.46, cascade_length * 0.46),
			Vector3(-radius - cascade_length * 0.76, radius * 0.38, cascade_length * 0.55),
			Vector3(-radius - cascade_length, radius * 0.29, cascade_length * 0.60),
		]
		for row_index in range(cascade_rows.size()):
			var row := cascade_rows[row_index] as Vector3
			var width_phase := sin(float(row_index) * 1.73 + 0.45)
			row.y *= 1.0 + width_phase * cascade_width_wave
			cascade_rows[row_index] = row
		for row_index in range(cascade_rows.size() - 1):
			var top := cascade_rows[row_index] as Vector3
			var bottom := cascade_rows[row_index + 1] as Vector3
			for vertex in [
				Vector3(-top.y, top.z, top.x),
				Vector3(bottom.y, bottom.z, bottom.x),
				Vector3(-bottom.y, bottom.z, bottom.x),
				Vector3(-top.y, top.z, top.x),
				Vector3(top.y, top.z, top.x),
				Vector3(bottom.y, bottom.z, bottom.x),
			]:
				st.set_normal(Vector3.UP)
				st.add_vertex(vertex)
	return st.commit()
