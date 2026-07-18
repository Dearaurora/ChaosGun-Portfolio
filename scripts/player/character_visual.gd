extends Node3D
class_name CharacterVisual
## 角色可视化：代码构建蓝色豆子人模型（参考图风格）
## 可分离部件：帽子、衣服、枪械

@export var body_color: Color = Color(0.15, 0.35, 1.0)
@export var show_hat: bool = false
@export var show_vest: bool = false
@export var show_visor: bool = true

const HERO_CHARACTER_SCENE_PATH := "res://assets/models/generated/characters/hero_character_rig_v2.glb"
const LEGACY_CHARACTER_SCENE_PATH := "res://assets/models/generated/characters/bean_character.glb"
const WEAPON_MODEL_ROOT := "res://assets/models/generated/weapons/"
const RuntimeGlobals = preload("res://scripts/globals/runtime_globals.gd")
const FOOTSTEP_STREAMS: Array[AudioStream] = [
	preload("res://assets/audio/impact-sounds/Audio/footstep_wood_001.ogg"),
	preload("res://assets/audio/impact-sounds/Audio/footstep_wood_002.ogg"),
	preload("res://assets/audio/impact-sounds/Audio/footstep_wood_004.ogg"),
]
const HERO_RUNTIME_SCALE := Vector3(1.14, 1.06, 1.14)
const CONTACT_SHADOW_Y_OFFSET := -0.075
const HERO_RECOIL_SCALE := 0.62
const HERO_RECOIL_YAW_SCALE := 0.72
const HERO_RECOIL_ROLL_SCALE := 0.68
const HERO_WEAPON_KICK_SCALE := 0.32
const HERO_SPINE_PIVOT := Vector3(0.0, 0.62, 0.0)
const WEAPON_SWITCH_DURATION := 0.22
const WEAPON_SWITCH_DIP_RADIANS := 0.10
const LOCOMOTION_START_DECAY := 5.6
const LOCOMOTION_STOP_DECAY := 4.8
const AUTHORED_MOTION_BLEND := 0.065
const AUTHORED_HIT_BLEND := 0.035
const SUIT_ROUGHNESS := 0.54
const RUBBER_COLOR := Color("#412853")
const FACE_PANEL_COLOR := Color("#171126")
const EYE_COLOR := Color("#ffd45a")

enum AuthoredMotionState {
	HOLD,
	START,
	RUN,
	STOP,
	HIT,
}

var _weapon_holder: Node3D
var _bounce_time: float = 0.0
var _hit_flash_timer: float = 0.0
var _body_mesh: MeshInstance3D
var _body_color_meshes: Array[MeshInstance3D] = []
var _suit_materials: Array[StandardMaterial3D] = []
var _rubber_materials: Array[StandardMaterial3D] = []
var _face_panel_materials: Array[StandardMaterial3D] = []
var _eye_materials: Array[StandardMaterial3D] = []
var _rendered_body_color := Color.TRANSPARENT
var _has_rendered_body_color: bool = false
var _asset_root: Node3D = null
var _animation_player: AnimationPlayer = null
var _skeleton: Skeleton3D = null
var _uses_hero_rig: bool = false
var _active_weapon_pose: StringName = &"neutral"
var _contact_shadow: MeshInstance3D = null
var _contact_shadow_material: StandardMaterial3D = null
var _leg_bone_indices: Array[int] = []
var _leg_base_rotations: Array[Quaternion] = []
var _leg_swing_amounts := Vector2.ZERO
var _spine_bone_index: int = -1
var _spine_pose_base_rotation := Quaternion.IDENTITY
var _upper_body_recoil_angle: float = 0.0
var _locomotion_forward_amount: float = 0.0
var _locomotion_right_amount: float = 0.0
var _locomotion_speed_ratio: float = 0.0
var _last_facing_dir: Vector3 = Vector3.ZERO
var _turn_anticipation_angle: float = 0.0
var _current_weapon_id: StringName = &"pistol"
var _action_scale: Vector3 = Vector3.ONE
var _stride_scale: Vector3 = Vector3.ONE
var _recoil_pitch: float = 0.0
var _recoil_yaw: float = 0.0
var _recoil_roll: float = 0.0
var _impact_pitch: float = 0.0
var _impact_roll: float = 0.0
var _weapon_kick: float = 0.0
var _weapon_side_kick: float = 0.0
var _fire_compression: float = 0.0
var _recoil_recovery_scale: float = 1.0
var _fire_serial: int = 0
var _upper_body_recoil_yaw: float = 0.0
var _upper_body_recoil_roll: float = 0.0
var _weapon_holder_base_position: Vector3 = Vector3.ZERO
var _authored_muzzle_positions: Dictionary = {}
var _weapon_switch_elapsed: float = WEAPON_SWITCH_DURATION
var _weapon_switch_amount: float = 0.0
var _locomotion_start_impulse: float = 0.0
var _locomotion_stop_impulse: float = 0.0
var _locomotion_impulse_direction := Vector2.ZERO
var _last_input_speed_ratio: float = 0.0
var _has_authored_motion: bool = false
var _authored_motion_state: int = AuthoredMotionState.HOLD
var _authored_motion_clip: StringName = &""
var _authored_motion_desired_moving: bool = false
var _last_footstep_phase: float = -1.0
var _footstep_serial: int = 0

func _ready() -> void:
	if not _build_asset_visual():
		_build_body()
		if show_visor:
			_build_visor()
		else:
			_build_eyes()
		if show_hat:
			_build_hat()
		if show_vest:
			_build_vest_stripes()
		_build_limbs()
	if _uses_hero_rig:
		_build_contact_shadow()
	_build_weapon_holder()
	# 默认手枪
	set_weapon_visual(&"pistol")

# ============================================================
#  身体 — 蓝色豆子形状（球体，稍微压扁）
# ============================================================
func _build_body() -> void:
	_body_mesh = MeshInstance3D.new()
	var mesh = SphereMesh.new()
	mesh.radius = 1.4
	mesh.height = 2.6
	mesh.radial_segments = 16
	mesh.rings = 12
	var mat = StandardMaterial3D.new()
	mat.albedo_color = body_color
	mat.roughness = 0.8
	mesh.material = mat
	_body_mesh.mesh = mesh
	_body_mesh.position = Vector3(0, 1.5, 0)
	add_child(_body_mesh)
	_body_color_meshes.append(_body_mesh)

## 运行时动态修改角色颜色
func set_body_color(color: Color) -> void:
	body_color = color
	_apply_rendered_body_color(color)

func _apply_rendered_body_color(color: Color) -> void:
	if _has_rendered_body_color and _rendered_body_color.is_equal_approx(color):
		return
	for mesh_instance in _body_color_meshes:
		_apply_body_color_to_mesh(mesh_instance, color)
	_rendered_body_color = color
	_has_rendered_body_color = true

func _build_asset_visual() -> bool:
	var asset_path := HERO_CHARACTER_SCENE_PATH
	var packed_scene = load(asset_path) as PackedScene
	if packed_scene == null:
		asset_path = LEGACY_CHARACTER_SCENE_PATH
		packed_scene = load(asset_path) as PackedScene
	if packed_scene == null:
		return false

	_asset_root = packed_scene.instantiate() as Node3D
	if _asset_root == null:
		return false
	_uses_hero_rig = asset_path == HERO_CHARACTER_SCENE_PATH
	_asset_root.name = "HeroCharacterAsset" if _uses_hero_rig else "BeanCharacterAsset"
	if _uses_hero_rig:
		# The authored Blender character faces +Z after glTF conversion; gameplay faces -Z.
		_asset_root.rotation_degrees.y = 180.0
	add_child(_asset_root)
	_animation_player = _find_animation_player(_asset_root)
	_skeleton = _find_skeleton(_asset_root)
	_configure_authored_motion_library()
	_cache_locomotion_bones()

	_create_marker("FaceVisor", Vector3(0, 1.58, -0.84))
	_create_marker("LeftHand", Vector3(-0.18, 1.13, -1.40))
	_create_marker("RightHand", Vector3(0.18, 0.98, -1.34))
	# These long-gun anchors mirror the authored support and trigger gloves.
	_create_marker("LeftHandGrip", Vector3(-0.09, 1.23, -2.02))
	_create_marker("RightHandGrip", Vector3(0.14, 1.23, -1.12))
	_create_marker("LeftFoot", Vector3(-0.39, 0.18, -0.16))
	_create_marker("RightFoot", Vector3(0.39, 0.18, -0.16))
	_cache_asset_meshes(_asset_root)
	set_body_color(body_color)
	return true

