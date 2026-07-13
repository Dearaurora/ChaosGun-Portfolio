extends Area3D
class_name WeaponPickup

const RuntimeGlobals = preload("res://scripts/globals/runtime_globals.gd")
const WEAPON_MODEL_ROOT := "res://assets/models/generated/weapons/"

var weapon_data: WeaponData
var _rotation_speed: float = 0.85
var _base_y: float = 1.5
var _visual_root: Node3D = null
var _icon_root: Node3D = null
var _accent_color: Color = Color("#38aeea")
var _uses_external_pedestal := false
var _premium_presentation := false

signal picked_up()

func setup(data: WeaponData) -> void:
	weapon_data = data
	_base_y = position.y
	_accent_color = _weapon_color(data.weapon_id)
	_build_visual(data.weapon_id)
	_play_materialize_intro()

func configure_spawn_presentation(spawn_kind: String) -> void:
	_uses_external_pedestal = true
	_premium_presentation = spawn_kind == "fixed"
	var base := get_node_or_null("ToyPickupVisual/PickupBase") as MeshInstance3D
	var glow := get_node_or_null("ToyPickupVisual/PickupGlow") as MeshInstance3D
	var trim := get_node_or_null("ToyPickupVisual/PickupTrim") as MeshInstance3D
	if base:
		base.visible = false
	if glow:
		glow.visible = false
	if trim:
		trim.visible = false
	if _icon_root:
		_icon_root.position.y = 0.96 if _premium_presentation else 0.80
		_icon_root.scale = Vector3.ONE * (1.12 if _premium_presentation else 1.0)

func _ready() -> void:
	add_to_group("weapon_pickup")
	_base_y = position.y
	body_entered.connect(_on_body_entered)

func _process(delta: float) -> void:
	if _icon_root:
		_icon_root.rotate_y(_rotation_speed * delta)
	var float_offset = sin(Time.get_ticks_msec() * 0.0026) * 0.14
	position.y = _base_y + float_offset

func _on_body_entered(body: Node3D) -> void:
	var wm = body.get_node_or_null("WeaponManager") as WeaponManager
	if not wm:
		return
	wm.equip_weapon(weapon_data)
	_animate_pickup_to_character(body)
	_spawn_pickup_burst()
	picked_up.emit()
	queue_free()

