extends "res://scripts/maps/momentum_circuit_arena_base.gd"
class_name MomentumCircuitArena

const MomentumCircuitProductionConfigScript = preload(
	"res://scripts/maps/momentum_circuit_production_config.gd"
)
const GravityControllerScript = preload(
	"res://scripts/maps/momentum_circuit_gravity_controller.gd"
)
const GravityActivatorScript = preload(
	"res://scripts/maps/momentum_circuit_gravity_activator.gd"
)
const StabilizerAnchorScript = preload(
	"res://scripts/maps/momentum_circuit_stabilizer_anchor.gd"
)
const MechanismVFXScript = preload(
	"res://scripts/maps/momentum_circuit_mechanism_vfx.gd"
)
const CloudVortexScript = preload(
	"res://scripts/maps/momentum_circuit_cloud_vortex.gd"
)
const PartyShooterCameraDirectorScript = preload(
	"res://scripts/maps/party_shooter_camera_director.gd"
)

const PRODUCTION_CONFIG_PATH := "res://resources/maps/momentum_circuit_production_v2.json"
const FOREGROUND_SCENE_PATH := (
	"res://assets/models/generated/momentum_circuit/momentum_circuit_foreground.glb"
)

const ROLE_GAMEPLAY := &"gameplay"
const ROLE_FOREGROUND := &"foreground"
const ROLE_MECHANISM_VFX := &"mechanism_vfx"
const ROLE_BACKDROP := &"backdrop"

const CYAN_COLOR := Color("#52E5F5")
const ORANGE_COLOR := Color("#FF9A3D")
const SKY_TOP_COLOR := Color("#5B8ED8")
const SKY_HORIZON_COLOR := Color("#756CC5")

var _production_config: Dictionary = {}
var _production_layers: Dictionary = {}
var _gravity_controller: Node3D = null
var _stabilizer_anchors: Array[Node3D] = []
var _gravity_activators: Array[StaticBody3D] = []
var _camera_director: Node = null


func _build_map_layout() -> void:
	if not _ensure_layout() or not _ensure_production_config():
		return
	_production_layers = _create_production_layers()
	var gameplay := _production_layers[ROLE_GAMEPLAY] as Node3D
	var foreground := _production_layers[ROLE_FOREGROUND] as Node3D
	var mechanism_vfx := _production_layers[ROLE_MECHANISM_VFX] as Node3D
	var backdrop := _production_layers[ROLE_BACKDROP] as Node3D

	_build_shared_geometry(gameplay, false)
	_build_production_foreground(foreground)
	_build_production_mechanisms(gameplay)
	_build_production_mechanism_vfx(mechanism_vfx)
	_build_production_backdrop(backdrop)
	_build_spawn_markers()


func _build_map_dressing() -> void:
	# All production responsibilities are created in deterministic layer order by
	# _build_map_layout().  Keeping this hook empty avoids a second visual owner.
	pass


func _ensure_production_config() -> bool:
	if not _production_config.is_empty():
		return true
	_production_config = MomentumCircuitProductionConfigScript.load_default()
	if _production_config.is_empty():
		push_error("Momentum Circuit production config is invalid or missing")
		return false
	set_meta("production_config_source", PRODUCTION_CONFIG_PATH)
	set_meta("production_config_schema", String(_production_config.get("schema", "")))
	set_meta("production_config_version", int(_production_config.get("version", -1)))
	return true


func get_production_config() -> Dictionary:
	_ensure_production_config()
	return _production_config.duplicate(true)


func get_gravity_controller() -> Node3D:
	return _gravity_controller


func get_production_layer(role: StringName) -> Node3D:
	return _production_layers.get(role) as Node3D


func _create_production_layers() -> Dictionary:
	var result := {}
	var layer_names := {
		ROLE_GAMEPLAY: "Gameplay",
		ROLE_FOREGROUND: "ForegroundVisuals",
		ROLE_MECHANISM_VFX: "MechanismVFX",
		ROLE_BACKDROP: "Backdrop",
	}
	for role: StringName in [ROLE_BACKDROP, ROLE_GAMEPLAY, ROLE_FOREGROUND, ROLE_MECHANISM_VFX]:
		var node_name := String(layer_names[role])
		var existing := get_node_or_null(node_name)
		if existing:
			remove_child(existing)
			existing.free()
		var layer := Node3D.new()
		layer.name = node_name
		layer.set_meta("momentum_circuit_role", String(role))
		add_child(layer)
		result[role] = layer
	return result


