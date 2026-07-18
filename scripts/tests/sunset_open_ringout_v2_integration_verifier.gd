extends SceneTree

const SCENE_PATH := "res://scenes/maps/open_ringout_slice.tscn"
const V2_ROOT_PATH := "OpenRingoutBlenderVisuals/SunsetV2GameplayVisuals"
const P14_ROOT_PATH := "OpenRingoutBlenderVisuals/P14SunsetEnvironment"

const REQUIRED_V2_NODES := [
	"V2CentralCliff",
	"V7CentralCliffShoulder",
	"V2CentralWarmBand",
	"V2CentralTop",
	"V2CentralTopInset",
	"V10CentralFloorTile_0",
	"V10CentralLobeTile_0",
	"V2CentralEdgeRim_0",
	"V2CentralEdgePost_0",
	"V2CentralEdgeGem_0",
	"V6CentralNorthLandingSocketBed",
	"V6CentralNorthLandingSocketDeck_0",
	"V6CentralNorthLandingSocketBackBeam",
	"V6CentralSouthLandingSocketBed",
	"V6CentralSouthLandingSocketDeck_0",
	"V6CentralSouthLandingSocketBackBeam",
	"V6CentralEastLandingSocketBed",
	"V6CentralEastLandingSocketDeck_0",
	"V6CentralEastLandingSocketBackBeam",
	"V6CentralWestLandingSocketBed",
	"V6CentralWestLandingSocketDeck_0",
	"V6CentralWestLandingSocketBackBeam",
	"V2EastBridgeShadow",
	"V2EastBridgeSupportB",
	"V2EastBridgePlank_0",
	"V2EastBridgeFastener_0_0",
	"V2EastBridgePost_0",
	"V2EastBridgeGem_0",
	"V3BumperNorthBody",
	"V3BumperCenterBody",
	"V3WestBarricadeBody",
	"V3WoodCrateBody",
	"V3OrangeCrateBody",
	"V3TanCrateBody",
	"V3NorthIslandTop",
	"V3EastIslandTop",
	"V3SouthIslandTop",
	"V3WestIslandTop",
	"V3NorthBridgePlank_0",
	"V3SouthBridgePlank_0",
	"V3WestBridgePlank_0",
	"V3NorthWindmillTower",
	"V3EastTreeATrunk",
	"V3SouthBarrelRed",
	"V3WestTire_0",
	"V3NorthFencePost_0",
	"V2EastBridgeMouthBeam_0",
	"V3CloudNorthWest_0",
	"V3DistantIslandNWCliff",
	"V3HotAirBalloonBody",
	"V3NorthIslandCliffMidShelf",
	"V3NorthIslandV5SocketBed",
	"V3NorthIslandV5SocketDeck_0",
	"V3NorthIslandV5SocketBackBeam",
	"V3SouthIslandV5SocketBed",
	"V3SouthIslandV5SocketDeck_0",
	"V3SouthIslandV5SocketBackBeam",
	"V4NorthWindmillBase",
	"V3EastTreeAV4FoliageMiddle",
	"V3SouthIslandV4TopPanel_0",
	"V3SouthBarrelRedV4TopLid",
	"V3SouthBarrelRedV5Label",
	"V3SouthBarrelRedV5BottomFoot",
	"V3WestTireV5Sidewall_0",
	"V3BumperNorthV5TopPad_0",
	"V3BumperNorthV5EndPlate_0",
	"V3WoodCrateV5SideInsetFrame_0",
	"V3WoodCrateV5SideLatch_0",
	"V3WoodCrateV5CornerCap_0",
	"V3WestBarricadeV5Panel_0",
	"V3EastIslandV5SocketBed",
	"V3EastIslandV5SocketSideBeam_0",
	"V3WestIslandV5SocketBackBeam",
	"V8NorthWindmillWindow",
	"V9NorthWindmillLowerBand",
	"V10NorthHeroTreeTrunk",
	"V10NorthDuckABody",
	"V10NorthDuckBBody",
	"V10EastBlueCrateBody",
	"V10EastGoldCrateBody",
	"V10EastRedCrateBody",
]

const FORBIDDEN_FRAGMENTED_CLIFF_PREFIXES := [
	"V10CentralSouthCliffFacet_",
	"V10CentralEastCliffFacet_",
	"V10NorthIslandFrontCliffFacet_",
]

