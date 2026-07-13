extends "res://scripts/maps/battle_arena.gd"

const RINGOUT_HUD_SCRIPT = preload("res://scripts/ui/ringout_hud.gd")

const PLAYABLE_ROOT_NAME := "OpenRingoutPlayable"
const COVER_ROOT_NAME := "OpenRingoutCovers"
const EDGE_GLOW_ROOT_NAME := "OpenRingoutEdgeGlow"
const ABYSS_ROOT_NAME := "OpenRingoutAbyss"
const BACKDROP_ROOT_NAME := "OpenRingoutBackdrop"
const ART_ROOT_NAME := "OpenRingoutArt"
const BLENDER_VISUAL_ROOT_NAME := "OpenRingoutBlenderVisuals"
const BLENDER_VISUAL_SCENE_PATH := "res://assets/models/generated/open_ringout_slice/open_ringout_visuals.glb"
const SUNSET_V2_VISUAL_ROOT_NAME := "SunsetV2GameplayVisuals"
const SUNSET_V2_VISUAL_SCENE_PATH := "res://assets/models/generated/sunset_toy_sky_islands/open_ringout_v2_preview.glb"
const SUNSET_V2_HIDDEN_LEGACY_PREFIXES := [
	"main_deck_",
	"main_west_lip_",
	"main_east_lip_",
	"north_deck_",
	"east_deck_",
	"south_deck_",
	"west_deck_",
	"north_bridge_",
	"east_bridge_",
	"south_bridge_",
	"west_bridge_",
	"A1MainDeck",
	"A1MainWestLip",
	"A1MainEastLip",
	"A1NorthDeck",
	"A1EastDeck",
	"A1SouthDeck",
	"A1WestDeck",
	"A1NorthBridge",
	"A1EastBridge",
	"A1SouthBridge",
	"A1WestBridge",
	"A1BridgeMouthMarker",
	"A1SurfacePanel_Main",
	"A1SurfacePanel_WestLip",
	"A1SurfacePanel_EastLip",
	"A1SurfacePanel_BridgeE",
	"A1SurfacePanel_North",
	"A1SurfacePanel_East",
	"A1SurfacePanel_South",
	"A1SurfacePanel_West",
	"A1SurfacePanel_BridgeN",
	"A1SurfacePanel_BridgeS",
	"A1SurfacePanel_BridgeW",
	"A1CenterPickup",
	"A1EdgeBeacon_",
	"A1PerimeterToyBlock_",
	"center_pickup_",
	"tile_line_",
	"concept_outer_edge_glow_main",
	"concept_outer_edge_glow_north",
	"concept_outer_edge_glow_east",
	"concept_outer_edge_glow_south",
	"concept_outer_edge_glow_west",
	"EastCombatLaneFloorInset",
	"bumper_",
	"crate_left_",
	"crate_wood",
	"orange_block",
	"tan_block",
	"ChunkyCoverClusterWest",
	"gold_bolt_",
]

const DRESSING_ASSET_BASE := "res://assets/models/third_party/kenney/curated_food_dojo/"

var _ringout_hud: CanvasLayer = null

func _ready() -> void:
	super._ready()

func _build_map_layout() -> void:
	_clear_open_ringout_nodes()

	var abyss_root = Node3D.new()
	abyss_root.name = ABYSS_ROOT_NAME
	add_child(abyss_root)

	var backdrop_root = Node3D.new()
	backdrop_root.name = BACKDROP_ROOT_NAME
	add_child(backdrop_root)

	var playable_root = Node3D.new()
	playable_root.name = PLAYABLE_ROOT_NAME
	add_child(playable_root)

	var cover_root = Node3D.new()
	cover_root.name = COVER_ROOT_NAME
	add_child(cover_root)

	var glow_root = Node3D.new()
	glow_root.name = EDGE_GLOW_ROOT_NAME
	add_child(glow_root)

	var art_root = Node3D.new()
	art_root.name = ART_ROOT_NAME
	add_child(art_root)

	var deck_mat = _material(Color("#c7a47a"), 0.95, 0.07)
	var deck_alt_mat = _material(Color("#d7c094"), 0.95, 0.07)
	var bridge_mat = _material(Color("#ad7b57"), 0.92, 0.07)
	var cliff_mat = _material(Color("#4d4f76"), 0.98, 0.06)
	var dark_cliff_mat = _material(Color("#2e3154"), 0.98, 0.04)
	var cover_orange_mat = _material(Color("#dc7a2c"), 0.86, 0.16)
	var cover_yellow_mat = _material(Color("#d4b944"), 0.90, 0.12)
	var cover_red_mat = _material(Color("#c7493b"), 0.88, 0.14)
	var cover_tan_mat = _material(Color("#d8b47b"), 0.92, 0.10)
	var metal_mat = _material(Color("#8f9690"), 0.58, 0.18)
	var water_mat = _abyss_gradient_material()
	var glow_mat = _emissive_material(Color(1.0, 0.42, 0.08, 0.86), Color("#ff8128"), 1.25)

	_spawn_abyss_plane("AbyssPlane", Vector3(0, -12.28, 0), Vector2(260, 220), abyss_root, water_mat)
	_build_abyss_clouds(abyss_root)
	_build_background_islands(backdrop_root)

	_spawn_platform("MainDeck", Vector3(0, -1, 0), Vector3(52, 2, 36), playable_root, deck_mat, cliff_mat)
	_spawn_platform("MainDeckWestLip", Vector3(-20, -0.98, 9), Vector3(18, 2, 20), playable_root, deck_mat, cliff_mat)
	_spawn_platform("MainDeckEastLip", Vector3(21, -0.98, -3), Vector3(18, 2, 23), playable_root, deck_mat, cliff_mat)
	_spawn_platform("NorthDeck", Vector3(4, -1, -30), Vector3(22, 2, 15), playable_root, deck_alt_mat, dark_cliff_mat)
	_spawn_platform("EastDeck", Vector3(41.75, -1, 3), Vector3(12.5, 2, 18), playable_root, deck_alt_mat, dark_cliff_mat)
	_spawn_platform("SouthDeck", Vector3(9, -1, 30), Vector3(24, 2, 16), playable_root, deck_alt_mat, dark_cliff_mat)
	_spawn_platform("WestDeck", Vector3(-41.55, -1, 2), Vector3(12.9, 2, 20), playable_root, deck_alt_mat, dark_cliff_mat)

	_spawn_platform("NorthBridge", Vector3(4, -0.3, -20), Vector3(11, 1.3, 9), playable_root, bridge_mat, cliff_mat)
	_spawn_platform("EastBridge", Vector3(32.75, -0.3, 2), Vector3(6.5, 1.3, 8), playable_root, bridge_mat, cliff_mat)
	_spawn_platform("SouthBridge", Vector3(7, -0.3, 20), Vector3(11, 1.3, 9), playable_root, bridge_mat, cliff_mat)
	_spawn_platform("WestBridge", Vector3(-32.10, -0.3, 2), Vector3(7.2, 1.3, 9), playable_root, bridge_mat, cliff_mat)

	_build_tile_lines(playable_root)
	_build_edge_glow(glow_root, glow_mat)
	_build_chunky_cover(cover_root, cover_orange_mat, cover_yellow_mat, cover_red_mat, cover_tan_mat, metal_mat)
	_build_center_pickup_pad(cover_root, glow_mat, metal_mat)
	_build_art_dressing(art_root, cover_orange_mat, cover_yellow_mat, cover_red_mat, cover_tan_mat, metal_mat, glow_mat)
	_build_blender_visual_layer()

