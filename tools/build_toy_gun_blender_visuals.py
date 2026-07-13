import argparse
import math
import sys
from pathlib import Path

import bpy


OUT_DIR = Path("assets/models/generated/weapons")


def clear_scene():
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete()


def mat(name, color, roughness=0.72, metallic=0.0, emission=None, strength=0.0):
    material = bpy.data.materials.new(name)
    material.use_nodes = True
    bsdf = material.node_tree.nodes.get("Principled BSDF")
    bsdf.inputs["Base Color"].default_value = color
    bsdf.inputs["Roughness"].default_value = roughness
    bsdf.inputs["Metallic"].default_value = metallic
    if emission is not None and "Emission Color" in bsdf.inputs:
        bsdf.inputs["Emission Color"].default_value = emission
        bsdf.inputs["Emission Strength"].default_value = strength
    return material


def add_cube(name, loc, scale, material, bevel=0.035, rot=(0, 0, 0)):
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=loc, rotation=rot)
    obj = bpy.context.object
    obj.name = name
    obj.dimensions = scale
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    obj.data.materials.append(material)
    if bevel > 0.0:
        bevel_mod = obj.modifiers.new(name="toy_bevel", type="BEVEL")
        bevel_mod.width = bevel
        bevel_mod.segments = 5
        bevel_mod.affect = "EDGES"
        normal = obj.modifiers.new(name="weighted_normals", type="WEIGHTED_NORMAL")
        normal.keep_sharp = True
    return obj


def add_cylinder(name, loc, radius, depth, material, bevel=0.0, rot=(0, 0, 0), vertices=24):
    bpy.ops.mesh.primitive_cylinder_add(vertices=vertices, radius=radius, depth=depth, location=loc, rotation=rot)
    obj = bpy.context.object
    obj.name = name
    obj.data.materials.append(material)
    bpy.ops.object.shade_smooth()
    if bevel > 0.0:
        bevel_mod = obj.modifiers.new(name="toy_bevel", type="BEVEL")
        bevel_mod.width = bevel
        bevel_mod.segments = 4
        bevel_mod.affect = "EDGES"
    normal = obj.modifiers.new(name="weighted_normals", type="WEIGHTED_NORMAL")
    normal.keep_sharp = True
    return obj


def add_tapered_box(name, loc, rear_width, front_width, length, height, material, bevel=0.035):
    rear_y = length * 0.5
    front_y = -length * 0.5
    bottom = -height * 0.5
    top = height * 0.5
    vertices = [
        (-rear_width * 0.5, rear_y, bottom), (rear_width * 0.5, rear_y, bottom),
        (rear_width * 0.5, rear_y, top), (-rear_width * 0.5, rear_y, top),
        (-front_width * 0.5, front_y, bottom), (front_width * 0.5, front_y, bottom),
        (front_width * 0.5, front_y, top), (-front_width * 0.5, front_y, top),
    ]
    faces = [(0, 1, 2, 3), (4, 7, 6, 5), (0, 4, 5, 1), (3, 2, 6, 7), (1, 5, 6, 2), (0, 3, 7, 4)]
    mesh = bpy.data.meshes.new(name + "Mesh")
    mesh.from_pydata(vertices, [], faces)
    mesh.materials.append(material)
    obj = bpy.data.objects.new(name, mesh)
    obj.location = loc
    bpy.context.collection.objects.link(obj)
    bevel_mod = obj.modifiers.new(name="toy_bevel", type="BEVEL")
    bevel_mod.width = bevel
    bevel_mod.segments = 4
    bevel_mod.affect = "EDGES"
    normal = obj.modifiers.new(name="weighted_normals", type="WEIGHTED_NORMAL")
    normal.keep_sharp = True
    return obj


def add_muzzle(name, y, material, glow_material):
    # The model points toward Blender -Y, which imports as Godot -Z.
    add_cylinder(name + "Barrel", (0, y, 0.18), 0.045, 0.28, material, 0.01, (math.radians(90), 0, 0), 24)
    add_cylinder(name + "MuzzleGlow", (0, y - 0.17, 0.18), 0.065, 0.035, glow_material, 0.005, (math.radians(90), 0, 0), 24)


