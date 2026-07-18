from math import cos, exp, pi, sin

import bmesh
import bpy
from mathutils import Vector


SUIT_NAME = "hero_suit_red"
RUBBER_NAME = "hero_rubber_purple"
SOLE_NAME = "hero_rubber_sole"
FACE_NAME = "hero_face_recess"
EYE_NAME = "hero_eye_emission"

BODY_BONES = [
    "Root",
    "Spine",
    "Head",
    "UpperArm.L",
    "Forearm.L",
    "Hand.L",
    "UpperArm.R",
    "Forearm.R",
    "Hand.R",
    "Thigh.L",
    "Shin.L",
    "Foot.L",
    "Thigh.R",
    "Shin.R",
    "Foot.R",
]


def _material(name, color, roughness, emission=None, emission_strength=0.0):
    material = bpy.data.materials.get(name) or bpy.data.materials.new(name)
    material.diffuse_color = color
    material.use_nodes = True
    shader = material.node_tree.nodes.get("Principled BSDF")
    if shader is not None:
        shader.inputs["Base Color"].default_value = color
        shader.inputs["Roughness"].default_value = roughness
        shader.inputs["Metallic"].default_value = 0.0
        if emission is not None:
            emission_input = shader.inputs.get("Emission Color") or shader.inputs.get("Emission")
            strength_input = shader.inputs.get("Emission Strength")
            if emission_input is not None:
                emission_input.default_value = emission
            if strength_input is not None:
                strength_input.default_value = emission_strength
    return material


def materials():
    return {
        "suit": _material(SUIT_NAME, (0.88, 0.075, 0.055, 1.0), 0.48),
        "rubber": _material(RUBBER_NAME, (0.16, 0.07, 0.21, 1.0), 0.56),
        "sole": _material(SOLE_NAME, (0.125, 0.060, 0.175, 1.0), 0.64),
        "face": _material(FACE_NAME, (0.028, 0.014, 0.050, 1.0), 0.36),
        "eye": _material(
            EYE_NAME,
            (1.0, 0.52, 0.045, 1.0),
            0.34,
            (1.0, 0.33, 0.02, 1.0),
            2.2,
        ),
    }


def _recalculate_normals(mesh):
    editable = bmesh.new()
    editable.from_mesh(mesh)
    editable.faces.ensure_lookup_table()
    bmesh.ops.recalc_face_normals(editable, faces=list(editable.faces))
    editable.to_mesh(mesh)
    editable.free()
    mesh.update()


def _mesh_object(name, vertices, faces, assigned_materials, smooth=True):
    mesh = bpy.data.meshes.new(name + "Mesh")
    mesh.from_pydata(vertices, [], faces)
    for material in assigned_materials:
        mesh.materials.append(material)
    mesh.validate(verbose=False)
    _recalculate_normals(mesh)
    if smooth:
        for polygon in mesh.polygons:
            polygon.use_smooth = True
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(obj)
    return obj


def _smoothstep(start, end, value):
    if end <= start:
        return 1.0 if value >= end else 0.0
    amount = max(0.0, min(1.0, (value - start) / (end - start)))
    return amount * amount * (3.0 - 2.0 * amount)


def _signed_power(value, power):
    if abs(value) < 1.0e-8:
        return 0.0
    return (1.0 if value > 0.0 else -1.0) * (abs(value) ** power)


def _superellipse(theta, radius_x, radius_y, exponent):
    power = 2.0 / exponent
    return Vector(
        (
            radius_x * _signed_power(cos(theta), power),
            radius_y * _signed_power(sin(theta), power),
        )
    )


def _assign_rigid_weight(obj, bone_name):
    group = obj.vertex_groups.new(name=bone_name)
    group.add([vertex.index for vertex in obj.data.vertices], 1.0, "REPLACE")


def _assign_pair_weights(obj, first_bone, second_bone, amounts):
    first = obj.vertex_groups.new(name=first_bone)
    second = obj.vertex_groups.new(name=second_bone)
    for vertex_index, second_amount in enumerate(amounts):
        second_amount = max(0.0, min(1.0, second_amount))
        if second_amount < 0.9999:
            first.add([vertex_index], 1.0 - second_amount, "REPLACE")
        if second_amount > 0.0001:
            second.add([vertex_index], second_amount, "REPLACE")