func _build_map_dressing() -> void:
	var root = get_node_or_null("OpenRingoutDressing")
	if root:
		root.queue_free()

	root = Node3D.new()
	root.name = "OpenRingoutDressing"
	add_child(root)

	for prop in [
		[DRESSING_ASSET_BASE + "nature_tree_small.glb", Vector3(-66, -10, -36), Vector3(3.2, 3.4, 3.2), 20.0],
		[DRESSING_ASSET_BASE + "nature_tree_simple.glb", Vector3(64, -10, -30), Vector3(3.0, 3.2, 3.0), -12.0],
		[DRESSING_ASSET_BASE + "nature_tree_small.glb", Vector3(-58, -10, 38), Vector3(2.9, 3.1, 2.9), -32.0],
		[DRESSING_ASSET_BASE + "nature_tree_simple.glb", Vector3(57, -10, 38), Vector3(3.1, 3.3, 3.1), 18.0],
		[DRESSING_ASSET_BASE + "nature_rock_smallTopA.glb", Vector3(-56, -10.4, -13), Vector3(2.7, 2.4, 2.7), 0.0],
		[DRESSING_ASSET_BASE + "nature_rock_smallA.glb", Vector3(58, -10.4, 17), Vector3(2.4, 2.1, 2.4), 35.0],
		[DRESSING_ASSET_BASE + "nature_plant_bushDetailed.glb", Vector3(-46, -10.3, 32), Vector3(2.2, 2.2, 2.2), 0.0],
		[DRESSING_ASSET_BASE + "nature_grass_large.glb", Vector3(45, -10.4, -34), Vector3(2.2, 2.2, 2.2), -20.0],
	]:
		_spawn_prop(prop[0], prop[1], prop[2], root, prop[3])

func _get_spawn_points() -> Array:
	return [
		Vector3(-17.5, 1.05, -9.5),
		Vector3(17.5, 1.05, -8.5),
		Vector3(-17.0, 1.05, 10.5),
		Vector3(17.0, 1.05, 10.0),
	]

func _configure_map_runtime() -> void:
	var config = RuntimeGlobals.game_config()
	if config:
		config.set("default_lives", 4)
		config.set("respawn_delay", 1.15)
		config.set("invincible_duration", 1.5)
		config.set("fall_threshold", -16.0)
		config.set("control_mode", "lock_on")
		config.set("character_speed", 620.0)
		config.set("character_horizontal_damp", 2.4)
		config.set("character_air_horizontal_damp", 0.25)
		config.set("character_gravity_scale", 24.0)
		config.set("bullet_speed_multiplier", 1.0)
		config.set("knockback_multiplier", 1.35)
		config.set("knockback_lift_ratio", 0.24)
		config.set("max_recoil_impulse", 9.5)
		config.set("weapon_feel_overrides", {
			"pistol": {"knockback_power": 92.0, "damage": 14.0, "bullet_lifetime": 1.45},
			"smg": {"knockback_power": 68.0, "damage": 7.0, "bullet_lifetime": 1.25},
			"ak_rifle": {"knockback_power": 92.0, "damage": 13.0, "bullet_lifetime": 1.55},
			"sniper": {"knockback_power": 330.0, "damage": 42.0, "bullet_lifetime": 1.9},
			"gatling": {"knockback_power": 58.0, "damage": 5.0, "bullet_lifetime": 1.25},
			"shotgun": {"knockback_power": 25.0, "damage": 4.5, "bullet_lifetime": 0.85},
		})

	if weapon_spawner:
		var center_points = [
			Vector3(0, 1.65, 0),
		]
		var random_points = [
			Vector3(-3, 1.65, -32),
			Vector3(43, 1.65, 1),
			Vector3(13, 1.65, 31),
			Vector3(-43, 1.65, 8),
		]
		weapon_spawner.initial_delay = 0.45
		weapon_spawner.stay_duration = 20.0
		weapon_spawner.random_spawn_interval = 22.5
		weapon_spawner.random_stay_duration = 4.5
		weapon_spawner.respawn_cooldown = 4.5
		weapon_spawner.max_active_pickups = 2
		weapon_spawner.fixed_spawn_points = center_points
		weapon_spawner.random_spawn_points = random_points
		weapon_spawner.custom_spawn_clusters = []
		weapon_spawner.custom_spawn_points = []

func _apply_map_visual_overrides() -> void:
	var camera = get_node_or_null("GlobalCamera") as Camera3D
	if camera:
		camera.projection = Camera3D.PROJECTION_ORTHOGONAL
		camera.position = Vector3(40, 50, 55)
		camera.look_at(Vector3(2, 0, 2), Vector3.UP)
		camera.size = 58.5
		camera.current = true

	var light = get_node_or_null("DirectionalLight3D") as DirectionalLight3D
	if light:
		light.light_color = Color("#ffd2a3")
		light.light_energy = 1.06
		light.shadow_enabled = true
		light.shadow_blur = 2.6
		light.rotation_degrees = Vector3(-48, 38, 0)

	_configure_toy_light("ToyFillLight", Vector3(-36, 26, 22), Color("#ffd0b2"), 0.18, 82.0)
	_configure_toy_light("ToyRimLight", Vector3(42, 24, -36), Color("#9bbfff"), 0.32, 100.0)

	var env_node = get_node_or_null("WorldEnvironment") as WorldEnvironment
	if env_node == null:
		env_node = WorldEnvironment.new()
		env_node.name = "WorldEnvironment"
		add_child(env_node)

	var env = Environment.new()
	var sky = Sky.new()
	var sky_mat = ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color("#536fa6")
	sky_mat.sky_horizon_color = Color("#f0b6aa")
	sky_mat.ground_bottom_color = Color("#2e4778")
	sky_mat.ground_horizon_color = Color("#f0b78e")
	sky.sky_material = sky_mat
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_exposure = 0.76
	env.adjustment_enabled = true
	env.adjustment_contrast = 1.12
	env.adjustment_saturation = 1.16
	env.adjustment_brightness = 1.02
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("#f5c0a2")
	env.ambient_light_energy = 0.14
	env.fog_enabled = true
	env.fog_light_color = Color("#c2a0bd")
	env.fog_density = 0.0018
	env.fog_sun_scatter = 0.22
	env.ssao_enabled = true
	env.ssao_radius = 1.65
	env.ssao_intensity = 1.05
	env.ssao_power = 1.55
	env.glow_enabled = true
	env.glow_intensity = 0.44
	env.glow_strength = 0.88
	env.glow_bloom = 0.08
	env_node.environment = env