func _build_production_foreground(parent: Node3D) -> void:
	var packed := load(FOREGROUND_SCENE_PATH) as PackedScene
	if packed == null:
		push_error("Momentum Circuit production foreground is missing: %s" % FOREGROUND_SCENE_PATH)
		return
	var foreground := packed.instantiate() as Node3D
	if foreground == null:
		push_error("Momentum Circuit foreground could not be instantiated")
		return
	foreground.name = "MomentumCircuitForeground"
	foreground.set_meta("visual_only", true)
	foreground.set_meta("layout_source", LAYOUT_PATH)
	parent.add_child(foreground)
	_verify_visual_only_tree(parent, "ForegroundVisuals")


func _build_production_mechanisms(parent: Node3D) -> void:
	_stabilizer_anchors.clear()
	_gravity_activators.clear()

	var mechanisms := Node3D.new()
	mechanisms.name = "GravityMechanisms"
	parent.add_child(mechanisms)

	_gravity_controller = GravityControllerScript.new() as Node3D
	_gravity_controller.name = "GravityFieldController"
	_gravity_controller.add_to_group(&"momentum_circuit_gravity_controller")
	mechanisms.add_child(_gravity_controller)

	var anchors_root := Node3D.new()
	anchors_root.name = "StabilizerAnchors"
	mechanisms.add_child(anchors_root)
	var anchor_config := _production_config["anchors"] as Dictionary
	for index in range((_layout["portals"] as Array).size()):
		var portal_data := (_layout["portals"] as Array)[index] as Dictionary
		var anchor := StabilizerAnchorScript.new() as Node3D
		anchor.name = "StabilizerAnchor%02d" % (index + 1)
		anchor.position = MomentumCircuitLayoutScript.vector3(
			portal_data["position_world"],
			"portals[%d].position_world" % index
		)
		anchor.add_to_group(&"momentum_circuit_stabilizer_anchor")
		anchor.set_meta("layout_id", String(portal_data["id"]))
		anchor.set_meta("layout_position_world", anchor.position)
		anchor.set_meta("outer_radius", float(anchor_config["outer_radius"]))
		anchor.set_meta("core_radius", float(anchor_config["core_radius"]))
		anchor.set_meta("teleport_enabled", false)
		anchor.set_meta("color_token", "#52E5F5")
		anchors_root.add_child(anchor)
		_stabilizer_anchors.append(anchor)

	var activators_root := Node3D.new()
	activators_root.name = "GravityActivators"
	mechanisms.add_child(activators_root)
	var gravity_config := _production_config["gravity"] as Dictionary
	for index in range((_layout["shockwave_nodes"] as Array).size()):
		var node_data := (_layout["shockwave_nodes"] as Array)[index] as Dictionary
		var activator := GravityActivatorScript.new() as StaticBody3D
		activator.name = "GravityActivator%02d" % (index + 1)
		activator.position = MomentumCircuitLayoutScript.vector3(
			node_data["position_world"],
			"shockwave_nodes[%d].position_world" % index
		)
		activator.add_to_group(&"gravity_activator")
		activator.add_to_group(&"momentum_circuit_gravity_activator")
		activator.call(
			"configure",
			_gravity_controller,
			float(gravity_config["node_cooldown_seconds"])
		)
		var radius := _component_radius(node_data)
		activator.set_meta("layout_id", String(node_data["id"]))
		activator.set_meta("layout_position_world", activator.position)
		activator.set_meta("outer_radius_world", radius)
		activator.set_meta("shoot_only", true)
		activator.set_meta("color_token", "#FF9A3D")
		activators_root.add_child(activator)

		var hit_shape := CollisionShape3D.new()
		hit_shape.name = "HitShape"
		var cylinder_shape := CylinderShape3D.new()
		cylinder_shape.radius = radius * 0.82
		cylinder_shape.height = 1.2
		hit_shape.shape = cylinder_shape
		hit_shape.position = Vector3(0.0, 0.6, 0.0)
		activator.add_child(hit_shape)
		_gravity_activators.append(activator)

	var controller_config := _production_config.duplicate(true)
	var platform := _layout["platform"] as Dictionary
	controller_config["outer_outline_world_xz"] = platform.get(
		"visual_top_outline_world_xz",
		platform["outline_world_xz"]
	)
	_gravity_controller.call("configure", controller_config, _stabilizer_anchors)


