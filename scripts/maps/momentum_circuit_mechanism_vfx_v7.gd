extends "res://scripts/maps/momentum_circuit_mechanism_vfx_v6.gd"
class_name MomentumCircuitMechanismVFXV7

const RuntimeGlobals = preload("res://scripts/globals/runtime_globals.gd")
const BRIDGE_WHITE := Color("#EAE4FF")
const BRIDGE_LAVENDER := Color("#C8BBFF")
const TELEPORT_CYAN := Color("#52E5F5")
const TELEPORT_WHITE := Color("#D8FFFF")
const WARNING_ORANGE := Color("#FFAE66")
const AUDIO_RATE := 22050

var _production_config: Dictionary = {}
var _teleporters_by_id: Dictionary = {}
var _cooldown_segments: Dictionary = {}
var _bridge_detail_materials: Array[StandardMaterial3D] = []
var _bridge_scan_bars: Dictionary = {}
var _bridge_unified_surfaces: Dictionary = {}
var _active_trails: Array[Dictionary] = []
var _opening_remaining := 0.0
var _opening_duration := 1.35
var _last_state := ""
var _warning_pulse_index := 0
var _last_trail_key := ""
var _last_trail_msec := 0
var _hum_player: AudioStreamPlayer3D = null
var _event_player: AudioStreamPlayer3D = null
var _teleport_player: AudioStreamPlayer3D = null
var _hum_stream: AudioStreamWAV = null
var _warning_stream: AudioStreamWAV = null
var _switch_stream: AudioStreamWAV = null
var _lock_stream: AudioStreamWAV = null
var _teleport_stream: AudioStreamWAV = null
var _ready_stream: AudioStreamWAV = null
var _reject_stream: AudioStreamWAV = null


func configure(controller: Node, teleporters: Array[Node3D], production_config: Dictionary) -> void:
	_production_config = production_config.duplicate(true)
	var bridge_config := _production_config.get("light_bridges", {}) as Dictionary
	super.configure(controller, teleporters, bridge_config)
	_opening_duration = float(bridge_config.get("opening_scan_seconds", 1.35))
	_opening_remaining = _opening_duration
	_build_bridge_detail_layers()
	_build_eight_segment_cooldown_rings(teleporters)
	_build_audio_players()
	for teleporter: Node3D in teleporters:
		var id := String(teleporter.get("teleporter_id"))
		_teleporters_by_id[id] = teleporter
		if teleporter.has_signal("teleported"):
			teleporter.teleported.connect(_on_v7_teleported)
		if teleporter.has_signal("teleport_rejected"):
			teleporter.teleport_rejected.connect(_on_teleport_rejected)
		if teleporter.has_signal("landing_cooldown_finished"):
			teleporter.landing_cooldown_finished.connect(_on_landing_cooldown_finished)
	_apply_v7_bridge_details()


func _process(delta: float) -> void:
	super._process(delta)
	_opening_remaining = maxf(0.0, _opening_remaining - maxf(0.0, delta))
	_apply_v7_bridge_details()
	_update_cooldown_segments()
	_update_teleport_trails(delta)
	_update_audio_state()

func _exit_tree() -> void:
	for player: AudioStreamPlayer3D in [_hum_player, _event_player, _teleport_player]:
		if is_instance_valid(player):
			player.stop()
			player.stream = null
	_hum_stream = null
	_warning_stream = null
	_switch_stream = null
	_lock_stream = null
	_teleport_stream = null
	_ready_stream = null
	_reject_stream = null


func get_debug_state() -> Dictionary:
	var debug := super.get_debug_state()
	debug["visual_version"] = 7
	debug["bridge_visual_layers"] = 3
	debug["bridge_visual_width"] = float(
		(_production_config.get("light_bridges", {}) as Dictionary).get("visual_width", 4.0)
	)
	debug["bridge_scan_bar_count"] = _bridge_scan_bars.size() * 2
	debug["teleport_trail_enabled"] = true
	debug["active_teleport_trail_count"] = _active_trails.size()
	debug["cooldown_ring_segments"] = 8
	debug["cooldown_segment_count"] = _cooldown_segments.size() * 8
	debug["opening_scan_active"] = _opening_remaining > 0.0
	debug["audio_player_count"] = 3
	debug["active_hum_playing"] = is_instance_valid(_hum_player) and _hum_player.playing
	debug["event_audio_playing"] = is_instance_valid(_event_player) and _event_player.playing
	debug["teleport_audio_playing"] = is_instance_valid(_teleport_player) and _teleport_player.playing
	return debug