func _configure_toy_light(name: String, pos: Vector3, color: Color, energy: float, light_range: float) -> void:
	var light = get_node_or_null(name) as OmniLight3D
	if light == null:
		light = OmniLight3D.new()
		light.name = name
		add_child(light)
	light.position = pos
	light.light_color = color
	light.light_energy = energy
	light.omni_range = light_range
	light.shadow_enabled = false

func _uses_fixed_runtime_camera() -> bool:
	return true

func _setup_control_mode_panel() -> void:
	pass

func _setup_hud() -> void:
	_ringout_hud = RINGOUT_HUD_SCRIPT.new()
	_ringout_hud.name = "OpenRingoutHUD"
	add_child(_ringout_hud)
	_ringout_hud.set_characters(_characters)

func _spawn_characters() -> void:
	super._spawn_characters()
	await get_tree().process_frame
	var loadouts = ["pistol", "smg", "ak_rifle", "shotgun"]
	for i in range(_characters.size()):
		var character = _characters[i] as BaseCharacter
		if character == null:
			continue
		var old_hud = character.get_node_or_null("GameHUD")
		if old_hud:
			old_hud.queue_free()
		_face_character_toward_center(character)
		_apply_slice_loadout(character, loadouts[i] if i < loadouts.size() else "pistol")

func _face_character_toward_center(character: BaseCharacter) -> void:
	var dir = -character.global_position
	dir.y = 0
	if dir.length_squared() <= 0.001:
		return
	character.transform.basis = Basis.looking_at(dir.normalized(), Vector3.UP)

func _apply_slice_loadout(character: BaseCharacter, loadout: String) -> void:
	var visual = character.get_visual()
	if visual:
		visual.scale = Vector3.ONE * 1.42
	if character.weapon_manager == null:
		return
	match loadout:
		"smg":
			character.weapon_manager.equip_weapon(WeaponData.create_smg())
		"ak_rifle":
			character.weapon_manager.equip_weapon(WeaponData.create_ak_rifle())
		"sniper":
			character.weapon_manager.equip_weapon(WeaponData.create_sniper())
		"gatling":
			character.weapon_manager.equip_weapon(WeaponData.create_gatling())
		"shotgun":
			character.weapon_manager.equip_weapon(WeaponData.create_shotgun())
		_:
			if visual:
				visual.set_weapon_visual(&"pistol")
	if visual:
		visual.set_weapon_visual(StringName(loadout))

func _clear_open_ringout_nodes() -> void:
	for child in get_children():
		if child.name in [
			"Floor",
			"Obstacles",
			"ExternalArt",
			"KaykitMap",
			"CommercialSliceWhitebox",
			"CommercialSliceBackdrop",
			"CommercialSliceDressing",
			"OpenRingoutDressing",
			PLAYABLE_ROOT_NAME,
			COVER_ROOT_NAME,
			EDGE_GLOW_ROOT_NAME,
			ABYSS_ROOT_NAME,
			BACKDROP_ROOT_NAME,
			ART_ROOT_NAME,
			BLENDER_VISUAL_ROOT_NAME,
		]:
			child.queue_free()

func _spawn_platform(
	name: String,
	pos: Vector3,
	size: Vector3,
	parent: Node3D,
	top_mat: Material,
	side_mat: Material
) -> Node3D:
	var root = _spawn_whitebox_block(name, pos, size, parent, top_mat)
	var collision_visual = root.get_child(0) as MeshInstance3D
	if collision_visual:
		collision_visual.visible = false
	_build_platform_art(root, size, top_mat, side_mat)
	return root

func _spawn_whitebox_block(
	name: String,
	pos: Vector3,
	size: Vector3,
	parent: Node3D,
	mat: Material,
	collision_enabled: bool = true,
	yaw_deg: float = 0.0
) -> Node3D:
	var root = Node3D.new()
	root.name = name
	root.position = pos
	root.rotation_degrees = Vector3(0, yaw_deg, 0)
	parent.add_child(root)

	var mesh_instance = MeshInstance3D.new()
	var mesh = BoxMesh.new()
	mesh.size = size
	mesh_instance.mesh = mesh
	mesh_instance.position = Vector3(0, size.y * 0.5, 0)
	mesh_instance.material_override = mat
	root.add_child(mesh_instance)

	if collision_enabled:
		var static_body = StaticBody3D.new()
		var collision_shape = CollisionShape3D.new()
		var box = BoxShape3D.new()
		box.size = size
		collision_shape.shape = box
		collision_shape.position = Vector3(0, size.y * 0.5, 0)
		static_body.add_child(collision_shape)
		root.add_child(static_body)

	return root

func _spawn_visual_box(name: String, pos: Vector3, size: Vector3, parent: Node3D, mat: Material) -> MeshInstance3D:
	var mesh_instance = MeshInstance3D.new()
	mesh_instance.name = name
	var mesh = BoxMesh.new()
	mesh.size = size
	mesh_instance.mesh = mesh
	mesh_instance.position = pos
	mesh_instance.material_override = mat
	parent.add_child(mesh_instance)
	return mesh_instance

func _build_art_dressing(
	parent: Node3D,
	orange_mat: Material,
	yellow_mat: Material,
	red_mat: Material,
	tan_mat: Material,
	metal_mat: Material,
	glow_mat: Material
) -> void:
	_spawn_art_capsule("NorthOrangeBumper", Vector3(-13, 1.38, -16.8), Vector3(9.0, 1.0, 2.0), parent, red_mat, 0.0)
	_spawn_art_capsule("SouthOrangeBumper", Vector3(-4.0, 1.38, 16.7), Vector3(13.0, 1.0, 2.0), parent, orange_mat, 0.0)
	_spawn_art_capsule("WestOrangeBumper", Vector3(-25.2, 1.38, -12.0), Vector3(10.0, 1.0, 2.0), parent, orange_mat, 12.0)

	_spawn_art_capsule("NorthBridgeSoftRailL", Vector3(-2.4, 1.5, -22.9), Vector3(7.6, 0.55, 0.7), parent, glow_mat, 90.0)
	_spawn_art_capsule("NorthBridgeSoftRailR", Vector3(10.4, 1.5, -22.9), Vector3(7.6, 0.55, 0.7), parent, glow_mat, 90.0)
	_spawn_art_capsule("SouthBridgeSoftRailL", Vector3(0.8, 1.5, 22.9), Vector3(7.6, 0.55, 0.7), parent, glow_mat, 90.0)
	_spawn_art_capsule("SouthBridgeSoftRailR", Vector3(13.2, 1.5, 22.9), Vector3(7.6, 0.55, 0.7), parent, glow_mat, 90.0)


	for bolt in [
		Vector3(-23, 1.62, -15), Vector3(23, 1.62, -15),
		Vector3(-23, 1.62, 15), Vector3(23, 1.62, 15),
		Vector3(-44, 1.62, -4), Vector3(-44, 1.62, 8),
		Vector3(43, 1.62, -5), Vector3(43, 1.62, 10),
		Vector3(0, 1.62, -35), Vector3(10, 1.62, -35),
		Vector3(2, 1.62, 35), Vector3(16, 1.62, 35),
	]:
		_spawn_art_bolt("GoldBolt", bolt, parent, yellow_mat)

	_spawn_art_cube("OrangeToyBlock", Vector3(16.5, 1.45, -13.5), Vector3(3.2, 2.4, 3.2), parent, orange_mat)
	_spawn_art_cube("YellowToyBlock", Vector3(-35, 1.45, -5), Vector3(3.0, 1.7, 3.0), parent, yellow_mat)

