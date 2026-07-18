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
var _sky_plane: MeshInstance3D = null
var _layer_a: Node3D = null
var _layer_b: Node3D = null
var _puff_count := 0


func _ready() -> void:
	rebuild()


func _process(delta: float) -> void:
	advance_motion(delta)


func rebuild() -> void:
	set_process(false)
	for child: Node in get_children():
		remove_child(child)
		child.free()

	_elapsed = 0.0
	_puff_count = 0
	set_meta("visual_only", true)
	set_meta("collision_owner", "Godot gameplay scene")
	set_meta("cloud_vortex_layer_speeds", Vector2(LAYER_A_SPEED, LAYER_B_SPEED))
	if not is_in_group(&"momentum_circuit_cloud_vortex"):
		add_to_group(&"momentum_circuit_cloud_vortex")

	_build_sky_plane()
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
		_layer_a.rotation.y = fposmod(_layer_a.rotation.y + LAYER_A_SPEED * safe_delta, TAU)
	if is_instance_valid(_layer_b):
		_layer_b.rotation.y = fposmod(_layer_b.rotation.y + LAYER_B_SPEED * safe_delta, TAU)


func get_debug_state() -> Dictionary:
	return {
		"ready": is_instance_valid(_sky_plane) and is_instance_valid(_layer_a) and is_instance_valid(_layer_b),
		"visual_only": bool(get_meta("visual_only", false)),
		"layer_count": LAYER_COUNT,
		"arms_per_layer": ARMS_PER_LAYER,
		"puffs_per_arm": PUFFS_PER_ARM,
		"puff_count": _puff_count,
		"layer_a_speed": LAYER_A_SPEED,
		"layer_b_speed": LAYER_B_SPEED,
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
	var plane := PlaneMesh.new()
	plane.size = SKY_PLANE_SIZE
	plane.subdivide_width = 2
	plane.subdivide_depth = 2
	_sky_plane.mesh = plane
	_sky_plane.position = Vector3(0.0, SKY_Y, 0.0)
	_sky_plane.material_override = _sky_material()
	_sky_plane.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_sky_plane.set_meta("visual_only", true)
	add_child(_sky_plane)


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

	# A softly masked copy of the authored vortex texture forms one continuous
	# cloud-arm veil.  Rotating two veils in opposite directions produces the
	# required slow parallax without the disconnected "polka dot" silhouette of
	# individual sphere puffs.
	var veil := MeshInstance3D.new()
	veil.name = "SpiralCloudVeil"
	var plane := PlaneMesh.new()
	plane.size = SKY_PLANE_SIZE * scale_multiplier
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

void fragment() {
	vec3 color = texture(vortex_texture, UV).rgb;
	ALBEDO = color;
	EMISSION = color * 0.055;
}
"""
	var material := ShaderMaterial.new()
	material.shader = shader
	material.set_shader_parameter("vortex_texture", VORTEX_TEXTURE)
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
	vec3 sample_color = texture(vortex_texture, UV).rgb;
	float warm_cloud = max(sample_color.r - sample_color.b * 0.72, 0.0);
	float cool_streak = max(sample_color.b - sample_color.r * 0.82, 0.0);
	float cloud_mask = smoothstep(0.035, 0.32, warm_cloud + cool_streak * 0.28);
	float radial = length(UV - vec2(0.5));
	float edge_fade = 1.0 - smoothstep(0.46, 0.70, radial);
	vec3 color = mix(sample_color, veil_tint.rgb, 0.22);
	ALBEDO = color;
	EMISSION = color * 0.07;
	ALPHA = cloud_mask * edge_fade * veil_alpha;
}
"""
	var material := ShaderMaterial.new()
	material.shader = shader
	material.set_shader_parameter("vortex_texture", VORTEX_TEXTURE)
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
