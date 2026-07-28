extends Node3D
## Dynamic battle scene driven by MatchConfig.

const RuntimeGlobals = preload("res://scripts/globals/runtime_globals.gd")
const CombatProfileLoader = preload("res://scripts/globals/combat_profile_loader.gd")

@onready var weapon_spawner = $WeaponSpawner

const PLAYER_SCENE = preload("res://scenes/characters/player.tscn")
const AI_SCENE = preload("res://scenes/characters/ai_character.tscn")
const CONTROL_MODE_PANEL_SCRIPT = preload("res://scripts/ui/control_mode_panel.gd")
const MATCH_HUD_SCENE = preload("res://scenes/ui/match_hud.tscn")

var DEFAULT_SPAWN_POINTS := [
	Vector3(-12, 1, -12),
	Vector3(12, 1, 12),
	Vector3(-12, 1, 12),
	Vector3(12, 1, -12),
]

var _characters: Array = []
var _match_hud: CanvasLayer = null
var _victory_screen: CanvasLayer = null
var _match_ended := false
var _ta_runtime: Node = null

func _ready() -> void:
	_build_map_layout()
	_build_map_dressing()
	_apply_shared_runtime_config()
	_configure_map_runtime()
	_apply_ta_pipeline()
	_apply_map_visual_overrides()
	_spawn_characters()
	_setup_hud()
	_setup_victory_screen()
	_setup_control_mode_panel()

func _process(delta: float) -> void:
	if has_method("_update_map_runtime_camera"):
		call("_update_map_runtime_camera", delta)
		return
	if _uses_fixed_runtime_camera():
		return
	if _ta_runtime and is_instance_valid(_ta_runtime) and _ta_runtime.has_method("update_runtime_camera"):
		_ta_runtime.call("update_runtime_camera", self, _characters, delta)

func _apply_ta_pipeline() -> void:
	var ta_script = load("res://scripts/maps/ta_pipeline_manager.gd")
	if ta_script and ta_script.can_instantiate():
		var ta = ta_script.new() as Node
		if ta and ta.has_method("apply_pipeline"):
			# Keep the runtime object inside the scene tree so it is cleaned up with the arena.
			ta.name = "TAPipelineRuntime"
			add_child(ta)
			_ta_runtime = ta
			ta.call("apply_pipeline", self)

func _build_map_layout() -> void:
	_build_kaykit_floor()

func _build_map_dressing() -> void:
	_build_external_art_dressing()

func _get_spawn_points() -> Array:
	return DEFAULT_SPAWN_POINTS.duplicate()

func _apply_shared_runtime_config() -> void:
	var game_config = RuntimeGlobals.game_config()
	if game_config:
		CombatProfileLoader.apply_party_shooter_v1(game_config)

	var respawn_points: Array[Vector3] = []
	for point in _get_spawn_points():
		respawn_points.append(point as Vector3)
	if game_config:
		game_config.set("respawn_points", respawn_points)

func _configure_map_runtime() -> void:
	pass

func _apply_map_visual_overrides() -> void:
	pass

func _uses_fixed_runtime_camera() -> bool:
	return false

func _spawn_characters() -> void:
	var human_index := 0
	var spawn_points := _get_spawn_points()
	for i in range(MatchConfig.slots.size()):
		var slot = MatchConfig.slots[i]
		if slot == MatchConfig.SlotType.EMPTY:
			continue

		var character: BaseCharacter
		var spawn_pos = spawn_points[i] if i < spawn_points.size() else Vector3(i * 8, 0.5, 0)

		if slot == MatchConfig.SlotType.HUMAN:
			var player_instance = PLAYER_SCENE.instantiate()
			player_instance.input_prefix = MatchConfig.INPUT_PREFIXES[human_index] if human_index < MatchConfig.INPUT_PREFIXES.size() else "p1_"
			player_instance.slot_index = i
			human_index += 1
			character = player_instance
		else:
			character = AI_SCENE.instantiate()

		character.transform.origin = spawn_pos
		character.name = _get_character_name(i, slot)
		add_child(character)

		if slot == MatchConfig.SlotType.HUMAN:
			character.add_to_group("player")
		else:
			character.add_to_group("player")
			character.add_to_group("ai")

		character.eliminated.connect(_on_character_eliminated)
		_apply_color(character, i)
		_characters.append(character)

