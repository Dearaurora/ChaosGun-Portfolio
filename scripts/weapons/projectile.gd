extends Area3D
class_name Projectile

signal impact_resolved(position: Vector3, direction: Vector3, weapon_id: StringName)

const RuntimeGlobals = preload("res://scripts/globals/runtime_globals.gd")
const HitEffectScene: PackedScene = preload("res://scenes/effects/hit_effect.tscn")
const CombatVisualResourceCache = preload("res://scripts/effects/combat_visual_resource_cache.gd")

const BULLET_GOLD := Color("#ffc83d")
const BULLET_WHITE := Color("#fff8d8")
const BULLET_TRAIL_GOLD := Color("#ffb72f")

## 鐢?Weapon 鍦ㄥ彂灏勬椂娉ㄥ叆锛屼笉鍐嶇‖缂栫爜
var speed: float = 60.0
var knockback_power: float = 18.0
var damage: float = 0.0
var direction: Vector3 = Vector3.FORWARD
var shooter: Node3D = null
var lifetime: float = 2.0
var projectile_color: Color = Color("#ffce3a")
var _knockback_origin: Vector3 = Vector3.ZERO
var _close_range_knockback_multiplier: float = 1.0
var _knockback_falloff_start: float = 0.0
var _knockback_falloff_end: float = 0.0
var _far_range_knockback_multiplier: float = 1.0
var _collision_exclusions: Array[RID] = []
var _credited_attacker: Node3D = null

var _visual_weapon_id: StringName = &"pistol"
var _visual_profile: Dictionary = {}
var _visual_root: Node3D = null
var _rim: MeshInstance3D = null
var _core: MeshInstance3D = null
var _trail: MeshInstance3D = null
var _trail_core: MeshInstance3D = null
var _trajectory_underlay: MeshInstance3D = null
var _trajectory_core: MeshInstance3D = null
var _lead_spark: MeshInstance3D = null
var _visual_build_count := 0
var _hit := false  # 闃叉灏勭嚎鍜?Area3D 淇″彿閲嶅瑙﹀彂

func _ready() -> void:
	add_to_group("projectile")
	body_entered.connect(_on_body_entered)
	_cache_collision_exclusions()
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
		query.exclude = _collision_exclusions
		var result = space_state.intersect_ray(query)
		if result:
			if _is_friendly_character(result.collider):
				global_position += move_vec
				return
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
		_trail.position.z = body_length * 0.12
		if _trail_core:
			_trail_core.scale.z = trail_length * 0.48 * pulse
			_trail_core.position.z = body_length * 0.10

func _on_body_entered(body: Node3D) -> void:
	if _hit:
		return
	if is_instance_valid(shooter) and body == shooter:
		return
	if _is_friendly_character(body):
		return
	_handle_hit(body)

func _handle_hit(body: Node3D) -> void:
	if _hit:
		return
	if _is_friendly_character(body):
		return
	_hit = true
	var distance_multiplier := get_knockback_multiplier_for_distance(
		_knockback_origin.distance_to(global_position)
	)
	var attacker := _credited_attacker if is_instance_valid(_credited_attacker) else null
	if body.has_method("apply_hit"):
		body.apply_hit(
			direction * knockback_power * distance_multiplier,
			damage,
			attacker,
			_visual_weapon_id
		)
	elif body.has_method("apply_knockback"):
		body.apply_knockback(direction * knockback_power * distance_multiplier)
	# 鍑讳腑鐗规晥
	_spawn_hit_effect()
	impact_resolved.emit(global_position, direction, _visual_weapon_id)
	queue_free()

func _cache_collision_exclusions() -> void:
	_collision_exclusions.clear()
	_credited_attacker = null
	if not is_instance_valid(shooter):
		return
	_credited_attacker = shooter
	if shooter is CollisionObject3D:
		_collision_exclusions.append((shooter as CollisionObject3D).get_rid())
	if not (shooter is BaseCharacter):
		return
	_credited_attacker = (shooter as BaseCharacter).get_combat_identity()
	for node in get_tree().get_nodes_in_group("player"):
		if node is BaseCharacter and (shooter as BaseCharacter).is_friendly_to(node as BaseCharacter):
			var rid := (node as BaseCharacter).get_rid()
			if rid not in _collision_exclusions:
				_collision_exclusions.append(rid)

