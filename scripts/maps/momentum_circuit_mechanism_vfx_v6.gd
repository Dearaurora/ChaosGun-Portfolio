extends Node3D
class_name MomentumCircuitMechanismVFXV6

const CYAN := Color("#52E5F5")
const CYAN_WHITE := Color("#D8FFFF")

var _controller: Node = null
var _config: Dictionary = {}
var _bridge_visuals: Dictionary = {}
var _teleport_pulses: Array[Dictionary] = []
var _elapsed := 0.0


func configure(controller: Node, teleporters: Array[Node3D], config: Dictionary) -> void:
	_controller = controller
	_config = config.duplicate(true)
	_build_bridge_visuals()
	_build_teleporter_pulses(teleporters)
	_apply_bridge_state()


func _process(delta: float) -> void:
	_elapsed += delta
	_apply_bridge_state()
	_update_teleporter_pulses(delta)


func get_debug_state() -> Dictionary:
	var controller_debug: Dictionary = {}
	if is_instance_valid(_controller) and _controller.has_method("get_debug_state"):
		controller_debug = _controller.call("get_debug_state") as Dictionary
	return {
		"visual_only": true,
		"bridge_visual_count": _bridge_visuals.size(),
		"endpoint_socket_count": _bridge_visuals.size() * 2,
		"teleporter_visual_count": _teleport_pulses.size(),
		"literal_arrow_count": 0,
		"text_node_count": 0,
		"state": String(controller_debug.get("state", "")),
		"active_bridge_id": String(controller_debug.get("active_bridge_id", "")),
		"next_bridge_id": String(controller_debug.get("next_bridge_id", "")),
	}


