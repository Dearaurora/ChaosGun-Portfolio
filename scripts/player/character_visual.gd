extends Node3D
class_name CharacterVisual
## 角色可视化：代码构建蓝色豆子人模型（参考图风格）
## 可分离部件：帽子、衣服、枪械

@export var body_color: Color = Color(0.15, 0.35, 1.0)
@export var show_hat: bool = false
@export var show_vest: bool = false
@export var show_visor: bool = true

const BEAN_CHARACTER_SCENE_PATH := "res://assets/models/generated/characters/bean_character.glb"
const WEAPON_MODEL_ROOT := "res://assets/models/generated/weapons/"

var _weapon_holder: Node3D
var _bounce_time: float = 0.0
var _hit_flash_timer: float = 0.0
var _body_mesh: MeshInstance3D
var _body_color_meshes: Array[MeshInstance3D] = []
var _asset_root: Node3D = null
var _locomotion_forward_amount: float = 0.0
var _locomotion_right_amount: float = 0.0
var _locomotion_speed_ratio: float = 0.0
var _current_weapon_id: StringName = &"pistol"
var _action_scale: Vector3 = Vector3.ONE
var _stride_scale: Vector3 = Vector3.ONE
var _recoil_pitch: float = 0.0
var _impact_pitch: float = 0.0
var _impact_roll: float = 0.0
var _weapon_kick: float = 0.0
var _weapon_holder_base_position: Vector3 = Vector3.ZERO

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
	for mesh_instance in _body_color_meshes:
		_apply_body_color_to_mesh(mesh_instance, color)

func _build_asset_visual() -> bool:
	var packed_scene = load(BEAN_CHARACTER_SCENE_PATH) as PackedScene
	if packed_scene == null:
		return false

	_asset_root = packed_scene.instantiate() as Node3D
	if _asset_root == null:
		return false
	_asset_root.name = "BeanCharacterAsset"
	add_child(_asset_root)

	_create_marker("FaceVisor", Vector3(0, 1.58, -0.84))
	_create_marker("LeftHand", Vector3(-0.18, 1.13, -1.40))
	_create_marker("RightHand", Vector3(0.18, 0.98, -1.34))
	_create_marker("LeftFoot", Vector3(-0.39, 0.18, -0.16))
	_create_marker("RightFoot", Vector3(0.39, 0.18, -0.16))
	_cache_asset_meshes(_asset_root)
	set_body_color(body_color)
	return true

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
			if lower_name == "body":
				_body_mesh = mesh_instance
				_body_color_meshes.append(mesh_instance)
			elif lower_name.contains("body"):
				_body_color_meshes.append(mesh_instance)
			elif lower_name.contains("belly") or lower_name.contains("hand"):
				_body_color_meshes.append(mesh_instance)
		_cache_asset_meshes(child)

func _apply_body_color_to_mesh(mesh_instance: MeshInstance3D, color: Color) -> void:
	if mesh_instance == null:
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
	_weapon_holder.position = Vector3(0.0, 1.03, -1.45)
	_weapon_holder.scale = Vector3.ONE
	add_child(_weapon_holder)
	_weapon_holder_base_position = _weapon_holder.position

## 切换枪械可视模型
func set_weapon_visual(weapon_id: StringName) -> void:
	_current_weapon_id = weapon_id
	_set_weapon_pose_visual(weapon_id)
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

	_build_weapon_readability_proxy(weapon_id)

func _set_weapon_pose_visual(weapon_id: StringName) -> void:
	if _asset_root == null:
		return
	var wants_pistol := weapon_id == &"pistol"
	_set_weapon_pose_mesh_visibility(_asset_root, wants_pistol)

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
	weapon_asset.position = Vector3(0.0, 0.04, -0.10)
	weapon_asset.rotation_degrees.y = 180.0
	weapon_asset.scale = Vector3.ONE * _weapon_asset_scale(weapon_id)
	_weapon_holder.add_child(weapon_asset)
	return true

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
		"holder_scale": _weapon_holder.scale.x if _weapon_holder else 0.0,
		"silhouette_length": float(profile["silhouette_length"]),
		"silhouette_width": float(profile["silhouette_width"]),
		"has_asset": asset != null,
		"uses_proxy": proxy != null,
		"asset_scale": _weapon_asset_scale(_current_weapon_id),
		"asset_rotation_y": asset.rotation_degrees.y if asset else 0.0,
		"weapon_pose": "pistol" if _current_weapon_id == &"pistol" else "long",
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
		_:
			return ""

func _weapon_asset_scale(weapon_id: StringName) -> float:
	match weapon_id:
		&"pistol":
			return 1.34
		&"smg":
			return 1.14
		&"ak_rifle":
			return 1.00
		&"sniper":
			return 0.92
		_:
			return 1.0

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
	var kick := 0.055
	var pitch := 0.045
	match weapon_id:
		&"smg":
			kick = 0.035
			pitch = 0.028
		&"ak_rifle":
			kick = 0.075
			pitch = 0.060
		&"sniper":
			kick = 0.145
			pitch = 0.115
	_weapon_kick = maxf(_weapon_kick, kick)
	_recoil_pitch = maxf(_recoil_pitch, pitch)