const HIDDEN_LEGACY_NODES := [
	"main_deck_irregular_top_slab",
	"main_west_lip_irregular_top_slab",
	"main_east_lip_irregular_top_slab",
	"east_bridge_irregular_top_slab",
	"A1MainDeckHeroCrown",
	"A1EastBridgeRouteRailL",
	"A1SurfacePanel_MainNW",
	"A1SurfacePanel_BridgeE",
	"A1CenterPickupHaloCool",
	"A1CenterPickupTick_0",
	"A1CenterPickupSpark_0",
	"A1CenterPickupBurstTick_0",
	"A1EdgeBeacon_00",
	"center_pickup_glow_disc",
	"bumper_north_body",
	"bumper_center_body",
	"crate_left_a",
	"crate_wood",
	"orange_block",
	"tan_block",
	"ChunkyCoverClusterWest",
	"gold_bolt_0",
	"tile_line_x_0",
	"north_deck_irregular_top_slab",
	"south_bridge_irregular_top_slab",
	"A1NorthDeckHeroCrown",
	"A1WestBridgeRouteRailL",
	"A1PerimeterToyBlock_0",
	"A1PerimeterToyBlock_1",
	"A1PerimeterToyBlock_2",
	"A1PerimeterToyBlock_3",
	"A1PerimeterToyBlock_4",
	"A1PerimeterToyBlock_5",
]

var _failures: Array[String] = []
var _arena: Node = null


func _initialize() -> void:
	print("==================================================")
	print("[Sunset Open Ring-Out V2 Integration Verifier]")
	print("==================================================")

	_configure_empty_roster()
	var packed = load(SCENE_PATH) as PackedScene
	if packed == null:
		_fail("Could not load %s" % SCENE_PATH)
		await _finish()
		return
	_arena = packed.instantiate()
	root.add_child(_arena)
	await process_frame
	await process_frame

	var v2_root = _arena.get_node_or_null(V2_ROOT_PATH)
	if v2_root == null:
		_fail("Missing V2 visual root: %s" % V2_ROOT_PATH)
	else:
		for node_name in REQUIRED_V2_NODES:
			if v2_root.find_child(node_name, true, false) == null:
				_fail("Missing V2 node: %s" % node_name)
		var fragmented_cliff_found := false
		for prefix in FORBIDDEN_FRAGMENTED_CLIFF_PREFIXES:
			if _find_prefixed_node(v2_root, prefix) != null:
				fragmented_cliff_found = true
				_fail("Fragmented island-cliff module must remain absent: %s" % prefix)
		if not fragmented_cliff_found:
			print("OK  continuous main-island underbody without detached cliff modules")
		if _contains_collision(v2_root):
			_fail("V2 gameplay visual layer must remain collision-free")
		_verify_nonblack_texture(v2_root, "V2CentralTopInset")
		_verify_nonblack_texture(v2_root, "V2EastBridgePlank_0")
		_verify_p24_surface_hierarchy(v2_root)
		var old_balloon = v2_root.find_child("V3HotAirBalloonBody", true, false) as Node3D
		if old_balloon == null or old_balloon.visible:
			_fail("Old V3 hot-air balloon should be hidden after the P14 replacement loads")

	var legacy_root = _arena.get_node_or_null("OpenRingoutBlenderVisuals/BlenderAuthoredOpenRingoutVisuals")
	if legacy_root == null:
		_fail("Missing legacy Blender visual root")
	else:
		for node_name in HIDDEN_LEGACY_NODES:
			var node = legacy_root.find_child(node_name, true, false) as Node3D
			if node == null:
				_fail("Missing expected legacy node: %s" % node_name)
			elif node.visible:
				_fail("Replaced legacy node is still visible: %s" % node_name)
		var far_cloud = legacy_root.find_child("FarAbyssCloudPuff_0", true, false) as Node3D
		if far_cloud == null or far_cloud.visible:
			_fail("Legacy background cloud should be hidden after the P14 environment loads")

	var p14_root = _arena.get_node_or_null(P14_ROOT_PATH) as Node3D
	if p14_root == null:
		_fail("Missing P14 environment root: %s" % P14_ROOT_PATH)
	else:
		var p14_cloud = p14_root.find_child("P14CloudBankNorth", true, false) as Node3D
		if p14_cloud == null:
			_fail("P14 authored cloud source must remain available")
		elif not p14_cloud.visible:
			_fail("Approved P15 cloud banks must remain visible")
		var p14_island = p14_root.find_child("P14DistantIslandNorthWestCliff", true, false) as Node3D
		if p14_island == null or not p14_island.visible:
			_fail("P14 distant-island depth art must remain visible")
		var p14_balloon = p14_root.find_child("P14HotAirBalloonEnvelope", true, false) as Node3D
		if p14_balloon == null or not p14_balloon.visible:
			_fail("P14 segmented hot-air balloon must remain visible")
		if _contains_collision(p14_root):
			_fail("P14 environment layer must remain collision-free")

	_verify_p24_grounding_profile()

	await _finish()


func _configure_empty_roster() -> void:
	var match_config = root.get_node_or_null("MatchConfig")
	if match_config:
		match_config.slots = [
			match_config.SlotType.EMPTY,
			match_config.SlotType.EMPTY,
			match_config.SlotType.EMPTY,
			match_config.SlotType.EMPTY,
		]