def build_pistol():
    shell = mat("pistol_plum_shell", (0.15, 0.11, 0.16, 1.0), 0.70)
    slide = mat("pistol_graphite_slide", (0.075, 0.08, 0.10, 1.0), 0.64)
    accent = mat("pistol_red_side_accent", (0.92, 0.18, 0.16, 1.0), 0.68)
    warm = mat("pistol_warm_function_trim", (1.0, 0.42, 0.08, 1.0), 0.60)
    dark = mat("soft_black_grip", (0.04, 0.045, 0.06, 1.0), 0.80)
    steel = mat("warm_steel_barrel", (0.58, 0.60, 0.64, 1.0), 0.58, 0.03)
    glow = mat("pistol_muzzle_warm", (1.0, 0.50, 0.10, 1.0), 0.35, emission=(1.0, 0.32, 0.05, 1.0), strength=0.35)

    add_tapered_box("Body", (0, -0.28, 0.18), 0.36, 0.30, 0.62, 0.24, shell, 0.05)
    add_cube("Slide", (0, -0.37, 0.33), (0.40, 0.56, 0.13), slide, 0.04)
    add_cube("SlideInsetLeft", (-0.205, -0.38, 0.32), (0.025, 0.30, 0.065), accent, 0.01)
    add_cube("SlideInsetRight", (0.205, -0.38, 0.32), (0.025, 0.30, 0.065), accent, 0.01)
    add_cube("Grip", (0, 0.02, -0.08), (0.25, 0.20, 0.44), dark, 0.045, (math.radians(-12), 0, 0))
    add_cube("TriggerGuard", (0, -0.11, 0.03), (0.26, 0.12, 0.15), warm, 0.028)
    add_cube("RearSight", (0, -0.12, 0.43), (0.24, 0.06, 0.055), dark, 0.012)
    add_cube("FrontSight", (0, -0.61, 0.43), (0.08, 0.05, 0.065), dark, 0.01)
    add_muzzle("Pistol", -0.64, steel, glow)


def build_smg():
    shell = mat("smg_plum_shell", (0.13, 0.11, 0.15, 1.0), 0.70)
    green = mat("smg_lime_accent", (0.38, 0.76, 0.16, 1.0), 0.70)
    warm = mat("smg_warm_trim", (1.0, 0.54, 0.10, 1.0), 0.62)
    dark = mat("smg_dark_parts", (0.04, 0.05, 0.06, 1.0), 0.80)
    steel = mat("smg_soft_steel", (0.56, 0.59, 0.61, 1.0), 0.58, 0.03)
    glow = mat("smg_muzzle_green", (0.62, 1.0, 0.26, 1.0), 0.35, emission=(0.38, 1.0, 0.2, 1.0), strength=0.35)

    add_tapered_box("Body", (0, -0.38, 0.18), 0.38, 0.32, 0.76, 0.25, shell, 0.05)
    add_cube("FrontShroud", (0, -0.78, 0.18), (0.32, 0.30, 0.28), green, 0.045)
    add_cube("TopRail", (0, -0.43, 0.35), (0.24, 0.64, 0.08), dark, 0.025)
    for y in (-0.72, -0.81):
        add_cube("ShroudVent", (0, y, 0.34), (0.18, 0.035, 0.035), dark, 0.008)
    add_cube("Grip", (0, -0.02, -0.09), (0.22, 0.18, 0.43), dark, 0.04, (math.radians(-10), 0, 0))
    add_cube("Magazine", (0, -0.40, -0.13), (0.20, 0.18, 0.42), dark, 0.035, (math.radians(8), 0, 0))
    add_tapered_box("StubStock", (0, 0.16, 0.17), 0.34, 0.25, 0.34, 0.22, dark, 0.04)
    add_cube("ChargingHandle", (0.21, -0.23, 0.27), (0.12, 0.10, 0.06), warm, 0.018)
    add_muzzle("SMG", -0.91, steel, glow)


