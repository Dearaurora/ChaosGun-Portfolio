extends "res://scripts/maps/twin_bays_arena_base.gd"

const FOREGROUND_SCENE_PATH := "res://assets/models/generated/twin_bays_splash_arena/twin_bays_splash_arena_foreground.glb"
const SplashBackdropScript = preload("res://scripts/maps/twin_bays_splash_backdrop.gd")
const PortalVFXScript = preload("res://scripts/maps/twin_bays_portal_vfx.gd")
const MatchPresentationScript = preload("res://scripts/maps/party_shooter_match_presentation.gd")

const MATCH_PRESENTATION_PROFILE := {
	"profile_id": "twin_bays_splash_arena",
	"intro_reveal_duration": 1.35,
	"winner_focus_delay": 0.78,
	"winner_camera_duration": 0.72,
	"hud_focus_alpha": 0.22,
	"hud_root_names": ["GameHUD"],
	"ready_color": Color("#FFF4DC"),
	"go_color": Color("#FFD447"),
	"ink_color": Color("#073E57"),
}

var _match_presentation: PartyShooterMatchPresentation = null


func _ready() -> void:
	super._ready()
	_setup_match_presentation()
	call_deferred("_start_match_presentation")


func _setup_match_presentation() -> void:
	if _match_presentation and is_instance_valid(_match_presentation):
		return
	_match_presentation = MatchPresentationScript.new() as PartyShooterMatchPresentation
	_match_presentation.name = "PartyShooterMatchPresentation"
	add_child(_match_presentation)
	_match_presentation.configure(self, _camera_director, _characters, MATCH_PRESENTATION_PROFILE)


func _start_match_presentation() -> void:
	if _match_presentation and is_instance_valid(_match_presentation):
		_match_presentation.configure(self, _camera_director, _characters, MATCH_PRESENTATION_PROFILE)
		_match_presentation.start_intro()


func get_match_presentation_debug() -> Dictionary:
	if _match_presentation and is_instance_valid(_match_presentation):
		return _match_presentation.get_debug_state()
	return {}


func _present_match_result(winner: BaseCharacter, winner_name: String, winner_color: Color) -> void:
	if _match_presentation and is_instance_valid(_match_presentation):
		await _match_presentation.present_result(winner, winner_color)
	if not is_inside_tree():
		return
	super._present_match_result(winner, winner_name, winner_color)

func _build_twin_bays_foreground(parent: Node3D) -> void:
	var packed := load(FOREGROUND_SCENE_PATH) as PackedScene
	if packed == null:
		push_error("Twin Bays production foreground is missing: %s" % FOREGROUND_SCENE_PATH)
		return
	var foreground := packed.instantiate() as Node3D
	if foreground == null:
		push_error("Twin Bays production foreground could not be instantiated")
		return
	foreground.name = "TwinBaysSplashForeground"
	foreground.set_meta("visual_only", true)
	foreground.set_meta("layout_source", TwinBaysLayoutScript.DEFAULT_PATH)
	parent.add_child(foreground)

func _build_twin_bays_backdrop(parent: Node3D) -> void:
	var backdrop := SplashBackdropScript.new() as TwinBaysSplashBackdrop
	backdrop.name = "SplashBackdropVisuals"
	parent.add_child(backdrop)
	backdrop.rebuild()

func _build_twin_bays_portal_visuals(
	portal: TwinBaysPortal,
	portal_data: Dictionary,
	_portal_normal: Vector3,
	_portal_mat: Material,
	_portal_core_mat: Material
) -> void:
	var vfx := PortalVFXScript.new() as TwinBaysPortalVFX
	portal.add_child(vfx)
	vfx.configure(portal, portal_data)

func _twin_bays_camera_profile() -> Dictionary:
	var look_at := Vector3(0.25, 1.0, 0.0)
	var view_offset := twin_bays_gameplay_view_offset()
	return {
		"position": look_at + view_offset,
		"look_at": look_at,
		# The production water pipes extend beyond the playable platform.  This
		# overview keeps both submerged entries in frame; live combat still zooms
		# toward the party through the shared camera director.
		"size": 98.0,
	}


func _twin_bays_runtime_camera_profile() -> Dictionary:
	var profile := super._twin_bays_runtime_camera_profile()
	profile["reveal_focus"] = Vector3(0.25, 1.0, 0.0)
	profile["reveal_size"] = 98.0
	profile["reveal_duration"] = 1.35
	profile["winner_focus_size"] = 38.5
	profile["winner_focus_duration"] = 0.72
	return profile


func _on_twin_bays_character_teleported(
	character: BaseCharacter,
	from_portal: TwinBaysPortal,
	to_portal: TwinBaysPortal
) -> void:
	# An immediate opening portal use is gameplay-critical. End only the arena
	# reveal camera override so the shared discontinuity guard can frame both
	# ends of the jump; READY/GO remains independent and finishes normally.
	if _camera_director and is_instance_valid(_camera_director):
		var camera_state := _camera_director.call("get_debug_state") as Dictionary
		if String(camera_state.get("presentation_mode", "")) == "reveal":
			_camera_director.call("release_presentation_override")
	super._on_twin_bays_character_teleported(character, from_portal, to_portal)

func _apply_twin_bays_environment_overrides() -> void:
	var key := get_node_or_null("DirectionalLight3D") as DirectionalLight3D
	if key:
		key.rotation_degrees = Vector3(-52.0, -31.0, 0.0)
		key.light_color = Color("#FFF0D5")
		key.light_energy = 0.74
		key.shadow_enabled = true
		key.shadow_blur = 2.15
		key.shadow_opacity = 0.67

	_configure_fill_light()
	var env_node := get_node_or_null("WorldEnvironment") as WorldEnvironment
	if env_node == null:
		env_node = WorldEnvironment.new()
		env_node.name = "WorldEnvironment"
		add_child(env_node)

	var environment := Environment.new()
	var sky := Sky.new()
	var sky_material := ProceduralSkyMaterial.new()
	sky_material.sky_top_color = Color("#68C9F1")
	sky_material.sky_horizon_color = Color("#BFEFFD")
	sky_material.ground_bottom_color = Color("#157CA7")
	sky_material.ground_horizon_color = Color("#69D3E6")
	sky_material.sun_angle_max = 18.0
	sky_material.sun_curve = 0.08
	sky.sky_material = sky_material
	environment.background_mode = Environment.BG_SKY
	environment.sky = sky
	environment.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	environment.tonemap_mode = Environment.TONE_MAPPER_ACES
	environment.tonemap_exposure = 0.64
	environment.adjustment_enabled = true
	environment.adjustment_brightness = 0.98
	environment.adjustment_contrast = 1.06
	environment.adjustment_saturation = 1.10
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("#B5EAF1")
	environment.ambient_light_energy = 0.24
	environment.ssao_enabled = true
	environment.ssao_radius = 1.15
	environment.ssao_intensity = 0.92
	environment.ssao_power = 1.30
	environment.glow_enabled = true
	environment.glow_intensity = 0.18
	environment.glow_strength = 0.58
	environment.glow_bloom = 0.02
	environment.fog_enabled = false
	env_node.environment = environment

func _configure_fill_light() -> void:
	var fill := get_node_or_null("SplashCoolFill") as OmniLight3D
	if fill == null:
		fill = OmniLight3D.new()
		fill.name = "SplashCoolFill"
		add_child(fill)
	fill.position = Vector3(-18.0, 36.0, 24.0)
	fill.light_color = Color("#86E8FF")
	fill.light_energy = 0.12
	fill.omni_range = 128.0
	fill.shadow_enabled = false
