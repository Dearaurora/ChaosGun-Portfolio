extends Area3D
class_name WeaponPickup

const RuntimeGlobals = preload("res://scripts/globals/runtime_globals.gd")

var weapon_data: WeaponData
var _rotation_speed: float = 2.8
var _base_y: float = 1.5
var _visual_root: Node3D = null
var _icon_root: Node3D = null
var _accent_color: Color = Color("#38aeea")

signal picked_up()

func setup(data: WeaponData) -> void:
	weapon_data = data
	_base_y = position.y
	_accent_color = _weapon_color(data.weapon_id)
	_build_visual(data.weapon_id)

func _ready() -> void:
	add_to_group("weapon_pickup")
	_base_y = position.y
	body_entered.connect(_on_body_entered)

func _process(delta: float) -> void:
	if _icon_root:
		_icon_root.rotate_y(_rotation_speed * delta)
	var float_offset = sin(Time.get_ticks_msec() * 0.003) * 0.3
	position.y = _base_y + float_offset

func _on_body_entered(body: Node3D) -> void:
	var wm = body.get_node_or_null("WeaponManager") as WeaponManager
	if not wm:
		return
	wm.equip_weapon(weapon_data)
	_spawn_pickup_burst()
	picked_up.emit()
	queue_free()

func _build_visual(weapon_id: StringName) -> void:
	var legacy = get_node_or_null("MeshInstance3D") as MeshInstance3D
	if legacy:
		legacy.visible = false

	if _visual_root == null:
		_visual_root = Node3D.new()
		_visual_root.name = "ToyPickupVisual"
		add_child(_visual_root)
	for child in _visual_root.get_children():
		child.queue_free()

	_add_cylinder(_visual_root, "PickupBase", Vector3(0, -0.48, 0), 1.55, 0.20, _mat(Color("#56616b"), Color("#56616b"), 0.0), 28)
	_add_cylinder(_visual_root, "PickupGlow", Vector3(0, -0.31, 0), 1.18, 0.08, _mat(Color(_accent_color.r, _accent_color.g, _accent_color.b, 0.58), _accent_color, 1.8), 28)

	_icon_root = Node3D.new()
	_icon_root.name = "PickupWeaponIcon"
	_icon_root.position = Vector3(0, 0.44, 0)
	_icon_root.rotation_degrees = Vector3(0, 28, 0)
	_visual_root.add_child(_icon_root)

	match weapon_id:
		&"smg":
			_add_box(_icon_root, "SMGBody", Vector3(0.0, 0.0, 0), Vector3(1.65, 0.24, 0.36), _accent_color)
			_add_box(_icon_root, "SMGBarrel", Vector3(0.95, 0.02, 0), Vector3(0.62, 0.14, 0.22), Color("#dff6ff"))
			_add_box(_icon_root, "SMGGrip", Vector3(-0.28, -0.34, 0), Vector3(0.22, 0.62, 0.22), Color("#202833"))
			_add_box(_icon_root, "SMGMag", Vector3(0.28, -0.38, 0), Vector3(0.28, 0.52, 0.22), Color("#202833"))
		&"ak_rifle":
			_add_box(_icon_root, "RifleBody", Vector3(0.0, 0.0, 0), Vector3(2.10, 0.26, 0.38), _accent_color)
			_add_box(_icon_root, "RifleBarrel", Vector3(1.25, 0.02, 0), Vector3(0.75, 0.15, 0.20), Color("#dff6ff"))
			_add_box(_icon_root, "RifleStock", Vector3(-1.15, 0.0, 0), Vector3(0.58, 0.24, 0.42), Color("#202833"))
			_add_box(_icon_root, "RifleMag", Vector3(0.12, -0.43, 0), Vector3(0.30, 0.62, 0.24), Color("#a3441f"))
		&"sniper":
			_add_box(_icon_root, "SniperBody", Vector3(0.0, 0.0, 0), Vector3(2.55, 0.20, 0.30), _accent_color)
			_add_box(_icon_root, "SniperBarrel", Vector3(1.55, 0.02, 0), Vector3(1.0, 0.12, 0.16), Color("#dff6ff"))
			_add_box(_icon_root, "SniperScope", Vector3(0.08, 0.28, 0), Vector3(0.78, 0.20, 0.24), Color("#202833"))
			_add_box(_icon_root, "SniperStock", Vector3(-1.35, 0.0, 0), Vector3(0.62, 0.22, 0.36), Color("#202833"))
		_:
			_add_box(_icon_root, "PistolBody", Vector3(0.0, 0.0, 0), Vector3(1.10, 0.28, 0.38), _accent_color)
			_add_box(_icon_root, "PistolBarrel", Vector3(0.62, 0.02, 0), Vector3(0.52, 0.16, 0.22), Color("#dff6ff"))
			_add_box(_icon_root, "PistolGrip", Vector3(-0.25, -0.36, 0), Vector3(0.28, 0.62, 0.24), Color("#202833"))