def build_ak_rifle():
    shell = mat("rifle_plum_receiver", (0.14, 0.105, 0.13, 1.0), 0.70)
    orange = mat("rifle_orange_accent", (0.91, 0.30, 0.08, 1.0), 0.68)
    amber = mat("rifle_amber_trim", (0.93, 0.60, 0.14, 1.0), 0.66)
    dark = mat("rifle_dark_parts", (0.045, 0.043, 0.05, 1.0), 0.80)
    steel = mat("rifle_soft_steel", (0.56, 0.57, 0.56, 1.0), 0.58, 0.03)
    glow = mat("rifle_muzzle_warm", (1.0, 0.72, 0.18, 1.0), 0.32, emission=(1.0, 0.58, 0.12, 1.0), strength=0.35)

    add_tapered_box("Receiver", (0, -0.42, 0.19), 0.38, 0.34, 0.66, 0.26, shell, 0.05)
    add_tapered_box("Foregrip", (0, -0.92, 0.19), 0.35, 0.26, 0.42, 0.28, amber, 0.045)
    add_cube("TopCover", (0, -0.43, 0.36), (0.29, 0.58, 0.08), dark, 0.025)
    for y in (-0.80, -0.91, -1.02):
        add_cube("ForegripRib", (0, y, 0.34), (0.30, 0.045, 0.045), orange, 0.01)
    add_tapered_box("Stock", (0, 0.25, 0.18), 0.46, 0.28, 0.58, 0.27, dark, 0.05)
    add_cube("StockPad", (0, 0.56, 0.18), (0.48, 0.09, 0.31), amber, 0.035)
    add_cube("Grip", (0, -0.12, -0.10), (0.22, 0.18, 0.46), dark, 0.04, (math.radians(-12), 0, 0))
    add_cube("CurvedMagUpper", (0, -0.43, -0.10), (0.22, 0.22, 0.31), dark, 0.04, (math.radians(8), 0, 0))
    add_cube("CurvedMagLower", (0, -0.37, -0.34), (0.22, 0.24, 0.29), dark, 0.04, (math.radians(24), 0, 0))
    add_cylinder("RifleBarrel", (0, -1.25, 0.19), 0.04, 0.48, steel, 0.008, (math.radians(90), 0, 0), 24)
    add_cylinder("GasTube", (0, -1.16, 0.31), 0.025, 0.34, dark, 0.006, (math.radians(90), 0, 0), 20)
    add_cube("FrontSight", (0, -1.34, 0.34), (0.12, 0.07, 0.18), dark, 0.018)
    add_cylinder("RifleMuzzleGlow", (0, -1.53, 0.19), 0.06, 0.035, glow, 0.005, (math.radians(90), 0, 0), 24)


def build_sniper():
    shell = mat("sniper_plum_shell", (0.12, 0.105, 0.15, 1.0), 0.70)
    cyan = mat("sniper_cyan_accent", (0.10, 0.62, 0.80, 1.0), 0.68)
    cream = mat("sniper_cream_trim", (0.88, 0.80, 0.60, 1.0), 0.68)
    dark = mat("sniper_dark_parts", (0.04, 0.05, 0.065, 1.0), 0.80)
    steel = mat("sniper_soft_steel", (0.58, 0.60, 0.62, 1.0), 0.58, 0.03)
    glass = mat("sniper_scope_glass", (0.50, 0.95, 1.0, 1.0), 0.34, emission=(0.16, 0.65, 1.0, 1.0), strength=0.2)
    glow = mat("sniper_muzzle_cyan", (0.50, 0.95, 1.0, 1.0), 0.32, emission=(0.18, 0.75, 1.0, 1.0), strength=0.35)

    add_tapered_box("SlimBody", (0, -0.58, 0.18), 0.30, 0.22, 1.02, 0.22, shell, 0.04)
    add_tapered_box("Stock", (0, 0.28, 0.17), 0.44, 0.26, 0.66, 0.27, dark, 0.045)
    add_cube("CheekRest", (0, 0.16, 0.34), (0.31, 0.28, 0.10), cream, 0.03)
    add_cube("StockPad", (0, 0.63, 0.17), (0.46, 0.09, 0.31), cyan, 0.03)
    add_cube("Grip", (0, -0.08, -0.10), (0.20, 0.16, 0.42), dark, 0.035, (math.radians(-12), 0, 0))
    add_cube("Magazine", (0, -0.52, -0.12), (0.17, 0.16, 0.34), cream, 0.035)
    add_cube("ScopeMountRear", (0, -0.35, 0.34), (0.16, 0.10, 0.18), dark, 0.02)
    add_cube("ScopeMountFront", (0, -0.70, 0.34), (0.16, 0.10, 0.18), dark, 0.02)
    add_cylinder("ScopeTube", (0, -0.54, 0.43), 0.08, 0.52, dark, 0.008, (math.radians(90), 0, 0), 24)
    add_cylinder("ScopeRearRing", (0, -0.28, 0.43), 0.105, 0.07, cream, 0.01, (math.radians(90), 0, 0), 24)
    add_cylinder("ScopeFrontRing", (0, -0.80, 0.43), 0.105, 0.07, cream, 0.01, (math.radians(90), 0, 0), 24)
    add_cylinder("ScopeLens", (0, -0.83, 0.43), 0.083, 0.025, glass, 0.004, (math.radians(90), 0, 0), 24)
    add_cube("BarrelShroud", (0, -1.08, 0.19), (0.21, 0.36, 0.20), shell, 0.035)
    add_cylinder("LongBarrel", (0, -1.31, 0.19), 0.032, 0.70, steel, 0.006, (math.radians(90), 0, 0), 24)
    add_cube("BipodLeft", (-0.12, -1.08, -0.02), (0.04, 0.06, 0.38), dark, 0.012, (0, math.radians(-10), math.radians(-18)))
    add_cube("BipodRight", (0.12, -1.08, -0.02), (0.04, 0.06, 0.38), dark, 0.012, (0, math.radians(10), math.radians(18)))
    add_cylinder("SniperMuzzleGlow", (0, -1.72, 0.19), 0.052, 0.035, glow, 0.004, (math.radians(90), 0, 0), 24)