func _build_bridge_detail_layers() -> void:
	var gameplay_width := float(_config.get("width", 4.0))
	var width := maxf(
		gameplay_width,
		float(_config.get("visual_width", gameplay_width))
	)
	var thickness := float(_config.get("thickness", 0.18))
	var active_color := Color(_config.get("active_color", "#C8BBFF"))
	for bridge_id: String in _bridge_visuals:
		var visual := _bridge_visuals[bridge_id] as Dictionary
		var spec := _bridge_spec(bridge_id)
		var start := _point(spec.get("start_xz", []), float(_config.get("top_y", 1.06)))
		var finish := _point(spec.get("end_xz", []), float(_config.get("top_y", 1.06)))
		var direction := finish - start
		var span_length := Vector2(direction.x, direction.z).length()
		var deck_roots := visual["deck_roots"] as Array
		var deck_meshes := visual["deck_meshes"] as Array
		var edge_material := _detail_material(BRIDGE_WHITE.darkened(0.05), 0.42, 0.90)
		var core_material := _detail_material(active_color.darkened(0.08), 0.38, 0.30)
		var scan_material := _detail_material(TELEPORT_WHITE, 0.90, 0.58)
		var rib_material := _detail_material(BRIDGE_WHITE.darkened(0.16), 0.24, 0.48)
		var center_material := _detail_material(Color("#41395F"), 0.05, 0.68)
		var skirt_material := _detail_material(Color("#352C55"), 0.04, 0.92)
		var ribbon_material := _detail_material(BRIDGE_LAVENDER, 1.15, 0.26)
		var lane_material := _detail_material(TELEPORT_WHITE, 0.74, 0.52)
		_bridge_detail_materials.append_array([
			edge_material,
			core_material,
			scan_material,
			rib_material,
			center_material,
			skirt_material,
			ribbon_material,
			lane_material,
		])
		var scan_bars: Array[MeshInstance3D] = []
		var unified_surface := MeshInstance3D.new()
		unified_surface.name = "UnifiedBridgeSurface"
		var unified_mesh := BoxMesh.new()
		unified_mesh.size = Vector3(width - 0.42, 0.075, span_length + 0.18)
		unified_surface.mesh = unified_mesh
		unified_surface.position = (start + finish) * 0.5 + Vector3.UP * 0.045
		unified_surface.rotation.y = atan2(direction.x, direction.z)
		unified_surface.material_override = _detail_material(BRIDGE_LAVENDER.darkened(0.24), 0.20, 0.82)
		unified_surface.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		unified_surface.set_meta("visual_only", true)
		add_child(unified_surface)
		_bridge_unified_surfaces[bridge_id] = unified_surface
		for index in range(deck_roots.size()):
			var half_root := deck_roots[index] as Node3D
			# The collision remains flush at the canonical 1.06u height.  Raising
			# only the energy presentation gives the bridge a readable hover gap
			# above the deck and hole rim without becoming gameplay geometry.
			half_root.position.y += 0.065
			var deck := deck_meshes[index] as MeshInstance3D
			var deck_box := deck.mesh as BoxMesh
			deck_box.size.x = width
			var half_length := deck_box.size.z
			for side in [-1.0, 1.0]:
				var side_skirt := MeshInstance3D.new()
				side_skirt.name = "SuspendedSideSkirt"
				var skirt_mesh := BoxMesh.new()
				skirt_mesh.size = Vector3(0.26, 0.19, half_length)
				side_skirt.mesh = skirt_mesh
				side_skirt.position = Vector3(
					side * (width * 0.5 - 0.13),
					-thickness * 0.30,
					half_length * 0.5
				)
				side_skirt.material_override = skirt_material
				side_skirt.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				side_skirt.set_meta("visual_only", true)
				half_root.add_child(side_skirt)
				var edge := MeshInstance3D.new()
				edge.name = "FlushFrameEdge"
				var edge_mesh := BoxMesh.new()
				edge_mesh.size = Vector3(0.18, 0.045, half_length)
				edge.mesh = edge_mesh
				edge.position = Vector3(side * (width * 0.5 - 0.14), thickness * 0.58, half_length * 0.5)
				edge.material_override = edge_material
				edge.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				edge.set_meta("visual_only", true)
				half_root.add_child(edge)
				var safety_ribbon := MeshInstance3D.new()
				safety_ribbon.name = "MagneticSafetyRibbon"
				var ribbon_mesh := BoxMesh.new()
				ribbon_mesh.size = Vector3(0.075, 0.46, half_length)
				safety_ribbon.mesh = ribbon_mesh
				safety_ribbon.position = Vector3(
					side * (width * 0.5 + 0.10),
					thickness * 0.58 + 0.20,
					half_length * 0.5
				)
				safety_ribbon.material_override = ribbon_material
				safety_ribbon.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				safety_ribbon.set_meta("visual_only", true)
				half_root.add_child(safety_ribbon)
			var core := MeshInstance3D.new()
			core.name = "TranslucentEnergyCore"
			var core_mesh := BoxMesh.new()
			core_mesh.size = Vector3(width - 0.64, 0.032, half_length)
			core.mesh = core_mesh
			core.position = Vector3(0.0, thickness * 0.60, half_length * 0.5)
			core.material_override = core_material
			core.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			core.set_meta("visual_only", true)
			half_root.add_child(core)
			var center_channel := MeshInstance3D.new()
			center_channel.name = "EnergyCenterChannel"
			var center_mesh := BoxMesh.new()
			center_mesh.size = Vector3(0.11, 0.038, half_length)
			center_channel.mesh = center_mesh
			center_channel.position = Vector3(0.0, thickness * 0.69, half_length * 0.5)
			center_channel.material_override = center_material
			center_channel.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			center_channel.set_meta("visual_only", true)
			half_root.add_child(center_channel)
			for lane_side in [-1.0, 1.0]:
				var energy_lane := MeshInstance3D.new()
				energy_lane.name = "TransportEnergyLane"
				var lane_mesh := BoxMesh.new()
				lane_mesh.size = Vector3(0.16, 0.034, half_length)
				energy_lane.mesh = lane_mesh
				energy_lane.position = Vector3(
					lane_side * width * 0.24,
					thickness * 0.70,
					half_length * 0.5
				)
				energy_lane.material_override = lane_material
				energy_lane.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				energy_lane.set_meta("visual_only", true)
				half_root.add_child(energy_lane)
			var center_lock := MeshInstance3D.new()
			center_lock.name = "BridgeCenterLock"
			var lock_mesh := BoxMesh.new()
			lock_mesh.size = Vector3(width + 0.22, 0.065, 0.82)
			center_lock.mesh = lock_mesh
			center_lock.position = Vector3(
				0.0,
				thickness * 0.68,
				maxf(0.42, half_length - 0.41)
			)
			center_lock.material_override = edge_material
			center_lock.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			center_lock.set_meta("visual_only", true)
			half_root.add_child(center_lock)
			for rib_index in range(1, 5):
				var rib := MeshInstance3D.new()
				rib.name = "EnergyCoreRib%02d" % rib_index
				var rib_mesh := BoxMesh.new()
				rib_mesh.size = Vector3(width - 0.72, 0.025, 0.085)
				rib.mesh = rib_mesh
				rib.position = Vector3(
					0.0,
					thickness * 0.66,
					half_length * float(rib_index) / 5.0
				)
				rib.material_override = rib_material
				rib.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				rib.set_meta("visual_only", true)
				half_root.add_child(rib)
			var scan_bar := MeshInstance3D.new()
			scan_bar.name = "DeploymentScanBand"
			var scan_mesh := BoxMesh.new()
			scan_mesh.size = Vector3(width - 0.30, 0.042, 0.22)
			scan_bar.mesh = scan_mesh
			scan_bar.position = Vector3(0.0, thickness * 0.72, 0.18)
			scan_bar.material_override = scan_material
			scan_bar.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			scan_bar.set_meta("visual_only", true)
			half_root.add_child(scan_bar)
			scan_bars.append(scan_bar)
		_bridge_scan_bars[bridge_id] = scan_bars


