extends Node3D
class_name MomentumCircuitMechanismVFX

## Dynamic, visual-only presentation for Momentum Circuit's pseudo-gravity
## corridor, three shootable activators, and four stabilizer anchors.

const MomentumCircuitLayoutScript = preload("res://scripts/maps/momentum_circuit_layout.gd")
const RuntimeGlobals = preload("res://scripts/globals/runtime_globals.gd")
const WARNING_SOUND := preload("res://assets/audio/scifi-sounds/Audio/forceField_001.ogg")
const ACTIVE_SOUND := preload("res://assets/audio/scifi-sounds/Audio/forceField_003.ogg")
const REVERSING_SOUND := preload("res://assets/audio/scifi-sounds/Audio/engineCircular_002.ogg")
const REJECTED_SOUND := preload("res://assets/audio/scifi-sounds/Audio/computerNoise_003.ogg")
const STABILIZED_SOUND := preload("res://assets/audio/scifi-sounds/Audio/forceField_000.ogg")

const CUE_Y := 1.16
const CORRIDOR_X_MIN := 2.0
const FLOW_LENGTH := 4.0
const FLOW_HALF_WIDTH := 0.16
const BOUNDARY_HALF_WIDTH := 0.10
const RIM_HALF_WIDTH := 0.12
const ANCHOR_OUTER_RADIUS := 5.5
const ANCHOR_CORE_RADIUS := 2.75

const CYAN := Color("#52E5F5")
const ORANGE := Color("#FF9A3D")
const FLOW_WARM := Color("#FFAE66")
const FLOW_COOL := Color("#22CDEB")

var _layout: Dictionary = {}
var _controller: Node = null
var _content_root: Node3D = null
var _boundary_cue: MeshInstance3D = null
var _boundary_material: ShaderMaterial = null
var _rim_cue: MeshInstance3D = null
var _rim_material: ShaderMaterial = null
var _flow_instances: MultiMeshInstance3D = null
var _flow_material: ShaderMaterial = null
var _flow_positions: Array[Vector3] = []
var _rim_segment_count := 0
var _activator_visuals: Dictionary = {}
var _anchor_visuals: Dictionary = {}
var _stabilized_character_ids: Dictionary = {}
var _state_audio: AudioStreamPlayer3D = null
var _interaction_audio: AudioStreamPlayer3D = null
var _anchor_audio: AudioStreamPlayer3D = null
var _last_interaction_activator_id := ""

var _state: StringName = &"IDLE"
var _direction := 1
var _pending_direction := 1
var _state_remaining := 0.0
var _activation_serial := 0
var _global_guard_remaining := 0.0
var _accepted_flash_remaining := 0.0
var _rejected_flash_remaining := 0.0
var _elapsed := 0.0
var _last_auto_bind_attempt := -10.0


func _ready() -> void:
	rebuild()
	call_deferred("_auto_bind_controller")


func _process(delta: float) -> void:
	var safe_delta := maxf(delta, 0.0)
	_elapsed = fmod(_elapsed + safe_delta, 3600.0)
	_accepted_flash_remaining = maxf(0.0, _accepted_flash_remaining - safe_delta)
	_rejected_flash_remaining = maxf(0.0, _rejected_flash_remaining - safe_delta)
	if not is_instance_valid(_controller) and _elapsed - _last_auto_bind_attempt >= 1.0:
		_auto_bind_controller()
	_sync_from_controller()
	_apply_dynamic_state()


func rebuild() -> void:
	if is_instance_valid(_content_root):
		remove_child(_content_root)
		_content_root.free()

	_layout = MomentumCircuitLayoutScript.load_default()
	_flow_positions.clear()
	_rim_segment_count = 0
	_activator_visuals.clear()
	_anchor_visuals.clear()
	set_meta("visual_only", true)
	set_meta("collision_owner", "Godot gameplay scene")
	set_meta("layout_source", MomentumCircuitLayoutScript.DEFAULT_PATH)
	if not is_in_group(&"momentum_circuit_mechanism_vfx"):
		add_to_group(&"momentum_circuit_mechanism_vfx")

	_content_root = Node3D.new()
	_content_root.name = "DynamicMechanismVisuals"
	_content_root.set_meta("visual_only", true)
	add_child(_content_root)
	if _layout.is_empty():
		push_error("Momentum Circuit mechanism VFX requires the validated layout")
		return

	_build_directional_cues()
	_build_activator_visuals()
	_build_anchor_visuals()
	_build_audio_feedback()
	_apply_dynamic_state()