def build_gatling():
    shell = mat("gatling_graphite_receiver", (0.075, 0.07, 0.09, 1.0), 0.67)
    gold = mat("gatling_gold_housing", (0.94, 0.58, 0.08, 1.0), 0.64)
    cream = mat("gatling_cream_trim", (0.90, 0.80, 0.56, 1.0), 0.70)
    dark = mat("gatling_dark_mechanics", (0.035, 0.04, 0.055, 1.0), 0.82)
    steel = mat("gatling_soft_steel", (0.44, 0.48, 0.52, 1.0), 0.56, 0.06)
    cyan = mat("gatling_cyan_status", (0.12, 0.70, 0.76, 1.0), 0.48, emission=(0.08, 0.72, 0.82, 1.0), strength=0.22)
    glow = mat("gatling_muzzle_gold", (1.0, 0.78, 0.16, 1.0), 0.34, emission=(1.0, 0.56, 0.08, 1.0), strength=0.38)

    add_tapered_box("Receiver", (0, -0.36, 0.20), 0.48, 0.40, 0.72, 0.34, shell, 0.06)
    add_cube("ReceiverTop", (0, -0.40, 0.43), (0.35, 0.56, 0.11), gold, 0.032)
    add_tapered_box("RearStock", (0, 0.27, 0.19), 0.52, 0.34, 0.58, 0.34, dark, 0.055)
    add_cube("StockPad", (0, 0.59, 0.19), (0.53, 0.09, 0.38), cream, 0.035)
    add_cube("RearGrip", (0, -0.05, -0.11), (0.24, 0.20, 0.48), dark, 0.045, (math.radians(-10), 0, 0))
    add_cube("AmmoCanister", (0.31, -0.33, -0.03), (0.24, 0.43, 0.48), gold, 0.045)
    add_cube("AmmoCanisterBand", (0.315, -0.33, -0.03), (0.255, 0.09, 0.50), cream, 0.02)
    add_cube("CarryHandle", (0, -0.26, 0.58), (0.25, 0.40, 0.08), dark, 0.025)
    add_cube("StatusLight", (-0.205, -0.43, 0.35), (0.035, 0.24, 0.09), cyan, 0.01)

    add_cylinder("BarrelDrum", (0, -0.82, 0.20), 0.24, 0.36, gold, 0.025, (math.radians(90), 0, 0), 28)
    add_cylinder("BarrelDrumCore", (0, -0.84, 0.20), 0.13, 0.40, dark, 0.015, (math.radians(90), 0, 0), 24)
    barrel_offsets = [
        (-0.12, 0.20), (-0.06, 0.305), (0.06, 0.305),
        (0.12, 0.20), (0.06, 0.095), (-0.06, 0.095),
    ]
    for index, (x, z) in enumerate(barrel_offsets):
        add_cylinder(f"RotaryBarrel{index}", (x, -1.24, z), 0.035, 0.76, steel, 0.006, (math.radians(90), 0, 0), 18)
        add_cylinder(f"MuzzleGlow{index}", (x, -1.635, z), 0.047, 0.035, glow, 0.004, (math.radians(90), 0, 0), 18)
    add_cylinder("FrontBrace", (0, -1.45, 0.20), 0.22, 0.08, dark, 0.014, (math.radians(90), 0, 0), 28)


