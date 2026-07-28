from math import cos, exp, pi, sin

import bpy
from mathutils import Vector

import hero_character_p29_geometry as base


SUIT_NAME = base.SUIT_NAME
RUBBER_NAME = base.RUBBER_NAME
SOLE_NAME = base.SOLE_NAME
FACE_NAME = base.FACE_NAME
EYE_NAME = base.EYE_NAME
BODY_BONES = base.BODY_BONES


def materials():
    return {
        "suit": base._material(SUIT_NAME, (0.84, 0.028, 0.015, 1.0), 0.58),
        "rubber": base._material(RUBBER_NAME, (0.105, 0.028, 0.145, 1.0), 0.64),
        "sole": base._material(SOLE_NAME, (0.072, 0.018, 0.105, 1.0), 0.70),
        "face": base._material(FACE_NAME, (0.018, 0.006, 0.032, 1.0), 0.46),
        "eye": base._material(
            EYE_NAME,
            (1.0, 0.36, 0.015, 1.0),
            0.38,
            (1.0, 0.25, 0.008, 1.0),
            2.0,
        ),
    }


def _append_profile_component(
    vertices,
    faces,
    ring_specs,
    segments=40,
    opening=None,
):
    ring_vertices = []
    component_start = len(vertices)
    for z, radius_x, radius_y, exponent, center_y in ring_specs:
        ring = []
        for segment in range(segments):
            theta = 2.0 * pi * segment / segments
            point = base._superellipse(theta, radius_x, radius_y, exponent)
            ring.append(len(vertices))
            vertices.append((point.x, center_y + point.y, z))
        ring_vertices.append(ring)

    for ring_index in range(len(ring_specs) - 1):
        for segment in range(segments):
            next_segment = (segment + 1) % segments
            if (
                opening is not None
                and opening["bottom_ring"] <= ring_index < opening["top_ring"]
                and opening["start_segment"] <= segment < opening["end_segment"]
            ):
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
    bottom = ring_specs[0]
    vertices.append((0.0, bottom[4], bottom[0]))
    top_center = len(vertices)
    top = ring_specs[-1]
    vertices.append((0.0, top[4], top[0]))
    for segment in range(segments):
        next_segment = (segment + 1) % segments
        faces.append((bottom_center, ring_vertices[0][next_segment], ring_vertices[0][segment]))
        faces.append((top_center, ring_vertices[-1][segment], ring_vertices[-1][next_segment]))

    opening_edges = []
    if opening is not None:
        start_segment = opening["start_segment"]
        end_segment = opening["end_segment"]
        bottom_ring = opening["bottom_ring"]
        top_ring = opening["top_ring"]
        boundary = []
        for segment in range(start_segment, end_segment + 1):
            boundary.append(ring_vertices[bottom_ring][segment])
        for ring_index in range(bottom_ring + 1, top_ring + 1):
            boundary.append(ring_vertices[ring_index][end_segment])
        for segment in range(end_segment - 1, start_segment - 1, -1):
            boundary.append(ring_vertices[top_ring][segment])
        for ring_index in range(top_ring - 1, bottom_ring, -1):
            boundary.append(ring_vertices[ring_index][start_segment])

        inner_boundary = []
        bottom_z = ring_specs[bottom_ring][0]
        top_z = ring_specs[top_ring][0]
        for outer_index in boundary:
            point = Vector(vertices[outer_index])
            inner = point.copy()
            inner.y += opening.get("recess_depth", 0.112)
            if point.z <= bottom_z + 0.001:
                inner.z += opening.get("vertical_inset", 0.032)
            elif point.z >= top_z - 0.001:
                inner.z -= opening.get("vertical_inset", 0.032)
            if point.x < -0.35:
                inner.x += opening.get("side_inset", 0.028)
            elif point.x > 0.35:
                inner.x -= opening.get("side_inset", 0.028)
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
            opening_edges.append(
                (
                    boundary[boundary_index],
                    boundary[next_index],
                )
            )

    return {
        "start": component_start,
        "end": len(vertices),
        "rings": ring_vertices,
        "opening_edges": opening_edges,
    }