def _add_subdivision(obj, levels=1):
    modifier = obj.modifiers.new("P29Subdivision", "SUBSURF")
    modifier.subdivision_type = "CATMULL_CLARK"
    modifier.levels = levels
    modifier.render_levels = levels
    modifier.show_only_control_edges = True
    if hasattr(modifier, "boundary_smooth"):
        modifier.boundary_smooth = "PRESERVE_CORNERS"


def _mark_edge_crease(mesh, edge_keys, amount):
    if not hasattr(mesh, "attributes"):
        return
    crease = mesh.attributes.get("crease_edge")
    if crease is None:
        crease = mesh.attributes.new("crease_edge", "FLOAT", "EDGE")
    normalized = {tuple(sorted(edge)) for edge in edge_keys}
    for edge in mesh.edges:
        if tuple(sorted(edge.vertices)) in normalized:
            crease.data[edge.index].value = amount


def create_continuous_shell(suit_material):
    # One authored cage carries the tunic, collar transition, hood, and crown.
    # Dense reconstruction fragments and neck-cover plates are intentionally absent.
    ring_specs = [
        # A low, full tunic volume narrows continuously into the hood.  These
        # are one cage, not collar/neck/torso overlays.
        (0.655, 0.610, 0.390, 4.1, 0.035),
        (0.690, 0.670, 0.440, 4.4, 0.038),
        (0.760, 0.720, 0.500, 4.6, 0.042),
        (0.900, 0.748, 0.545, 4.5, 0.046),
        (1.070, 0.742, 0.565, 4.3, 0.050),
        (1.230, 0.710, 0.552, 4.0, 0.052),
        (1.380, 0.665, 0.525, 3.6, 0.053),
        (1.500, 0.615, 0.492, 3.3, 0.053),
        (1.600, 0.570, 0.470, 3.1, 0.053),
        (1.755, 0.515, 0.452, 2.7, 0.054),
        (1.830, 0.500, 0.462, 2.5, 0.056),
        (1.905, 0.500, 0.478, 2.3, 0.058),
        (2.080, 0.520, 0.492, 2.15, 0.060),
        (2.285, 0.520, 0.492, 2.05, 0.062),
        (2.390, 0.500, 0.478, 2.0, 0.062),
        (2.485, 0.470, 0.448, 2.0, 0.062),
        (2.575, 0.425, 0.410, 2.0, 0.062),
        (2.645, 0.350, 0.345, 2.0, 0.062),
        (2.700, 0.245, 0.255, 2.0, 0.062),
        (2.735, 0.105, 0.110, 2.0, 0.062),
    ]
    segments = 40
    opening_start = 25
    opening_end = 35
    opening_bottom_ring = 10
    opening_top_ring = 14
    vertices = []
    ring_vertices = []

    for ring_index, (z, radius_x, radius_y, exponent, center_y) in enumerate(ring_specs):
        current_ring = []
        vertical_opening_weight = (
            _smoothstep(1.78, 1.90, z) * (1.0 - _smoothstep(2.34, 2.46, z))
        )
        for segment in range(segments):
            theta = 2.0 * pi * segment / segments
            point = _superellipse(theta, radius_x, radius_y, exponent)
            front_distance = min(abs(segment - 30), segments - abs(segment - 30))
            front_weight = max(0.0, 1.0 - front_distance / 7.0)
            y = center_y + point.y - 0.060 * front_weight * vertical_opening_weight
            # The lower perimeter rises toward the sides so the visible hem
            # rounds into the body rather than reading as an apron edge.
            lower_edge_lift = 0.0
            if ring_index == 0:
                lower_edge_lift = 0.070 * (abs(point.x) / radius_x) ** 1.7
            current_ring.append(len(vertices))
            vertices.append((point.x, y, z + lower_edge_lift))
        ring_vertices.append(current_ring)

    faces = []
    for ring_index in range(len(ring_specs) - 1):
        inside_opening = (
            ring_index >= opening_bottom_ring
            and ring_index < opening_top_ring
        )
        for segment in range(segments):
            next_segment = (segment + 1) % segments
            if inside_opening and opening_start <= segment < opening_end:
                continue
            faces.append(
                (
                    ring_vertices[ring_index][segment],
                    ring_vertices[ring_index][next_segment],
                    ring_vertices[ring_index + 1][next_segment],
                    ring_vertices[ring_index + 1][segment],
                )
            )

    bottom_center = len(vertices)
    vertices.append((0.0, 0.035, 0.615))
    top_center = len(vertices)
    vertices.append((0.0, 0.062, 2.742))
    for segment in range(segments):
        next_segment = (segment + 1) % segments
        faces.append((bottom_center, ring_vertices[0][next_segment], ring_vertices[0][segment]))
        faces.append((top_center, ring_vertices[-1][segment], ring_vertices[-1][next_segment]))

    boundary = []
    for segment in range(opening_start, opening_end + 1):
        boundary.append(ring_vertices[opening_bottom_ring][segment])
    for ring_index in range(opening_bottom_ring + 1, opening_top_ring + 1):
        boundary.append(ring_vertices[ring_index][opening_end])
    for segment in range(opening_end - 1, opening_start - 1, -1):
        boundary.append(ring_vertices[opening_top_ring][segment])
    for ring_index in range(opening_top_ring - 1, opening_bottom_ring, -1):
        boundary.append(ring_vertices[ring_index][opening_start])

    inner_boundary = []
    for outer_index in boundary:
        point = Vector(vertices[outer_index])
        inner = point.copy()
        inner.y += 0.118
        if point.z <= ring_specs[opening_bottom_ring][0] + 0.001:
            inner.z += 0.038
        elif point.z >= ring_specs[opening_top_ring][0] - 0.001:
            inner.z -= 0.038
        if point.x < -0.35:
            inner.x += 0.030
        elif point.x > 0.35:
            inner.x -= 0.030
        inner_boundary.append(len(vertices))
        vertices.append(tuple(inner))

    for boundary_index in range(len(boundary)):
        next_index = (boundary_index + 1) % len(boundary)
        faces.append(
            (
                boundary[boundary_index],
                boundary[next_index],
                inner_boundary[next_index],
                inner_boundary[boundary_index],
            )
        )

    body = _mesh_object("HeroCloudBody", vertices, faces, [suit_material])
    body["p29_topology"] = "continuous_hood_neck_torso_shell"
    body["p29_face_opening"] = "inset"
    _mark_edge_crease(
        body.data,
        [
            (boundary[index], boundary[(index + 1) % len(boundary)])
            for index in range(len(boundary))
        ],
        0.72,
    )
    _mark_edge_crease(
        body.data,
        [
            (ring_vertices[0][segment], ring_vertices[0][(segment + 1) % segments])
            for segment in range(segments)
        ],
        0.42,
    )
    _add_subdivision(body, 1)
    return body


