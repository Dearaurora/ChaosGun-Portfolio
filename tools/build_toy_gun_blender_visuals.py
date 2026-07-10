import math
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


def add_muzzle(name, y, material, glow_material):
    # The model points toward Blender -Y, which imports as Godot -Z.
    add_cylinder(name + "Barrel", (0, y, 0.18), 0.045, 0.28, material, 0.01, (math.radians(90), 0, 0), 24)
    add_cylinder(name + "MuzzleGlow", (0, y - 0.17, 0.18), 0.065, 0.035, glow_material, 0.005, (math.radians(90), 0, 0), 24)


def build_pistol():
    blue = mat("pistol_blue_shell", (0.08, 0.58, 0.95, 1.0), 0.66)
    orange = mat("pistol_orange_trim", (1.0, 0.37, 0.12, 1.0), 0.62)
    dark = mat("soft_black_grip", (0.055, 0.06, 0.075, 1.0), 0.78)
    steel = mat("warm_steel_barrel", (0.78, 0.80, 0.82, 1.0), 0.5, 0.05)
    glow = mat("pistol_muzzle_blue", (0.42, 0.9, 1.0, 1.0), 0.35, emission=(0.25, 0.75, 1.0, 1.0), strength=0.35)

    add_cube("Body", (0, -0.28, 0.18), (0.34, 0.58, 0.23), blue, 0.055)
    add_cube("Slide", (0, -0.36, 0.32), (0.40, 0.52, 0.13), orange, 0.045)
    add_cube("Grip", (0, 0.02, -0.08), (0.25, 0.20, 0.44), dark, 0.045, (math.radians(-12), 0, 0))
    add_cube("TriggerGuard", (0, -0.11, 0.03), (0.26, 0.12, 0.15), orange, 0.028)
    add_muzzle("Pistol", -0.64, steel, glow)


def build_smg():
    green = mat("smg_lime_shell", (0.45, 0.86, 0.12, 1.0), 0.68)
    yellow = mat("smg_yellow_trim", (1.0, 0.72, 0.16, 1.0), 0.62)
    dark = mat("smg_dark_parts", (0.055, 0.07, 0.07, 1.0), 0.78)
    steel = mat("smg_soft_steel", (0.72, 0.75, 0.75, 1.0), 0.5, 0.05)
    glow = mat("smg_muzzle_green", (0.62, 1.0, 0.26, 1.0), 0.35, emission=(0.38, 1.0, 0.2, 1.0), strength=0.35)

    add_cube("Body", (0, -0.42, 0.18), (0.35, 0.86, 0.24), green, 0.055)
    add_cube("TopRail", (0, -0.42, 0.34), (0.28, 0.70, 0.10), yellow, 0.035)
    add_cube("Grip", (0, -0.02, -0.09), (0.22, 0.18, 0.43), dark, 0.04, (math.radians(-10), 0, 0))
    add_cube("Magazine", (0, -0.40, -0.13), (0.20, 0.18, 0.42), dark, 0.035, (math.radians(8), 0, 0))
    add_cube("StubStock", (0, 0.11, 0.17), (0.30, 0.25, 0.20), yellow, 0.04)
    add_muzzle("SMG", -0.91, steel, glow)


def build_ak_rifle():
    orange = mat("rifle_orange_shell", (1.0, 0.48, 0.08, 1.0), 0.66)
    amber = mat("rifle_amber_trim", (1.0, 0.75, 0.18, 1.0), 0.62)
    dark = mat("rifle_dark_parts", (0.06, 0.055, 0.05, 1.0), 0.78)
    steel = mat("rifle_soft_steel", (0.72, 0.73, 0.70, 1.0), 0.48, 0.05)
    glow = mat("rifle_muzzle_warm", (1.0, 0.72, 0.18, 1.0), 0.32, emission=(1.0, 0.58, 0.12, 1.0), strength=0.35)

    add_cube("LongBody", (0, -0.55, 0.19), (0.34, 1.10, 0.24), orange, 0.055)
    add_cube("ForegripTrim", (0, -0.90, 0.35), (0.30, 0.34, 0.10), amber, 0.035)
    add_cube("Stock", (0, 0.18, 0.18), (0.38, 0.48, 0.24), dark, 0.05, (math.radians(4), 0, 0))
    add_cube("Grip", (0, -0.12, -0.10), (0.22, 0.18, 0.46), dark, 0.04, (math.radians(-12), 0, 0))
    add_cube("CurvedMag", (0, -0.46, -0.18), (0.22, 0.26, 0.52), amber, 0.04, (math.radians(13), 0, 0))
    add_cylinder("RifleBarrel", (0, -1.25, 0.19), 0.04, 0.48, steel, 0.008, (math.radians(90), 0, 0), 24)
    add_cylinder("RifleMuzzleGlow", (0, -1.53, 0.19), 0.06, 0.035, glow, 0.005, (math.radians(90), 0, 0), 24)


def build_sniper():
    cyan = mat("sniper_cyan_shell", (0.10, 0.72, 0.92, 1.0), 0.66)
    cream = mat("sniper_cream_trim", (1.0, 0.92, 0.68, 1.0), 0.64)
    dark = mat("sniper_dark_parts", (0.045, 0.055, 0.07, 1.0), 0.78)
    steel = mat("sniper_soft_steel", (0.76, 0.78, 0.80, 1.0), 0.48, 0.05)
    glass = mat("sniper_scope_glass", (0.50, 0.95, 1.0, 1.0), 0.34, emission=(0.16, 0.65, 1.0, 1.0), strength=0.2)
    glow = mat("sniper_muzzle_cyan", (0.50, 0.95, 1.0, 1.0), 0.32, emission=(0.18, 0.75, 1.0, 1.0), strength=0.35)

    add_cube("SlimBody", (0, -0.64, 0.18), (0.25, 1.22, 0.20), cyan, 0.045)
    add_cube("Stock", (0, 0.25, 0.17), (0.34, 0.56, 0.22), dark, 0.045)
    add_cube("Grip", (0, -0.08, -0.10), (0.20, 0.16, 0.42), dark, 0.035, (math.radians(-12), 0, 0))
    add_cube("Magazine", (0, -0.52, -0.12), (0.17, 0.16, 0.34), cream, 0.035)
    add_cylinder("ScopeTube", (0, -0.54, 0.43), 0.08, 0.52, dark, 0.008, (math.radians(90), 0, 0), 24)
    add_cylinder("ScopeLens", (0, -0.83, 0.43), 0.083, 0.025, glass, 0.004, (math.radians(90), 0, 0), 24)
    add_cylinder("LongBarrel", (0, -1.31, 0.19), 0.032, 0.70, steel, 0.006, (math.radians(90), 0, 0), 24)
    add_cylinder("SniperMuzzleGlow", (0, -1.72, 0.19), 0.052, 0.035, glow, 0.004, (math.radians(90), 0, 0), 24)


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
    export_weapon("pistol", build_pistol)
    export_weapon("smg", build_smg)
    export_weapon("ak_rifle", build_ak_rifle)
    export_weapon("sniper", build_sniper)


if __name__ == "__main__":
    main()
