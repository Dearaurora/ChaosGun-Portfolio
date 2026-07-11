extends SceneTree

const SCENE_PATH := "res://scenes/maps/open_ringout_slice.tscn"
const V2_ROOT_PATH := "OpenRingoutBlenderVisuals/SunsetV2GameplayVisuals"

const REQUIRED_V2_NODES := [
	"V2CentralCliff",
	"V2CentralWarmBand",
	"V2CentralTop",
	"V2CentralTopInset",
	"V2CentralCliffFacet_0",
	"V2CentralEdgeRim_0",
	"V2CentralEdgePost_0",
	"V2CentralEdgeGem_0",
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
	"V4CentralPanel_0_0",
	"V4CentralCliffShoulder_0",
	"V3NorthIslandCliffMidShelf",
	"V3EastIslandV4CliffFacet_0",
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
		if _contains_collision(v2_root):
			_fail("V2 gameplay visual layer must remain collision-free")
		_verify_nonblack_texture(v2_root, "V4CentralPanel_0_0")
		_verify_nonblack_texture(v2_root, "V2EastBridgePlank_0")

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
		if far_cloud == null or not far_cloud.visible:
			_fail("Unreplaced background depth art must remain visible")

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


func _contains_collision(node: Node) -> bool:
	if node is CollisionObject3D or node is CollisionShape3D:
		return true
	for child in node.get_children():
		if _contains_collision(child):
			return true
	return false


func _verify_nonblack_texture(root_node: Node, mesh_name: String) -> void:
	var mesh_instance := root_node.find_child(mesh_name, true, false) as MeshInstance3D
	if mesh_instance == null:
		_fail("Missing textured mesh: %s" % mesh_name)
		return
	var material := mesh_instance.get_active_material(0) as BaseMaterial3D
	if material == null or material.albedo_texture == null:
		_fail("Missing albedo texture on %s" % mesh_name)
		return
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