func _get_character_name(index: int, slot_type: int) -> String:
	if slot_type == MatchConfig.SlotType.HUMAN:
		return "Player %d" % (index + 1)
	return "AI Bot %d" % (index + 1)

func _apply_color(character: BaseCharacter, slot_index: int) -> void:
	var color = MatchConfig.PLAYER_COLORS[slot_index]
	await get_tree().process_frame
	var visual = character.get_visual()
	if visual and visual.has_method("set_body_color"):
		visual.set_body_color(color)

func _setup_hud() -> void:
	_match_hud = MATCH_HUD_SCENE.instantiate()
	_match_hud.name = "GameHUD"
	var hud_parent: Node = self
	for character in _characters:
		if character is PlayerCharacter:
			hud_parent = character
			break
	hud_parent.add_child(_match_hud)
	_match_hud.call("set_characters", _characters)

func _setup_victory_screen() -> void:
	_victory_screen = VictoryScreen.new()
	add_child(_victory_screen)

func _setup_control_mode_panel() -> void:
	if not bool(get_meta("enable_control_mode_review_panel", false)):
		return
	var panel = CONTROL_MODE_PANEL_SCRIPT.new()
	add_child(panel)

func _on_character_eliminated(_character: BaseCharacter) -> void:
	if _match_ended:
		return

	var survivors: Array = []
	for c in _characters:
		if not c.is_game_over:
			survivors.append(c)

	if survivors.size() <= 1:
		_match_ended = true
		if survivors.size() == 1:
			var winner := survivors[0] as BaseCharacter
			var winner_name: String = winner.name
			var slot_index := _characters.find(winner)
			var winner_color: Color = MatchConfig.PLAYER_COLORS[slot_index] if slot_index < MatchConfig.PLAYER_COLORS.size() else Color.WHITE
			_present_match_result(winner, winner_name, winner_color)
		else:
			_present_match_result(null, "DRAW", Color.WHITE)

func _present_match_result(_winner: BaseCharacter, winner_name: String, winner_color: Color) -> void:
	if _victory_screen:
		_victory_screen.show_victory(winner_name, winner_color, _characters)

