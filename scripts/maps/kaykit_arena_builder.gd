@tool
extends Node3D

@export var build: bool = false :
	set(value):
		if value:
			_build_arena()

@export var spacing: float = 4.0

const ASSET_PATH = "res://assets/models/kaykit_platformer/KayKit_Platformer_Pack_1.0_FREE/KayKit_Platformer_Pack_1.0_FREE/Assets/gltf/green/"

var map_layout = [
	[1, 1, 1, 1, 1],
	[1, 0, 1, 0, 1],
	[1, 1, 1, 1, 1],
	[1, 0, 1, 0, 1],
	[1, 1, 1, 1, 1],
]

func _build_arena():
	# Clear existing children
	for child in get_children():
		child.queue_free()
	
	var packed_scene = load(ASSET_PATH + "platform_4x4x1_green.gltf")
	if not packed_scene:
		print("Failed to load KayKit platform asset.")
		return
		
	var width = map_layout[0].size()
	var height = map_layout.size()
	
	var offset_x = (width * spacing) / 2.0 - (spacing / 2.0)
	var offset_z = (height * spacing) / 2.0 - (spacing / 2.0)
	
	for z in range(height):
		for x in range(width):
			if map_layout[z][x] == 1:
				var instance = packed_scene.instantiate()
				add_child(instance)
				instance.owner = get_tree().edited_scene_root
				
				# KayKit origin is usually center bottom
				instance.position = Vector3(x * spacing - offset_x, 0, z * spacing - offset_z)
				
				# Generate collision box
				var static_body = StaticBody3D.new()
				var collision_shape = CollisionShape3D.new()
				var box = BoxShape3D.new()
				box.size = Vector3(4, 1, 4) # Assuming 4x4x1 is exactly 4x1x4 meters
				collision_shape.shape = box
				# Shift collision up so its center matches the 1-height platform if needed
				collision_shape.position = Vector3(0, 0.5, 0)
				
				static_body.add_child(collision_shape)
				instance.add_child(static_body)
				static_body.owner = get_tree().edited_scene_root
				collision_shape.owner = get_tree().edited_scene_root
	
	print("KayKit Arena Built Successfully!")