func _spawn_art_capsule(
	name: String,
	pos: Vector3,
	size: Vector3,
	parent: Node3D,
	mat: Material,
	yaw_deg: float
) -> Node3D:
	var root = Node3D.new()
	root.name = name
	root.position = pos
	root.rotation_degrees = Vector3(0, yaw_deg, 0)
	parent.add_child(root)

	var mesh_instance = MeshInstance3D.new()
	var capsule = CapsuleMesh.new()
	capsule.radius = size.z * 0.5
	capsule.height = size.x
	capsule.radial_segments = 18
	mesh_instance.mesh = capsule
	mesh_instance.rotation_degrees = Vector3(0, 0, 90)
	mesh_instance.scale = Vector3(1, size.y / maxf(size.z, 0.1), 1)
	mesh_instance.material_override = mat
	root.add_child(mesh_instance)
	return root

func _spawn_art_panel(name: String, pos: Vector3, size: Vector3, parent: Node3D, mat: Material, yaw_deg: float) -> MeshInstance3D:
	var panel = _spawn_visual_box(name, pos, size, parent, mat)
	panel.rotation_degrees = Vector3(0, yaw_deg, 0)
	return panel

func _spawn_art_bolt(name: String, pos: Vector3, parent: Node3D, mat: Material) -> MeshInstance3D:
	var bolt = MeshInstance3D.new()
	bolt.name = name
	var mesh = CylinderMesh.new()
	mesh.top_radius = 0.42
	mesh.bottom_radius = 0.42
	mesh.height = 0.18
	mesh.radial_segments = 12
	bolt.mesh = mesh
	bolt.position = pos
	bolt.material_override = mat
	parent.add_child(bolt)
	return bolt

func _spawn_art_cube(name: String, pos: Vector3, size: Vector3, parent: Node3D, mat: Material) -> MeshInstance3D:
	var cube = _spawn_visual_box(name, pos, size, parent, mat)
	cube.rotation_degrees = Vector3(0, 8.0, 0)
	return cube

func _build_blender_visual_layer() -> void:
	var existing = get_node_or_null(BLENDER_VISUAL_ROOT_NAME)
	if existing:
		existing.queue_free()

	var visual_root = Node3D.new()
	visual_root.name = BLENDER_VISUAL_ROOT_NAME
	add_child(visual_root)

	var packed_scene = load(BLENDER_VISUAL_SCENE_PATH) as PackedScene
	if packed_scene == null:
		push_warning("Open Ringout Blender visual scene is not available: %s" % BLENDER_VISUAL_SCENE_PATH)
		return

	var visual_scene = packed_scene.instantiate() as Node3D
	if visual_scene == null:
		push_warning("Open Ringout Blender visual scene could not be instantiated.")
		return

	visual_scene.name = "BlenderAuthoredOpenRingoutVisuals"
	visual_root.add_child(visual_scene)
	_build_sunset_v2_visual_layer(visual_root, visual_scene)
	_set_generated_platform_art_visible(false)
	_set_generated_support_visuals_visible(false)
	var art_root = get_node_or_null(ART_ROOT_NAME)
	if art_root:
		art_root.visible = false

func _build_sunset_v2_visual_layer(parent: Node3D, legacy_visual: Node3D) -> void:
	var packed_scene = load(SUNSET_V2_VISUAL_SCENE_PATH) as PackedScene
	if packed_scene == null:
		push_warning("Sunset V2 visual scene is not available: %s" % SUNSET_V2_VISUAL_SCENE_PATH)
		return
	var visual_scene = packed_scene.instantiate() as Node3D
	if visual_scene == null:
		push_warning("Sunset V2 visual scene could not be instantiated.")
		return
	visual_scene.name = SUNSET_V2_VISUAL_ROOT_NAME
	parent.add_child(visual_scene)
	_set_sunset_v2_legacy_nodes_visible(legacy_visual, false)

func _set_sunset_v2_legacy_nodes_visible(node: Node, is_visible: bool) -> void:
	if node is Node3D and _is_sunset_v2_replaced_legacy_name(String(node.name)):
		(node as Node3D).visible = is_visible
	for child in node.get_children():
		_set_sunset_v2_legacy_nodes_visible(child, is_visible)

func _is_sunset_v2_replaced_legacy_name(node_name: String) -> bool:
	for prefix in SUNSET_V2_HIDDEN_LEGACY_PREFIXES:
		if node_name.begins_with(String(prefix)):
			return true
	return false

func _set_generated_support_visuals_visible(is_visible: bool) -> void:
	var cover_root = get_node_or_null(COVER_ROOT_NAME)
	if cover_root:
		cover_root.visible = true
		for child in cover_root.get_children():
			if child.name == "CenterPickupPad":
				child.visible = true
			else:
				_set_visual_meshes_visible(child, is_visible)
	var glow_root = get_node_or_null(EDGE_GLOW_ROOT_NAME)
	if glow_root:
		glow_root.visible = is_visible
	var playable_root = get_node_or_null(PLAYABLE_ROOT_NAME)
	if playable_root:
		var tile_lines = playable_root.get_node_or_null("TileLines")
		if tile_lines:
			tile_lines.visible = is_visible

func _set_visual_meshes_visible(node: Node, is_visible: bool) -> void:
	if node is MeshInstance3D:
		(node as MeshInstance3D).visible = is_visible
	for child in node.get_children():
		_set_visual_meshes_visible(child, is_visible)

func _set_generated_platform_art_visible(is_visible: bool) -> void:
	var playable_root = get_node_or_null(PLAYABLE_ROOT_NAME)
	if playable_root == null:
		return
	for platform in playable_root.get_children():
		for child in platform.get_children():
			if child is MeshInstance3D and String(child.name).begins_with("Art"):
				(child as MeshInstance3D).visible = is_visible

func _build_platform_art(root: Node3D, size: Vector3, top_mat: Material, side_mat: Material) -> void:
	var radius = minf(size.x, size.z) * 0.12
	var points = _rounded_rect_points(size.x, size.z, radius, 4)
	var top_y = size.y + 0.055
	var skirt_bottom_y = -5.1

	var top = MeshInstance3D.new()
	top.name = "ArtTop"
	top.mesh = _make_top_mesh(points, top_y)
	top.material_override = top_mat
	root.add_child(top)

	var skirt = MeshInstance3D.new()
	skirt.name = "ArtSkirt"
	skirt.mesh = _make_side_mesh(points, top_y - 0.08, skirt_bottom_y)
	skirt.material_override = side_mat
	root.add_child(skirt)

	var rim = MeshInstance3D.new()
	rim.name = "ArtRim"
	rim.mesh = _make_side_mesh(_scale_points(points, 1.015), top_y + 0.05, top_y - 0.22)
	rim.material_override = _emissive_material(Color(1.0, 0.60, 0.18, 0.82), Color("#ff9a33"), 0.95)
	root.add_child(rim)

	var bevel = MeshInstance3D.new()
	bevel.name = "ArtBevel"
	bevel.mesh = _make_side_mesh(_scale_points(points, 0.965), top_y - 0.04, top_y - 0.55)
	bevel.material_override = _material(Color("#b58b63"), 0.92, 0.07)
	root.add_child(bevel)