func bind_controller(controller: Node) -> void:
	if controller == _controller:
		_sync_from_controller()
		return
	_disconnect_controller()
	_controller = controller if is_instance_valid(controller) else null
	if not is_instance_valid(_controller):
		return

	_connect_controller_signal(&"state_changed", Callable(self, "_on_controller_state_changed"))
	_connect_controller_signal(&"activation_accepted", Callable(self, "_on_activation_accepted"))
	_connect_controller_signal(&"activation_rejected", Callable(self, "_on_activation_rejected"))
	_connect_controller_signal(&"character_stabilized", Callable(self, "_on_character_stabilized"))
	_sync_from_controller()


func get_debug_state() -> Dictionary:
	return {
		"ready": not _layout.is_empty() and is_instance_valid(_boundary_cue) and not _flow_positions.is_empty(),
		"visual_only": bool(get_meta("visual_only", false)),
		"controller_valid": is_instance_valid(_controller),
		"controller_path": String(_controller.get_path()) if is_instance_valid(_controller) and _controller.is_inside_tree() else "",
		"controller_state": _state,
		"state": _state,
		"direction": _direction,
		"pending_direction": _pending_direction,
		"state_remaining": _state_remaining,
		"activation_serial": _activation_serial,
		"global_guard_remaining": _global_guard_remaining,
		"surface_fill_present": false,
		"literal_arrow_count": 0,
		"static_deck_rim_present": true,
		"dynamic_gravity_rim_separate": true,
		"boundary_cue_count": 1 if is_instance_valid(_boundary_cue) else 0,
		"flow_streak_count": _flow_positions.size(),
		"rim_segment_count": _rim_segment_count,
		"activator_visual_count": _activator_visuals.size(),
		"anchor_visual_count": _anchor_visuals.size(),
		"audio_player_count": _count_audio_players(_content_root),
		"stabilized_character_count": _stabilized_character_ids.size(),
		"collision_node_count": _count_collision_nodes(_content_root),
		"shadow_caster_count": _count_shadow_casters(_content_root),
	}


func _auto_bind_controller() -> void:
	_last_auto_bind_attempt = _elapsed
	if is_instance_valid(_controller) or not is_inside_tree():
		return
	var candidate := get_tree().get_first_node_in_group(&"momentum_circuit_gravity_controller")
	if candidate == null:
		candidate = _find_controller_candidate(get_tree().current_scene)
	if candidate:
		bind_controller(candidate)


func _find_controller_candidate(root: Node) -> Node:
	if root == null:
		return null
	if root.has_method("get_debug_state") and root.has_method("request_toggle"):
		return root
	for child: Node in root.get_children():
		var result := _find_controller_candidate(child)
		if result:
			return result
	return null


func _connect_controller_signal(signal_name: StringName, callback: Callable) -> void:
	if not is_instance_valid(_controller) or not _controller.has_signal(signal_name):
		return
	if not _controller.is_connected(signal_name, callback):
		_controller.connect(signal_name, callback)


func _disconnect_controller() -> void:
	if not is_instance_valid(_controller):
		_controller = null
		return
	var bindings := {
		&"state_changed": Callable(self, "_on_controller_state_changed"),
		&"activation_accepted": Callable(self, "_on_activation_accepted"),
		&"activation_rejected": Callable(self, "_on_activation_rejected"),
		&"character_stabilized": Callable(self, "_on_character_stabilized"),
	}
	for signal_name: StringName in bindings:
		var callback: Callable = bindings[signal_name]
		if _controller.has_signal(signal_name) and _controller.is_connected(signal_name, callback):
			_controller.disconnect(signal_name, callback)
	_controller = null