def assign_continuous_shell_weights(body):
    body.vertex_groups.clear()
    groups = {name: body.vertex_groups.new(name=name) for name in BODY_BONES}
    for vertex in body.data.vertices:
        head_amount = _smoothstep(1.68, 1.98, vertex.co.z)
        if head_amount < 0.9999:
            groups["Spine"].add([vertex.index], 1.0 - head_amount, "REPLACE")
        if head_amount > 0.0001:
            groups["Head"].add([vertex.index], head_amount, "REPLACE")


def _quadratic_point(start, control, end, amount):
    return (
        start * ((1.0 - amount) ** 2)
        + control * (2.0 * (1.0 - amount) * amount)
        + end * (amount ** 2)
    )


def _quadratic_tangent(start, control, end, amount):
    return (control - start) * (2.0 * (1.0 - amount)) + (end - control) * (2.0 * amount)


def _tube_mesh(name, samples, radial_segments, material, weight_amounts=None, bones=None):
    vertices = []
    vertex_amounts = []
    depth_axis = Vector((0.0, 1.0, 0.0))
    for center, tangent, radius_x, radius_y, amount in samples:
        tangent = tangent.normalized()
        side_axis = depth_axis.cross(tangent).normalized()
        for segment in range(radial_segments):
            angle = 2.0 * pi * segment / radial_segments
            point = center + depth_axis * cos(angle) * radius_y + side_axis * sin(angle) * radius_x
            vertices.append(tuple(point))
            vertex_amounts.append(amount)
    faces = []
    ring_count = len(samples)
    for ring_index in range(ring_count - 1):
        current = ring_index * radial_segments
        following = (ring_index + 1) * radial_segments
        for segment in range(radial_segments):
            next_segment = (segment + 1) % radial_segments
            faces.append(
                (
                    current + segment,
                    current + next_segment,
                    following + next_segment,
                    following + segment,
                )
            )
    start_center = len(vertices)
    vertices.append(tuple(samples[0][0]))
    vertex_amounts.append(samples[0][4])
    end_center = len(vertices)
    vertices.append(tuple(samples[-1][0]))
    vertex_amounts.append(samples[-1][4])
    for segment in range(radial_segments):
        next_segment = (segment + 1) % radial_segments
        faces.append((start_center, next_segment, segment))
        last_ring = (ring_count - 1) * radial_segments
        faces.append((end_center, last_ring + segment, last_ring + next_segment))
    obj = _mesh_object(name, vertices, faces, [material])
    if bones is not None:
        _assign_pair_weights(obj, bones[0], bones[1], vertex_amounts if weight_amounts is None else weight_amounts)
    return obj


