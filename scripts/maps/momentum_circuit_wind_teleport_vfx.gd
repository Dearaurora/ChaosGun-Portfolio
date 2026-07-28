extends Node3D
class_name MomentumCircuitWindTeleportVFX

const CYAN := Color("#52E5F5")
const WHITE_CYAN := Color("#D8FFFF")
var _wind_controller: Node = null
var _teleporters: Array[Node3D] = []
var _wind_visuals: Array[Dictionary] = []
var _pulse_visuals: Array[Dictionary] = []

func configure(holes: Array, wind_controller: Node, teleporters: Array[Node3D]) -> void:
	_wind_controller = wind_controller
	_teleporters = teleporters
	for hole_index in holes.size():
		var hole_value: Variant = holes[hole_index]
		if not hole_value is Dictionary: continue
		var hole := hole_value as Dictionary
		var center := _center(hole)
		var root := Node3D.new()
		root.name = "WindField_%s" % String(hole.get("id", "Hole"))
		root.position = Vector3(center.x, 0.35, center.y)
		add_child(root)
		var rings: Array[MeshInstance3D] = []
		for index in range(3):
			var ring := MeshInstance3D.new()
			var mesh := TorusMesh.new()
			mesh.inner_radius = 1.4 + index * 0.8
			mesh.outer_radius = mesh.inner_radius + 0.10
			mesh.rings = 32
			mesh.ring_segments = 8
			ring.mesh = mesh
			ring.material_override = _make_material(0.24 - index * 0.04)
			ring.position.y = -0.3 - index * 0.35
			root.add_child(ring)
			rings.append(ring)
		var column := MeshInstance3D.new()
		var column_mesh := CylinderMesh.new()
		column_mesh.top_radius = 0.35
		column_mesh.bottom_radius = 0.9
		column_mesh.height = 2.8
		column.mesh = column_mesh
		column.material_override = _make_material(0.10)
		column.position.y = -1.0
		root.add_child(column)
		_wind_visuals.append({"root": root, "rings": rings, "column": column, "phase": hole_index * 1.7})
	for teleporter in _teleporters:
		var pulse := MeshInstance3D.new()
		var pulse_mesh := TorusMesh.new()
		pulse_mesh.inner_radius = 2.35
		pulse_mesh.outer_radius = 2.48
		pulse_mesh.rings = 32
		pulse_mesh.ring_segments = 8
		pulse.mesh = pulse_mesh
		pulse.material_override = _make_material(0.34)
		pulse.position = teleporter.position + Vector3.UP * 0.12
		pulse.set_meta("teleporter_id", String(teleporter.get("teleporter_id")))
		pulse.scale = Vector3.ONE * 0.1
		add_child(pulse)
		_pulse_visuals.append({"mesh": pulse, "time": 99.0})
		if teleporter.has_signal("teleported"):
			teleporter.teleported.connect(_on_teleported)

func _process(delta: float) -> void:
	var time := Time.get_ticks_msec() / 1000.0
	for visual in _wind_visuals:
		var rings: Array = visual["rings"]
		for index in rings.size():
			var ring := rings[index] as MeshInstance3D
			ring.rotation.y += delta * (0.9 + index * 0.25)
			ring.scale = Vector3.ONE * (0.92 + sin(time * 2.0 + float(visual["phase"]) + index) * 0.08)
		var column := visual["column"] as MeshInstance3D
		column.scale.y = 0.88 + sin(time * 2.4 + float(visual["phase"])) * 0.12
	for pulse in _pulse_visuals:
		var mesh := pulse["mesh"] as MeshInstance3D
		var pulse_time := float(pulse["time"])
		if pulse_time < 2.0:
			pulse_time += delta
			pulse["time"] = pulse_time
			var phase := clampf(pulse_time / 0.32, 0.0, 1.0)
			mesh.scale = Vector3.ONE * lerpf(0.1, 1.25, phase)
			(mesh.material_override as StandardMaterial3D).albedo_color.a = (1.0 - phase) * 0.34

func _on_teleported(_character: BaseCharacter, _source_id: String, destination_id: String) -> void:
	for pulse in _pulse_visuals:
		var mesh := pulse["mesh"] as MeshInstance3D
		var owner_pos := mesh.position
		if String(mesh.get_meta("teleporter_id", "")) == destination_id:
			pulse["time"] = 0.0
			mesh.position = owner_pos

func _make_material(alpha: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color(CYAN.r, CYAN.g, CYAN.b, alpha)
	material.emission_enabled = true
	material.emission = WHITE_CYAN
	material.emission_energy_multiplier = 1.6
	material.no_depth_test = false
	return material

func _center(hole: Dictionary) -> Vector2:
	var value: Variant = hole.get("center_world_xz", hole.get("center_world", hole.get("center", [0.0, 0.0])))
	if value is Array and (value as Array).size() >= 2:
		return Vector2(float(value[0]), float(value[1]))
	return Vector2.ZERO