func _rounded_rect_points(width: float, depth: float, radius: float, segments: int) -> Array[Vector2]:
	var hx = width * 0.5
	var hz = depth * 0.5
	var r = clampf(radius, 0.5, minf(hx, hz) - 0.1)
	var centers = [
		Vector2(hx - r, -hz + r),
		Vector2(hx - r, hz - r),
		Vector2(-hx + r, hz - r),
		Vector2(-hx + r, -hz + r),
	]
	var ranges = [
		[-90.0, 0.0],
		[0.0, 90.0],
		[90.0, 180.0],
		[180.0, 270.0],
	]
	var points: Array[Vector2] = []
	for corner in range(4):
		for step in range(segments + 1):
			var t = float(step) / float(segments)
			var angle = deg_to_rad(lerpf(ranges[corner][0], ranges[corner][1], t))
			points.append(centers[corner] + Vector2(cos(angle), sin(angle)) * r)
	return points

func _scale_points(points: Array[Vector2], scale_factor: float) -> Array[Vector2]:
	var scaled: Array[Vector2] = []
	for point in points:
		scaled.append(point * scale_factor)
	return scaled

func _make_top_mesh(points: Array[Vector2], y: float) -> ArrayMesh:
	var vertices: Array[Vector3] = []
	var normals: Array[Vector3] = []
	var center = Vector3.ZERO
	for point in points:
		center += Vector3(point.x, y, point.y)
	center /= float(points.size())

	for i in range(points.size()):
		var a = Vector3(points[i].x, y, points[i].y)
		var b2 = points[(i + 1) % points.size()]
		var b = Vector3(b2.x, y, b2.y)
		vertices.append(center)
		vertices.append(a)
		vertices.append(b)
		normals.append(Vector3.UP)
		normals.append(Vector3.UP)
		normals.append(Vector3.UP)
	return _array_mesh(vertices, normals)

func _make_side_mesh(points: Array[Vector2], top_y: float, bottom_y: float) -> ArrayMesh:
	var vertices: Array[Vector3] = []
	var normals: Array[Vector3] = []
	for i in range(points.size()):
		var p0 = points[i]
		var p1 = points[(i + 1) % points.size()]
		var top0 = Vector3(p0.x, top_y, p0.y)
		var top1 = Vector3(p1.x, top_y, p1.y)
		var bottom0 = Vector3(p0.x, bottom_y, p0.y)
		var bottom1 = Vector3(p1.x, bottom_y, p1.y)
		var normal = Vector3(p0.y - p1.y, 0.0, p1.x - p0.x).normalized()
		for vertex in [top0, top1, bottom1, top0, bottom1, bottom0]:
			vertices.append(vertex)
			normals.append(normal)
	return _array_mesh(vertices, normals)

func _array_mesh(vertices: Array[Vector3], normals: Array[Vector3]) -> ArrayMesh:
	var mesh = ArrayMesh.new()
	var arrays = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = PackedVector3Array(vertices)
	arrays[Mesh.ARRAY_NORMAL] = PackedVector3Array(normals)
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh

func _build_tile_lines(parent: Node3D) -> void:
	var line_mat = _material(Color(0.44, 0.35, 0.26, 0.26), 1.0, 0.0)
	line_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	var line_root = Node3D.new()
	line_root.name = "TileLines"
	parent.add_child(line_root)
	for x in [-18, -9, 0, 9, 18]:
		_spawn_visual_box("TileLineX%d" % int(x), Vector3(x, 1.035, 0), Vector3(0.18, 0.06, 34), line_root, line_mat)
	for z in [-12, -4, 4, 12]:
		_spawn_visual_box("TileLineZ%d" % int(z), Vector3(0, 1.04, z), Vector3(49, 0.06, 0.18), line_root, line_mat)

func _build_edge_glow(parent: Node3D, mat: Material) -> void:
	for edge in [
		["GlowMainNorth", Vector3(0, 1.14, -18.25), Vector3(45, 0.15, 0.38)],
		["GlowMainSouth", Vector3(0, 1.14, 18.25), Vector3(45, 0.15, 0.38)],
		["GlowMainWest", Vector3(-26.25, 1.14, 0), Vector3(0.38, 0.15, 31)],
		["GlowMainEast", Vector3(26.25, 1.14, 0), Vector3(0.38, 0.15, 31)],
		["GlowNorthOuter", Vector3(4, 1.14, -37.65), Vector3(19, 0.15, 0.38)],
		["GlowEastOuter", Vector3(48.25, 1.14, 3), Vector3(0.38, 0.15, 15)],
		["GlowSouthOuter", Vector3(9, 1.14, 37.65), Vector3(20, 0.15, 0.38)],
		["GlowWestOuter", Vector3(-48.25, 1.14, 2), Vector3(0.38, 0.15, 16)],
		["GlowNorthBridgeL", Vector3(-2.2, 1.06, -20), Vector3(0.34, 0.12, 8)],
		["GlowNorthBridgeR", Vector3(10.2, 1.06, -20), Vector3(0.34, 0.12, 8)],
		["GlowSouthBridgeL", Vector3(0.8, 1.06, 20), Vector3(0.34, 0.12, 8)],
		["GlowSouthBridgeR", Vector3(13.2, 1.06, 20), Vector3(0.34, 0.12, 8)],
		["GlowEastBridgeT", Vector3(32.75, 1.06, -2.5), Vector3(6.2, 0.12, 0.34)],
		["GlowEastBridgeB", Vector3(32.75, 1.06, 6.5), Vector3(6.2, 0.12, 0.34)],
		["GlowWestBridgeT", Vector3(-32.10, 1.06, -2.5), Vector3(6.9, 0.12, 0.34)],
		["GlowWestBridgeB", Vector3(-32.10, 1.06, 6.5), Vector3(6.9, 0.12, 0.34)],
	]:
		_spawn_visual_box(edge[0], edge[1], edge[2], parent, mat)