func _sync_from_controller() -> void:
	if not is_instance_valid(_controller) or not _controller.has_method("get_debug_state"):
		return
	var raw_state: Variant = _controller.call("get_debug_state")
	if not raw_state is Dictionary:
		return
	var debug := raw_state as Dictionary
	_state = StringName(String(debug.get("state", _state)).to_upper())
	_direction = _normalized_direction(int(debug.get("direction", _direction)))
	_pending_direction = _normalized_direction(int(debug.get("pending_direction", _direction)))
	_state_remaining = maxf(0.0, float(debug.get("state_remaining", 0.0)))
	_activation_serial = int(debug.get("activation_serial", _activation_serial))
	_global_guard_remaining = maxf(0.0, float(debug.get("global_guard_remaining", 0.0)))


func _on_controller_state_changed(
	_previous_state: StringName,
	state: StringName,
	direction: int,
	activation_serial: int
) -> void:
	_state = StringName(String(state).to_upper())
	_direction = _normalized_direction(direction)
	_activation_serial = activation_serial
	_sync_from_controller()
	_play_state_audio(_state)


func _on_activation_accepted(
	activator: Node3D,
	direction: int,
	_attacker: Node3D
) -> void:
	_direction = _normalized_direction(direction)
	_accepted_flash_remaining = 0.45
	_last_interaction_activator_id = _layout_id(activator)
	_sync_from_controller()


func _on_activation_rejected(_reason: StringName, activator: Node3D) -> void:
	_rejected_flash_remaining = 0.25
	_last_interaction_activator_id = _layout_id(activator)
	_play_one_shot(_interaction_audio, REJECTED_SOUND)


func _on_character_stabilized(character: Node3D, stabilized: bool) -> void:
	if not is_instance_valid(character):
		return
	var instance_id := character.get_instance_id()
	if stabilized:
		_stabilized_character_ids[instance_id] = true
		if is_instance_valid(_anchor_audio):
			_anchor_audio.position = to_local(character.global_position)
		_play_one_shot(_anchor_audio, STABILIZED_SOUND)
	else:
		_stabilized_character_ids.erase(instance_id)