func _build_eight_segment_cooldown_rings(teleporters: Array[Node3D]) -> void:
	for pulse_value: Variant in _teleport_pulses:
		var pulse := pulse_value as Dictionary
		var legacy_ring := pulse.get("ready_ring") as MeshInstance3D
		if legacy_ring:
			legacy_ring.visible = false
	for teleporter: Node3D in teleporters:
		var id := String(teleporter.get("teleporter_id"))
		var root := Node3D.new()
		root.name = "EightSegmentRecharge_%s" % id
		root.position = teleporter.position + Vector3.UP * 0.175
		root.set_meta("visual_only", true)
		add_child(root)
		var segments: Array[Dictionary] = []
		for index in range(8):
			var angle := -PI * 0.5 + TAU * float(index) / 8.0
			var segment := MeshInstance3D.new()
			segment.name = "RechargeSegment%02d" % (index + 1)
			var mesh := BoxMesh.new()
			mesh.size = Vector3(1.32, 0.036, 0.38)
			segment.mesh = mesh
			segment.position = Vector3(cos(angle) * 2.30, 0.0, sin(angle) * 2.30)
			# Keep each of the eight blocks tangent to the ring.  The previous
			# radial orientation read as a sunburst rather than a recharge dial.
			segment.rotation.y = -angle - PI * 0.5
			var material := _detail_material(TELEPORT_CYAN, 1.10, 0.48)
			segment.material_override = material
			segment.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			segment.set_meta("visual_only", true)
			root.add_child(segment)
			segments.append({"mesh": segment, "material": material})
		_cooldown_segments[id] = {"teleporter": teleporter, "segments": segments}