def create_layered_shell(suit_material):
    vertices = []
    faces = []

    torso = _append_profile_component(
        vertices,
        faces,
        [
            (0.790, 0.595, 0.425, 4.8, 0.018),
            (0.825, 0.620, 0.445, 4.8, 0.020),
            (1.020, 0.615, 0.455, 4.8, 0.024),
            (1.270, 0.595, 0.450, 4.6, 0.028),
            (1.500, 0.560, 0.435, 4.3, 0.032),
            (1.610, 0.545, 0.425, 4.1, 0.034),
        ],
    )
    collar = _append_profile_component(
        vertices,
        faces,
        [
            (1.560, 0.565, 0.452, 4.8, 0.034),
            (1.578, 0.600, 0.475, 5.0, 0.034),
            (1.605, 0.615, 0.484, 5.0, 0.034),
            (1.720, 0.615, 0.484, 5.0, 0.034),
            (1.748, 0.600, 0.475, 5.0, 0.034),
            (1.765, 0.565, 0.452, 4.8, 0.034),
        ],
    )
    helmet_start = len(vertices)
    helmet = _append_profile_component(
        vertices,
        faces,
        [
            (1.700, 0.485, 0.432, 3.5, 0.034),
            (1.780, 0.510, 0.455, 3.2, 0.034),
            (1.900, 0.520, 0.472, 3.0, 0.034),
            (2.000, 0.520, 0.480, 2.8, 0.034),
            (2.160, 0.520, 0.485, 2.6, 0.034),
            (2.320, 0.515, 0.478, 2.4, 0.034),
            (2.440, 0.500, 0.465, 2.25, 0.034),
            (2.555, 0.455, 0.430, 2.1, 0.034),
            (2.645, 0.390, 0.375, 2.0, 0.034),
            (2.705, 0.280, 0.285, 2.0, 0.034),
            (2.738, 0.105, 0.110, 2.0, 0.034),
        ],
        opening={
            "start_segment": 24,
            "end_segment": 36,
            "bottom_ring": 2,
            "top_ring": 5,
            "recess_depth": 0.112,
            "vertical_inset": 0.032,
            "side_inset": 0.028,
        },
    )

    body = base._mesh_object("HeroCloudBody", vertices, faces, [suit_material])
    body["v3_topology"] = "layered_helmet_collar_tunic_shell"
    body["v3_face_opening"] = "deep_inset_with_brow"
    body["v3_helmet_vertex_start"] = helmet_start
    base._mark_edge_crease(body.data, helmet["opening_edges"], 0.72)
    for component, amount in ((torso, 0.44), (collar, 0.62), (helmet, 0.28)):
        ring = component["rings"][0]
        base._mark_edge_crease(
            body.data,
            [(ring[index], ring[(index + 1) % len(ring)]) for index in range(len(ring))],
            amount,
        )
        ring = component["rings"][-1]
        base._mark_edge_crease(
            body.data,
            [(ring[index], ring[(index + 1) % len(ring)]) for index in range(len(ring))],
            amount,
        )
    base._add_subdivision(body, 1)
    return body


def assign_continuous_shell_weights(body):
    body.vertex_groups.clear()
    groups = {name: body.vertex_groups.new(name=name) for name in BODY_BONES}
    helmet_start = int(body.get("v3_helmet_vertex_start", len(body.data.vertices)))
    for vertex in body.data.vertices:
        bone_name = "Head" if vertex.index >= helmet_start else "Spine"
        groups[bone_name].add([vertex.index], 1.0, "REPLACE")