func _build_directional_cues() -> void:
	var platform := _layout["platform"] as Dictionary
	var outer := MomentumCircuitLayoutScript.packed_vector2_array(
		platform.get("visual_top_outline_world_xz", platform["outline_world_xz"]),
		"platform.visual_top_outline_world_xz"
	)
	var holes: Array[PackedVector2Array] = []
	for hole_index in range((_layout["holes"] as Array).size()):
		var hole := (_layout["holes"] as Array)[hole_index] as Dictionary
		holes.append(
			MomentumCircuitLayoutScript.packed_vector2_array(
				hole.get("visual_top_outline_world_xz", hole["outline_world_xz"]),
				"holes[%d].visual_top_outline_world_xz" % hole_index
			)
		)

	_boundary_cue = MeshInstance3D.new()
	_boundary_cue.name = "GravityBoundaryPulse"
	_boundary_cue.mesh = _build_boundary_cue_mesh(platform, outer, holes)
	_boundary_cue.position.y = CUE_Y
	_boundary_material = _directional_cue_material(ORANGE, 3.8, 0.0)
	_boundary_cue.material_override = _boundary_material
	_boundary_cue.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_boundary_cue.set_meta("visual_only", true)
	_boundary_cue.set_meta("corridor_x_min", CORRIDOR_X_MIN)
	_content_root.add_child(_boundary_cue)

	_rim_cue = MeshInstance3D.new()
	_rim_cue.name = "GravityRimChase"
	_rim_cue.mesh = _build_rim_cue_mesh(outer)
	_rim_cue.position.y = CUE_Y + 0.025
	_rim_material = _directional_cue_material(FLOW_WARM, 5.4, 0.28)
	_rim_cue.material_override = _rim_material
	_rim_cue.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_rim_cue.set_meta("visual_only", true)
	_content_root.add_child(_rim_cue)

	_flow_material = _directional_cue_material(FLOW_COOL, 7.2, 0.56)
	var flow_mesh := _build_flow_streak_mesh()
	var flow_candidates := [
		Vector2(8.0, -28.0), Vector2(22.0, -25.0), Vector2(38.0, -21.0),
		Vector2(12.0, -16.0), Vector2(30.0, -13.0), Vector2(43.0, -7.0),
		Vector2(9.0, -2.0), Vector2(25.0, 1.0), Vector2(40.0, 4.0),
		Vector2(15.0, 9.0), Vector2(34.0, 12.0), Vector2(10.0, 18.0),
		Vector2(28.0, 20.0), Vector2(44.0, 24.0), Vector2(19.0, 29.0),
		Vector2(36.0, 33.0),
	]
	for center: Vector2 in flow_candidates:
		if not _is_walkable(center, outer, holes):
			continue
		if not _is_walkable(center + Vector2(FLOW_LENGTH * 0.55, 0.0), outer, holes):
			continue
		if not _is_walkable(center - Vector2(FLOW_LENGTH * 0.55, 0.0), outer, holes):
			continue
		_flow_positions.append(Vector3(center.x, CUE_Y + 0.09, center.y))

	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.use_custom_data = true
	multimesh.mesh = flow_mesh
	multimesh.instance_count = _flow_positions.size()
	for index in range(_flow_positions.size()):
		var length_scale := 0.72 + fmod(float(index) * 0.37, 0.42)
		var width_scale := 0.82 + fmod(float(index) * 0.23, 0.28)
		var basis := Basis.IDENTITY.scaled(Vector3(length_scale, 1.0, width_scale))
		multimesh.set_instance_transform(index, Transform3D(basis, _flow_positions[index]))
		multimesh.set_instance_custom_data(index, Color(float(index) / maxf(1.0, float(_flow_positions.size())), 0.0, 0.0, 0.0))
	_flow_instances = MultiMeshInstance3D.new()
	_flow_instances.name = "DirectionalFlowStreaks"
	_flow_instances.multimesh = multimesh
	_flow_instances.material_override = _flow_material
	_flow_instances.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_flow_instances.set_meta("visual_only", true)
	_content_root.add_child(_flow_instances)


func _build_boundary_cue_mesh(
	platform: Dictionary,
	outer: PackedVector2Array,
	holes: Array[PackedVector2Array]
) -> ArrayMesh:
	var bounds := platform["bounds_world_xz"] as Dictionary
	var minimum := MomentumCircuitLayoutScript.vector2(bounds["minimum"], "platform.bounds.minimum")
	var maximum := MomentumCircuitLayoutScript.vector2(bounds["maximum"], "platform.bounds.maximum")
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var z := floorf(minimum.y)
	while z < maximum.y:
		var next_z := minf(z + 0.72, maximum.y)
		var center := Vector2(CORRIDOR_X_MIN + BOUNDARY_HALF_WIDTH, (z + next_z) * 0.5)
		if _is_walkable(center, outer, holes):
			_add_top_quad(
				st,
				Vector2(CORRIDOR_X_MIN, z),
				Vector2(CORRIDOR_X_MIN + BOUNDARY_HALF_WIDTH * 2.0, z),
				Vector2(CORRIDOR_X_MIN + BOUNDARY_HALF_WIDTH * 2.0, next_z),
				Vector2(CORRIDOR_X_MIN, next_z)
			)
		z += 0.92
	return st.commit()


func _build_rim_cue_mesh(outer: PackedVector2Array) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	_rim_segment_count = 0
	for index in range(outer.size()):
		var a := outer[index]
		var b := outer[(index + 1) % outer.size()]
		if a.x < CORRIDOR_X_MIN or b.x < CORRIDOR_X_MIN or a.distance_to(b) < 0.05:
			continue
		var perpendicular := Vector2(-(b - a).y, (b - a).x).normalized() * RIM_HALF_WIDTH
		_add_top_quad(st, a - perpendicular, a + perpendicular, b + perpendicular, b - perpendicular)
		_rim_segment_count += 1
	return st.commit()