func _build_production_mechanism_vfx(parent: Node3D) -> void:
	var vfx := MechanismVFXScript.new() as Node3D
	vfx.name = "GravityMechanismVFX"
	vfx.set_meta("visual_only", true)
	parent.add_child(vfx)
	if vfx.has_method("bind_controller"):
		vfx.call("bind_controller", _gravity_controller)
	_verify_visual_only_tree(parent, "MechanismVFX")


func _build_production_backdrop(parent: Node3D) -> void:
	var vortex := CloudVortexScript.new() as Node3D
	vortex.name = "CloudVortex"
	vortex.set_meta("visual_only", true)
	parent.add_child(vortex)
	_verify_visual_only_tree(parent, "Backdrop")


func _verify_visual_only_tree(root: Node, label: String) -> void:
	var pending: Array[Node] = [root]
	while not pending.is_empty():
		var node: Node = pending.pop_back()
		if node != root and (
			node is CollisionObject3D
			or node is CollisionShape3D
			or node is Camera3D
			or node is Light3D
		):
			push_error("Momentum Circuit %s contains forbidden node: %s" % [label, root.get_path_to(node)])
		if node is CSGShape3D and (node as CSGShape3D).use_collision:
			push_error("Momentum Circuit %s contains collision-enabled CSG: %s" % [label, root.get_path_to(node)])
		for child: Node in node.get_children():
			pending.append(child)


func _configure_map_runtime() -> void:
	super._configure_map_runtime()
	if weapon_spawner == null or not _ensure_production_config():
		return
	var weapons := _production_config["weapons"] as Dictionary
	weapon_spawner.initial_delay = float(weapons["initial_delay"])
	weapon_spawner.stay_duration = float(weapons["stay_duration"])
	weapon_spawner.respawn_cooldown = float(weapons["respawn_cooldown"])
	weapon_spawner.max_active_pickups = int(weapons["max_active_pickups"])


func _apply_map_visual_overrides() -> void:
	_configure_production_camera()
	_configure_production_lighting()
	_configure_production_environment()


func _uses_fixed_runtime_camera() -> bool:
	return false


func _configure_production_camera() -> void:
	var camera := get_node_or_null("GlobalCamera") as Camera3D
	if camera == null or not _ensure_production_config():
		return
	var profile := _runtime_camera_profile()
	var map_focus := profile["map_focus"] as Vector3
	var view_offset := profile["view_offset"] as Vector3
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.keep_aspect = Camera3D.KEEP_HEIGHT
	camera.position = map_focus + view_offset
	camera.look_at(map_focus, Vector3.UP)
	camera.size = float(profile["initial_size"])
	camera.current = true
	if _camera_director == null or not is_instance_valid(_camera_director):
		_camera_director = PartyShooterCameraDirectorScript.new() as Node
		_camera_director.name = "MomentumCircuitCameraDirector"
		add_child(_camera_director)
	_camera_director.call("configure", camera, profile)


