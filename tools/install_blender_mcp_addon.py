import os
import sys

import bpy


addon_path = os.environ.get("BLENDER_MCP_ADDON")
if not addon_path or not os.path.exists(addon_path):
    raise SystemExit(f"BLENDER_MCP_ADDON not found: {addon_path!r}")

module_name = os.path.splitext(os.path.basename(addon_path))[0]

bpy.ops.preferences.addon_install(filepath=addon_path, overwrite=True)
bpy.ops.preferences.addon_enable(module=module_name)
bpy.ops.wm.save_userpref()

enabled = module_name in bpy.context.preferences.addons
print(f"BLENDER_MCP_ADDON_MODULE={module_name}")
print(f"BLENDER_MCP_ADDON_ENABLED={enabled}")
if not enabled:
    raise SystemExit(1)