func _build_flow_streak_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	_add_top_quad(
		st,
		Vector2(-FLOW_LENGTH * 0.5, -FLOW_HALF_WIDTH),
		Vector2(FLOW_LENGTH * 0.5, -FLOW_HALF_WIDTH),
		Vector2(FLOW_LENGTH * 0.5, FLOW_HALF_WIDTH),
		Vector2(-FLOW_LENGTH * 0.5, FLOW_HALF_WIDTH)
	)
	return st.commit()


func _add_top_quad(st: SurfaceTool, a: Vector2, b: Vector2, c: Vector2, d: Vector2) -> void:
	for point in [a, c, b, a, d, c]:
		st.set_normal(Vector3.UP)
		st.add_vertex(Vector3(point.x, 0.0, point.y))


func _build_activator_visuals() -> void:
	for index in range((_layout["shockwave_nodes"] as Array).size()):
		var data := (_layout["shockwave_nodes"] as Array)[index] as Dictionary
		var root := Node3D.new()
		root.name = "ActivatorVFX%02d" % (index + 1)
		root.position = MomentumCircuitLayoutScript.vector3(
			data["position_world"],
			"shockwave_nodes[%d].position_world" % index
		)
		root.set_meta("layout_id", String(data["id"]))
		root.set_meta("visual_only", true)
		_content_root.add_child(root)

		var radius := _component_radius(data)
		var material := _emissive_alpha_material(ORANGE, 0.72, 1.3)
		var ring := MeshInstance3D.new()
		ring.name = "ActivatorPulseRing"
		var torus := TorusMesh.new()
		torus.inner_radius = radius * 0.70
		torus.outer_radius = radius * 0.96
		torus.rings = 36
		torus.ring_segments = 9
		ring.mesh = torus
		ring.position.y = 0.18
		ring.material_override = material
		ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(ring)
		_activator_visuals[String(data["id"])] = {
			"root": root,
			"ring": ring,
			"material": material,
			"activator": _find_gameplay_node_by_layout_id(&"momentum_circuit_gravity_activator", String(data["id"])),
			"base_scale": Vector3.ONE,
			"phase": float(index) * 1.71,
		}


func _build_anchor_visuals() -> void:
	for index in range((_layout["portals"] as Array).size()):
		var data := (_layout["portals"] as Array)[index] as Dictionary
		var root := Node3D.new()
		root.name = "StabilityAnchorVFX%02d" % (index + 1)
		root.position = MomentumCircuitLayoutScript.vector3(
			data["position_world"],
			"portals[%d].position_world" % index
		)
		root.set_meta("layout_id", String(data["id"]))
		root.set_meta("visual_only", true)
		_content_root.add_child(root)

		var radius_material := _emissive_alpha_material(CYAN, 0.12, 0.55)
		var radius_ring := MeshInstance3D.new()
		radius_ring.name = "StabilityOuterRadius"
		radius_ring.mesh = _build_annulus_mesh(ANCHOR_OUTER_RADIUS - 0.24, ANCHOR_OUTER_RADIUS, 64)
		radius_ring.position.y = 0.115
		radius_ring.material_override = radius_material
		radius_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(radius_ring)

		var core_material := _emissive_alpha_material(CYAN, 0.58, 1.1)
		var core_ring := MeshInstance3D.new()
		core_ring.name = "StabilityCoreRing"
		core_ring.mesh = _build_annulus_mesh(ANCHOR_CORE_RADIUS - 0.18, ANCHOR_CORE_RADIUS, 52)
		core_ring.position.y = 0.14
		core_ring.material_override = core_material
		core_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(core_ring)

		var beam_material := _emissive_alpha_material(CYAN, 0.12, 1.15)
		var beam := MeshInstance3D.new()
		beam.name = "StabilityLightColumn"
		var beam_mesh := CylinderMesh.new()
		beam_mesh.top_radius = 0.10
		beam_mesh.bottom_radius = 0.42
		beam_mesh.height = 3.8
		beam_mesh.radial_segments = 20
		beam_mesh.rings = 1
		beam.mesh = beam_mesh
		beam.position.y = 2.05
		beam.material_override = beam_material
		beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(beam)

		_anchor_visuals[String(data["id"])] = {
			"root": root,
			"radius_ring": radius_ring,
			"core_ring": core_ring,
			"radius_material": radius_material,
			"core_material": core_material,
			"beam": beam,
			"beam_material": beam_material,
			"phase": float(index) * 1.37,
		}