func _runtime_camera_profile() -> Dictionary:
	var camera := _production_config["camera"] as Dictionary
	return {
		"profile_id": String(camera["profile_id"]),
		"map_focus": MomentumCircuitProductionConfigScript.vector3(camera["map_focus"], "camera.map_focus"),
		"view_offset": MomentumCircuitProductionConfigScript.vector3(camera["view_offset"], "camera.view_offset"),
		"initial_size": float(camera["initial_size"]),
		"idle_overview_size": float(camera["idle_overview_size"]),
		"min_size": float(camera["min_size"]),
		"max_size": float(camera["max_size"]),
		"discontinuity_max_size": float(camera["max_size"]),
		"playable_min": MomentumCircuitProductionConfigScript.vector2(camera["playable_min"], "camera.playable_min"),
		"playable_max": MomentumCircuitProductionConfigScript.vector2(camera["playable_max"], "camera.playable_max"),
		"focus_min": MomentumCircuitProductionConfigScript.vector2(camera["focus_min"], "camera.focus_min"),
		"focus_max": MomentumCircuitProductionConfigScript.vector2(camera["focus_max"], "camera.focus_max"),
		"track_min_y": float(camera["track_min_y"]),
		"world_frame_padding": float(camera["world_frame_padding"]),
		"character_screen_radius": float(camera["character_screen_radius"]),
		"screen_edge_gutter": float(camera["screen_edge_gutter"]),
		"min_layout_viewport": Vector2(640.0, 360.0),
		"fallback_layout_viewport": MomentumCircuitProductionConfigScript.vector2(camera["fallback_viewport"], "camera.fallback_viewport"),
		"reserve_corner_hud": true,
		"hud_occlusion_group": &"party_shooter_camera_occluder",
		"hud_occlusion_gutter": 12.0,
		"reveal_focus": MomentumCircuitProductionConfigScript.vector3(camera["map_focus"], "camera.map_focus"),
		"reveal_size": float(camera["idle_overview_size"]),
	}


func _update_map_runtime_camera(delta: float) -> void:
	if _camera_director and is_instance_valid(_camera_director):
		_camera_director.call("update_camera", _characters, delta)


func get_runtime_camera_debug() -> Dictionary:
	if _camera_director and is_instance_valid(_camera_director):
		return _camera_director.call("get_debug_state") as Dictionary
	return {}


func _configure_production_lighting() -> void:
	var key := get_node_or_null("DirectionalLight3D") as DirectionalLight3D
	if key:
		key.rotation_degrees = Vector3(-52.0, -28.0, 0.0)
		key.light_color = Color("#FFE7D9")
		key.light_energy = 0.82
		key.shadow_enabled = true
		key.shadow_blur = 2.3
		key.shadow_opacity = 0.55
	var fill := get_node_or_null("MomentumCircuitCoolFill") as OmniLight3D
	if fill == null:
		fill = OmniLight3D.new()
		fill.name = "MomentumCircuitCoolFill"
		add_child(fill)
	fill.position = Vector3(-24.0, 34.0, 20.0)
	fill.light_color = CYAN_COLOR
	fill.light_energy = 0.10
	fill.omni_range = 125.0
	fill.shadow_enabled = false


func _configure_production_environment() -> void:
	var environment_node := get_node_or_null("WorldEnvironment") as WorldEnvironment
	if environment_node == null:
		environment_node = WorldEnvironment.new()
		environment_node.name = "WorldEnvironment"
		add_child(environment_node)
	var environment := Environment.new()
	var sky := Sky.new()
	var sky_material := ProceduralSkyMaterial.new()
	sky_material.sky_top_color = SKY_TOP_COLOR
	sky_material.sky_horizon_color = SKY_HORIZON_COLOR
	sky_material.ground_bottom_color = Color("#514B84")
	sky_material.ground_horizon_color = Color("#756CC5")
	sky_material.sun_angle_max = 16.0
	sky_material.sun_curve = 0.10
	sky.sky_material = sky_material
	environment.background_mode = Environment.BG_SKY
	environment.sky = sky
	environment.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("#C8C2EE")
	environment.ambient_light_energy = 0.32
	environment.tonemap_mode = Environment.TONE_MAPPER_ACES
	environment.tonemap_exposure = 0.72
	environment.adjustment_enabled = true
	environment.adjustment_brightness = 1.02
	environment.adjustment_contrast = 1.05
	environment.adjustment_saturation = 1.03
	environment.ssao_enabled = true
	environment.ssao_radius = 1.1
	environment.ssao_intensity = 0.82
	environment.ssao_power = 1.25
	environment.glow_enabled = true
	environment.glow_intensity = 0.14
	environment.glow_strength = 0.52
	environment.glow_bloom = 0.02
	environment.fog_enabled = false
	environment_node.environment = environment
