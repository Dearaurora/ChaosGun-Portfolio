extends Node3D
class_name MomentumCircuitHoleDepthVFX

const VORTEX_TEXTURE := preload(
	"res://assets/textures/generated/momentum_circuit/cloud_vortex_background_v1.png"
)

var _config: Dictionary = {}
var _hole_count := 0
var _cloud_layer_count := 0
var _shaft_wall_count := 0
var _cloud_texture: Texture2D = VORTEX_TEXTURE


func configure(holes: Array, config: Dictionary) -> void:
	_config = config.duplicate(true)
	for child: Node in get_children():
		remove_child(child)
		child.free()
	_hole_count = 0
	_cloud_layer_count = 0
	_shaft_wall_count = 0
	var texture_path := String(
		_config.get("texture_path", VORTEX_TEXTURE.resource_path)
	)
	if ResourceLoader.exists(texture_path):
		var loaded := load(texture_path) as Texture2D
		if loaded != null:
			_cloud_texture = loaded
	set_meta("visual_only", true)
	set_meta("platform_plane_fall_effect", false)
	for value: Variant in holes:
		if not value is Dictionary:
			continue
		var hole := value as Dictionary
		var points_value: Variant = hole.get("visual_top_outline_world_xz", [])
		if not points_value is Array or (points_value as Array).size() < 3:
			continue
		var polygon := PackedVector2Array()
		for point_value: Variant in points_value as Array:
			var point := point_value as Array
			polygon.append(Vector2(float(point[0]), float(point[1])))
		_build_hole_layers(String(hole.get("id", "hole")), polygon)
		_hole_count += 1


func get_debug_state() -> Dictionary:
	return {
		"visual_only": true,
		"hole_count": _hole_count,
		"cloud_layer_count": _cloud_layer_count,
		"shaft_wall_count": _shaft_wall_count,
		"inner_wall_layers": int(_config.get("inner_wall_layers", 3)),
		"platform_plane_fall_effect": false,
		"collision_node_count": _count_collision_nodes(self),
	}


func _build_hole_layers(hole_id: String, polygon: PackedVector2Array) -> void:
	var shaft_top := float(_config.get("shaft_top_y", -1.0))
	var shaft_mid := float(_config.get("shaft_mid_y", -3.25))
	var shaft_bottom := -absf(float(_config.get("occlusion_depth", 6.4))) + 0.45
	_add_shaft_wall(
		"ShaftWallUpper_%s" % hole_id,
		polygon,
		shaft_top,
		shaft_mid,
		Color("#211A3A"),
	)
	_add_shaft_wall(
		"ShaftWallLower_%s" % hole_id,
		polygon,
		shaft_mid,
		shaft_bottom,
		Color("#0D091B"),
	)

	var occlusion := MeshInstance3D.new()
	occlusion.name = "VoidOcclusion_%s" % hole_id
	occlusion.mesh = _polygon_mesh(polygon, -4.05)
	occlusion.material_override = _occlusion_material()
	occlusion.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	occlusion.set_meta("visual_only", true)
	add_child(occlusion)

	var cloud_alpha := float(_config.get("cloud_alpha", 0.16))
	var speed := float(_config.get("cloud_parallax_speed", 0.018))
	for index in range(2):
		var cloud := MeshInstance3D.new()
		cloud.name = "SubDeckMist_%s_%02d" % [hole_id, index + 1]
		cloud.mesh = _polygon_mesh(polygon, -4.18 - float(index) * 0.72)
		cloud.material_override = _cloud_material(
			cloud_alpha * (1.0 if index == 0 else 0.62),
			speed * (1.0 if index == 0 else -0.58),
			float(index) * 0.31
		)
		cloud.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		cloud.set_meta("visual_only", true)
		add_child(cloud)
		_cloud_layer_count += 1


func _polygon_mesh(polygon: PackedVector2Array, y: float) -> ArrayMesh:
	var triangles := Geometry2D.triangulate_polygon(polygon)
	var vertices := PackedVector3Array()
	var uvs := PackedVector2Array()
	var bounds := Rect2(polygon[0], Vector2.ZERO)
	for point: Vector2 in polygon:
		bounds = bounds.expand(point)
	for point: Vector2 in polygon:
		vertices.append(Vector3(point.x, y, point.y))
		uvs.append(Vector2(
			(point.x - bounds.position.x) / maxf(bounds.size.x, 0.001),
			(point.y - bounds.position.y) / maxf(bounds.size.y, 0.001)
		))
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = triangles
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


func _add_shaft_wall(
	node_name: String,
	polygon: PackedVector2Array,
	top_y: float,
	bottom_y: float,
	color: Color
) -> void:
	var vertices := PackedVector3Array()
	var indices := PackedInt32Array()
	for index in range(polygon.size()):
		var next_index := (index + 1) % polygon.size()
		var start := polygon[index]
		var finish := polygon[next_index]
		var base := vertices.size()
		vertices.append(Vector3(start.x, top_y, start.y))
		vertices.append(Vector3(finish.x, top_y, finish.y))
		vertices.append(Vector3(finish.x, bottom_y, finish.y))
		vertices.append(Vector3(start.x, bottom_y, start.y))
		indices.append_array(PackedInt32Array([
			base, base + 1, base + 2,
			base, base + 2, base + 3,
		]))
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var wall := MeshInstance3D.new()
	wall.name = node_name
	wall.mesh = mesh
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.96
	material.metallic = 0.0
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	wall.material_override = material
	wall.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	wall.set_meta("visual_only", true)
	add_child(wall)
	_shaft_wall_count += 1


func _occlusion_material() -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color("#090714B8")
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	return material


func _cloud_material(alpha: float, speed: float, phase: float) -> ShaderMaterial:
	var shader := Shader.new()
	shader.code = """
shader_type spatial;
render_mode unshaded, cull_disabled, blend_mix, depth_draw_never;

uniform sampler2D cloud_texture : source_color, filter_linear_mipmap_anisotropic;
uniform float scroll_speed = 0.018;
uniform float phase = 0.0;
uniform float layer_alpha = 0.16;

void fragment() {
	vec2 drift = vec2(TIME * scroll_speed, TIME * scroll_speed * 0.37 + phase);
	vec3 sample_color = texture(cloud_texture, fract(UV * 0.74 + drift)).rgb;
	float warm = max(sample_color.r - sample_color.b * 0.68, 0.0);
	float mask = smoothstep(0.04, 0.38, warm);
	vec3 tint = mix(vec3(0.30, 0.25, 0.48), vec3(1.0, 0.72, 0.68), mask);
	ALBEDO = tint;
	EMISSION = tint * 0.045;
	ALPHA = (0.22 + mask * 0.78) * layer_alpha;
}
"""
	var material := ShaderMaterial.new()
	material.shader = shader
	material.set_shader_parameter("cloud_texture", _cloud_texture)
	material.set_shader_parameter("scroll_speed", speed)
	material.set_shader_parameter("phase", phase)
	material.set_shader_parameter("layer_alpha", alpha)
	material.render_priority = -1
	return material


func _count_collision_nodes(root: Node) -> int:
	var count := 1 if root is CollisionObject3D or root is CollisionShape3D else 0
	for child: Node in root.get_children():
		count += _count_collision_nodes(child)
	return count