def build_shotgun():
    shell = mat("shotgun_plum_receiver", (0.13, 0.095, 0.15, 1.0), 0.70)
    violet = mat("shotgun_violet_pump", (0.56, 0.24, 0.78, 1.0), 0.68)
    cream = mat("shotgun_cream_trim", (0.91, 0.79, 0.58, 1.0), 0.70)
    dark = mat("shotgun_dark_parts", (0.04, 0.045, 0.06, 1.0), 0.82)
    steel = mat("shotgun_soft_steel", (0.52, 0.55, 0.59, 1.0), 0.56, 0.04)
    glow = mat("shotgun_muzzle_violet", (0.84, 0.48, 1.0, 1.0), 0.34, emission=(0.64, 0.20, 1.0, 1.0), strength=0.34)

    add_tapered_box("Receiver", (0, -0.39, 0.20), 0.42, 0.34, 0.66, 0.30, shell, 0.055)
    add_cube("ReceiverTop", (0, -0.43, 0.40), (0.31, 0.52, 0.09), dark, 0.025)
    add_tapered_box("Stock", (0, 0.28, 0.18), 0.52, 0.31, 0.64, 0.34, dark, 0.055)
    add_cube("StockPad", (0, 0.63, 0.18), (0.53, 0.09, 0.39), violet, 0.035)
    add_cube("Grip", (0, -0.08, -0.10), (0.23, 0.19, 0.46), dark, 0.04, (math.radians(-11), 0, 0))
    add_cube("TriggerGuard", (0, -0.24, 0.01), (0.27, 0.17, 0.15), cream, 0.025)
    add_cylinder("MainBarrel", (0, -1.11, 0.24), 0.065, 0.92, steel, 0.010, (math.radians(90), 0, 0), 24)
    add_cylinder("MagazineTube", (0, -1.02, 0.08), 0.052, 0.76, dark, 0.009, (math.radians(90), 0, 0), 22)
    add_cube("PumpBody", (0, -0.89, 0.16), (0.38, 0.43, 0.31), violet, 0.052)
    for y in (-0.75, -0.85, -0.95, -1.05):
        add_cube("PumpRib", (0, y, 0.35), (0.34, 0.035, 0.045), cream, 0.008)
    add_cube("FrontSight", (0, -1.49, 0.36), (0.10, 0.07, 0.12), cream, 0.016)
    add_cylinder("ShotgunMuzzle", (0, -1.58, 0.24), 0.085, 0.075, dark, 0.012, (math.radians(90), 0, 0), 24)
    add_cylinder("ShotgunMuzzleGlow", (0, -1.625, 0.24), 0.062, 0.025, glow, 0.004, (math.radians(90), 0, 0), 24)


def export_weapon(name, build_fn):
    clear_scene()
    build_fn()
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    out_path = OUT_DIR / f"{name}.glb"
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.export_scene.gltf(
        filepath=str(out_path),
        export_format="GLB",
        use_selection=True,
        export_apply=True,
    )
    print(f"Exported {out_path}")


def main():
    builders = {
        "pistol": build_pistol,
        "smg": build_smg,
        "ak_rifle": build_ak_rifle,
        "sniper": build_sniper,
        "gatling": build_gatling,
        "shotgun": build_shotgun,
    }
    parser = argparse.ArgumentParser()
    parser.add_argument("--weapon", action="append", choices=builders.keys())
    blender_args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    args = parser.parse_args(blender_args)
    requested = args.weapon if args.weapon else list(builders.keys())
    for name in requested:
        export_weapon(name, builders[name])


if __name__ == "__main__":
    main()
