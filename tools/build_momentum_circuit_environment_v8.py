"""Build the visual-only Momentum Circuit v8 environment kit.

The exported GLB is deliberately a small model library.  Godot owns placement,
parallax, and animation so this asset contains no collision, lights, cameras,
armatures, or authored animation tracks.
"""

from __future__ import annotations

import math
import os
from pathlib import Path

import bpy
from mathutils import Vector


ROOT = Path(__file__).resolve().parents[1]
ASSET_VERSION = int(os.environ.get("MC_ENVIRONMENT_VERSION", "8"))
if ASSET_VERSION not in (8, 9):
    raise ValueError("MC_ENVIRONMENT_VERSION must be 8 or 9")
SOURCE_PATH = (
    ROOT
    / "assets"
    / "source"
    / f"momentum_circuit_v{ASSET_VERSION}"
    / f"momentum_circuit_environment_v{ASSET_VERSION}.blend"
)
GLB_PATH = (
    ROOT
    / "assets"
    / "models"
    / "generated"
    / f"momentum_circuit_v{ASSET_VERSION}"
    / f"momentum_circuit_environment_v{ASSET_VERSION}.glb"
)

MATERIAL_PREFIX = f"MC{ASSET_VERSION}_"
CERAMIC = MATERIAL_PREFIX + "VioletCeramic"
TRIM = MATERIAL_PREFIX + "LavenderTrim"
GUNMETAL = MATERIAL_PREFIX + "Gunmetal"
CYAN = MATERIAL_PREFIX + "CyanEmission"
AMBER = MATERIAL_PREFIX + "AmberEmission"


def blender_location(value: tuple[float, float, float]) -> tuple[float, float, float]:
    if ASSET_VERSION < 9:
        return value
    # Builder coordinates are authored in Godot's X/Y-up/Z convention.
    # Blender is Z-up and exports +Y toward Godot -Z.
    return (value[0], -value[2], value[1])


def blender_scale(value: tuple[float, float, float]) -> tuple[float, float, float]:
    if ASSET_VERSION < 9:
        return value
    return (value[0], value[2], value[1])


def blender_rotation(value: tuple[float, float, float]) -> tuple[float, float, float]:
    if ASSET_VERSION < 9:
        return value
    return (value[0], -value[2], -value[1])


def reset_scene() -> None:
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)
    for datablocks in (
        bpy.data.meshes,
        bpy.data.curves,
        bpy.data.materials,
        bpy.data.cameras,
        bpy.data.lights,
    ):
        for datablock in list(datablocks):
            datablocks.remove(datablock)


def material(
    name: str,
    color: tuple[float, float, float, float],
    roughness: float,
    metallic: float = 0.0,
    emission_strength: float = 0.0,
) -> bpy.types.Material:
    result = bpy.data.materials.new(name)
    result.diffuse_color = color
    result.use_nodes = True
    principled = result.node_tree.nodes.get("Principled BSDF")
    principled.inputs["Base Color"].default_value = color
    principled.inputs["Roughness"].default_value = roughness
    principled.inputs["Metallic"].default_value = metallic
    if emission_strength > 0.0:
        principled.inputs["Emission Color"].default_value = color
        principled.inputs["Emission Strength"].default_value = emission_strength
    return result


def make_empty(name: str, parent: bpy.types.Object | None = None) -> bpy.types.Object:
    result = bpy.data.objects.new(name, None)
    bpy.context.scene.collection.objects.link(result)
    result.empty_display_type = "PLAIN_AXES"
    result.parent = parent
    return result


def finish_object(
    obj: bpy.types.Object,
    name: str,
    parent: bpy.types.Object,
    mat: bpy.types.Material,
) -> bpy.types.Object:
    obj.name = name
    obj.parent = parent
    obj.data.materials.append(mat)
    obj["visual_only"] = True
    return obj