def create_sleeve(suffix, sign, suit_material):
    start = Vector((sign * 0.465, -0.002, 1.570))
    control = Vector((sign * 0.640, -0.006, 1.410))
    end = Vector((sign * 0.790, -0.010, 1.145))
    start_tangent = _quadratic_tangent(start, control, end, 0.0).normalized()
    samples = [
        (start - start_tangent * 0.180, start_tangent, 0.020, 0.020, 0.0),
        (start - start_tangent * 0.125, start_tangent, 0.100, 0.092, 0.0),
        (start - start_tangent * 0.065, start_tangent, 0.180, 0.164, 0.0),
        (start, start_tangent, 0.208, 0.190, 0.0),
    ]
    path_steps = 15
    for index in range(1, path_steps + 1):
        amount = index / path_steps
        center = _quadratic_point(start, control, end, amount)
        tangent = _quadratic_tangent(start, control, end, amount)
        radius = 0.205 * (1.0 - amount) + 0.140 * amount + sin(pi * amount) * 0.007
        samples.append((center, tangent, radius, radius * 0.91, amount))
    sleeve = _tube_mesh(
        "HeroSleeve." + suffix,
        samples,
        24,
        suit_material,
        bones=("UpperArm." + suffix, "Forearm." + suffix),
    )
    sleeve["p29_joint"] = "shoulder_embedded_under_shell"
    return sleeve


def create_wrist_cuff(suffix, sign, rubber_material):
    start = Vector((sign * 0.465, -0.002, 1.570))
    control = Vector((sign * 0.640, -0.006, 1.410))
    end = Vector((sign * 0.790, -0.010, 1.145))
    axis = _quadratic_tangent(start, control, end, 1.0).normalized()
    offsets = (-0.095, -0.066, 0.066, 0.095)
    radii = (0.142, 0.168, 0.168, 0.142)
    samples = []
    for offset, radius in zip(offsets, radii):
        samples.append((end + axis * offset, axis, radius, radius * 0.92, 0.0))
    cuff = _tube_mesh("HeroWristCuff." + suffix, samples, 24, rubber_material)
    _assign_rigid_weight(cuff, "Forearm." + suffix)
    cuff["p29_joint"] = "rounded_cuff_overlap"
    return cuff


