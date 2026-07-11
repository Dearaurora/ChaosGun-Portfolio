import bpy


if "blender_mcp_addon" not in bpy.context.preferences.addons:
    bpy.ops.preferences.addon_enable(module="blender_mcp_addon")

bpy.context.scene.blendermcp_port = 9876
if not bpy.context.scene.blendermcp_server_running:
    bpy.ops.blendermcp.start_server()

print("BLENDER_MCP_SOCKET_STARTED=localhost:9876", flush=True)