func _build_chunky_cover(
	parent: Node3D,
	orange_mat: Material,
	yellow_mat: Material,
	red_mat: Material,
	tan_mat: Material,
	metal_mat: Material
) -> void:
	_spawn_collision_box("BumperNorthCollision", Vector3(-13.0, 1.75, -16.8), Vector3(9.0, 1.84, 1.84), parent, 0.0)
	_spawn_collision_box("BumperCenterNorthCollision", Vector3(5.0, 1.75, -13.5), Vector3(7.0, 1.84, 1.84), parent, 0.0)
	_spawn_collision_box("BumperCenterCollision", Vector3(7.0, 1.75, -1.5), Vector3(8.0, 2.10, 2.10), parent, 0.0)
	_spawn_collision_box("BumperSouthCollision", Vector3(-4.0, 1.75, 16.7), Vector3(13.0, 1.76, 1.76), parent, 0.0)

	_spawn_collision_box("LeftCrateACollision", Vector3(-17.0, 1.70, 6.0), Vector3(2.8, 2.0, 2.8), parent, 0.0)
	_spawn_collision_box("LeftCrateBCollision", Vector3(-14.2, 1.70, 6.0), Vector3(2.8, 2.0, 2.8), parent, 0.0)
	_spawn_collision_box("WoodCrateCollision", Vector3(-6.0, 1.68, 12.0), Vector3(5.0, 1.9, 2.8), parent, 2.0)
	_spawn_collision_box("OrangeBlockCollision", Vector3(16.5, 1.72, -13.5), Vector3(3.4, 2.5, 3.4), parent, 8.0)
	_spawn_collision_box("TanBlockCollision", Vector3(19.0, 1.66, 2.0), Vector3(5.2, 2.0, 4.0), parent, -4.0)

	_spawn_collision_box("WestChunkyCoverCollision", Vector3(-13.3, 1.70, 5.6), Vector3(4.8, 1.62, 2.9), parent, 5.0)
	_spawn_collision_box("WestChunkyCushionACollision", Vector3(-15.7, 1.78, 5.7), Vector3(1.40, 1.46, 2.25), parent, 5.0)
	_spawn_collision_box("WestChunkyCushionBCollision", Vector3(-11.0, 1.78, 5.4), Vector3(1.35, 1.46, 2.25), parent, 5.0)

func _spawn_collision_box(
	name: String,
	center: Vector3,
	size: Vector3,
	parent: Node3D,
	yaw_deg: float
) -> Node3D:
	var root = Node3D.new()
	root.name = name
	root.position = center
	root.rotation_degrees = Vector3(0, yaw_deg, 0)
	parent.add_child(root)

	var body = StaticBody3D.new()
	body.name = "StaticBody3D"
	var shape = CollisionShape3D.new()
	var box = BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)
	root.add_child(body)
	return root

func _spawn_capsule_cover(
	name: String,
	pos: Vector3,
	size: Vector3,
	parent: Node3D,
	mat: Material,
	yaw_deg: float
) -> Node3D:
	var root = Node3D.new()
	root.name = name
	root.position = pos
	root.rotation_degrees = Vector3(0, yaw_deg, 0)
	parent.add_child(root)

	var mesh_instance = MeshInstance3D.new()
	var capsule = CapsuleMesh.new()
	capsule.radius = size.z * 0.5
	capsule.height = size.x
	capsule.radial_segments = 16
	mesh_instance.mesh = capsule
	mesh_instance.rotation_degrees = Vector3(0, 0, 90)
	mesh_instance.position = Vector3(0, size.y * 0.5, 0)
	mesh_instance.scale = Vector3(1, size.y / size.z, 1)
	mesh_instance.material_override = mat
	root.add_child(mesh_instance)

	var body = StaticBody3D.new()
	var shape = CollisionShape3D.new()
	var box = BoxShape3D.new()
	box.size = size
	shape.shape = box
	shape.position = Vector3(0, size.y * 0.5, 0)
	body.add_child(shape)
	root.add_child(body)
	return root

func _spawn_crate_stack(name: String, pos: Vector3, parent: Node3D, mat_a: Material, mat_b: Material, trim_mat: Material) -> Node3D:
	var root = Node3D.new()
	root.name = name
	root.position = pos
	parent.add_child(root)
	_spawn_soft_cube("%sA" % name, Vector3(-1.2, 0, 0), Vector3(2.5, 1.8, 2.6), root, mat_a)
	_spawn_soft_cube("%sB" % name, Vector3(1.2, 0, 0), Vector3(2.5, 1.8, 2.6), root, mat_a)
	_spawn_visual_box("%sTrim" % name, Vector3(0, 2.0, 0), Vector3(5.2, 0.25, 2.8), root, trim_mat)
	_spawn_soft_cube("%sBottom" % name, Vector3(0, -0.95, 0), Vector3(5.3, 0.55, 2.9), root, mat_b)
	return root

func _spawn_soft_cube(name: String, pos: Vector3, size: Vector3, parent: Node3D, mat: Material) -> Node3D:
	var root = Node3D.new()
	root.name = name
	root.position = pos
	parent.add_child(root)

	var mesh_instance = MeshInstance3D.new()
	var mesh = BoxMesh.new()
	mesh.size = size
	mesh_instance.mesh = mesh
	mesh_instance.position = Vector3(0, size.y * 0.5, 0)
	mesh_instance.material_override = mat
	root.add_child(mesh_instance)

	var body = StaticBody3D.new()
	var shape = CollisionShape3D.new()
	var box = BoxShape3D.new()
	box.size = size
	shape.shape = box
	shape.position = Vector3(0, size.y * 0.5, 0)
	body.add_child(shape)
	root.add_child(body)
	return root

func _spawn_round_cover(name: String, pos: Vector3, parent: Node3D, body_mat: Material, trim_mat: Material) -> Node3D:
	var root = Node3D.new()
	root.name = name
	root.position = pos
	parent.add_child(root)

	var body_mesh = MeshInstance3D.new()
	var cylinder = CylinderMesh.new()
	cylinder.top_radius = 1.6
	cylinder.bottom_radius = 1.6
	cylinder.height = 1.8
	cylinder.radial_segments = 18
	body_mesh.mesh = cylinder
	body_mesh.position = Vector3(0, 0.9, 0)
	body_mesh.material_override = body_mat
	root.add_child(body_mesh)

	var cap = MeshInstance3D.new()
	var cap_mesh = CylinderMesh.new()
	cap_mesh.top_radius = 1.75
	cap_mesh.bottom_radius = 1.75
	cap_mesh.height = 0.22
	cap_mesh.radial_segments = 18
	cap.mesh = cap_mesh
	cap.position = Vector3(0, 1.92, 0)
	cap.material_override = trim_mat
	root.add_child(cap)

	var collision_body = StaticBody3D.new()
	var shape = CollisionShape3D.new()
	var cyl_shape = CylinderShape3D.new()
	cyl_shape.radius = 1.6
	cyl_shape.height = 1.8
	shape.shape = cyl_shape
	shape.position = Vector3(0, 0.9, 0)
	collision_body.add_child(shape)
	root.add_child(collision_body)
	return root

func _build_center_pickup_pad(parent: Node3D, glow_mat: Material, metal_mat: Material) -> void:
	var pad = Node3D.new()
	pad.name = "CenterPickupPad"
	parent.add_child(pad)

	var base = MeshInstance3D.new()
	var base_mesh = CylinderMesh.new()
	base_mesh.top_radius = 3.0
	base_mesh.bottom_radius = 3.2
	base_mesh.height = 0.35
	base_mesh.radial_segments = 24
	base.mesh = base_mesh
	base.position = Vector3(0, 1.12, 0)
	base.material_override = metal_mat
	pad.add_child(base)

	var glow = MeshInstance3D.new()
	var glow_mesh = CylinderMesh.new()
	glow_mesh.top_radius = 2.1
	glow_mesh.bottom_radius = 2.1
	glow_mesh.height = 0.08
	glow_mesh.radial_segments = 24
	glow.mesh = glow_mesh
	glow.position = Vector3(0, 1.36, 0)
	glow.material_override = glow_mat
	pad.add_child(glow)