func _find_animation_player(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer:
		return node as AnimationPlayer
	for child in node.get_children():
		var found := _find_animation_player(child)
		if found != null:
			return found
	return null

func _find_skeleton(node: Node) -> Skeleton3D:
	if node is Skeleton3D:
		return node as Skeleton3D
	for child in node.get_children():
		var found := _find_skeleton(child)
		if found != null:
			return found
	return null

func _configure_authored_motion_library() -> void:
	_has_authored_motion = false
	if not _uses_hero_rig or _animation_player == null:
		return
	var weapon_suffixes := [&"pistol", &"smg", &"ak", &"sniper", &"shotgun", &"gatling"]
	for weapon_suffix in weapon_suffixes:
		for phase in [&"start", &"run", &"stop", &"hit"]:
			var clip := StringName("%s_%s" % [phase, weapon_suffix])
			if not _animation_player.has_animation(clip):
				return
			var animation := _animation_player.get_animation(clip)
			if animation != null:
				animation.loop_mode = Animation.LOOP_LINEAR if phase == &"run" else Animation.LOOP_NONE
	_has_authored_motion = true
	_animation_player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL

func _cache_locomotion_bones() -> void:
	_leg_bone_indices.clear()
	_leg_base_rotations.clear()
	if _skeleton == null:
		return
	for bone_name in [&"Thigh.L", &"Thigh.R"]:
		var bone_index := _skeleton.find_bone(bone_name)
		if bone_index < 0:
			continue
		_leg_bone_indices.append(bone_index)
		_leg_base_rotations.append(_skeleton.get_bone_pose_rotation(bone_index))
	_spine_bone_index = _skeleton.find_bone(&"Spine")
	_cache_weapon_pose_recoil_base()

func _cache_weapon_pose_recoil_base() -> void:
	if _skeleton == null or _spine_bone_index < 0:
		return
	_spine_pose_base_rotation = _skeleton.get_bone_pose_rotation(_spine_bone_index)

func _build_contact_shadow() -> void:
	_contact_shadow = MeshInstance3D.new()
	_contact_shadow.name = "ContactShadow"
	var shadow_mesh := CylinderMesh.new()
	shadow_mesh.top_radius = 0.98
	shadow_mesh.bottom_radius = 0.98
	shadow_mesh.height = 0.016
	shadow_mesh.radial_segments = 32
	_contact_shadow.mesh = shadow_mesh
	_contact_shadow.scale = Vector3(1.0, 1.0, 0.70)
	_contact_shadow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_contact_shadow_material = StandardMaterial3D.new()
	_contact_shadow_material.albedo_color = Color(0.07, 0.045, 0.11, 0.30)
	_contact_shadow_material.roughness = 1.0
	_contact_shadow_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_contact_shadow_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_contact_shadow.material_override = _contact_shadow_material
	add_child(_contact_shadow)
	_contact_shadow.top_level = true
	_update_contact_shadow()

func _runtime_visual_scale() -> Vector3:
	return HERO_RUNTIME_SCALE if _uses_hero_rig else Vector3.ONE

func _create_marker(name: String, pos: Vector3) -> Node3D:
	var marker = Node3D.new()
	marker.name = name
	marker.position = pos
	add_child(marker)
	return marker

func _cache_asset_meshes(node: Node) -> void:
	for child in node.get_children():
		if child is MeshInstance3D:
			var mesh_instance := child as MeshInstance3D
			var lower_name = String(mesh_instance.name).to_lower()
			_apply_asset_material_profile(mesh_instance)
			if _body_mesh == null and lower_name.contains("body"):
				_body_mesh = mesh_instance
			if _mesh_has_suit_material(mesh_instance):
				_body_color_meshes.append(mesh_instance)
			elif lower_name.contains("body") or lower_name.contains("helmet") or lower_name.contains("leg"):
				_body_color_meshes.append(mesh_instance)
			elif lower_name.contains("belly") or lower_name.contains("hand"):
				_body_color_meshes.append(mesh_instance)
		_cache_asset_meshes(child)

func _apply_asset_material_profile(mesh_instance: MeshInstance3D) -> void:
	if mesh_instance.mesh == null:
		return
	for surface_index in range(mesh_instance.mesh.get_surface_count()):
		var source_material := mesh_instance.mesh.surface_get_material(surface_index)
		if source_material == null:
			continue
		var material_name := String(source_material.resource_name).to_lower()
		if not (
			material_name.contains("hero_suit")
			or material_name.contains("hero_rubber")
			or material_name.contains("hero_face")
			or material_name.contains("hero_eye")
		):
			continue
		var runtime_material := mesh_instance.get_surface_override_material(surface_index) as StandardMaterial3D
		if runtime_material == null:
			runtime_material = (
				(source_material as StandardMaterial3D).duplicate() as StandardMaterial3D
				if source_material is StandardMaterial3D
				else StandardMaterial3D.new()
			)
			mesh_instance.set_surface_override_material(surface_index, runtime_material)
		if material_name.contains("hero_suit"):
			_configure_suit_material(runtime_material, body_color)
			if not _suit_materials.has(runtime_material):
				_suit_materials.append(runtime_material)
		elif material_name.contains("hero_rubber"):
			_configure_rubber_material(runtime_material)
			if not _rubber_materials.has(runtime_material):
				_rubber_materials.append(runtime_material)
		elif material_name.contains("hero_face"):
			_configure_face_panel_material(runtime_material)
			if not _face_panel_materials.has(runtime_material):
				_face_panel_materials.append(runtime_material)
		elif material_name.contains("hero_eye"):
			_configure_eye_material(runtime_material)
			if not _eye_materials.has(runtime_material):
				_eye_materials.append(runtime_material)

func _configure_suit_material(material: StandardMaterial3D, color: Color) -> void:
	material.albedo_color = color
	material.roughness = SUIT_ROUGHNESS
	material.metallic = 0.0
	material.metallic_specular = 0.29
	material.emission_enabled = false

func _configure_rubber_material(material: StandardMaterial3D) -> void:
	material.albedo_color = RUBBER_COLOR
	material.roughness = 0.66
	material.metallic = 0.0
	material.metallic_specular = 0.16
	material.emission_enabled = false

func _configure_face_panel_material(material: StandardMaterial3D) -> void:
	material.albedo_color = FACE_PANEL_COLOR
	material.roughness = 0.40
	material.metallic = 0.0
	material.metallic_specular = 0.30
	material.emission_enabled = true
	material.emission = Color("#261934")
	material.emission_energy_multiplier = 0.16

func _configure_eye_material(material: StandardMaterial3D) -> void:
	material.albedo_color = EYE_COLOR
	material.roughness = 0.34
	material.metallic = 0.0
	material.metallic_specular = 0.18
	material.emission_enabled = true
	material.emission = Color("#ffb52f")
	material.emission_energy_multiplier = 1.75

func _mesh_has_suit_material(mesh_instance: MeshInstance3D) -> bool:
	if mesh_instance.mesh == null:
		return false
	for surface_index in range(mesh_instance.mesh.get_surface_count()):
		var source_material := mesh_instance.mesh.surface_get_material(surface_index)
		if source_material != null and String(source_material.resource_name).to_lower().contains("hero_suit"):
			return true
	return false

func _apply_body_color_to_mesh(mesh_instance: MeshInstance3D, color: Color) -> void:
	if mesh_instance == null:
		return
	var tinted_suit_surface := false
	if mesh_instance.mesh != null:
		for surface_index in range(mesh_instance.mesh.get_surface_count()):
			var source_material := mesh_instance.mesh.surface_get_material(surface_index)
			if source_material == null or not String(source_material.resource_name).to_lower().contains("hero_suit"):
				continue
			var surface_material := mesh_instance.get_surface_override_material(surface_index) as StandardMaterial3D
			if surface_material == null:
				if source_material is StandardMaterial3D:
					surface_material = (source_material as StandardMaterial3D).duplicate() as StandardMaterial3D
				else:
					surface_material = StandardMaterial3D.new()
					surface_material.roughness = 0.82
				mesh_instance.set_surface_override_material(surface_index, surface_material)
			_configure_suit_material(surface_material, color)
			if not _suit_materials.has(surface_material):
				_suit_materials.append(surface_material)
			tinted_suit_surface = true
	if tinted_suit_surface:
		return
	var mat = mesh_instance.material_override as StandardMaterial3D
	if mat == null:
		mat = StandardMaterial3D.new()
		mat.roughness = 0.82
		mat.metallic_specular = 0.18
		mesh_instance.material_override = mat
	mat.albedo_color = color

func _build_visor() -> void:
	var visor = Node3D.new()
	visor.name = "FaceVisor"
	visor.position = Vector3(0, 1.92, -1.12)
	add_child(visor)

	var rim = MeshInstance3D.new()
	rim.name = "Rim"
	var rim_mesh = SphereMesh.new()
	rim_mesh.radius = 0.54
	rim_mesh.height = 0.42
	rim_mesh.radial_segments = 16
	rim_mesh.rings = 8
	var rim_mat = StandardMaterial3D.new()
	rim_mat.albedo_color = Color("#1e2a3b")
	rim_mat.roughness = 0.72
	rim_mesh.material = rim_mat
	rim.mesh = rim_mesh
	rim.scale = Vector3(1.36, 0.72, 0.18)
	visor.add_child(rim)

	var glass = MeshInstance3D.new()
	glass.name = "Glass"
	var glass_mesh = SphereMesh.new()
	glass_mesh.radius = 0.46
	glass_mesh.height = 0.34
	glass_mesh.radial_segments = 16
	glass_mesh.rings = 8
	var glass_mat = StandardMaterial3D.new()
	glass_mat.albedo_color = Color("#b9efff")
	glass_mat.roughness = 0.32
	glass_mat.metallic_specular = 0.35
	glass_mesh.material = glass_mat
	glass.mesh = glass_mesh
	glass.position = Vector3(0, 0.01, -0.08)
	glass.scale = Vector3(1.20, 0.58, 0.12)
	visor.add_child(glass)

	var highlight = MeshInstance3D.new()
	highlight.name = "Highlight"
	var highlight_mesh = SphereMesh.new()
	highlight_mesh.radius = 0.12
	highlight_mesh.height = 0.08
	highlight_mesh.radial_segments = 10
	highlight_mesh.rings = 4
	var highlight_mat = StandardMaterial3D.new()
	highlight_mat.albedo_color = Color(1.0, 1.0, 1.0, 0.78)
	highlight_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	highlight_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	highlight_mesh.material = highlight_mat
	highlight.mesh = highlight_mesh
	highlight.position = Vector3(-0.23, 0.09, -0.15)
	highlight.scale = Vector3(1.6, 0.55, 0.18)
	visor.add_child(highlight)

# ============================================================
#  眼睛 — 白底黑瞳 + 愤怒角度
# ============================================================
func _build_eyes() -> void:
	var eye_y = 2.1
	var eye_z = -1.1
	var eye_spacing = 0.5

	for side in [-1, 1]:
		# 白色眼球
		var eye = MeshInstance3D.new()
		var eye_mesh = SphereMesh.new()
		eye_mesh.radius = 0.28
		eye_mesh.height = 0.5
		var eye_mat = StandardMaterial3D.new()
		eye_mat.albedo_color = Color.WHITE
		eye_mesh.material = eye_mat
		eye.mesh = eye_mesh
		eye.position = Vector3(side * eye_spacing, eye_y, eye_z)
		add_child(eye)

		# 黑色瞳孔
		var pupil = MeshInstance3D.new()
		var pupil_mesh = SphereMesh.new()
		pupil_mesh.radius = 0.14
		pupil_mesh.height = 0.28
		var pupil_mat = StandardMaterial3D.new()
		pupil_mat.albedo_color = Color.BLACK
		pupil_mesh.material = pupil_mat
		pupil.mesh = pupil_mesh
		pupil.position = Vector3(side * eye_spacing, eye_y, eye_z - 0.18)
		add_child(pupil)

		# 愤怒眉毛（倾斜的小方块）
		var brow = MeshInstance3D.new()
		var brow_mesh = BoxMesh.new()
		brow_mesh.size = Vector3(0.4, 0.08, 0.08)
		var brow_mat = StandardMaterial3D.new()
		brow_mat.albedo_color = Color.BLACK
		brow_mesh.material = brow_mat
		brow.mesh = brow_mesh
		brow.position = Vector3(side * eye_spacing, eye_y + 0.35, eye_z - 0.1)
		# 内高外低的愤怒角度
		brow.rotation_degrees.z = side * 20.0
		add_child(brow)

# ============================================================
#  帽子 — 黑色礼帽（帽冠 + 帽檐）
# ============================================================
func _build_hat() -> void:
	var hat = Node3D.new()
	hat.name = "Hat"
	hat.position = Vector3(0, 2.7, 0)
	add_child(hat)

	var hat_mat = StandardMaterial3D.new()
	hat_mat.albedo_color = Color(0.1, 0.1, 0.1)
	hat_mat.roughness = 0.6

	# 帽冠
	var crown = MeshInstance3D.new()
	var crown_mesh = CylinderMesh.new()
	crown_mesh.top_radius = 0.55
	crown_mesh.bottom_radius = 0.65
	crown_mesh.height = 0.7
	crown_mesh.material = hat_mat
	crown.mesh = crown_mesh
	crown.position = Vector3(0, 0.35, 0)
	hat.add_child(crown)

	# 帽檐
	var brim = MeshInstance3D.new()
	var brim_mesh = CylinderMesh.new()
	brim_mesh.top_radius = 1.0
	brim_mesh.bottom_radius = 1.0
	brim_mesh.height = 0.08
	brim_mesh.material = hat_mat
	brim.mesh = brim_mesh
	brim.position = Vector3(0, 0, 0)
	hat.add_child(brim)

# ============================================================
#  马甲 — 黑白竖条纹（简化：用几条黑色长方体贴在身体上）
# ============================================================
func _build_vest_stripes() -> void:
	var stripe_mat = StandardMaterial3D.new()
	stripe_mat.albedo_color = Color(0.15, 0.15, 0.15)

	for i in range(-2, 3):
		var stripe = MeshInstance3D.new()
		var s_mesh = BoxMesh.new()
		s_mesh.size = Vector3(0.08, 1.2, 0.05)
		s_mesh.material = stripe_mat
		stripe.mesh = s_mesh
		# 贴在身体前面，均匀分布
		var x_pos = i * 0.3
		stripe.position = Vector3(x_pos, 1.3, -1.35)
		add_child(stripe)

func _build_limbs() -> void:
	for side in [-1, 1]:
		var hand = MeshInstance3D.new()
		hand.name = "LeftHand" if side < 0 else "RightHand"
		var hand_mesh = SphereMesh.new()
		hand_mesh.radius = 0.32
		hand_mesh.height = 0.58
		hand_mesh.radial_segments = 12
		var hand_mat = StandardMaterial3D.new()
		hand_mat.albedo_color = body_color
		hand_mat.roughness = 0.82
		hand_mesh.material = hand_mat
		hand.mesh = hand_mesh
		hand.position = Vector3(side * 1.05, 1.25, -0.7)
		add_child(hand)
		_body_color_meshes.append(hand)

	for side in [-1, 1]:
		var foot = MeshInstance3D.new()
		foot.name = "LeftFoot" if side < 0 else "RightFoot"
		var foot_mesh = SphereMesh.new()
		foot_mesh.radius = 0.34
		foot_mesh.height = 0.34
		foot_mesh.radial_segments = 12
		var foot_mat = StandardMaterial3D.new()
		foot_mat.albedo_color = Color(0.07, 0.08, 0.10)
		foot_mat.roughness = 0.8
		foot_mesh.material = foot_mat
		foot.mesh = foot_mesh
		foot.scale = Vector3(1.2, 0.45, 0.85)
		foot.position = Vector3(side * 0.55, 0.24, -0.35)
		add_child(foot)

# ============================================================
#  枪械模型容器
# ============================================================
func _build_weapon_holder() -> void:
	_weapon_holder = Node3D.new()
	_weapon_holder.name = "WeaponHolder"
	_weapon_holder.position = _weapon_holder_position_for(&"pistol")
	_weapon_holder.scale = Vector3.ONE
	add_child(_weapon_holder)
	_weapon_holder_base_position = _weapon_holder.position

## 切换枪械可视模型
func set_weapon_visual(weapon_id: StringName) -> void:
	var should_settle := _uses_hero_rig and weapon_id != _current_weapon_id
	_current_weapon_id = weapon_id
	if should_settle:
		_clear_fire_pose()
	_set_weapon_pose_visual(weapon_id)
	_weapon_holder_base_position = _weapon_holder_position_for(weapon_id)
	_weapon_holder.position = _weapon_holder_base_position
	if should_settle:
		_weapon_switch_elapsed = 0.0
		_weapon_switch_amount = 0.0
	# 清除旧模型
	for child in _weapon_holder.get_children():
		_weapon_holder.remove_child(child)
		child.queue_free()

	var built_asset := _build_weapon_asset_visual(weapon_id)
	if built_asset:
		return

	var gun_mat = StandardMaterial3D.new()
	gun_mat.albedo_color = _weapon_color(weapon_id)
	gun_mat.roughness = 0.5

	match weapon_id:
		&"pistol":
			_build_gun_parts(gun_mat, [
				{"size": Vector3(0.2, 0.35, 0.15), "pos": Vector3(0, -0.15, 0)},   # 握把
				{"size": Vector3(0.2, 0.15, 0.5), "pos": Vector3(0, 0.05, -0.25)},  # 枪身
			])
		&"smg":
			_build_gun_parts(gun_mat, [
				{"size": Vector3(0.2, 0.35, 0.15), "pos": Vector3(0, -0.15, 0)},   # 握把
				{"size": Vector3(0.2, 0.18, 0.8), "pos": Vector3(0, 0.05, -0.4)},  # 枪身
				{"size": Vector3(0.12, 0.3, 0.08), "pos": Vector3(0, -0.2, -0.3)}, # 弹匣
			])
		&"ak_rifle":
			_build_gun_parts(gun_mat, [
				{"size": Vector3(0.2, 0.35, 0.15), "pos": Vector3(0, -0.15, 0)},   # 握把
				{"size": Vector3(0.2, 0.2, 1.3), "pos": Vector3(0, 0.05, -0.6)},   # 枪身
				{"size": Vector3(0.12, 0.4, 0.08), "pos": Vector3(0, -0.25, -0.4)},# 弹匣（AK弯曲感）
				{"size": Vector3(0.18, 0.15, 0.4), "pos": Vector3(0, 0.0, 0.35)},  # 枪托
			])
		&"sniper":
			_build_gun_parts(gun_mat, [
				{"size": Vector3(0.18, 0.3, 0.15), "pos": Vector3(0, -0.15, 0)},   # 握把
				{"size": Vector3(0.15, 0.15, 2.0), "pos": Vector3(0, 0.05, -1.0)}, # 超长枪管
				{"size": Vector3(0.12, 0.2, 0.08), "pos": Vector3(0, -0.15, -0.3)},# 弹匣
				{"size": Vector3(0.2, 0.18, 0.5), "pos": Vector3(0, 0.0, 0.4)},    # 枪托
				{"size": Vector3(0.1, 0.15, 0.25), "pos": Vector3(0, 0.2, -0.6)},  #瞄准镜
			])
		&"gatling":
			_build_gun_parts(gun_mat, [
				{"size": Vector3(0.38, 0.30, 0.82), "pos": Vector3(0, 0.05, -0.38)},
				{"size": Vector3(0.30, 0.30, 0.72), "pos": Vector3(0, 0.05, -1.08)},
				{"size": Vector3(0.20, 0.42, 0.18), "pos": Vector3(0, -0.22, -0.24)},
			])
		&"shotgun":
			_build_gun_parts(gun_mat, [
				{"size": Vector3(0.30, 0.25, 1.28), "pos": Vector3(0, 0.05, -0.62)},
				{"size": Vector3(0.35, 0.30, 0.46), "pos": Vector3(0, 0.02, 0.30)},
				{"size": Vector3(0.32, 0.28, 0.42), "pos": Vector3(0, 0.01, -0.88)},
			])

	_build_weapon_readability_proxy(weapon_id)

func _weapon_holder_position_for(weapon_id: StringName) -> Vector3:
	if _uses_hero_rig:
		match weapon_id:
			&"pistol":
				return Vector3(0.0, 1.39, -0.72)
			&"smg":
				return Vector3(-0.12, 1.35, -0.83)
			&"ak_rifle":
				return Vector3(-0.18, 1.34, -0.92)
			&"sniper":
				return Vector3(-0.18, 1.35, -0.96)
			&"gatling":
				return Vector3(-0.10, 1.27, -0.88)
			&"shotgun":
				return Vector3(-0.14, 1.31, -0.90)
	match weapon_id:
		&"pistol":
			return Vector3(0.0, 1.18, -1.24)
		&"smg":
			return Vector3(0.0, 1.23, -1.22)
		&"ak_rifle":
			return Vector3(0.0, 1.28, -1.20)
		&"sniper":
			return Vector3(0.0, 1.31, -1.20)
		&"gatling":
			return Vector3(0.0, 1.28, -1.20)
		&"shotgun":
			return Vector3(0.0, 1.28, -1.20)
	return Vector3(0.0, 1.18, -1.24)

func _set_weapon_pose_visual(weapon_id: StringName) -> void:
	if _asset_root == null:
		return
	if _uses_hero_rig and _animation_player != null:
		_authored_motion_state = AuthoredMotionState.HOLD
		_active_weapon_pose = _weapon_pose_animation_for(weapon_id)
		if _animation_player.has_animation(_active_weapon_pose):
			_animation_player.play(_active_weapon_pose)
			_animation_player.seek(0.0, true)
			_animation_player.pause()
			_authored_motion_clip = _active_weapon_pose
			_cache_weapon_pose_recoil_base()
			return
	var wants_pistol := weapon_id == &"pistol"
	_set_weapon_pose_mesh_visibility(_asset_root, wants_pistol)

func _weapon_pose_animation_for(weapon_id: StringName) -> StringName:
	match weapon_id:
		&"smg":
			return &"hold_smg"
		&"ak_rifle":
			return &"hold_ak"
		&"sniper":
			return &"hold_sniper"
		&"gatling":
			return &"hold_gatling"
		&"shotgun":
			return &"hold_shotgun"
		_:
			return &"hold_pistol"

func _weapon_motion_suffix(weapon_id: StringName) -> StringName:
	if weapon_id == &"ak_rifle":
		return &"ak"
	if weapon_id in [&"pistol", &"smg", &"sniper", &"shotgun", &"gatling"]:
		return weapon_id
	return &"pistol"

func _authored_motion_animation_for(phase: StringName) -> StringName:
	return StringName("%s_%s" % [phase, _weapon_motion_suffix(_current_weapon_id)])

func _play_authored_motion(phase: StringName, blend: float = AUTHORED_MOTION_BLEND, restart: bool = true) -> bool:
	if not _has_authored_motion or _animation_player == null:
		return false
	var clip := _authored_motion_animation_for(phase)
	if not _animation_player.has_animation(clip):
		return false
	if restart or _authored_motion_clip != clip or not _animation_player.is_playing():
		_animation_player.play(clip, blend)
		if restart:
			_animation_player.seek(0.0, true)
	_authored_motion_clip = clip
	return true

func _begin_authored_start() -> void:
	if not _play_authored_motion(&"start"):
		return
	_authored_motion_state = AuthoredMotionState.START

func _begin_authored_run(blend: float = AUTHORED_MOTION_BLEND) -> void:
	if not _play_authored_motion(&"run", blend):
		return
	_authored_motion_state = AuthoredMotionState.RUN
	_last_footstep_phase = -1.0

func _begin_authored_stop() -> void:
	if not _play_authored_motion(&"stop"):
		return
	_authored_motion_state = AuthoredMotionState.STOP

func _begin_authored_hit() -> void:
	if not _play_authored_motion(&"hit", AUTHORED_HIT_BLEND):
		return
	_authored_motion_state = AuthoredMotionState.HIT

func _settle_authored_hold(blend: float = AUTHORED_MOTION_BLEND) -> void:
	if _animation_player == null:
		return
	_active_weapon_pose = _weapon_pose_animation_for(_current_weapon_id)
	if _animation_player.has_animation(_active_weapon_pose):
		_animation_player.play(_active_weapon_pose, blend)
		_animation_player.seek(0.0, true)
		_animation_player.pause()
		_authored_motion_clip = _active_weapon_pose
		_cache_weapon_pose_recoil_base()
	_authored_motion_state = AuthoredMotionState.HOLD
	_last_footstep_phase = -1.0

func _update_authored_motion_input(speed_ratio: float) -> void:
	if not _has_authored_motion:
		return
	_authored_motion_desired_moving = speed_ratio > 0.16
	if _authored_motion_state == AuthoredMotionState.HIT:
		return
	match _authored_motion_state:
		AuthoredMotionState.HOLD:
			if _authored_motion_desired_moving:
				_begin_authored_start()
		AuthoredMotionState.START, AuthoredMotionState.RUN:
			if not _authored_motion_desired_moving:
				_begin_authored_stop()
		AuthoredMotionState.STOP:
			if _authored_motion_desired_moving:
				_begin_authored_start()

func _authored_clip_finished(delta: float) -> bool:
	if _animation_player == null or _authored_motion_clip.is_empty():
		return true
	if not _animation_player.is_playing():
		return true
	var animation := _animation_player.get_animation(_authored_motion_clip)
	if animation == null:
		return true
	return _animation_player.current_animation_position >= animation.length - maxf(delta * 1.5, 0.018)

func _update_authored_motion_playback(delta: float) -> void:
	if not _has_authored_motion or _animation_player == null:
		return
	if _authored_motion_state == AuthoredMotionState.RUN:
		_animation_player.speed_scale = lerpf(0.78, 1.18, _locomotion_speed_ratio)
	else:
		_animation_player.speed_scale = 1.0
	if not _authored_clip_finished(delta):
		return
	match _authored_motion_state:
		AuthoredMotionState.START:
			if _authored_motion_desired_moving:
				_begin_authored_run(0.025)
			else:
				_begin_authored_stop()
		AuthoredMotionState.STOP:
			if _authored_motion_desired_moving:
				_begin_authored_start()
			else:
				_settle_authored_hold(0.04)
		AuthoredMotionState.HIT:
			if _authored_motion_desired_moving:
				_begin_authored_run(0.04)
			else:
				_settle_authored_hold(0.04)

func _update_authored_footsteps() -> void:
	if not _has_authored_motion or _animation_player == null or _authored_motion_state != AuthoredMotionState.RUN:
		_last_footstep_phase = -1.0
		return
	var animation := _animation_player.get_animation(_authored_motion_clip)
	if animation == null or animation.length <= 0.001:
		return
	var phase := fposmod(_animation_player.current_animation_position, animation.length) / animation.length
	if _last_footstep_phase < 0.0:
		_last_footstep_phase = phase
		return
	var crossed_midpoint := _last_footstep_phase < 0.5 and phase >= 0.5
	var wrapped_cycle := phase < _last_footstep_phase
	if crossed_midpoint or wrapped_cycle:
		_play_footstep_sfx()
	_last_footstep_phase = phase

func _play_footstep_sfx() -> void:
	_footstep_serial += 1
	if RuntimeGlobals.runtime_audio_disabled() or not is_inside_tree() or FOOTSTEP_STREAMS.is_empty():
		return
	var scene_root := RuntimeGlobals.active_scene(get_tree())
	if scene_root == null:
		return
	var sfx := AudioStreamPlayer3D.new()
	sfx.stream = FOOTSTEP_STREAMS[_footstep_serial % FOOTSTEP_STREAMS.size()]
	sfx.volume_db = -18.5 if _current_weapon_id in [&"gatling", &"shotgun", &"sniper"] else -20.5
	sfx.pitch_scale = (0.965 if _footstep_serial % 2 == 0 else 1.035) + randf_range(-0.012, 0.012)
	sfx.unit_size = 16.0
	sfx.max_distance = 140.0
	scene_root.add_child(sfx)
	sfx.global_position = global_position
	sfx.play()
	sfx.finished.connect(sfx.queue_free)

func _set_weapon_pose_mesh_visibility(node: Node, wants_pistol: bool) -> void:
	if node is MeshInstance3D:
		var lower_name := String(node.name).to_lower()
		if lower_name.contains("posepistol"):
			(node as MeshInstance3D).visible = wants_pistol
		elif lower_name.contains("poselong"):
			(node as MeshInstance3D).visible = not wants_pistol
	for child in node.get_children():
		_set_weapon_pose_mesh_visibility(child, wants_pistol)

func _build_weapon_asset_visual(weapon_id: StringName) -> bool:
	var model_path := _weapon_model_path(weapon_id)
	if model_path.is_empty():
		return false

	var packed_scene = load(model_path) as PackedScene
	if packed_scene == null:
		return false

	var weapon_asset = packed_scene.instantiate() as Node3D
	if weapon_asset == null:
		return false

	weapon_asset.name = "WeaponAsset"
	weapon_asset.set_meta("weapon_id", String(weapon_id))
	weapon_asset.position = Vector3.ZERO if _uses_hero_rig else Vector3(0.0, 0.04, -0.10)
	weapon_asset.rotation_degrees.y = 180.0
	weapon_asset.scale = Vector3.ONE * _weapon_asset_scale(weapon_id)
	_weapon_holder.add_child(weapon_asset)
	_cache_authored_muzzle_position(weapon_id, weapon_asset)
	return true

func _cache_authored_muzzle_position(weapon_id: StringName, weapon_asset: Node3D) -> void:
	var points: Array[Vector3] = []
	_collect_authored_muzzle_points(weapon_asset, points)
	if points.is_empty():
		return
	var center := Vector3.ZERO
	for point in points:
		center += point
	_authored_muzzle_positions[weapon_id] = center / float(points.size())

func _collect_authored_muzzle_points(node: Node, points: Array[Vector3]) -> void:
	if node is Node3D and String(node.name).to_lower().contains("muzzleglow"):
		points.append(to_local((node as Node3D).global_position))
	for child in node.get_children():
		_collect_authored_muzzle_points(child, points)

func _build_weapon_readability_proxy(weapon_id: StringName) -> void:
	var profile := _weapon_readability_profile(weapon_id)
	var accent_color := _weapon_color(weapon_id)
	var outline_color := Color("#141824")

	var proxy := Node3D.new()
	proxy.name = "WeaponReadability"
	_weapon_holder.add_child(proxy)

	var outline := Node3D.new()
	outline.name = "WeaponReadabilityOutline"
	proxy.add_child(outline)

	var accent := Node3D.new()
	accent.name = "WeaponReadabilityAccent"
	proxy.add_child(accent)

	var length := float(profile["silhouette_length"])
	var width := float(profile["silhouette_width"])
	var height := float(profile["silhouette_height"])
	var body_z := -length * 0.42
	var outline_mat := _weapon_readability_material(outline_color, outline_color, 0.0)
	var accent_mat := _weapon_readability_material(accent_color, accent_color, 1.1)
	var highlight_mat := _weapon_readability_material(accent_color.lerp(Color.WHITE, 0.38), accent_color, 1.7)

	_add_weapon_proxy_box(outline, "BodyOutline", Vector3(0.0, -0.025, body_z), Vector3(width + 0.12, height + 0.08, length + 0.16), outline_mat)
	_add_weapon_proxy_box(accent, "BodyAccent", Vector3(0.0, 0.035, body_z), Vector3(width, height, length), accent_mat)
	_add_weapon_proxy_box(accent, "TopHighlight", Vector3(0.0, height * 0.45, body_z - length * 0.06), Vector3(width * 0.64, height * 0.22, length * 0.62), highlight_mat)

	var grip_z := -length * 0.10
	_add_weapon_proxy_box(outline, "GripOutline", Vector3(0.0, -height * 0.78, grip_z), Vector3(width * 0.86, height * 1.25, 0.24), outline_mat)
	_add_weapon_proxy_box(accent, "GripAccent", Vector3(0.0, -height * 0.70, grip_z), Vector3(width * 0.60, height * 0.92, 0.18), _weapon_readability_material(Color("#232b38"), Color("#232b38"), 0.0))

	if bool(profile.get("has_magazine", false)):
		var mag_z := -length * 0.40
		_add_weapon_proxy_box(outline, "MagazineOutline", Vector3(0.0, -height * 0.92, mag_z), Vector3(width * 0.76, height * 1.12, 0.22), outline_mat)
		_add_weapon_proxy_box(accent, "MagazineAccent", Vector3(0.0, -height * 0.84, mag_z), Vector3(width * 0.50, height * 0.82, 0.16), _weapon_readability_material(Color("#3a4657"), Color("#3a4657"), 0.0))

	if bool(profile.get("has_stock", false)):
		_add_weapon_proxy_box(outline, "StockOutline", Vector3(0.0, -0.015, 0.18), Vector3(width * 1.28, height * 0.92, 0.38), outline_mat)
		_add_weapon_proxy_box(accent, "StockAccent", Vector3(0.0, 0.035, 0.18), Vector3(width * 0.92, height * 0.64, 0.30), _weapon_readability_material(Color("#242b35"), Color("#242b35"), 0.0))

	if bool(profile.get("has_scope", false)):
		var scope_z := -length * 0.46
		_add_weapon_proxy_box(outline, "ScopeOutline", Vector3(0.0, height * 1.02, scope_z), Vector3(width * 1.02, height * 0.66, 0.56), outline_mat)
		_add_weapon_proxy_box(accent, "ScopeAccent", Vector3(0.0, height * 1.10, scope_z), Vector3(width * 0.70, height * 0.42, 0.42), _weapon_readability_material(Color("#d9f6ff"), accent_color, 0.9))

func _add_weapon_proxy_box(parent: Node3D, name: String, pos: Vector3, size: Vector3, mat: StandardMaterial3D) -> MeshInstance3D:
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = name
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh_instance.mesh = mesh
	mesh_instance.position = pos
	mesh_instance.material_override = mat
	parent.add_child(mesh_instance)
	return mesh_instance

func _weapon_readability_material(albedo: Color, emission: Color, emission_energy: float) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = albedo
	mat.roughness = 0.78
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.emission_enabled = emission_energy > 0.0
	mat.emission = emission
	mat.emission_energy_multiplier = emission_energy
	return mat

func _weapon_readability_profile(weapon_id: StringName) -> Dictionary:
	match weapon_id:
		&"smg":
			return {
				"silhouette_length": 1.05,
				"silhouette_width": 0.32,
				"silhouette_height": 0.24,
				"has_magazine": true,
				"has_stock": false,
				"has_scope": false,
			}
		&"ak_rifle":
			return {
				"silhouette_length": 1.48,
				"silhouette_width": 0.34,
				"silhouette_height": 0.25,
				"has_magazine": true,
				"has_stock": true,
				"has_scope": false,
			}
		&"sniper":
			return {
				"silhouette_length": 1.95,
				"silhouette_width": 0.25,
				"silhouette_height": 0.20,
				"has_magazine": false,
				"has_stock": true,
				"has_scope": true,
			}
		&"gatling":
			return {
				"silhouette_length": 1.72,
				"silhouette_width": 0.48,
				"silhouette_height": 0.34,
				"has_magazine": true,
				"has_stock": true,
				"has_scope": false,
			}
		&"shotgun":
			return {
				"silhouette_length": 1.78,
				"silhouette_width": 0.34,
				"silhouette_height": 0.27,
				"has_magazine": false,
				"has_stock": true,
				"has_scope": false,
			}
		_:
			return {
				"silhouette_length": 0.78,
				"silhouette_width": 0.30,
				"silhouette_height": 0.24,
				"has_magazine": false,
				"has_stock": false,
				"has_scope": false,
			}

func get_weapon_readability_debug() -> Dictionary:
	var profile := _weapon_readability_profile(_current_weapon_id)
	var proxy := _weapon_holder.get_node_or_null("WeaponReadability") if _weapon_holder else null
	var asset := _weapon_holder.get_node_or_null("WeaponAsset") if _weapon_holder else null
	return {
		"weapon_id": String(_current_weapon_id),
		"holder_position": _weapon_holder.position if _weapon_holder else Vector3.ZERO,
		"holder_base_position": _weapon_holder_base_position,
		"holder_scale": _weapon_holder.scale.x if _weapon_holder else 0.0,
		"silhouette_length": float(profile["silhouette_length"]),
		"silhouette_width": float(profile["silhouette_width"]),
		"has_asset": asset != null,
		"uses_proxy": proxy != null,
		"asset_scale": _weapon_asset_scale(_current_weapon_id),
		"asset_rotation_y": asset.rotation_degrees.y if asset else 0.0,
		"muzzle_anchor_source": "authored_model" if _authored_muzzle_positions.has(_current_weapon_id) else "fallback_profile",
		"weapon_pose": String(_active_weapon_pose) if _uses_hero_rig else ("pistol" if _current_weapon_id == &"pistol" else "long"),
		"uses_hero_rig": _uses_hero_rig,
		"has_magazine": bool(profile.get("has_magazine", false)),
		"has_stock": bool(profile.get("has_stock", false)),
		"has_scope": bool(profile.get("has_scope", false)),
		"accent_color": _weapon_color(_current_weapon_id),
	}

func _weapon_model_path(weapon_id: StringName) -> String:
	match weapon_id:
		&"pistol":
			return WEAPON_MODEL_ROOT + "pistol.glb"
		&"smg":
			return WEAPON_MODEL_ROOT + "smg.glb"
		&"ak_rifle":
			return WEAPON_MODEL_ROOT + "ak_rifle.glb"
		&"sniper":
			return WEAPON_MODEL_ROOT + "sniper.glb"
		&"gatling":
			return WEAPON_MODEL_ROOT + "gatling.glb"
		&"shotgun":
			return WEAPON_MODEL_ROOT + "shotgun.glb"
		_:
			return ""

func _weapon_asset_scale(weapon_id: StringName) -> float:
	if _uses_hero_rig:
		match weapon_id:
			&"pistol":
				return 1.0
			&"smg":
				return 0.84
			&"ak_rifle":
				return 0.74
			&"sniper":
				return 0.68
			&"gatling":
				return 0.66
			&"shotgun":
				return 0.72
	match weapon_id:
		&"pistol":
			return 1.34
		&"smg":
			return 1.14
		&"ak_rifle":
			return 1.00
		&"sniper":
			return 0.92
		&"gatling":
			return 0.90
		&"shotgun":
			return 0.96
		_:
			return 1.0

func get_weapon_muzzle_local_position(weapon_id: StringName = _current_weapon_id) -> Vector3:
	if _authored_muzzle_positions.has(weapon_id):
		return (_authored_muzzle_positions[weapon_id] as Vector3) * _runtime_visual_scale()
	var muzzle_position := Vector3.ZERO
	if _uses_hero_rig:
		match weapon_id:
			&"smg":
				muzzle_position = Vector3(-0.12, 1.39, -1.91)
			&"ak_rifle":
				muzzle_position = Vector3(-0.18, 1.38, -2.24)
			&"sniper":
				muzzle_position = Vector3(-0.18, 1.39, -2.31)
			&"gatling":
				muzzle_position = Vector3(-0.10, 1.32, -1.97)
			&"shotgun":
				muzzle_position = Vector3(-0.14, 1.35, -2.07)
			_:
				muzzle_position = Vector3(0.0, 1.43, -1.69)
	else:
		match weapon_id:
			&"smg":
				muzzle_position = Vector3(0.0, 1.28, -2.78)
			&"ak_rifle":
				muzzle_position = Vector3(0.0, 1.26, -3.08)
			&"sniper":
				muzzle_position = Vector3(0.0, 1.24, -3.13)
			&"gatling":
				muzzle_position = Vector3(0.0, 1.26, -3.00)
			&"shotgun":
				muzzle_position = Vector3(0.0, 1.26, -3.02)
			_:
				muzzle_position = Vector3(0.0, 1.31, -2.64)
	return muzzle_position * _runtime_visual_scale()

func _build_gun_parts(mat: StandardMaterial3D, parts: Array) -> void:
	for part in parts:
		var mesh_inst = MeshInstance3D.new()
		var box = BoxMesh.new()
		box.size = part["size"]
		box.material = mat
		mesh_inst.mesh = box
		mesh_inst.position = part["pos"]
		_weapon_holder.add_child(mesh_inst)

func _weapon_color(weapon_id: StringName) -> Color:
	match weapon_id:
		&"smg":
			return Color("#65ff49")
		&"ak_rifle":
			return Color("#ffb13b")
		&"sniper":
			return Color("#5ce3ff")
		&"gatling":
			return Color("#ffd34d")
		&"shotgun":
			return Color("#d884ff")
		_:
			return Color("#ff6b72")

# ============================================================
#  动画：弹跳移动 + 压扁拉伸 (Squash & Stretch)
# ============================================================

var _deform_tween: Tween = null

## 垂直压扁（高度减小，水平变宽）
func animate_squash(y_scale: float = 0.6, xz_scale: float = 1.3, duration: float = 0.15) -> void:
	_play_deform(Vector3(xz_scale, y_scale, xz_scale), duration)

## 垂直拉伸（高度增加，水平变窄）
func animate_stretch(y_scale: float = 1.3, xz_scale: float = 0.7, duration: float = 0.15) -> void:
	_play_deform(Vector3(xz_scale, y_scale, xz_scale), duration)

func _play_deform(target_scale: Vector3, duration: float) -> void:
	if _deform_tween and _deform_tween.is_running():
		_deform_tween.kill()
	
	_deform_tween = create_tween().set_trans(Tween.TRANS_SPRING).set_ease(Tween.EASE_OUT)
	# 瞬间变形成目标比例
	_action_scale = target_scale
	# 弹性恢复到正常
	_deform_tween.tween_property(self, "_action_scale", Vector3.ONE, duration)

func animate_fire(weapon_id: StringName = &"pistol") -> void:
	_fire_serial += 1
	var profile := _fire_profile_for_weapon(weapon_id)
	var alternating_sign := -1.0 if _fire_serial % 2 == 0 else 1.0
	var lateral_sign := alternating_sign if bool(profile.get("alternate", false)) else 1.0
	_weapon_kick = maxf(_weapon_kick, float(profile["kick"]))
	_recoil_pitch = maxf(_recoil_pitch, float(profile["pitch"]))
	_recoil_yaw = _dominant_signed_impulse(_recoil_yaw, float(profile["yaw"]) * lateral_sign)
	_recoil_roll = _dominant_signed_impulse(_recoil_roll, float(profile["roll"]) * lateral_sign)
	_weapon_side_kick = _dominant_signed_impulse(_weapon_side_kick, float(profile["side_kick"]) * lateral_sign)
	_fire_compression = maxf(_fire_compression, float(profile["compression"]))
	_recoil_recovery_scale = float(profile["recovery"])

func _fire_profile_for_weapon(weapon_id: StringName) -> Dictionary:
	match weapon_id:
		&"smg":
			return {"kick": 0.040, "pitch": 0.036, "yaw": 0.032, "roll": 0.022, "side_kick": 0.022, "compression": 0.022, "recovery": 1.55, "alternate": true}
		&"ak_rifle":
			return {"kick": 0.092, "pitch": 0.080, "yaw": 0.046, "roll": 0.032, "side_kick": 0.032, "compression": 0.045, "recovery": 1.00, "alternate": true}
		&"sniper":
			return {"kick": 0.175, "pitch": 0.160, "yaw": 0.018, "roll": 0.026, "side_kick": 0.014, "compression": 0.075, "recovery": 0.65, "alternate": false}
		&"gatling":
			return {"kick": 0.028, "pitch": 0.026, "yaw": 0.022, "roll": 0.018, "side_kick": 0.020, "compression": 0.030, "recovery": 1.80, "alternate": true}
		&"shotgun":
			return {"kick": 0.125, "pitch": 0.120, "yaw": 0.040, "roll": 0.038, "side_kick": 0.032, "compression": 0.090, "recovery": 0.72, "alternate": true}
		_:
			return {"kick": 0.065, "pitch": 0.060, "yaw": 0.014, "roll": 0.016, "side_kick": 0.012, "compression": 0.025, "recovery": 1.18, "alternate": true}

func get_fire_profile_debug(weapon_id: StringName) -> Dictionary:
	return _fire_profile_for_weapon(weapon_id).duplicate(true)

func _dominant_signed_impulse(current: float, incoming: float) -> float:
	return incoming if absf(incoming) >= absf(current) else current

func _clear_fire_pose() -> void:
	_recoil_pitch = 0.0
	_recoil_yaw = 0.0
	_recoil_roll = 0.0
	_weapon_kick = 0.0
	_weapon_side_kick = 0.0
	_fire_compression = 0.0
	_recoil_recovery_scale = 1.0

func animate_respawn() -> void:
	if _deform_tween and _deform_tween.is_running():
		_deform_tween.kill()
	_action_scale = Vector3(0.36, 1.42, 0.36)
	_deform_tween = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_deform_tween.tween_property(self, "_action_scale", Vector3(1.10, 0.94, 1.10), 0.18)
	_deform_tween.tween_property(self, "_action_scale", Vector3.ONE, 0.12)

func animate_match_spawn() -> void:
	if _deform_tween and _deform_tween.is_running():
		_deform_tween.kill()
	_action_scale = Vector3(0.58, 0.34, 0.58)
	_deform_tween = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_deform_tween.tween_property(self, "_action_scale", Vector3(1.12, 0.96, 1.12), 0.22)
	_deform_tween.tween_property(self, "_action_scale", Vector3.ONE, 0.16)

func animate_match_winner() -> void:
	if _deform_tween and _deform_tween.is_running():
		_deform_tween.kill()
	_action_scale = Vector3.ONE
	_deform_tween = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_deform_tween.tween_property(self, "_action_scale", Vector3(1.10, 1.16, 1.10), 0.18)
	_deform_tween.tween_property(self, "_action_scale", Vector3(1.04, 0.98, 1.04), 0.14)
	_deform_tween.tween_property(self, "_action_scale", Vector3.ONE, 0.16)

func animate_movement(is_moving: bool, delta: float) -> void:
	var move_dir := Vector3.FORWARD if is_moving else Vector3.ZERO
	var speed_ratio := 1.0 if is_moving else 0.0
	animate_locomotion(move_dir, Vector3.FORWARD, speed_ratio, delta)

func animate_locomotion(move_dir: Vector3, facing_dir: Vector3, speed_ratio: float, delta: float) -> void:
	var flat_facing := Vector3(facing_dir.x, 0.0, facing_dir.z)
	if flat_facing.length_squared() <= 0.0001:
		flat_facing = Vector3.FORWARD
	else:
		flat_facing = flat_facing.normalized()
	_update_turn_anticipation(flat_facing, delta)

	var flat_move := Vector3(move_dir.x, 0.0, move_dir.z)
	var clamped_speed := clampf(speed_ratio, 0.0, 1.0)
	if flat_move.length_squared() > 0.0001:
		flat_move = flat_move.normalized()
	else:
		clamped_speed = 0.0
	_update_authored_motion_input(clamped_speed)

	var right_dir := Vector3(-flat_facing.z, 0.0, flat_facing.x).normalized()
	var target_forward := flat_move.dot(flat_facing) * clamped_speed
	var target_right := flat_move.dot(right_dir) * clamped_speed
	if clamped_speed > 0.35 and _last_input_speed_ratio <= 0.10:
		_locomotion_start_impulse = 1.0
		_locomotion_impulse_direction = Vector2(target_right, target_forward).normalized()
	elif clamped_speed <= 0.10 and _last_input_speed_ratio > 0.35:
		_locomotion_stop_impulse = 1.0
		_locomotion_impulse_direction = Vector2(_locomotion_right_amount, _locomotion_forward_amount).normalized()
	_last_input_speed_ratio = clamped_speed
	var blend_rate := 8.5 if clamped_speed > _locomotion_speed_ratio else 13.5
	var blend := clampf(delta * blend_rate, 0.0, 1.0)
	_locomotion_forward_amount = lerpf(_locomotion_forward_amount, target_forward, blend)
	_locomotion_right_amount = lerpf(_locomotion_right_amount, target_right, blend)
	_locomotion_speed_ratio = lerpf(_locomotion_speed_ratio, clamped_speed, blend)

	var pose_blend := clampf(delta * 12.0, 0.0, 1.0)
	var root_recoil_pitch := 0.0 if _uses_hero_rig else _recoil_pitch
	var start_pitch := -_locomotion_impulse_direction.y * _locomotion_start_impulse * 0.045
	var stop_pitch := _locomotion_impulse_direction.y * _locomotion_stop_impulse * 0.060
	var start_roll := -_locomotion_impulse_direction.x * _locomotion_start_impulse * 0.045
	var stop_roll := _locomotion_impulse_direction.x * _locomotion_stop_impulse * 0.060
	if _locomotion_speed_ratio > 0.02 or absf(_locomotion_forward_amount) > 0.02 or absf(_locomotion_right_amount) > 0.02:
		_bounce_time += delta * lerpf(8.0, 13.5, _locomotion_speed_ratio)
		var step_wave := absf(sin(_bounce_time))
		var step_bob := pow(step_wave, 1.55) * 0.11 * _locomotion_speed_ratio
		var contact_weight := pow(absf(cos(_bounce_time)), 5.0) * _locomotion_speed_ratio
		_stride_scale = Vector3(
			1.0 + contact_weight * 0.040 + _locomotion_stop_impulse * 0.035,
			1.0 - contact_weight * 0.052 - _locomotion_stop_impulse * 0.045,
			1.0 + contact_weight * 0.028 + _locomotion_start_impulse * 0.025
		)
		position.y = lerpf(position.y, step_bob, pose_blend)
		rotation.x = lerpf(rotation.x, -_locomotion_forward_amount * 0.045 + start_pitch + stop_pitch + root_recoil_pitch + _impact_pitch, pose_blend)
		rotation.y = lerpf(rotation.y, _turn_anticipation_angle, pose_blend)
		rotation.z = lerpf(rotation.z, (-_locomotion_right_amount * 0.085) + start_roll + stop_roll + sin(_bounce_time * 0.5) * 0.018 * _locomotion_speed_ratio + _impact_roll, pose_blend)
	else:
		_bounce_time = 0.0
		var settle_scale := Vector3(
			1.0 + _locomotion_stop_impulse * 0.055,
			1.0 - _locomotion_stop_impulse * 0.070,
			1.0 + _locomotion_stop_impulse * 0.040
		)
		_stride_scale = _stride_scale.lerp(settle_scale, pose_blend)
		position.y = lerpf(position.y, 0.0, pose_blend)
		rotation.x = lerpf(rotation.x, stop_pitch + root_recoil_pitch + _impact_pitch, pose_blend)
		rotation.y = lerpf(rotation.y, _turn_anticipation_angle, pose_blend)
		rotation.z = lerpf(rotation.z, stop_roll + _impact_roll, pose_blend)
	_apply_leg_step_pose(pose_blend)

func _update_turn_anticipation(flat_facing: Vector3, delta: float) -> void:
	if _last_facing_dir.length_squared() > 0.0001:
		var facing_delta := _last_facing_dir.signed_angle_to(flat_facing, Vector3.UP)
		if absf(facing_delta) > 0.012:
			_turn_anticipation_angle = clampf(-facing_delta * 0.32, -0.18, 0.18)
		else:
			_turn_anticipation_angle = move_toward(_turn_anticipation_angle, 0.0, delta * 0.62)
	_last_facing_dir = flat_facing

func _apply_leg_step_pose(blend: float) -> void:
	if _skeleton == null or _leg_bone_indices.size() != 2:
		_leg_swing_amounts = Vector2.ZERO
		return
	var gait_weight := maxf(absf(_locomotion_forward_amount), absf(_locomotion_right_amount) * 0.82)
	gait_weight *= _locomotion_speed_ratio
	var stride_angle := sin(_bounce_time) * 0.16 * gait_weight
	var strafe_angle := cos(_bounce_time) * 0.055 * _locomotion_right_amount * _locomotion_speed_ratio
	_leg_swing_amounts = Vector2(stride_angle + strafe_angle, -stride_angle - strafe_angle)
	if _has_authored_motion:
		return
	for index in range(_leg_bone_indices.size()):
		var direction := 1.0 if index == 0 else -1.0
		var target_rotation := _leg_base_rotations[index]
		target_rotation *= Quaternion(Vector3.RIGHT, stride_angle * direction)
		target_rotation *= Quaternion(Vector3.FORWARD, strafe_angle * direction)
		var bone_index := _leg_bone_indices[index]
		var current_rotation := _skeleton.get_bone_pose_rotation(bone_index)
		_skeleton.set_bone_pose_rotation(bone_index, current_rotation.slerp(target_rotation, blend))

func _apply_upper_body_recoil() -> void:
	if not _uses_hero_rig or _skeleton == null or _spine_bone_index < 0:
		_upper_body_recoil_angle = 0.0
		_upper_body_recoil_yaw = 0.0
		_upper_body_recoil_roll = 0.0
		return
	var locomotion_pitch := _locomotion_forward_amount * 0.045
	locomotion_pitch += _locomotion_impulse_direction.y * _locomotion_start_impulse * 0.055
	locomotion_pitch -= _locomotion_impulse_direction.y * _locomotion_stop_impulse * 0.050
	var locomotion_roll := -_locomotion_right_amount * 0.105
	locomotion_roll -= _locomotion_impulse_direction.x * _locomotion_start_impulse * 0.060
	locomotion_roll += _locomotion_impulse_direction.x * _locomotion_stop_impulse * 0.050
	_upper_body_recoil_angle = _recoil_pitch * HERO_RECOIL_SCALE + locomotion_pitch - _weapon_switch_amount * WEAPON_SWITCH_DIP_RADIANS
	_upper_body_recoil_yaw = _recoil_yaw * HERO_RECOIL_YAW_SCALE
	_upper_body_recoil_roll = _recoil_roll * HERO_RECOIL_ROLL_SCALE + locomotion_roll
	var recoil_rotation := _upper_body_recoil_rotation()
	_skeleton.set_bone_pose_rotation(
		_spine_bone_index,
		recoil_rotation * _spine_pose_base_rotation
	)
	_skeleton.force_update_all_bone_transforms()

func _upper_body_recoil_rotation() -> Quaternion:
	return (
		Quaternion(Vector3.UP, _upper_body_recoil_yaw)
		* Quaternion(Vector3.FORWARD, _upper_body_recoil_roll)
		* Quaternion(Vector3.RIGHT, -_upper_body_recoil_angle)
	)

func _update_weapon_holder_pose() -> void:
	if _weapon_holder == null:
		return
	if not _uses_hero_rig:
		_weapon_holder.position = _weapon_holder_base_position + Vector3(_weapon_side_kick, 0.0, _weapon_kick)
		_weapon_holder.basis = Basis.IDENTITY
		return
	var recoil_basis := Basis(_upper_body_recoil_rotation())
	var pivot_offset := _weapon_holder_base_position - HERO_SPINE_PIVOT
	var kick_offset := Vector3(
		_weapon_side_kick,
		-_fire_compression * 0.12,
		_weapon_kick * HERO_WEAPON_KICK_SCALE
	)
	_weapon_holder.position = HERO_SPINE_PIVOT + recoil_basis * (pivot_offset + kick_offset)
	_weapon_holder.basis = recoil_basis

func get_locomotion_forward_amount() -> float:
	return _locomotion_forward_amount

func get_locomotion_right_amount() -> float:
	return _locomotion_right_amount

func animate_hit(impact_dir: Vector3 = Vector3.ZERO, strength: float = 1.0) -> void:
	_hit_flash_timer = 0.12
	_begin_authored_hit()
	var clamped_strength := clampf(strength, 0.35, 1.35)
	var local_impact := global_basis.inverse() * impact_dir.normalized() if impact_dir.length_squared() > 0.0001 else Vector3.RIGHT
	_impact_roll = clampf(-local_impact.x * 0.16 * clamped_strength, -0.22, 0.22)
	_impact_pitch = clampf(local_impact.z * 0.10 * clamped_strength, -0.14, 0.14)

func get_motion_debug() -> Dictionary:
	return {
		"action_scale": _action_scale,
		"stride_scale": _stride_scale,
		"recoil_pitch": _recoil_pitch,
		"recoil_yaw": _recoil_yaw,
		"recoil_roll": _recoil_roll,
		"impact_pitch": _impact_pitch,
		"impact_roll": _impact_roll,
		"weapon_kick": _weapon_kick,
		"weapon_side_kick": _weapon_side_kick,
		"fire_compression": _fire_compression,
		"fire_serial": _fire_serial,
		"recoil_recovery_scale": _recoil_recovery_scale,
		"upper_body_recoil": _upper_body_recoil_angle,
		"upper_body_recoil_yaw": _upper_body_recoil_yaw,
		"upper_body_recoil_roll": _upper_body_recoil_roll,
		"hero_recoil_rigged": _uses_hero_rig and _spine_bone_index >= 0,
		"leg_swing": _leg_swing_amounts,
		"turn_anticipation": _turn_anticipation_angle,
		"locomotion_start_impulse": _locomotion_start_impulse,
		"locomotion_stop_impulse": _locomotion_stop_impulse,
		"locomotion_impulse_direction": _locomotion_impulse_direction,
		"weapon_switch_settle": _weapon_switch_amount,
		"weapon_switch_elapsed": _weapon_switch_elapsed,
		"visual_scale": _runtime_visual_scale(),
		"has_contact_shadow": _contact_shadow != null,
		"authored_motion_enabled": _has_authored_motion,
		"authored_motion_state": _authored_motion_state,
		"authored_motion_clip": _authored_motion_clip,
		"authored_motion_position": _animation_player.current_animation_position if _animation_player != null else 0.0,
		"footstep_serial": _footstep_serial,
		"footstep_phase": _last_footstep_phase,
	}

func get_material_debug() -> Dictionary:
	return {
		"suit_surface_count": _suit_materials.size(),
		"rubber_surface_count": _rubber_materials.size(),
		"face_panel_surface_count": _face_panel_materials.size(),
		"eye_surface_count": _eye_materials.size(),
		"suit_roughness": _suit_materials[0].roughness if not _suit_materials.is_empty() else 0.0,
		"face_panel_emission": _face_panel_materials[0].emission_energy_multiplier if not _face_panel_materials.is_empty() else 0.0,
		"eye_emission": _eye_materials[0].emission_energy_multiplier if not _eye_materials.is_empty() else 0.0,
	}

func _update_contact_shadow() -> void:
	if _contact_shadow == null or not is_inside_tree():
		return
	var grounded_position := global_position - Vector3.UP * position.y
	var local_motion := Vector3(_locomotion_right_amount, 0.0, -_locomotion_forward_amount)
	var world_motion := global_basis * local_motion
	_contact_shadow.global_position = grounded_position - world_motion * 0.10 + Vector3.UP * CONTACT_SHADOW_Y_OFFSET
	_contact_shadow.global_rotation = Vector3.ZERO
	_contact_shadow.scale = Vector3(
		1.0 + absf(_locomotion_right_amount) * 0.10 + _locomotion_stop_impulse * 0.06,
		1.0,
		0.70 + absf(_locomotion_forward_amount) * 0.10 + _locomotion_start_impulse * 0.05
	)
	if _contact_shadow_material != null:
		var lift_ratio := clampf(position.y / 0.22, 0.0, 1.0)
		_contact_shadow_material.albedo_color.a = lerpf(0.30, 0.18, lift_ratio)

func _process(delta: float) -> void:
	if _has_authored_motion and _animation_player != null:
		_animation_player.advance(delta)
	_locomotion_start_impulse = move_toward(_locomotion_start_impulse, 0.0, delta * LOCOMOTION_START_DECAY)
	_locomotion_stop_impulse = move_toward(_locomotion_stop_impulse, 0.0, delta * LOCOMOTION_STOP_DECAY)
	if _last_input_speed_ratio <= 0.10 and _locomotion_speed_ratio < 0.05:
		var idle_settle := clampf(delta * 10.0, 0.0, 1.0)
		rotation.x = lerpf(rotation.x, _impact_pitch, idle_settle)
		rotation.z = lerpf(rotation.z, _impact_roll, idle_settle)
	var recoil_decay := maxf(_recoil_recovery_scale, 0.55)
	_recoil_pitch = move_toward(_recoil_pitch, 0.0, delta * 0.72 * recoil_decay)
	_recoil_yaw = move_toward(_recoil_yaw, 0.0, delta * 0.86 * recoil_decay)
	_recoil_roll = move_toward(_recoil_roll, 0.0, delta * 1.05 * recoil_decay)
	_impact_pitch = move_toward(_impact_pitch, 0.0, delta * 1.35)
	_impact_roll = move_toward(_impact_roll, 0.0, delta * 1.75)
	_weapon_kick = move_toward(_weapon_kick, 0.0, delta * 0.85 * recoil_decay)
	_weapon_side_kick = move_toward(_weapon_side_kick, 0.0, delta * 0.92 * recoil_decay)
	_fire_compression = move_toward(_fire_compression, 0.0, delta * 0.74 * recoil_decay)
	if _recoil_pitch <= 0.0001 and absf(_recoil_yaw) <= 0.0001 and _weapon_kick <= 0.0001:
		_recoil_recovery_scale = move_toward(_recoil_recovery_scale, 1.0, delta * 4.0)
	_update_authored_motion_playback(delta)
	_update_authored_footsteps()
	_update_weapon_switch_settle(delta)
	_apply_upper_body_recoil()
	var visual_scale := _runtime_visual_scale()
	var fire_scale := Vector3(
		1.0 + _fire_compression * 0.32,
		1.0 - _fire_compression,
		1.0 + _fire_compression * 0.22
	)
	scale = Vector3(
		visual_scale.x * _action_scale.x * _stride_scale.x * fire_scale.x,
		visual_scale.y * _action_scale.y * _stride_scale.y * fire_scale.y,
		visual_scale.z * _action_scale.z * _stride_scale.z * fire_scale.z
	)
	_update_weapon_holder_pose()
	_update_contact_shadow()
	if _hit_flash_timer > 0:
		_hit_flash_timer -= delta
		var flash_weight := clampf(_hit_flash_timer / 0.12, 0.0, 1.0) * 0.72
		var flash_color := body_color.lerp(Color("#fff0cf"), flash_weight)
		_apply_rendered_body_color(flash_color)
	else:
		_apply_rendered_body_color(body_color)

func _update_weapon_switch_settle(delta: float) -> void:
	if _weapon_switch_elapsed >= WEAPON_SWITCH_DURATION:
		_weapon_switch_amount = 0.0
		return
	_weapon_switch_elapsed = minf(_weapon_switch_elapsed + delta, WEAPON_SWITCH_DURATION)
	var phase := _weapon_switch_elapsed / WEAPON_SWITCH_DURATION
	_weapon_switch_amount = sin(phase * PI)

## 更新身体颜色
func set_color(color: Color) -> void:
	set_body_color(color)
