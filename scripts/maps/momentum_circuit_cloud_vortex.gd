extends Node3D
class_name MomentumCircuitCloudVortex

## Visual-only, two-layer cloud vortex for Momentum Circuit.
## The arena owns gameplay and collision; this node deliberately creates only
## render geometry and keeps every GeometryInstance3D shadow-disabled.

const LAYER_A_SPEED := 0.003
const LAYER_B_SPEED := -0.008
const LAYER_COUNT := 2
const ARMS_PER_LAYER := 3
const PUFFS_PER_ARM := 1
const SKY_PLANE_SIZE := Vector2(260.0, 240.0)
const SKY_Y := -13.0
const LAYER_A_Y := -11.4
const LAYER_B_Y := -10.0

const VORTEX_TEXTURE := preload(
	"res://assets/textures/generated/momentum_circuit/cloud_vortex_background_v1.png"
)

const SKY_BLUE := Color("#5B8ED8")
const SKY_VIOLET := Color("#756CC5")
const CLOUD_HIGHLIGHT := Color("#FFD1BF")
const CLOUD_SHADOW := Color("#8979B9")

var _elapsed := 0.0
var _layer_a_speed := LAYER_A_SPEED
var _layer_b_speed := LAYER_B_SPEED
var _ev_reduction := 0.50
var _base_texture_path := VORTEX_TEXTURE.resource_path
var _vortex_texture: Texture2D = VORTEX_TEXTURE
var _background_plane_size := SKY_PLANE_SIZE
var _background_exposure := 0.72
var _screen_locked_background := false
var _background_camera: Camera3D = null
var _sky_plane: MeshInstance3D = null
var _sky_material_instance: ShaderMaterial = null
var _layer_a: Node3D = null
var _layer_b: Node3D = null
var _puff_count := 0


func _ready() -> void:
	rebuild()

func configure(config: Dictionary) -> void:
	_layer_a_speed = float(config.get("upper_angular_speed", LAYER_A_SPEED))
	_layer_b_speed = float(config.get("lower_angular_speed", LAYER_B_SPEED))
	_ev_reduction = float(config.get("ev_reduction", 0.50))
	_base_texture_path = String(config.get("base_texture_path", VORTEX_TEXTURE.resource_path))
	if ResourceLoader.exists(_base_texture_path):
		var loaded_texture := load(_base_texture_path) as Texture2D
		if loaded_texture != null:
			_vortex_texture = loaded_texture
	var plane_size_value: Variant = config.get("background_plane_size", [])
	if plane_size_value is Array and (plane_size_value as Array).size() >= 2:
		_background_plane_size = Vector2(
			float((plane_size_value as Array)[0]),
			float((plane_size_value as Array)[1])
		)
	_background_exposure = clampf(float(config.get("background_exposure", 0.72)), 0.1, 1.0)
	_screen_locked_background = bool(config.get("screen_locked_background", false))
	rebuild()


func _process(delta: float) -> void:
	advance_motion(delta)
	_update_screen_locked_background()


func rebuild() -> void:
	set_process(false)
	if is_instance_valid(_sky_plane) and _sky_plane.get_parent() != self:
		_sky_plane.queue_free()
		_sky_plane = null
	for child: Node in get_children():
		remove_child(child)
		child.free()

	_elapsed = 0.0
	_puff_count = 0
	set_meta("visual_only", true)
	set_meta("collision_owner", "Godot gameplay scene")
	set_meta("cloud_vortex_layer_speeds", Vector2(_layer_a_speed, _layer_b_speed))
	set_meta("ev_reduction", _ev_reduction)
	if not is_in_group(&"momentum_circuit_cloud_vortex"):
		add_to_group(&"momentum_circuit_cloud_vortex")

	_build_sky_plane()
	if _screen_locked_background:
		call_deferred("_attach_background_to_camera")
	_layer_a = _build_cloud_layer(
		"CloudHighlightLayer",
		LAYER_A_Y,
		CLOUD_HIGHLIGHT,
		0.14,
		0.0,
		1.12
	)
	_layer_b = _build_cloud_layer(
		"CloudShadowLayer",
		LAYER_B_Y,
		CLOUD_SHADOW,
		0.09,
		0.43,
		1.18
	)
	set_process(true)


