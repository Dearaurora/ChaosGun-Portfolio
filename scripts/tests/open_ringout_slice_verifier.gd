extends SceneTree

const SCENE_PATH := "res://scenes/maps/open_ringout_slice.tscn"
const REQUIRED_NODES := [
	"OpenRingoutAbyss",
	"OpenRingoutBackdrop",
	"OpenRingoutPlayable",
	"OpenRingoutPlayable/MainDeck",
	"OpenRingoutPlayable/NorthDeck",
	"OpenRingoutPlayable/EastDeck",
	"OpenRingoutPlayable/SouthDeck",
	"OpenRingoutPlayable/WestDeck",
	"OpenRingoutPlayable/NorthBridge",
	"OpenRingoutPlayable/EastBridge",
	"OpenRingoutPlayable/SouthBridge",
	"OpenRingoutPlayable/WestBridge",
	"OpenRingoutArt",
	"OpenRingoutBlenderVisuals",
	"OpenRingoutCovers",
	"OpenRingoutEdgeGlow",
	"OpenRingoutHUD",
	"WeaponSpawner",
	"GlobalCamera",
]

var _failures: Array[String] = []
var _host: Node = null

func _initialize() -> void:
	root.set_meta("disable_runtime_audio", true)
	print("==================================================")
	print("[Open Ringout Verifier]")
	print("==================================================")

	var scene = load(SCENE_PATH)
	if scene == null:
		_fail("Could not load %s" % SCENE_PATH)
		await _finish()
		return
	_configure_showcase_roster()

	_host = Node.new()
	root.add_child(_host)

	var arena = scene.instantiate()
	_host.add_child(arena)

	await process_frame
	await process_frame

	_verify_required_nodes(arena)
	_verify_no_legacy_layout(arena)
	_verify_spawn_points(arena)
	_verify_weapon_spawns(arena)
	await _verify_weapon_pickup_visual(arena)
	await _verify_runtime_weapon_pickup_spawn(arena)
	_verify_ringout_hud(arena)
	_verify_art_asset_layer(arena)
	_verify_visual_cover_collision(arena)
	_verify_floor_color_logic(arena)
	_verify_bridge_connector_visibility(arena)
	_verify_bridge_surface_integrity(arena)
	_verify_east_west_bridge_topology(arena)
	_verify_bridge_decor_not_flat_stickers(arena)
	_verify_party_roster(arena)
	_verify_open_edges(arena)
	_verify_visual_profile(arena)
	_verify_abyss_background_design(arena)
	await _verify_ringout_respawn(arena)

	await _finish()

func _configure_showcase_roster() -> void:
	var match_config = root.get_node_or_null("MatchConfig")
	if match_config == null:
		_fail("MatchConfig autoload missing")
		return
	match_config.slots = [
		match_config.SlotType.HUMAN,
		match_config.SlotType.AI,
		match_config.SlotType.AI,
		match_config.SlotType.AI,
	]
	match_config.PLAYER_COLORS = [
		Color("#ef3f3f"),
		Color("#78d23d"),
		Color("#24a9e8"),
		Color("#f2bf27"),
	]

func _verify_required_nodes(arena: Node) -> void:
	print("\n--- Required Nodes ---")
	for path in REQUIRED_NODES:
		if arena.get_node_or_null(path) == null:
			_fail("Missing node: %s" % path)
		else:
			print("OK  ", path)

func _verify_no_legacy_layout(arena: Node) -> void:
	print("\n--- Legacy Layout Check ---")
	for path in [
		"KaykitMap",
		"CommercialSliceWhitebox",
		"CommercialSliceBackdrop",
		"Floor",
		"Obstacles",
		"ExternalArt",
	]:
		if arena.get_node_or_null(path) != null:
			_fail("Legacy layout node is present in the new slice: %s" % path)
		else:
			print("OK  ", path, " absent")

func _verify_spawn_points(arena: Node) -> void:
	print("\n--- Spawn Points ---")
	if not arena.has_method("_get_spawn_points"):
		_fail("Arena is missing _get_spawn_points")
		return

	var points = arena.call("_get_spawn_points") as Array
	if points.size() != 4:
		_fail("Expected 4 spawn points, got %d" % points.size())
		return

	var playable = arena.get_node_or_null("OpenRingoutPlayable") as Node3D
	if playable == null:
		_fail("OpenRingoutPlayable missing during spawn check")
		return

	for point in points:
		var spawn := point as Vector3
		if not _point_over_playable_surface(spawn, playable):
			_fail("Spawn point is not over a playable surface: %s" % str(spawn))
		else:
			print("OK  ", spawn)

	var game_config = root.get_node_or_null("GameConfig")
	if game_config == null:
		_fail("GameConfig autoload missing")
		return
	var respawn_points = game_config.get("respawn_points") as Array
	if respawn_points.size() != points.size():
		_fail("GameConfig.respawn_points count does not match arena spawn points")

func _verify_weapon_spawns(arena: Node) -> void:
	print("\n--- Weapon Spawns ---")
	var spawner = arena.get_node_or_null("WeaponSpawner")
	if spawner == null:
		_fail("WeaponSpawner missing")
		return

	var fixed_value = spawner.get("fixed_spawn_points")
	var random_value = spawner.get("random_spawn_points")
	var legacy_points_value = spawner.get("custom_spawn_points")
	var legacy_clusters_value = spawner.get("custom_spawn_clusters")
	var fixed_points: Array = fixed_value if fixed_value is Array else []
	var random_points: Array = random_value if random_value is Array else []
	var legacy_points: Array = legacy_points_value if legacy_points_value is Array else []
	var legacy_clusters: Array = legacy_clusters_value if legacy_clusters_value is Array else []
	if fixed_points.size() != 1:
		_fail("Expected exactly one fixed center weapon spawn, got %d" % fixed_points.size())
		return
	if (fixed_points[0] as Vector3).distance_to(Vector3(0, 1.65, 0)) > 0.1:
		_fail("Fixed weapon spawn must stay at the center pad: %s" % str(fixed_points[0]))
	if random_points.size() < 4:
		_fail("Expected at least four random weapon candidate points, got %d" % random_points.size())
		return
	for random_point in random_points:
		var candidate := random_point as Vector3
		for blocked_anchor in [
			Vector3(9, 1.65, -30),
			Vector3(-39, 1.65, 2),
		]:
			if candidate.distance_to(blocked_anchor) < 4.0:
				_fail("Random weapon candidate overlaps a major cover prop: %s" % str(candidate))
	if not legacy_points.is_empty() or not legacy_clusters.is_empty():
		_fail("Legacy multi-point weapon spawn pools should be disabled for the open ringout slice")
	if int(spawner.get("max_active_pickups")) != 2:
		_fail("Open ringout weapon spawner should allow only center + one random pickup")
	if not is_equal_approx(float(spawner.get("random_spawn_interval")), 22.5):
		_fail("Random weapon spawn interval should be 22.5 seconds, got %.2f" % float(spawner.get("random_spawn_interval")))
	if not is_equal_approx(float(spawner.get("respawn_cooldown")), 4.5):
		_fail("Center weapon respawn cooldown should be 4.5 seconds, got %.2f" % float(spawner.get("respawn_cooldown")))
	if float(spawner.get("random_stay_duration")) >= float(spawner.get("random_spawn_interval")):
		_fail("Random weapon lifetime must be shorter than its spawn interval")

	var points = fixed_points + random_points
	if points.size() < 5:
		_fail("Expected center plus random weapon spawn candidates")
		return

	var playable = arena.get_node_or_null("OpenRingoutPlayable") as Node3D
	if playable == null:
		_fail("OpenRingoutPlayable missing during weapon spawn check")
		return

	for point in points:
		var spawn := point as Vector3
		if not _point_over_playable_surface(spawn, playable):
			_fail("Weapon spawn is not over a playable surface: %s" % str(spawn))
		else:
			print("OK  ", spawn)