def add_box(
    name: str,
    parent: bpy.types.Object,
    mat: bpy.types.Material,
    location: tuple[float, float, float],
    scale: tuple[float, float, float],
    rotation: tuple[float, float, float] = (0.0, 0.0, 0.0),
    bevel: float = 0.08,
) -> bpy.types.Object:
    bpy.ops.mesh.primitive_cube_add(
        location=blender_location(location),
        rotation=blender_rotation(rotation),
    )
    obj = bpy.context.object
    obj.scale = blender_scale(scale)
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    if bevel > 0.0:
        modifier = obj.modifiers.new("LowPolyBevel", "BEVEL")
        modifier.width = bevel
        modifier.segments = 2 if ASSET_VERSION >= 9 else 1
    return finish_object(obj, name, parent, mat)


def add_cylinder(
    name: str,
    parent: bpy.types.Object,
    mat: bpy.types.Material,
    location: tuple[float, float, float],
    radius: float,
    depth: float,
    vertices: int = 12,
    rotation: tuple[float, float, float] = (0.0, 0.0, 0.0),
) -> bpy.types.Object:
    bpy.ops.mesh.primitive_cylinder_add(
        vertices=vertices,
        radius=radius,
        depth=depth,
        location=blender_location(location),
        rotation=blender_rotation(rotation),
    )
    return finish_object(bpy.context.object, name, parent, mat)


def add_sphere(
    name: str,
    parent: bpy.types.Object,
    mat: bpy.types.Material,
    location: tuple[float, float, float],
    scale: tuple[float, float, float],
) -> bpy.types.Object:
    bpy.ops.mesh.primitive_ico_sphere_add(
        subdivisions=1,
        radius=1.0,
        location=blender_location(location),
    )
    obj = bpy.context.object
    obj.scale = blender_scale(scale)
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    return finish_object(obj, name, parent, mat)


def add_torus(
    name: str,
    parent: bpy.types.Object,
    mat: bpy.types.Material,
    location: tuple[float, float, float],
    major_radius: float,
    minor_radius: float,
    rotation: tuple[float, float, float] = (0.0, 0.0, 0.0),
) -> bpy.types.Object:
    bpy.ops.mesh.primitive_torus_add(
        major_segments=16,
        minor_segments=4,
        major_radius=major_radius,
        minor_radius=minor_radius,
        location=blender_location(location),
        rotation=blender_rotation(rotation),
    )
    return finish_object(bpy.context.object, name, parent, mat)


def family(root: bpy.types.Object, index: int, name: str) -> bpy.types.Object:
    result = make_empty(f"EnvFamily{index:02d}_{name}", root)
    result["family_index"] = index
    result["family_id"] = name
    result["visual_only"] = True
    return result


def consolidate_family(parent: bpy.types.Object) -> None:
    """Join same-material parts so each family stays within a tiny draw budget."""
    mesh_children = [child for child in parent.children if child.type == "MESH"]
    for obj in mesh_children:
        bpy.context.view_layer.objects.active = obj
        for modifier in list(obj.modifiers):
            bpy.ops.object.modifier_apply(modifier=modifier.name)
    by_material: dict[str, list[bpy.types.Object]] = {}
    for obj in mesh_children:
        material_name = obj.data.materials[0].name if obj.data.materials else "Unassigned"
        by_material.setdefault(material_name, []).append(obj)
    for material_name, objects in by_material.items():
        bpy.ops.object.select_all(action="DESELECT")
        for obj in objects:
            obj.select_set(True)
        bpy.context.view_layer.objects.active = objects[0]
        if len(objects) > 1:
            bpy.ops.object.join()
        joined = bpy.context.view_layer.objects.active
        joined.name = f"{parent.name}_{material_name.removeprefix(MATERIAL_PREFIX)}"
        joined.parent = parent
        joined["visual_only"] = True


