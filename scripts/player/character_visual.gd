extends Node3D
class_name CharacterVisual
## 角色可视化：代码构建蓝色豆子人模型（参考图风格）
## 可分离部件：帽子、衣服、枪械

@export var body_color: Color = Color(0.15, 0.35, 1.0)
@export var show_hat: bool = true
@export var show_vest: bool = true

var _weapon_holder: Node3D
var _bounce_time: float = 0.0
var _hit_flash_timer: float = 0.0
var _body_mesh: MeshInstance3D

func _ready() -> void:
	_build_body()
	_build_eyes()
	if show_hat:
		_build_hat()
	if show_vest:
		_build_vest_stripes()
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

# ============================================================
#  枪械模型容器
# ============================================================
func _build_weapon_holder() -> void:
	_weapon_holder = Node3D.new()
	_weapon_holder.name = "WeaponHolder"
	_weapon_holder.position = Vector3(0.8, 1.4, -1.0)
	add_child(_weapon_holder)

## 切换枪械可视模型
func set_weapon_visual(weapon_id: StringName) -> void:
	# 清除旧模型
	for child in _weapon_holder.get_children():
		child.queue_free()

	var gun_mat = StandardMaterial3D.new()
	gun_mat.albedo_color = Color(0.25, 0.25, 0.25)
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

func _build_gun_parts(mat: StandardMaterial3D, parts: Array) -> void:
	for part in parts:
		var mesh_inst = MeshInstance3D.new()
		var box = BoxMesh.new()
		box.size = part["size"]
		box.material = mat
		mesh_inst.mesh = box
		mesh_inst.position = part["pos"]
		_weapon_holder.add_child(mesh_inst)

# ============================================================
#  动画：弹跳移动 + 受击闪红
# ============================================================
func animate_movement(is_moving: bool, delta: float) -> void:
	if is_moving:
		_bounce_time += delta * 12.0
		# 上下弹跳
		position.y = abs(sin(_bounce_time)) * 0.25
		# 轻微左右摇摆
		rotation.z = sin(_bounce_time * 0.5) * 0.04
	else:
		_bounce_time = 0.0
		position.y = lerp(position.y, 0.0, 8.0 * delta)
		rotation.z = lerp(rotation.z, 0.0, 8.0 * delta)

func animate_hit() -> void:
	_hit_flash_timer = 0.15

func _process(delta: float) -> void:
	if _hit_flash_timer > 0:
		_hit_flash_timer -= delta
		if _body_mesh and _body_mesh.mesh:
			var mat = _body_mesh.mesh.material as StandardMaterial3D
			if mat:
				mat.albedo_color = Color.RED if fmod(_hit_flash_timer, 0.1) > 0.05 else body_color
	elif _body_mesh and _body_mesh.mesh:
		var mat = _body_mesh.mesh.material as StandardMaterial3D
		if mat and mat.albedo_color != body_color:
			mat.albedo_color = body_color

## 更新身体颜色
func set_color(color: Color) -> void:
	body_color = color
	if _body_mesh and _body_mesh.mesh:
		var mat = _body_mesh.mesh.material as StandardMaterial3D
		if mat:
			mat.albedo_color = color
