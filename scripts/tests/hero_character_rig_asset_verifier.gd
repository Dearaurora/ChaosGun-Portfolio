extends SceneTree

const ASSET_PATH := "res://assets/models/generated/characters/hero_character_rig_v1.glb"
const EXPECTED_BONES := [
	&"Root",
	&"Spine",
	&"Head",
	&"UpperArm.L",
	&"Forearm.L",
	&"Hand.L",
	&"UpperArm.R",
	&"Forearm.R",
	&"Hand.R",
	&"Foot.L",
	&"Foot.R",
]

var _skeletons: Array[Skeleton3D] = []
var _meshes: Array[MeshInstance3D] = []


func _initialize() -> void:
	var packed := load(ASSET_PATH) as PackedScene
	if packed == null:
		_fail("could not load %s" % ASSET_PATH)
		return

	var instance := packed.instantiate()
	root.add_child(instance)
	_collect_nodes(instance)
	if _skeletons.size() != 1:
		_fail("expected one Skeleton3D, found %d" % _skeletons.size())
		return
	if _meshes.size() < 4:
		_fail("expected at least four MeshInstance3D nodes, found %d" % _meshes.size())
		return

	var skeleton := _skeletons[0]
	for bone_name in EXPECTED_BONES:
		if skeleton.find_bone(bone_name) < 0:
			_fail("missing bone %s" % bone_name)
			return

	var skinned_meshes := 0
	for mesh in _meshes:
		if mesh.skin != null:
			skinned_meshes += 1
	if skinned_meshes == 0:
		_fail("no MeshInstance3D has an imported Skin resource")
		return

	print(
		"HERO_RIG_GODOT_PASS bones=%d meshes=%d skinned=%d"
		% [skeleton.get_bone_count(), _meshes.size(), skinned_meshes]
	)
	quit(0)


func _collect_nodes(node: Node) -> void:
	if node is Skeleton3D:
		_skeletons.append(node)
	if node is MeshInstance3D:
		_meshes.append(node)
	for child in node.get_children():
		_collect_nodes(child)


func _fail(message: String) -> void:
	push_error("HERO_RIG_GODOT_FAIL %s" % message)
	quit(1)