def build_ring_segment(root, mats) -> None:
    parent = family(root, 1, "RingSegment")
    radius = 7.4 if ASSET_VERSION >= 9 else 4.6
    angles = (
        [math.radians(-68.0 + 13.6 * float(index)) for index in range(11)]
        if ASSET_VERSION >= 9
        else [math.radians(value) for value in (-36.0, -18.0, 0.0, 18.0, 36.0)]
    )
    for index, angle in enumerate(angles):
        x = math.sin(angle) * radius
        z = math.cos(angle) * radius
        add_box(
            f"RingHull_{index:02d}",
            parent,
            mats[CERAMIC],
            (x, 0.0, z),
            (1.18 if ASSET_VERSION >= 9 else 1.05, 0.62 if ASSET_VERSION >= 9 else 0.28, 1.48 if ASSET_VERSION >= 9 else 0.64),
            (0.0, angle, 0.0),
            0.16 if ASSET_VERSION >= 9 else 0.12,
        )
        if ASSET_VERSION >= 9:
            add_box(
                f"RingTopPlate_{index:02d}",
                parent,
                mats[GUNMETAL],
                (x, 0.68, z),
                (0.96, 0.08, 1.18),
                (0.0, angle, 0.0),
                0.05,
            )
        add_box(
            f"RingLight_{index:02d}",
            parent,
            mats[CYAN],
            (math.sin(angle) * (radius - 1.62), 0.08, math.cos(angle) * (radius - 1.62)),
            (0.78 if ASSET_VERSION >= 9 else 0.52, 0.18 if ASSET_VERSION >= 9 else 0.06, 0.12 if ASSET_VERSION >= 9 else 0.06),
            (0.0, angle, 0.0),
            0.02,
        )
    if ASSET_VERSION >= 9:
        # The tower sits on the central socket.  A short, wide bridge joins it
        # to the apex of the C-shaped collector so the complete station reads
        # as one piece even at the overview camera distance.
        add_box(
            "ArcTowerBridge",
            parent,
            mats[CERAMIC],
            (0.0, 0.0, 3.65),
            (1.58, 0.62, 2.45),
            bevel=0.18,
        )
        add_box(
            "ArcTowerBridgeLight",
            parent,
            mats[CYAN],
            (0.0, 0.69, 3.65),
            (0.16, 0.06, 2.08),
            bevel=0.03,
        )
        add_cylinder(
            "ArcTowerSocket",
            parent,
            mats[GUNMETAL],
            (0.0, 0.02, 0.0),
            2.55,
            1.15,
            12,
        )
        add_torus(
            "ArcTowerSocketTrim",
            parent,
            mats[TRIM],
            (0.0, 0.63, 0.0),
            2.08,
            0.16,
        )
        # Thick end pylons make the arc read as a suspended maintenance
        # gantry rather than an isolated decorative ring.
        for end_index, angle in enumerate((angles[0], angles[-1])):
            add_box(
                f"ArcEndPylon{end_index + 1}",
                parent,
                mats[GUNMETAL],
                (math.sin(angle) * radius, -1.16, math.cos(angle) * radius),
                (1.34, 1.72, 1.64),
                (0.0, angle, 0.0),
                0.16,
            )
            add_box(
                f"ArcEndLamp{end_index + 1}",
                parent,
                mats[AMBER],
                (math.sin(angle) * (radius - 1.64), -0.22, math.cos(angle) * (radius - 1.64)),
                (0.58, 0.20, 0.16),
                (0.0, angle, 0.0),
                0.04,
            )
    else:
        add_box("RingSpine", parent, mats[GUNMETAL], (0.0, -0.28, 4.0), (4.0, 0.14, 0.18), bevel=0.05)