def create_sleeve(suffix, sign, suit_material):
    start = Vector((sign * 0.480, -0.004, 1.490))
    control = Vector((sign * 0.635, -0.006, 1.340))
    end = Vector((sign * 0.792, -0.010, 1.120))
    start_tangent = base._quadratic_tangent(start, control, end, 0.0).normalized()
    samples = [
        (start - start_tangent * 0.100, start_tangent, 0.016, 0.016, 0.0),
        (start - start_tangent * 0.065, start_tangent, 0.074, 0.068, 0.0),
        (start - start_tangent * 0.032, start_tangent, 0.142, 0.130, 0.0),
        (start, start_tangent, 0.174, 0.158, 0.0),
    ]
    path_steps = 15
    for index in range(1, path_steps + 1):
        amount = index / path_steps
        center = base._quadratic_point(start, control, end, amount)
        tangent = base._quadratic_tangent(start, control, end, amount)
        radius = 0.178 * (1.0 - amount) + 0.132 * amount + sin(pi * amount) * 0.006
        samples.append((center, tangent, radius, radius * 0.91, amount))
    sleeve = base._tube_mesh(
        "HeroSleeve." + suffix,
        samples,
        24,
        suit_material,
        bones=None,
    )
    groups = {
        name: sleeve.vertex_groups.new(name=name)
        for name in ("Spine", "UpperArm." + suffix, "Forearm." + suffix)
    }
    for ring_index, sample in enumerate(samples):
        if ring_index == 0:
            weights = {"Spine": 1.0}
        elif ring_index == 1:
            weights = {"Spine": 0.88, "UpperArm." + suffix: 0.12}
        elif ring_index == 2:
            weights = {"Spine": 0.52, "UpperArm." + suffix: 0.48}
        elif ring_index == 3:
            weights = {"Spine": 0.18, "UpperArm." + suffix: 0.82}
        else:
            elbow_amount = base._smoothstep(0.44, 0.70, sample[4])
            weights = {
                "UpperArm." + suffix: 1.0 - elbow_amount,
                "Forearm." + suffix: elbow_amount,
            }
        indices = [
            ring_index * 24 + segment
            for segment in range(24)
        ]
        for group_name, weight in weights.items():
            if weight > 0.0001:
                groups[group_name].add(indices, weight, "REPLACE")
    start_center = len(samples) * 24
    end_center = start_center + 1
    groups["Spine"].add([start_center], 1.0, "REPLACE")
    groups["Forearm." + suffix].add([end_center], 1.0, "REPLACE")
    sleeve["v3_joint"] = "slim_shoulder_embedded_under_tunic"
    return sleeve


def create_wrist_cuff(suffix, sign, rubber_material):
    start = Vector((sign * 0.480, -0.004, 1.490))
    control = Vector((sign * 0.635, -0.006, 1.340))
    end = Vector((sign * 0.792, -0.010, 1.120))
    axis = base._quadratic_tangent(start, control, end, 1.0).normalized()
    offsets = (-0.068, -0.045, 0.045, 0.068)
    radii = (0.135, 0.151, 0.151, 0.135)
    samples = [
        (end + axis * offset, axis, radius, radius * 0.92, 0.0)
        for offset, radius in zip(offsets, radii)
    ]
    cuff = base._tube_mesh("HeroWristCuff." + suffix, samples, 24, rubber_material)
    base._assign_rigid_weight(cuff, "Forearm." + suffix)
    cuff["v3_joint"] = "thin_rounded_cuff"
    return cuff


def create_mitten(suffix, sign, rubber_material):
    longitude_segments = 28
    latitude_segments = 18
    vertices = []
    faces = []

    def append_ellipsoid(center, radii):
        rings = []
        bottom = len(vertices)
        vertices.append(tuple(center + Vector((0.0, 0.0, -radii.z))))
        for latitude_index in range(1, latitude_segments):
            latitude = -0.5 * pi + pi * latitude_index / latitude_segments
            local_z = sin(latitude)
            ring_radius = cos(latitude)
            ring = []
            for longitude_index in range(longitude_segments):
                longitude = 2.0 * pi * longitude_index / longitude_segments
                local_x = ring_radius * cos(longitude)
                local_y = ring_radius * sin(longitude)
                point = center + Vector(
                    (
                        radii.x * local_x,
                        radii.y * local_y,
                        radii.z * local_z,
                    )
                )
                ring.append(len(vertices))
                vertices.append(tuple(point))
            rings.append(ring)
        top = len(vertices)
        vertices.append(tuple(center + Vector((0.0, 0.0, radii.z))))
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

    append_ellipsoid(
        Vector((sign * 0.855, -0.020, 0.910)),
        Vector((0.150, 0.134, 0.215)),
    )
    append_ellipsoid(
        Vector((sign * 0.735, -0.030, 0.885)),
        Vector((0.092, 0.116, 0.124)),
    )
    glove = base._mesh_object("HeroGlove." + suffix, vertices, faces, [rubber_material])
    base._assign_rigid_weight(glove, "Hand." + suffix)
    glove["v3_topology"] = "defined_thumb_mitten"
    base._add_subdivision(glove, 1)
    return glove