func _build_bridge_visuals() -> void:
	var width := float(_config.get("width", 4.0))
	var top_y := float(_config.get("top_y", 1.06))
	var thickness := float(_config.get("thickness", 0.18))
	for value: Variant in _config.get("bridges", []):
		var spec := value as Dictionary
		var bridge_id := String(spec.get("id", ""))
		var start := _point(spec.get("start_xz", []), top_y)
		var finish := _point(spec.get("end_xz", []), top_y)
		var direction := finish - start
		var length := Vector2(direction.x, direction.z).length()
		var root := Node3D.new()
		root.name = "LightBridgeVFX_%s" % bridge_id
		root.set_meta("bridge_id", bridge_id)
		root.set_meta("visual_only", true)
		add_child(root)

		var deck_material := _bridge_material(
			Color(_config.get("active_color", "#C8BBFF")).darkened(0.22),
			0.24
		)
		var deck_roots: Array[Node3D] = []
		var deck_meshes: Array[MeshInstance3D] = []
		for half_index in range(2):
			var origin := start if half_index == 0 else finish
			var half_direction := direction if half_index == 0 else -direction
			var half_root := Node3D.new()
			half_root.name = "BridgeExtension%d" % (half_index + 1)
			half_root.position = origin - Vector3.UP * thickness * 0.5
			half_root.rotation.y = atan2(half_direction.x, half_direction.z)
			root.add_child(half_root)
			var half_deck := MeshInstance3D.new()
			half_deck.name = "BridgeSurfaceHalf%d" % (half_index + 1)
			var half_mesh := BoxMesh.new()
			half_mesh.size = Vector3(width, thickness, length * 0.5)
			half_deck.mesh = half_mesh
			half_deck.position.z = length * 0.25
			half_deck.material_override = deck_material
			half_deck.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			half_root.add_child(half_deck)
			deck_roots.append(half_root)
			deck_meshes.append(half_deck)

		var sockets: Array[Dictionary] = []
		for socket_index in range(2):
			var socket_root := Node3D.new()
			socket_root.name = "EndpointDock%d" % (socket_index + 1)
			socket_root.position = (start if socket_index == 0 else finish) + Vector3.UP * 0.018
			var inward_direction := direction if socket_index == 0 else -direction
			socket_root.rotation.y = atan2(inward_direction.x, inward_direction.z)
			socket_root.set_meta("visual_only", true)
			root.add_child(socket_root)
			var dock_bed := MeshInstance3D.new()
			dock_bed.name = "RecessedDockBed"
			var dock_bed_mesh := BoxMesh.new()
			dock_bed_mesh.size = Vector3(width + 0.96, 0.038, 1.42)
			dock_bed.mesh = dock_bed_mesh
			dock_bed.position = Vector3(0.0, -0.028, 0.44)
			dock_bed.material_override = _bridge_material(Color("#29233F"), 0.015)
			dock_bed.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			dock_bed.set_meta("visual_only", true)
			socket_root.add_child(dock_bed)
			var socket_material := _bridge_material(Color(_config.get("dormant_color", "#4A435F")), 0.12)
			var back_bar := MeshInstance3D.new()
			back_bar.name = "DockBackBar"
			var back_mesh := BoxMesh.new()
			back_mesh.size = Vector3(width + 0.74, 0.070, 0.34)
			back_bar.mesh = back_mesh
			back_bar.position.z = -0.08
			back_bar.material_override = socket_material
			back_bar.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			back_bar.set_meta("visual_only", true)
			socket_root.add_child(back_bar)
			for side in [-1.0, 1.0]:
				var guide := MeshInstance3D.new()
				guide.name = "DockGuide"
				var guide_mesh := BoxMesh.new()
				guide_mesh.size = Vector3(0.30, 0.060, 1.28)
				guide.mesh = guide_mesh
				guide.position = Vector3(side * (width * 0.5 + 0.16), 0.0, 0.57)
				guide.material_override = socket_material
				guide.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				guide.set_meta("visual_only", true)
				socket_root.add_child(guide)
			var inner_lip := MeshInstance3D.new()
			inner_lip.name = "DockInnerLip"
			var lip_mesh := BoxMesh.new()
			lip_mesh.size = Vector3(width - 0.26, 0.040, 0.20)
			inner_lip.mesh = lip_mesh
			inner_lip.position = Vector3(0.0, 0.025, 1.08)
			inner_lip.material_override = socket_material
			inner_lip.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			inner_lip.set_meta("visual_only", true)
			socket_root.add_child(inner_lip)
			sockets.append({
				"root": socket_root,
				"mesh": back_bar,
				"material": socket_material,
			})

		_bridge_visuals[bridge_id] = {
			"root": root,
			"deck_roots": deck_roots,
			"deck_meshes": deck_meshes,
			"deck_material": deck_material,
			"sockets": sockets,
		}


func _build_teleporter_pulses(teleporters: Array[Node3D]) -> void:
	for teleporter: Node3D in teleporters:
		var pulse := MeshInstance3D.new()
		pulse.name = "TeleportArrivalPulse_%s" % String(teleporter.get("teleporter_id"))
		var pulse_mesh := TorusMesh.new()
		pulse_mesh.inner_radius = 2.35
		pulse_mesh.outer_radius = 2.48
		pulse_mesh.rings = 32
		pulse_mesh.ring_segments = 8
		pulse.mesh = pulse_mesh
		var material := _teleporter_material(0.0)
		pulse.material_override = material
		pulse.position = teleporter.position + Vector3.UP * 0.12
		pulse.set_meta("teleporter_id", String(teleporter.get("teleporter_id")))
		pulse.scale = Vector3.ONE * 0.1
		pulse.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(pulse)
		var ready_ring := MeshInstance3D.new()
		ready_ring.name = "TeleportReadyRing_%s" % String(teleporter.get("teleporter_id"))
		var ready_mesh := TorusMesh.new()
		ready_mesh.inner_radius = 2.10
		ready_mesh.outer_radius = 2.30
		ready_mesh.rings = 32
		ready_mesh.ring_segments = 8
		ready_ring.mesh = ready_mesh
		var ready_material := _teleporter_material(0.42)
		ready_ring.material_override = ready_material
		ready_ring.position = teleporter.position + Vector3.UP * 0.16
		ready_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(ready_ring)
		var cooldown_veil := MeshInstance3D.new()
		cooldown_veil.name = "TeleportCooldownVeil_%s" % String(teleporter.get("teleporter_id"))
		var veil_mesh := CylinderMesh.new()
		veil_mesh.top_radius = 2.28
		veil_mesh.bottom_radius = 2.28
		veil_mesh.height = 0.035
		veil_mesh.radial_segments = 40
		cooldown_veil.mesh = veil_mesh
		var veil_material := _cooldown_veil_material()
		cooldown_veil.material_override = veil_material
		cooldown_veil.position = teleporter.position + Vector3.UP * 0.145
		cooldown_veil.visible = false
		cooldown_veil.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(cooldown_veil)
		_teleport_pulses.append({
			"teleporter": teleporter,
			"mesh": pulse,
			"material": material,
			"ready_ring": ready_ring,
			"ready_material": ready_material,
			"cooldown_veil": cooldown_veil,
			"veil_material": veil_material,
			"time": 99.0,
		})
		if teleporter.has_signal("teleported"):
			teleporter.teleported.connect(_on_teleported)