def build_energy_tower(root, mats) -> None:
    parent = family(root, 2, "EnergyTower")
    add_cylinder("TowerFoundation", parent, mats[GUNMETAL], (0, 0.34, 0), 2.35, 0.68, 12)
    add_cylinder("TowerBase", parent, mats[CERAMIC], (0, 0.82, 0), 1.85, 0.44, 12)
    add_torus("TowerBaseTrim", parent, mats[TRIM], (0, 1.08, 0), 1.62, 0.16)
    add_cylinder("TowerDeck", parent, mats[GUNMETAL], (0, 1.23, 0), 1.18, 0.34, 12)
    add_cylinder("TowerCore", parent, mats[CYAN], (0, 2.75, 0), 0.42, 3.75, 10)
    if ASSET_VERSION >= 9:
        for index in range(4):
            angle = math.tau * float(index) / 4.0
            add_box(
                f"TowerCasingRail{index + 1}",
                parent,
                mats[CERAMIC],
                (math.cos(angle) * 0.68, 2.86, math.sin(angle) * 0.68),
                (0.34, 2.48, 0.42),
                (0.0, -angle, 0.0),
                0.08,
            )
    else:
        add_cylinder("TowerCasing", parent, mats[TRIM], (0, 2.4, 0), 0.64, 2.2, 10)
    add_torus(
        "TowerCollar",
        parent,
        mats[TRIM],
        (0, 1.48, 0),
        0.82,
        0.12,
        (0, 0, 0) if ASSET_VERSION >= 9 else (math.pi / 2, 0, 0),
    )
    add_cylinder("TowerSpire", parent, mats[CYAN], (0, 5.0, 0), 0.12, 1.1, 8)
    if ASSET_VERSION >= 9:
        add_cylinder("TowerUpperCap", parent, mats[GUNMETAL], (0, 4.42, 0), 1.02, 0.42, 12)
        add_torus("TowerUpperCapTrim", parent, mats[TRIM], (0, 4.66, 0), 0.86, 0.12)
        for index, height in enumerate((1.18, 2.22, 3.28)):
            add_torus(
                f"TowerStructureRing{index + 1}",
                parent,
                mats[GUNMETAL],
                (0, height, 0),
                0.70,
                0.08,
                (0, 0, 0),
            )
        for index in range(4):
            angle = math.tau * float(index) / 4.0
            add_box(
                f"TowerBaseButtress{index + 1}",
                parent,
                mats[CERAMIC],
                (math.cos(angle) * 2.04, 0.72, math.sin(angle) * 2.04),
                (0.56, 0.62, 0.82),
                (0.0, -angle, 0.0),
                0.12,
            )
        for index in range(4):
            angle = math.tau * float(index) / 4.0
            add_box(
                f"TowerCrownFork{index + 1}",
                parent,
                mats[GUNMETAL],
                (math.cos(angle) * 0.48, 5.18, math.sin(angle) * 0.48),
                (0.18, 0.72, 0.24),
                (0.0, -angle, 0.0),
                0.05,
            )


def build_navigation_beacon(root, mats) -> None:
    parent = family(root, 3, "NavigationBeacon")
    add_cylinder("BeaconFoot", parent, mats[GUNMETAL], (0, 0.18, 0), 0.72, 0.36, 10)
    add_cylinder("BeaconMast", parent, mats[TRIM], (0, 1.35, 0), 0.16, 2.35, 8)
    add_sphere("BeaconLamp", parent, mats[CYAN], (0, 2.65, 0), (0.34, 0.34, 0.34))
    for index in range(3):
        angle = index * TAU / 3.0
        add_box(
            f"BeaconFin_{index}",
            parent,
            mats[CERAMIC],
            (math.cos(angle) * 0.42, 0.7, math.sin(angle) * 0.42),
            (0.34, 0.05, 0.12),
            (0.0, -angle, 0.0),
            0.03,
        )


def build_maintenance_disc(root, mats) -> None:
    parent = family(root, 4, "MaintenanceDisc")
    add_cylinder("DiscHull", parent, mats[CERAMIC], (0, 0.18, 0), 1.45, 0.36, 12)
    add_cylinder("DiscInset", parent, mats[GUNMETAL], (0, 0.38, 0), 0.88, 0.16, 12)
    add_torus(
        "DiscLight",
        parent,
        mats[CYAN],
        (0, 0.48, 0),
        0.88,
        0.08,
        (0, 0, 0) if ASSET_VERSION >= 9 else (math.pi / 2, 0, 0),
    )
    add_box("DiscDock", parent, mats[TRIM], (1.5, 0.1, 0), (0.42, 0.18, 0.62), bevel=0.08)