func _verify_weapon_pickup_visual(arena: Node) -> void:
	print("\n--- Weapon Pickup Visual ---")
	var pickup_scene = load("res://scenes/weapons/weapon_pickup.tscn") as PackedScene
	if pickup_scene == null:
		_fail("Weapon pickup scene missing")
		return
	var pickup = pickup_scene.instantiate() as WeaponPickup
	if pickup == null:
		_fail("Weapon pickup scene did not instantiate as WeaponPickup")
		return
	arena.add_child(pickup)
	pickup.position = Vector3(0, 1.65, 0)
	pickup.setup(WeaponData.create_smg())
	await process_frame

	if pickup.get_node_or_null("ToyPickupVisual/PickupBase") == null:
		_fail("Pickup visual missing base")
	if pickup.get_node_or_null("ToyPickupVisual/PickupGlow") == null:
		_fail("Pickup visual missing glow")
	if pickup.get_node_or_null("ToyPickupVisual/PickupWeaponIcon/SMGBody") == null:
		_fail("Pickup visual missing SMG body icon")
	var legacy = pickup.get_node_or_null("MeshInstance3D") as MeshInstance3D
	if legacy and legacy.visible:
		_fail("Legacy pickup cube is still visible")
	else:
		print("OK  toy pickup visual")
	pickup.queue_free()

func _verify_runtime_weapon_pickup_spawn(arena: Node) -> void:
	print("\n--- Runtime Weapon Pickup Spawn ---")
	await create_timer(0.60).timeout
	await process_frame

	var active_pickups: Array[WeaponPickup] = []
	for node in get_nodes_in_group("weapon_pickup"):
		if node is WeaponPickup and _host != null and _host.is_ancestor_of(node):
			active_pickups.append(node as WeaponPickup)

	if active_pickups.is_empty():
		_fail("No runtime weapon pickups spawned after configured initial delay")
		return

	var has_center_pickup := false
	var random_pickups := 0
	for pickup in active_pickups:
		if pickup.global_position.distance_to(Vector3(0, 1.65, 0)) < 2.5:
			has_center_pickup = true
		else:
			random_pickups += 1
		if pickup.get_node_or_null("ToyPickupVisual/PickupWeaponIcon") == null:
			_fail("Runtime pickup is missing toy weapon icon: %s" % pickup.name)

	if active_pickups.size() != 2:
		_fail("Expected exactly two active pickups: center plus one random, got %d" % active_pickups.size())
	if random_pickups != 1:
		_fail("Expected exactly one active random weapon pickup, got %d" % random_pickups)
	if not has_center_pickup:
		_fail("Runtime pickups did not include the guaranteed center pickup")
	else:
		print("OK  runtime pickups: ", active_pickups.size())

func _verify_ringout_hud(arena: Node) -> void:
	print("\n--- Ringout HUD ---")
	var hud = arena.get_node_or_null("OpenRingoutHUD")
	if hud == null:
		_fail("OpenRingoutHUD missing")
		return

	var root_node = hud.get_node_or_null("HUDRoot")
	if root_node == null:
		_fail("OpenRingoutHUD did not build HUDRoot")
		return

	var required_paths: Array[String] = [
		"Avatar",
		"Avatar/Visor",
		"PlayerTag",
		"LifeLabel",
		"WeaponBox",
		"WeaponBox/WeaponSilhouette",
		"WeaponBox/WeaponName",
		"WeaponBox/AmmoLabel",
	]

	for i in range(4):
		var panel_name = "PlayerPanel%d" % (i + 1)
		var panel = root_node.get_node_or_null(panel_name)
		if panel == null:
			_fail("HUD missing %s" % panel_name)
			continue

		for path in required_paths:
			if panel.get_node_or_null(path) == null:
				_fail("%s is missing HUD element: %s" % [panel_name, path])

		var tag = panel.get_node_or_null("PlayerTag") as Label
		if tag == null or tag.text.strip_edges().is_empty():
			_fail("%s player tag is empty" % panel_name)

		var life_label = panel.get_node_or_null("LifeLabel") as Label
		if life_label == null or not life_label.text.contains("LIFE"):
			_fail("%s life label should expose stock/life information" % panel_name)

		var weapon_name = panel.get_node_or_null("WeaponBox/WeaponName") as Label
		if weapon_name == null or weapon_name.text.strip_edges().is_empty():
			_fail("%s weapon name label is empty" % panel_name)

		var ammo_label = panel.get_node_or_null("WeaponBox/AmmoLabel") as Label
		if ammo_label == null or ammo_label.text.strip_edges().is_empty():
			_fail("%s ammo label is empty" % panel_name)
		elif ammo_label.text.contains("AMMO"):
			_fail("%s ammo label should show compact counts only, got %s" % [panel_name, ammo_label.text])
		elif ammo_label.text != "INF" and not ammo_label.text.contains("/"):
			_fail("%s ammo label should use current/max count format, got %s" % [panel_name, ammo_label.text])

		var silhouette = panel.get_node_or_null("WeaponBox/WeaponSilhouette") as Control
		if silhouette == null:
			_fail("%s weapon silhouette is missing" % panel_name)
		else:
			if not silhouette.has_method("set_weapon"):
				_fail("%s weapon silhouette should be a drawable icon control" % panel_name)
			if silhouette.get_child_count() > 0:
				_fail("%s weapon silhouette should not be assembled from blocky child panels" % panel_name)

		for forbidden in ["WeaponBox/AmmoTrack", "WeaponBox/AmmoFill"]:
			if panel.get_node_or_null(forbidden) != null:
				_fail("%s should not contain progress bar ammo UI: %s" % [panel_name, forbidden])

		print("OK  ", panel_name)

