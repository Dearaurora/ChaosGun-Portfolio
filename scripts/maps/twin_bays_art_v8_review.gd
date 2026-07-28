extends "res://scripts/maps/twin_bays_art_v7_review.gd"
class_name TwinBaysArtV8Review

## Isolated V8 look-development bridge. Geometry remains the retained,
## collision-free V7 benchmark asset; this pass changes only the existing
## background-water material and environment parameters.


func configure(arena: Node3D, art_profile: Dictionary) -> void:
	super.configure(arena, art_profile)
	name = "TwinBaysArtV8Review"
	set_meta("art_v8_review", true)
	set_meta("water_mass_light_candidate", true)