func _is_friendly_character(body: Node) -> bool:
	return is_instance_valid(_credited_attacker) and _credited_attacker is BaseCharacter and body is BaseCharacter and (_credited_attacker as BaseCharacter).is_friendly_to(body as BaseCharacter)

func configure_visual_profile(weapon_id: StringName, color: Color) -> void:
	_visual_weapon_id = weapon_id
	projectile_color = color
	_visual_profile = _profile_for_weapon(weapon_id)
	if is_inside_tree():
		_rebuild_projectile_visual()

func configure_knockback_falloff(
	origin: Vector3,
	close_multiplier: float,
	falloff_start: float,
	falloff_end: float,
	far_multiplier: float
) -> void:
	_knockback_origin = origin
	_close_range_knockback_multiplier = maxf(0.0, close_multiplier)
	_knockback_falloff_start = maxf(0.0, falloff_start)
	_knockback_falloff_end = maxf(_knockback_falloff_start, falloff_end)
	_far_range_knockback_multiplier = maxf(0.0, far_multiplier)

func get_knockback_multiplier_for_distance(distance: float) -> float:
	if _knockback_falloff_end <= _knockback_falloff_start + 0.001:
		return _close_range_knockback_multiplier
	var ratio := clampf(
		(distance - _knockback_falloff_start) / (_knockback_falloff_end - _knockback_falloff_start),
		0.0,
		1.0
	)
	var eased_ratio := smoothstep(0.0, 1.0, ratio)
	return lerpf(_close_range_knockback_multiplier, _far_range_knockback_multiplier, eased_ratio)

func get_visual_profile_debug() -> Dictionary:
	if _visual_profile.is_empty():
		_visual_profile = _profile_for_weapon(_visual_weapon_id)
	var copy := _visual_profile.duplicate(true)
	copy["weapon_id"] = String(_visual_weapon_id)
	copy["core_color"] = BULLET_WHITE
	copy["shell_color"] = BULLET_GOLD
	copy["trail_color"] = BULLET_TRAIL_GOLD
	copy["weapon_accent_color"] = projectile_color
	copy["build_count"] = _visual_build_count
	return copy

func _rebuild_projectile_visual() -> void:
	_visual_build_count += 1
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
	_trajectory_underlay = null
	_trajectory_core = null
	_rim = _add_bolt_mesh(
		"BulletRim",
		Vector3(0.0, -0.018, 0.0),
		body_length,
		body_radius,
		_make_projectile_material(BULLET_GOLD, BULLET_GOLD, 0.92, 1.0, false)
	)
	_core = _add_bolt_mesh(
		"BulletCore",
		Vector3(0.0, 0.016, -body_length * 0.12),
		body_length * 0.52,
		body_radius * 0.42,
		_make_projectile_material(BULLET_WHITE, BULLET_WHITE, 1.20, 1.0, false)
	)
	_lead_spark = null

	_trail = _add_tail_mesh(
		"ShortTrail",
		Vector3(0.0, 0.0, body_length * 0.12),
		trail_width,
		_make_projectile_material(BULLET_TRAIL_GOLD, BULLET_TRAIL_GOLD, 0.86, trail_alpha + 0.10, true)
	)
	_trail.scale = Vector3(trail_width * 1.16, 1.0, trail_length)
	_trail_core = _add_tail_mesh(
		"ShortTrailCore",
		Vector3(0.0, 0.010, body_length * 0.10),
		trail_width * 0.28,
		_make_projectile_material(BULLET_WHITE, BULLET_WHITE, 1.18, minf(0.68, trail_alpha + 0.25), true)
	)
	_trail_core.scale = Vector3(trail_width * 0.28, 1.0, trail_length * 0.48)