func _verify_party_roster(arena: Node) -> void:
	print("\n--- Party Roster ---")
	var chars = arena.get("_characters") as Array
	if chars.size() != 4:
		_fail("Expected 4 spawned characters for the playable slice, got %d" % chars.size())
		return

	for character in chars:
		if not (character is BaseCharacter):
			_fail("Roster contains non-character node: %s" % str(character))
			continue
		var base := character as BaseCharacter
		var visual = base.get_node_or_null("Visual")
		if visual == null:
			_fail("%s is missing Visual" % base.name)
			continue
		if visual.get_node_or_null("Hat") != null:
			_fail("%s still has a head decoration" % base.name)
		if visual.get_node_or_null("FaceVisor") == null:
			_fail("%s is missing the toy visor face" % base.name)
		if visual.get_node_or_null("BeanCharacterAsset") == null:
			_fail("%s did not load the Blender bean character asset" % base.name)
		if visual.find_child("Body", true, false) == null:
			_fail("%s bean character asset is missing Body mesh" % base.name)
		if visual.find_child("LeftHandGrip", true, false) == null or visual.find_child("RightHandGrip", true, false) == null:
			_fail("%s bean character asset is missing defined weapon grip hands" % base.name)
		if base.lives != 4:
			_fail("%s should start the open ringout slice with 4 lives, got %d" % [base.name, base.lives])
		var weapon_holder = visual.get_node_or_null("WeaponHolder")
		if weapon_holder == null:
			_fail("%s is missing WeaponHolder" % base.name)
		else:
			var weapon_asset = weapon_holder.get_node_or_null("WeaponAsset")
			if weapon_asset == null:
				_fail("%s did not load the Blender weapon asset" % base.name)
			elif not _has_mesh_instance(weapon_asset):
				_fail("%s Blender weapon asset has no visible mesh" % base.name)
		if visual.get_node_or_null("LeftFoot") == null or visual.get_node_or_null("RightFoot") == null:
			_fail("%s is missing readable feet" % base.name)
		print("OK  ", base.name)

func _has_mesh_instance(node: Node) -> bool:
	if node is MeshInstance3D:
		return true
	for child in node.get_children():
		if _has_mesh_instance(child):
			return true
	return false

func _verify_art_asset_layer(arena: Node) -> void:
	print("\n--- Art Asset Layer ---")
	var playable = arena.get_node_or_null("OpenRingoutPlayable") as Node3D
	if playable == null:
		_fail("OpenRingoutPlayable missing during art asset check")
		return

	for path in [
		"MainDeck",
		"NorthDeck",
		"EastDeck",
		"SouthDeck",
		"WestDeck",
	]:
		var platform = playable.get_node_or_null(path) as Node3D
		if platform == null:
			_fail("Missing platform for art check: %s" % path)
			continue
		var art_top = platform.get_node_or_null("ArtTop") as MeshInstance3D
		var art_skirt = platform.get_node_or_null("ArtSkirt") as MeshInstance3D
		var art_rim = platform.get_node_or_null("ArtRim") as MeshInstance3D
		if art_top == null or art_skirt == null or art_rim == null:
			_fail("%s is missing platform art nodes" % path)
			continue
		if art_top.mesh is BoxMesh:
			_fail("%s ArtTop is still a plain BoxMesh" % path)
		if art_top.mesh == null or art_skirt.mesh == null:
			_fail("%s platform art mesh is missing" % path)
		print("OK  ", path)

	var art_root = arena.get_node_or_null("OpenRingoutArt") as Node3D
	if art_root == null:
		_fail("OpenRingoutArt root missing")
		return
	if art_root.get_child_count() < 12:
		_fail("OpenRingoutArt has too few decorative asset nodes: %d" % art_root.get_child_count())
	else:
		print("OK  art nodes: ", art_root.get_child_count())

	var blender_root = arena.get_node_or_null("OpenRingoutBlenderVisuals") as Node3D
	if blender_root == null:
		_fail("OpenRingoutBlenderVisuals root missing")
	elif blender_root.get_child_count() == 0:
		_fail("OpenRingoutBlenderVisuals did not instantiate the GLB visual asset")
	else:
		for required_visual in [
			"WarmCloudBankNorth",
			"WarmCloudBankSouth",
			"DistantToyIslandNE",
			"DistantToyIslandSW",
			"concept_outer_edge_glow_main_south_a",
			"concept_outer_edge_glow_north_a",
			"concept_outer_edge_glow_east_south",
			"concept_outer_edge_glow_south_a",
			"concept_outer_edge_glow_west_south",
			"main_deck_irregular_top_slab",
			"main_deck_cliff_block_south_0",
			"main_deck_cliff_block_west_0",
			"north_deck_irregular_top_slab",
			"north_deck_cliff_block_south_0",
			"east_deck_irregular_top_slab",
			"south_deck_irregular_top_slab",
			"west_deck_irregular_top_slab",
			"EastCombatLaneFloorInset",
			"ChunkyCoverClusterWest",
			"BridgeWarningConeNorthL_body",
			"BridgeWarningConeNorthR_body",
			"BridgeWarningConeEastT_body",
			"BridgeWarningConeEastB_body",
			"BridgeWarningConeSouthL_body",
			"BridgeWarningConeSouthR_body",
			"BridgeWarningConeWestT_body",
			"BridgeWarningConeWestB_body",
			"east_deck_inset_glow_south_a",
			"A1MainDeckOuterSkirtNorth",
			"A1MainDeckOuterSkirtSouth",
			"A1NorthBridgeRouteRailL",
			"A1NorthBridgeRouteRailR",
			"A1CenterPickupRuneOuter",
			"A1SkyIslandToyWindmillNE_pole",
			"A1DepthCloudRibbonNorth",
		]:
			if not _has_named_descendant(blender_root, required_visual):
				_fail("OpenRingoutBlenderVisuals is missing %s" % required_visual)
		for forbidden_visual in [
			"_front_lip",
			"_back_lip",
			"bumper_east",
			"bumper_se",
			"round_drum_",
			"round_drum_cap_",
			"tiny_cone_",
			"blue_panel_",
			"metal_plate_",
		]:
			if _has_descendant_name_containing(blender_root, forbidden_visual):
				_fail("OpenRingoutBlenderVisuals still has forbidden duplicate or stale prop: %s" % forbidden_visual)
		print("OK  blender visual children: ", blender_root.get_child_count())

	for required_gameplay_cover in [
		"OpenRingoutCovers/BumperCenterCollision",
		"OpenRingoutCovers/BumperSouthCollision",
		"OpenRingoutCovers/OrangeBlockCollision",
		"OpenRingoutCovers/WestChunkyCoverCollision",
	]:
		if arena.get_node_or_null(required_gameplay_cover) == null:
			_fail("Missing named combat cover anchor: %s" % required_gameplay_cover)

	for forbidden_overlap in [
		"EastOrangeBumper",
		"EastLowRail",
		"EastDrum",
		"TinyConeNorth",
		"TinyConeEast",
		"TinyConeSouth",
		"BlueInsetNorth",
		"BlueInsetSouth",
		"MetalToyPlate",
	]:
		if _has_named_descendant(arena, forbidden_overlap):
			_fail("Open ringout art still has duplicate or unclear runtime prop node: %s" % forbidden_overlap)

