extends SceneTree

const HERO_PATH := "res://assets/models/generated/sunset_toy_sky_islands/sunset_hero_slice.glb"
const MIN_MESH_COUNT := 55
const MIN_MATERIAL_COUNT := 16

const REQUIRED_NODES := [
	"HeroPlatformCliff",
	"HeroPlatformWarmBand",
	"HeroPlatformTop",
	"HeroBridgePlank_0",
	"HeroBridgePost_0",
	"HeroBridgeGem_0",
	"HeroRedBumperBody",
	"HeroGoldenCrate",
	"HeroPickupGoldRing",
	"HeroCharacterBody",
	"HeroCharacterVisor",
	"HeroCharacterHandL",
	"HeroPistolBody",
	"HeroPistolMuzzle",
	"HeroMuzzleCore",
	"HeroProjectile_0Body",
	"HeroCloudPinkNorth_0",
	"HeroDistantIslandCliff_0",
]

var _failures: Array[String] = []
var _host: Node = null


func _initialize() -> void:
	print("==================================================")
	print("[Sunset Hero Verifier]")
	print("==================================================")

	var packed = load(HERO_PATH) as PackedScene
	if packed == null:
		_fail("Could not load %s" % HERO_PATH)
		await _finish()
		return

	_host = packed.instantiate()
	root.add_child(_host)

	for node_name in REQUIRED_NODES:
		if _host.find_child(node_name, true, false) == null:
			_fail("Missing required hero node: %s" % node_name)

	var meshes: Array[MeshInstance3D] = []
	_collect_meshes(_host, meshes)
	print("Mesh instances: %d" % meshes.size())
	if meshes.size() < MIN_MESH_COUNT:
		_fail("Expected at least %d mesh instances, found %d" % [MIN_MESH_COUNT, meshes.size()])

	var material_ids := {}
	for mesh_instance in meshes:
		if mesh_instance.mesh == null:
			continue
		for surface_index in range(mesh_instance.mesh.get_surface_count()):
			var material = mesh_instance.mesh.surface_get_material(surface_index)
			if material:
				material_ids[material.get_instance_id()] = true
	print("Unique materials: %d" % material_ids.size())
	if material_ids.size() < MIN_MATERIAL_COUNT:
		_fail("Expected at least %d unique materials, found %d" % [MIN_MATERIAL_COUNT, material_ids.size()])

	if _contains_collision_object(_host):
		_fail("Hero visual GLB must remain collision-free")

	await _finish()


func _collect_meshes(node: Node, output: Array[MeshInstance3D]) -> void:
	if node is MeshInstance3D:
		output.append(node as MeshInstance3D)
	for child in node.get_children():
		_collect_meshes(child, output)


func _contains_collision_object(node: Node) -> bool:
	if node is CollisionObject3D or node is CollisionShape3D:
		return true
	for child in node.get_children():
		if _contains_collision_object(child):
			return true
	return false


func _fail(message: String) -> void:
	_failures.append(message)
	push_error(message)


func _finish() -> void:
	if _host:
		_host.queue_free()
	await process_frame
	if _failures.is_empty():
		print("[Sunset Hero Verifier] PASS")
		quit(0)
		return
	print("[Sunset Hero Verifier] FAIL (%d)" % _failures.size())
	quit(1)