def create_mitten(suffix, sign, rubber_material):
    center = Vector((sign * 0.870, -0.018, 0.925))
    radius_x = 0.158
    radius_y = 0.140
    radius_z = 0.214
    longitude_segments = 28
    latitude_segments = 18
    vertices = []
    rings = []
    bottom = len(vertices)
    vertices.append(tuple(center + Vector((0.0, 0.0, -radius_z))))
    for latitude_index in range(1, latitude_segments):
        latitude = -0.5 * pi + pi * latitude_index / latitude_segments
        local_z = sin(latitude)
        ring_radius = cos(latitude)
        ring = []
        for longitude_index in range(longitude_segments):
            longitude = 2.0 * pi * longitude_index / longitude_segments
            local_x = ring_radius * cos(longitude)
            local_y = ring_radius * sin(longitude)
            thumb_weight = exp(
                -((local_x + 0.78) / 0.30) ** 2
                -((local_z + 0.08) / 0.34) ** 2
                -((local_y + 0.10) / 0.58) ** 2
            )
            local_x -= 0.50 * thumb_weight
            local_y -= 0.06 * thumb_weight
            local_z -= 0.08 * thumb_weight
            point = center + Vector(
                (
                    sign * radius_x * local_x,
                    radius_y * local_y,
                    radius_z * local_z,
                )
            )
            ring.append(len(vertices))
            vertices.append(tuple(point))
        rings.append(ring)
    top = len(vertices)
    vertices.append(tuple(center + Vector((0.0, 0.0, radius_z))))
    faces = []
    for segment in range(longitude_segments):
        next_segment = (segment + 1) % longitude_segments
        faces.append((bottom, rings[0][segment], rings[0][next_segment]))
        faces.append((top, rings[-1][next_segment], rings[-1][segment]))
    for ring_index in range(len(rings) - 1):
        for segment in range(longitude_segments):
            next_segment = (segment + 1) % longitude_segments
            faces.append(
                (
                    rings[ring_index][segment],
                    rings[ring_index + 1][segment],
                    rings[ring_index + 1][next_segment],
                    rings[ring_index][next_segment],
                )
            )
    glove = _mesh_object("HeroGlove." + suffix, vertices, faces, [rubber_material])
    _assign_rigid_weight(glove, "Hand." + suffix)
    glove["p29_topology"] = "single_surface_mitten"
    _add_subdivision(glove, 1)
    return glove


def create_leg(suffix, sign, suit_material):
    center_x = sign * 0.315
    specs = [
        (0.365, 0.170, 0.158),
        (0.405, 0.184, 0.168),
        (0.490, 0.192, 0.174),
        (0.590, 0.198, 0.180),
        (0.705, 0.198, 0.180),
        (0.810, 0.188, 0.172),
    ]
    samples = []
    for z, radius_x, radius_y in specs:
        center = Vector((center_x, 0.030, z))
        samples.append((center, Vector((0.0, 0.0, 1.0)), radius_x, radius_y, _smoothstep(0.68, 0.48, z)))
    leg = _tube_mesh("HeroLeg." + suffix, samples, 24, suit_material)
    # Tube order runs bottom-to-top, so the lower shin receives the second group.
    amounts = []
    for vertex in leg.data.vertices:
        amounts.append(1.0 - _smoothstep(0.42, 0.61, vertex.co.z))
    _assign_pair_weights(leg, "Thigh." + suffix, "Shin." + suffix, amounts)
    return leg


def create_boot(suffix, sign, rubber_material):
    center_x = sign * 0.315
    specs = [
        (0.065, -0.052, 0.220, 0.282, 3.0),
        (0.095, -0.064, 0.236, 0.295, 3.0),
        (0.150, -0.077, 0.240, 0.288, 2.9),
        (0.225, -0.060, 0.230, 0.255, 2.8),
        (0.315, 0.000, 0.210, 0.195, 2.7),
        (0.395, 0.023, 0.193, 0.176, 2.6),
    ]
    segments = 32
    vertices = []
    rings = []
    for z, center_y, radius_x, radius_y, exponent in specs:
        ring = []
        for segment in range(segments):
            theta = 2.0 * pi * segment / segments
            point = _superellipse(theta, radius_x, radius_y, exponent)
            ring.append(len(vertices))
            vertices.append((center_x + point.x, center_y + point.y, z))
        rings.append(ring)
    faces = []
    for ring_index in range(len(rings) - 1):
        for segment in range(segments):
            next_segment = (segment + 1) % segments
            faces.append(
                (
                    rings[ring_index][segment],
                    rings[ring_index][next_segment],
                    rings[ring_index + 1][next_segment],
                    rings[ring_index + 1][segment],
                )
            )
    bottom_center = len(vertices)
    vertices.append((center_x, -0.070, specs[0][0]))
    top_center = len(vertices)
    vertices.append((center_x, 0.035, specs[-1][0]))
    for segment in range(segments):
        next_segment = (segment + 1) % segments
        faces.append((bottom_center, rings[0][next_segment], rings[0][segment]))
        faces.append((top_center, rings[-1][segment], rings[-1][next_segment]))
    boot = _mesh_object("HeroBoot." + suffix, vertices, faces, [rubber_material])
    _assign_rigid_weight(boot, "Foot." + suffix)
    boot["p29_topology"] = "rounded_toe_boot"
    _add_subdivision(boot, 1)
    return boot