func _verify_visual_cover_collision(arena: Node) -> void:
	print("\n--- Visual Cover Collision ---")
	var blender_root = arena.get_node_or_null("OpenRingoutBlenderVisuals") as Node3D
	var cover_root = arena.get_node_or_null("OpenRingoutCovers") as Node3D
	if blender_root == null or cover_root == null:
		_fail("Cannot verify cover collision without Blender visuals and OpenRingoutCovers")
		return

	for check in [
		["bumper_north_body", "OpenRingoutCovers/BumperNorthCollision", "north red bumper"],
		["bumper_center_north_body", "OpenRingoutCovers/BumperCenterNorthCollision", "upper center red bumper"],
		["bumper_center_body", "OpenRingoutCovers/BumperCenterCollision", "center orange bumper"],
		["bumper_south_body", "OpenRingoutCovers/BumperSouthCollision", "south orange bumper"],
		["crate_left_a", "OpenRingoutCovers/LeftCrateACollision", "left yellow crate"],
		["crate_left_b", "OpenRingoutCovers/LeftCrateBCollision", "left yellow crate"],
		["crate_wood", "OpenRingoutCovers/WoodCrateCollision", "wood crate"],
		["orange_block", "OpenRingoutCovers/OrangeBlockCollision", "orange block"],
		["tan_block", "OpenRingoutCovers/TanBlockCollision", "tan block"],
		["ChunkyCoverClusterWest", "OpenRingoutCovers/WestChunkyCoverCollision", "west chunky cover"],
		["ChunkyCoverClusterWest_CushionA", "OpenRingoutCovers/WestChunkyCushionACollision", "west orange cushion"],
		["ChunkyCoverClusterWest_CushionB", "OpenRingoutCovers/WestChunkyCushionBCollision", "west orange cushion"],
	]:
		var visual_name := check[0] as String
		var collision_path := check[1] as String
		var label := check[2] as String
		var visual = _find_mesh_instance_by_name(blender_root, visual_name)
		if visual == null:
			_fail("Missing visual cover mesh for collision check: %s" % visual_name)
			continue
		var proxy = arena.get_node_or_null(collision_path)
		if proxy == null:
			_fail("%s has no matching runtime collision proxy: %s" % [label, collision_path])
			continue
		var shape = _find_collision_shape(proxy)
		if shape == null:
			_fail("%s collision proxy has no CollisionShape3D: %s" % [label, collision_path])
			continue
		var visual_center := _mesh_xz_center(visual)
		var collision_center := Vector2(shape.global_position.x, shape.global_position.z)
		var center_delta := visual_center.distance_to(collision_center)
		var visual_size := _mesh_visual_size(visual)
		var collision_size := _collision_shape_xz_size(shape)
		var max_center_delta := maxf(0.75, maxf(visual_size.x, visual_size.z) * 0.16)
		if center_delta > max_center_delta:
			_fail("%s collision center is %.2f from visual center; max %.2f" % [label, center_delta, max_center_delta])
		if collision_size.x < visual_size.x * 0.72 or collision_size.y < visual_size.z * 0.72:
			_fail("%s collision footprint %s is too small for visual %s" % [label, str(collision_size), str(Vector2(visual_size.x, visual_size.z))])
		else:
			print("OK  ", label)

func _verify_floor_color_logic(arena: Node) -> void:
	print("\n--- Floor Color Logic ---")
	for check in [
		["OpenRingoutPlayable/MainDeck", Color("#c7a47a"), "main combat platform"],
		["OpenRingoutPlayable/MainDeckWestLip", Color("#c7a47a"), "main island west extension"],
		["OpenRingoutPlayable/MainDeckEastLip", Color("#c7a47a"), "main island east extension"],
		["OpenRingoutPlayable/NorthDeck", Color("#d7c094"), "outer side platform"],
		["OpenRingoutPlayable/EastDeck", Color("#d7c094"), "outer side platform"],
		["OpenRingoutPlayable/SouthDeck", Color("#d7c094"), "outer side platform"],
		["OpenRingoutPlayable/WestDeck", Color("#d7c094"), "outer side platform"],
		["OpenRingoutPlayable/NorthBridge", Color("#ad7b57"), "bridge connector"],
		["OpenRingoutPlayable/EastBridge", Color("#ad7b57"), "bridge connector"],
		["OpenRingoutPlayable/SouthBridge", Color("#ad7b57"), "bridge connector"],
		["OpenRingoutPlayable/WestBridge", Color("#ad7b57"), "bridge connector"],
	]:
		_verify_platform_top_color(arena, check[0], check[1], check[2])

	var tile_line = arena.get_node_or_null("OpenRingoutPlayable/TileLines/TileLineX0") as MeshInstance3D
	var tile_line_mat = tile_line.material_override as StandardMaterial3D if tile_line else null
	if tile_line_mat == null:
		_fail("Tile floor groove material missing")
	elif tile_line_mat.albedo_color.a > 0.34:
		_fail("Tile grooves should be subtle floor seams, alpha %.2f is too strong" % tile_line_mat.albedo_color.a)
	else:
		print("OK  subtle tile grooves")

	var blender_root = arena.get_node_or_null("OpenRingoutBlenderVisuals") as Node3D
	if blender_root:
		for main_island_mesh in [
			"main_deck_irregular_top_slab",
			"main_west_lip_irregular_top_slab",
			"main_east_lip_irregular_top_slab",
			"EastCombatLaneFloorInset",
		]:
			_verify_named_mesh_color(blender_root, main_island_mesh, Color("#c7a47a"), "single-color main island floor")

	for forbidden_ground_patch in [
		"CenterWearPatchA",
		"CenterWearPatchB",
	]:
		if _has_named_descendant(arena, forbidden_ground_patch):
			_fail("Main island should not contain separate ground color patch: %s" % forbidden_ground_patch)

	if blender_root:
		for forbidden_main_floor_mark in [
			"main_deck_inset_glow_",
			"main_west_lip_inset_glow_",
			"main_east_lip_inset_glow_",
			"EastCombatLaneFloorStripe",
		]:
			if _has_descendant_name_containing(blender_root, forbidden_main_floor_mark):
				_fail("Main island should not use free-floating red/orange floor tick marks: %s" % forbidden_main_floor_mark)

