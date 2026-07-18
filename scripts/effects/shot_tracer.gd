extends Node3D
class_name ShotTracer

const CombatVisualResourceCache = preload("res://scripts/effects/combat_visual_resource_cache.gd")
const TRACER_GOLD := Color("#ffc83d")
const TRACER_WHITE := Color("#fff8d8")

var _length: float = 5.5
var _width: float = 0.22
var _lifetime: float = 0.10
var _color: Color = Color("#ffce3a")
var _timer_started := false
var _style: StringName = &"yellow_white_teardrop"
var _accent_count: int = 0
var _visual_build_count := 0

func setup(start_position: Vector3, direction: Vector3, color: Color, profile: Dictionary = {}) -> void:
	if is_inside_tree():
		global_position = start_position
	else:
		position = start_position
	_color = color
	_length = clampf(float(profile.get("length", _length)), 1.0, 6.0)
	_width = clampf(float(profile.get("width", _width)), 0.08, 0.32)
	_lifetime = clampf(float(profile.get("lifetime", _lifetime)), 0.035, 0.10)
	_style = &"yellow_white_teardrop"

	var aim_dir := direction
	aim_dir.y = 0.0
	if aim_dir.length_squared() <= 0.001:
		aim_dir = Vector3.FORWARD
	transform.basis = Basis.looking_at(aim_dir.normalized(), Vector3.UP)

	_build_visual()
	if is_inside_tree() and not _timer_started:
		_start_lifetime()

func get_visual_debug() -> Dictionary:
	return {
		"length": _length,
		"width": _width,
		"lifetime": _lifetime,
		"color": TRACER_GOLD,
		"core_color": TRACER_WHITE,
		"weapon_accent_color": _color,
		"shape": String(_style),
		"accent_count": _accent_count,
		"build_count": _visual_build_count,
	}

func _ready() -> void:
	if get_child_count() == 0:
		_build_visual()
	if not _timer_started:
		_start_lifetime()

func _build_visual() -> void:
	_visual_build_count += 1
	for child in get_children():
		child.free()
	_accent_count = 0

	_add_teardrop(
		"TracerGlow",
		_length,
		_width,
		Vector3(0.0, 0.0, -_length * 0.50),
		_make_material(TRACER_GOLD, TRACER_GOLD, 0.92, 0.82, true)
	)
	_add_teardrop(
		"TracerCore",
		_length * 0.52,
		_width * 0.42,
		Vector3(0.0, 0.014, -_length * 0.70),
		_make_material(TRACER_WHITE, TRACER_WHITE, 1.18, 0.92, true)
	)


func _add_teardrop(
	mesh_name: String,
	length: float,
	radius: float,
	pos: Vector3,
	mat: StandardMaterial3D
) -> MeshInstance3D:
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = mesh_name
	mesh_instance.mesh = CombatVisualResourceCache.teardrop_mesh(length, radius)
	mesh_instance.position = pos
	mesh_instance.material_override = mat
	mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mesh_instance)
	return mesh_instance

func _add_tracer_head(head_scale: float) -> void:
	_add_sphere(
		"TracerAccent_%d" % _accent_count,
		Vector3(0.0, 0.014, -_length * head_scale),
		Vector3(_width * 0.78, 0.014, _width * 1.15),
		_make_material(_color.lightened(0.10), _color, 1.85, 0.82, true)
	)
	_accent_count += 1

func _start_lifetime() -> void:
	_timer_started = true
	var hold := _lifetime * 0.28
	var fade := maxf(0.02, _lifetime - hold)
	var tw := create_tween()
	tw.tween_interval(hold)
	tw.tween_property(self, "scale", Vector3(1.0, 0.58, 0.78), fade).set_ease(Tween.EASE_IN)
	tw.tween_callback(queue_free)

func _add_box(mesh_name: String, pos: Vector3, visual_scale: Vector3, mat: StandardMaterial3D) -> MeshInstance3D:
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = mesh_name
	mesh_instance.mesh = CombatVisualResourceCache.box_mesh()
	mesh_instance.position = pos
	mesh_instance.scale = visual_scale
	mesh_instance.material_override = mat
	mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mesh_instance)
	return mesh_instance

func _add_tapered_streak(mesh_name: String, streak_length: float, streak_width: float, y_offset: float, mat: StandardMaterial3D) -> MeshInstance3D:
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = mesh_name
	mesh_instance.mesh = CombatVisualResourceCache.tapered_streak_mesh(streak_length, streak_width)
	mesh_instance.position.y = y_offset
	mesh_instance.material_override = mat
	mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mesh_instance)
	return mesh_instance

func _add_sphere(mesh_name: String, pos: Vector3, visual_scale: Vector3, mat: StandardMaterial3D) -> MeshInstance3D:
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = mesh_name
	mesh_instance.mesh = CombatVisualResourceCache.sphere_mesh(14, 6)
	mesh_instance.position = pos
	mesh_instance.scale = visual_scale
	mesh_instance.material_override = mat
	mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mesh_instance)
	return mesh_instance

func _make_material(albedo: Color, emission: Color, energy: float, alpha: float, additive: bool) -> StandardMaterial3D:
	return CombatVisualResourceCache.material(albedo, emission, energy, alpha, additive)
