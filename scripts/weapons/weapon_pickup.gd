extends Area3D
class_name WeaponPickup
## 地图上的武器拾取物：悬浮旋转，走过去自动拾取

var weapon_data: WeaponData
var _rotation_speed: float = 2.0

signal picked_up()

func setup(data: WeaponData) -> void:
	weapon_data = data
	# 根据武器类型设置颜色标识
	var mesh_inst = $MeshInstance3D as MeshInstance3D
	if mesh_inst and mesh_inst.mesh:
		var mat = StandardMaterial3D.new()
		match data.weapon_id:
			&"smg":
				mat.albedo_color = Color(1, 0.6, 0, 1)
			&"ak_rifle":
				mat.albedo_color = Color(1, 0.2, 0.2, 1)
			&"sniper":
				mat.albedo_color = Color(1, 1, 1, 1)
			_:
				mat.albedo_color = Color(0.5, 0.5, 0.5, 1)
		mat.emission_enabled = true
		mat.emission = mat.albedo_color
		mat.emission_energy_multiplier = 1.5
		mesh_inst.material_override = mat

func _ready() -> void:
	add_to_group("weapon_pickup")
	body_entered.connect(_on_body_entered)

func _process(delta: float) -> void:
	# 悬浮旋转 + 上下浮动
	rotate_y(_rotation_speed * delta)
	var float_offset = sin(Time.get_ticks_msec() * 0.003) * 0.3
	position.y = 1.5 + float_offset

func _on_body_entered(body: Node3D) -> void:
	# 只有拥有 WeaponManager 的角色可以拾取
	var wm = body.get_node_or_null("WeaponManager") as WeaponManager
	if not wm:
		return
	wm.equip_weapon(weapon_data)
	picked_up.emit()
	queue_free()