func _verify_bridge_connector_visibility(arena: Node) -> void:
	print("\n--- Bridge Connector Visibility ---")
	var blender_root = arena.get_node_or_null("OpenRingoutBlenderVisuals") as Node3D
	if blender_root == null:
		_fail("OpenRingoutBlenderVisuals missing during bridge connector visibility check")
		return

	for check in [
		["north_bridge_irregular_top_slab", Vector2(8.0, 4.0), "north bridge deck"],
		["east_bridge_irregular_top_slab", Vector2(5.5, 6.0), "east bridge deck"],
		["south_bridge_irregular_top_slab", Vector2(8.0, 3.8), "south bridge deck"],
		["west_bridge_irregular_top_slab", Vector2(5.0, 7.0), "west bridge deck"],
	]:
		var mesh_name := check[0] as String
		var minimum_size := check[1] as Vector2
		var role := check[2] as String
		var mesh = _find_mesh_instance_by_name(blender_root, mesh_name)
		if mesh == null:
			_fail("Missing obvious bridge connector mesh: %s" % mesh_name)
			continue
		var visual_size := _mesh_visual_size(mesh)
		if visual_size.x < minimum_size.x or visual_size.z < minimum_size.y:
			_fail("%s is too small to read as %s, size %s" % [mesh_name, role, str(visual_size)])
		else:
			print("OK  ", mesh_name, " ", role)

func _verify_bridge_surface_integrity(arena: Node) -> void:
	print("\n--- Bridge Surface Integrity ---")
	var main_platform = arena.get_node_or_null("OpenRingoutPlayable/MainDeck") as Node3D
	if main_platform == null:
		_fail("MainDeck missing during bridge surface integrity check")
		return
	var main_collision_top := _platform_collision_top_y(main_platform)
	var main_art_top := _platform_art_top_y(main_platform)
	if is_nan(main_collision_top) or is_nan(main_art_top):
		_fail("MainDeck is missing collision or ArtTop data for bridge height comparison")
		return

	for bridge_path in [
		"OpenRingoutPlayable/NorthBridge",
		"OpenRingoutPlayable/EastBridge",
		"OpenRingoutPlayable/SouthBridge",
		"OpenRingoutPlayable/WestBridge",
	]:
		var bridge = arena.get_node_or_null(bridge_path) as Node3D
		if bridge == null:
			_fail("Missing bridge for surface integrity check: %s" % bridge_path)
			continue
		var collision_top := _platform_collision_top_y(bridge)
		var art_top := _platform_art_top_y(bridge)
		if is_nan(collision_top):
			_fail("%s missing collision top for surface integrity check" % bridge_path)
		elif absf(collision_top - main_collision_top) > 0.04:
			_fail("%s collision top should match MainDeck %.2f, got %.2f" % [bridge_path, main_collision_top, collision_top])
		else:
			print("OK  ", bridge_path, " collision top %.2f" % collision_top)
		if is_nan(art_top):
			_fail("%s missing ArtTop for surface integrity check" % bridge_path)
		elif absf(art_top - main_art_top) > 0.05:
			_fail("%s ArtTop should match MainDeck visual top %.2f, got %.2f" % [bridge_path, main_art_top, art_top])
		else:
			print("OK  ", bridge_path, " ArtTop %.2f" % art_top)

	var blender_root = arena.get_node_or_null("OpenRingoutBlenderVisuals") as Node3D
	if blender_root == null:
		_fail("OpenRingoutBlenderVisuals missing during bridge surface integrity check")
		return
	var main_visual = _find_mesh_instance_by_name(blender_root, "main_deck_irregular_top_slab")
	if main_visual == null:
		_fail("Main deck Blender top slab missing during bridge surface integrity check")
		return
	var main_visual_top := _mesh_y_range(main_visual).y
	for bridge_mesh_name in [
		"north_bridge_irregular_top_slab",
		"east_bridge_irregular_top_slab",
		"south_bridge_irregular_top_slab",
		"west_bridge_irregular_top_slab",
	]:
		var bridge_mesh = _find_mesh_instance_by_name(blender_root, bridge_mesh_name)
		if bridge_mesh == null:
			_fail("Missing Blender bridge top slab: %s" % bridge_mesh_name)
			continue
		var bridge_y_range := _mesh_y_range(bridge_mesh)
		var bridge_visual_top := bridge_y_range.y
		var bridge_visual_thickness := bridge_y_range.y - bridge_y_range.x
		if absf(bridge_visual_top - main_visual_top) > 0.06:
			_fail("%s visual top should match main visual top %.2f, got %.2f" % [bridge_mesh_name, main_visual_top, bridge_visual_top])
		elif absf(bridge_visual_top - main_visual_top) < 0.015:
			_fail("%s visual top is coplanar with island top %.2f and can z-fight at overlaps" % [bridge_mesh_name, main_visual_top])
		elif bridge_visual_thickness < 0.60:
			_fail("%s visual top slab is too thin %.2f and can render like a flat sticker" % [bridge_mesh_name, bridge_visual_thickness])
		else:
			print("OK  ", bridge_mesh_name, " visual top %.2f, thickness %.2f" % [bridge_visual_top, bridge_visual_thickness])

	for overlay_check in [
		"BridgeWarningConeNorthL_body",
		"BridgeWarningConeNorthR_body",
		"BridgeWarningConeEastT_body",
		"BridgeWarningConeEastB_body",
		"BridgeWarningConeSouthL_body",
		"BridgeWarningConeSouthR_body",
		"BridgeWarningConeWestT_body",
		"BridgeWarningConeWestB_body",
	]:
		var mesh_name := overlay_check as String
		var mesh = _find_mesh_instance_by_name(blender_root, mesh_name)
		if mesh == null:
			_fail("Missing bridge overlay during height check: %s" % mesh_name)
			continue
		var y_range := _mesh_y_range(mesh)
		if y_range.x > main_visual_top + 0.06:
			_fail("%s floats above visual bridge surface %.2f, visual bottom %.2f" % [mesh_name, main_visual_top, y_range.x])
		elif y_range.y < main_visual_top - 0.02:
			_fail("%s is buried below visual bridge surface %.2f, visual top %.2f" % [mesh_name, main_visual_top, y_range.y])
		else:
			print("OK  ", mesh_name, " grounded on visual bridge surface")


