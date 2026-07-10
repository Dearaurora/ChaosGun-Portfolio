extends Area3D
class_name Projectile

const RuntimeGlobals = preload("res://scripts/globals/runtime_globals.gd")
const HitEffectScene: PackedScene = preload("res://scenes/effects/hit_effect.tscn")

## 鐢?Weapon 鍦ㄥ彂灏勬椂娉ㄥ叆锛屼笉鍐嶇‖缂栫爜
var speed: float = 60.0
var knockback_power: float = 18.0
var damage: float = 0.0
var direction: Vector3 = Vector3.FORWARD
var shooter: Node3D = null
var lifetime: float = 2.0
var projectile_color: Color = Color("#ffce3a")

var _visual_weapon_id: StringName = &"pistol"
var _visual_profile: Dictionary = {}
var _visual_root: Node3D = null
var _rim: MeshInstance3D = null
var _core: MeshInstance3D = null
var _trail: MeshInstance3D = null
var _trajectory_underlay: MeshInstance3D = null
var _trajectory_core: MeshInstance3D = null
var _lead_spark: MeshInstance3D = null
var _hit := false  # 闃叉灏勭嚎鍜?Area3D 淇″彿閲嶅瑙﹀彂

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	get_tree().create_timer(lifetime).timeout.connect(queue_free)
	_hide_scene_placeholder_meshes()
	_rebuild_projectile_visual()

func _physics_process(delta: float) -> void:
	if _hit:
		return

	var move_vec = direction * speed * delta
	var move_dist = move_vec.length()

	# --- 灏勭嚎妫€娴嬶細闃叉楂橀€熷脊绌挎ā ---
	if move_dist > 0.01:
		var space_state = get_world_3d().direct_space_state
		var query = PhysicsRayQueryParameters3D.create(
			global_position, global_position + move_vec)
		# 鎺掗櫎灏勬墜鐨勭鎾炰綋
		if shooter:
			query.exclude = [shooter.get_rid()]
		var result = space_state.intersect_ray(query)
		if result:
			# 灏勭嚎鍛戒腑 鈫?绉诲姩鍒板懡涓偣骞惰Е鍙戝嚮涓?
			global_position = result.position
			_handle_hit(result.collider)
			return

	# 鏃犲懡涓紝姝ｅ父绉诲姩
	global_position += move_vec

	if _trail:
		var trail_length := _profile_float("trail_length", 0.65)
		var body_length := _profile_float("body_length", 0.72)
		var pulse := 0.94 + sin(Time.get_ticks_msec() * 0.018) * 0.04
		_trail.scale.z = trail_length * pulse
		_trail.position.z = body_length * 0.48 + _trail.scale.z * 0.5
	if _trajectory_core:
		var trajectory_length := _profile_float("trajectory_length", 1.55)
		var trajectory_body_length := _profile_float("body_length", 0.72)
		var pulse := 0.97 + sin(Time.get_ticks_msec() * 0.022) * 0.025
		_trajectory_core.scale.z = trajectory_length * 0.88 * pulse
		_trajectory_core.position.z = trajectory_body_length * 0.44 + _trajectory_core.scale.z * 0.5
	if _trajectory_underlay and _trajectory_core:
		_trajectory_underlay.scale.z = max(_trajectory_underlay.scale.z, _trajectory_core.scale.z + 0.12)

func _on_body_entered(body: Node3D) -> void:
	if _hit:
		return
	if body == shooter:
		return
	_handle_hit(body)

func _handle_hit(body: Node3D) -> void:
	if _hit:
		return
	_hit = true
	if body.has_method("apply_hit"):
		body.apply_hit(direction * knockback_power, damage, shooter)
	elif body.has_method("apply_knockback"):
		body.apply_knockback(direction * knockback_power)
	# 鍑讳腑鐗规晥
	_spawn_hit_effect()
	queue_free()

func configure_visual_profile(weapon_id: StringName, color: Color) -> void:
	_visual_weapon_id = weapon_id
	projectile_color = color
	_visual_profile = _profile_for_weapon(weapon_id)
	if is_inside_tree():
		_rebuild_projectile_visual()

