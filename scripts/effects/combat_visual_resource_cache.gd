extends RefCounted
class_name CombatVisualResourceCache

## Shares immutable combat-effect resources across short-lived effect nodes.
## Mesh instances keep their own transforms, so sharing does not couple animation state.

static var _materials: Dictionary = {}
static var _meshes: Dictionary = {}
static var _material_builds := 0
static var _mesh_builds := 0


static func material(
	albedo: Color,
	emission: Color,
	energy: float,
	alpha: float,
	additive: bool,
	cull_disabled: bool = true
) -> StandardMaterial3D:
	var key := "material|%s|%s|%.4f|%.4f|%d|%d" % [
		albedo.to_html(true),
		emission.to_html(true),
		energy,
		alpha,
		int(additive),
		int(cull_disabled),
	]
	if _materials.has(key):
		return _materials[key] as StandardMaterial3D

	var resource := StandardMaterial3D.new()
	resource.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA if alpha < 0.99 else BaseMaterial3D.TRANSPARENCY_DISABLED
	resource.albedo_color = Color(albedo.r, albedo.g, albedo.b, alpha)
	resource.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	resource.emission_enabled = energy > 0.0
	resource.emission = emission
	resource.emission_energy_multiplier = energy
	if cull_disabled:
		resource.cull_mode = BaseMaterial3D.CULL_DISABLED
	if additive:
		resource.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	_materials[key] = resource
	_material_builds += 1
	return resource


static func box_mesh() -> BoxMesh:
	const KEY := "box|unit"
	if _meshes.has(KEY):
		return _meshes[KEY] as BoxMesh
	var resource := BoxMesh.new()
	resource.size = Vector3.ONE
	_store_mesh(KEY, resource)
	return resource


static func sphere_mesh(radial_segments: int, rings: int) -> SphereMesh:
	var key := "sphere|%d|%d" % [radial_segments, rings]
	if _meshes.has(key):
		return _meshes[key] as SphereMesh
	var resource := SphereMesh.new()
	resource.radius = 1.0
	resource.height = 2.0
	resource.radial_segments = radial_segments
	resource.rings = rings
	_store_mesh(key, resource)
	return resource


static func torus_mesh(inner_radius: float, outer_radius: float, rings: int, ring_segments: int) -> TorusMesh:
	var key := "torus|%.4f|%.4f|%d|%d" % [inner_radius, outer_radius, rings, ring_segments]
	if _meshes.has(key):
		return _meshes[key] as TorusMesh
	var resource := TorusMesh.new()
	resource.inner_radius = inner_radius
	resource.outer_radius = outer_radius
	resource.rings = rings
	resource.ring_segments = ring_segments
	_store_mesh(key, resource)
	return resource


static func cylinder_mesh(top_radius: float, bottom_radius: float, height: float, radial_segments: int) -> CylinderMesh:
	var key := "cylinder|%.4f|%.4f|%.4f|%d" % [top_radius, bottom_radius, height, radial_segments]
	if _meshes.has(key):
		return _meshes[key] as CylinderMesh
	var resource := CylinderMesh.new()
	resource.top_radius = top_radius
	resource.bottom_radius = bottom_radius
	resource.height = height
	resource.radial_segments = radial_segments
	resource.rings = 1
	_store_mesh(key, resource)
	return resource