func _add_box(parent: Node3D, name: String, pos: Vector3, size: Vector3, color: Color) -> MeshInstance3D:
	var mesh_instance = MeshInstance3D.new()
	mesh_instance.name = name
	var mesh = BoxMesh.new()
	mesh.size = size
	mesh.material = _mat(color, color, 0.25)
	mesh_instance.mesh = mesh
	mesh_instance.position = pos
	parent.add_child(mesh_instance)
	return mesh_instance

func _add_cylinder(parent: Node3D, name: String, pos: Vector3, radius: float, height: float, mat: Material, segments: int) -> MeshInstance3D:
	var mesh_instance = MeshInstance3D.new()
	mesh_instance.name = name
	var mesh = CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = segments
	mesh.material = mat
	mesh_instance.mesh = mesh
	mesh_instance.position = pos
	parent.add_child(mesh_instance)
	return mesh_instance

func _spawn_pickup_burst() -> void:
	var scene_root = RuntimeGlobals.active_scene(get_tree())
	if scene_root == null:
		return
	var burst = Node3D.new()
	burst.name = "PickupBurst"
	scene_root.add_child(burst)
	burst.global_position = global_position + Vector3.UP * 0.15
	_add_cylinder(burst, "BurstDisc", Vector3.ZERO, 1.25, 0.08, _mat(Color(_accent_color.r, _accent_color.g, _accent_color.b, 0.40), _accent_color, 2.4), 28)
	for i in range(6):
		var angle = TAU * float(i) / 6.0
		var sparkle = MeshInstance3D.new()
		sparkle.name = "Sparkle"
		var mesh = SphereMesh.new()
		mesh.radius = 0.18
		mesh.height = 0.18
		mesh.material = _mat(_accent_color.lerp(Color.WHITE, 0.35), _accent_color, 2.0)
		sparkle.mesh = mesh
		sparkle.position = Vector3(cos(angle) * 0.72, 0.25, sin(angle) * 0.72)
		burst.add_child(sparkle)
	var tween = burst.create_tween()
	tween.tween_property(burst, "scale", Vector3.ONE * 1.8, 0.18).set_ease(Tween.EASE_OUT)
	tween.tween_callback(burst.queue_free)

func _weapon_color(weapon_id: StringName) -> Color:
	match weapon_id:
		&"smg":
			return Color("#79d946")
		&"ak_rifle":
			return Color("#ff9b23")
		&"sniper":
			return Color("#31bde8")
		_:
			return Color("#38aeea")

func _mat(albedo: Color, emission: Color, emission_energy: float) -> StandardMaterial3D:
	var mat = StandardMaterial3D.new()
	mat.albedo_color = albedo
	mat.roughness = 0.58
	mat.metallic_specular = 0.18
	if albedo.a < 1.0:
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	if emission_energy > 0.0:
		mat.emission_enabled = true
		mat.emission = emission
		mat.emission_energy_multiplier = emission_energy
	return mat