func advance_motion(delta: float) -> void:
	var safe_delta := maxf(delta, 0.0)
	_elapsed = fmod(_elapsed + safe_delta, 3600.0)
	if is_instance_valid(_layer_a):
		_layer_a.rotation.y = fposmod(_layer_a.rotation.y + _layer_a_speed * safe_delta, TAU)
	if is_instance_valid(_layer_b):
		_layer_b.rotation.y = fposmod(_layer_b.rotation.y + _layer_b_speed * safe_delta, TAU)
	if is_instance_valid(_sky_material_instance):
		var upper_angle := _elapsed * _layer_a_speed
		var lower_angle := _elapsed * _layer_b_speed
		_sky_material_instance.set_shader_parameter(
			"upper_rotation", Vector2(cos(upper_angle), sin(upper_angle))
		)
		_sky_material_instance.set_shader_parameter(
			"lower_rotation", Vector2(cos(lower_angle), sin(lower_angle))
		)


func get_debug_state() -> Dictionary:
	return {
		"ready": is_instance_valid(_sky_plane) and is_instance_valid(_layer_a) and is_instance_valid(_layer_b),
		"visual_only": bool(get_meta("visual_only", false)),
		"layer_count": LAYER_COUNT,
		"arms_per_layer": ARMS_PER_LAYER,
		"puffs_per_arm": PUFFS_PER_ARM,
		"puff_count": _puff_count,
		"layer_a_speed": _layer_a_speed,
		"layer_b_speed": _layer_b_speed,
		"ev_reduction": _ev_reduction,
		"base_texture_path": _base_texture_path,
		"background_plane_size": _background_plane_size,
		"background_exposure": _background_exposure,
		"screen_locked_background": _screen_locked_background,
		"layer_a_rotation": _layer_a.rotation.y if is_instance_valid(_layer_a) else 0.0,
		"layer_b_rotation": _layer_b.rotation.y if is_instance_valid(_layer_b) else 0.0,
		"elapsed": _elapsed,
		"sky_plane_present": is_instance_valid(_sky_plane),
		"collision_node_count": _count_collision_nodes(self),
		"shadow_caster_count": _count_shadow_casters(self),
	}


func _build_sky_plane() -> void:
	_sky_plane = MeshInstance3D.new()
	_sky_plane.name = "VortexSkyPlane"
	if _screen_locked_background:
		var quad := QuadMesh.new()
		quad.size = _background_plane_size
		_sky_plane.mesh = quad
		_sky_plane.position = Vector3(0.0, 0.0, -240.0)
	else:
		var plane := PlaneMesh.new()
		plane.size = _background_plane_size
		plane.subdivide_width = 2
		plane.subdivide_depth = 2
		_sky_plane.mesh = plane
		_sky_plane.position = Vector3(0.0, SKY_Y, 0.0)
	_sky_material_instance = _sky_material()
	_sky_plane.material_override = _sky_material_instance
	_sky_plane.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_sky_plane.set_meta("visual_only", true)
	add_child(_sky_plane)


func _attach_background_to_camera() -> void:
	if not _screen_locked_background or not is_instance_valid(_sky_plane):
		return
	_background_camera = get_viewport().get_camera_3d()
	if not is_instance_valid(_background_camera):
		var arena := get_parent()
		while arena != null and arena.get_parent() != null:
			if arena.get_node_or_null("GlobalCamera") is Camera3D:
				_background_camera = arena.get_node("GlobalCamera") as Camera3D
				break
			arena = arena.get_parent()
	if not is_instance_valid(_background_camera):
		call_deferred("_attach_background_to_camera")
		return
	_sky_plane.reparent(_background_camera, false)
	_sky_plane.position = Vector3(0.0, 0.0, -240.0)
	_sky_plane.rotation = Vector3.ZERO
	_update_screen_locked_background()


func _update_screen_locked_background() -> void:
	if (
		not _screen_locked_background
		or not is_instance_valid(_sky_plane)
		or not is_instance_valid(_background_camera)
		or not _sky_plane.mesh is QuadMesh
	):
		return
	var viewport_size := get_viewport().get_visible_rect().size
	var aspect := (
		viewport_size.x / maxf(viewport_size.y, 1.0)
		if viewport_size.x > 0.0
		else 1.5
	)
	var height := _background_camera.size * 1.035
	(_sky_plane.mesh as QuadMesh).size = Vector2(height * aspect, height)


func _build_cloud_layer(
	node_name: String,
	world_y: float,
	color: Color,
	alpha: float,
	angular_offset: float,
	scale_multiplier: float
) -> Node3D:
	var layer := Node3D.new()
	layer.name = node_name
	layer.position.y = world_y
	layer.rotation.y = angular_offset
	layer.set_meta("visual_only", true)
	add_child(layer)
	if _screen_locked_background:
		# The camera-attached background shader composites both slow counter-
		# rotating veils in one pass. Keeping separate transparent full-screen
		# planes here would triple fill-rate cost at 1920x1080.
		return layer

	# A softly masked copy of the authored vortex texture forms one continuous
	# cloud-arm veil.  Rotating two veils in opposite directions produces the
	# required slow parallax without the disconnected "polka dot" silhouette of
	# individual sphere puffs.
	var veil := MeshInstance3D.new()
	veil.name = "SpiralCloudVeil"
	var plane := PlaneMesh.new()
	plane.size = _background_plane_size * scale_multiplier
	veil.mesh = plane
	veil.material_override = _cloud_veil_material(color, alpha)
	veil.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	veil.set_meta("visual_only", true)
	layer.add_child(veil)
	_puff_count += 1
	return layer


