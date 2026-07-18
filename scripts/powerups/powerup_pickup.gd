extends Area3D
class_name PowerupPickup

const RuntimeGlobals = preload("res://scripts/globals/runtime_globals.gd")

var powerup_id: StringName = PowerupCatalog.SPEED
var _accent_color := Color("#55e46d")
var _base_y := 1.5
var _elapsed := 0.0
var _visual_root: Node3D = null
var _icon_root: Node3D = null
var _uses_external_pedestal := false
var _icon_base_y := 0.46

signal picked_up()

func setup(id: StringName) -> void:
	powerup_id = id
	_accent_color = PowerupCatalog.color(id)
	_base_y = position.y
	_build_visual()
	_play_materialize_intro()

func configure_spawn_presentation(_spawn_kind: String) -> void:
	_uses_external_pedestal = true
	for node_name in ["PickupBase", "PickupGlow", "PickupTrim"]:
		var node := get_node_or_null("PowerupPickupVisual/%s" % node_name) as MeshInstance3D
		if node:
			node.visible = false
	if _icon_root:
		_icon_base_y = 0.98
		_icon_root.position.y = _icon_base_y
		_icon_root.scale = Vector3.ONE * 1.10

func _ready() -> void:
	add_to_group("powerup_pickup")
	add_to_group("combat_pickup")
	_base_y = position.y
	body_entered.connect(_on_body_entered)

func _process(delta: float) -> void:
	_elapsed += delta
	if _icon_root:
		_icon_root.rotate_y(delta * 0.92)
		_icon_root.position.y = _icon_base_y + sin(_elapsed * 3.4) * 0.08
	position.y = _base_y + sin(_elapsed * 2.7) * 0.13

func _on_body_entered(body: Node3D) -> void:
	if not body.has_method("apply_powerup"):
		return
	if not bool(body.call("apply_powerup", powerup_id)):
		return
	_animate_pickup_to_character(body)
	_spawn_pickup_burst()
	picked_up.emit()
	queue_free()

func get_visual_debug() -> Dictionary:
	return {
		"powerup_id": String(powerup_id),
		"accent_color": _accent_color,
		"has_icon": _icon_root != null,
		"uses_external_pedestal": _uses_external_pedestal,
	}

func _build_visual() -> void:
	if _visual_root == null:
		_visual_root = Node3D.new()
		_visual_root.name = "PowerupPickupVisual"
		add_child(_visual_root)
	for child in _visual_root.get_children():
		child.queue_free()

	_add_cylinder(_visual_root, "PickupBase", Vector3(0, -0.48, 0), 1.48, 0.23, _material(Color("#303545"), Color("#303545"), 0.0, 1.0), 32)
	_add_cylinder(_visual_root, "PickupGlow", Vector3(0, -0.29, 0), 1.08, 0.08, _material(Color(_accent_color.r, _accent_color.g, _accent_color.b, 0.48), _accent_color, 0.72, 0.48), 32)
	var trim := MeshInstance3D.new()
	trim.name = "PickupTrim"
	var trim_mesh := TorusMesh.new()
	trim_mesh.inner_radius = 1.22
	trim_mesh.outer_radius = 1.38
	trim_mesh.rings = 32
	trim_mesh.ring_segments = 8
	trim.mesh = trim_mesh
	trim.position.y = -0.24
	trim.material_override = _material(Color("#687386"), Color("#687386"), 0.0, 1.0)
	trim.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_visual_root.add_child(trim)

	_icon_root = Node3D.new()
	_icon_root.name = "PowerupIcon"
	_icon_base_y = 0.46
	_icon_root.position = Vector3(0, _icon_base_y, 0)
	_visual_root.add_child(_icon_root)
	match powerup_id:
		PowerupCatalog.SPEED:
			_build_speed_icon()
		PowerupCatalog.CLONE:
			_build_clone_icon()
		PowerupCatalog.FURY:
			_build_fury_icon()

func _build_speed_icon() -> void:
	var core := _add_sphere(_icon_root, "SpeedCore", Vector3(0, 0.10, 0), Vector3(0.46, 0.62, 0.30), _accent_color)
	core.rotation.z = deg_to_rad(-18.0)
	for index in range(3):
		var streak := _add_box(_icon_root, "WindChevron_%d" % index, Vector3(-0.72 + float(index) * 0.18, 0.34 - float(index) * 0.30, 0), Vector3(0.62, 0.10, 0.16), _accent_color.lerp(Color.WHITE, 0.35))
		streak.rotation.z = deg_to_rad(-18.0)

func _build_clone_icon() -> void:
	for index in range(2):
		var side := -1.0 if index == 0 else 1.0
		var body_color := _accent_color.lerp(Color.WHITE, 0.12 + float(index) * 0.18)
		_add_sphere(_icon_root, "CloneBody_%d" % index, Vector3(side * 0.40, 0.08 + float(index) * 0.08, 0), Vector3(0.40, 0.62, 0.32), body_color)
		var band_y := 0.24 + float(index) * 0.08
		_add_cylinder(
			_icon_root,
			"CloneVisorBand_%d" % index,
			Vector3(side * 0.40, band_y, 0.0),
			0.35,
			0.18,
			_material(Color("#241a38"), Color("#241a38"), 0.0, 1.0),
			18
		)
		for face_side in [-1.0, 1.0]:
			_add_box(
				_icon_root,
				"CloneFaceSignal_%d_%s" % [index, "F" if face_side < 0.0 else "B"],
				Vector3(side * 0.40, band_y, face_side * 0.34),
				Vector3(0.18, 0.085, 0.045),
				Color("#ffe06b")
			)