func _apply_v7_bridge_details() -> void:
	if not is_instance_valid(_controller) or not _controller.has_method("get_debug_state"):
		return
	var debug := _controller.call("get_debug_state") as Dictionary
	var state := String(debug.get("state", "ACTIVE"))
	var active_id := String(debug.get("active_bridge_id", ""))
	var next_id := String(debug.get("next_bridge_id", ""))
	var progress := float(debug.get("state_progress", 0.0))
	var opening_progress := 1.0 - clampf(_opening_remaining / maxf(_opening_duration, 0.001), 0.0, 1.0)
	for bridge_id: String in _bridge_unified_surfaces:
		var surface := _bridge_unified_surfaces[bridge_id] as MeshInstance3D
		surface.visible = bridge_id == active_id and state != "SWITCHING"
		if surface.visible:
			var material := surface.material_override as StandardMaterial3D
			if state == "WARNING":
				var warning_pulse := 0.55 + 0.45 * absf(sin(progress * PI * 4.0))
				_set_material(
					material,
					WARNING_ORANGE.darkened(0.10),
					lerpf(0.42, 0.88, warning_pulse),
					lerpf(0.82, 0.94, warning_pulse)
				)
			else:
				_set_material(material, BRIDGE_LAVENDER.darkened(0.24), 0.20, 0.82)
	for bridge_id: String in _bridge_scan_bars:
		var bars := _bridge_scan_bars[bridge_id] as Array
		for index in range(bars.size()):
			var bar := bars[index] as MeshInstance3D
			var visible_scan := false
			var scan_progress := 0.0
			if bridge_id == active_id and _opening_remaining > 0.0:
				visible_scan = true
				scan_progress = fposmod(opening_progress * 1.35 + float(index) * 0.12, 1.0)
			elif state == "SWITCHING" and bridge_id == next_id:
				visible_scan = true
				scan_progress = clampf(progress, 0.0, 1.0)
			bar.visible = visible_scan
			if visible_scan:
				var parent_root := bar.get_parent() as Node3D
				var energy_core := parent_root.get_node_or_null("TranslucentEnergyCore") as MeshInstance3D
				var core_box := energy_core.mesh as BoxMesh if energy_core else null
				var length := core_box.size.z if core_box else 1.0
				bar.position.z = lerpf(0.16, maxf(0.16, length - 0.16), scan_progress)
		if bridge_id == next_id and _opening_remaining > 0.0:
			var visual := _bridge_visuals[bridge_id] as Dictionary
			for socket_value: Variant in visual["sockets"] as Array:
				var socket := socket_value as Dictionary
				var socket_material := socket["material"] as StandardMaterial3D
				var pulse := 0.5 + 0.5 * sin(opening_progress * PI * 4.0)
				_set_material(socket_material, BRIDGE_LAVENDER, lerpf(0.12, 0.38, pulse), 1.0)