func _apply_bridge_state() -> void:
	if not is_instance_valid(_controller) or not _controller.has_method("get_debug_state"):
		return
	var debug := _controller.call("get_debug_state") as Dictionary
	var state := String(debug.get("state", "ACTIVE"))
	var active_id := String(debug.get("active_bridge_id", ""))
	var next_id := String(debug.get("next_bridge_id", ""))
	var progress := float(debug.get("state_progress", 0.0))
	var active_color := Color(_config.get("active_color", "#C8BBFF"))
	var warning_color := Color(_config.get("warning_color", "#FFAE66"))
	var dormant_color := Color(_config.get("dormant_color", "#4A435F"))
	# State progress, rather than wall-clock time, keeps review captures repeatable
	# while still producing four readable pulses during the two-second warning.
	var warning_flash := 0.28 + 0.72 * (0.5 + 0.5 * cos(progress * TAU * 4.0))

	for bridge_id: String in _bridge_visuals:
		var visual := _bridge_visuals[bridge_id] as Dictionary
		var deck_roots := visual["deck_roots"] as Array
		var deck_meshes := visual["deck_meshes"] as Array
		var deck_material := visual["deck_material"] as StandardMaterial3D
		var extension := 0.0
		var deck_color := active_color
		var deck_energy := 0.24
		var active_alpha := clampf(float(_config.get("active_alpha", 0.44)), 0.2, 0.90)
		var deck_alpha := active_alpha
		if state == "SWITCHING":
			if bridge_id == active_id:
				extension = 1.0 - progress
				deck_color = warning_color.darkened(0.16)
				deck_energy = lerpf(0.48, 0.08, progress)
				deck_alpha = lerpf(maxf(active_alpha, 0.50), 0.08, progress)
			elif bridge_id == next_id:
				extension = progress
				deck_color = active_color.darkened(0.22)
				deck_energy = lerpf(0.10, 0.24, progress)
				deck_alpha = lerpf(0.10, active_alpha, progress)
		elif bridge_id == active_id:
			extension = 1.0
			deck_color = active_color.darkened(0.22)
			if state == "WARNING":
				deck_color = active_color.darkened(0.20).lerp(warning_color.darkened(0.14), warning_flash)
				deck_energy = lerpf(0.28, 0.62, warning_flash)
				deck_alpha = lerpf(active_alpha, minf(0.90, active_alpha + 0.14), warning_flash)
		for deck_root_value: Variant in deck_roots:
			var deck_root := deck_root_value as Node3D
			deck_root.scale = Vector3(1.0, 1.0, maxf(0.006, extension))
		for deck_mesh_value: Variant in deck_meshes:
			(deck_mesh_value as MeshInstance3D).visible = extension > 0.005
		_set_material(
			deck_material,
			deck_color,
			deck_energy,
			clampf(extension, 0.0, 1.0) * deck_alpha
		)

		for socket_value: Variant in visual["sockets"] as Array:
			var socket := socket_value as Dictionary
			var socket_material := socket["material"] as StandardMaterial3D
			var socket_color := dormant_color
			var socket_energy := 0.10
			if bridge_id == active_id:
				socket_color = active_color if state == "ACTIVE" else warning_color
				socket_energy = 0.32 if state == "ACTIVE" else lerpf(0.34, 0.78, warning_flash)
			elif bridge_id == next_id and (state == "WARNING" or state == "SWITCHING"):
				var next_pulse := 0.5 + 0.5 * cos(progress * TAU * 4.0)
				socket_color = active_color
				socket_energy = lerpf(0.22, 0.68, next_pulse)
			_set_material(socket_material, socket_color, socket_energy, 1.0)