func _build_fury_icon() -> void:
	_add_sphere(_icon_root, "FuryCore", Vector3(0, 0.02, 0), Vector3(0.48, 0.48, 0.36), Color("#ff7a32"))
	for index in range(5):
		var angle := TAU * float(index) / 5.0
		var flame := _add_cone(_icon_root, "FuryFlame_%d" % index, Vector3(cos(angle) * 0.42, 0.50 + float(index % 2) * 0.10, sin(angle) * 0.28), _accent_color.lerp(Color("#ffc24f"), float(index % 2) * 0.45))
		flame.rotation.z = angle * 0.08

func _animate_pickup_to_character(body: Node3D) -> void:
	if _icon_root == null:
		return
	var scene_root := RuntimeGlobals.active_scene(get_tree())
	if scene_root == null:
		return
	var collect_visual := _icon_root
	_icon_root = null
	collect_visual.name = "PowerupCollectVisual"
	collect_visual.reparent(scene_root, true)
	var target_position := body.global_position + Vector3.UP * 1.15
	var tween := collect_visual.create_tween().set_parallel(true)
	tween.tween_property(collect_visual, "global_position", target_position, 0.14).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_property(collect_visual, "scale", Vector3.ONE * 0.12, 0.14).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tween.tween_property(collect_visual, "rotation:y", collect_visual.rotation.y + PI, 0.14)
	tween.chain().tween_callback(collect_visual.queue_free)

func _spawn_pickup_burst() -> void:
	var scene_root := RuntimeGlobals.active_scene(get_tree())
	if scene_root == null:
		return
	var burst := Node3D.new()
	burst.name = "PowerupPickupBurst"
	scene_root.add_child(burst)
	burst.global_position = global_position + Vector3.UP * 0.12
	for index in range(7):
		var angle := TAU * float(index) / 7.0
		var shard := _add_box(burst, "PowerupShard_%d" % index, Vector3(cos(angle) * 0.70, 0.22, sin(angle) * 0.70), Vector3(0.10, 0.32, 0.28), _accent_color.lerp(Color.WHITE, 0.32))
		shard.rotation.y = -angle
	var tween := burst.create_tween().set_parallel(true)
	tween.tween_property(burst, "scale", Vector3.ONE * 1.55, 0.18).set_ease(Tween.EASE_OUT)
	tween.tween_property(burst, "position:y", burst.position.y + 0.24, 0.18)
	tween.chain().tween_callback(burst.queue_free)

func _play_materialize_intro() -> void:
	if _icon_root == null:
		return
	_icon_root.scale = Vector3(0.28, 1.42, 0.28)
	var tween := create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(_icon_root, "scale", Vector3(1.08, 0.94, 1.08), 0.16)
	tween.tween_property(_icon_root, "scale", Vector3.ONE, 0.08)

func _add_box(parent: Node3D, node_name: String, pos: Vector3, size: Vector3, color: Color) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.name = node_name
	var mesh := BoxMesh.new()
	mesh.size = size
	instance.mesh = mesh
	instance.position = pos
	instance.material_override = _material(color, color, 0.55, color.a)
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(instance)
	return instance

func _add_sphere(parent: Node3D, node_name: String, pos: Vector3, visual_scale: Vector3, color: Color) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.name = node_name
	var mesh := SphereMesh.new()
	mesh.radius = 1.0
	mesh.height = 2.0
	mesh.radial_segments = 14
	mesh.rings = 7
	instance.mesh = mesh
	instance.position = pos
	instance.scale = visual_scale
	instance.material_override = _material(color, color, 0.62, color.a)
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(instance)
	return instance

func _add_cone(parent: Node3D, node_name: String, pos: Vector3, color: Color) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.name = node_name
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.04
	mesh.bottom_radius = 0.19
	mesh.height = 0.62
	mesh.radial_segments = 10
	instance.mesh = mesh
	instance.position = pos
	instance.material_override = _material(color, color, 0.90, color.a)
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(instance)
	return instance

func _add_cylinder(parent: Node3D, node_name: String, pos: Vector3, radius: float, height: float, material: Material, segments: int) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.name = node_name
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = segments
	instance.mesh = mesh
	instance.position = pos
	instance.material_override = material
	parent.add_child(instance)
	return instance

func _material(albedo: Color, emission: Color, energy: float, alpha: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(albedo.r, albedo.g, albedo.b, alpha)
	material.roughness = 0.56
	if alpha < 0.99:
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.emission_enabled = energy > 0.0
	material.emission = emission
	material.emission_energy_multiplier = energy
	return material