def create_leg(suffix, sign, suit_material):
    center_x = sign * 0.285
    specs = [
        (0.405, 0.158, 0.150),
        (0.455, 0.168, 0.158),
        (0.565, 0.176, 0.164),
        (0.700, 0.180, 0.168),
        (0.835, 0.178, 0.166),
        (0.920, 0.168, 0.158),
    ]
    samples = [
        (
            Vector((center_x, 0.024, z)),
            Vector((0.0, 0.0, 1.0)),
            radius_x,
            radius_y,
            0.0,
        )
        for z, radius_x, radius_y in specs
    ]
    leg = base._tube_mesh("HeroLeg." + suffix, samples, 24, suit_material)
    amounts = [
        1.0 - base._smoothstep(0.44, 0.64, vertex.co.z)
        for vertex in leg.data.vertices
    ]
    base._assign_pair_weights(leg, "Thigh." + suffix, "Shin." + suffix, amounts)
    return leg


def create_boot(suffix, sign, rubber_material):
    center_x = sign * 0.285
    specs = [
        (0.055, -0.040, 0.215, 0.255, 2.6),
        (0.085, -0.050, 0.226, 0.268, 2.6),
        (0.145, -0.060, 0.228, 0.260, 2.55),
        (0.225, -0.040, 0.218, 0.232, 2.5),
        (0.320, -0.004, 0.200, 0.192, 2.45),
        (0.410, 0.018, 0.186, 0.170, 2.4),
        (0.445, 0.022, 0.180, 0.164, 2.4),
    ]
    segments = 32
    vertices = []
    rings = []
    for z, center_y, radius_x, radius_y, exponent in specs:
        ring = []
        for segment in range(segments):
            theta = 2.0 * pi * segment / segments
            point = base._superellipse(theta, radius_x, radius_y, exponent)
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
    vertices.append((center_x, -0.050, specs[0][0]))
    top_center = len(vertices)
    vertices.append((center_x, 0.022, specs[-1][0]))
    for segment in range(segments):
        next_segment = (segment + 1) % segments
        faces.append((bottom_center, rings[0][next_segment], rings[0][segment]))
        faces.append((top_center, rings[-1][segment], rings[-1][next_segment]))
    boot = base._mesh_object("HeroBoot." + suffix, vertices, faces, [rubber_material])
    base._assign_rigid_weight(boot, "Foot." + suffix)
    boot["v3_topology"] = "soft_round_toe_short_boot"
    base._add_subdivision(boot, 1)
    return boot


def create_boot_sole(suffix, sign, sole_material):
    sole = base.create_rounded_prism(
        "HeroBootSole." + suffix,
        Vector((sign * 0.285, -0.055, 0.073)),
        0.416,
        0.462,
        0.026,
        0.068,
        sole_material,
        "Foot." + suffix,
    )
    vertices = [vertex.co.copy() for vertex in sole.data.vertices]
    for vertex, point in zip(sole.data.vertices, vertices):
        local_y = point.y + 0.055
        local_z = point.z - 0.073
        vertex.co.y = -0.055 + local_z
        vertex.co.z = 0.073 + local_y
    sole.data.update()
    return sole


def create_face_details(suit_material, face_material, eye_material):
    face = base.create_rounded_prism(
        "FacePanel",
        Vector((0.0, -0.310, 2.115)),
        0.720,
        0.340,
        0.025,
        0.082,
        face_material,
    )
    face["v3_face_panel"] = "deep_recessed_inside_helmet"
    eyes = []
    for name, x in (("EyeL", -0.190), ("EyeR", 0.190)):
        eye = base.create_rounded_prism(
            name,
            Vector((x, -0.329, 2.115)),
            0.072,
            0.166,
            0.012,
            0.030,
            eye_material,
        )
        eyes.append(eye)
    return [face, *eyes]


def build_character():
    mats = materials()
    body = create_layered_shell(mats["suit"])
    details = create_face_details(mats["suit"], mats["face"], mats["eye"])
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