func _build_background_islands(parent: Node3D) -> void:
	var cliff_mat = _material(Color("#3f385a"), 0.98, 0.04)
	var dark_cliff_mat = _material(Color("#2a2e4d"), 0.98, 0.04)
	var grass_mat = _material(Color("#637b61"), 0.95, 0.08)
	var ledge_mat = _material(Color("#7f6a67"), 0.95, 0.06)
	var toy_red_mat = _material(Color("#ad4c45"), 0.88, 0.12)
	var toy_orange_mat = _material(Color("#ba6d38"), 0.86, 0.14)

	for island in [
		["BackdropIslandLeft", Vector3(-82, -12.7, -54), Vector3(14, 5.4, 9), -7.0],
		["BackdropIslandRight", Vector3(84, -12.8, -52), Vector3(15, 5.6, 10), 8.0],
		["BackdropIslandLowerLeft", Vector3(-74, -12.8, 64), Vector3(13, 5.0, 8), 10.0],
		["BackdropIslandLowerRight", Vector3(76, -12.8, 63), Vector3(13, 5.0, 8), -11.0],
	]:
		var prefix := island[0] as String
		var pos := island[1] as Vector3
		var size := island[2] as Vector3
		var yaw := island[3] as float
		_spawn_art_panel("%sCliff" % prefix, pos, size, parent, cliff_mat, yaw)
		_spawn_art_panel("%sGrass" % prefix, pos + Vector3(0, size.y * 0.52 + 0.18, 0), Vector3(size.x * 0.82, 0.34, size.z * 0.72), parent, grass_mat, yaw)
		_spawn_art_panel("%sLedge" % prefix, pos + Vector3(0, size.y * 0.28, -size.z * 0.26), Vector3(size.x * 0.54, 0.45, 1.4), parent, ledge_mat, yaw)

	for column in [
		["BackdropIslandLeftColumnA", Vector3(-86, -15.7, -51), Vector3(2.8, 5.8, 3.8), dark_cliff_mat],
		["BackdropIslandLeftColumnB", Vector3(-80, -16.1, -57), Vector3(2.4, 4.8, 3.0), dark_cliff_mat],
		["BackdropIslandRightColumnA", Vector3(88, -15.8, -49), Vector3(3.0, 6.0, 3.9), dark_cliff_mat],
		["BackdropIslandRightColumnB", Vector3(82, -16.2, -56), Vector3(2.4, 4.8, 3.0), dark_cliff_mat],
		["BackdropIslandLowerLeftColumnA", Vector3(-78, -15.8, 67), Vector3(2.8, 5.6, 3.6), dark_cliff_mat],
		["BackdropIslandLowerRightColumnA", Vector3(80, -15.8, 66), Vector3(2.8, 5.6, 3.6), dark_cliff_mat],
	]:
		_spawn_visual_box(column[0], column[1], column[2], parent, column[3])

	for prop in [
		["BackdropToyRedBlockL", Vector3(-81, -9.45, -55), Vector3(1.1, 0.8, 1.0), toy_red_mat, -8.0],
		["BackdropToyOrangeBlockR", Vector3(83, -9.40, -53), Vector3(1.2, 0.8, 1.0), toy_orange_mat, 6.0],
		["BackdropToyRedBlockLL", Vector3(-73, -9.65, 64), Vector3(1.0, 0.7, 0.9), toy_red_mat, 12.0],
		["BackdropToyOrangeBlockLR", Vector3(75, -9.65, 63), Vector3(1.0, 0.7, 0.9), toy_orange_mat, -10.0],
	]:
		_spawn_art_cube(prop[0], prop[1], prop[2], parent, prop[3])
		var node = parent.get_node_or_null(prop[0]) as Node3D
		if node:
			node.rotation_degrees.y = prop[4]

func _build_abyss_clouds(parent: Node3D) -> void:
	var warm_cloud_mat = _material(Color(0.98, 0.70, 0.58, 0.55), 1.0, 0.0)
	warm_cloud_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	var pink_mist_mat = _material(Color(0.82, 0.47, 0.65, 0.42), 1.0, 0.0)
	pink_mist_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	var cream_mist_mat = _material(Color(1.0, 0.84, 0.70, 0.46), 1.0, 0.0)
	cream_mist_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	var blue_mist_mat = _material(Color(0.58, 0.70, 0.98, 0.30), 1.0, 0.0)
	blue_mist_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	var shadow_mist_mat = _material(Color(0.16, 0.21, 0.42, 0.22), 1.0, 0.0)
	shadow_mist_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA

	for cloud in [
		["AbyssMistNorthWarmBank", Vector3(5, -11.68, -60), Vector2(46, 15), -4.0, warm_cloud_mat],
		["AbyssMistNorthWestBank", Vector3(-36, -11.66, -53), Vector2(26, 14), -12.0, cream_mist_mat],
		["AbyssMistNorthEastBank", Vector3(40, -11.66, -51), Vector2(30, 14), 10.0, pink_mist_mat],
		["AbyssMistSouthWarmBank", Vector3(-3, -11.65, 61), Vector2(52, 16), 5.0, warm_cloud_mat],
		["AbyssMistSouthWestBank", Vector3(-37, -11.63, 55), Vector2(28, 15), 10.0, blue_mist_mat],
		["AbyssMistSouthEastBank", Vector3(38, -11.63, 54), Vector2(30, 15), -10.0, cream_mist_mat],
		["AbyssMistLeftRear", Vector3(-61, -11.62, -25), Vector2(20, 18), -20.0, pink_mist_mat],
		["AbyssMistRightRear", Vector3(62, -11.61, -23), Vector2(22, 18), 18.0, warm_cloud_mat],
		["AbyssMistLeftFront", Vector3(-62, -11.60, 30), Vector2(23, 18), 13.0, blue_mist_mat],
		["AbyssMistRightFront", Vector3(62, -11.60, 33), Vector2(23, 18), -15.0, pink_mist_mat],
		["AbyssMistUnderNorthGap", Vector3(-18, -11.52, -25), Vector2(20, 10), -10.0, blue_mist_mat],
		["AbyssMistUnderEastGap", Vector3(36, -11.51, 16), Vector2(20, 10), 15.0, cream_mist_mat],
		["AbyssMistUnderSouthGap", Vector3(7, -11.50, 31), Vector2(20, 10), 5.0, warm_cloud_mat],
		["AbyssMistUnderWestGap", Vector3(-38, -11.50, 15), Vector2(20, 10), -16.0, blue_mist_mat],
		["AbyssMistDepthShadowNW", Vector3(-30, -11.98, -44), Vector2(22, 11), 7.0, shadow_mist_mat],
		["AbyssMistDepthShadowSE", Vector3(31, -11.98, 46), Vector2(23, 11), -7.0, shadow_mist_mat],
		["AbyssMistDepthShadowLeft", Vector3(-66, -11.99, 4), Vector2(17, 26), 0.0, shadow_mist_mat],
		["AbyssMistDepthShadowRight", Vector3(66, -11.99, 5), Vector2(17, 26), 0.0, shadow_mist_mat],
	]:
		_spawn_soft_cloud(cloud[0], cloud[1], cloud[2], parent, cloud[4], cloud[3])

	var glow_blue_mat = _emissive_material(Color(0.72, 0.88, 1.0, 0.72), Color("#9fdcff"), 1.45)
	var glow_warm_mat = _emissive_material(Color(1.0, 0.78, 0.38, 0.68), Color("#ffd36a"), 1.25)
	var mote_xs := [-56, -41, -26, -8, 13, 31, 47, 59, -52, -19, 24, 54]
	var mote_zs := [-18, 28, -40, 44, -43, 31, -15, 18, 46, -54, 52, -46]
	for i in range(12):
		var x: float = float(mote_xs[i])
		var z: float = float(mote_zs[i])
		var y: float = -10.95 + float(i % 3) * 0.12
		var size := Vector2(0.65 + float(i % 4) * 0.12, 0.65 + float((i + 2) % 4) * 0.10)
		var mat: Material = glow_blue_mat if i % 2 == 0 else glow_warm_mat
		_spawn_flat_disc("AbyssGlowMote%d" % i, Vector3(x, y, z), size, parent, mat, float(i * 17))