func _bridge_spec(bridge_id: String) -> Dictionary:
	for value: Variant in _config.get("bridges", []):
		var spec := value as Dictionary
		if String(spec.get("id", "")) == bridge_id:
			return spec
	return {}


func _update_cooldown_segments() -> void:
	for teleporter_id: String in _cooldown_segments:
		var info := _cooldown_segments[teleporter_id] as Dictionary
		var teleporter := info["teleporter"] as Node
		if not is_instance_valid(teleporter) or not teleporter.has_method("get_debug_state"):
			continue
		var debug := teleporter.call("get_debug_state") as Dictionary
		var progress := clampf(float(debug.get("cooldown_progress", 1.0)), 0.0, 1.0)
		var exact := progress * 8.0
		var segments := info["segments"] as Array
		for index in range(segments.size()):
			var segment := segments[index] as Dictionary
			var mesh := segment["mesh"] as MeshInstance3D
			var material := segment["material"] as StandardMaterial3D
			var amount := clampf(exact - float(index), 0.0, 1.0)
			mesh.visible = amount > 0.02
			material.albedo_color = Color(TELEPORT_CYAN, lerpf(0.12, 0.50, amount))
			material.emission_energy_multiplier = lerpf(0.18, 1.15, amount)


func _on_v7_teleported(character: BaseCharacter, source_id: String, destination_id: String) -> void:
	var key := "%d:%s:%s" % [character.get_instance_id(), source_id, destination_id]
	var now := Time.get_ticks_msec()
	if key == _last_trail_key and now - _last_trail_msec < 40:
		return
	_last_trail_key = key
	_last_trail_msec = now
	var source := _teleporters_by_id.get(source_id) as Node3D
	var destination := _teleporters_by_id.get(destination_id) as Node3D
	if not is_instance_valid(source) or not is_instance_valid(destination):
		return
	_spawn_teleport_trail(source.global_position, destination.global_position)
	_play_at(_teleport_player, _teleport_stream, destination.global_position)


func _spawn_teleport_trail(source: Vector3, destination: Vector3) -> void:
	var root := Node3D.new()
	root.name = "TeleportEnergyTrail"
	root.set_meta("visual_only", true)
	add_child(root)
	var material := _detail_material(TELEPORT_CYAN, 2.15, 0.70)
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var previous := source + Vector3.UP * 0.28
	for index in range(1, 8):
		var t := float(index) / 7.0
		var point := source.lerp(destination, t) + Vector3.UP * (0.28 + sin(t * PI) * 4.8)
		var segment := MeshInstance3D.new()
		segment.name = "TrailSegment%02d" % index
		var mesh := BoxMesh.new()
		mesh.size = Vector3(0.10, 0.10, previous.distance_to(point))
		segment.mesh = mesh
		segment.position = (previous + point) * 0.5
		segment.material_override = material
		segment.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		segment.set_meta("visual_only", true)
		root.add_child(segment)
		segment.look_at(point, Vector3.UP)
		previous = point
	_active_trails.append({
		"root": root,
		"material": material,
		"time": 0.0,
		"duration": float((_production_config.get("teleporters", {}) as Dictionary).get("trail_duration", 0.28)),
	})