func _apply_dynamic_state() -> void:
	if (
		not is_instance_valid(_boundary_material)
		or not is_instance_valid(_rim_material)
		or not is_instance_valid(_flow_material)
	):
		return
	var state_text := String(_state).to_upper()
	var blink := 0.5 + 0.5 * sin(_elapsed * 11.0)
	var boundary_intensity := 0.0
	var rim_intensity := 0.015
	var flow_intensity := 0.0
	var displayed_direction := _direction

	match state_text:
		"WARNING":
			boundary_intensity = lerpf(0.32, 0.72, blink)
			rim_intensity = lerpf(0.18, 0.48, blink)
			flow_intensity = lerpf(0.08, 0.28, blink)
		"ACTIVE":
			boundary_intensity = 0.0
			rim_intensity = 0.80 + blink * 0.16
			flow_intensity = 0.88 + blink * 0.12
		"REVERSING":
			boundary_intensity = lerpf(0.28, 0.58, blink)
			rim_intensity = lerpf(0.08, 0.22, blink)
			flow_intensity = 0.0
			if _state_remaining <= 0.12:
				displayed_direction = _pending_direction
				flow_intensity = 0.06
		"RECOVERY":
			var recovery_ratio := clampf(_state_remaining / 0.75, 0.0, 1.0)
			boundary_intensity = 0.10 * recovery_ratio
			rim_intensity = lerpf(0.015, 0.42, recovery_ratio)
			flow_intensity = 0.48 * recovery_ratio
		_:
			boundary_intensity = 0.0
			rim_intensity = 0.015
			flow_intensity = 0.0

	if _accepted_flash_remaining > 0.0:
		boundary_intensity = minf(0.82, boundary_intensity + _accepted_flash_remaining * 0.75)
		rim_intensity = minf(1.0, rim_intensity + _accepted_flash_remaining * 0.9)

	for material: ShaderMaterial in [_boundary_material, _rim_material, _flow_material]:
		material.set_shader_parameter("direction", float(displayed_direction))
	_boundary_material.set_shader_parameter("intensity", boundary_intensity)
	_rim_material.set_shader_parameter("intensity", rim_intensity)
	_flow_material.set_shader_parameter("intensity", flow_intensity)

	for layout_id: String in _activator_visuals:
		var entry_value: Variant = _activator_visuals[layout_id]
		var entry := entry_value as Dictionary
		var ring := entry["ring"] as MeshInstance3D
		var material := entry["material"] as StandardMaterial3D
		var phase := float(entry["phase"])
		var pulse := 1.0 + sin(_elapsed * 3.4 + phase) * 0.035
		var activator := entry.get("activator", null) as Node
		if not is_instance_valid(activator):
			activator = _find_gameplay_node_by_layout_id(&"momentum_circuit_gravity_activator", layout_id)
			entry["activator"] = activator
		var ready_factor := _activator_ready_factor(activator)
		if _global_guard_remaining > 0.0:
			ready_factor *= 0.52
		var is_interaction_target := layout_id == _last_interaction_activator_id
		if is_interaction_target and _accepted_flash_remaining > 0.0:
			pulse += _accepted_flash_remaining * 0.34
			ready_factor = 1.0
		if is_interaction_target and _rejected_flash_remaining > 0.0:
			pulse += blink * 0.08
			ready_factor *= 0.22 + blink * 0.22
		ring.scale = (entry["base_scale"] as Vector3) * pulse
		material.albedo_color = Color(ORANGE, 0.16 + ready_factor * 0.66)
		material.emission_energy_multiplier = 0.28 + ready_factor * 1.45

	var anchor_active := not _stabilized_character_ids.is_empty()
	for entry_value: Variant in _anchor_visuals.values():
		var entry := entry_value as Dictionary
		var phase := float(entry["phase"])
		var radius_ring := entry["radius_ring"] as MeshInstance3D
		var core_ring := entry["core_ring"] as MeshInstance3D
		var radius_material := entry["radius_material"] as StandardMaterial3D
		var core_material := entry["core_material"] as StandardMaterial3D
		var beam := entry["beam"] as MeshInstance3D
		var beam_material := entry["beam_material"] as StandardMaterial3D
		var wave := 0.5 + 0.5 * sin(_elapsed * (4.2 if anchor_active else 1.7) + phase)
		radius_ring.scale = Vector3.ONE * (1.0 + wave * (0.018 if anchor_active else 0.006))
		core_ring.scale = Vector3.ONE * (1.0 + wave * (0.042 if anchor_active else 0.018))
		radius_material.albedo_color = Color(CYAN, 0.15 + wave * (0.18 if anchor_active else 0.05))
		core_material.albedo_color = Color(CYAN, 0.55 + wave * (0.34 if anchor_active else 0.16))
		core_material.emission_energy_multiplier = 0.8 + wave * (1.25 if anchor_active else 0.55)
		beam.scale = Vector3(1.0 + wave * 0.04, 0.96 + wave * 0.08, 1.0 + wave * 0.04)
		beam_material.albedo_color = Color(CYAN, 0.08 + wave * (0.16 if anchor_active else 0.06))
		beam_material.emission_energy_multiplier = 0.75 + wave * (1.10 if anchor_active else 0.45)