func set_projectile_color(color: Color) -> void:
	if projectile_color.is_equal_approx(color):
		return
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
	mesh_instance.mesh = CombatVisualResourceCache.sphere_mesh(14, 6)
	mesh_instance.position = pos
	mesh_instance.scale = visual_scale
	mesh_instance.material_override = mat
	_visual_root.add_child(mesh_instance)
	return mesh_instance

func _add_bolt_mesh(mesh_name: String, pos: Vector3, bolt_length: float, bolt_radius: float, mat: StandardMaterial3D) -> MeshInstance3D:
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = mesh_name
	mesh_instance.mesh = CombatVisualResourceCache.teardrop_mesh(bolt_length, bolt_radius)
	mesh_instance.position = pos
	mesh_instance.material_override = mat
	mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_visual_root.add_child(mesh_instance)
	return mesh_instance

func _add_tail_mesh(mesh_name: String, pos: Vector3, _trail_width: float, mat: StandardMaterial3D) -> MeshInstance3D:
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = mesh_name
	mesh_instance.mesh = CombatVisualResourceCache.tail_mesh()
	mesh_instance.position = pos
	mesh_instance.material_override = mat
	mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_visual_root.add_child(mesh_instance)
	return mesh_instance

func _add_box_mesh(mesh_name: String, pos: Vector3, visual_scale: Vector3, mat: StandardMaterial3D) -> MeshInstance3D:
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = mesh_name
	mesh_instance.mesh = CombatVisualResourceCache.box_mesh()
	mesh_instance.position = pos
	mesh_instance.scale = visual_scale
	mesh_instance.material_override = mat
	_visual_root.add_child(mesh_instance)
	return mesh_instance

func _make_projectile_material(albedo: Color, emission: Color, energy: float, alpha: float, additive: bool) -> StandardMaterial3D:
	return CombatVisualResourceCache.material(albedo, emission, energy, alpha, additive)

func _profile_float(key: String, fallback: float) -> float:
	if _visual_profile.has(key):
		return float(_visual_profile[key])
	return fallback

func _profile_for_weapon(weapon_id: StringName) -> Dictionary:
	match weapon_id:
		&"smg":
			return {
				"body_length": 0.52,
				"body_radius": 0.14,
				"trail_length": 0.42,
				"trail_width": 0.11,
				"trail_alpha": 0.30,
				"shape": "yellow_white_teardrop",
			}
		&"ak_rifle":
			return {
				"body_length": 0.86,
				"body_radius": 0.20,
				"trail_length": 0.82,
				"trail_width": 0.19,
				"trail_alpha": 0.42,
				"shape": "yellow_white_teardrop",
			}
		&"sniper":
			return {
				"body_length": 0.82,
				"body_radius": 0.16,
				"trail_length": 0.86,
				"trail_width": 0.13,
				"trail_alpha": 0.38,
				"shape": "yellow_white_teardrop",
			}
		&"gatling":
			return {
				"body_length": 0.48,
				"body_radius": 0.12,
				"trail_length": 0.38,
				"trail_width": 0.09,
				"trail_alpha": 0.28,
				"shape": "yellow_white_teardrop",
			}
		&"shotgun":
			return {
				"body_length": 0.60,
				"body_radius": 0.18,
				"trail_length": 0.48,
				"trail_width": 0.14,
				"trail_alpha": 0.27,
				"shape": "yellow_white_teardrop",
			}
		_:
			return {
				"body_length": 0.62,
				"body_radius": 0.18,
				"trail_length": 0.56,
				"trail_width": 0.14,
				"trail_alpha": 0.32,
				"shape": "yellow_white_teardrop",
			}

func _spawn_hit_effect() -> void:
	var hit = HitEffectScene.instantiate() as Node3D
	if hit and hit.has_method("configure"):
		hit.call("configure", projectile_color, _visual_weapon_id, direction)
	var scene_root = RuntimeGlobals.active_scene(get_tree())
	if scene_root == null:
		return
	scene_root.add_child(hit)
	hit.global_position = global_position