func _animate_pickup_to_character(body: Node3D) -> void:
	if _icon_root == null:
		return
	var scene_root := RuntimeGlobals.active_scene(get_tree())
	if scene_root == null:
		return
	var collect_visual := _icon_root
	_icon_root = null
	collect_visual.name = "PickupCollectVisual"
	collect_visual.reparent(scene_root, true)
	var target_position := body.global_position + Vector3.UP * 1.35
	var tween := collect_visual.create_tween().set_parallel(true)
	tween.tween_property(collect_visual, "global_position", target_position, 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_property(collect_visual, "scale", Vector3.ONE * 0.18, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tween.tween_property(collect_visual, "rotation:y", collect_visual.rotation.y + PI * 0.75, 0.12)
	tween.chain().tween_callback(collect_visual.queue_free)

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

	_add_cylinder(_visual_root, "PickupBase", Vector3(0, -0.48, 0), 1.55, 0.24, _mat(Color("#303545"), Color("#303545"), 0.0), 32)
	_add_cylinder(_visual_root, "PickupGlow", Vector3(0, -0.30, 0), 1.12, 0.09, _mat(Color(_accent_color.r, _accent_color.g, _accent_color.b, 0.46), _accent_color, 0.65), 32)
	var trim := MeshInstance3D.new()
	trim.name = "PickupTrim"
	var trim_mesh := TorusMesh.new()
	trim_mesh.inner_radius = 1.26
	trim_mesh.outer_radius = 1.42
	trim_mesh.rings = 32
	trim_mesh.ring_segments = 8
	trim.mesh = trim_mesh
	trim.position.y = -0.25
	trim.material_override = _mat(Color("#687386"), Color("#687386"), 0.0)
	_visual_root.add_child(trim)

	_icon_root = Node3D.new()
	_icon_root.name = "PickupWeaponIcon"
	_icon_root.position = Vector3(0, 0.44, 0)
	_icon_root.rotation_degrees = Vector3(0, 24, 0)
	_visual_root.add_child(_icon_root)

	if _build_weapon_asset(weapon_id):
		return

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
		&"gatling":
			_add_box(_icon_root, "GatlingBody", Vector3(0.0, 0.0, 0), Vector3(1.85, 0.34, 0.48), _accent_color)
			_add_box(_icon_root, "GatlingBarrels", Vector3(1.25, 0.02, 0), Vector3(0.85, 0.24, 0.34), Color("#596575"))
			_add_box(_icon_root, "GatlingAmmo", Vector3(-0.10, -0.42, 0), Vector3(0.42, 0.55, 0.34), Color("#202833"))
		&"shotgun":
			_add_box(_icon_root, "ShotgunBody", Vector3(0.0, 0.0, 0), Vector3(2.35, 0.25, 0.36), _accent_color)
			_add_box(_icon_root, "ShotgunPump", Vector3(0.62, -0.03, 0), Vector3(0.62, 0.31, 0.42), Color("#8850b7"))
			_add_box(_icon_root, "ShotgunStock", Vector3(-1.25, 0.0, 0), Vector3(0.62, 0.28, 0.44), Color("#202833"))
		_:
			_add_box(_icon_root, "PistolBody", Vector3(0.0, 0.0, 0), Vector3(1.10, 0.28, 0.38), _accent_color)
			_add_box(_icon_root, "PistolBarrel", Vector3(0.62, 0.02, 0), Vector3(0.52, 0.16, 0.22), Color("#dff6ff"))
			_add_box(_icon_root, "PistolGrip", Vector3(-0.25, -0.36, 0), Vector3(0.28, 0.62, 0.24), Color("#202833"))

func _build_weapon_asset(weapon_id: StringName) -> bool:
	var model_path := WEAPON_MODEL_ROOT + String(weapon_id) + ".glb"
	var packed_scene := load(model_path) as PackedScene
	if packed_scene == null:
		return false
	var asset := packed_scene.instantiate() as Node3D
	if asset == null:
		return false
	asset.name = "WeaponAsset"
	asset.rotation_degrees = Vector3(0.0, 90.0, 0.0)
	asset.scale = Vector3.ONE * _weapon_asset_scale(weapon_id)
	_icon_root.add_child(asset)
	return true

func _weapon_asset_scale(weapon_id: StringName) -> float:
	match weapon_id:
		&"pistol":
			return 1.82
		&"smg":
			return 1.58
		&"ak_rifle":
			return 1.42
		&"sniper":
			return 1.28
		&"gatling":
			return 1.22
		&"shotgun":
			return 1.30
		_:
			return 1.0

func _play_materialize_intro() -> void:
	if _icon_root == null:
		return
	_icon_root.scale = Vector3(0.32, 1.45, 0.32)
	var tween := create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(_icon_root, "scale", Vector3(1.08, 0.94, 1.08), 0.16)
	tween.tween_property(_icon_root, "scale", Vector3.ONE, 0.08)

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
	var ring := MeshInstance3D.new()
	ring.name = "PickupBurstRing"
	var torus := TorusMesh.new()
	torus.inner_radius = 0.88
	torus.outer_radius = 1.12
	torus.rings = 28
	torus.ring_segments = 8
	ring.mesh = torus
	ring.material_override = _mat(Color(_accent_color.r, _accent_color.g, _accent_color.b, 0.72), _accent_color, 1.0)
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	burst.add_child(ring)
	for i in range(4):
		var angle := TAU * float(i) / 4.0
		var shard := _add_box(burst, "PickupShard_%d" % i, Vector3(cos(angle) * 0.72, 0.25, sin(angle) * 0.72), Vector3(0.12, 0.34, 0.42), _accent_color.lerp(Color.WHITE, 0.35))
		shard.rotation.y = -angle
		shard.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var tween = burst.create_tween()
	tween.tween_property(burst, "scale", Vector3.ONE * 1.55, 0.16).set_ease(Tween.EASE_OUT)
	tween.tween_callback(burst.queue_free)

func _weapon_color(weapon_id: StringName) -> Color:
	match weapon_id:
		&"smg":
			return Color("#79d946")
		&"ak_rifle":
			return Color("#ff9b23")
		&"sniper":
			return Color("#31bde8")
		&"gatling":
			return Color("#ffd34d")
		&"shotgun":
			return Color("#d884ff")
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