func _update_teleporter_pulses(delta: float) -> void:
	for pulse_value: Variant in _teleport_pulses:
		var pulse := pulse_value as Dictionary
		_update_pad_cooldown_visual(pulse)
		var pulse_time := float(pulse["time"])
		if pulse_time >= 2.0:
			continue
		pulse_time += delta
		pulse["time"] = pulse_time
		var phase := clampf(pulse_time / 0.32, 0.0, 1.0)
		var mesh := pulse["mesh"] as MeshInstance3D
		mesh.scale = Vector3.ONE * lerpf(0.1, 1.25, phase)
		var material := pulse["material"] as StandardMaterial3D
		material.albedo_color = Color(CYAN, (1.0 - phase) * 0.34)


func _update_pad_cooldown_visual(pulse: Dictionary) -> void:
	var teleporter := pulse.get("teleporter") as Node
	if not is_instance_valid(teleporter) or not teleporter.has_method("get_debug_state"):
		return
	var debug := teleporter.call("get_debug_state") as Dictionary
	var duration := maxf(0.001, float(debug.get("landing_cooldown_seconds", 3.0)))
	var remaining := maxf(0.0, float(debug.get("landing_cooldown_remaining", 0.0)))
	var ready := 1.0 - clampf(remaining / duration, 0.0, 1.0)
	var ready_material := pulse["ready_material"] as StandardMaterial3D
	ready_material.albedo_color = Color(CYAN, lerpf(0.10, 0.42, ready))
	ready_material.emission_energy_multiplier = lerpf(0.16, 1.15, ready)
	var ready_ring := pulse["ready_ring"] as MeshInstance3D
	ready_ring.scale = Vector3.ONE * lerpf(0.94, 1.0, ready)
	var veil := pulse["cooldown_veil"] as MeshInstance3D
	veil.visible = remaining > 0.0
	var veil_material := pulse["veil_material"] as StandardMaterial3D
	veil_material.albedo_color = Color(Color("#17172A"), lerpf(0.0, 0.52, 1.0 - ready))


func _on_teleported(_character: BaseCharacter, _source_id: String, destination_id: String) -> void:
	for pulse_value: Variant in _teleport_pulses:
		var pulse := pulse_value as Dictionary
		var mesh := pulse["mesh"] as MeshInstance3D
		if String(mesh.get_meta("teleporter_id", "")) == destination_id:
			pulse["time"] = 0.0


func _bridge_material(color: Color, emission: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
	material.albedo_color = color
	material.emission_enabled = true
	material.emission = color
	material.emission_energy_multiplier = emission
	material.roughness = 0.76
	material.metallic = 0.02
	return material


func _teleporter_material(alpha: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color(CYAN, alpha)
	material.emission_enabled = true
	material.emission = CYAN_WHITE
	material.emission_energy_multiplier = 1.6
	return material


func _cooldown_veil_material() -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color(Color("#17172A"), 0.0)
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	return material


func _set_material(material: StandardMaterial3D, color: Color, energy: float, alpha: float) -> void:
	material.albedo_color = Color(color, alpha)
	material.emission = color
	material.emission_energy_multiplier = energy


func _point(value: Variant, y: float) -> Vector3:
	var values := value as Array
	return Vector3(float(values[0]), y, float(values[1]))