func _sky_material() -> ShaderMaterial:
	var shader := Shader.new()
	shader.code = """
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_opaque;

uniform sampler2D vortex_texture : source_color, filter_linear_mipmap_anisotropic;
uniform float exposure : hint_range(0.1, 1.0) = 0.72;
uniform vec2 upper_rotation = vec2(1.0, 0.0);
uniform vec2 lower_rotation = vec2(1.0, 0.0);
uniform float composite_motion = 0.0;

vec2 rotate_uv(vec2 uv, vec2 rotation, float scale_factor) {
	vec2 p = (uv - vec2(0.5)) * scale_factor;
	return vec2(
		rotation.x * p.x - rotation.y * p.y,
		rotation.y * p.x + rotation.x * p.y
	) + vec2(0.5);
}

void fragment() {
	vec3 base = texture(vortex_texture, UV).rgb;
	vec3 color = base;
	if (composite_motion > 0.5) {
		vec3 upper = texture(vortex_texture, rotate_uv(UV, upper_rotation, 1.035)).rgb;
		vec3 lower = texture(vortex_texture, rotate_uv(UV, lower_rotation, 1.075)).rgb;
		float lower_screen_mask = smoothstep(0.16, 0.52, UV.y);
		float cloud_mask = smoothstep(0.04, 0.34, base.r - base.b * 0.56);
		float blend_mask = lower_screen_mask * (0.22 + cloud_mask * 0.78);
		color = mix(color, upper, blend_mask * 0.045);
		color = mix(color, lower, blend_mask * 0.030);
	}
	color *= exposure;
	ALBEDO = color;
	EMISSION = color * 0.048;
}
"""
	var material := ShaderMaterial.new()
	material.shader = shader
	material.set_shader_parameter("vortex_texture", _vortex_texture)
	material.set_shader_parameter("exposure", _background_exposure)
	material.set_shader_parameter("upper_rotation", Vector2(1.0, 0.0))
	material.set_shader_parameter("lower_rotation", Vector2(1.0, 0.0))
	material.set_shader_parameter("composite_motion", 1.0 if _screen_locked_background else 0.0)
	return material


func _cloud_veil_material(color: Color, alpha: float) -> ShaderMaterial:
	var shader := Shader.new()
	shader.code = """
shader_type spatial;
render_mode unshaded, cull_disabled, blend_mix, depth_draw_never;

uniform sampler2D vortex_texture : source_color, filter_linear_mipmap_anisotropic;
uniform vec4 veil_tint : source_color = vec4(1.0, 0.82, 0.75, 1.0);
uniform float veil_alpha : hint_range(0.0, 0.35) = 0.12;

void fragment() {
	vec3 sample_color = texture(vortex_texture, UV).rgb * 0.72;
	float warm_cloud = max(sample_color.r - sample_color.b * 0.72, 0.0);
	float cool_streak = max(sample_color.b - sample_color.r * 0.82, 0.0);
	float cloud_mask = smoothstep(0.035, 0.32, warm_cloud + cool_streak * 0.28);
	float radial = length(UV - vec2(0.5));
	float edge_fade = 1.0 - smoothstep(0.46, 0.70, radial);
	vec3 color = mix(sample_color, veil_tint.rgb, 0.22);
	ALBEDO = color;
	EMISSION = color * 0.061;
	ALPHA = cloud_mask * edge_fade * veil_alpha;
}
"""
	var material := ShaderMaterial.new()
	material.shader = shader
	material.set_shader_parameter("vortex_texture", _vortex_texture)
	material.set_shader_parameter("veil_tint", color)
	material.set_shader_parameter("veil_alpha", alpha)
	material.render_priority = -2
	return material


func _count_collision_nodes(root: Node) -> int:
	var count := 1 if root is CollisionObject3D or root is CollisionShape3D else 0
	for child: Node in root.get_children():
		count += _count_collision_nodes(child)
	return count


func _count_shadow_casters(root: Node) -> int:
	var count := 0
	if root is GeometryInstance3D:
		var geometry := root as GeometryInstance3D
		if geometry.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_OFF:
			count += 1
	for child: Node in root.get_children():
		count += _count_shadow_casters(child)
	return count
