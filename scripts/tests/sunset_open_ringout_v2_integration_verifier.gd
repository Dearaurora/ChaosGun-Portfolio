extends SceneTree

const SCENE_PATH := "res://scenes/maps/open_ringout_slice.tscn"
const V2_ROOT_PATH := "OpenRingoutBlenderVisuals/SunsetV2GameplayVisuals"

const REQUIRED_V2_NODES := [
	"V2CentralCliff",
	"V2CentralWarmBand",
	"V2CentralTop",
	"V2CentralTopInset",
	"V2CentralEdgePost_0",
	"V2CentralEdgeGem_0",
	"V2EastBridgeShadow",
	"V2EastBridgePlank_0",
	"V2EastBridgePost_0",
	"V2EastBridgeGem_0",
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
	"tile_line_x_0",
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
		var north_deck = legacy_root.find_child("north_deck_irregular_top_slab", true, false) as Node3D
		if north_deck == null or not north_deck.visible:
			_fail("Unreplaced north deck must remain visible")

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