func animate_respawn() -> void:
	if _deform_tween and _deform_tween.is_running():
		_deform_tween.kill()
	_action_scale = Vector3(0.36, 1.42, 0.36)
	_deform_tween = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_deform_tween.tween_property(self, "_action_scale", Vector3(1.10, 0.94, 1.10), 0.18)
	_deform_tween.tween_property(self, "_action_scale", Vector3.ONE, 0.12)

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

	var flat_move := Vector3(move_dir.x, 0.0, move_dir.z)
	var clamped_speed := clampf(speed_ratio, 0.0, 1.0)
	if flat_move.length_squared() > 0.0001:
		flat_move = flat_move.normalized()
	else:
		clamped_speed = 0.0

	var right_dir := Vector3(-flat_facing.z, 0.0, flat_facing.x).normalized()
	var target_forward := flat_move.dot(flat_facing) * clamped_speed
	var target_right := flat_move.dot(right_dir) * clamped_speed
	var blend := clampf(delta * 10.0, 0.0, 1.0)
	_locomotion_forward_amount = lerpf(_locomotion_forward_amount, target_forward, blend)
	_locomotion_right_amount = lerpf(_locomotion_right_amount, target_right, blend)
	_locomotion_speed_ratio = lerpf(_locomotion_speed_ratio, clamped_speed, blend)

	var pose_blend := clampf(delta * 12.0, 0.0, 1.0)
	if _locomotion_speed_ratio > 0.02 or absf(_locomotion_forward_amount) > 0.02 or absf(_locomotion_right_amount) > 0.02:
		_bounce_time += delta * lerpf(8.0, 13.5, _locomotion_speed_ratio)
		var step_bob := absf(sin(_bounce_time)) * 0.22 * _locomotion_speed_ratio
		var stride_pulse := absf(sin(_bounce_time)) * _locomotion_speed_ratio
		_stride_scale = Vector3(1.0 + stride_pulse * 0.035, 1.0 - stride_pulse * 0.050, 1.0 + stride_pulse * 0.025)
		position.y = lerpf(position.y, step_bob, pose_blend)
		rotation.x = lerpf(rotation.x, -_locomotion_forward_amount * 0.08 + _recoil_pitch + _impact_pitch, pose_blend)
		rotation.z = lerpf(rotation.z, (-_locomotion_right_amount * 0.18) + sin(_bounce_time * 0.5) * 0.025 * _locomotion_speed_ratio + _impact_roll, pose_blend)
	else:
		_bounce_time = 0.0
		_stride_scale = _stride_scale.lerp(Vector3.ONE, pose_blend)
		position.y = lerpf(position.y, 0.0, pose_blend)
		rotation.x = lerpf(rotation.x, _recoil_pitch + _impact_pitch, pose_blend)
		rotation.z = lerpf(rotation.z, _impact_roll, pose_blend)

func get_locomotion_forward_amount() -> float:
	return _locomotion_forward_amount

func get_locomotion_right_amount() -> float:
	return _locomotion_right_amount

func animate_hit(impact_dir: Vector3 = Vector3.ZERO, strength: float = 1.0) -> void:
	_hit_flash_timer = 0.15
	var clamped_strength := clampf(strength, 0.35, 1.35)
	var local_impact := global_basis.inverse() * impact_dir.normalized() if impact_dir.length_squared() > 0.0001 else Vector3.RIGHT
	_impact_roll = clampf(-local_impact.x * 0.16 * clamped_strength, -0.22, 0.22)
	_impact_pitch = clampf(local_impact.z * 0.10 * clamped_strength, -0.14, 0.14)

func get_motion_debug() -> Dictionary:
	return {
		"action_scale": _action_scale,
		"stride_scale": _stride_scale,
		"recoil_pitch": _recoil_pitch,
		"impact_pitch": _impact_pitch,
		"impact_roll": _impact_roll,
		"weapon_kick": _weapon_kick,
	}

func _process(delta: float) -> void:
	_recoil_pitch = move_toward(_recoil_pitch, 0.0, delta * 0.72)
	_impact_pitch = move_toward(_impact_pitch, 0.0, delta * 1.35)
	_impact_roll = move_toward(_impact_roll, 0.0, delta * 1.75)
	_weapon_kick = move_toward(_weapon_kick, 0.0, delta * 0.85)
	scale = Vector3(_action_scale.x * _stride_scale.x, _action_scale.y * _stride_scale.y, _action_scale.z * _stride_scale.z)
	if _weapon_holder:
		_weapon_holder.position = _weapon_holder_base_position + Vector3(0.0, 0.0, _weapon_kick)
	if _hit_flash_timer > 0:
		_hit_flash_timer -= delta
		var flash_color = Color.RED if fmod(_hit_flash_timer, 0.1) > 0.05 else body_color
		for mesh_instance in _body_color_meshes:
			_apply_body_color_to_mesh(mesh_instance, flash_color)
	else:
		for mesh_instance in _body_color_meshes:
			_apply_body_color_to_mesh(mesh_instance, body_color)

## 更新身体颜色
func set_color(color: Color) -> void:
	body_color = color
	for mesh_instance in _body_color_meshes:
		_apply_body_color_to_mesh(mesh_instance, color)
