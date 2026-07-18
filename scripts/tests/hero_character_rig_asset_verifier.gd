extends SceneTree

const ASSET_PATH := "res://assets/models/generated/characters/hero_character_rig_v2.glb"
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
const EXPECTED_ANIMATIONS := [
	&"neutral",
	&"hold_pistol",
	&"hold_smg",
	&"hold_ak",
	&"hold_sniper",
	&"hold_shotgun",
	&"hold_gatling",
	&"start_pistol", &"run_pistol", &"stop_pistol", &"hit_pistol",
	&"start_smg", &"run_smg", &"stop_smg", &"hit_smg",
	&"start_ak", &"run_ak", &"stop_ak", &"hit_ak",
	&"start_sniper", &"run_sniper", &"stop_sniper", &"hit_sniper",
	&"start_shotgun", &"run_shotgun", &"stop_shotgun", &"hit_shotgun",
	&"start_gatling", &"run_gatling", &"stop_gatling", &"hit_gatling",
]
const EXPECTED_MESHES := [
	"HeroCloudBody",
	"HeroSleeve.L",
	"HeroSleeve.R",
	"HeroWristCuff.L",
	"HeroWristCuff.R",
	"FacePanel",
	"EyeL",
	"EyeR",
]

var _skeletons: Array[Skeleton3D] = []
var _meshes: Array[MeshInstance3D] = []
var _animation_players: Array[AnimationPlayer] = []


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
	if _animation_players.size() != 1:
		_fail("expected one AnimationPlayer, found %d" % _animation_players.size())
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
	for mesh_name in EXPECTED_MESHES:
		if not _has_mesh_named(mesh_name):
			_fail("missing production mesh %s" % mesh_name)
			return

	var animation_player := _animation_players[0]
	for animation_name in EXPECTED_ANIMATIONS:
		if not animation_player.has_animation(animation_name):
			_fail("missing animation %s; imported %s" % [animation_name, animation_player.get_animation_list()])
			return
		var animation := animation_player.get_animation(animation_name)
		if animation == null or animation.get_track_count() == 0:
			_fail("animation %s has no pose tracks" % animation_name)
			return
		if String(animation_name).begins_with("run_") and (animation.length < 0.55 or animation.length > 0.66):
			_fail("run animation %s should retain the authored 0.6 second cadence, got %.3f" % [animation_name, animation.length])
			return

	print(
		"HERO_RIG_GODOT_PASS bones=%d meshes=%d skinned=%d animations=%s"
		% [skeleton.get_bone_count(), _meshes.size(), skinned_meshes, animation_player.get_animation_list()]
	)
	quit(0)


func _collect_nodes(node: Node) -> void:
	if node is Skeleton3D:
		_skeletons.append(node)
	if node is MeshInstance3D:
		_meshes.append(node)
	if node is AnimationPlayer:
		_animation_players.append(node)
	for child in node.get_children():
		_collect_nodes(child)


func _has_mesh_named(mesh_name: String) -> bool:
	var normalized_target := mesh_name.to_lower().replace(".", "").replace("_", "")
	for mesh in _meshes:
		var normalized_name := String(mesh.name).to_lower().replace(".", "").replace("_", "")
		if normalized_name == normalized_target:
			return true
	return false


func _fail(message: String) -> void:
	push_error("HERO_RIG_GODOT_FAIL %s" % message)
	quit(1)