func stage_review_teleport_trail(progress: float = 0.40) -> bool:
	var ids: Array[String] = []
	for raw_id: Variant in _teleporters_by_id.keys():
		ids.append(String(raw_id))
	ids.sort()
	if ids.size() < 2:
		return false
	var source := _teleporters_by_id[ids[0]] as Node3D
	var destination := _teleporters_by_id[ids[1]] as Node3D
	_spawn_teleport_trail(source.global_position, destination.global_position)
	if _active_trails.is_empty():
		return false
	var trail := _active_trails[-1] as Dictionary
	trail["duration"] = 999.0
	trail["time"] = clampf(progress, 0.0, 1.0) * 0.28
	return true


func _update_teleport_trails(delta: float) -> void:
	for index in range(_active_trails.size() - 1, -1, -1):
		var trail := _active_trails[index] as Dictionary
		trail["time"] = float(trail["time"]) + maxf(0.0, delta)
		var phase := clampf(float(trail["time"]) / maxf(float(trail["duration"]), 0.001), 0.0, 1.0)
		var material := trail["material"] as StandardMaterial3D
		material.albedo_color = Color(TELEPORT_CYAN, (1.0 - phase) * 0.70)
		material.emission_energy_multiplier = lerpf(2.15, 0.15, phase)
		var root := trail["root"] as Node3D
		root.scale = Vector3(1.0, lerpf(1.0, 0.35, phase), 1.0)
		if phase >= 1.0:
			root.queue_free()
			_active_trails.remove_at(index)


func _build_audio_players() -> void:
	var audio := _production_config.get("map_audio", {}) as Dictionary
	if not bool(audio.get("enabled", true)):
		return
	_hum_player = _make_audio_player("BridgeActiveHum", float(audio.get("active_hum_db", -23.0)))
	_event_player = _make_audio_player("BridgeStateAudio", float(audio.get("warning_db", -10.0)))
	_teleport_player = _make_audio_player("TeleportFeedbackAudio", float(audio.get("teleport_db", -8.0)))
	if RuntimeGlobals.runtime_audio_disabled():
		return
	_hum_stream = _synth_tone(82.0, 0.75, 0.20, true, 0.35)
	_warning_stream = _synth_tone(520.0, 0.10, 0.52, false, 0.0)
	_switch_stream = _synth_sweep(310.0, 118.0, 0.24, 0.55)
	_lock_stream = _synth_sweep(260.0, 720.0, 0.16, 0.48)
	_teleport_stream = _synth_sweep(420.0, 1260.0, 0.22, 0.56)
	_ready_stream = _synth_tone(880.0, 0.12, 0.42, false, 0.0)
	_reject_stream = _synth_tone(170.0, 0.09, 0.32, false, 0.0)


func _make_audio_player(node_name: String, volume_db: float) -> AudioStreamPlayer3D:
	var player := AudioStreamPlayer3D.new()
	player.name = node_name
	player.volume_db = volume_db
	player.max_distance = float((_production_config.get("map_audio", {}) as Dictionary).get("max_distance", 38.0))
	player.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
	player.unit_size = 9.0
	add_child(player)
	return player


func _update_audio_state() -> void:
	if not is_instance_valid(_controller) or not _controller.has_method("get_debug_state") \
		or not is_instance_valid(_hum_player) or _hum_stream == null:
		return
	var debug := _controller.call("get_debug_state") as Dictionary
	var state := String(debug.get("state", "ACTIVE"))
	var progress := float(debug.get("state_progress", 0.0))
	var bridge_id := String(debug.get("active_bridge_id", ""))
	var next_id := String(debug.get("next_bridge_id", ""))
	_hum_player.global_position = _bridge_midpoint(bridge_id)
	if state == "ACTIVE" and not _hum_player.playing:
		_hum_player.stream = _hum_stream
		_hum_player.play()
	elif state != "ACTIVE" and _hum_player.playing:
		_hum_player.stop()
	if state != _last_state:
		var previous := _last_state
		_last_state = state
		if state == "WARNING":
			_warning_pulse_index = 0
		elif state == "SWITCHING":
			_play_at(_event_player, _switch_stream, _bridge_midpoint(bridge_id))
		elif state == "ACTIVE" and previous == "SWITCHING":
			_play_at(_event_player, _lock_stream, _bridge_midpoint(next_id if not next_id.is_empty() else bridge_id))
	if state == "WARNING":
		var thresholds := [0.0, 0.38, 0.68, 0.88]
		while _warning_pulse_index < thresholds.size() and progress >= float(thresholds[_warning_pulse_index]):
			_play_at(_event_player, _warning_stream, _bridge_midpoint(bridge_id))
			_warning_pulse_index += 1