func _directional_cue_material(color: Color, speed: float, phase_scale: float) -> ShaderMaterial:
	var shader := Shader.new()
	shader.code = """
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_mix;

uniform vec4 cue_color : source_color = vec4(1.0, 0.682, 0.4, 1.0);
uniform float intensity : hint_range(0.0, 1.0) = 0.0;
uniform float direction = 1.0;
uniform float speed = 5.0;
uniform float phase_scale = 0.0;
varying vec3 world_position;
varying float instance_phase;

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	instance_phase = INSTANCE_CUSTOM.x;
}

void fragment() {
	float coordinate = world_position.x * 0.82 * direction - TIME * speed + instance_phase * phase_scale * 6.283185;
	float wave = 0.5 + 0.5 * sin(coordinate);
	float moving_head = pow(wave, 5.0);
	float visibility = 0.34 + moving_head * 0.66;
	ALBEDO = cue_color.rgb;
	EMISSION = cue_color.rgb * (0.50 + intensity * 1.85);
	ALPHA = clamp(cue_color.a * intensity * visibility, 0.0, 0.94);
}
"""
	var material := ShaderMaterial.new()
	material.shader = shader
	material.set_shader_parameter("cue_color", color)
	material.set_shader_parameter("intensity", 0.0)
	material.set_shader_parameter("direction", 1.0)
	material.set_shader_parameter("speed", speed)
	material.set_shader_parameter("phase_scale", phase_scale)
	material.render_priority = 2
	return material


func _build_annulus_mesh(inner_radius: float, outer_radius: float, segments: int) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for index in range(segments):
		var angle_a := TAU * float(index) / float(segments)
		var angle_b := TAU * float(index + 1) / float(segments)
		var outer_a := Vector3(cos(angle_a) * outer_radius, 0.0, sin(angle_a) * outer_radius)
		var outer_b := Vector3(cos(angle_b) * outer_radius, 0.0, sin(angle_b) * outer_radius)
		var inner_a := Vector3(cos(angle_a) * inner_radius, 0.0, sin(angle_a) * inner_radius)
		var inner_b := Vector3(cos(angle_b) * inner_radius, 0.0, sin(angle_b) * inner_radius)
		for vertex in [outer_a, outer_b, inner_b, outer_a, inner_b, inner_a]:
			st.set_normal(Vector3.UP)
			st.add_vertex(vertex)
	return st.commit()


func _build_audio_feedback() -> void:
	_state_audio = _create_audio_player("GravityStateAudio", Vector3(22.0, 3.0, 0.0), -8.0)
	_interaction_audio = _create_audio_player("GravityInteractionAudio", Vector3(22.0, 2.0, 0.0), -7.0)
	_anchor_audio = _create_audio_player("StabilityAnchorAudio", Vector3.ZERO, -10.0)


