import os
import sys
from pathlib import Path

import bpy


PROJECT_ROOT = Path(__file__).resolve().parents[1]
TOOLS_DIR = PROJECT_ROOT / "tools"
OUT_PATH = PROJECT_ROOT / "docs" / "workflow" / "commercial-slice-a-blender-visual-preview.png"

sys.path.insert(0, str(TOOLS_DIR))
import build_commercial_slice_blender_visuals as visual_builder


def setup_camera():
    bpy.ops.object.light_add(type="SUN", location=(0, 0, 40))
    sun = bpy.context.object
    sun.name = "PreviewSun"
    sun.rotation_euler = (0.9, 0.0, -0.7)
    sun.data.energy = 2.2

    bpy.ops.object.camera_add(location=(0, 0, 118), rotation=(0.0, 0.0, 0.0))
    camera = bpy.context.object
    camera.name = "PreviewCamera"
    camera.data.type = "ORTHO"
    camera.data.ortho_scale = 142
    bpy.context.scene.camera = camera


def render_preview():
    OUT_PATH.parent.mkdir(parents=True, exist_ok=True)
    scene = bpy.context.scene
    scene.render.engine = "BLENDER_EEVEE"
    scene.eevee.taa_render_samples = 64
    scene.render.resolution_x = 1600
    scene.render.resolution_y = 1600
    scene.view_settings.view_transform = "Standard"
    scene.view_settings.look = "Medium High Contrast"
    scene.view_settings.exposure = 0
    scene.view_settings.gamma = 1
    scene.render.film_transparent = False
    scene.world.color = (0.68, 0.84, 0.93)
    scene.render.filepath = str(OUT_PATH)
    bpy.ops.render.render(write_still=True)


if __name__ == "__main__":
    os.chdir(PROJECT_ROOT)
    visual_builder.clear_scene()
    visual_builder.build_scene()
    setup_camera()
    render_preview()
    print(f"Rendered {OUT_PATH}")