func _verify_east_west_bridge_topology(arena: Node) -> void:
	print("\n--- East/West Bridge Topology ---")
	var east_bridge = arena.get_node_or_null("OpenRingoutPlayable/EastBridge") as Node3D
	var east_deck = arena.get_node_or_null("OpenRingoutPlayable/EastDeck") as Node3D
	var west_bridge = arena.get_node_or_null("OpenRingoutPlayable/WestBridge") as Node3D
	var west_deck = arena.get_node_or_null("OpenRingoutPlayable/WestDeck") as Node3D
	if east_bridge == null or east_deck == null or west_bridge == null or west_deck == null:
		_fail("East/west bridge topology nodes are missing")
		return
	var east_bridge_extent := _platform_x_extent(east_bridge)
	var east_deck_extent := _platform_x_extent(east_deck)
	var west_bridge_extent := _platform_x_extent(west_bridge)
	var west_deck_extent := _platform_x_extent(west_deck)
	if east_bridge_extent == Vector2.ZERO or east_deck_extent == Vector2.ZERO or west_bridge_extent == Vector2.ZERO or west_deck_extent == Vector2.ZERO:
		_fail("Could not inspect east/west bridge collision extents")
		return
	var east_overlap := east_bridge_extent.y - east_deck_extent.x
	var west_overlap := west_deck_extent.y - west_bridge_extent.x
	for check in [["east", east_overlap], ["west", west_overlap]]:
		var label := check[0] as String
		var overlap := check[1] as float
		if overlap < 0.35 or overlap > 0.80:
			_fail("%s bridge should enter its side island by 0.35-0.80, got %.2f" % [label, overlap])
		else:
			print("OK  ", label, " bridge island overlap %.2f" % overlap)


func _verify_bridge_decor_not_flat_stickers(arena: Node) -> void:
	print("\n--- Bridge Decor Sticker Check ---")
	var blender_root = arena.get_node_or_null("OpenRingoutBlenderVisuals") as Node3D
	if blender_root == null:
		_fail("OpenRingoutBlenderVisuals missing during bridge decor sticker check")
		return

	for forbidden_bridge_floor_mark in [
		"north_bridge_inset_glow_",
		"east_bridge_inset_glow_",
		"south_bridge_inset_glow_",
		"west_bridge_inset_glow_",
		"BridgeTransitionPlate",
		"BridgeConnector",
		"BridgeTransitionPlateNorth_bolt",
		"BridgeTransitionPlateEast_bolt",
		"BridgeTransitionPlateSouth_bolt",
		"BridgeTransitionPlateWest_bolt",
		"BridgeConnectorNorth_cap",
		"BridgeConnectorEast_cap",
		"BridgeConnectorSouth_cap",
		"BridgeConnectorWest_cap",
	]:
		if _has_descendant_name_containing(blender_root, forbidden_bridge_floor_mark):
			_fail("Bridge should not use sticker-like floor marks: %s" % forbidden_bridge_floor_mark)

	print("OK  bridge decks use clean single-surface geometry")

func _verify_platform_top_color(arena: Node, path: String, expected: Color, role: String) -> void:
	var platform = arena.get_node_or_null(path) as Node3D
	if platform == null:
		_fail("Missing platform for floor color check: %s" % path)
		return
	var top = platform.get_node_or_null("ArtTop") as MeshInstance3D
	var mat = top.material_override as StandardMaterial3D if top else null
	if mat == null:
		_fail("%s missing ArtTop material for floor color check" % path)
		return
	if _color_delta(mat.albedo_color, expected) > 0.14:
		_fail("%s color should read as %s, got %s" % [path, role, str(mat.albedo_color)])
	else:
		print("OK  ", path, " ", role)

func _verify_named_mesh_color(root_node: Node, mesh_name: String, expected: Color, role: String) -> void:
	var mesh = _find_mesh_instance_by_name(root_node, mesh_name)
	if mesh == null:
		_fail("Missing mesh for floor color logic: %s" % mesh_name)
		return
	var mat = _mesh_material(mesh)
	if mat == null:
		_fail("%s missing material for floor color logic" % mesh_name)
		return
	if _color_delta(mat.albedo_color, expected) > 0.22:
		_fail("%s should read as %s, got %s" % [mesh_name, role, str(mat.albedo_color)])
	else:
		print("OK  ", mesh_name, " ", role)

func _find_mesh_instance_by_name(node: Node, target_name: String) -> MeshInstance3D:
	if node.name == target_name and node is MeshInstance3D:
		return node as MeshInstance3D
	for child in node.get_children():
		var found = _find_mesh_instance_by_name(child, target_name)
		if found:
			return found
	return null

func _mesh_material(mesh: MeshInstance3D) -> StandardMaterial3D:
	var active = mesh.get_active_material(0)
	if active is StandardMaterial3D:
		return active as StandardMaterial3D
	if mesh.mesh != null:
		var surface = mesh.mesh.surface_get_material(0)
		if surface is StandardMaterial3D:
			return surface as StandardMaterial3D
	return null

func _mesh_visual_size(mesh: MeshInstance3D) -> Vector3:
	if mesh.mesh == null:
		return Vector3.ZERO
	var local_size := mesh.mesh.get_aabb().size
	var scale := mesh.global_transform.basis.get_scale()
	return Vector3(
		local_size.x * absf(scale.x),
		local_size.y * absf(scale.y),
		local_size.z * absf(scale.z)
	)