func _spawn_abyss_plane(
	name: String,
	pos: Vector3,
	size: Vector2,
	parent: Node3D,
	mat: Material
) -> MeshInstance3D:
	var plane_instance = MeshInstance3D.new()
	plane_instance.name = name
	var plane = PlaneMesh.new()
	plane.size = size
	plane.subdivide_width = 8
	plane.subdivide_depth = 8
	plane_instance.mesh = plane
	plane_instance.position = pos
	plane_instance.material_override = mat
	parent.add_child(plane_instance)
	return plane_instance

func _spawn_flat_disc(
	name: String,
	pos: Vector3,
	size: Vector2,
	parent: Node3D,
	mat: Material,
	yaw_deg: float = 0.0
) -> MeshInstance3D:
	var disc = MeshInstance3D.new()
	disc.name = name
	var mesh = CylinderMesh.new()
	mesh.top_radius = 0.5
	mesh.bottom_radius = 0.5
	mesh.height = 0.08
	mesh.radial_segments = 22
	disc.mesh = mesh
	disc.position = pos
	disc.rotation_degrees = Vector3(0, yaw_deg, 0)
	disc.scale = Vector3(size.x, 1, size.y)
	disc.material_override = mat
	parent.add_child(disc)
	return disc

func _spawn_soft_cloud(
	name: String,
	pos: Vector3,
	size: Vector2,
	parent: Node3D,
	mat: Material,
	yaw_deg: float = 0.0
) -> Node3D:
	var root = Node3D.new()
	root.name = name
	root.position = pos
	root.rotation_degrees = Vector3(0, yaw_deg, 0)
	parent.add_child(root)

	var cloud_color := _material_albedo(mat)
	var cloud_mat := _soft_cloud_material(cloud_color)
	var puff_specs = [
		[Vector3(-0.22, 0.0, -0.06), Vector2(0.86, 0.74), 0.0],
		[Vector3(0.18, 0.01, 0.04), Vector2(0.76, 0.64), 5.0],
		[Vector3(0.48, -0.01, -0.02), Vector2(0.54, 0.58), -8.0],
		[Vector3(-0.54, -0.02, 0.08), Vector2(0.48, 0.54), 11.0],
	]
	var suffix := name.trim_prefix("AbyssMist")
	for i in range(puff_specs.size()):
		var spec = puff_specs[i]
		var mesh_instance = MeshInstance3D.new()
		mesh_instance.name = "AbyssSoftCloud%s_%d" % [suffix, i]
		var plane = PlaneMesh.new()
		plane.size = Vector2(size.x * (spec[1] as Vector2).x, size.y * (spec[1] as Vector2).y)
		plane.subdivide_width = 2
		plane.subdivide_depth = 2
		mesh_instance.mesh = plane
		mesh_instance.position = Vector3(
			(spec[0] as Vector3).x * size.x,
			(spec[0] as Vector3).y,
			(spec[0] as Vector3).z * size.y
		)
		mesh_instance.rotation_degrees = Vector3(0, spec[2], 0)
		mesh_instance.material_override = cloud_mat
		root.add_child(mesh_instance)
	return root

func _soft_cloud_material(color: Color) -> ShaderMaterial:
	var shader = Shader.new()
	shader.code = "
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_mix;

uniform vec4 cloud_color : source_color = vec4(1.0, 0.75, 0.75, 0.25);
uniform float cloud_core = 0.08;
uniform float cloud_falloff = 0.95;

void fragment() {
	vec2 p = UV * 2.0 - vec2(1.0);
	float d = length(p);
	float feather = 1.0 - smoothstep(cloud_core, cloud_falloff, d);
	float lobe = 0.82 + 0.18 * sin((UV.x + UV.y) * 10.0);
	ALBEDO = cloud_color.rgb;
	EMISSION = cloud_color.rgb * 0.08;
	ALPHA = cloud_color.a * feather * lobe;
}
"
	var shader_mat = ShaderMaterial.new()
	shader_mat.shader = shader
	shader_mat.set_shader_parameter("cloud_color", color)
	return shader_mat

func _abyss_gradient_material() -> ShaderMaterial:
	var shader = Shader.new()
	shader.code = "
shader_type spatial;
render_mode unshaded, cull_disabled;

uniform vec4 deep_color : source_color = vec4(0.12, 0.20, 0.42, 1.0);
uniform vec4 horizon_color : source_color = vec4(0.33, 0.43, 0.70, 1.0);
uniform vec4 warm_haze : source_color = vec4(0.88, 0.52, 0.58, 1.0);

void fragment() {
	vec2 p = UV - vec2(0.5);
	float radial = smoothstep(0.08, 0.72, length(p));
	float vertical_warmth = smoothstep(0.20, 0.90, UV.y);
	vec3 base = mix(horizon_color.rgb, deep_color.rgb, radial);
	base = mix(base, warm_haze.rgb, vertical_warmth * 0.08);
	ALBEDO = base;
	EMISSION = base * 0.06;
}
"
	var shader_mat = ShaderMaterial.new()
	shader_mat.shader = shader
	return shader_mat

func _material_albedo(mat: Material) -> Color:
	if mat is StandardMaterial3D:
		return (mat as StandardMaterial3D).albedo_color
	return Color(0.85, 0.72, 0.84, 0.24)

func _material(color: Color, roughness: float, specular: float) -> StandardMaterial3D:
	var mat = StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = max(roughness, 0.72)
	mat.metallic = 0.0
	mat.metallic_specular = min(specular, 0.18)
	return mat

func _emissive_material(color: Color, emission: Color, energy: float) -> StandardMaterial3D:
	var mat = _material(color, 0.72, 0.15)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA if color.a < 1.0 else BaseMaterial3D.TRANSPARENCY_DISABLED
	mat.emission_enabled = true
	mat.emission = emission
	mat.emission_energy_multiplier = energy
	return mat