func get_visual_profile_debug() -> Dictionary:
	if _visual_profile.is_empty():
		_visual_profile = _profile_for_weapon(_visual_weapon_id)
	var copy := _visual_profile.duplicate(true)
	copy["weapon_id"] = String(_visual_weapon_id)
	copy["core_color"] = projectile_color
	return copy

func _rebuild_projectile_visual() -> void:
	if _visual_profile.is_empty():
		_visual_profile = _profile_for_weapon(_visual_weapon_id)
	if _visual_root and is_instance_valid(_visual_root):
		_visual_root.queue_free()

	_visual_root = Node3D.new()
	_visual_root.name = "ProjectileVisual"
	add_child(_visual_root)

	var body_length := _profile_float("body_length", 0.72)
	var body_radius := _profile_float("body_radius", 0.18)
	var trail_length := _profile_float("trail_length", 0.62)
	var trail_width := _profile_float("trail_width", body_radius * 0.72)
	var trail_alpha := _profile_float("trail_alpha", 0.34)
	var trajectory_length := _profile_float("trajectory_length", 1.55)
	var trajectory_width := _profile_float("trajectory_width", body_radius * 1.25)
	var trajectory_alpha := _profile_float("trajectory_alpha", 0.58)
	var outline_alpha := _profile_float("outline_alpha", 0.62)

	var rim_color := Color("#141826")
	_trajectory_underlay = _add_box_mesh(
		"TrajectoryUnderlay",
		Vector3(0.0, -0.045, body_length * 0.42 + trajectory_length * 0.5),
		Vector3(trajectory_width + 0.105, 0.025, trajectory_length + 0.18),
		_make_projectile_material(rim_color, rim_color, 0.0, outline_alpha, false)
	)
	_trajectory_core = _add_box_mesh(
		"TrajectoryCore",
		Vector3(0.0, -0.018, body_length * 0.44 + trajectory_length * 0.44),
		Vector3(trajectory_width, 0.018, trajectory_length * 0.88),
		_make_projectile_material(projectile_color.lerp(Color.WHITE, 0.08), projectile_color, 3.2, trajectory_alpha, true)
	)
	_rim = _add_blob_mesh(
		"BulletRim",
		Vector3(0.0, -0.018, 0.0),
		Vector3(body_radius + 0.045, body_radius * 0.46, body_length * 0.52 + 0.035),
		_make_projectile_material(rim_color, rim_color, 0.0, 1.0, false)
	)
	_core = _add_blob_mesh(
		"BulletCore",
		Vector3(0.0, 0.028, -0.035),
		Vector3(body_radius, body_radius * 0.40, body_length * 0.48),
		_make_projectile_material(projectile_color.lerp(Color.WHITE, 0.18), projectile_color, 3.4, 0.96, true)
	)
	var hot_center := _add_blob_mesh(
		"BulletHotCenter",
		Vector3(0.0, 0.055, -body_length * 0.22),
		Vector3(body_radius * 0.46, body_radius * 0.18, body_length * 0.18),
		_make_projectile_material(Color.WHITE, projectile_color, 4.6, 0.88, true)
	)
	hot_center.visible = true
	_lead_spark = _add_blob_mesh(
		"LeadSpark",
		Vector3(0.0, 0.075, -body_length * 0.44),
		Vector3(body_radius * 0.54, body_radius * 0.26, body_radius * 0.54),
		_make_projectile_material(Color.WHITE, projectile_color, 5.4, 0.92, true)
	)

	_trail = MeshInstance3D.new()
	_trail.name = "ShortTrail"
	var trail_mesh := BoxMesh.new()
	trail_mesh.size = Vector3(1.0, 1.0, 1.0)
	_trail.mesh = trail_mesh
	_trail.position = Vector3(0.0, 0.0, body_length * 0.48 + trail_length * 0.5)
	_trail.scale = Vector3(trail_width, body_radius * 0.18, trail_length)
	_trail.material_override = _make_projectile_material(projectile_color, projectile_color, 2.2, trail_alpha, true)
	_visual_root.add_child(_trail)