func _mesh_xz_center(mesh: MeshInstance3D) -> Vector2:
	if mesh.mesh == null:
		return Vector2.ZERO
	var aabb = mesh.mesh.get_aabb()
	var local_center: Vector3 = aabb.position + aabb.size * 0.5
	var global_center: Vector3 = mesh.global_transform * local_center
	return Vector2(global_center.x, global_center.z)

func _collision_shape_xz_size(shape: CollisionShape3D) -> Vector2:
	var scale := shape.global_transform.basis.get_scale()
	if shape.shape is BoxShape3D:
		var box := shape.shape as BoxShape3D
		return Vector2(box.size.x * absf(scale.x), box.size.z * absf(scale.z))
	if shape.shape is CylinderShape3D:
		var cyl := shape.shape as CylinderShape3D
		return Vector2(cyl.radius * 2.0 * absf(scale.x), cyl.radius * 2.0 * absf(scale.z))
	if shape.shape is CapsuleShape3D:
		var cap := shape.shape as CapsuleShape3D
		return Vector2(cap.radius * 2.0 * absf(scale.x), cap.radius * 2.0 * absf(scale.z))
	return Vector2.ZERO

func _mesh_xz_area(mesh: MeshInstance3D) -> float:
	var size := _mesh_visual_size(mesh)
	return absf(size.x * size.z)

func _mesh_y_range(mesh: MeshInstance3D) -> Vector2:
	if mesh.mesh == null:
		return Vector2(NAN, NAN)
	var aabb = mesh.mesh.get_aabb()
	var min_y := INF
	var max_y := -INF
	for x in [aabb.position.x, aabb.position.x + aabb.size.x]:
		for y in [aabb.position.y, aabb.position.y + aabb.size.y]:
			for z in [aabb.position.z, aabb.position.z + aabb.size.z]:
				var global_point := mesh.global_transform * Vector3(x, y, z)
				min_y = minf(min_y, global_point.y)
				max_y = maxf(max_y, global_point.y)
	return Vector2(min_y, max_y)

func _platform_collision_top_y(platform: Node3D) -> float:
	var shape = _find_collision_shape(platform)
	if shape == null or not (shape.shape is BoxShape3D):
		return NAN
	var box := shape.shape as BoxShape3D
	var y_scale := absf(shape.global_transform.basis.get_scale().y)
	return shape.global_position.y + box.size.y * y_scale * 0.5

func _platform_x_extent(platform: Node3D) -> Vector2:
	var shape = _find_collision_shape(platform)
	if shape == null or not (shape.shape is BoxShape3D):
		return Vector2.ZERO
	var box := shape.shape as BoxShape3D
	var x_scale := absf(shape.global_transform.basis.get_scale().x)
	var half_width := box.size.x * x_scale * 0.5
	return Vector2(shape.global_position.x - half_width, shape.global_position.x + half_width)

func _platform_art_top_y(platform: Node3D) -> float:
	var top = platform.get_node_or_null("ArtTop") as MeshInstance3D
	if top == null:
		return NAN
	return _mesh_y_range(top).y

func _find_collision_shape(node: Node) -> CollisionShape3D:
	if node is CollisionShape3D:
		return node as CollisionShape3D
	for child in node.get_children():
		var found := _find_collision_shape(child)
		if found != null:
			return found
	return null

func _color_delta(a: Color, b: Color) -> float:
	return absf(a.r - b.r) + absf(a.g - b.g) + absf(a.b - b.b)

func _has_named_descendant(node: Node, target_name: String) -> bool:
	if node.name == target_name:
		return true
	for child in node.get_children():
		if _has_named_descendant(child, target_name):
			return true
	return false

func _has_descendant_name_containing(node: Node, name_part: String) -> bool:
	if String(node.name).contains(name_part):
		return true
	for child in node.get_children():
		if _has_descendant_name_containing(child, name_part):
			return true
	return false

func _count_descendants_with_prefix(node: Node, prefix: String) -> int:
	var count := 1 if String(node.name).begins_with(prefix) else 0
	for child in node.get_children():
		count += _count_descendants_with_prefix(child, prefix)
	return count

func _has_collision_descendant(node: Node) -> bool:
	if node is StaticBody3D or node is CollisionShape3D or node is Area3D:
		return true
	for child in node.get_children():
		if _has_collision_descendant(child):
			return true
	return false

func _verify_open_edges(arena: Node) -> void:
	print("\n--- Open Edge Check ---")
	var edge_root = arena.get_node_or_null("OpenRingoutEdgeGlow") as Node3D
	if edge_root == null:
		_fail("OpenRingoutEdgeGlow missing")
		return

	var glow_segments := 0
	for child in edge_root.get_children():
		if String(child.name).begins_with("Glow"):
			glow_segments += 1
		if (child as Node).get_node_or_null("StaticBody3D") != null:
			_fail("Edge glow segment has collision and would act like a wall: %s" % child.name)
	if glow_segments < 10:
		_fail("Expected at least 10 non-colliding edge glow segments, got %d" % glow_segments)
	else:
		print("OK  glow segments: ", glow_segments)

func _verify_visual_profile(arena: Node) -> void:
	print("\n--- Visual Profile ---")
	var light = arena.get_node_or_null("DirectionalLight3D") as DirectionalLight3D
	if light == null:
		_fail("DirectionalLight3D missing")
	elif light.light_energy < 0.55 or light.light_energy > 1.25:
		_fail("DirectionalLight3D energy is outside the warm toy range: %.2f" % light.light_energy)
	else:
		print("OK  light energy: %.2f" % light.light_energy)

	var env_node = arena.get_node_or_null("WorldEnvironment") as WorldEnvironment
	if env_node == null or env_node.environment == null:
		_fail("WorldEnvironment missing")
	else:
		var env = env_node.environment
		if env.ambient_light_energy < 0.12:
			_fail("Ambient light is too low for readable party-game visuals")
		else:
			print("OK  ambient light: %.2f" % env.ambient_light_energy)
		if not env.ssao_enabled:
			_fail("SSAO must be enabled for soft toy contact shadows")
		if not env.glow_enabled or env.glow_intensity < 0.42:
			_fail("Glow is too weak for toy edge and pickup highlights")
		if not env.adjustment_enabled or env.adjustment_saturation < 1.15 or env.adjustment_saturation > 1.24:
			_fail("Color grading must stay warm without returning to oversaturation")

	var camera = arena.get_node_or_null("GlobalCamera") as Camera3D
	if camera == null:
		_fail("GlobalCamera missing during visual profile check")
	elif camera.projection != Camera3D.PROJECTION_ORTHOGONAL or camera.size < 56.0 or camera.size > 62.0:
		_fail("GlobalCamera is not locked to the approved orthographic screenshot framing")

	if arena.get_node_or_null("ToyFillLight") == null:
		_fail("ToyFillLight missing")
	if arena.get_node_or_null("ToyRimLight") == null:
		_fail("ToyRimLight missing")