func _on_landing_cooldown_finished(teleporter_id: String) -> void:
	var teleporter := _teleporters_by_id.get(teleporter_id) as Node3D
	if is_instance_valid(teleporter):
		_play_at(_teleport_player, _ready_stream, teleporter.global_position)


func _on_teleport_rejected(_character: BaseCharacter, source_id: String, _reason: StringName) -> void:
	var teleporter := _teleporters_by_id.get(source_id) as Node3D
	if is_instance_valid(teleporter):
		_play_at(_teleport_player, _reject_stream, teleporter.global_position)
		for pulse_value: Variant in _teleport_pulses:
			var pulse := pulse_value as Dictionary
			var mesh := pulse["mesh"] as MeshInstance3D
			if String(mesh.get_meta("teleporter_id", "")) == source_id:
				pulse["time"] = 0.18


func _play_at(player: AudioStreamPlayer3D, stream: AudioStream, position: Vector3) -> void:
	if not is_instance_valid(player) or stream == null:
		return
	player.global_position = position
	player.stream = stream
	player.play()


func _bridge_midpoint(bridge_id: String) -> Vector3:
	for value: Variant in _config.get("bridges", []):
		var spec := value as Dictionary
		if String(spec.get("id", "")) != bridge_id:
			continue
		var start := _point(spec.get("start_xz", []), float(_config.get("top_y", 1.06)))
		var finish := _point(spec.get("end_xz", []), float(_config.get("top_y", 1.06)))
		return (start + finish) * 0.5
	return Vector3.ZERO


func _detail_material(color: Color, emission: float, alpha: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
	material.albedo_color = Color(color, alpha)
	material.emission_enabled = true
	material.emission = color
	material.emission_energy_multiplier = emission
	material.roughness = 0.78
	material.metallic = 0.01
	return material


func _synth_tone(frequency: float, duration: float, amplitude: float, looping: bool, wobble: float) -> AudioStreamWAV:
	var sample_count := maxi(1, int(duration * AUDIO_RATE))
	var data := PackedByteArray()
	data.resize(sample_count * 2)
	for index in range(sample_count):
		var t := float(index) / float(AUDIO_RATE)
		var envelope := 1.0 if looping else sin(clampf(t / duration, 0.0, 1.0) * PI)
		var phase := TAU * frequency * t + sin(t * TAU * 2.0) * wobble
		var sample := int(clampf(sin(phase) * amplitude * envelope, -1.0, 1.0) * 32767.0)
		data.encode_s16(index * 2, sample)
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = AUDIO_RATE
	stream.stereo = false
	stream.data = data
	if looping:
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		stream.loop_begin = 0
		stream.loop_end = sample_count
	return stream


func _synth_sweep(start_frequency: float, end_frequency: float, duration: float, amplitude: float) -> AudioStreamWAV:
	var sample_count := maxi(1, int(duration * AUDIO_RATE))
	var data := PackedByteArray()
	data.resize(sample_count * 2)
	var phase := 0.0
	for index in range(sample_count):
		var t := float(index) / float(sample_count)
		var frequency := lerpf(start_frequency, end_frequency, t)
		phase += TAU * frequency / float(AUDIO_RATE)
		var envelope := sin(t * PI)
		var sample := int(clampf(sin(phase) * amplitude * envelope, -1.0, 1.0) * 32767.0)
		data.encode_s16(index * 2, sample)
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = AUDIO_RATE
	stream.stereo = false
	stream.data = data
	return stream