def _rounded_rectangle_outline(width, height, radius, corner_segments):
    points = []
    corners = [
        (width * 0.5 - radius, height * 0.5 - radius, 0.0),
        (-width * 0.5 + radius, height * 0.5 - radius, 0.5 * pi),
        (-width * 0.5 + radius, -height * 0.5 + radius, pi),
        (width * 0.5 - radius, -height * 0.5 + radius, 1.5 * pi),
    ]
    for center_x, center_z, start_angle in corners:
        for step in range(corner_segments + 1):
            angle = start_angle + 0.5 * pi * step / corner_segments
            points.append((center_x + cos(angle) * radius, center_z + sin(angle) * radius))
    return points


def create_rounded_prism(name, center, width, height, depth, radius, material, bone=None):
    outline = _rounded_rectangle_outline(width, height, radius, 5)
    front_y = center.y - depth * 0.5
    back_y = center.y + depth * 0.5
    vertices = []
    for x, z in outline:
        vertices.append((center.x + x, front_y, center.z + z))
    for x, z in outline:
        vertices.append((center.x + x, back_y, center.z + z))
    count = len(outline)
    faces = [tuple(range(count - 1, -1, -1)), tuple(range(count, count * 2))]
    for index in range(count):
        next_index = (index + 1) % count
        faces.append((index, next_index, count + next_index, count + index))
    obj = _mesh_object(name, vertices, faces, [material])
    if bone is not None:
        _assign_rigid_weight(obj, bone)
    return obj


def create_boot_sole(suffix, sign, sole_material):
    sole = create_rounded_prism(
        "HeroBootSole." + suffix,
        Vector((sign * 0.315, -0.075, 0.090)),
        0.475,
        0.540,
        0.055,
        0.085,
        sole_material,
        "Foot." + suffix,
    )
    # Rounded-prism axes are X/Z with depth on Y. Rotate so the thin dimension is Z.
    vertices = [vertex.co.copy() for vertex in sole.data.vertices]
    for vertex, point in zip(sole.data.vertices, vertices):
        local_y = point.y + 0.075
        local_z = point.z - 0.090
        vertex.co.y = -0.075 + local_z
        vertex.co.z = 0.090 + local_y
    sole.data.update()
    return sole


def create_face_details(face_material, eye_material):
    face = create_rounded_prism(
        "FacePanel",
        Vector((0.0, -0.285, 2.125)),
        0.760,
        0.390,
        0.024,
        0.096,
        face_material,
    )
    face["p29_face_panel"] = "recessed_inside_shell_opening"
    eyes = []
    for name, x in (("EyeL", -0.205), ("EyeR", 0.205)):
        eye = create_rounded_prism(
            name,
            Vector((x, -0.301, 2.125)),
            0.064,
            0.162,
            0.012,
            0.030,
            eye_material,
        )
        eyes.append(eye)
    return [face, *eyes]


def build_character():
    mats = materials()
    body = create_continuous_shell(mats["suit"])
    details = create_face_details(mats["face"], mats["eye"])
    deform_parts = []
    for suffix, sign in (("L", -1.0), ("R", 1.0)):
        deform_parts.extend(
            [
                create_sleeve(suffix, sign, mats["suit"]),
                create_wrist_cuff(suffix, sign, mats["rubber"]),
                create_mitten(suffix, sign, mats["rubber"]),
                create_leg(suffix, sign, mats["suit"]),
                create_boot(suffix, sign, mats["rubber"]),
                create_boot_sole(suffix, sign, mats["sole"]),
            ]
        )
    return body, details, deform_parts