def build_mechanical_arm(root, mats) -> None:
    parent = family(root, 5, "MechanicalArm")
    add_cylinder("ArmBase", parent, mats[GUNMETAL], (0, 0.35, 0), 0.85, 0.7, 10)
    add_sphere("ArmJointA", parent, mats[TRIM], (0, 1.0, 0), (0.5, 0.5, 0.5))
    add_box("ArmUpper", parent, mats[CERAMIC], (0, 2.0, 0), (0.35, 1.0, 0.42), (0, 0, -0.34), 0.09)
    add_sphere("ArmJointB", parent, mats[AMBER], (0.66, 2.9, 0), (0.42, 0.42, 0.42))
    add_box("ArmFore", parent, mats[CERAMIC], (1.38, 3.45, 0), (0.9, 0.28, 0.34), (0, 0, 0.36), 0.08)
    add_sphere("ArmJointC", parent, mats[TRIM], (2.2, 3.92, 0), (0.38, 0.38, 0.38))
    add_box("ArmTool", parent, mats[GUNMETAL], (2.64, 4.15, 0), (0.45, 0.16, 0.52), (0, 0, 0.2), 0.04)


def build_docking_frame(root, mats) -> None:
    parent = family(root, 6, "DockingFrame")
    add_box("DockLeft", parent, mats[CERAMIC], (-2.5, 1.5, 0), (0.42, 1.5, 0.56), bevel=0.1)
    add_box("DockRight", parent, mats[CERAMIC], (2.5, 1.5, 0), (0.42, 1.5, 0.56), bevel=0.1)
    add_box("DockTop", parent, mats[CERAMIC], (0, 2.72, 0), (2.15, 0.28, 0.56), bevel=0.1)
    add_box("DockFootL", parent, mats[GUNMETAL], (-2.5, 0.18, 0), (0.8, 0.18, 1.05), bevel=0.06)
    add_box("DockFootR", parent, mats[GUNMETAL], (2.5, 0.18, 0), (0.8, 0.18, 1.05), bevel=0.06)
    for side in (-1.0, 1.0):
        add_box(
            f"DockGuide_{'L' if side < 0 else 'R'}",
            parent,
            mats[CYAN],
            (side * 1.72, 2.55, -0.58),
            (0.58, 0.06, 0.06),
            bevel=0.02,
        )
    if ASSET_VERSION >= 9:
        add_box("DockThreshold", parent, mats[TRIM], (0, 0.18, 0), (1.65, 0.16, 1.0), bevel=0.08)
        add_box("DockHeaderLight", parent, mats[CYAN], (0, 2.52, -0.58), (1.08, 0.07, 0.06), bevel=0.02)


def build_cargo_skiff(root, mats) -> None:
    parent = family(root, 7, "CargoSkiff")
    add_box("SkiffHull", parent, mats[CERAMIC], (0, 0.35, 0), (2.2, 0.38, 0.82), bevel=0.18)
    add_box("SkiffCab", parent, mats[TRIM], (0.75, 0.92, 0), (0.72, 0.42, 0.62), bevel=0.12)
    add_box("SkiffCargo", parent, mats[GUNMETAL], (-0.75, 0.88, 0), (0.72, 0.44, 0.68), bevel=0.08)
    for z in (-0.58, 0.58):
        add_box("SkiffEngine", parent, mats[CYAN], (-2.18, 0.34, z), (0.18, 0.18, 0.15), bevel=0.04)


def build_maintenance_drone(root, mats) -> None:
    parent = family(root, 8, "MaintenanceDrone")
    add_cylinder("DroneBody", parent, mats[CERAMIC], (0, 0, 0), 0.9, 0.38, 10)
    add_sphere("DroneCore", parent, mats[CYAN], (0, 0.26, 0), (0.38, 0.22, 0.38))
    for index in range(4):
        angle = index * math.pi / 2.0
        add_box(
            f"DroneArm_{index}",
            parent,
            mats[GUNMETAL],
            (math.cos(angle) * 0.92, 0, math.sin(angle) * 0.92),
            (0.54, 0.08, 0.13),
            (0, -angle, 0),
            0.04,
        )
        add_sphere(
            f"DroneTip_{index}",
            parent,
            mats[AMBER],
            (math.cos(angle) * 1.46, 0, math.sin(angle) * 1.46),
            (0.18, 0.18, 0.18),
        )