func _build_kaykit_floor() -> void:
	var path_base = "res://assets/models/kaykit_platformer/KayKit_Platformer_Pack_1.0_FREE/KayKit_Platformer_Pack_1.0_FREE/Assets/gltf/green/"
	var block_large = load(path_base + "platform_6x6x2_green.gltf")
	var block_small = load(path_base + "platform_4x4x1_green.gltf")

	if not block_large or not block_small:
		print("KayKit floor assets missing, keeping fallback arena geometry.")
		return

	for child in get_children():
		if child is CSGShape3D or child is StaticBody3D or child.name == "Floor" or child.name == "Obstacles" or child.name == "VisualLanguage" or child.name == "KaykitMap":
			child.queue_free()

	var map_node = Node3D.new()
	map_node.name = "KaykitMap"
	add_child(map_node)

	var floor_mat = _make_floor_material()
	var trim_mat = _make_trim_material()

	# Layer 0: visual foundation only.
	var base_plate = _spawn_visual_block(block_large, Vector3(0, -4.8, 0), Vector3(52, 1.8, 52), map_node)
	_apply_material_recursive(base_plate, floor_mat)

	# Layer 1: main playable shell (continuous traversal area).
	var main_shell = _spawn_block(block_large, Vector3(0, -1.0, 0), Vector3(34, 2, 34), map_node)
	_apply_material_recursive(main_shell, floor_mat)

	# Layer 2: center objective island (high-risk, high-reward).
	var center_plate = _spawn_block(block_large, Vector3(0, -0.2, 0), Vector3(10, 2, 10), map_node)
	_apply_material_recursive(center_plate, trim_mat)

	# Layer 3: rotational lanes linking inner fight and outer flank.
	for p in [
		Vector3(0, -0.8, -12), Vector3(0, -0.8, 12),
		Vector3(-12, -0.8, 0), Vector3(12, -0.8, 0)
	]:
		var lane_link = _spawn_block(block_small, p, Vector3(8, 2, 6), map_node)
		_apply_material_recursive(lane_link, floor_mat)

	# Layer 4: outer ring anchors to preserve long-route flanking.
	for p in [
		Vector3(-16, -0.8, -16), Vector3(16, -0.8, -16),
		Vector3(-16, -0.8, 16), Vector3(16, -0.8, 16),
		Vector3(-16, -0.8, 8), Vector3(16, -0.8, -8),
		Vector3(-8, -0.8, -16), Vector3(8, -0.8, 16)
	]:
		var flank_anchor = _spawn_block(block_small, p, Vector3(6, 2, 6), map_node)
		_apply_material_recursive(flank_anchor, floor_mat)

	# Half-cover set: gives peek opportunities but punishable if over-commit.
	for p in [
		Vector3(-6.0, 0.1, -2.5), Vector3(6.0, 0.1, 2.5),
		Vector3(2.5, 0.1, -6.0), Vector3(-2.5, 0.1, 6.0),
		Vector3(-12.0, 0.1, -5.0), Vector3(12.0, 0.1, 5.0),
		Vector3(-5.0, 0.1, 12.0), Vector3(5.0, 0.1, -12.0)
	]:
		_spawn_tactical_cover(block_small, p, Vector3(2.2, 1.6, 3.2), map_node, trim_mat)

	# Full-cover set: route reset and anti-snowball anchors.
	for p in [
		Vector3(-8.5, 0.3, 0.0), Vector3(8.5, 0.3, 0.0),
		Vector3(0.0, 0.3, -8.5), Vector3(0.0, 0.3, 8.5),
		Vector3(-14.0, 0.3, -10.0), Vector3(14.0, 0.3, 10.0),
		Vector3(-14.0, 0.3, 10.0), Vector3(14.0, 0.3, -10.0)
	]:
		_spawn_tactical_cover(block_small, p, Vector3(2.8, 2.8, 2.8), map_node, trim_mat)

	# Spawn buffers: two exits from each spawn quadrant to avoid instant lock.
	for p in [
		Vector3(-13.0, 0.2, -13.0), Vector3(-9.0, 0.2, -13.0),
		Vector3(13.0, 0.2, 13.0), Vector3(9.0, 0.2, 13.0),
		Vector3(-13.0, 0.2, 13.0), Vector3(-9.0, 0.2, 13.0),
		Vector3(13.0, 0.2, -13.0), Vector3(9.0, 0.2, -13.0)
	]:
		_spawn_tactical_cover(block_small, p, Vector3(2.4, 2.2, 2.4), map_node, trim_mat)

func _make_floor_material() -> StandardMaterial3D:
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color("#6dc487")
	mat.metallic = 0.0
	mat.roughness = 0.95
	mat.specular = 0.1
	return mat

func _make_trim_material() -> StandardMaterial3D:
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color("#88d8c7")
	mat.metallic = 0.0
	mat.roughness = 0.92
	mat.specular = 0.14
	return mat

func _apply_material_recursive(node: Node, mat: Material) -> void:
	if node is MeshInstance3D:
		var mesh_node = node as MeshInstance3D
		var mesh = mesh_node.mesh
		if mesh:
			for i in range(mesh.get_surface_count()):
				mesh_node.set_surface_override_material(i, mat)
	for c in node.get_children():
		_apply_material_recursive(c, mat)

func _spawn_tactical_cover(scene: PackedScene, pos: Vector3, col_size: Vector3, parent: Node, mat: Material) -> void:
	var cover = _spawn_block(scene, pos, col_size, parent)
	_apply_material_recursive(cover, mat)

