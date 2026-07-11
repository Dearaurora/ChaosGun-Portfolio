import time

import bpy


if "blender_mcp_addon" not in bpy.context.preferences.addons:
    bpy.ops.preferences.addon_enable(module="blender_mcp_addon")

bpy.context.scene.blendermcp_port = 9876
bpy.ops.blendermcp.start_server()
print("BLENDER_MCP_SOCKET_STARTED=localhost:9876", flush=True)

# Keep Blender alive when launched in background mode. The MCP addon runs its
# socket listener in a thread and schedules Blender API work onto the main loop.
while True:
    time.sleep(0.25)