func set_projectile_color(color: Color) -> void:
	projectile_color = color
	if is_inside_tree():
		_rebuild_projectile_visual()

func _hide_scene_placeholder_meshes() -> void:
	for child in get_children():
		if child is MeshInstance3D:
			var mesh_instance := child as MeshInstance3D
			if not String(mesh_instance.name).begins_with("Bullet") and mesh_instance.name != "ShortTrail":
				mesh_instance.visible = false

func _add_blob_mesh(mesh_name: String, pos: Vector3, visual_scale: Vector3, mat: StandardMaterial3D) -> MeshInstance3D:
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = mesh_name
	var mesh := SphereMesh.new()
	mesh.radius = 1.0
	mesh.height = 2.0
	mesh.radial_segments = 14
	mesh.rings = 6
	mesh_instance.mesh = mesh
	mesh_instance.position = pos
	mesh_instance.scale = visual_scale
	mesh_instance.material_override = mat
	_visual_root.add_child(mesh_instance)
	return mesh_instance

func _add_box_mesh(mesh_name: String, pos: Vector3, visual_scale: Vector3, mat: StandardMaterial3D) -> MeshInstance3D:
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = mesh_name
	var mesh := BoxMesh.new()
	mesh.size = Vector3.ONE
	mesh_instance.mesh = mesh
	mesh_instance.position = pos
	mesh_instance.scale = visual_scale
	mesh_instance.material_override = mat
	_visual_root.add_child(mesh_instance)
	return mesh_instance

func _make_projectile_material(albedo: Color, emission: Color, energy: float, alpha: float, additive: bool) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA if alpha < 0.99 else BaseMaterial3D.TRANSPARENCY_DISABLED
	mat.albedo_color = Color(albedo.r, albedo.g, albedo.b, alpha)
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.emission_enabled = energy > 0.0
	mat.emission = emission
	mat.emission_energy_multiplier = energy
	if additive:
		mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	return mat

func _profile_float(key: String, fallback: float) -> float:
	if _visual_profile.has(key):
		return float(_visual_profile[key])
	return fallback

func _profile_for_weapon(weapon_id: StringName) -> Dictionary:
	match weapon_id:
		&"smg":
			return {
				"body_length": 0.78,
				"body_radius": 0.16,
				"trail_length": 0.64,
				"trail_width": 0.12,
				"trail_alpha": 0.30,
				"trajectory_length": 1.35,
				"trajectory_width": 0.22,
				"trajectory_alpha": 0.54,
				"outline_alpha": 0.56,
			}
		&"ak_rifle":
			return {
				"body_length": 1.18,
				"body_radius": 0.28,
				"trail_length": 0.88,
				"trail_width": 0.18,
				"trail_alpha": 0.34,
				"trajectory_length": 2.05,
				"trajectory_width": 0.34,
				"trajectory_alpha": 0.60,
				"outline_alpha": 0.64,
			}
		&"sniper":
			return {
				"body_length": 1.40,
				"body_radius": 0.16,
				"trail_length": 1.16,
				"trail_width": 0.11,
				"trail_alpha": 0.38,
				"trajectory_length": 2.65,
				"trajectory_width": 0.24,
				"trajectory_alpha": 0.58,
				"outline_alpha": 0.62,
			}
		_:
			return {
				"body_length": 0.98,
				"body_radius": 0.24,
				"trail_length": 0.75,
				"trail_width": 0.16,
				"trail_alpha": 0.32,
				"trajectory_length": 1.65,
				"trajectory_width": 0.28,
				"trajectory_alpha": 0.58,
				"outline_alpha": 0.62,
			}

func _spawn_hit_effect() -> void:

	var hit = HitEffectScene.instantiate()
	var scene_root = RuntimeGlobals.active_scene(get_tree())
	if scene_root == null:
		return
	scene_root.add_child(hit)
	hit.global_position = global_position
	var tw = hit.create_tween()
	tw.tween_property(hit, "scale", Vector3.ZERO, 0.25).set_ease(Tween.EASE_IN)
	tw.tween_callback(hit.queue_free)