func _verify_p24_grounding_profile() -> void:
	var light := _arena.get_node_or_null("DirectionalLight3D") as DirectionalLight3D
	var environment_node := _arena.get_node_or_null("WorldEnvironment") as WorldEnvironment
	if light == null or light.shadow_blur > 1.75 or light.shadow_opacity < 0.74:
		_fail("P24 key-light shadows are too diffuse to ground the toy assets")
	if environment_node == null or environment_node.environment == null:
		_fail("P24 grounding environment is missing")
		return
	var environment := environment_node.environment
	if environment.ssao_radius > 1.0 or environment.ssao_intensity < 1.05:
		_fail("P24 SSAO must remain tight and strong at contact points")
	else:
		print("OK  P24 tight contact shadows without a dirty floor wash")


func _contains_collision(node: Node) -> bool:
	if node is CollisionObject3D or node is CollisionShape3D:
		return true
	for child in node.get_children():
		if _contains_collision(child):
			return true
	return false


func _find_prefixed_node(node: Node, prefix: String) -> Node:
	if String(node.name).begins_with(prefix):
		return node
	for child in node.get_children():
		var match_node := _find_prefixed_node(child, prefix)
		if match_node:
			return match_node
	return null


func _verify_nonblack_texture(root_node: Node, mesh_name: String) -> void:
	var mesh_instance := root_node.find_child(mesh_name, true, false) as MeshInstance3D
	if mesh_instance == null:
		_fail("Missing textured mesh: %s" % mesh_name)
		return
	var material := mesh_instance.get_active_material(0) as BaseMaterial3D
	if material == null or material.albedo_texture == null:
		_fail("Missing albedo texture on %s" % mesh_name)
		return
	var has_roughness_map := material.roughness_texture != null or material.orm_texture != null
	if not has_roughness_map and (material.roughness < 0.68 or material.roughness > 0.86):
		_fail("%s textured material should keep a soft toy highlight" % mesh_name)
	if material.normal_texture == null:
		_fail("%s is missing the P24 clean wood normal map" % mesh_name)
	var image := material.albedo_texture.get_image()
	if image == null or image.is_empty():
		_fail("Could not inspect albedo texture on %s" % mesh_name)
		return
	if image.is_compressed():
		image = image.duplicate()
		var decompress_error := image.decompress()
		if decompress_error != OK:
			_fail("Could not decompress albedo texture on %s" % mesh_name)
			return
	var sample := image.get_pixel(int(image.get_width() / 2), int(image.get_height() / 2))
	if sample.get_luminance() < 0.12:
		_fail("Albedo texture on %s is unexpectedly dark" % mesh_name)
	var min_luminance := INF
	var max_luminance := -INF
	var step_x := maxi(int(image.get_width() / 8), 1)
	var step_y := maxi(int(image.get_height() / 8), 1)
	for y in range(0, image.get_height(), step_y):
		for x in range(0, image.get_width(), step_x):
			var luminance := image.get_pixel(x, y).get_luminance()
			min_luminance = minf(min_luminance, luminance)
			max_luminance = maxf(max_luminance, luminance)
	if max_luminance - min_luminance < 0.04:
		_fail("Albedo texture on %s is too flat for gameplay distance" % mesh_name)


func _verify_p24_surface_hierarchy(root_node: Node) -> void:
	var light_tile := root_node.find_child("V10CentralFloorTile_0", true, false) as MeshInstance3D
	var mid_tile := root_node.find_child("V10CentralFloorTile_2", true, false) as MeshInstance3D
	var bumper := root_node.find_child("V3BumperCenterBody", true, false) as MeshInstance3D
	if light_tile == null or mid_tile == null or bumper == null:
		_fail("P24 surface hierarchy nodes are incomplete")
		return
	var light_luminance := _material_texture_center_luminance(light_tile)
	var mid_luminance := _material_texture_center_luminance(mid_tile)
	if absf(light_luminance - mid_luminance) < 0.045:
		_fail("P24 central floor panels do not have enough value separation")
	var bumper_material := bumper.get_active_material(0) as BaseMaterial3D
	if bumper_material == null:
		_fail("P24 center bumper material is missing")
		return
	var bumper_color := bumper_material.albedo_color
	if bumper_color.r - bumper_color.g < 0.16:
		_fail("P24 center bumper must read as red against the orange deck")
	else:
		print("OK  P24 layered wood surfaces and red cover hierarchy")


func _material_texture_center_luminance(mesh_instance: MeshInstance3D) -> float:
	var material := mesh_instance.get_active_material(0) as BaseMaterial3D
	if material == null or material.albedo_texture == null:
		return -1.0
	var image := material.albedo_texture.get_image()
	if image == null or image.is_empty():
		return -1.0
	if image.is_compressed():
		image = image.duplicate()
		if image.decompress() != OK:
			return -1.0
	return image.get_pixel(int(image.get_width() / 2), int(image.get_height() / 2)).get_luminance()


func _fail(message: String) -> void:
	_failures.append(message)
	push_error(message)


func _finish() -> void:
	if _arena:
		_arena.queue_free()
	await process_frame
	if _failures.is_empty():
		print("[Sunset Open Ring-Out V2 Integration Verifier] PASS")
		quit(0)
		return
	print("[Sunset Open Ring-Out V2 Integration Verifier] FAIL (%d)" % _failures.size())
	quit(1)