func _build_external_art_dressing() -> void:
	var root = get_node_or_null("ExternalArt")
	if root:
		root.queue_free()

	root = Node3D.new()
	root.name = "ExternalArt"
	add_child(root)

	var p = "res://assets/models/third_party/kenney/curated_food_dojo/"
	_spawn_prop(p + "gate.glb", Vector3(0, -0.2, -25), Vector3(1.5, 1.5, 1.5), root)
	_spawn_prop(p + "gate.glb", Vector3(0, -0.2, 25), Vector3(1.5, 1.5, 1.5), root, 180.0)
	_spawn_prop(p + "town_banner-red.glb", Vector3(-7, 0.2, -21), Vector3(1.8, 1.8, 1.8), root)
	_spawn_prop(p + "town_banner-green.glb", Vector3(7, 0.2, -21), Vector3(1.8, 1.8, 1.8), root)
	_spawn_prop(p + "town_banner-green.glb", Vector3(-7, 0.2, 21), Vector3(1.8, 1.8, 1.8), root)
	_spawn_prop(p + "town_banner-red.glb", Vector3(7, 0.2, 21), Vector3(1.8, 1.8, 1.8), root)

	_spawn_prop(p + "grave_altar-stone.glb", Vector3(0, 0.0, -16), Vector3(1.6, 1.4, 1.6), root)
	_spawn_prop(p + "grave_altar-stone.glb", Vector3(0, 0.0, 16), Vector3(1.6, 1.4, 1.6), root, 180.0)
	_spawn_prop(p + "grave_pillar-large.glb", Vector3(-5.5, 0, -5.5), Vector3(1.5, 1.8, 1.5), root)
	_spawn_prop(p + "grave_pillar-large.glb", Vector3(5.5, 0, -5.5), Vector3(1.5, 1.8, 1.5), root)
	_spawn_prop(p + "grave_pillar-large.glb", Vector3(-5.5, 0, 5.5), Vector3(1.5, 1.8, 1.5), root)
	_spawn_prop(p + "grave_pillar-large.glb", Vector3(5.5, 0, 5.5), Vector3(1.5, 1.8, 1.5), root)

	# Perimeter dressing to kill "void map" look.
	for x in [-19.0, -13.0, 13.0, 19.0]:
		_spawn_prop(p + "nature_tree_small.glb", Vector3(x, 0, -20), Vector3(1.7, 1.9, 1.7), root)
		_spawn_prop(p + "nature_tree_small.glb", Vector3(x, 0, 20), Vector3(1.7, 1.9, 1.7), root)
	for z in [-19.0, -13.0, 13.0, 19.0]:
		_spawn_prop(p + "nature_tree_simple.glb", Vector3(-20, 0, z), Vector3(1.7, 1.9, 1.7), root)
		_spawn_prop(p + "nature_tree_simple.glb", Vector3(20, 0, z), Vector3(1.7, 1.9, 1.7), root)

	_spawn_prop(p + "nature_rock_smallTopA.glb", Vector3(-22, 0, -10), Vector3(1.9, 1.6, 1.9), root)
	_spawn_prop(p + "nature_rock_smallTopA.glb", Vector3(22, 0, 10), Vector3(1.9, 1.6, 1.9), root)
	_spawn_prop(p + "nature_rock_smallTopA.glb", Vector3(-22, 0, 10), Vector3(1.9, 1.6, 1.9), root)
	_spawn_prop(p + "nature_rock_smallTopA.glb", Vector3(22, 0, -10), Vector3(1.9, 1.6, 1.9), root)

func _spawn_prop(path: String, pos: Vector3, scl: Vector3, parent: Node3D, yaw_deg: float = 0.0) -> void:
	var ps = load(path)
	if not ps:
		return
	var inst = ps.instantiate() as Node3D
	if not inst:
		return
	parent.add_child(inst)
	inst.position = pos
	inst.scale = scl
	inst.rotation_degrees = Vector3(0, yaw_deg, 0)

func _spawn_block(scene: PackedScene, pos: Vector3, col_size: Vector3, parent: Node) -> Node3D:
	var instance = scene.instantiate()
	parent.add_child(instance)
	instance.position = pos
	instance.scale = Vector3(col_size.x / 4.0, col_size.y / 2.0, col_size.z / 4.0)

	var static_body = StaticBody3D.new()
	var collision_shape = CollisionShape3D.new()
	var box = BoxShape3D.new()
	box.size = Vector3(4.0, 2.0, 4.0)
	collision_shape.shape = box
	collision_shape.position = Vector3(0, 1.0, 0)
	static_body.add_child(collision_shape)
	instance.add_child(static_body)
	return instance

func _spawn_whitebox_block(name: String, pos: Vector3, size: Vector3, parent: Node3D, mat: Material, collision_enabled: bool = true, yaw_deg: float = 0.0) -> Node3D:
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

func _spawn_visual_block(scene: PackedScene, pos: Vector3, col_size: Vector3, parent: Node) -> Node3D:
	var instance = scene.instantiate()
	parent.add_child(instance)
	instance.position = pos
	instance.scale = Vector3(col_size.x / 4.0, col_size.y / 2.0, col_size.z / 4.0)
	return instance
