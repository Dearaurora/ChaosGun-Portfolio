extends Node3D
class_name WeaponSpawnPedestal

enum VisualState { COOLING, PREWARM, ACTIVE }

var _premium := false
var _state := VisualState.COOLING
var _accent_color := Color("#6a7382")
var _state_ring: MeshInstance3D
var _state_disc: MeshInstance3D
var _light_nodes: Array[MeshInstance3D] = []
var _phase := 0.0

func _ready() -> void:
	add_to_group("weapon_spawn_pedestal")

func configure(premium: bool) -> void:
	_premium = premium
	_build()
	set_state(VisualState.COOLING, Color("#6a7382"))

func set_state(state: VisualState, accent_color: Color = Color("#6a7382")) -> void:
	_state = state
	_accent_color = accent_color
	_apply_state_materials()

func get_visual_debug() -> Dictionary:
	return {
		"premium": _premium,
		"state": _state,
		"light_count": _light_nodes.size(),
		"radius": 1.82 if _premium else 1.38,
	}

func _process(delta: float) -> void:
	_phase += delta
	if _state_ring == null:
		return
	var pulse := 1.0
	match _state:
		VisualState.PREWARM:
			pulse = 0.88 + absf(sin(_phase * 12.0)) * 0.18
		VisualState.ACTIVE:
			pulse = 0.98 + sin(_phase * 3.8) * 0.025
		_:
			pulse = 0.82
	_state_ring.scale = Vector3.ONE * pulse
	if _state_disc:
		_state_disc.scale = Vector3.ONE * (0.98 + sin(_phase * 2.8) * 0.015 if _state == VisualState.ACTIVE else 1.0)

func _build() -> void:
	for child in get_children():
		child.queue_free()
	_light_nodes.clear()
	var radius := 1.82 if _premium else 1.38
	var dark := _material(Color("#303545"), Color("#303545"), 0.0, false)
	var trim := _material(Color("#596273"), Color("#596273"), 0.0, false)

	_add_cylinder("PedestalFoot", Vector3(0.0, -0.50, 0.0), radius, radius * 1.06, 0.28, dark, 32)
	_add_cylinder("PedestalTop", Vector3(0.0, -0.30, 0.0), radius * 0.88, radius * 0.92, 0.16, trim, 32)
	_state_disc = _add_cylinder("StateDisc", Vector3(0.0, -0.18, 0.0), radius * 0.66, radius * 0.66, 0.075, trim, 32)

	_state_ring = MeshInstance3D.new()
	_state_ring.name = "StateRing"
	var torus := TorusMesh.new()
	torus.inner_radius = radius * 0.69
	torus.outer_radius = radius * 0.79
	torus.rings = 32
	torus.ring_segments = 8
	_state_ring.mesh = torus
	_state_ring.position.y = -0.16
	_state_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_state_ring)

	var light_count := 6 if _premium else 4
	for i in range(light_count):
		var angle := TAU * float(i) / float(light_count)
		var light := _add_box(
			"StatusLight_%d" % i,
			Vector3(cos(angle) * radius * 0.78, -0.12, sin(angle) * radius * 0.78),
			Vector3(0.22 if _premium else 0.18, 0.07, 0.10),
			trim
		)
		light.rotation.y = -angle
		light.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_light_nodes.append(light)

	if _premium:
		for i in range(4):
			var angle := TAU * float(i) / 4.0 + PI * 0.25
			var clamp := _add_box(
				"PremiumClamp_%d" % i,
				Vector3(cos(angle) * radius * 0.93, -0.26, sin(angle) * radius * 0.93),
				Vector3(0.34, 0.18, 0.24),
				dark
			)
			clamp.rotation.y = -angle

func _apply_state_materials() -> void:
	if _state_ring == null:
		return
	var state_color := Color("#596273")
	var energy := 0.0
	var alpha := 1.0
	match _state:
		VisualState.PREWARM:
			state_color = _accent_color.lerp(Color.WHITE, 0.22)
			energy = 0.85
			alpha = 0.82
		VisualState.ACTIVE:
			state_color = _accent_color
			energy = 0.55
			alpha = 0.88
	_state_ring.material_override = _material(Color(state_color.r, state_color.g, state_color.b, alpha), state_color, energy, alpha < 0.99)
	if _state_disc:
		_state_disc.material_override = _material(Color(state_color.r, state_color.g, state_color.b, 0.34 if _state != VisualState.COOLING else 1.0), state_color, energy * 0.35, _state != VisualState.COOLING)
	for light in _light_nodes:
		light.material_override = _material(state_color, state_color, energy + (0.25 if _state == VisualState.ACTIVE else 0.0), false)

func _add_cylinder(node_name: String, pos: Vector3, top_radius: float, bottom_radius: float, height: float, material: Material, segments: int) -> MeshInstance3D:
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = node_name
	var mesh := CylinderMesh.new()
	mesh.top_radius = top_radius
	mesh.bottom_radius = bottom_radius
	mesh.height = height
	mesh.radial_segments = segments
	mesh_instance.mesh = mesh
	mesh_instance.position = pos
	mesh_instance.material_override = material
	add_child(mesh_instance)
	return mesh_instance

func _add_box(node_name: String, pos: Vector3, size: Vector3, material: Material) -> MeshInstance3D:
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = node_name
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh_instance.mesh = mesh
	mesh_instance.position = pos
	mesh_instance.material_override = material
	add_child(mesh_instance)
	return mesh_instance

func _material(albedo: Color, emission: Color, energy: float, transparent: bool) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = albedo
	material.roughness = 0.62
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA if transparent else BaseMaterial3D.TRANSPARENCY_DISABLED
	material.emission_enabled = energy > 0.0
	material.emission = emission
	material.emission_energy_multiplier = energy
	return material