func _create_audio_player(player_name: String, local_position: Vector3, volume_db: float) -> AudioStreamPlayer3D:
	var player := AudioStreamPlayer3D.new()
	player.name = player_name
	player.position = local_position
	player.volume_db = volume_db
	player.max_distance = 105.0
	player.unit_size = 18.0
	_content_root.add_child(player)
	return player


func _play_state_audio(state: StringName) -> void:
	match String(state).to_upper():
		"WARNING":
			_play_one_shot(_state_audio, WARNING_SOUND)
		"ACTIVE":
			_play_one_shot(_state_audio, ACTIVE_SOUND)
		"REVERSING":
			_play_one_shot(_state_audio, REVERSING_SOUND)


func _play_one_shot(player: AudioStreamPlayer3D, stream: AudioStream) -> void:
	if not is_instance_valid(player) or stream == null or RuntimeGlobals.runtime_audio_disabled():
		return
	player.stop()
	player.stream = stream
	player.play()


func _layout_id(node: Node) -> String:
	if not is_instance_valid(node):
		return ""
	return String(node.get_meta("layout_id", ""))


func _find_gameplay_node_by_layout_id(group_name: StringName, layout_id: String) -> Node:
	if not is_inside_tree():
		return null
	for candidate: Node in get_tree().get_nodes_in_group(group_name):
		if _layout_id(candidate) == layout_id:
			return candidate
	return null


func _activator_ready_factor(activator: Node) -> float:
	if not is_instance_valid(activator) or not activator.has_method("get_debug_state"):
		return 1.0
	var debug := activator.call("get_debug_state") as Dictionary
	var duration := maxf(0.001, float(debug.get("cooldown_seconds", 8.0)))
	var remaining := maxf(0.0, float(debug.get("cooldown_remaining", 0.0)))
	if remaining <= 0.0:
		return 1.0
	return lerpf(0.18, 0.72, 1.0 - clampf(remaining / duration, 0.0, 1.0))


func _component_radius(data: Dictionary) -> float:
	var bounds := data["component_bounds_xywh_px"] as Array
	var projection := _layout["projection"] as Dictionary
	var diameter_x := float(bounds[2]) * float(projection["world_units_per_pixel_x"])
	var diameter_z := float(bounds[3]) * float(projection["world_units_per_pixel_z"])
	return maxf(0.8, (diameter_x + diameter_z) * 0.25)


func _is_walkable(
	point: Vector2,
	outer: PackedVector2Array,
	holes: Array[PackedVector2Array]
) -> bool:
	if point.x < CORRIDOR_X_MIN or not Geometry2D.is_point_in_polygon(point, outer):
		return false
	for hole: PackedVector2Array in holes:
		if Geometry2D.is_point_in_polygon(point, hole):
			return false
	return true


func _emissive_alpha_material(
	color: Color,
	alpha: float,
	emission_energy: float
) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(color, alpha)
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.emission_enabled = true
	material.emission = color
	material.emission_energy_multiplier = emission_energy
	material.roughness = 0.74
	material.render_priority = 2
	return material


func _normalized_direction(value: int) -> int:
	return 1 if value >= 0 else -1


func _count_collision_nodes(root: Node) -> int:
	if root == null:
		return 0
	var count := 1 if root is CollisionObject3D or root is CollisionShape3D else 0
	for child: Node in root.get_children():
		count += _count_collision_nodes(child)
	return count


func _count_shadow_casters(root: Node) -> int:
	if root == null:
		return 0
	var count := 0
	if root is GeometryInstance3D:
		var geometry := root as GeometryInstance3D
		if geometry.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_OFF:
			count += 1
	for child: Node in root.get_children():
		count += _count_shadow_casters(child)
	return count


func _count_audio_players(root: Node) -> int:
	if root == null:
		return 0
	var count := 1 if root is AudioStreamPlayer or root is AudioStreamPlayer3D else 0
	for child: Node in root.get_children():
		count += _count_audio_players(child)
	return count