def build_patrol_probe(root, mats) -> None:
    parent = family(root, 9, "PatrolProbe")
    add_sphere("ProbeCore", parent, mats[CERAMIC], (0, 0, 0), (0.72, 0.72, 0.72))
    add_sphere("ProbeEye", parent, mats[CYAN], (0, 0.05, -0.67), (0.28, 0.28, 0.16))
    for index in range(3):
        angle = index * TAU / 3.0
        add_box(
            f"ProbeFin_{index}",
            parent,
            mats[TRIM],
            (math.cos(angle) * 0.88, -0.05, math.sin(angle) * 0.88),
            (0.68, 0.08, 0.24),
            (0, -angle, 0),
            0.04,
        )


def build_sensor_pylon(root, mats) -> None:
    parent = family(root, 10, "SensorPylon")
    add_cylinder("SensorBase", parent, mats[GUNMETAL], (0, 0.25, 0), 1.05, 0.5, 12)
    add_cylinder("SensorColumn", parent, mats[CERAMIC], (0, 1.65, 0), 0.42, 2.8, 10)
    add_torus(
        "SensorHalo",
        parent,
        mats[CYAN],
        (0, 2.75, 0),
        0.92,
        0.09,
        (0, 0, 0) if ASSET_VERSION >= 9 else (math.pi / 2, 0, 0),
    )
    add_box("SensorHead", parent, mats[TRIM], (0, 3.1, 0), (0.72, 0.22, 0.42), bevel=0.08)
    add_cylinder("SensorSpire", parent, mats[AMBER], (0, 3.82, 0), 0.10, 1.1, 8)


def main() -> None:
    reset_scene()
    mats = {
        CERAMIC: material(CERAMIC, (0.18, 0.14, 0.34, 1.0), 0.78, 0.02),
        TRIM: material(TRIM, (0.37, 0.30, 0.56, 1.0), 0.68, 0.03),
        GUNMETAL: material(GUNMETAL, (0.06, 0.05, 0.12, 1.0), 0.62, 0.16),
        CYAN: material(CYAN, (0.08, 0.72, 0.90, 1.0), 0.38, 0.02, 1.75 if ASSET_VERSION >= 9 else 3.6),
        AMBER: material(AMBER, (1.0, 0.50, 0.20, 1.0), 0.44, 0.02, 2.4),
    }

    root = make_empty(f"MomentumCircuitEnvironmentV{ASSET_VERSION}")
    root["visual_only"] = True
    root["model_family_count"] = 10
    root["max_materials"] = 5
    root["collision_owner"] = "Godot gameplay scene"

    build_ring_segment(root, mats)
    build_energy_tower(root, mats)
    build_navigation_beacon(root, mats)
    build_maintenance_disc(root, mats)
    build_mechanical_arm(root, mats)
    build_docking_frame(root, mats)
    build_cargo_skiff(root, mats)
    build_maintenance_drone(root, mats)
    build_patrol_probe(root, mats)
    build_sensor_pylon(root, mats)

    for family_root in list(root.children):
        consolidate_family(family_root)

    for obj in bpy.context.scene.objects:
        obj.select_set(True)
    bpy.context.view_layer.objects.active = root

    SOURCE_PATH.parent.mkdir(parents=True, exist_ok=True)
    GLB_PATH.parent.mkdir(parents=True, exist_ok=True)
    bpy.ops.wm.save_as_mainfile(filepath=str(SOURCE_PATH))
    bpy.ops.export_scene.gltf(
        filepath=str(GLB_PATH),
        export_format="GLB",
        export_yup=True,
        export_apply=True,
        export_extras=True,
        export_lights=False,
        export_cameras=False,
        export_animations=False,
    )
    print(f"Momentum Circuit v{ASSET_VERSION} source: {SOURCE_PATH}")
    print(f"Momentum Circuit v{ASSET_VERSION} GLB: {GLB_PATH}")


if __name__ == "__main__":
    TAU = math.tau
    main()
