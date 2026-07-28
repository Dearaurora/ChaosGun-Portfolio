extends TextureRect
class_name WeaponThumbnail


func set_weapon(weapon_id: String, _accent: Color = Color.WHITE) -> void:
	var texture_path := "res://assets/ui/generated/weapons/%s.png" % weapon_id
	texture = load(texture_path) if ResourceLoader.exists(texture_path) else load("res://assets/ui/generated/weapons/pistol.png")