static func teardrop_mesh(length: float, radius: float, radial_segments: int = 14) -> ArrayMesh:
	var key := "teardrop|%.4f|%.4f|%d" % [length, radius, radial_segments]
	if _meshes.has(key):
		return _meshes[key] as ArrayMesh

	# A planar silhouette is intentional: the gameplay camera reads the same
	# round cap and tapered rear at every pitch, like a high-contrast arcade sprite.
	var front_z := -length * 0.50
	var cap_radius := minf(radius, length * 0.32)
	var cap_center_z := front_z + cap_radius
	var rear_z := length * 0.50
	var cap_steps := maxi(6, radial_segments / 2)
	var perimeter := PackedVector3Array()
	for step in range(cap_steps + 1):
		var theta := (PI * 0.5) * float(step) / float(cap_steps)
		perimeter.append(Vector3(
			sin(theta) * radius,
			0.0,
			cap_center_z - cos(theta) * cap_radius
		))
	perimeter.append(Vector3(0.0, 0.0, rear_z))
	for step in range(cap_steps, -1, -1):
		var theta := (PI * 0.5) * float(step) / float(cap_steps)
		perimeter.append(Vector3(
			-sin(theta) * radius,
			0.0,
			cap_center_z - cos(theta) * cap_radius
		))
	var vertices := PackedVector3Array([Vector3(0.0, 0.0, 0.0)])
	vertices.append_array(perimeter)
	var indices := PackedInt32Array()
	for index in range(perimeter.size()):
		var next_index := (index + 1) % perimeter.size()
		indices.append_array(PackedInt32Array([0, index + 1, next_index + 1]))
	var resource := _array_mesh(vertices, indices)
	_store_mesh(key, resource)
	return resource


static func wedge_mesh(angle: float, petal_length: float, petal_width: float, base_distance: float) -> ArrayMesh:
	var key := "wedge|%.5f|%.4f|%.4f|%.4f" % [angle, petal_length, petal_width, base_distance]
	if _meshes.has(key):
		return _meshes[key] as ArrayMesh
	var direction := Vector3(sin(angle), 0.0, -cos(angle))
	var perpendicular := Vector3(cos(angle), 0.0, sin(angle))
	var base_center := direction * base_distance
	var tip := direction * petal_length
	var resource := _array_mesh(
		PackedVector3Array([
			base_center - perpendicular * petal_width,
			base_center + perpendicular * petal_width,
			tip,
		]),
		PackedInt32Array([0, 1, 2])
	)
	_store_mesh(key, resource)
	return resource


static func tapered_streak_mesh(streak_length: float, streak_width: float) -> ArrayMesh:
	var key := "streak|%.4f|%.4f" % [streak_length, streak_width]
	if _meshes.has(key):
		return _meshes[key] as ArrayMesh
	var half_width := streak_width * 0.5
	var resource := _array_mesh(
		PackedVector3Array([
			Vector3(-half_width * 0.18, 0.0, 0.0),
			Vector3(half_width * 0.18, 0.0, 0.0),
			Vector3(-half_width, 0.0, -streak_length * 0.18),
			Vector3(half_width, 0.0, -streak_length * 0.18),
			Vector3(-half_width * 0.72, 0.0, -streak_length * 0.82),
			Vector3(half_width * 0.72, 0.0, -streak_length * 0.82),
			Vector3(0.0, 0.0, -streak_length),
		]),
		PackedInt32Array([0, 1, 3, 0, 3, 2, 2, 3, 5, 2, 5, 4, 4, 5, 6])
	)
	_store_mesh(key, resource)
	return resource


static func tail_mesh() -> ArrayMesh:
	const KEY := "tail|unit"
	if _meshes.has(KEY):
		return _meshes[KEY] as ArrayMesh
	var resource := _array_mesh(
		PackedVector3Array([
			Vector3(-0.50, 0.0, 0.0),
			Vector3(0.50, 0.0, 0.0),
			Vector3(0.0, 0.0, 1.0),
		]),
		PackedInt32Array([0, 1, 2])
	)
	_store_mesh(KEY, resource)
	return resource


static func get_debug() -> Dictionary:
	return {
		"material_count": _materials.size(),
		"mesh_count": _meshes.size(),
		"material_builds": _material_builds,
		"mesh_builds": _mesh_builds,
	}


static func clear_for_tests() -> void:
	_materials.clear()
	_meshes.clear()
	_material_builds = 0
	_mesh_builds = 0


static func _array_mesh(vertices: PackedVector3Array, indices: PackedInt32Array) -> ArrayMesh:
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_INDEX] = indices
	var resource := ArrayMesh.new()
	resource.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return resource


static func _store_mesh(key: String, resource: Mesh) -> void:
	_meshes[key] = resource
	_mesh_builds += 1