func _verify_abyss_background_design(arena: Node) -> void:
	print("\n--- Abyss Background Design ---")
	var abyss_root = arena.get_node_or_null("OpenRingoutAbyss") as Node3D
	if abyss_root == null:
		_fail("OpenRingoutAbyss missing during background design check")
		return
	if _has_collision_descendant(abyss_root):
		_fail("Abyss visual depth layers must not contain collision")

	var mist_count := _count_descendants_with_prefix(abyss_root, "AbyssMist")
	if mist_count < 16:
		_fail("Abyss needs layered mist/cloud puffs, got %d" % mist_count)
	else:
		print("OK  abyss mist layers: ", mist_count)

	var soft_cloud_count := _count_descendants_with_prefix(abyss_root, "AbyssSoftCloud")
	if soft_cloud_count < 48:
		_fail("Abyss needs soft volumetric-looking cloud puffs instead of hard flat marks, got %d" % soft_cloud_count)
	else:
		print("OK  abyss soft cloud puffs: ", soft_cloud_count)

	var mote_count := _count_descendants_with_prefix(abyss_root, "AbyssGlowMote")
	if mote_count < 10:
		_fail("Abyss needs small glowing depth motes, got %d" % mote_count)
	else:
		print("OK  abyss glow motes: ", mote_count)

	var backdrop_root = arena.get_node_or_null("OpenRingoutBackdrop") as Node3D
	if backdrop_root == null:
		_fail("OpenRingoutBackdrop missing during background design check")
		return
	if _has_collision_descendant(backdrop_root):
		_fail("Backdrop islands must be visual only and non-colliding")
	for required_backdrop in [
		"BackdropIslandLeftCliff",
		"BackdropIslandRightCliff",
		"BackdropIslandLowerLeftCliff",
		"BackdropIslandLowerRightCliff",
	]:
		if not _has_named_descendant(backdrop_root, required_backdrop):
			_fail("Missing concept-style distant floating island: %s" % required_backdrop)
		else:
			print("OK  ", required_backdrop)

	var blender_root = arena.get_node_or_null("OpenRingoutBlenderVisuals") as Node3D
	if blender_root:
		for required_depth_visual in [
			"FarFloatingIslandLeft_cliff",
			"FarFloatingIslandRight_cliff",
			"FarAbyssCloudPuff_0",
			"FarAbyssCloudPuff_8",
			"FarAbyssGlowMote_0",
		]:
			if not _has_named_descendant(blender_root, required_depth_visual):
				_fail("Blender background depth layer is missing %s" % required_depth_visual)
			else:
				print("OK  ", required_depth_visual)

func _verify_ringout_respawn(arena: Node) -> void:
	print("\n--- Ring-Out Respawn ---")
	var chars = arena.get("_characters") as Array
	if chars.is_empty():
		_fail("No characters available for ring-out respawn check")
		return

	var character = chars[0] as BaseCharacter
	if character == null:
		_fail("First roster entry is not a BaseCharacter")
		return

	if character.lives != 4:
		_fail("Open slice should start characters at 4 lives, got %d" % character.lives)
	else:
		print("OK  initial lives: ", character.lives)

	var manager: WeaponManager = character.weapon_manager
	if manager == null:
		_fail("Character is missing WeaponManager during respawn weapon check")
		return
	manager.equip_weapon(WeaponData.create_smg())
	await process_frame
	if not manager.has_primary() or manager.current_weapon == null or manager.current_weapon.weapon_data.weapon_id != &"smg":
		_fail("Could not equip non-default weapon before respawn test")
		return

	character.global_position = Vector3(0, -20, 0)
	character.call("_check_fall")
	await process_frame

	if character.lives != 3:
		_fail("Ring-out did not deduct exactly one life, got %d" % character.lives)
	else:
		print("OK  life deducted on fall")

	await create_timer(1.35).timeout
	await process_frame

	if character.is_dead:
		_fail("Character did not respawn after ring-out delay")
	else:
		print("OK  character respawned")

	if manager.has_primary():
		_fail("Respawned character retained a primary weapon")
	elif manager.current_weapon == null or manager.current_weapon.weapon_data.weapon_id != &"pistol":
		_fail("Respawned character should hold the base pistol")
	else:
		print("OK  respawn reset weapon to base pistol")
	var visual: Node = character.get_visual()
	if visual and StringName(visual.get("_current_weapon_id")) != &"pistol":
		_fail("Respawned character visual did not reset to pistol")

	var playable = arena.get_node_or_null("OpenRingoutPlayable") as Node3D
	if playable and not _point_over_playable_surface(character.global_position, playable):
		_fail("Respawned character is not over playable surface: %s" % str(character.global_position))
	else:
		print("OK  respawn position is playable")

func _point_over_playable_surface(point: Vector3, playable: Node3D) -> bool:
	for child in playable.get_children():
		if not (child is Node3D):
			continue
		if _point_over_block(point, child as Node3D):
			return true
	return false

func _point_over_block(point: Vector3, block_root: Node3D) -> bool:
	var mesh_instance: MeshInstance3D = null
	for child in block_root.get_children():
		if child is MeshInstance3D:
			mesh_instance = child as MeshInstance3D
			break
	if mesh_instance == null:
		return false
	if not (mesh_instance.mesh is BoxMesh):
		return false

	var box = mesh_instance.mesh as BoxMesh
	var local_point = block_root.to_local(point)
	var half_size = box.size * 0.5
	var inside_x = absf(local_point.x) <= half_size.x + 0.25
	var inside_z = absf(local_point.z) <= half_size.z + 0.25
	return inside_x and inside_z

func _fail(message: String) -> void:
	_failures.append(message)
	push_error(message)

func _finish() -> void:
	if _host and is_instance_valid(_host):
		_host.queue_free()
		await process_frame

	print("\n==================================================")
	if _failures.is_empty():
		print("[Open Ringout Verifier] PASS")
		print("==================================================")
		quit(0)
		return

	print("[Open Ringout Verifier] FAIL")
	for failure in _failures:
		print("- ", failure)
	print("==================================================")
	quit(1)
